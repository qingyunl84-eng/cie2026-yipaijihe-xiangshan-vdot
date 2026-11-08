#include <am.h>
#include <klib.h>
#include <stdint.h>

extern unsigned long run_vmul(const int8_t *a, const int8_t *b,
                              uint8_t *out);

static const int8_t a[16] __attribute__((aligned(16))) = {
  127, -128, 127, -128, 0, 1, -1, 2,
  -2, 3, -3, 4, -4, 64, -64, 8
};

static const int8_t b[16] __attribute__((aligned(16))) = {
  127, -128, -128, 127, -128, 127, 127, 100,
  100, -100, -100, 64, 64, 4, 4, -16
};

static uint8_t out[16] __attribute__((aligned(16)));

int main(const char *args) {
  (void)args;
  printf("stage2 vmul regression test start\n");

  for (int i = 0; i < 16; i++) out[i] = 0xa5;

  unsigned long vl = run_vmul(a, b, out);
  if (vl != 16) {
    printf("FAIL: actual vl = %d, expected 16\n", (int)vl);
    return 1;
  }

  for (int i = 0; i < 16; i++) {
    // 先计算完整有符号乘积，再转成 uint8_t，保留低八位。
    int32_t product = (int32_t)a[i] * (int32_t)b[i];
    uint8_t expected = (uint8_t)product;

    printf("element %d: product = %d, expected byte = %d, actual byte = %d\n",
           i, (int)product, (int)expected, (int)out[i]);

    if (out[i] != expected) {
      printf("FAIL: vmul element %d mismatch\n", i);
      return 1;
    }
  }

  printf("PASS: vmul.vv regression all elements\n");
  return 0;
}