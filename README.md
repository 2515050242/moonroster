# 星序 Xingxu · 多资源计划修复库

星序面向需要在资源故障、容量变化或任务延期后调整既有计划的排程系统开发者。独立的 MoonBit `repair` 包提供求解与校验接口，也可通过 JSON CLI 调用。

调用方为每项任务提供原选项、候选区间、同时占用的资源、前置任务及改动权重。求解器为每项任务选择一个候选，遵守逐时容量、前置依赖和冻结约束，并以所有变动任务的权重之和为目标。输出包含候选索引、改动清单和搜索结论。搜索穷尽时可证明最优或无解，预算耗尽时区分已有可行方案与结果未知。校验接口接收外部候选索引，检查约束并重新计算成本。

[验收复现与检查项](docs/acceptance.md) · [修复库接口](docs/repair.md)

## 示例：码头泊位争用

本例对应 `examples/repair/dispatch.json`。每个 tick 表示相同长度的时间单位，任务区间左闭右开。

| 任务 | 原候选 0 | 替代候选 1 | 每刻需求 | 调整一次的成本 |
| --- | --- | --- | --- | --- |
| 常规订单 routine | [0,1) | [1,2) | 泊位 1、人力 1 | 2 |
| 优先订单 priority | [0,1) | [2,3) | 泊位 1、人力 2 | 9 |

全程泊位容量为 1、人力容量为 2。两项任务的 `baseline` 都是 0，`frozen` 均为 false。`after` 为空，表示本例没有前置任务。成本权重由调用者给定，不代表系统自动推断的经济损失。

泊位容量为 1，两笔订单原定都占用 `[0,1)`。常规订单可以移到 `[1,2)`，成本为 2。优先订单可以移到 `[2,3)`，成本为 9。两个订单还分别需要 1 和 2 单位装卸人力。

```sh
moon build cmd/web --target js --release
node cmd/solve.mjs --audit examples/repair/dispatch.json examples/repair/dispatch-baseline.json
node cmd/solve.mjs --repair examples/repair/dispatch.json
```

第一条 CLI 命令预期退出码为 1，输出：

```json
{"status":"conflict","kind":"capacity","resource":"dock","tick":0,"used":2,"available":1}
```

第二条 CLI 命令预期退出码为 0，输出：

```json
{"status":"optimal","choices":[1,0],"cost":2,"attempts":5,"lower_bound":2,"changes":[{"task":"routine","before":0,"after":1,"cost":2}]}
```

`choices` 按任务输入顺序排列，索引从 0 开始。结果把常规订单移到第 1 刻，优先订单留在原时段。只移动优先订单需付 9，两笔都移动需付 11，因此 2 是这一组候选中的最低成本。该例使用合成数据。

## 其他修复示例

```sh
moon build cmd/web --target js --release
node cmd/solve.mjs --repair examples/repair/equipment.json
node cmd/solve.mjs --repair examples/repair/release.json
```

三个示例分别覆盖设备故障时改用备用设备、软件发布前置任务延迟、码头争抢时优先保留高代价订单。审计命令复核码头原方案，预期返回容量冲突和退出码 1。使用 [接口、示例结果和限制](docs/repair.md) 接入其他 MoonBit 工程。

## 原有课程排程应用

两个入口均需要 MoonBit 工具链和 Node.js 20 或更新版本。本轮验证使用 moon 0.1.20261104、moonc v0.10.20。课表网页继续使用原格式，示例为虚构数据。安装后在项目根目录运行：

```sh
moon build cmd/web --target js --release
node web/serve.mjs
```

浏览器访问 <http://127.0.0.1:8765/web/>。页面默认载入示例：可直接生成排程，也可以在表单中增删时段、场地和课程。完成后按 `Ctrl+C` 停止本地服务。

如需快速验证 MoonBit 核心，可运行：

```sh
moon run cmd/main
```

此命令运行内置示例并输出 JSON；页面支持导入自己的 JSON 数据、导出输入以便下次继续编辑，以及导出结果。`examples/` 中提供课程、实验室和活动三组示例。

