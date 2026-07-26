#include "KeyVoxPredictiveNative.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <fcntl.h>
#include <memory>
#include <mutex>
#include <stdexcept>
#include <string>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unordered_map>
#include <unordered_set>
#include <unistd.h>
#include <utility>
#include <vector>

#include "latinime/dictionary/property/ngram_context.h"
#include "latinime/dictionary/structure/dictionary_structure_with_buffer_policy_factory.h"
#include "latinime/suggest/core/dictionary/dictionary.h"
#include "latinime/suggest/core/layout/proximity_info.h"
#include "latinime/suggest/core/result/suggestion_results.h"
#include "latinime/suggest/core/session/dic_traverse_session.h"
#include "latinime/suggest/core/suggest_options.h"
#include "latinime/utils/int_array_view.h"

using namespace latinime;

namespace {

thread_local std::string lastError;
constexpr int kInternalCandidateCount = 32;

template <typename T>
T readValue(const uint8_t *data) {
    T value;
    std::memcpy(&value, data, sizeof(T));
    return value;
}

class MappedFile {
public:
    explicit MappedFile(const std::string &path) {
        descriptor_ = open(path.c_str(), O_RDONLY);
        if (descriptor_ < 0) throw std::runtime_error("could not open artifact");
        struct stat status {};
        if (fstat(descriptor_, &status) != 0 || status.st_size <= 0) {
            throw std::runtime_error("could not stat artifact");
        }
        size_ = static_cast<size_t>(status.st_size);
        data_ = static_cast<const uint8_t *>(
            mmap(nullptr, size_, PROT_READ, MAP_PRIVATE, descriptor_, 0)
        );
        if (data_ == MAP_FAILED) throw std::runtime_error("could not map artifact");
    }

    ~MappedFile() {
        if (data_ && data_ != MAP_FAILED) {
            munmap(const_cast<uint8_t *>(data_), size_);
        }
        if (descriptor_ >= 0) close(descriptor_);
    }

    MappedFile(const MappedFile &) = delete;
    MappedFile &operator=(const MappedFile &) = delete;

    const uint8_t *data() const { return data_; }
    size_t size() const { return size_; }

private:
    int descriptor_ = -1;
    const uint8_t *data_ = nullptr;
    size_t size_ = 0;
};

uint64_t fnv1a64(const std::string &first, bool separator = false,
                 const std::string &second = {}) {
    uint64_t value = 14695981039346656037ULL;
    auto observe = [&value](uint8_t byte) {
        value ^= byte;
        value *= 1099511628211ULL;
    };
    for (uint8_t byte : first) observe(byte);
    if (separator) observe(0xff);
    for (uint8_t byte : second) observe(byte);
    return value;
}

class ContextArtifact {
public:
    explicit ContextArtifact(const std::string &path) : file_(path) {
        if (file_.size() < 24 || std::memcmp(file_.data(), "KVLM0001", 8) != 0) {
            throw std::runtime_error("invalid context artifact");
        }
        totalTokens_ = readValue<uint64_t>(file_.data() + 8);
        unigramCount_ = readValue<uint32_t>(file_.data() + 16);
        bigramCount_ = readValue<uint32_t>(file_.data() + 20);
        unigramOffset_ = 24;
        bigramOffset_ = unigramOffset_ + static_cast<size_t>(unigramCount_) * 9;
        if (bigramOffset_ + static_cast<size_t>(bigramCount_) * 10 != file_.size()) {
            throw std::runtime_error("invalid context artifact size");
        }
    }

    std::pair<double, double> unigram(const std::string &word) const {
        const uint8_t *entry = lookup(unigramOffset_, unigramCount_, 9, fnv1a64(word));
        if (!entry) {
            return {0.0, std::log(1.0 / static_cast<double>(std::max<uint64_t>(1, totalTokens_)))};
        }
        const double logCount = static_cast<double>(entry[8]) / 255.0 * 16.0;
        const double count = std::expm1(logCount);
        return {
            logCount,
            std::log((count + 1.0) / static_cast<double>(std::max<uint64_t>(1, totalTokens_))),
        };
    }

