/* Deliberately no TLS, network, RNG, cipher, RSA or PSA backend. The app's
 * existing secure random salt and fixed PBKDF2 policy remain in PinHasher. */
#define MBEDTLS_MD_C
#define MBEDTLS_SHA256_C
#define MBEDTLS_PKCS5_C
