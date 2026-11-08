#!/bin/bash
# 03　四轮 RTL/NEMU 协同仿真（difftest）
#
# 前置：已完成 01、02，$NOOP_HOME/build/emu 与 NEMU 参考模型都存在
# 用法：bash scripts/03-run-cosim.sh
# 耗时：约 4~6 分钟

set -u

HERE=$(cd "$(dirname "$0")/.." && pwd)
: "${AM_HOME:?请先 export AM_HOME}"
: "${NOOP_HOME:?请先 export NOOP_HOME}"
: "${NEMU_HOME:?请先 export NEMU_HOME}"

REF="$NEMU_HOME/build/riscv64-nemu-interpreter-so"
WORK=/tmp/cie2026-cosim
mkdir -p "$WORK"

echo "把测试程序放进 nexus-am……"
cp -r "$HERE/src/apps/." "$AM_HOME/apps/"

echo "编译四个测试程序……"
for app in stage2-vdot-positive stage2-vdot-boundary stage3-vdot-baseline stage3-vdot-perf; do
  make -C "$AM_HOME/apps/$app" ARCH=riscv64-xs CROSS_COMPILE=riscv64-linux-gnu- >/dev/null || exit 1
done

stage() {  # $1=app 目录名  $2=规范文件名
  local src
  src=$(ls "$AM_HOME/apps/$1"/build/*.bin 2>/dev/null | head -1)
  [ -z "$src" ] && { echo ""; return; }
  cp "$src" "$WORK/$2"
  echo "$WORK/$2"
}

P=$(stage stage2-vdot-positive  cosim-vdot-positive.bin)
B=$(stage stage2-vdot-boundary  cosim-vdot-boundary.bin)
L=$(stage stage3-vdot-baseline  cosim-baseline.bin)
F=$(stage stage3-vdot-perf      cosim-consistency.bin)

run() {  # $1=标题  $2=镜像
  echo
  echo "================================================================"
  echo "  RTL 协同仿真测试    $1"
  echo "================================================================"
  [ -z "$2" ] && { echo "  二进制不存在，已跳过"; return; }
  cd "$NOOP_HOME" || return
  ./build/emu -i "$2" --diff="$REF" 2>&1 \
    | grep -aE "Difftest enabled|^dot result|^case |^PASS|^FAIL|HIT GOOD TRAP|Core-0 instrCnt" \
    | sed -E -e $'s/\x1b\\[[0-9;]*[A-Za-z]//g' \
             -e 's/^\[PERF \]\[time=[^]]*\] SimTop\.[^:]*: //'
}

echo "开始，四轮合计约 4~6 分钟，中途无输出属正常。"
echo "参考模型：$REF"

run "第一轮   vdot 正例（1 个用例）"     "$P"
run "第二轮   vdot 边界（8 个用例）"     "$B"
run "第三轮   基线组合（5 个用例）"      "$L"
run "第四轮   双实现一致性（1 个用例）"  "$F"

echo
echo "================================================================"
echo "  四轮结束"
echo "================================================================"