    std::array<double, 3> bigram(const std::string &previous,
                                  const std::string &candidate) const {
        if (previous.empty()) return {0.0, std::log(0.25), 0.0};
        const uint8_t *entry = lookup(
            bigramOffset_, bigramCount_, 10, fnv1a64(previous, true, candidate)
        );
        if (!entry) return {0.0, std::log(0.25), 0.0};
        return {
            static_cast<double>(entry[8]) / 255.0 * 16.0,
            static_cast<double>(entry[9]) / 255.0 * 16.0 - 16.0,
            1.0,
        };
    }

private:
    const uint8_t *lookup(size_t offset, uint32_t count, size_t stride,
                          uint64_t wanted) const {
        uint32_t low = 0;
        uint32_t high = count;
        while (low < high) {
            const uint32_t middle = low + (high - low) / 2;
            const uint64_t key = readValue<uint64_t>(
                file_.data() + offset + static_cast<size_t>(middle) * stride
            );
            if (key < wanted) low = middle + 1;
            else high = middle;
        }
        if (low >= count) return nullptr;
        const uint8_t *entry = file_.data() + offset + static_cast<size_t>(low) * stride;
        return readValue<uint64_t>(entry) == wanted ? entry : nullptr;
    }

    MappedFile file_;
    uint64_t totalTokens_ = 0;
    uint32_t unigramCount_ = 0;
    uint32_t bigramCount_ = 0;
    size_t unigramOffset_ = 0;
    size_t bigramOffset_ = 0;
};

struct TreeView {
    const uint8_t *nodes;
    uint16_t count;
};

class TreeModel {
public:
    explicit TreeModel(const std::string &path) : file_(path) {
        if (file_.size() < 20 || std::memcmp(file_.data(), "KVTR0001", 8) != 0) {
            throw std::runtime_error("invalid tree model");
        }
        featureCount_ = readValue<uint16_t>(file_.data() + 8);
        const uint16_t treeCount = readValue<uint16_t>(file_.data() + 10);
        baseline_ = readValue<double>(file_.data() + 12);
        size_t offset = 20;
        trees_.reserve(treeCount);
        for (uint16_t tree = 0; tree < treeCount; ++tree) {
            if (offset + 2 > file_.size()) throw std::runtime_error("truncated tree model");
            const uint16_t count = readValue<uint16_t>(file_.data() + offset);
            offset += 2;
            const size_t bytes = static_cast<size_t>(count) * 22;
            if (offset + bytes > file_.size()) throw std::runtime_error("truncated tree nodes");
            trees_.push_back({file_.data() + offset, count});
            offset += bytes;
        }
        if (offset != file_.size()) throw std::runtime_error("invalid tree model length");
    }

