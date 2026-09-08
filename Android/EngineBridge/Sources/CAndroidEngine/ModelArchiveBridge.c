#include "EngineBridge.h"
#include <jni.h>

static JavaVM *archive_vm;
static jclass archive_class;
static jmethodID extract_method;

int keyvox_archive_bridge_initialize(JNIEnv *env, JavaVM *vm, jclass type) {
    if (archive_class) return 1;
    jmethodID method = (*env)->GetStaticMethodID(env, type, "extractModelMember",
        "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;J)Z");
    if (!method) return 0;
    jclass owner = (*env)->NewGlobalRef(env, type);
    if (!owner) return 0;
    extract_method = method;
    archive_vm = vm;
    archive_class = owner;
    return 1;
}

int keyvox_extract_model_member(const char *archive, const char *member, const char *destination, int64_t size) {
    if (!archive_class || !archive || !member || !destination) return 0;
    JNIEnv *env = 0;
    int attached = 0;
    jint status = (*archive_vm)->GetEnv(archive_vm, (void **)&env, JNI_VERSION_1_6);
    if (status == JNI_EDETACHED) {
        if ((*archive_vm)->AttachCurrentThread(archive_vm, &env, 0) != JNI_OK) return 0;
        attached = 1;
    } else if (status != JNI_OK) return 0;
    jstring a = (*env)->NewStringUTF(env, archive);
    jstring m = a ? (*env)->NewStringUTF(env, member) : 0;
    jstring d = m ? (*env)->NewStringUTF(env, destination) : 0;
    int result = 0;
    if (a && m && d && !(*env)->ExceptionCheck(env))
        result = (*env)->CallStaticBooleanMethod(env, archive_class, extract_method, a, m, d, (jlong)size);
    if ((*env)->ExceptionCheck(env)) { (*env)->ExceptionClear(env); result = 0; }
    if (a) (*env)->DeleteLocalRef(env, a);
    if (m) (*env)->DeleteLocalRef(env, m);
    if (d) (*env)->DeleteLocalRef(env, d);
    if (attached) (*archive_vm)->DetachCurrentThread(archive_vm);
    return result;
}
