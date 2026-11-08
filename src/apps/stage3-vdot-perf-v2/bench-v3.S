# vdot 点积延迟测试
#
# 测法：天然 RAW 闭环。让指令读写同一个向量寄存器，相邻迭代自动形成依赖，
# 不需要额外的搬运指令。vdot 和 baseline 用同一套办法，两边对称。
#
# 顺序：
#   E1 E2        计时边界的地板
#   E3 E4        第一版的两个测量，用来复现 76 和 90
#   S1 S2        单发测量（数字不可用，用来说明为什么不能用单发）
#   L1 L2        延迟，主结果
#   D1 D2 D3     另一条路径复核，以及把 baseline 的链条拆开
#
# 约定：函数返回计时区间的周期数。循环版返回 256 轮总数，C 侧除以 LOOP_N。

.text
.option push
.option arch, +v

.equ LOOP_N, 256

# 每个函数共用的准备：打开向量、装数据、v3 填 -1。
# v3 填非零是为了万一实现漏写结果，能立刻看出来。
.macro PREAMBLE
  li       t0, 0x600
  csrs     mstatus, t0
  csrw     vstart, zero
  vsetivli zero, 16, e8, m1, tu, mu
  vle8.v   v1, (a0)
  vle8.v   v2, (a1)
  vmv.v.i  v3, -1
.endm

.macro T_BEGIN
  rdcycle  t2
.endm

.macro T_END
  rdcycle  t3
  sub      a0, t3, t2
.endm

# 旧版的边界，前后各夹一道 fence，只在 E2 里用。
.macro TF_BEGIN
  fence    iorw, iorw
  rdcycle  t2
  fence    iorw, iorw
.endm

.macro TF_END
  fence    iorw, iorw
  rdcycle  t3
  fence    iorw, iorw
  sub      a0, t3, t2
.endm


# ---------------------------------------------------------------- 边界成本

# 两次 rdcycle 紧挨着，中间什么也不做。计时的地板。
.balign 64
.globl bench_empty_csr
.type  bench_empty_csr, @function
bench_empty_csr:
  PREAMBLE
  T_BEGIN
  T_END
  ret
.size bench_empty_csr, .-bench_empty_csr

# 同上，但换成 fence 包夹。用来复现旧版 empty=59，看那 59 拍里都是什么。
.balign 64
.globl bench_empty_fence
.type  bench_empty_fence, @function
bench_empty_fence:
  PREAMBLE
  TF_BEGIN
  TF_END
  ret
.size bench_empty_fence, .-bench_empty_fence

# 第一版的两个测量：同样的 fence 包夹，中间分别放 vdot 和 baseline。
# 计时区内容与原始 bench.S 一致，用来复现 76 和 90。
.balign 64
.globl bench_fence_vdot
.type  bench_fence_vdot, @function
bench_fence_vdot:
  PREAMBLE
  TF_BEGIN
  vsetivli t0, 8, e8, m1, tu, mu
  .word    0x3a1121d7          # vdot.vv v3, v1, v2
  TF_END
  ret
.size bench_fence_vdot, .-bench_fence_vdot

.balign 64
.globl bench_fence_baseline
.type  bench_fence_baseline, @function
bench_fence_baseline:
  PREAMBLE
  TF_BEGIN
  vsetivli   t0, 8, e8, m1, tu, mu
  vwmul.vv   v4, v1, v2
  vsetivli   zero, 8, e16, m1, tu, mu
  vmv.v.i    v3, 0
  vwredsum.vs v3, v4, v3
  TF_END
  ret
.size bench_fence_baseline, .-bench_fence_baseline


# ---------------------------------------------------------------- 单发

# 一条标量搬运。S2 的对照，用来算出"多一条 vdot"应该多几拍。
.balign 64
.globl bench_single_mv
.type  bench_single_mv, @function
bench_single_mv:
  PREAMBLE
  T_BEGIN
  vsetivli t0, 8, e8, m1, tu, mu
  vmv.x.s  t4, v3
  T_END
  ret
.size bench_single_mv, .-bench_single_mv

# 比 S1 多一条 vdot。如果单发能测准，这个数应该更大。
.balign 64
.globl bench_single_vdot
.type  bench_single_vdot, @function
bench_single_vdot:
  PREAMBLE
  T_BEGIN
  vsetivli t0, 8, e8, m1, tu, mu
  .word    0x3a1121d7          # vdot.vv v3, v1, v2
  vmv.x.s  t4, v3
  T_END
  ret
