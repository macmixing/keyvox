#include "EngineBridge.h"
#include <jni.h>
#include <string.h>
#include <limits.h>

extern int keyvox_install_main_loop(void);
static JavaVM *vm;
static jclass listener_class;
static jmethodID event_method;

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *value, void *reserved) {
    vm = value;
    return JNI_VERSION_1_6;
}

JNIEXPORT jboolean JNICALL Java_org_keyvox_android_engine_NativeEngine_initialize(
    JNIEnv *env, jclass type, jstring resources, jstring models, jstring dictionary) {
    if (!keyvox_install_main_loop()) return JNI_FALSE;
    if (!listener_class) {
        listener_class = (*env)->NewGlobalRef(env, type);
        event_method = (*env)->GetStaticMethodID(env, type, "receive", "([B)V");
        if (!listener_class || !event_method) return JNI_FALSE;
    }
    const char *r = (*env)->GetStringUTFChars(env, resources, 0);
    const char *m = (*env)->GetStringUTFChars(env, models, 0);
    const char *d = (*env)->GetStringUTFChars(env, dictionary, 0);
    if (r && m && d) keyvox_engine_configure(r, m, d);
    if (r) (*env)->ReleaseStringUTFChars(env, resources, r);
    if (m) (*env)->ReleaseStringUTFChars(env, models, m);
    if (d) (*env)->ReleaseStringUTFChars(env, dictionary, d);
    return !(*env)->ExceptionCheck(env);
}

JNIEXPORT void JNICALL Java_org_keyvox_android_engine_NativeEngine_transcribe(
    JNIEnv *env, jclass type, jstring path, jlong request) {
    const char *value = (*env)->GetStringUTFChars(env, path, 0);
    if (value) { keyvox_engine_transcribe(value, request); (*env)->ReleaseStringUTFChars(env, path, value); }
}
JNIEXPORT void JNICALL Java_org_keyvox_android_engine_NativeEngine_cancel(JNIEnv *env, jclass type) { keyvox_engine_cancel(); }
JNIEXPORT void JNICALL Java_org_keyvox_android_engine_NativeEngine_download(JNIEnv *env, jclass type) { keyvox_engine_download(); }

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
