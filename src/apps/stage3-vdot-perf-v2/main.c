// vdot 延迟测试的主程序。
// 每项跑 SAMPLES 次取最小值：干扰只会让时间变长，最小值最接近真值。
// 循环版返回的是 256 轮总数，这里除以 LOOP_N 换算成每轮。

#include <am.h>
#include <klib.h>
#include <stdint.h>

#define LOOP_N   256
#define SAMPLES  4
#define WARMUP   1

typedef unsigned long (*fn_t)(const int8_t *, const int8_t *, uint8_t *);

extern unsigned long bench_empty_csr        (const int8_t *, const int8_t *, uint8_t *);
extern unsigned long bench_empty_fence      (const int8_t *, const int8_t *, uint8_t *);
extern unsigned long bench_fence_vdot       (const int8_t *, const int8_t *, uint8_t *);
extern unsigned long bench_fence_baseline   (const int8_t *, const int8_t *, uint8_t *);
extern unsigned long bench_single_mv        (const int8_t *, const int8_t *, uint8_t *);
extern unsigned long bench_single_vdot      (const int8_t *, const int8_t *, uint8_t *);
extern unsigned long bench_lat_vdot         (const int8_t *, const int8_t *, uint8_t *);
extern unsigned long bench_lat_baseline     (const int8_t *, const int8_t *, uint8_t *);
extern unsigned long bench_lat_move         (const int8_t *, const int8_t *, uint8_t *);
extern unsigned long bench_lat_baseline_mv  (const int8_t *, const int8_t *, uint8_t *);
extern unsigned long bench_lat_baseline_nored(const int8_t *, const int8_t *, uint8_t *);

enum { E1, E2, E3, E4,
       S1, S2,
       L1, L2,
       D1, D2, D3,
       N_ITEM };

static const fn_t fns[N_ITEM] = {
  bench_empty_csr, bench_empty_fence, bench_fence_vdot, bench_fence_baseline,
  bench_single_mv, bench_single_vdot,
  bench_lat_vdot, bench_lat_baseline,
  bench_lat_move, bench_lat_baseline_mv, bench_lat_baseline_nored,
};

// 前 8 个是真实数据，后 8 个是干扰，用来查实现会不会多算。
static const int8_t a[16] __attribute__((aligned(16))) = {
  1, 2, 3, 4, 5, 6, 7, 8,  127, 127, 127, 127, 127, 127, 127, 127
};
static const int8_t b[16] __attribute__((aligned(16))) = {
  9, 10, 11, 12, 13, 14, 15, 16,  127, 127, 127, 127, 127, 127, 127, 127
};
static uint8_t out[16] __attribute__((aligned(16)));

static unsigned long best[N_ITEM];

// 入参是放大 100 倍的值，打印成 x.xx
static void p100(const char *label, long v) {
  if (v < 0) {
    v = -v;
    printf("  %s-%d.%02d\n", label, (int)(v / 100), (int)(v % 100));
  } else {
    printf("  %s%d.%02d\n", label, (int)(v / 100), (int)(v % 100));
  }
}

static long per_iter(int i) {
  return (long)(best[i] * 100 / LOOP_N);
}

int main(const char *args) {
  (void)args;

  printf("stage3 vdot latency\n");
  printf("LOOP_N=%d  SAMPLES=%d\n\n", LOOP_N, SAMPLES);

  for (int i = 0; i < N_ITEM; i++) best[i] = ~0UL;

  for (int w = 0; w < WARMUP; w++)
    for (int i = 0; i < N_ITEM; i++) fns[i](a, b, out);

  for (int s = 0; s < SAMPLES; s++)
    for (int i = 0; i < N_ITEM; i++) {
      unsigned long c = fns[i](a, b, out);
      if (c < best[i]) best[i] = c;
    }

  printf("legacy\n");
  printf("  empty           %d\n", (int)best[E2]);
  printf("  vdot            %d\n", (int)best[E3]);
  printf("  baseline        %d\n", (int)best[E4]);
  p100("ratio_end       ", best[E3] ? (long)(best[E4] * 100 / best[E3]) : 0);
  printf("  vdot_net        %d\n", (int)(best[E3] - best[E2]));
  printf("  base_net        %d\n", (int)(best[E4] - best[E2]));
  {
    long vn = (long)(best[E3] - best[E2]);
    long bn = (long)(best[E4] - best[E2]);
    p100("ratio_net       ", vn ? (bn * 100 / vn) : 0);
  }
  printf("\n");

  printf("boundary\n");
  printf("  csr_only        %d\n", (int)best[E1]);
  printf("  fence           %d\n\n", (int)(best[E2] - best[E1]));

  printf("single\n");
  printf("  single_mv       %d\n", (int)best[S1]);
  printf("  single_vdot     %d\n", (int)best[S2]);
  printf("  delta           %d\n\n", (int)best[S2] - (int)best[S1]);

  {
    long v = per_iter(L1);
    long b = per_iter(L2);

    printf("latency\n");
    p100("vdot            ", v);
    p100("baseline        ", b);
    p100("speedup         ", v ? (b * 100 / v) : 0);
    printf("\n");

    printf("crosscheck\n");
    {
      long mv  = per_iter(D1) / 2;
      long bm  = per_iter(D2);
      long nr  = per_iter(D3);
      long net = bm - mv;
      long red = bm - nr;
      long mul = nr - mv;

      p100("move            ", mv);
      p100("baseline_mv     ", bm);
      p100("baseline_nored  ", nr);
      p100("baseline_net    ", net);
      p100("reduce          ", red);
      p100("multiply        ", mul);
    }
    printf("\n");
  }

  printf("done\n");
  return 0;
}
