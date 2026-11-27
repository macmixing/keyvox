// Prints LatinIME's suggestions for typed letters, as tapped at the center of each key of a
// letter layout, after up to three previous words. Typed letters left empty ask for next-word
// predictions.
//
// usage: latinime_suggestions DICTIONARY_DIRECTORY [--shared-session]
//            --row LETTERS OFFSET [--row LETTERS OFFSET]... < QUERIES
//   each --row: a letter row of the layout, top to bottom: its letters and the offset of its first
//     letter, in key pitches (letter_layout.py)
//   each query line: typed<TAB>previous word[<TAB>older word[<TAB>oldest word]]
//   each output line: query index, then word<TAB>score<TAB>type for each suggestion, best first
//
// Each letter key is 100 units square: row r spans r * 100 to (r + 1) * 100 down, and a row's ith
// letter spans (offset + i) * 100 to (offset + i + 1) * 100 across. The keyboard is as wide as its
// widest letter row and a row taller than its letter rows, for the space bar, five keys wide in its
// middle; the apostrophe key follows the second row's last letter. A letter without a key of its
// own is tapped on its base letter's key, as a long press there types it. Typed
// letters of MAX_WORD_LENGTH code points or more get no suggestions, as in the keyboard's engine.
//
// Each query searches in a session of its own. A session continues its last search when the
// new typed letters start with the last ones, keeping that search's previous words, so a shared
// session answers some queries for the query asked before them. With --shared-session every
// query searches in one session, as the caches the bundled rankers learned from did.

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <memory>
#include <sstream>
#include <string>
#include <sys/stat.h>
#include <unordered_map>
#include <vector>

#include "dictionary/property/ngram_context.h"
#include "dictionary/structure/dictionary_structure_with_buffer_policy_factory.h"
#include "suggest/core/dictionary/dictionary.h"
#include "suggest/core/layout/proximity_info.h"
#include "suggest/core/result/suggestion_results.h"
#include "suggest/core/session/dic_traverse_session.h"
#include "suggest/core/suggest_options.h"

using namespace latinime;

struct Key { int code, x, y, w, h; };
struct LetterRow { std::vector<int> letters; double offset; };
struct Keyboard { std::vector<Key> keys; int width, height; };

static std::vector<int> utf8CodePoints(const std::string &text);

static constexpr int kKeySize = 100;

static int keyPosition(double pitches) {
    return static_cast<int>(std::lround(pitches * kKeySize));
}

static Keyboard letterKeyboard(const std::vector<LetterRow> &rows) {
    Keyboard keyboard{{}, 0, static_cast<int>(rows.size() + 1) * kKeySize};
    for (size_t row = 0; row < rows.size(); ++row) {
        const auto &letters = rows[row].letters;
        for (size_t column = 0; column < letters.size(); ++column) {
            keyboard.keys.push_back({letters[column], keyPosition(rows[row].offset + column),
                    static_cast<int>(row) * kKeySize, kKeySize, kKeySize});
        }
        keyboard.width = std::max(keyboard.width,
                keyPosition(rows[row].offset + letters.size()));
    }
    keyboard.keys.push_back({' ', keyboard.width / 2 - 5 * kKeySize / 2,
            static_cast<int>(rows.size()) * kKeySize, 5 * kKeySize, kKeySize});
    const size_t apostropheRow = rows.size() > 1 ? 1 : 0;
    keyboard.keys.push_back({'\'', keyPosition(rows[apostropheRow].offset
            + rows[apostropheRow].letters.size()), static_cast<int>(apostropheRow) * kKeySize,
            kKeySize, kKeySize});
    return keyboard;
}

static JniArray intArray(const std::vector<int> &values) {
    JniArray array;
    array.ints.assign(values.begin(), values.end());
    return array;
}

static ProximityInfo makeProximityInfo(JNIEnv *env, const Keyboard &keyboard) {
    const auto &keys = keyboard.keys;
    const int gridWidth = (keyboard.width + kKeySize - 1) / kKeySize;
    const int gridHeight = (keyboard.height + kKeySize - 1) / kKeySize;
    const int keyboardWidth = keyboard.width;
    const int keyboardHeight = keyboard.height;
    std::vector<int> proximity(gridWidth * gridHeight * MAX_PROXIMITY_CHARS_SIZE, 0);
    for (int gy = 0; gy < gridHeight; ++gy) {
        for (int gx = 0; gx < gridWidth; ++gx) {
            const int cx = gx * kKeySize + kKeySize / 2;
            const int cy = gy * kKeySize + kKeySize / 2;
            std::vector<std::pair<float, int>> nearby;
            for (const auto &key : keys) {
                const float dx = static_cast<float>(cx - (key.x + key.w / 2));
                const float dy = static_cast<float>(cy - (key.y + key.h / 2));
                const float distance = std::hypot(dx, dy);
                if (distance <= 175.0f) nearby.push_back({distance, key.code});
            }
            std::sort(nearby.begin(), nearby.end());
            const int base = (gy * gridWidth + gx) * MAX_PROXIMITY_CHARS_SIZE;
            for (int i = 0; i < static_cast<int>(nearby.size()) && i < MAX_PROXIMITY_CHARS_SIZE; ++i) {
                proximity[base + i] = nearby[i].second;
            }
        }
    }
    std::vector<int> xs, ys, widths, heights, codes;
    for (const auto &key : keys) {
        xs.push_back(key.x); ys.push_back(key.y); widths.push_back(key.w);
        heights.push_back(key.h); codes.push_back(key.code);
    }
    auto proximityArray = intArray(proximity);
    auto xArray = intArray(xs); auto yArray = intArray(ys);
    auto widthArray = intArray(widths); auto heightArray = intArray(heights);
    auto codeArray = intArray(codes);
    return ProximityInfo(env, keyboardWidth, keyboardHeight, gridWidth, gridHeight, kKeySize, kKeySize,
            &proximityArray, static_cast<int>(keys.size()), &xArray, &yArray, &widthArray,
            &heightArray, &codeArray, nullptr, nullptr, nullptr);
}

