# 0.1.0 发布与交付包

0.1.0 已于 2026-11-25 发布到 [Mooncakes](https://mooncakes.io/docs/youyong5/moondeform@0.1.0/)，来源提交为 `827103b4675e3b51be864070b177af7afc4444cb`。后续提交补充验证脚本与文档，不改变注册表上的不可变版本。版本、模块名、许可证与仓库地址仍从 `moon.mod` 读取；候选生成脚本本身不执行发布。

## 两种归档

| 内容 | 用途与生成方式 |
| --- | --- |
| `youyong5-moondeform-0.1.0.zip` | `moon package --frozen` 创建的实际注册表候选归档；不是手工拼出的替代包 |
| `MoonDeform-0.1.0-<提交前缀>-candidate.zip` | 交付候选：已提交源码、可追溯历史、预编译演示、上述注册表归档及验证记录 |

`.moonignore` 控制注册表归档：保留源码、公开接口、文档、示例、测试与上游许可，排除构建缓存、依赖缓存、演示输出、工作区临时文件和发布产物。规则依据 [MoonBit 官方模块文档](https://docs.moonbitlang.com/en/stable/toolchain/moon/module.html#publishing-files-with-moonignore)，实际结果由 `moon package` 生成并逐文件核对，不仅检查忽略规则本身。

`scripts/check_package.py` 核对必要文件、来源字节和 Git 跟踪状态，再将实际注册表包解压到临时目录：用它运行 native / JS 独立消费模块，重新编译浏览器示例并执行真实求解器桥接检查。该检查证明归档内容可用，不代表注册表权限、服务器校验或远端安装已完成。

## 本地生成

先提交代码，保持工作区干净，并保留完整 Git 历史：

```sh
python3 scripts/check_release.py
python3 scripts/package_release.py
```

`check_release.py` 包含四后端物理测试、独立消费、上游参考、示例、归档消费与 8 项发布证据绑定回归检查。后 8 项是 Python 工程检查，不计入 52 项 MoonBit 物理／API 测试。

若有 Playwright 及 Chromium，可生成匹配的真实浏览器记录：

```sh
python3 scripts/check_browser.py
python3 scripts/package_release.py --require-browser
```

没有当前提交的浏览器证据时，默认本地候选明确写为“该提交没有浏览器记录”；启用 `--require-browser` 会拒绝生成。已有证据若对应其他提交、源码或演示，即使是成功结果也会被拒绝。失败检查会清除本轮对应的旧成功记录。

## CI 交付

core 作业生成库／归档检查结果和编译演示；browser 作业对该演示执行真实 Chromium 检查；registry 作业在全新项目从 Mooncakes 下载已发布 0.1.0，检查 native / JS 消费及核心源码指纹，并上传 `registry-consumer-evidence`。candidate 作业依赖 core、browser、registry 三者成功，下载它们的输入并强制 `--require-browser`。它不需要登录 Mooncakes，也不会发布、打标签或创建 GitHub Release。

每次完整成功运行的 `release-candidate` 产物都包含提交号、源码指纹、注册表包和演示文件的 SHA-256，以及相同提交的 core / browser 记录。

## 候选包内容与完整性

解压后的 `MoonDeform/` 包含：

- `git archive HEAD` 导出的已提交源码、文档、测试和许可证。
- `dist/`：静态站、编译 JS 和无需服务器的单文件 HTML。
- `registry/`：实际注册表候选归档。
- `validation/`：核心检查、归档检查和已提供的浏览器检查记录。
- `RELEASE.json`：版本、提交、源码及演示指纹、实际验证状态；不猜测全局发布状态。
- `SHA256SUMS`：候选包内各内容文件的 SHA-256；生成时同时验证 ZIP 完整性和逐文件校验值。
- `history.bundle`：仅当前提交及可达祖先，不包含其他本地开发分支或 Git 配置。

在解压目录可执行 `sha256sum -c SHA256SUMS`。恢复 Git 历史的方式为：

```sh
git init restored-source
git -C restored-source fetch ../history.bundle HEAD
git -C restored-source checkout -b main FETCH_HEAD
```

指纹用于追踪具体交付内容，不承诺不同机器／工具版本生成的 ZIP 逐字节一致。

## 服务器预检与正式发布

初次开发环境预检因未登录而停止；随后维护者在 Windows 的全新源码目录完成登录，提供服务器 dry-run `202 Accepted` 与正式发布 `200 OK` 的终端输出，打包及解压后的 `moon check` 均通过。

本开发环境随后独立执行 `moon view youyong5/moondeform@0.1.0`，注册表返回发布时间 `2026-11-25T09:20:38.555725+00:00`。干净外部项目的 `moon add`、registry 依赖来源检查、native / JS 检查／构建／运行均通过。下载的模块清单、包清单、公开接口和六个核心源码文件与上述提交一致；由于从 Windows 发布，比较仅将 CRLF 规范化为 LF，没有忽略其他字符差异。

注册表中的 0.1.0 与后续提交生成的交付候选应按各自来源提交区分：`registry/` 内的包是当前提交的本地 `moon package` 输出，不能称为已上传的 0.1.0 原归档。远端安装证据独立上传到 CI 的 `registry-consumer-evidence`；最终验收对应见 [ACCEPTANCE](ACCEPTANCE.md)。
