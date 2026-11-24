# GitHub 首次公开检查单

当前目标是可复现的开源开发版，而非已经通过赛事验收或完成 Mooncakes 发布的最终版本。

## 本地完成条件

- `python3 scripts/check_release.py` 完成并在任一失败时返回非零状态。
- 独立消费模块实际运行，公共接口与生成的 `.mbti` 一致。
- 上游版本、MIT 许可、移植部分、新增部分及数值限制可追踪。
- README 同时给出库的复用方式与演示运行方式。
- Git 历史保留实际开发提交，发布包不混入 `_build/`、`.mooncakes/`、凭据、缓存或环境专用工具。
- 预编译演示由当前源码重新生成，不能把它当作额外实现。

## 首次推送后验证

1. 公开仓库为 [youyong5/MoonDeform](https://github.com/youyong5/MoonDeform)，模块名为 `youyong5/moondeform`。
2. `moon.mod` 已声明真实仓库 URL。
3. 检查 GitHub Actions 的 core 与 browser 两个作业，保留实际结果。浏览器失败时先修复，不把本地 Node 检查当作浏览器通过。
4. 如需在线演示，可将 `dist/` 部署到静态托管；库本身无需后端服务。
5. Mooncakes 发布是下一阶段，发布后还需验证干净消费项目的远端安装。

本地检查脚本不执行上述外部步骤。首次推送、在线演示部署和软件包发布是维护者单独执行的操作。

## 推荐仓库描述

Renderer-independent 2D XPBD deformable physics for MoonBit, with signed-area and bending constraints, an extensible scalar-constraint API, upstream reference checks and a static playground.

## 版本说明应写清楚

本项目的贡献是 MoonBit 生态移植与二维工程扩展，XPBD 算法来源于已有研究；不是提出新物理算法。核心范围为粒子、二维网格、封闭软体和静态接触，暂不包含自碰撞、CCD、防翻转或三维布料。
