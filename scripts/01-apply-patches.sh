#!/bin/bash
# 01　把三份补丁打到基线版本的源码上
#
# 前置：XiangShan / NEMU 处于 README 中记录的基线提交
# 用法：bash scripts/01-apply-patches.sh

set -e

HERE=$(cd "$(dirname "$0")/.." && pwd)
: "${NOOP_HOME:?请先 export NOOP_HOME}"
: "${NEMU_HOME:?请先 export NEMU_HOME}"

XS_PATCH="$HERE/src/patches/xiangshan-vdot.patch"
YS_PATCH="$HERE/src/patches/yunsuan-vdot.patch"
NEMU_PATCH="$HERE/src/patches/nemu-vdot.patch"

echo "检查补丁能否干净应用……"
git -C "$NOOP_HOME" apply --check "$XS_PATCH"
git -C "$NOOP_HOME/yunsuan" apply --check "$YS_PATCH"
git -C "$NEMU_HOME" apply --check "$NEMU_PATCH"

echo "应用补丁……"
git -C "$NOOP_HOME" apply "$XS_PATCH"
git -C "$NOOP_HOME/yunsuan" apply "$YS_PATCH"
git -C "$NEMU_HOME" apply "$NEMU_PATCH"

echo "完成。改动位置："
git -C "$NOOP_HOME" diff --stat
git -C "$NOOP_HOME/yunsuan" diff --stat
git -C "$NEMU_HOME" diff --stat
