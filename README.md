# 星序 Xingxu（MoonRoster）

MoonRoster 是一个面向小规模课程和共享场地的离线排程工具。填写课程、人员、班级、时间和教室后，它会搜索满足条件的安排；也可锁定已经确定的时间或教室，再为其他课程安排位置。

适用场景包括课程排课、实验室活动和社团活动。浏览器里的输入与结果只在本机处理；使用示例中的姓名与安排均为虚构数据。

## 快速开始

需要 [MoonBit 工具链](https://www.moonbitlang.cn/download/)和 Node.js 20 或更新版本。本轮验证使用 moon 0.1.20261102、moonc v0.10.19；请使用相同或更新的稳定版。安装好后，在项目根目录运行：

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
