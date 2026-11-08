.text
.balign 4
.globl run_vadd
.type run_vadd, @function
run_vadd:
  li t0, 0x600
  csrs mstatus, t0
  csrw vstart, zero

  vsetivli t0, 4, e32, m1, ta, ma
  vle32.v v1, (a0)
  vle32.v v2, (a1)

.globl stage1_vadd_insn
stage1_vadd_insn:
  vadd.vv v3, v1, v2
  vse32.v v3, (a2)

  mv a0, t0
  ret
.size run_vadd, .-run_vadd
