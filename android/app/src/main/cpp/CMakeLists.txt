cmake_minimum_required(VERSION 3.22.1)
project(kasir_pin_kdf LANGUAGES C)
set(KDF_VENDOR ${CMAKE_CURRENT_SOURCE_DIR}/third_party/mbedtls)
add_library(kasir_pin_kdf SHARED pin_kdf.c
    ${KDF_VENDOR}/library/md.c
    ${KDF_VENDOR}/library/sha256.c
    ${KDF_VENDOR}/library/pkcs5.c
    ${KDF_VENDOR}/library/platform_util.c)
target_include_directories(kasir_pin_kdf PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR} ${KDF_VENDOR}/include ${KDF_VENDOR}/library)
target_compile_definitions(kasir_pin_kdf PRIVATE
    MBEDTLS_CONFIG_FILE="pin_crypto_config.h")
# This CPU-bound primitive must also be optimized in debug. No -march=native,
# fast-math or private Android crypto libraries. Gradle aligns the native build
# ABIs with the requested Flutter targets, retaining every default ABI.
target_compile_options(kasir_pin_kdf PRIVATE -O2 -fvisibility=hidden
    -Wall -Wextra -Werror=implicit-function-declaration)
target_link_options(kasir_pin_kdf PRIVATE -Wl,-z,max-page-size=16384)
