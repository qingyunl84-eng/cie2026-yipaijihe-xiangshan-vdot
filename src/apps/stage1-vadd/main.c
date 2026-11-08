#include <am.h>
#include <klib.h>
#include <stdint.h>

extern unsigned long run_vadd(const uint32_t *a, const uint32_t *b,
                              uint32_t *c);

static uint32_t a[4] __attribute__((aligned(16))) = {1, 2, 3, 4};
static uint32_t b[4] __attribute__((aligned(16))) = {10, 20, 30, 40};
static uint32_t c[4] __attribute__((aligned(16))) = {0, 0, 0, 0};
static const uint32_t expected[4] = {11, 22, 33, 44};

int main(const char *args) {
  (void)args;
  printf("stage1 vadd test start\n");

  unsigned long vl = run_vadd(a, b, c);
  printf("actual vl = %d\n", (int)vl);

  if (vl != 4) {
    printf("FAIL: expected vl = 4\n");
    return 1;
  }

  for (int i = 0; i < 4; i++) {
    printf("element %d: %d + %d = %d, expected %d\n",
           i, (int)a[i], (int)b[i], (int)c[i], (int)expected[i]);

    if (c[i] != expected[i]) {
      printf("FAIL: result mismatch\n");
      return 1;
    }
  }

  printf("PASS: vadd.vv\n");
  return 0;
}