    double probability(const double *features, size_t count) const {
        if (count != featureCount_) throw std::runtime_error("wrong feature count");
        double raw = baseline_;
        for (const TreeView &tree : trees_) {
            uint16_t index = 0;
            while (true) {
                const uint8_t *node = tree.nodes + static_cast<size_t>(index) * 22;
                const uint8_t feature = node[0];
                const uint8_t flags = node[1];
                const uint16_t left = readValue<uint16_t>(node + 2);
                const uint16_t right = readValue<uint16_t>(node + 4);
                const double threshold = readValue<double>(node + 6);
                const double value = readValue<double>(node + 14);
                if (flags & 1) {
                    raw += value;
                    break;
                }
                const double observed = features[feature];
                if (std::isnan(observed)) index = flags & 2 ? left : right;
                else index = observed <= threshold ? left : right;
                if (index >= tree.count) throw std::runtime_error("invalid tree child");
            }
        }
        return 1.0 / (1.0 + std::exp(-raw));
    }

private:
    MappedFile file_;
    uint16_t featureCount_ = 0;
    double baseline_ = 0;
    std::vector<TreeView> trees_;
};

std::vector<int> utf8CodePoints(const std::string &text) {
    std::vector<int> result;
    for (size_t index = 0; index < text.size();) {
        const uint8_t first = static_cast<uint8_t>(text[index]);
        int codePoint = 0;
        size_t length = 0;
        if (first < 0x80) {
            codePoint = first;
            length = 1;
        } else if ((first & 0xE0) == 0xC0) {
            codePoint = first & 0x1F;
            length = 2;
        } else if ((first & 0xF0) == 0xE0) {
            codePoint = first & 0x0F;
            length = 3;
        } else if ((first & 0xF8) == 0xF0) {
            codePoint = first & 0x07;
            length = 4;
        } else {
            ++index;
            continue;
        }
        if (index + length > text.size()) break;
        bool valid = true;
        for (size_t offset = 1; offset < length; ++offset) {
            const uint8_t continuation = static_cast<uint8_t>(text[index + offset]);
            if ((continuation & 0xC0) != 0x80) {
                valid = false;
                break;
            }
            codePoint = (codePoint << 6) | (continuation & 0x3F);
        }
        if (valid) result.push_back(codePoint);
        index += valid ? length : 1;
    }
    return result;
}

void appendUtf8(int codePoint, std::string *text) {
    if (codePoint <= 0x7F) {
        text->push_back(static_cast<char>(codePoint));
    } else if (codePoint <= 0x7FF) {
        text->push_back(static_cast<char>(0xC0 | (codePoint >> 6)));
        text->push_back(static_cast<char>(0x80 | (codePoint & 0x3F)));
    } else if (codePoint <= 0xFFFF) {
        text->push_back(static_cast<char>(0xE0 | (codePoint >> 12)));
        text->push_back(static_cast<char>(0x80 | ((codePoint >> 6) & 0x3F)));
        text->push_back(static_cast<char>(0x80 | (codePoint & 0x3F)));
    } else {
        text->push_back(static_cast<char>(0xF0 | (codePoint >> 18)));
        text->push_back(static_cast<char>(0x80 | ((codePoint >> 12) & 0x3F)));
        text->push_back(static_cast<char>(0x80 | ((codePoint >> 6) & 0x3F)));
        text->push_back(static_cast<char>(0x80 | (codePoint & 0x3F)));
    }
}

int damerauOSA(const std::string &left, const std::string &right) {
    const size_t leftCount = left.size();
    const size_t rightCount = right.size();
    std::vector<int> previousPrevious(rightCount + 1);
    std::vector<int> previous(rightCount + 1);
    std::vector<int> current(rightCount + 1);
    for (size_t column = 0; column <= rightCount; ++column) {
        previous[column] = static_cast<int>(column);
    }
    for (size_t row = 1; row <= leftCount; ++row) {
        current[0] = static_cast<int>(row);
        for (size_t column = 1; column <= rightCount; ++column) {
            const int substitution = previous[column - 1]
                + (left[row - 1] == right[column - 1] ? 0 : 1);
            current[column] = std::min({
                previous[column] + 1,
                current[column - 1] + 1,
                substitution,
            });
            if (row > 1 && column > 1
                    && left[row - 1] == right[column - 2]
                    && left[row - 2] == right[column - 1]) {
                current[column] = std::min(current[column], previousPrevious[column - 2] + 1);
            }
        }
        previousPrevious.swap(previous);
        previous.swap(current);
    }
    return previous[rightCount];
}

struct NativeCandidate {
    std::string word;
    int score = 0;
    int type = 0;
    double probability = 0;
    size_t nativeRank = 0;
};

class Engine {
public:
    Engine(const char *dictionaryPath,
           const char *contextPath,
           const char *correctionRankerPath,
           const char *completionRankerPath,
           const char *actionModelPath,
           const KVPKKeyGeometry *keys,
           int32_t keyCount,
           int32_t keyboardWidth,
           int32_t keyboardHeight)
        : context_(contextPath),
          correctionRanker_(correctionRankerPath),
          completionRanker_(completionRankerPath),
          actionModel_(actionModelPath) {
        struct stat status {};
        if (stat(dictionaryPath, &status) != 0 || status.st_size <= 0
                || status.st_size > INT32_MAX) {
            throw std::runtime_error("invalid dictionary");
        }
        auto policy = DictionaryStructureWithBufferPolicyFactory::newPolicyForExistingDictFile(
            dictionaryPath, 0, static_cast<int>(status.st_size), false
        );
        if (!policy) throw std::runtime_error("could not open dictionary");
        dictionary_ = std::make_unique<Dictionary>(&environment_, std::move(policy));
        session_ = std::make_unique<DicTraverseSession>(&environment_, nullptr, true);
        if (!updateGeometry(keys, keyCount, keyboardWidth, keyboardHeight)) {
            throw std::runtime_error("invalid keyboard geometry");
        }
    }

