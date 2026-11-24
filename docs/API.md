# 公共 API 与量纲

本页对应 0.1.0；完整签名由 [`pkg.generated.mbti`](../pkg.generated.mbti) 给出。所有求解入口都通过公开 API 使用，不要求访问粒子或约束的私有存储。

## 世界与粒子

统一采用长度 L、质量 M、时间 T 的一致单位制，例如米、千克、秒。库不会自动换算像素和物理长度；渲染缩放应由宿主完成。

| API / 参数 | 含义与范围 |
| --- | --- |
| `World::new(config~)` | 验证配置，创建独立世界；默认重力 `(0, -9.81)` |
| `Config::new(substeps~, iterations~)` | 默认 4 个子步、每子步 8 次迭代；各为 1–128 |
| `damping` | 非负，单位 1/T；每子步按 `exp(-damping*h)` 衰减速度，默认 0.2 |
| `restitution` | 0–1；接触法向恢复系数，默认 0 |
| `friction` | 0–1；每子步接触切向速度衰减比例，默认 0.2，并非库仑摩擦系数 |
| `add_particle(position, mass~, radius~)` | 默认质量 1、接触半径 0.02；质量与半径非负，`mass=0` 固定 |
| `position(id)` / `velocity(id)` | 返回位置 L、速度 L/T；`positions()` 返回副本 |
| `set_position(id, position)` | 瞬移并将该粒子的速度清零；也可移动固定点 |
| `set_velocity(id, velocity)` | 设置速度；固定点忽略非零速度 |
| `apply_force(id, force)` | 累加力 ML/T²，作用于下一次成功 `step` 的所有子步，成功后清空 |
| `step(dt)` | `0 < dt <= 0.1`；子步 `h=dt/substeps >= 1e-12`，返回 `StepReport` |

句柄为所属世界内的稳定整数索引，不包含世界标识，调用方必须避免跨世界混用。当前没有粒子删除或约束索引回收；`set_constraint_enabled(id, false)` 可以禁用约束，计数仍包含禁用项。

## 约束与柔度

| 构造方法 | 残差 C(x) | 默认目标与限制 |
| --- | --- | --- |
| `add_distance(a, b, compliance~, rest_length?)` | 两点距离减目标长度，单位 L | 默认捕获初始距离；目标可为 0 |
| `add_area(ids, compliance~, rest_area?)` | 有符号面积减目标面积，单位 L² | 至少 3 点，默认初始面积；目标绝对值至少 `1e-12` |
| `add_bend(a, b, c, compliance~)` | `(a-b, c-b)` 的有符号角偏差，单位弧度 | 捕获初始角，两臂长度至少 `1e-10`；差值按周期包裹 |
| `add_custom(ids, evaluate, compliance~)` | 调用方给定的标量等式残差 | 非空且不重复的句柄，残差与梯度必须有限 |

上述约束默认 `compliance=0`，表示硬约束。所有柔度必须有限且非负；同一数值在不同残差定义下不代表同一材料。

XPBD 使用 `alpha = compliance / h²`。若 C 的单位为 U，则柔度单位为 `U²*T²/(M*L²)`：距离约束为 `T²/M`，面积约束为 `L²*T²/M`，角度约束为 `T²/(M*L²)`。将自定义残差和梯度都乘以 s 时，应将柔度乘以 s²，才能保持相同投影响应。

面积约束要求调用方提供按边界顺序排列的简单轮廓。它保持总有符号面积，不能防止局部翻转、自交或粒子穿越。

自定义回调返回 `(C, gradients)`，梯度按传入句柄顺序排列，数量必须相同。它可能在每次迭代和 `report()` 中被反复调用，必须保持纯函数行为。不要在回调中修改世界、依赖调用次数、读取墙钟或改变捕获状态。库会阻止世界重入，但不能撤销调用方闭包的外部副作用；panic 不属于可恢复错误。

## 静态障碍与模型构造器

- `add_plane(n, offset)` 将法线及偏移一起归一化；允许区域为 `dot(n/|n|, p) >= offset/|n| + particle_radius`。例如 `(0, 2), 2` 表示水平面 y=1。
- `add_circle(center, radius)` 是实心障碍，半径必须大于 0；粒子中心留在障碍半径与粒子半径之和以外。它不是圆形轨道约束。
- `rope(start, end, segments)` 创建 `segments+1` 个粒子并固定起点；`mass` 是每个可动粒子的质量。
- `grid(origin, columns, rows, spacing)` 从原点向右、向下创建三角网格，固定顶行两角；返回的 `Body.edges` 可供任意渲染器绘制。
- `soft_ring(center, radius, count)` 创建封闭弹性多边形，包含周边距离、顶点弯曲及全局面积约束，无默认固定点。

模型构造失败会回滚本次新增的粒子与约束。构造器仅是便利入口；宿主可以自己生成任意二维拓扑。

## 诊断与失败恢复

`StepReport` 提供时间 T、最大速度 L/T、动能 ML²/T²、粒子／约束数量，以及最大绝对约束残差。最大残差混合了长度、面积、角度和自定义单位，不能作为统一精度阈值。`report()` 不推进时间，但会计算启用约束的残差。

`InvalidInput` 表示参数范围或重入问题，`InvalidHandle` 表示索引越界，`NumericalFailure` 表示求解或诊断产生无效数值。失败的 `step` 会恢复该帧开始时的位置、速度、累积力、约束乘子和时间；调用方可以修复／禁用问题约束后重试同一帧。

位置约束投影并非能量守恒积分器。应分别验证目标形变、约束残差、碰撞行为和实际工作负载，避免只凭动画看起来稳定来判断精度。