struct Result { std::string word; int score; int type; };

static std::vector<int> utf8CodePoints(const std::string &text) {
    std::vector<int> result;
    for (size_t i = 0; i < text.size();) {
        const unsigned char first = static_cast<unsigned char>(text[i]);
        int codePoint = 0;
        size_t length = 0;
        if (first < 0x80) { codePoint = first; length = 1; }
        else if ((first & 0xE0) == 0xC0) { codePoint = first & 0x1F; length = 2; }
        else if ((first & 0xF0) == 0xE0) { codePoint = first & 0x0F; length = 3; }
        else if ((first & 0xF8) == 0xF0) { codePoint = first & 0x07; length = 4; }
        else { ++i; continue; }
        if (i + length > text.size()) break;
        bool valid = true;
        for (size_t offset = 1; offset < length; ++offset) {
            const unsigned char continuation = static_cast<unsigned char>(text[i + offset]);
            if ((continuation & 0xC0) != 0x80) { valid = false; break; }
            codePoint = (codePoint << 6) | (continuation & 0x3F);
        }
        if (valid) result.push_back(codePoint);
        i += valid ? length : 1;
    }
    return result;
}

static void appendUtf8(const int codePoint, std::string *text) {
    if (codePoint <= 0x7F) text->push_back(static_cast<char>(codePoint));
    else if (codePoint <= 0x7FF) {
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

// The letter whose key types the code point: its own key, or, for a letter without one, its base
// letter's.
static int physicalBaseKey(int codePoint, const std::unordered_map<int, Key> &byCode) {
    if (codePoint >= 'A' && codePoint <= 'Z') return codePoint + ('a' - 'A');
    if (byCode.count(codePoint)) return codePoint;
    switch (codePoint) {
        case 0x00E0: case 0x00E1: case 0x00E2: case 0x00E3: case 0x00E4:
        case 0x00E5: case 0x00E6: return 'a';
        case 0x00E7: return 'c';
        case 0x00E8: case 0x00E9: case 0x00EA: case 0x00EB: return 'e';
        case 0x00EC: case 0x00ED: case 0x00EE: case 0x00EF: return 'i';
        case 0x00F0: return 'd';
        case 0x00F1: return 'n';
        case 0x00F2: case 0x00F3: case 0x00F4: case 0x00F5: case 0x00F6:
        case 0x00F8: case 0x0153: return 'o';
        case 0x00DF: return 's';
        case 0x00F9: case 0x00FA: case 0x00FB: case 0x00FC: return 'u';
        case 0x00FD: case 0x00FF: return 'y';
        case 0x00FE: return 't';
        default: return codePoint;
    }
}

static std::vector<Result> suggest(Dictionary *dictionary, ProximityInfo *proximity,
        DicTraverseSession *session, JNIEnv *env, const std::unordered_map<int, Key> &byCode,
        const std::string &input, const std::vector<std::string> &previousWords = {}) {
    std::vector<int> xs, ys, times, pointerIds, codePoints;
    const auto inputCodePoints = utf8CodePoints(input);
    // LatinIME searches typed letters shorter than MAX_WORD_LENGTH only; the keyboard's engine
    // offers no candidates for longer ones, and neither does this.
    if (inputCodePoints.size() >= MAX_WORD_LENGTH) return {};
    for (int i = 0; i < static_cast<int>(inputCodePoints.size()); ++i) {
        // A code point no key types is tapped at the origin, as the keyboard's engine does.
        const auto found = byCode.find(physicalBaseKey(inputCodePoints[i], byCode));
        const Key key = found != byCode.end() ? found->second : Key{inputCodePoints[i], 0, 0, 0, 0};
        xs.push_back(key.x + key.w / 2); ys.push_back(key.y + key.h / 2);
        times.push_back(i * 100); pointerIds.push_back(0); codePoints.push_back(inputCodePoints[i]);
    }
    int previous[MAX_PREV_WORD_COUNT_FOR_N_GRAM][MAX_WORD_LENGTH] = {};
    int previousLengths[MAX_PREV_WORD_COUNT_FOR_N_GRAM] = {};
    bool beginnings[MAX_PREV_WORD_COUNT_FOR_N_GRAM] = {};
    const int previousCount = std::min(static_cast<int>(previousWords.size()),
            MAX_PREV_WORD_COUNT_FOR_N_GRAM);
    for (int index = 0; index < previousCount; ++index) {
        const auto points = utf8CodePoints(previousWords[index]);
        previousLengths[index] = std::min(static_cast<int>(points.size()), MAX_WORD_LENGTH - 1);
        std::copy_n(points.begin(), previousLengths[index], previous[index]);
    }
    NgramContext context(previous, previousLengths, beginnings, previousCount);
    const int rawOptions[] = {0, 1, 0, 0, 1000};
    SuggestOptions options(rawOptions, 5);
    SuggestionResults nativeResults(8);
    if (codePoints.empty()) {
        dictionary->getPredictions(&context, &nativeResults);
    } else {
        dictionary->getSuggestions(proximity, session, xs.data(), ys.data(), times.data(),
                pointerIds.data(), codePoints.data(), static_cast<int>(codePoints.size()), &context,
                &options, -1.0f, &nativeResults);
    }

    JniArray count; count.ints.resize(1);
    JniArray outputCodePoints; outputCodePoints.ints.resize(8 * MAX_WORD_LENGTH);
    JniArray scores; scores.ints.resize(8);
    JniArray spaces; spaces.ints.resize(8);
    JniArray types; types.ints.resize(8);
    JniArray confidence; confidence.ints.resize(8);
    JniArray weight; weight.floats.resize(1);
    nativeResults.outputSuggestions(env, &count, &outputCodePoints, &scores, &spaces, &types,
            &confidence, &weight);
    std::vector<Result> results;
    for (int i = 0; i < count.ints[0]; ++i) {
        std::string word;
        for (int j = 0; j < MAX_WORD_LENGTH; ++j) {
            const int cp = outputCodePoints.ints[i * MAX_WORD_LENGTH + j];
            if (cp == 0) break;
            appendUtf8(cp, &word);
        }
        results.push_back({word, scores.ints[i], types.ints[i]});
    }
    std::sort(results.begin(), results.end(), [](const auto &a, const auto &b) {
        return a.score > b.score || (a.score == b.score && a.word.size() < b.word.size());
    });
    return results;
}

static int usage() {
    std::cerr << "usage: latinime_suggestions DICTIONARY_DIRECTORY [--shared-session] "
                 "--row LETTERS OFFSET [--row LETTERS OFFSET]... < QUERIES\n";
    return 2;
}

int main(int argc, char **argv) {
    if (argc < 2) return usage();
    bool sharesSession = false;
    std::vector<LetterRow> rows;
    for (int index = 2; index < argc; ++index) {
        if (std::strcmp(argv[index], "--shared-session") == 0) {
            sharesSession = true;
        } else if (std::strcmp(argv[index], "--row") == 0 && index + 2 < argc) {
            char *end = nullptr;
            const double offset = std::strtod(argv[index + 2], &end);
            if (end == argv[index + 2] || *end != '\0') return usage();
            rows.push_back({utf8CodePoints(argv[index + 1]), offset});
            index += 2;
        } else {
            return usage();
        }
    }
    if (rows.empty()) return usage();
    struct stat info {};
    if (stat(argv[1], &info) != 0) return 3;
    auto policy = DictionaryStructureWithBufferPolicyFactory::newPolicyForExistingDictFile(
            argv[1], 0, static_cast<int>(info.st_size), false);
    if (!policy) return 4;
    JNIEnv env;
    Dictionary dictionary(&env, std::move(policy));
    const auto keyboard = letterKeyboard(rows);
    auto proximity = makeProximityInfo(&env, keyboard);
    std::unordered_map<int, Key> byCode;
    for (const auto &key : keyboard.keys) byCode[key.code] = key;
    std::unique_ptr<DicTraverseSession> sharedSession;
    if (sharesSession) sharedSession = std::make_unique<DicTraverseSession>(&env, nullptr, true);
    std::string line;
    long index = 0;
    while (std::getline(std::cin, line)) {
        std::vector<std::string> fields;
        std::stringstream stream(line);
        std::string field;
        while (std::getline(stream, field, '\t')) fields.push_back(field);
        if (fields.empty()) continue;
        std::vector<std::string> previous;
        for (size_t position = 1; position < fields.size() && position <= 3; ++position) {
            if (!fields[position].empty()) previous.push_back(fields[position]);
        }
        std::unique_ptr<DicTraverseSession> ownSession;
        if (!sharedSession) ownSession = std::make_unique<DicTraverseSession>(&env, nullptr, true);
        DicTraverseSession *session = sharedSession ? sharedSession.get() : ownSession.get();
        const auto results = suggest(&dictionary, &proximity, session, &env, byCode,
                fields[0], previous);
        std::cout << index++;
        for (const auto &result : results) {
            std::cout << "\t" << result.word << "\t" << result.score << "\t" << result.type;
        }
        std::cout << "\n";
    }
    return 0;
}