    bool updateGeometry(const KVPKKeyGeometry *keys,
                        int32_t keyCount,
                        int32_t keyboardWidth,
                        int32_t keyboardHeight) {
        if (!keys || keyCount <= 0 || keyboardWidth <= 0 || keyboardHeight <= 0) return false;
        std::lock_guard<std::mutex> lock(mutex_);

        constexpr int gridWidth = 10;
        constexpr int gridHeight = 4;
        const int cellWidth = std::max(1, keyboardWidth / gridWidth);
        const int cellHeight = std::max(1, keyboardHeight / gridHeight);
        const double radius = std::hypot(cellWidth, cellHeight) * 1.35;
        std::vector<int> proximity(
            gridWidth * gridHeight * MAX_PROXIMITY_CHARS_SIZE, 0
        );
        for (int row = 0; row < gridHeight; ++row) {
            for (int column = 0; column < gridWidth; ++column) {
                const int centerX = column * cellWidth + cellWidth / 2;
                const int centerY = row * cellHeight + cellHeight / 2;
                std::vector<std::pair<double, int>> nearby;
                for (int32_t index = 0; index < keyCount; ++index) {
                    const int keyCenterX = keys[index].x + keys[index].width / 2;
                    const int keyCenterY = keys[index].y + keys[index].height / 2;
                    const double distance = std::hypot(
                        static_cast<double>(centerX - keyCenterX),
                        static_cast<double>(centerY - keyCenterY)
                    );
                    if (distance <= radius) nearby.push_back({distance, keys[index].codePoint});
                }
                std::sort(nearby.begin(), nearby.end());
                const int base = (row * gridWidth + column) * MAX_PROXIMITY_CHARS_SIZE;
                const int limit = std::min(
                    static_cast<int>(nearby.size()),
                    MAX_PROXIMITY_CHARS_SIZE
                );
                for (int index = 0; index < limit; ++index) {
                    proximity[base + index] = nearby[index].second;
                }
            }
        }

        std::vector<int> x;
        std::vector<int> y;
        std::vector<int> widths;
        std::vector<int> heights;
        std::vector<int> codes;
        keyByCodePoint_.clear();
        x.reserve(keyCount);
        y.reserve(keyCount);
        widths.reserve(keyCount);
        heights.reserve(keyCount);
        codes.reserve(keyCount);
        for (int32_t index = 0; index < keyCount; ++index) {
            x.push_back(keys[index].x);
            y.push_back(keys[index].y);
            widths.push_back(keys[index].width);
            heights.push_back(keys[index].height);
            codes.push_back(keys[index].codePoint);
            keyByCodePoint_[keys[index].codePoint] = keys[index];
        }

        auto proximityArray = intArray(proximity);
        auto xArray = intArray(x);
        auto yArray = intArray(y);
        auto widthArray = intArray(widths);
        auto heightArray = intArray(heights);
        auto codeArray = intArray(codes);
        proximity_ = std::make_unique<ProximityInfo>(
            &environment_, keyboardWidth, keyboardHeight, gridWidth, gridHeight,
            cellWidth, cellHeight, &proximityArray, keyCount, &xArray, &yArray,
            &widthArray, &heightArray, &codeArray, nullptr, nullptr, nullptr
        );
        return true;
    }

