#pragma once

#include <cstdint>
#include <cstring>
#include <vector>

using jint = int32_t;
using jsize = int32_t;
using jlong = int64_t;
using jfloat = float;
using jboolean = uint8_t;
using jobject = void *;
using jclass = void *;
using jstring = void *;

struct JniArray {
    std::vector<jint> ints;
    std::vector<jfloat> floats;
    std::vector<jboolean> bools;
};

using jarray = JniArray *;
using jintArray = JniArray *;
using jfloatArray = JniArray *;
using jbooleanArray = JniArray *;
using jobjectArray = JniArray *;
using jmethodID = void *;

struct JNIEnv {
    jsize GetArrayLength(jarray array) {
        if (!array->ints.empty()) return static_cast<jsize>(array->ints.size());
        if (!array->floats.empty()) return static_cast<jsize>(array->floats.size());
        return static_cast<jsize>(array->bools.size());
    }

    void GetFloatArrayRegion(jfloatArray array, jsize start, jsize count, jfloat *out) {
        std::memcpy(out, array->floats.data() + start, count * sizeof(jfloat));
    }

    void GetIntArrayRegion(jintArray array, jsize start, jsize count, jint *out) {
        std::memcpy(out, array->ints.data() + start, count * sizeof(jint));
    }

    void GetBooleanArrayRegion(jbooleanArray array, jsize start, jsize count, jboolean *out) {
        std::memcpy(out, array->bools.data() + start, count * sizeof(jboolean));
    }

    void SetFloatArrayRegion(jfloatArray array, jsize start, jsize count, const jfloat *in) {
        std::memcpy(array->floats.data() + start, in, count * sizeof(jfloat));
    }

    void SetIntArrayRegion(jintArray array, jsize start, jsize count, const jint *in) {
        std::memcpy(array->ints.data() + start, in, count * sizeof(jint));
    }

    void SetBooleanArrayRegion(jbooleanArray array, jsize start, jsize count, const jboolean *in) {
        std::memcpy(array->bools.data() + start, in, count * sizeof(jboolean));
    }

    jsize GetStringLength(jstring) { return 0; }
    jsize GetStringUTFLength(jstring) { return 0; }
    void GetStringUTFRegion(jstring, jsize, jsize, char *) {}
    jobject GetObjectArrayElement(jobjectArray, jsize) { return nullptr; }
    void SetObjectArrayElement(jobjectArray, jsize, jobject) {}
    void DeleteLocalRef(jobject) {}
    jclass FindClass(const char *) { return nullptr; }
    jmethodID GetMethodID(jclass, const char *, const char *) { return nullptr; }
    jmethodID GetStaticMethodID(jclass, const char *, const char *) { return nullptr; }
    jobject NewObject(jclass, jmethodID, ...) { return nullptr; }
    jobjectArray NewObjectArray(jsize, jclass, jobject) { return nullptr; }
    jintArray NewIntArray(jsize size) {
        auto *array = new JniArray;
        array->ints.resize(size);
        return array;
    }
    jbooleanArray NewBooleanArray(jsize size) {
        auto *array = new JniArray;
        array->bools.resize(size);
        return array;
    }
    jstring NewStringUTF(const char *) { return nullptr; }
    jboolean CallBooleanMethod(jobject, jmethodID, ...) { return 0; }
    jint CallStaticIntMethod(jclass, jmethodID, ...) { return 0; }
    void ExceptionClear() {}
};

#define JNI_TRUE 1
#define JNI_FALSE 0
