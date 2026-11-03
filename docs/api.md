# JSON API 契约

核心入口为 `solve_json(input : String) -> String`，由 MoonBit 实现；调用者可独立使用核心，无需加载网页或 Node 服务。包接口见根目录 `pkg.generated.mbti`。模块尚未发布，当前可从源码构建；不提供已经可用的 Mooncakes 安装命令。

文件调用入口为 `node cmd/solve.mjs INPUT.json`，输入输出及退出码见 README。适配器只做受限文件读取、引擎调用和退出码映射，所有领域约束均在 MoonBit 内检查。其端到端检查脚本为 `verify_examples.mbtx`。

输入必须是 JSON 对象，包含 `rooms`、`slots`、`courses` 数组及 `node_limit` 整数。完整可运行数据见 `examples/`。

| 对象 | 必填字段 | 可选字段 |
| --- | --- | --- |
| 场地 | id、name 字符串，capacity 正整数 | 无 |
| 时段 | id、name 字符串 | 无 |
| 课程或活动 | id、name、teacher、group 字符串，size 正整数，allowed_slots 字符串数组 | locked_slot、locked_room，可省略或为 null |

ID 在各自集合内唯一；所有引用必须存在。空课程数组返回合法空方案。空允许时段属于有效但无解的约束。各时段必须在现实中互不重叠；同一个负责人或群组请始终使用相同文本。其他边界见 README。未知对象字段当前不参与求解，不应依赖其保留。

输出始终包含 `status`、`message`、`nodes`、`assignments`。`ok` 的 assignments 按输入课程顺序排列，每项含 course、slot、room 三个原始 ID，且覆盖全部课程一次。其他状态 assignments 为空，不输出未完成安排。message 供人阅读，不作为稳定错误码。

`invalid` 表示格式或输入约束不合法；`unsatisfiable` 表示预检已证明矛盾或搜索穷尽；`unknown` 表示节点预算耗尽；`ok` 表示找到可行解，不保证最优。nodes 统计展开的未完成搜索状态，预检不计数，不能据此估算运行秒数。固定输入和数组顺序得到确定性结果。每次调用独立，无持久状态。取消计算是网页终止 Worker 的操作，不会产生求解结论。

集成到其他 MoonBit 包时，导入 `2515050242/moonroster` 并调用 `@moonroster.solve_json(input)`；浏览器模块由 `moon build cmd/web --target js --release` 生成，导出同名函数。核心没有网络、文件写入和用户数据上传能力。
