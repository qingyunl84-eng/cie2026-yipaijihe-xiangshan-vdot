# 香山 vdot.vv 自定义点积指令

2026 CIE 全国 RISC-V 高水平创新及应用大赛 · 香山赛道
**团队：一拍即合**

在香山昆明湖 V2 的向量乘法单元上实现固定八元素的有符号 int8 点积指令 `vdot.vv`，
完成 RTL 与 NEMU 的协同仿真验证，并与标准 RVV 指令组合做延迟对比。

---

## 一、阶段完成情况

| 阶段 | 内容 | 交付物 |
|---|---|---|
| 阶段一 | 环境部署与验证 | 环境搭建、hello 程序在 RTL 仿真上跑通 |
| 阶段二 | vdot 设计与实现 | 指令语义、微架构、数据通路设计；功能测试；Vivado 单元级时序 |
| 阶段三 | 协同仿真与评估 | NEMU 指令扩展、四轮 difftest、延迟加速比测量 |

---

## 二、指令约定

```
int32_t sum = 0;
for (int i = 0; i < 8; i++)
  sum += (int32_t)(int8_t)vs1[i] * (int32_t)(int8_t)vs2[i];
```

- 两路源寄存器各取低八个有符号 8 位元素，**不累加旧目标值**
- 结果以 32 位补码写入 `vd[31:0]`，`vd[127:32]` 清零
- 仅支持 `SEW=e8`、`LMUL=m1`、`vl=8`、`vstart=0`、`vm=1`，其余按非法指令处理
- 编码：OPMVV，`funct6=001110`、`funct3=010`、`opcode=1010111`
- 机器码示例：`.word 0x3a1121d7`（即 `vdot.vv v3, v1, v2`）

汇编器没有该助记符，测试程序用 `.word` 直接发出机器码。

---

## 三、目录结构

```
.
├── docs/                 文档，每份都有 pdf / md / docx 三种格式
│   ├── pdf/
│   ├── md/               含 assets/ 图片
│   └── docx/
├── video/                三个阶段的讲解录屏
├── src/
│   ├── patches/          三份补丁：XiangShan / YunSuan / NEMU
│   ├── apps/             九个 nexus-am 测试程序
│   ├── configs/          NEMU 构建配置
│   └── timing/           Vivado 时序测试顶层与约束
├── tools/
│   └── vdot_model.py     独立的点积参考模型，用于生成测试向量、核对机器码
├── scripts/              复现脚本，见第五节
└── logs/
    └── 协同仿真验证结果.txt
```

---

## 四、环境与基线

复现必须使用下列提交，换版本会导致行号、模块结构和时序结果都对不上。

| 工程 | 基线提交 |
|---|---|
| XiangShan | `16ae9ddcda54fc9a2fddffad73174cf793ac7814` |
| YunSuan（香山的 yunsuan 子模块） | `cadd3c2f43096e253d61296b33ac697be8354e29` |
| NEMU | `53bcb5686f8fd05248ae98546b7dc04bdca1bbb0` |
| nexus-am | `086a238062fdfb3281b745a537b361983d0154b5` |

工具链：`riscv64-linux-gnu-gcc` 11.4.0、Verilator 5.048、Java 21。
时序测试使用 Vivado 2023.1，器件 `xc7a100tcsg324-1`。

环境变量：

```bash
export AM_HOME=$HOME/xs-env/nexus-am
export NEMU_HOME=$HOME/xs-env/NEMU
export NOOP_HOME=$HOME/xs-env/XiangShan
```

---

## 五、复现

四个脚本按顺序执行即可。前两步只做一次，后两步可重复。

```bash
# 1. 打补丁（要求源码处于上表的基线提交）
bash scripts/01-apply-patches.sh

# 2. 编译 NEMU 参考模型与 RTL 仿真器（emu 单核构建约 30 分钟以上）
bash scripts/02-build-nemu-emu.sh

# 3. 四轮协同仿真，约 4~6 分钟
bash scripts/03-run-cosim.sh

# 4. 延迟测量
bash scripts/04-run-bench.sh
```

第三步的四个测试覆盖：vdot 正例、vdot 边界（8 个用例）、基线组合（5 个用例）、
双实现一致性。通过时每轮都以 `Difftest enabled` 开始、`HIT GOOD TRAP` 结束。

第四步不加 `--diff`：闭环测量函数会覆写 `v3`，输出是垃圾值，开 difftest 会误报失配。
功能正确性由第三步保证。

---

## 六、主要结果

### 功能（RTL + NEMU 协同仿真）

| 轮次 | 覆盖 | 结果 |
|---|---|---|
| 一 | vdot 正例，和值 492，高位清零 | PASS |
| 二 | 零、极值、正负抵消等 8 个边界用例 | 8/8 PASS |
| 三 | 标准 RVV 基线组合，5 个用例 | 5/5 PASS |
| 四 | 两种实现输出一致 | PASS |

### 延迟（天然 RAW 依赖链，单条指令从操作数就绪到结果可用）

| 实现 | 延迟 |
|---|---|
| 标准 RVV 指令组合（基线） | 20.81 拍 |
| `vdot.vv` 专用指令 | 6.72 拍 |
| **加速比** | **3.09 倍** |

延迟定义采用体系结构通用口径：从输入操作数就绪，到结果可被后续指令使用所需的周期数。
取指、译码、重命名、提交不计入，这些阶段在稳态下被流水线重叠。
详细分解与交叉验证见 `docs/` 中的性能分析报告。

### 单元级时序

Vivado 2023.1，10 ns 时钟约束，布线后：

- WNS = +1.973 ns，TNS = 0，失败端点 0
- 关键路径：`walOut_r_reg[97]` → `dot_reg[31]`，数据路径 7.452 ns，10 级逻辑

这是单元级证据，不等同于完整 SoC 的时序收敛或频率签核。

---

## 七、文档与视频

`docs/` 下七份文档，每份都有 `pdf`、`md`、`docx` 三种格式：

| 文档 | 内容 |
|---|---|
| 第一阶段-环境部署与验证操作日志 | 从零搭建 xs-env 到 hello 跑通，含每步验证命令 |
| 第一阶段_向量加法指令执行过程文档 | 向量加法在香山上的执行过程 |
| 第二阶段_vdot.vv 设计文档 | 指令语义、微架构设计、数据通路 |
| 第二阶段-vdot.vv基础测试报告 | 功能测试与 Vivado 时序 |
| 第三阶段_协同仿真文档 | NEMU 扩展与四轮 difftest |
| 第三阶段-性能分析报告 | 延迟测量方法与 3.09 倍结论 |

`video/` 下三个录屏：

| 视频 | 内容 |
|---|---|
| 阶段二-vdot设计与实现.mp4 | 设计思路与源码讲解 |
| 阶段三-波形分析.mp4 | RTL 波形与数据通路观测 |
| 阶段三-性能分析.mp4 | 测量方法演进与加速比分析 |

波形文件（`.fst`）体积较大未入库，如需查看可另行提供。
