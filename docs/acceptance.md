# 星序 Xingxu 验收复现

项目主体为 MoonBit 多资源计划修复库。输入受扰计划、每项任务的原候选与备选区间、资源容量、前置依赖及改动权重。输出候选索引、变更清单、成本及搜索结论，另提供独立的方案校验。原课程排程网页是仓库早期应用。

## 从 GitHub 复现

使用 moonc 0.10.16 或更高版本和 Node.js 20 或更高版本。在新工作目录执行：

```sh
git clone https://github.com/2515050242/moonroster.git
cd moonroster
moon version --all
moon fmt --check
moon check --target wasm,wasm-gc,js --deny-warn
moon test --target wasm,wasm-gc,js --deny-warn
moon build cmd/web --target js --release --deny-warn
moon run verify_examples.mbtx --deny-warn
```

自动验证包括合成设备停机、软件发布、码头争用三例，预期最低改动成本分别为 3、4、2。码头原方案会报告泊位用量 2 超过容量 1，修复后候选索引为 `[1,0]`。输入、单例运行方法和输出见 [README](../README.md#示例码头泊位争用)。

## 在另一个 MoonBit 模块中使用

从 [Mooncakes 模块页](https://mooncakes.io/docs/2515050242/moonroster) 核对可用版本。在调用方模块根目录安装依赖：

```sh
moon add 2515050242/moonroster@0.1.0
```

在调用方的 `moon.pkg` 中导入 `"2515050242/moonroster/repair" @repair`。使用 `@repair.solve(problem)` 求解，再用 `@repair.audit(problem, choices)` 复核方案。字段、状态和规模限制见 [接口文档](repair.md)，最小类型化调用见 [可执行示例](../repair/README.mbt.md)。

## 验收对应证据

以下按十月公开给选手的九项流程整理，十一月以组委会的当期通知为准。

| 检查项 | 复核入口 |
| --- | --- |
| MoonBit 主实现与编译器 | `repair/` 实现输入校验、搜索、约束复核与 JSON API。CI 报告编译器版本 |
| 公开仓库及提交 | [仓库](https://github.com/2515050242/moonroster)与 [main 历史](https://github.com/2515050242/moonroster/commits/main/) |
| 核心功能 | [输入范围和返回状态](repair.md)与 [公开类型](../repair/pkg.generated.mbti) |
| README | [安装、命令及完整码头输入输出](../README.md) |
| CI | [Actions](https://github.com/2515050242/moonroster/actions)覆盖格式、检查、测试、构建和 CLI 复现 |
| 可运行示例 | [修复 JSON](../examples/repair)与 [MoonBit 最小调用](../repair/README.mbt.md) |
| 测试覆盖 | 三目标各 32 项。修复测试含 64 个小实例枚举对照、预算中断、冻结、依赖、容量与异常输入 |
| Mooncakes | [注册中心模块页](https://mooncakes.io/docs/2515050242/moonroster)及上面的安装命令 |
| 许可证与来源 | [Apache-2.0](../LICENSE)、[来源与维护记录](provenance.md)、[同类项目](related-work.md) |

最优性只针对调用方给出的有限候选。预算用尽时，可行方案仍需要区分最优性待证与未知结果。合成案例用于复现约束和行为。
