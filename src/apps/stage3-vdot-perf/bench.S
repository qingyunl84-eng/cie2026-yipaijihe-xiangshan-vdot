.text
.option push
.option arch, +v

# 适用条件：RV64、VLEN=128、M 模式；输入和输出缓冲区均至少 16 字节。
# 返回值是两个 cycle 读数之差，不直接等于功能单元内部延迟。
# FENCE 约束访问顺序；向量算术的计时顺序仍需结合当前 RTL 或波形确认。

# 展开成每个测量函数相同的准备部分。
.macro BENCH_BEGIN name
.balign 64
.globl \name
.type \name, @function
\name:
  # a0: 输入 a 地址
  # a1: 输入 b 地址
  # a2: 输出缓冲区地址
  li t0, 0x600
  csrs mstatus, t0
  csrw vstart, zero

  # 准备完整的两个输入寄存器。
  vsetivli t0, 16, e8, m1, tu, mu
  vle8.v v1, (a0)
  vle8.v v2, (a1)

  # 旧目标全部填 1，两种实现从相同状态开始。
  vmv.v.i v3, -1

  # 设置开始计时边界，读取起始周期计数。
  fence iorw, iorw
  rdcycle t2
  fence iorw, iorw
.endm

# 展开成每个函数相同的结束部分。
.macro BENCH_END name
  # 设置结束计时边界，读取结束周期计数。
  fence iorw, iorw
  rdcycle t3
  fence iorw, iorw

  # 按程序顺序，结果保存位于结束计数之后。
  vsetivli t0, 16, e8, m1, tu, mu
  vse8.v v3, (a2)

  # 周期差通过 a0 返回，计算结果通过 out 缓冲区返回。
  sub a0, t3, t2
  ret
.size \name, .-\name
.endm


# 测量一：空计时框架。
BENCH_BEGIN bench_empty
BENCH_END bench_empty


# 测量二：自定义点积。
BENCH_BEGIN bench_vdot
  vsetivli t0, 8, e8, m1, tu, mu

  # 本项目的 OPMVV 编码：vdot.vv v3, v1, v2。
  .word 0x3a1121d7
BENCH_END bench_vdot


# 测量三：标准向量指令基线。
BENCH_BEGIN bench_baseline
  # 八对有符号 8 位输入，生成 16 位乘积。
  # 加宽乘法的目的寄存器组仍为 v4/v5；八个有效乘积全部位于 v4。
  vsetivli t0, 8, e8, m1, tu, mu
  vwmul.vv v4, v1, v2

  # VLEN=128 时，e16、m1 可容纳八个 16 位元素，足够读取全部乘积。
  vsetivli zero, 8, e16, m1, tu, mu

  # 此时 vl=8，清零操作覆盖 v3 的全部 128 位。
  # 低 32 位提供归约初值，高 96 位预置为最终输出的零。
  vmv.v.i v3, 0

  # 加宽归约生成 32 位结果；tu 保留 v3 中已清零的高 96 位。
  vwredsum.vs v3, v4, v3
BENCH_END bench_baseline

.option pop
