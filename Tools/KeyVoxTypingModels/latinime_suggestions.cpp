// Prints LatinIME's suggestions for typed letters, as tapped at the center of each key of a
// QWERTY layout, after up to three previous words. Typed letters left empty ask for
// next-word predictions.
//
// usage: latinime_suggestions DICTIONARY_DIRECTORY < QUERIES
//   each query line: typed<TAB>previous word[<TAB>older word[<TAB>oldest word]]
//   each output line: query index, then word<TAB>score<TAB>type for each suggestion, best first
//
// Each query searches in a session of its own. A session continues its last search when the
// new typed letters start with the last ones, keeping that search's previous words, so a shared
// session would answer a query for the query asked before it.

#include <algorithm>
#include <cmath>
#include <iostream>
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

static std::vector<Key> qwertyKeys() {
    std::vector<Key> keys;
    const std::string rows[] = {"qwertyuiop", "asdfghjkl", "zxcvbnm"};
    const int offsets[] = {0, 50, 150};
    for (int row = 0; row < 3; ++row) {
        for (int col = 0; col < static_cast<int>(rows[row].size()); ++col) {
            keys.push_back({rows[row][col], offsets[row] + col * 100, row * 100, 100, 100});
        }
    }
    keys.push_back({' ', 250, 300, 500, 100});
    keys.push_back({'\'', 950, 100, 100, 100});
    return keys;
}

static JniArray intArray(const std::vector<int> &values) {
    JniArray array;
    array.ints.assign(values.begin(), values.end());
    return array;
}

static ProximityInfo makeProximityInfo(JNIEnv *env, const std::vector<Key> &keys) {
    constexpr int gridWidth = 10;
    constexpr int gridHeight = 4;
    constexpr int keyboardWidth = 1000;
    constexpr int keyboardHeight = 400;
    std::vector<int> proximity(gridWidth * gridHeight * MAX_PROXIMITY_CHARS_SIZE, 0);
    for (int gy = 0; gy < gridHeight; ++gy) {
        for (int gx = 0; gx < gridWidth; ++gx) {
            const int cx = gx * 100 + 50;
            const int cy = gy * 100 + 50;
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
    return ProximityInfo(env, keyboardWidth, keyboardHeight, gridWidth, gridHeight, 100, 100,
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

static int physicalBaseKey(int codePoint) {
    if (codePoint >= 'A' && codePoint <= 'Z') return codePoint + ('a' - 'A');
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
        DicTraverseSession *session, JNIEnv *env, const std::vector<Key> &keys,
        const std::string &input, const std::vector<std::string> &previousWords = {}) {
    std::unordered_map<int, Key> byCode;
    for (const auto &key : keys) byCode[key.code] = key;
    std::vector<int> xs, ys, times, pointerIds, codePoints;
    const auto inputCodePoints = utf8CodePoints(input);
    for (int i = 0; i < static_cast<int>(inputCodePoints.size()); ++i) {
        const auto key = byCode.at(physicalBaseKey(inputCodePoints[i]));
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

int main(int argc, char **argv) {
    if (argc != 2) {
        std::cerr << "usage: latinime_suggestions DICTIONARY_DIRECTORY < QUERIES\n";
        return 2;
    }
    struct stat info {};
    if (stat(argv[1], &info) != 0) return 3;
    auto policy = DictionaryStructureWithBufferPolicyFactory::newPolicyForExistingDictFile(
            argv[1], 0, static_cast<int>(info.st_size), false);
    if (!policy) return 4;
    JNIEnv env;
    Dictionary dictionary(&env, std::move(policy));
    auto keys = qwertyKeys();
    auto proximity = makeProximityInfo(&env, keys);
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
        DicTraverseSession session(&env, nullptr, true);
        const auto results = suggest(&dictionary, &proximity, &session, &env, keys,
                fields[0], previous);
        std::cout << index++;
        for (const auto &result : results) {
            std::cout << "\t" << result.word << "\t" << result.score << "\t" << result.type;
        }
        std::cout << "\n";
    }
    return 0;
}