    bool predict(const char *typedWord,
                 const char *previousWord,
                 const char *olderWord,
                 const char *oldestWord,
                 const int32_t *touchX,
                 const int32_t *touchY,
                 int32_t touchCount,
                 KVPKPredictionMode mode,
                 KVPKPredictionResult *result) {
        if (!result || !typedWord) return false;
        std::lock_guard<std::mutex> lock(mutex_);
        std::memset(result, 0, sizeof(*result));

        const std::string typed(typedWord);
        const std::vector<std::string> previous = nonEmptyWords(
            previousWord, olderWord, oldestWord
        );
        const std::vector<int> typedCodePoints = utf8CodePoints(typed);
        if (typedCodePoints.size() >= MAX_WORD_LENGTH) {
            result->typedWordIsValid = true;
            return true;
        }
        result->typedWordIsValid = !typedCodePoints.empty()
            && dictionary_->getProbability(
                CodePointArrayView(typedCodePoints.data(), typedCodePoints.size())
            ) >= 0;

        std::vector<NativeCandidate> candidates = nativeCandidates(
            typed, typedCodePoints, previous, touchX, touchY, touchCount
        );
        if (mode != KVPKPredictionModeNextWord) {
            candidates.erase(
                std::remove_if(
                    candidates.begin(), candidates.end(),
                    [&typed](const NativeCandidate &candidate) {
                        return candidate.word == typed || candidate.word.find(' ') != std::string::npos;
                    }
                ),
                candidates.end()
            );
            TreeModel &ranker = mode == KVPKPredictionModeCompletion
                ? completionRanker_ : correctionRanker_;
            rankCandidates(typed, previous, &candidates, ranker);
            if (candidates.size() > KVPK_MAX_SUGGESTIONS) {
                candidates.resize(KVPK_MAX_SUGGESTIONS);
            }
        }

        result->count = static_cast<int32_t>(
            std::min<size_t>(candidates.size(), KVPK_MAX_SUGGESTIONS)
        );
        for (int32_t index = 0; index < result->count; ++index) {
            const NativeCandidate &candidate = candidates[index];
            std::strncpy(
                result->suggestions[index].word,
                candidate.word.c_str(),
                KVPK_MAX_WORD_BYTES - 1
            );
            result->suggestions[index].word[KVPK_MAX_WORD_BYTES - 1] = '\0';
            result->suggestions[index].nativeScore = candidate.score;
            result->suggestions[index].nativeType = candidate.type;
            result->suggestions[index].rankProbability = candidate.probability;
        }

        if (mode == KVPKPredictionModeCorrection && !candidates.empty()) {
            result->automaticCorrectionProbability = actionProbability(
                typed, previous, candidates, result->typedWordIsValid
            );
        }
        return true;
    }

private:
    static JniArray intArray(const std::vector<int> &values) {
        JniArray array;
        array.ints.assign(values.begin(), values.end());
        return array;
    }

    static std::vector<std::string> nonEmptyWords(const char *previous,
                                                   const char *older,
                                                   const char *oldest) {
        std::vector<std::string> result;
        for (const char *word : {previous, older, oldest}) {
            if (word && word[0] != '\0') result.emplace_back(word);
        }
        return result;
    }

    NgramContext makeContext(const std::vector<std::string> &words) const {
        int codePoints[MAX_PREV_WORD_COUNT_FOR_N_GRAM][MAX_WORD_LENGTH] = {};
        int lengths[MAX_PREV_WORD_COUNT_FOR_N_GRAM] = {};
        bool beginnings[MAX_PREV_WORD_COUNT_FOR_N_GRAM] = {};
        const int count = std::min(
            static_cast<int>(words.size()),
            MAX_PREV_WORD_COUNT_FOR_N_GRAM
        );
        for (int index = 0; index < count; ++index) {
            const std::vector<int> points = utf8CodePoints(words[index]);
            lengths[index] = std::min(
                static_cast<int>(points.size()),
                MAX_WORD_LENGTH - 1
            );
            std::copy_n(points.begin(), lengths[index], codePoints[index]);
        }
        return NgramContext(codePoints, lengths, beginnings, count);
    }

