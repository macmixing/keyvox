#include "EngineBridge.h"
#include <jni.h>
#include <string.h>
#include <limits.h>

extern int keyvox_install_main_loop(void);
extern int keyvox_archive_bridge_initialize(JNIEnv *, JavaVM *, jclass);
static JavaVM *vm;
static jclass listener_class;
static jmethodID event_method;
static jmethodID dictionary_event_method;

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *value, void *reserved) {
    vm = value;
    return JNI_VERSION_1_6;
}

JNIEXPORT jboolean JNICALL Java_org_keyvox_android_engine_NativeEngine_initialize(
    JNIEnv *env, jclass type, jstring resources, jstring models, jstring dictionary, jstring runtime, jstring soc, jstring app_version) {
    if (!keyvox_install_main_loop()) return JNI_FALSE;
    if (!keyvox_archive_bridge_initialize(env, vm, type)) return JNI_FALSE;
    if (!listener_class) {
        listener_class = (*env)->NewGlobalRef(env, type);
        event_method = (*env)->GetStaticMethodID(env, type, "receive", "([B)V");
        dictionary_event_method = (*env)->GetStaticMethodID(env, type, "receiveDictionary", "([B)V");
        if (!listener_class || !event_method || !dictionary_event_method) return JNI_FALSE;
    }
    const char *r = (*env)->GetStringUTFChars(env, resources, 0);
    const char *m = r ? (*env)->GetStringUTFChars(env, models, 0) : 0;
    const char *d = m ? (*env)->GetStringUTFChars(env, dictionary, 0) : 0;
    const char *n = d ? (*env)->GetStringUTFChars(env, runtime, 0) : 0;
    const char *s = n ? (*env)->GetStringUTFChars(env, soc, 0) : 0;
    const char *v = s ? (*env)->GetStringUTFChars(env, app_version, 0) : 0;
    if (v) keyvox_engine_configure(r, m, d, n, s, v);
    if (r) (*env)->ReleaseStringUTFChars(env, resources, r);
    if (m) (*env)->ReleaseStringUTFChars(env, models, m);
    if (d) (*env)->ReleaseStringUTFChars(env, dictionary, d);
    if (n) (*env)->ReleaseStringUTFChars(env, runtime, n);
    if (s) (*env)->ReleaseStringUTFChars(env, soc, s);
    if (v) (*env)->ReleaseStringUTFChars(env, app_version, v);
    return v && !(*env)->ExceptionCheck(env);
}

JNIEXPORT void JNICALL Java_org_keyvox_android_engine_NativeEngine_transcribe(
    JNIEnv *env, jclass type, jstring path, jlong request) {
    const char *value = (*env)->GetStringUTFChars(env, path, 0);
    if (value) { keyvox_engine_transcribe(value, request); (*env)->ReleaseStringUTFChars(env, path, value); }
}
JNIEXPORT void JNICALL Java_org_keyvox_android_engine_NativeEngine_cancel(JNIEnv *env, jclass type) { keyvox_engine_cancel(); }
JNIEXPORT void JNICALL Java_org_keyvox_android_engine_NativeEngine_download(JNIEnv *env, jclass type) { keyvox_engine_download(); }
JNIEXPORT void JNICALL Java_org_keyvox_android_engine_NativeEngine_configurePromotions(
    JNIEnv *env, jclass type, jstring app_version, jboolean uses_bundled_manifest, jstring preview_campaign_id) {
    const char *version = (*env)->GetStringUTFChars(env, app_version, 0);
    const char *campaign = preview_campaign_id
        ? (*env)->GetStringUTFChars(env, preview_campaign_id, 0)
        : 0;
    if (version) keyvox_promotions_configure(version, uses_bundled_manifest == JNI_TRUE, campaign);
    if (version) (*env)->ReleaseStringUTFChars(env, app_version, version);
    if (campaign) (*env)->ReleaseStringUTFChars(env, preview_campaign_id, campaign);
}
JNIEXPORT void JNICALL Java_org_keyvox_android_engine_NativeEngine_refreshPromotions(JNIEnv *env, jclass type) { keyvox_promotions_refresh(); }

JNIEXPORT void JNICALL Java_org_keyvox_android_engine_NativeEngine_dictionaryList(
    JNIEnv *env, jclass type, jlong request) { keyvox_dictionary_list(request); }

JNIEXPORT void JNICALL Java_org_keyvox_android_engine_NativeEngine_dictionaryAddUTF8(
    JNIEnv *env, jclass type, jlong request, jbyteArray phrase) {
    if (!phrase) return;
    jsize length = (*env)->GetArrayLength(env, phrase);
    jbyte *bytes = (*env)->GetByteArrayElements(env, phrase, 0);
    if (bytes) keyvox_dictionary_add(request, (const uint8_t *) bytes, length);
    if (bytes) (*env)->ReleaseByteArrayElements(env, phrase, bytes, JNI_ABORT);
}

