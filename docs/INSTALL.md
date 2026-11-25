# 安装与独立接入

模块为 `youyong5/moondeform`，首个公开版本 `0.1.0` 已于 2026-11-25 发布。已从干净外部项目实际下载并完成 native / JS 检查、构建与运行。

## 工具与依赖

安装 MoonBit 官方工具链，确认 `moon version --all`。已验证版本和平台见 [VALIDATION](VALIDATION.md)。库只使用 MoonBit 标准库；native 目标需要系统 C 编译器，JS 程序需要 Node.js。

维护检查另需 Python 3 和 C++ 编译器，浏览器 UI 检查另需 Playwright 与 Chromium。这些工具不是库的第三方运行依赖。

## 源码接入：独立模块

以下命令适用于已验证的 Linux / POSIX shell，在新的工作目录运行：

```sh
mkdir moondeform-work
cd moondeform-work
git clone https://github.com/youyong5/MoonDeform.git library
cp -R library/tests/consumer app
moon work init ./library ./app
moon -C app run . --target native
moon -C app run . --target js
```

`app` 有自己的 `moon.mod`，通过 workspace 指向本地库，不访问库的私有字段。示例实际检查自定义约束投影、约束类型／粒子元数据、运行时柔度更新及有符号残差。源码更新后可再次运行相同入口。

维护者也可以在仓库根目录运行 `python3 scripts/consumer_check.py`，脚本在临时 workspace 中执行相同消费检查。

## 发布候选接入

GitHub Actions 的 `release-candidate` 产物包含一个 `MoonDeform-<版本>-<提交前缀>-candidate.zip`、对应外部 SHA-256 文件及 `release-candidate.json`。

先解压 GitHub 下载的产物 ZIP，再解压其中名称以 `-candidate.zip` 结尾的文件，进入 `MoonDeform/`：

```sh
moon run examples/headless --target native
moon run examples/runtime_material --target js
```

`dist/MoonDeform-demo.html` 可直接打开。若需独立模块消费，可将上面的 `library` 路径替换为解压后的 `MoonDeform`。候选包结构与证据说明见 [RELEASE](RELEASE.md)。

## Mooncakes 接入

在已有 MoonBit 项目根目录运行；如需新建，可先执行 `moon new my-simulation` 并进入该目录：

```sh
moon add youyong5/moondeform@0.1.0
```

调用包的 `moon.pkg` 导入：

```moonbit
import {
  "youyong5/moondeform" @deform,
}
```

随后使用 README 中的公开 API 示例。也可复制仓库的 `tests/consumer/main.mbt` 和 `moon.pkg` 到新项目中执行 `moon run . --target native`、`moon run . --target js`。该入口检查自定义约束、元数据、柔度修改、残差和 240 帧弹性环落地。

维护者执行 `python3 scripts/registry_check.py` 可重现注册表检查，结果写入 `artifacts/registry-consumer.json`。脚本创建无 workspace／缓存的临时项目，实际 `moon add` 指定版本，检查 `moon tree --json` 的 registry 来源，并核对已发布核心源码的 LF 规范化 SHA-256。它固定验证不可变的 0.1.0；当前开发源码通过独立的 workspace 检查。