    std::vector<NativeCandidate> nativeCandidates(
        const std::string &typed,
        const std::vector<int> &typedCodePoints,
        const std::vector<std::string> &previous,
        const int32_t *touchX,
        const int32_t *touchY,
        int32_t touchCount
    ) {
        std::vector<int> x;
        std::vector<int> y;
        std::vector<int> times;
        std::vector<int> pointerIds;
        x.reserve(typedCodePoints.size());
        y.reserve(typedCodePoints.size());
        times.reserve(typedCodePoints.size());
        pointerIds.reserve(typedCodePoints.size());
        for (size_t index = 0; index < typedCodePoints.size(); ++index) {
            if (touchX && touchY && touchCount == static_cast<int32_t>(typedCodePoints.size())) {
                x.push_back(touchX[index]);
                y.push_back(touchY[index]);
            } else if (const auto found = keyByCodePoint_.find(typedCodePoints[index]);
                       found != keyByCodePoint_.end()) {
                x.push_back(found->second.x + found->second.width / 2);
                y.push_back(found->second.y + found->second.height / 2);
            } else {
                x.push_back(0);
                y.push_back(0);
            }
            times.push_back(static_cast<int>(index) * 100);
            pointerIds.push_back(0);
        }

        NgramContext context = makeContext(previous);
        SuggestionResults nativeResults(kInternalCandidateCount);
        if (typedCodePoints.empty()) {
            dictionary_->getPredictions(&context, &nativeResults);
        } else {
            const int rawOptions[] = {0, 1, 0, 0, 1000};
            SuggestOptions options(rawOptions, 5);
            dictionary_->getSuggestions(
                proximity_.get(), session_.get(), x.data(), y.data(), times.data(),
                pointerIds.data(), const_cast<int *>(typedCodePoints.data()),
                static_cast<int>(typedCodePoints.size()), &context, &options, -1.0f,
                &nativeResults
            );
        }

        JniArray count;
        count.ints.resize(1);
        JniArray outputCodePoints;
        outputCodePoints.ints.resize(kInternalCandidateCount * MAX_WORD_LENGTH);
        JniArray scores;
        scores.ints.resize(kInternalCandidateCount);
        JniArray spaces;
        spaces.ints.resize(kInternalCandidateCount);
        JniArray types;
        types.ints.resize(kInternalCandidateCount);
        JniArray confidence;
        confidence.ints.resize(kInternalCandidateCount);
        JniArray weight;
        weight.floats.resize(1);
        nativeResults.outputSuggestions(
            &environment_, &count, &outputCodePoints, &scores, &spaces, &types,
            &confidence, &weight
        );

        std::vector<NativeCandidate> result;
        std::unordered_map<std::string, size_t> indexByWord;
        const int suggestionCount = std::clamp(
            count.ints[0],
            0,
            kInternalCandidateCount
        );
        for (int index = 0; index < suggestionCount; ++index) {
            std::string word;
            for (int position = 0; position < MAX_WORD_LENGTH; ++position) {
                const int codePoint = outputCodePoints.ints[index * MAX_WORD_LENGTH + position];
                if (codePoint == 0) break;
                appendUtf8(codePoint, &word);
            }
            if (word.empty()) continue;
            const auto existing = indexByWord.find(word);
            if (existing != indexByWord.end()) {
                NativeCandidate &candidate = result[existing->second];
                if (scores.ints[index] > candidate.score) {
                    candidate.score = scores.ints[index];
                    candidate.type = types.ints[index];
                }
                continue;
            }
            indexByWord[word] = result.size();
            result.push_back({
                word,
                scores.ints[index],
                types.ints[index],
                0.0,
                static_cast<size_t>(index),
            });
        }
        appendSingleEditCandidates(typed, &result);
        std::stable_sort(
            result.begin(), result.end(),
            [](const NativeCandidate &left, const NativeCandidate &right) {
                if (left.score != right.score) return left.score > right.score;
                return left.word.size() < right.word.size();
            }
        );
        for (size_t index = 0; index < result.size(); ++index) result[index].nativeRank = index;
        return result;
    }

    void appendSingleEditCandidates(
        const std::string &typed,
        std::vector<NativeCandidate> *candidates
    ) const {
        if (typed.size() < 2 || typed.size() + 1 >= MAX_WORD_LENGTH
                || !std::all_of(typed.begin(), typed.end(), [](unsigned char value) {
                    return value >= 'a' && value <= 'z';
                })) {
            return;
        }

        std::unordered_set<std::string> observed;
        int recoveryScore = 0;
        int recoveryType = Dictionary::KIND_CORRECTION;
        if (!candidates->empty()) {
            recoveryScore = std::min_element(
                candidates->begin(), candidates->end(),
                [](const NativeCandidate &left, const NativeCandidate &right) {
                    return left.score < right.score;
                }
            )->score - 1;
            recoveryType = candidates->front().type;
        }
        for (const NativeCandidate &candidate : *candidates) {
            observed.insert(candidate.word);
        }

        const auto appendDictionaryCandidate = [&](const std::string &candidate) {
            if (!observed.insert(candidate).second) return;
            const std::vector<int> codePoints = utf8CodePoints(candidate);
            if (dictionary_->getProbability(
                    CodePointArrayView(codePoints.data(), codePoints.size())) < 0) {
                return;
            }
            candidates->push_back({
                candidate,
                recoveryScore,
                recoveryType,
                0.0,
                candidates->size(),
            });
        };

        for (size_t position = 0; position <= typed.size(); ++position) {
            for (char inserted = 'a'; inserted <= 'z'; ++inserted) {
                std::string candidate = typed;
                candidate.insert(
                    candidate.begin() + static_cast<std::ptrdiff_t>(position),
                    inserted
                );
                appendDictionaryCandidate(candidate);
            }
        }

        for (size_t position = 0; position < typed.size(); ++position) {
            for (char replacement = 'a'; replacement <= 'z'; ++replacement) {
                if (replacement == typed[position]) continue;
                std::string candidate = typed;
                candidate[position] = replacement;
                appendDictionaryCandidate(candidate);
            }
        }

        for (size_t position = 0; position + 1 < typed.size(); ++position) {
            if (typed[position] == typed[position + 1]) continue;
            std::string candidate = typed;
            std::swap(candidate[position], candidate[position + 1]);
            appendDictionaryCandidate(candidate);
        }
    }

