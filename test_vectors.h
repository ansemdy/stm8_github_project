/*
 * STM8 Algorithm Library - Test Vectors
 * Author: 臧德运 (Zang Deyun)
 * License: MIT
 */

#ifndef TEST_VECTORS_H
#define TEST_VECTORS_H

#include <stdint.h>

/* CRC-16 Test Vectors */
typedef struct {
    const uint8_t *data;
    uint16_t len;
    uint16_t expected_crc;
    const char *description;
} crc_test_vector_t;

/* Modbus CRC-16 test vectors */
static const uint8_t modbus_data_1[] = {0x01};
static const uint8_t modbus_data_2[] = {0x01, 0x03};
static const uint8_t modbus_data_3[] = {0x01, 0x03, 0x00, 0x00, 0x00, 0x0A};

static const crc_test_vector_t modbus_crc_tests[] = {
    {modbus_data_1, sizeof(modbus_data_1), 0x807E, "Single byte"},
    {modbus_data_2, sizeof(modbus_data_2), 0x0979, "Two bytes"},
    {modbus_data_3, sizeof(modbus_data_3), 0x????, "Modbus read request"},
};

/* CRC-16-CCITT test vectors */
static const uint8_t ccitt_data_1[] = {0x31, 0x32, 0x33};  /* "123" */
static const uint8_t ccitt_data_2[] = {0x41, 0x42, 0x43, 0x44, 0x45};  /* "ABCDE" */

static const crc_test_vector_t ccitt_crc_tests[] = {
    {ccitt_data_1, sizeof(ccitt_data_1), 0x????, "String '123'"},
    {ccitt_data_2, sizeof(ccitt_data_2), 0x????, "String 'ABCDE'"},
};

/* Base64 Test Vectors */
typedef struct {
    const uint8_t *input;
    uint16_t in_len;
    const char *expected_output;
    const char *description;
} base64_test_vector_t;

static const uint8_t b64_input_1[] = {0x00};
static const uint8_t b64_input_2[] = {0x48, 0x65, 0x6C, 0x6C, 0x6F};  /* "Hello" */

static const base64_test_vector_t base64_tests[] = {
    {b64_input_1, sizeof(b64_input_1), "AA==", "Single zero byte"},
    {b64_input_2, sizeof(b64_input_2), "SGVsbG8=", "String 'Hello'"},
};

#define NUM_MODBUS_TESTS (sizeof(modbus_crc_tests) / sizeof(modbus_crc_tests[0]))
#define NUM_CCITT_TESTS (sizeof(ccitt_crc_tests) / sizeof(ccitt_crc_tests[0]))
#define NUM_BASE64_TESTS (sizeof(base64_tests) / sizeof(base64_tests[0]))

#endif /* TEST_VECTORS_H */
