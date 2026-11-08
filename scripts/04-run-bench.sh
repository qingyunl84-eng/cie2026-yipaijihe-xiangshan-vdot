#!/bin/bash
# 04　延迟测量（基准组合 vs vdot 专用指令）
#
# 前置：已完成 01、02
# 用法：bash scripts/04-run-bench.sh
# 输出：legacy / boundary / single / latency / crosscheck 五组数据
#
# 注意：这里不加 --diff。闭环函数会覆写 v3，输出是垃圾值，
#       开启 difftest 会误报 mismatch。功能正确性由 03 的协同仿真保证。

set -u

HERE=$(cd "$(dirname "$0")/.." && pwd)
: "${AM_HOME:?请先 export AM_HOME}"
: "${NOOP_HOME:?请先 export NOOP_HOME}"

echo "把测量程序放进 nexus-am……"
cp -r "$HERE/src/apps/stage3-vdot-perf-v2" "$AM_HOME/apps/"

cd "$AM_HOME/apps/stage3-vdot-perf-v2" || exit 1
rm -rf build
make ARCH=riscv64-xs CROSS_COMPILE=riscv64-linux-gnu- || exit 1

cd "$NOOP_HOME" || exit 1
BIN=$(ls "$AM_HOME/apps/stage3-vdot-perf-v2"/build/*.bin | head -1)
echo "镜像：$BIN"
echo

# 必须过滤 [PERF]：香山退出时会打印几百行统计，把结果全埋掉
./build/emu -i "$BIN" 2>&1 | grep -av "^\[PERF"
