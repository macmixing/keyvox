// Writes a LatinIME version 403 dictionary directory from a word list and an n-gram list.
//
// usage: write_latinime_dictionary UNIGRAMS NGRAMS OUTPUT_DIRECTORY
//   UNIGRAMS: word<TAB>probability (0-255), one per line
//   NGRAMS:   word<TAB>probability<TAB>previous word[<TAB>older word]

#include <algorithm>
#include <fstream>
#include <iostream>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

#include "dictionary/header/header_read_write_utils.h"
#include "dictionary/interface/dictionary_header_structure_policy.h"
#include "dictionary/property/historical_info.h"
#include "dictionary/property/ngram_context.h"
#include "dictionary/property/ngram_property.h"
#include "dictionary/property/unigram_property.h"
#include "dictionary/structure/dictionary_structure_with_buffer_policy_factory.h"
#include "suggest/core/dictionary/dictionary.h"
#include "utils/int_array_view.h"

using namespace latinime;

static bool compactAndReopen(JNIEnv *env, const char *outputDirectory,
        std::unique_ptr<Dictionary> *dictionary) {
    if (!(*dictionary)->flushWithGC(outputDirectory)) return false;
    auto policy = DictionaryStructureWithBufferPolicyFactory::newPolicyForExistingDictFile(
            outputDirectory, 0, 0, true);
    if (!policy) return false;
    dictionary->reset(new Dictionary(env, std::move(policy)));
    return true;
}

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

static std::vector<std::string> splitTabs(const std::string &line) {
    std::vector<std::string> fields;
    std::stringstream stream(line);
    std::string field;
    while (std::getline(stream, field, '\t')) fields.push_back(field);
    return fields;
}

int main(int argc, char **argv) {
    if (argc != 4) {
        std::cerr << "usage: write_latinime_dictionary UNIGRAMS NGRAMS OUTPUT_DIRECTORY\n";
        return 2;
    }

    DictionaryHeaderStructurePolicy::AttributeMap attributes;
    HeaderReadWriteUtils::setIntAttribute(&attributes, "MAX_UNIGRAM_ENTRY_COUNT", 150000);
    HeaderReadWriteUtils::setIntAttribute(&attributes, "MAX_BIGRAM_ENTRY_COUNT", 200000);
    HeaderReadWriteUtils::setIntAttribute(&attributes, "MAX_TRIGRAM_ENTRY_COUNT", 100000);
    HeaderReadWriteUtils::setIntAttribute(&attributes, "MAX_QUADGRAM_ENTRY_COUNT", 1000);
    HeaderReadWriteUtils::setBoolAttribute(&attributes, "USES_FORGETTING_CURVE", false);
    const std::vector<int> locale = {'e', 'n', '_', 'U', 'S'};
    auto policy = DictionaryStructureWithBufferPolicyFactory::newPolicyForOnMemoryDict(
            403, locale, &attributes);
    if (!policy) return 3;
    JNIEnv env;
    std::unique_ptr<Dictionary> dictionary(new Dictionary(&env, std::move(policy)));

    std::ifstream unigramInput(argv[1]);
    std::string line;
    int unigramCount = 0;
    int unigramFailures = 0;
    while (std::getline(unigramInput, line)) {
        const auto fields = splitTabs(line);
        if (fields.size() != 2) continue;
        auto codePoints = utf8CodePoints(fields[0]);
        if (codePoints.empty() || codePoints.size() >= MAX_WORD_LENGTH) continue;
        const int probability = std::stoi(fields[1]);
        const UnigramProperty property(false, false, false, false, probability, HistoricalInfo());
        if (!dictionary->addUnigramEntry(CodePointArrayView(codePoints), &property)) {
            ++unigramFailures;
        } else {
            ++unigramCount;
        }
        if (unigramCount > 0 && unigramCount % 5000 == 0) {
            std::cerr << "unigram_progress=" << unigramCount << " failures="
                      << unigramFailures << "\n";
        }
        if (dictionary->needsToRunGC(true)) {
            std::cerr << "unigram_gc_at=" << unigramCount << "\n";
            if (!compactAndReopen(&env, argv[3], &dictionary)) return 4;
            std::cerr << "unigram_gc_complete=" << unigramCount << "\n";
        }
    }
    if (!compactAndReopen(&env, argv[3], &dictionary)) return 5;

    std::ifstream ngramInput(argv[2]);
    int ngramCount = 0;
    int ngramFailures = 0;
    while (std::getline(ngramInput, line)) {
        const auto fields = splitTabs(line);
        if (fields.size() < 3 || fields.size() > 5) continue;
        auto target = utf8CodePoints(fields[0]);
        const int probability = std::stoi(fields[1]);
        const size_t previousCount = fields.size() - 2;
        int previous[MAX_PREV_WORD_COUNT_FOR_N_GRAM][MAX_WORD_LENGTH] = {};
        int previousLengths[MAX_PREV_WORD_COUNT_FOR_N_GRAM] = {};
        bool beginnings[MAX_PREV_WORD_COUNT_FOR_N_GRAM] = {};
        bool valid = !target.empty() && target.size() < MAX_WORD_LENGTH;
        for (size_t index = 0; index < previousCount && valid; ++index) {
            const auto codePoints = utf8CodePoints(fields[index + 2]);
            if (codePoints.empty() || codePoints.size() >= MAX_WORD_LENGTH) {
                valid = false;
                break;
            }
            previousLengths[index] = static_cast<int>(codePoints.size());
            std::copy(codePoints.begin(), codePoints.end(), previous[index]);
        }
        if (!valid) continue;
        const NgramContext context(previous, previousLengths, beginnings, previousCount);
        const NgramProperty property(context, std::move(target), probability, HistoricalInfo());
        if (!dictionary->addNgramEntry(&property)) {
            ++ngramFailures;
        } else {
            ++ngramCount;
        }
        if (ngramCount > 0 && ngramCount % 5000 == 0) {
            std::cerr << "ngram_progress=" << ngramCount << " failures="
                      << ngramFailures << "\n";
        }
        if (dictionary->needsToRunGC(true)) {
            std::cerr << "ngram_gc_at=" << ngramCount << "\n";
            if (!compactAndReopen(&env, argv[3], &dictionary)) return 6;
            std::cerr << "ngram_gc_complete=" << ngramCount << "\n";
        }
    }
    if (!dictionary->flushWithGC(argv[3])) return 7;

    std::cout << "unigrams=" << unigramCount << " unigram_failures=" << unigramFailures
              << " ngrams=" << ngramCount << " ngram_failures=" << ngramFailures << "\n";
    return unigramFailures || ngramFailures ? 8 : 0;
}
