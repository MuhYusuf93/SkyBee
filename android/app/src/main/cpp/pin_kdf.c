#include <jni.h>
#include <stdint.h>
#include <stdlib.h>
#include "mbedtls/pkcs5.h"
#include "mbedtls/platform_util.h"

/* One JNI crossing for the complete vetted PBKDF2 routine, on Flutter's
 * background task queue. No custom crypto, stored format change or logging.
 * Validate again at the native boundary; errors return null, never a fake key.
 */
JNIEXPORT jbyteArray JNICALL
Java_com_example_kasir_1app_MainActivity_nativeDerive(
    JNIEnv *env, jobject activity, jbyteArray password, jbyteArray salt,
    jint rounds) {
    (void) activity;
    if (password == NULL || salt == NULL || rounds < 600000 || rounds > 2000000)
        return NULL;
    const jsize password_len = (*env)->GetArrayLength(env, password);
    const jsize salt_len = (*env)->GetArrayLength(env, salt);
    if (salt_len < 16) return NULL;
    /* Explicit copies avoid pinning the Java heap during the calculation. */
    unsigned char *password_copy = malloc((size_t) password_len + 1);
    if (password_copy == NULL) return NULL;
    unsigned char *salt_copy = malloc((size_t) salt_len);
    if (salt_copy == NULL) {
        free(password_copy);
        return NULL;
    }
    (*env)->GetByteArrayRegion(env, password, 0, password_len, (jbyte *) password_copy);
    (*env)->GetByteArrayRegion(env, salt, 0, salt_len, (jbyte *) salt_copy);
    if ((*env)->ExceptionCheck(env)) {
        mbedtls_platform_zeroize(password_copy, (size_t) password_len);
        free(password_copy);
        free(salt_copy);
        return NULL;
    }
    unsigned char output[32] = {0};
    const int status = mbedtls_pkcs5_pbkdf2_hmac_ext(MBEDTLS_MD_SHA256,
        (const unsigned char *) password_copy, (size_t) password_len,
        (const unsigned char *) salt_copy, (size_t) salt_len,
        (unsigned int) rounds, sizeof(output), output);
    mbedtls_platform_zeroize(password_copy, (size_t) password_len);
    free(password_copy);
    free(salt_copy);
    jbyteArray result = NULL;
    if (status == 0) {
        result = (*env)->NewByteArray(env, sizeof(output));
        if (result != NULL)
            (*env)->SetByteArrayRegion(env, result, 0, sizeof(output), (jbyte *) output);
    }
    mbedtls_platform_zeroize(output, sizeof(output));
    return result;
}