    void rankCandidates(const std::string &typed,
                        const std::vector<std::string> &previous,
                        std::vector<NativeCandidate> *candidates,
                        const TreeModel &model) const {
        for (NativeCandidate &candidate : *candidates) {
            std::array<double, 23> features = candidateFeatures(
                typed, previous, candidate
            );
            candidate.probability = model.probability(features.data(), features.size());
        }
        std::stable_sort(
            candidates->begin(), candidates->end(),
            [](const NativeCandidate &left, const NativeCandidate &right) {
                return left.probability > right.probability;
            }
        );
    }

    std::array<double, 23> candidateFeatures(
        const std::string &typed,
        const std::vector<std::string> &previous,
        const NativeCandidate &candidate
    ) const {
        const int distance = damerauOSA(typed, candidate.word);
        const size_t longest = std::max<size_t>({1, typed.size(), candidate.word.size()});
        size_t commonPrefix = 0;
        while (commonPrefix < typed.size() && commonPrefix < candidate.word.size()
                && typed[commonPrefix] == candidate.word[commonPrefix]) {
            ++commonPrefix;
        }
        size_t commonSuffix = 0;
        while (commonSuffix < typed.size() && commonSuffix < candidate.word.size()
                && typed[typed.size() - commonSuffix - 1]
                    == candidate.word[candidate.word.size() - commonSuffix - 1]) {
            ++commonSuffix;
        }
        const auto unigram = context_.unigram(candidate.word);
        const auto bigram = context_.bigram(
            previous.empty() ? std::string() : previous.front(), candidate.word
        );
        return {
            candidate.score / 1000000.0,
            static_cast<double>(candidate.nativeRank),
            1.0 / static_cast<double>(candidate.nativeRank + 1),
            static_cast<double>(candidate.type),
            static_cast<double>(distance),
            static_cast<double>(distance) / static_cast<double>(longest),
            static_cast<double>(typed.size()),
            static_cast<double>(candidate.word.size()),
            static_cast<double>(std::abs(
                static_cast<int>(typed.size()) - static_cast<int>(candidate.word.size())
            )),
            static_cast<double>(commonPrefix) / static_cast<double>(longest),
            static_cast<double>(commonSuffix) / static_cast<double>(longest),
            static_cast<double>(!typed.empty() && !candidate.word.empty()
                && typed.front() == candidate.word.front()),
            static_cast<double>(!typed.empty() && !candidate.word.empty()
                && typed.back() == candidate.word.back()),
            static_cast<double>(typed.size() == candidate.word.size() && distance == 1),
            static_cast<double>(typed.find('\'') != std::string::npos),
            static_cast<double>(candidate.word.find('\'') != std::string::npos),
            static_cast<double>(!previous.empty()),
            static_cast<double>(std::min<size_t>(3, previous.size())),
            unigram.first,
            unigram.second,
            bigram[0],
            bigram[1],
            bigram[2],
        };
    }

