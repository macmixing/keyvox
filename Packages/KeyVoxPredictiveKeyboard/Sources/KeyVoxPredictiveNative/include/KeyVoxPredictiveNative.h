#ifndef KEYVOX_PREDICTIVE_NATIVE_H
#define KEYVOX_PREDICTIVE_NATIVE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

enum {
    KVPK_MAX_SUGGESTIONS = 8,
    KVPK_MAX_WORD_BYTES = 128,
};

typedef enum KVPKPredictionMode {
    KVPKPredictionModeCorrection = 0,
    KVPKPredictionModeCompletion = 1,
    KVPKPredictionModeNextWord = 2,
} KVPKPredictionMode;

typedef struct KVPKKeyGeometry {
    int32_t codePoint;
    int32_t x;
    int32_t y;
    int32_t width;
    int32_t height;
} KVPKKeyGeometry;

typedef struct KVPKSuggestion {
    char word[KVPK_MAX_WORD_BYTES];
    int32_t nativeScore;
    int32_t nativeType;
    double rankProbability;
} KVPKSuggestion;

typedef struct KVPKPredictionResult {
    int32_t count;
    KVPKSuggestion suggestions[KVPK_MAX_SUGGESTIONS];
    double automaticCorrectionProbability;
    bool typedWordIsValid;
} KVPKPredictionResult;

typedef struct KVPKWordAnalysis {
    bool wordIsValid;
    double unigramLogProbability;
    double precedingLogProbability;
    bool precedingPairObserved;
    double precedingTrigramLogProbability;
    bool precedingTrigramObserved;
} KVPKWordAnalysis;

typedef void *KVPKEngineRef;

const char *KVPKEngineLastError(void);

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
);

void KVPKEngineDestroy(KVPKEngineRef engine);

bool KVPKEngineUpdateGeometry(
    KVPKEngineRef engine,
    const KVPKKeyGeometry *keys,
    int32_t keyCount,
    int32_t keyboardWidth,
    int32_t keyboardHeight
);

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
);

bool KVPKEngineAnalyzeWord(
    KVPKEngineRef engine,
    const char *word,
    const char *previousWord,
    const char *olderWord,
    KVPKWordAnalysis *result
);

#ifdef __cplusplus
}
#endif

#endif