.size bench_single_vdot, .-bench_single_vdot


# ---------------------------------------------------------------- 延迟

# vdot.vv v3, v3, v2。vs2 从 v1 改成 v3，读写同一个寄存器，
# 这一轮读的就是上一轮写的结果，环自然闭合。
# 输出是垃圾值（每轮把结果喂回去），不要拿来做功能校验。
.balign 64
.globl bench_lat_vdot
.type  bench_lat_vdot, @function
bench_lat_vdot:
  PREAMBLE
  vsetivli t0, 8, e8, m1, tu, mu
  li       t5, LOOP_N
  T_BEGIN
1:
  .word    0x3a3121d7          # vdot.vv v3, v3, v2
  addi     t5, t5, -1
  bnez     t5, 1b
  T_END
  ret
.size bench_lat_vdot, .-bench_lat_vdot

# baseline 也走天然 RAW：vwmul 读 v3，vwredsum 写 v3，环自动闭合。
# 和原始 baseline.S 的区别只有两处，都是为了让环闭合：
#   vwmul 的 vs2 从 v1 改成 v3；去掉 vmv.v.i 清零，让 v3 跨迭代累加。
# 清零点掉不影响关键路径，它本来就和 vwmul 并行。
.balign 64
.globl bench_lat_baseline
.type  bench_lat_baseline, @function
bench_lat_baseline:
  PREAMBLE
  li       t5, LOOP_N
  T_BEGIN
1:
  vsetivli   t0, 8, e8, m1, tu, mu
  vwmul.vv   v4, v3, v2
  vsetivli   zero, 8, e16, m1, tu, mu
  vwredsum.vs v3, v4, v3
  addi       t5, t5, -1
  bnez       t5, 1b
  T_END
  ret
.size bench_lat_baseline, .-bench_lat_baseline


# ---------------------------------------------------------------- 复核与拆分

# 纯搬运环，一进一出。量出 vmv.v.v 自己值多少拍，
# 后面 D2 里含一条，要扣掉。
.balign 64
.globl bench_lat_move
.type  bench_lat_move, @function
bench_lat_move:
  PREAMBLE
  vsetivli zero, 8, e8, m1, tu, mu
  li       t5, LOOP_N
  T_BEGIN
1:
  vmv.v.v    v1, v3
  vmv.v.v    v3, v1
  addi       t5, t5, -1
  bnez       t5, 1b
  T_END
  ret
.size bench_lat_move, .-bench_lat_move

# baseline 的另一种闭环：加一条 vmv.v.v 把结果搬回 v1。
# 和 L2 测的是同一件事，方法不同，用来互相印证。
# 这个版本保留了 vmv.v.i 清零，所以链条里多一个环节。
.balign 64
.globl bench_lat_baseline_mv
.type  bench_lat_baseline_mv, @function
bench_lat_baseline_mv:
  PREAMBLE
  li       t5, LOOP_N
  T_BEGIN
1:
  vsetivli   t0, 8, e8, m1, tu, mu
  vwmul.vv   v4, v1, v2
  vsetivli   zero, 8, e16, m1, tu, mu
  vmv.v.i    v3, 0
  vwredsum.vs v3, v4, v3
  vmv.v.v    v1, v3
  addi       t5, t5, -1
  bnez       t5, 1b
  T_END
  ret
.size bench_lat_baseline_mv, .-bench_lat_baseline_mv

# 把"切 e16 + 清零 + 归约"整段拿掉，直接从 v4 搬回 v1，环还是闭合的。
# 和 D2 一比，就知道那一段值多少拍。
.balign 64
.globl bench_lat_baseline_nored
.type  bench_lat_baseline_nored, @function
bench_lat_baseline_nored:
  PREAMBLE
  li       t5, LOOP_N
  T_BEGIN
1:
  vsetivli   t0, 8, e8, m1, tu, mu
  vwmul.vv   v4, v1, v2
  vmv.v.v    v1, v4
  addi       t5, t5, -1
  bnez       t5, 1b
  T_END
  ret
.size bench_lat_baseline_nored, .-bench_lat_baseline_nored

.option pop
