# 上游筛选与复用决策

核查日期：2026-11-24。维护情况以 GitHub 仓库默认分支的提交为准，不把收藏、README 展示或仓库 `updated_at` 当成维护证据。没有在本机完整构建全部候选。

| 候选 | 默认分支最新提交（核查时） | 许可 | 功能与部署成本 | 决策 |
| --- | --- | --- | --- | --- |
| [PositionBasedDynamics](https://github.com/InteractiveComputerGraphics/PositionBasedDynamics) | `10a70bc146a97873dc3c8fef372f5217e010542e`，2026-09-01 | MIT，已读 LICENSE | 有 XPBD 距离、弯曲、体积等内核。完整 C++ 项目使用 CMake/Eigen，图形演示另有依赖 | 选中：固定版本移植必要核心，保留原文件和许可，避免完整运行时绑定 |
| [Fx2D](https://github.com/Bharath2/fx2d-physics-engine) | `5aa472d9822a46e2b07ebc0394979d35b2a5191f`，2026-11-17 | BSD-3-Clause | 持续有提交，C++20、XPBD 刚体；场景／图形额外引入 YAML/raylib/ImGui | 主体是刚体，与本项目网格形变范围不匹配；未复制代码 |
| [Ten Minute Physics](https://github.com/matthias-research/pages) | `bfc4b63667c7e3ef683a7d6491c26f13c7e0d831`，2026-10-06 | GitHub 元数据未识别统一许可 | 有教学演示，方便理解；仍需逐文件核对可复用许可与工程边界 | 可用于学习，未复制代码，不作为统一上游依赖 |
| [verlet-js](https://github.com/subprotocol/verlet-js) | `3293d409aafe3adfd56811849b9168cb84599c28`，2014-05-02 | LICENSE 内容为 MIT，已核对 | 轻量 JS、距离／角度约束；默认分支长期无新提交，且不是 XPBD | 不作为维护基础，未复制代码 |

“仍有近期维护”不等于保证未来维护。上游最新提交也不必修改物理内核；本项目固定提交以保证来源可复现，后续升级先运行差分验证。

## 复用清单

直接移植：`XPBD::solve_DistanceConstraint` 的位置投影与乘子更新结构，转换为二维向量、MoonBit 类型和直接柔度参数。

共同数学基础：其余约束使用同一标准 XPBD 标量投影公式。

新增：二维有符号面积梯度、二维角度梯度、粒子世界、三个拓扑构造器、公共自定义约束接口、静态接触、错误回滚、宿主桥接、数值测试和独立消费示例。

未复用：上游 Eigen 类型、完整 C++ 求解运行时、三维碰撞与渲染器。原始 `XPBD.cpp/.h` 作为溯源和测试材料保存，不参与 MoonBit 构建。运行 MoonDeform 不需要安装上游。
