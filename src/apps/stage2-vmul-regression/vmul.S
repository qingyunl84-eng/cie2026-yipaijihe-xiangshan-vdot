.text
.option push
.option arch, +v
.balign 4
.globl run_vmul
.type run_vmul, @function

# a0、a1 为两个输入数组地址，a2 为输出地址，各至少 16 字节。
# 返回值 a0 为本次执行的 vl。
run_vmul:
  li t0, 0x600
  csrs mstatus, t0
  csrw vstart, zero

  # 普通逐元素乘法，使用整个向量寄存器，不做点积求和。
  vsetivli t0, 16, e8, m1, tu, mu
  vle8.v v1, (a0)
  vle8.v v2, (a1)
  vmv.v.i v3, -1

.globl stage2_vmul_insn
stage2_vmul_insn:
  vmul.vv v3, v1, v2
  vse8.v v3, (a2)

  mv a0, t0
  ret
.size run_vmul, .-run_vmul
.option pop