也可以从文件求解，便于接入脚本或复现同一份安排。先完成上述 JavaScript 构建，再运行：

```sh
node cmd/solve.mjs examples/courses.json
node cmd/solve.mjs examples/laboratory.json
node cmd/solve.mjs examples/activities.json
```

标准输出是核心返回的 JSON。退出码：0 为找到方案，1 为已证明无解，2 为输入无效，3 为预算耗尽，64 为命令用法错误，74 为文件或引擎加载错误。文件必须为不超过 1 MiB 的 UTF-8 普通文件。输入还受核心的长度与规模限制。CLI 不修改文件；错误提示不回显输入路径。

## 输入与约束

- **时段**：唯一标识与名称。第一版将每个时段视为独立且互不重叠；请不要用两个标识表示实际重叠的时段。
- **场地**：唯一标识、名称和正整数容量。
- **课程或活动**：唯一标识、名称、教师或负责人、班级或群组、正整数人数和允许的时段。可以分别锁定时段和场地。
- **搜索节点上限**：1–100000 的整数。计算在后台运行，可点击“取消计算”；修改输入也会取消旧计算。

每次最多支持 64 项课程、64 个时段和 16 个场地；这些是输入保护上限，不代表该规模一定能在预算内求解。输入最多 262144 个 UTF-16 码元，JSON 嵌套最多 16 层。ID、名称、教师和班级须为 1–128 个 UTF-16 码元，不能含首尾空白。容量和人数须为 1–2147483647 的整数。校验不自动更改 ID 或人员名称。

同一时段内，教师、班级及场地均不能重复占用；人数不能超过场地容量。教师和班级通过填写的文本判断是否相同，请保持命名一致。每个课程恰好占用一个时段和一个场地。

高级 JSON 格式与表单同步，参考 [课程示例](examples/courses.json)。`allowed_slots` 存放时段 ID；`locked_slot`、`locked_room` 可省略。ID 在各自类型内必须唯一。请使用 UTF-8 文件。

锁定字段也可填写 `null`，表示不固定。核心在搜索前检查教师、班级及场地的资源匹配，能直接解释部分可用时段或场地不足；预检通过后仍需搜索，可能返回 `unknown`。

## 结果如何理解

| 状态 | 含义 |
| --- | --- |
| `ok` | 已找到一份满足约束的方案。 |
| `unsatisfiable` | 已确认当前约束下无解；对部分明显冲突给出具体提示。 |
| `unknown` | 搜索达到节点上限，尚不能判断是否有解。 |
| `invalid` | 输入格式、字段或引用有误。 |

结果是可行方案，不保证全局最优。第一版不处理连续多节课、跨周规则、时段的实际起止时间或多人协作。较复杂的无解问题可能只有一般性提示。使用前请结合实际情况复核。

## 开发与验证

核心求解器由 MoonBit 编写，浏览器使用 MoonBit 编译的 JavaScript 模块。网页仅提供数据录入、展示和本地导入导出；求解在核心中执行。

```sh
moon check --target wasm,wasm-gc,js --deny-warn
moon test --target wasm,wasm-gc,js --deny-warn
moon build cmd/web --target js --release
moon fmt --check
moon run verify_examples.mbtx --deny-warn
```

测试包括输入和冲突边界、锁定条件、搜索上限，以及小规模问题与独立穷举的对照。关于算法边界和现有项目的对比，请见 [设计说明](docs/design.md)和[相关项目](docs/related-work.md)。

`verify_examples.mbtx` 对三组真实文件夹具的结果独立检查课程覆盖、容量、引用、允许时段、锁定和资源冲突，并检查三种失败状态及 CLI 退出码。该验证脚本使用工具链随附的实验性 async 文件和进程 API，目前工具链会显示实验性依赖提示；求解库本身没有这些依赖。

## 许可证

开发者接入见 [JSON API 契约](docs/api.md)，逐条赛事核查见 [初审检查清单](docs/contest-review.md)。

[Apache License 2.0](LICENSE)。
