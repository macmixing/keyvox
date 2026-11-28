#include "KeyVoxPredictiveNative.h"

#include <climits>
#include <memory>
#include <sys/stat.h>

#include "latinime/dictionary/structure/dictionary_structure_with_buffer_policy_factory.h"
#include "latinime/suggest/core/dictionary/dictionary.h"
#include "latinime/utils/int_array_view.h"

using namespace latinime;

namespace {

/// A bundled dictionary opened alone, answering which words it has the way the engine's
/// `wordIsValid` does.
class DictionaryLookup {
public:
    explicit DictionaryLookup(DictionaryStructureWithBufferPolicy::StructurePolicyPtr policy)
        : dictionary_(&environment_, std::move(policy)) {}

    bool hasWord(const int32_t *codePoints, int32_t count) const {
        if (!codePoints || count <= 0 || count >= MAX_WORD_LENGTH) return false;
        return dictionary_.getProbability(CodePointArrayView(codePoints, count)) >= 0;
    }

private:
    JNIEnv environment_;
    Dictionary dictionary_;
};

}  // namespace

KVPKDictionaryRef KVPKDictionaryOpen(const char *dictionaryPath) {
    if (!dictionaryPath) return nullptr;
    struct stat status {};
    if (stat(dictionaryPath, &status) != 0 || status.st_size <= 0 || status.st_size > INT32_MAX) {
        return nullptr;
    }
    auto policy = DictionaryStructureWithBufferPolicyFactory::newPolicyForExistingDictFile(
        dictionaryPath, 0, static_cast<int>(status.st_size), false
    );
    if (!policy) return nullptr;
    try {
        return new DictionaryLookup(std::move(policy));
    } catch (...) {
        return nullptr;
    }
}

void KVPKDictionaryClose(KVPKDictionaryRef dictionary) {
    delete static_cast<DictionaryLookup *>(dictionary);
}

bool KVPKDictionaryHasWord(
    KVPKDictionaryRef dictionary,
    const int32_t *codePoints,
    int32_t codePointCount
) {
    if (!dictionary) return false;
    return static_cast<DictionaryLookup *>(dictionary)->hasWord(codePoints, codePointCount);
}
