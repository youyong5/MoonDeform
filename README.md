# MoonDeform

面向 MoonBit 生态的**二维可变形物理库**。以 XPBD 求解粒子、弹性网格与封闭软体的约束，核心不依赖浏览器、Canvas、游戏引擎或外部原生库。

模块名：`youyong5/moondeform`。当前是开源开发版 **0.1.0，尚未发布到 Mooncakes**。

源码：[youyong5/MoonDeform](https://github.com/youyong5/MoonDeform)。[持续集成结果](https://github.com/youyong5/MoonDeform/actions/workflows/ci.yml)包含核心四后端验证和真实浏览器检查。

## 核心与生态价值

- 同一个 `World` 支持距离、二维有符号面积、平面弯曲和调用方提供的自定义标量约束。
- 材料以柔度 `compliance` 表达：0 表示硬约束，数值越大越柔软。乘子在子步内累积，在子步开始时清零。
- 求解器、模型构造器与宿主渲染分离。游戏、动画工具、教学程序、离线批量模拟均可使用同一公开 API。
- `rope`、`grid`、`soft_ring` 是可选便利构造器；应用也可以直接提交自己的粒子拓扑与约束。
- 提供静态平面／圆形障碍、粒子半径、接触恢复与切向速度衰减。
- 无效输入返回 `PhysicsError`；求解失败回滚当前帧的位置、速度、力、乘子和时间。

这是一项基于已有算法的生态移植与工程扩展，不声称发明 XPBD。距离投影移植自 MIT 许可的 PositionBasedDynamics，具体来源、版本与改动见 [PROVENANCE](docs/PROVENANCE.md)。

## 快速运行

安装 MoonBit 官方工具链后，在项目目录执行：

```sh
git clone https://github.com/youyong5/MoonDeform.git
cd MoonDeform
moon version --all
moon check --target all --deny-warn
moon test --target all --deny-warn
moon run examples/headless --target native
```

实际验证的工具链与测试范围见 [VALIDATION](docs/VALIDATION.md)。库的运行依赖只有 MoonBit 标准库；核心不需要 npm、CMake、Eigen 或 Python。native 后端本身需要系统 C 编译器。

## 公共 API 示例

使用者的 `moon.pkg`：

```moonbit
import {
  "youyong5/moondeform" @deform,
}
```

```moonbit
fn main raise {
  let world = @deform.World::new()
  world.add_plane(@deform.Vec2::new(0.0, 1.0), 0.0)
  let body = world.soft_ring(@deform.Vec2::new(0.0, 2.5), 0.6, 16)
  for _ in 0..<120 {
    ignore(world.step(1.0 / 60.0))
  }
  for id in body.particles {
    let p = world.position(id)
    println("\{id},\{p.x},\{p.y}")
  }
}
```

开发版通过 MoonBit workspace 本地使用，完整独立消费模块位于 `tests/consumer/`，执行 `python3 scripts/consumer_check.py` 可验证它只依赖公开 API。发布后再按实际版本添加 Mooncakes 依赖。

## 自定义约束

参数默认值、量纲、句柄生命周期及错误恢复见 [公共 API 与量纲](docs/API.md)。

调用方返回残差 `C(x)` 和各粒子的梯度 `dC/dx`，求解器统一完成 XPBD 投影。例如把一个粒子约束到 `x=1`：

```moonbit
let id = world.add_particle(@deform.Vec2::new(3.0, 2.0))
ignore(world.add_custom([id], fn(points) {
  (points[0].x - 1.0, [@deform.Vec2::new(1.0, 0.0)])
}))
```

回调必须是无副作用的纯函数。梯度长度必须与句柄数量一致，所有返回值必须有限。求解／诊断期间，库会拒绝回调对世界进行增删、移动粒子或重入步进。调用方主动抛出的 panic 不属于可恢复的 `PhysicsError`。

## 浏览器演示

```sh
python3 scripts/build_demo.py
python3 -m http.server 8765 --directory dist
```

也可以直接双击构建后的 `dist/MoonDeform-demo.html`，无需启动服务器。

打开 `http://localhost:8765`。演示使用真实 MoonBit 编译产物，可切换弹性环、绳索、网格，修改柔度，暂停／单步或拖动节点。JavaScript 负责页面、绘图和时间驱动，物理求解在 MoonBit 内。

`dist/` 构建结果只有 HTML 与 JS，可部署到普通静态托管，无后端、账号、服务密钥或 CDN 依赖。

## 边界与参数

- 仅二维平面模型；不包含三维布料、有限元体积材料、自碰撞、粒子相互碰撞、撕裂或动态刚柔双向耦合。
- 面积约束保持有符号面积，不能保证网格不局部翻转或轮廓不自交。`add_area` 的轮廓必须由调用方提供简单、按边界排序的顶点。
- 静态碰撞是离散节点碰撞，边或高速运动仍可能穿过障碍；没有连续碰撞检测。
- 接触摩擦参数是切向速度衰减系数，不是完整的库仑摩擦模型。
- `0 < dt <= 0.1` 秒；子步至少 `1e-12` 秒。子步数、迭代数在 1–128 之间。建议固定 `1/60` 秒推进。
- `mass=0` 表示固定点；句柄为世界内稳定整数索引，不能跨世界混用。当前通过禁用约束释放作用，不回收／重排索引。
- 诊断中的最大残差混合了长度、面积和角度单位，只作排错统计，不能比较材料精度。
- 相同构建、相同输入的重复轨迹已测试；不承诺不同后端的浮点结果逐位相等。

## 验证与维护

推荐执行 `python3 scripts/check_release.py`，任一步失败即停止。当前四个核心后端各有 **37 项测试**通过，其中一项包含 40 组固定上游距离投影对照。受载弹簧还在两组时间步／迭代参数下验证了稳态伸长解析值。


```sh
moon fmt --check
moon check --target all --deny-warn
moon build --target all --deny-warn
moon test --target all --deny-warn
python3 scripts/upstream_reference.py
python3 scripts/consumer_check.py
python3 scripts/build_demo.py
node scripts/bridge_check.cjs
```

上游对照脚本需要 Python 与 C++ 编译器，仅用于维护，不是库的运行依赖。可选真实浏览器测试见 `scripts/browser_check.cjs`。CI 工作流已提供；远程执行状态与本地验证是分开记录的。

更多资料：[贡献指南](CONTRIBUTING.md) · [首次 GitHub 发布](docs/GITHUB_RELEASE.md) · [架构与差异](docs/DESIGN.md) · [上游选择](docs/UPSTREAM.md) · [来源声明](docs/PROVENANCE.md) · [验证记录](docs/VALIDATION.md)。

## License

MIT。移植部分保留 PositionBasedDynamics 原许可证，位于 `third_party/PositionBasedDynamics/LICENSE`。
