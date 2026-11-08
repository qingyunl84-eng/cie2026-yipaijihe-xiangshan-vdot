#!/bin/bash
# 02　编译 NEMU 参考模型与香山 RTL 仿真器
#
# 说明：emu 是全流程里最耗时的一步，单核构建通常 30 分钟以上。
#       如果已有同一提交、同一配置的 build/emu，可以跳过。
# 用法：bash scripts/02-build-nemu-emu.sh

set -e

HERE=$(cd "$(dirname "$0")/.." && pwd)
: "${NOOP_HOME:?请先 export NOOP_HOME}"
: "${NEMU_HOME:?请先 export NEMU_HOME}"

echo "== 编译 NEMU 参考模型 =="
cp "$HERE/src/configs/nemu.config" "$NEMU_HOME/configs/vdot_defconfig"
make -C "$NEMU_HOME" vdot_defconfig
make -C "$NEMU_HOME" -j1
ls -lh "$NEMU_HOME/build/riscv64-nemu-interpreter-so"

echo
echo "== 编译香山 RTL 仿真器（耗时较长）=="
make -C "$NOOP_HOME" emu \
  CONFIG=MinimalConfig NUM_CORES=1 \
  JVM_XMX=4G EMU_TRACE=0 NO_DIFF=0 -j1
ls -lh "$NOOP_HOME/build/emu"
