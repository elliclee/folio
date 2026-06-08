# Folio

[English](README.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md)

Folio 是一款本地优先的原生 macOS Markdown 阅读器与轻量编辑器。它完全用
SwiftUI 构建，不使用 WebView 渲染：由
[swift-markdown](https://github.com/apple/swift-markdown) 解析 GitHub Flavored
Markdown，渲染器直接输出原生 SwiftUI 视图与 `AttributedString`。它专注于
舒适的长文阅读，并提供多套适配不同写作风格与光照环境的视觉主题。

Folio 是当前主力应用，仅支持 macOS。最初的跨平台实现（一个名为
**PreviewerMD** 的 React + Tauri 应用）仍保留在本仓库的
[`Previewer.md/`](#历史版本previewermdtauri) 目录中。

## 功能

- 打开单个 Markdown 文件，或浏览整个 Markdown 文件夹。
- 原生侧栏文件树，支持置顶（Pinned）与最近（Recent）工作区文件夹。
- 渲染 GitHub Flavored Markdown：标题、列表、任务列表、表格、引用、删除线、
  链接、围栏代码块。
- 代码块原生语法高亮（约 30 种语言，不依赖 highlight.js）。
- 在「预览」与「分栏编辑/预览」之间切换；编辑结果保存到磁盘。
- 文档内查找（⌘F），高亮匹配并循环跳转。
- 通过原生打印管线打印或导出 PDF（⌘P）。
- 多个工作区窗口，每个窗口拥有独立的文档与主题。
- 从访达直接打开 `.md`/`.markdown` 文件（文件关联）。
- 多套阅读主题——Vercel（默认）、Claude、Claude Dark、Lovable、Spotify、
  Dark、High Contrast。暖色编辑向主题的标题使用衬线字体。
- 窗口位置与大小在重启后自动恢复。

## 环境要求

- macOS 15 或更高版本
- Swift 6 工具链（Xcode 16 或对应的命令行工具）

## 构建与运行

```bash
cd Folio
swift build          # 编译
swift test           # 运行测试
swift run            # 以欢迎文档启动
```

打包为可分发的 app（含图标与文件关联，ad-hoc 签名）：

```bash
cd Folio
./scripts/bundle.sh        # → dist/Folio.app
./scripts/bundle.sh --dmg  # → 同时生成 dist/Folio.dmg
```

安装：`cp -R dist/Folio.app /Applications/`。

开发便捷开关（无需打包，直接跑可执行文件）：

```bash
FOLIO_OPEN=~/notes swift run            # 启动时打开文件夹/文件
FOLIO_THEME=claude swift run            # 预设阅读主题
FOLIO_EXPORT_PDF=/tmp/doc.pdf swift run # 无界面打印渲染为 PDF
```

## 仓库结构

| 路径 | 用途 |
| --- | --- |
| `Folio/` | 原生 macOS SwiftUI 应用（当前主力）。 |
| `Previewer.md/` | 最初的 React + Tauri 应用 **PreviewerMD**（跨平台）。 |
| `src/` | 早期的纯浏览器 Markdown 预览原型。 |
| `docs/` | 规划笔记与实现记录。 |

`Folio/` 内的 Swift 模块在行为上与 Tauri 版的 TypeScript 模块一一对应
（各自带测试）；逐文件对照表与里程碑记录见
[`Folio/README.md`](Folio/README.md)。

## 历史版本：PreviewerMD（Tauri）

跨平台的 React + TypeScript + Vite + Tauri 应用仍可在 macOS、Windows、Linux
上使用。

```bash
cd Previewer.md
npm install
npm run tauri -- dev     # 开发
npm run tauri -- build   # 打包
```

渲染层代码位于 `Previewer.md/src/`；原生命令与 Tauri 配置位于
`Previewer.md/src-tauri/`。

## 安全与隐私

- Folio 本地优先，只处理用户选择的文件。
- 不要提交签名证书、描述文件、生成的归档或平台相关的构建产物。

## 贡献

欢迎提交 Issue 与 Pull Request。代码改动请尽量附带聚焦的测试，并在提 PR 前
运行 `swift test`（Tauri 版另有自己的检查）。

## 许可证

本项目采用 MIT 许可证，详见 [LICENSE](LICENSE)。