    double actionProbability(const std::string &typed,
                             const std::vector<std::string> &previous,
                             const std::vector<NativeCandidate> &ranked,
                             bool typedWordIsValid) const {
        if (typedWordIsValid || typed.size() < 2 || ranked.empty()) return 0;
        if (hasTripleRepeat(typed)) return 0;
        const NativeCandidate &best = ranked.front();
        const NativeCandidate &second = ranked.size() > 1 ? ranked[1] : best;
        const int distance = damerauOSA(typed, best.word);
        const size_t longest = std::max<size_t>({1, typed.size(), best.word.size()});
        if (distance >= static_cast<int>(best.word.size()) || distance > 4
                || static_cast<double>(distance) / static_cast<double>(longest) > 0.5) {
            return 0;
        }
        if (typed.size() <= 4 && !hasVowel(typed)) return 0;
        if (typed.size() >= 2 && typed[typed.size() - 1] == typed[typed.size() - 2]
                && best.word.rfind(typed, 0) == 0) {
            return 0;
        }

        const int rawTopScore = nativeTopScore(ranked);
        const double secondProbability = std::max(1e-6, second.probability);
        const std::array<double, 14> features = {
            best.probability,
            second.probability,
            best.probability - second.probability,
            best.probability / secondProbability,
            static_cast<double>(best.nativeRank),
            best.score / 1000000.0,
            rawTopScore / 1000000.0,
            (best.score - rawTopScore) / 1000000.0,
            static_cast<double>(distance),
            static_cast<double>(distance) / static_cast<double>(longest),
            static_cast<double>(typed.size()),
            static_cast<double>(best.word.size()),
            static_cast<double>(best.nativeRank == 0),
            static_cast<double>(!previous.empty()),
        };
        return actionModel_.probability(features.data(), features.size());
    }

    static int nativeTopScore(const std::vector<NativeCandidate> &candidates) {
        int score = INT32_MIN;
        for (const NativeCandidate &candidate : candidates) {
            score = std::max(score, candidate.score);
        }
        return score == INT32_MIN ? 0 : score;
    }

    static bool hasTripleRepeat(const std::string &word) {
        for (size_t index = 2; index < word.size(); ++index) {
            if (word[index] == word[index - 1] && word[index] == word[index - 2]) return true;
        }
        return false;
    }

    static bool hasVowel(const std::string &word) {
        return word.find_first_of("aeiouy") != std::string::npos;
    }

    JNIEnv environment_;
    std::unique_ptr<Dictionary> dictionary_;
    std::unique_ptr<DicTraverseSession> session_;
    std::unique_ptr<ProximityInfo> proximity_;
    std::unordered_map<int, KVPKKeyGeometry> keyByCodePoint_;
    ContextArtifact context_;
    TreeModel correctionRanker_;
    TreeModel completionRanker_;
    TreeModel actionModel_;
    std::mutex mutex_;
};

}  // namespace

KVPKEngineRef KVPKEngineCreate(
    const char *dictionaryPath,
    const char *contextPath,
    const char *correctionRankerPath,
    const char *completionRankerPath,
    const char *actionModelPath,
    const KVPKKeyGeometry *keys,
    int32_t keyCount,
    int32_t keyboardWidth,
    int32_t keyboardHeight
) {
    try {
        lastError.clear();
        return new Engine(
            dictionaryPath, contextPath, correctionRankerPath, completionRankerPath,
            actionModelPath, keys, keyCount, keyboardWidth, keyboardHeight
        );
    } catch (const std::exception &error) {
        lastError = error.what();
        return nullptr;
    } catch (...) {
        lastError = "unknown native initialization error";
        return nullptr;
    }
}

const char *KVPKEngineLastError(void) {
    return lastError.c_str();
}

void KVPKEngineDestroy(KVPKEngineRef engine) {
    delete static_cast<Engine *>(engine);
}

bool KVPKEngineUpdateGeometry(
    KVPKEngineRef engine,
    const KVPKKeyGeometry *keys,
    int32_t keyCount,
    int32_t keyboardWidth,
    int32_t keyboardHeight
) {
    if (!engine) return false;
    try {
        lastError.clear();
        return static_cast<Engine *>(engine)->updateGeometry(
            keys, keyCount, keyboardWidth, keyboardHeight
        );
    } catch (const std::exception &error) {
        lastError = error.what();
        return false;
    } catch (...) {
        lastError = "unknown geometry error";
        return false;
    }
}

bool KVPKEnginePredict(
    KVPKEngineRef engine,
    const char *typedWord,
    const char *previousWord,
    const char *olderWord,
    const char *oldestWord,
    const int32_t *touchX,
    const int32_t *touchY,
    int32_t touchCount,
    KVPKPredictionMode mode,
    KVPKPredictionResult *result
) {
    if (!engine) return false;
    try {
        lastError.clear();
        return static_cast<Engine *>(engine)->predict(
            typedWord, previousWord, olderWord, oldestWord,
            touchX, touchY, touchCount, mode, result
        );
    } catch (const std::exception &error) {
        lastError = error.what();
        return false;
    } catch (...) {
        lastError = "unknown prediction error";
        return false;
    }
}
