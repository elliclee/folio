# PreviewerMD

[English](README.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md)

PreviewerMD は、React、TypeScript、Vite、Tauri で構築されたローカル
ファーストの Markdown リーダー兼軽量エディターです。長文を快適に読むために、
文体、利用環境、夜間利用に合わせた複数の視覚テーマを備えています。この README は
デスクトップアプリを対象にしています。

## スクリーンショット

![PreviewerMD のプレビューモード](docs/screenshots/previewermd-preview.jpg)

![PreviewerMD のエディター/プレビュー分割表示](docs/screenshots/previewermd-split-view.jpg)

### テーマギャラリー

PreviewerMD には、読みやすさを重視した複数のテーマが用意されています。落ち着いた
ライトテーマ、エディトリアルな表示、夜間向けのダークテーマ、高コントラスト表示まで、
上部ツールバーから切り替えられます。テーマは本文だけでなく、読書シェル全体に適用されます。

![PreviewerMD Claude Dark テーマ](docs/screenshots/previewermd-theme-claude-dark.jpg)

![PreviewerMD Lovable テーマ](docs/screenshots/previewermd-theme-lovable.jpg)

![PreviewerMD Spotify テーマ](docs/screenshots/previewermd-theme-spotify.jpg)

## ステータス

PreviewerMD はローカル開発とパッケージングに利用できます。現在のリリース対象は
デスクトップアプリです。

## リポジトリ構成

| パス | 用途 |
| --- | --- |
| `Previewer.md/` | macOS、Windows、Linux 向けの Tauri デスクトップアプリ。 |
| `src/` | 旧ブラウザー版 Markdown previewer プロトタイプ。 |
| `docs/` | 計画メモと実装記録。 |

## 機能

- 単体の Markdown ファイル、または Markdown ドキュメントを含むフォルダーを開く。
- GitHub Flavored Markdown をレンダリングし、コードブロックのシンタックスハイライトに対応。
- フルプレビュー表示とエディター/プレビュー分割表示を切り替える。
- 意図した編集内容をディスクへ保存する。
- 現在のドキュメント内を検索する。
- レンダリング済み Markdown を印刷またはエクスポートする。
- ライト、ダーク、エディトリアル、高コントラストなど、利用環境に合わせた
  複数の読書テーマを選択する。
- ネイティブアプリに近いウィンドウ挙動とテーマ選択を保持する。
- アクティブなフォルダーをシステムターミナルで開く。

## 必要環境

- Node.js 20 以降
- npm 10 以降
- Rust stable toolchain
- 利用する OS に応じた Tauri 2 のプラットフォーム要件

デスクトップシェルを実行する前に、公式の Tauri prerequisites に従って
OS ごとの環境を準備してください。

## デスクトップ開発

```bash
cd Previewer.md
npm install
npm run tauri -- dev
```

よく使うコマンド：

```bash
npm test
npm run build
npm run perf:gate
cargo test --manifest-path src-tauri/Cargo.toml
npm run tauri -- build
```

レンダラー側のアプリコードは `Previewer.md/src/` にあります。Tauri の設定と
ネイティブコマンドは `Previewer.md/src-tauri/` にあります。

## 旧 Web プロトタイプ

リポジトリのルートには、旧ブラウザー版 previewer が残っています。以下のコマンドで
引き続き実行できます。

```bash
npm install
npm run dev
```

このプロトタイプは、本番向けの Tauri デスクトップアプリとは独立しています。

## リリース前の検証

タグ付けやビルド公開の前に、デスクトップアプリのチェックを実行してください。

```bash
cd Previewer.md
npm test
npm run build
npm run perf:gate
cargo test --manifest-path src-tauri/Cargo.toml
```

その後、パッケージ化したアプリを手動で smoke test します。

- Markdown ファイルとフォルダーを開く。
- ウィンドウのサイズと位置を変更し、終了後に再度開く。
- macOS では `Cmd+F`、Windows/Linux では `Ctrl+F` でドキュメント内検索を使う。
- 編集モードを切り替え、保存操作が意図通りであることを確認する。
- 現在のドキュメントを印刷またはエクスポートする。
- 現在のフォルダーをシステムターミナルで開く。

## セキュリティとプライバシー

- PreviewerMD はローカルファーストで、ユーザーが選択したファイルを扱います。
- 実際の `.env` ファイル、署名証明書、provisioning profile、生成済みアーカイブ、
  プラットフォーム固有のビルド成果物をコミットしないでください。
- `.env.example` にはプレースホルダーのみが含まれています。
- 公開リリース前に、ローカル実験で使用した可能性がある署名素材をローテーションしてください。

## コントリビュート

Issue と pull request を歓迎します。コードを変更する場合は、可能な範囲で焦点を絞った
テストを追加し、pull request を開く前に関連する検証コマンドを実行してください。

## ライセンス

このプロジェクトは MIT License の下で公開されています。詳しくは [LICENSE](LICENSE)
をご覧ください。
