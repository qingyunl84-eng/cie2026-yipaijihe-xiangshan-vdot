.text
.globl rvv_probe
rvv_probe:
  vsetivli t0, 4, e32, m1, ta, ma
  vadd.vv v3, v1, v2
  ret