JNIEXPORT void JNICALL Java_org_keyvox_android_engine_NativeEngine_dictionaryUpdateUTF8(
    JNIEnv *env, jclass type, jlong request, jstring identifier, jbyteArray phrase) {
    if (!identifier || !phrase) return;
    const char *id = (*env)->GetStringUTFChars(env, identifier, 0);
    jsize length = (*env)->GetArrayLength(env, phrase);
    jbyte *bytes = (*env)->GetByteArrayElements(env, phrase, 0);
    if (id && bytes) keyvox_dictionary_update(request, id, (const uint8_t *) bytes, length);
    if (id) (*env)->ReleaseStringUTFChars(env, identifier, id);
    if (bytes) (*env)->ReleaseByteArrayElements(env, phrase, bytes, JNI_ABORT);
}

JNIEXPORT void JNICALL Java_org_keyvox_android_engine_NativeEngine_dictionaryDelete(
    JNIEnv *env, jclass type, jlong request, jstring identifier) {
    if (!identifier) return;
    const char *id = (*env)->GetStringUTFChars(env, identifier, 0);
    if (id) keyvox_dictionary_delete(request, id);
    if (id) (*env)->ReleaseStringUTFChars(env, identifier, id);
}

JNIEXPORT void JNICALL Java_org_keyvox_android_engine_NativeEngine_dictionaryClearWarnings(
    JNIEnv *env, jclass type, jlong request) { keyvox_dictionary_clear_warnings(request); }

JNIEXPORT jbyteArray JNICALL Java_org_keyvox_android_engine_NativeEngine_composeUTF8(
    JNIEnv *env, jclass type, jbyteArray transcript, jbyteArray preceding,
    jboolean preceding_truncated, jbyteArray following, jboolean following_truncated) {
    if (!transcript) return 0;
    jsize transcript_length = (*env)->GetArrayLength(env, transcript);
    jsize preceding_length = preceding ? (*env)->GetArrayLength(env, preceding) : 0;
    jsize following_length = following ? (*env)->GetArrayLength(env, following) : 0;
    jbyte *transcript_bytes = (*env)->GetByteArrayElements(env, transcript, 0);
    jbyte *preceding_bytes = preceding ? (*env)->GetByteArrayElements(env, preceding, 0) : 0;
    jbyte *following_bytes = following ? (*env)->GetByteArrayElements(env, following, 0) : 0;
    if (!transcript_bytes || (preceding && !preceding_bytes) || (following && !following_bytes)) {
        if (transcript_bytes) (*env)->ReleaseByteArrayElements(env, transcript, transcript_bytes, JNI_ABORT);
        if (preceding_bytes) (*env)->ReleaseByteArrayElements(env, preceding, preceding_bytes, JNI_ABORT);
        if (following_bytes) (*env)->ReleaseByteArrayElements(env, following, following_bytes, JNI_ABORT);
        return 0;
    }

    int32_t output_length = 0;
    uint8_t *output = keyvox_engine_compose(
        (const uint8_t *) transcript_bytes, transcript_length,
        (const uint8_t *) preceding_bytes, preceding_length, preceding_truncated == JNI_TRUE,
        (const uint8_t *) following_bytes, following_length, following_truncated == JNI_TRUE,
        &output_length);
    (*env)->ReleaseByteArrayElements(env, transcript, transcript_bytes, JNI_ABORT);
    if (preceding_bytes) (*env)->ReleaseByteArrayElements(env, preceding, preceding_bytes, JNI_ABORT);
    if (following_bytes) (*env)->ReleaseByteArrayElements(env, following, following_bytes, JNI_ABORT);
    if (!output || output_length < 0) {
        keyvox_engine_free_bytes(output);
        return 0;
    }

    jbyteArray result = (*env)->NewByteArray(env, output_length);
    if (result) (*env)->SetByteArrayRegion(env, result, 0, output_length, (const jbyte *) output);
    keyvox_engine_free_bytes(output);
    return (*env)->ExceptionCheck(env) ? 0 : result;
}

// Swift sends events on MainActor, which the Android main Looper now drains.
void keyvox_engine_event(const char *json) {
    JNIEnv *env = 0;
    if (!listener_class || (*vm)->GetEnv(vm, (void **) &env, JNI_VERSION_1_6) != JNI_OK) return;
    size_t length = strlen(json);
    if (length > INT_MAX) return;
    jbyteArray bytes = (*env)->NewByteArray(env, (jsize) length);
    if (!bytes) return;
    (*env)->SetByteArrayRegion(env, bytes, 0, (jsize) length, (const jbyte *) json);
    if (!(*env)->ExceptionCheck(env)) (*env)->CallStaticVoidMethod(env, listener_class, event_method, bytes);
    (*env)->DeleteLocalRef(env, bytes);
}

void keyvox_dictionary_event(const uint8_t *json, int32_t length) {
    JNIEnv *env = 0;
    if (!listener_class || !dictionary_event_method || length < 0
        || (*vm)->GetEnv(vm, (void **) &env, JNI_VERSION_1_6) != JNI_OK) return;
    jbyteArray bytes = (*env)->NewByteArray(env, length);
    if (!bytes) return;
    (*env)->SetByteArrayRegion(env, bytes, 0, length, (const jbyte *) json);
    if (!(*env)->ExceptionCheck(env)) {
        (*env)->CallStaticVoidMethod(env, listener_class, dictionary_event_method, bytes);
    }
    (*env)->DeleteLocalRef(env, bytes);
}
