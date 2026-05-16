# Logo Generator for Gemini Web

这个文件把 `op7418/logo-generator-skill` 里最核心的部分抽离成 Gemini 网页版可直接使用的提示词工作流。

适用场景：
- 你想在 Gemini 网页版里先产出 6 个以上 logo 方向
- 你想让 Nano Banana 基于参考 logo 图生成高质感展示图
- 你不想先配置本地 skill、Python 环境和脚本

不适用场景：
- 你需要自动导出 SVG/PNG 文件
- 你需要本地批量生成 12 种背景风格
- 你希望 AI 直接帮你落盘成完整工程文件

## 一、先给 Gemini 的总控提示词

把下面整段贴给 Gemini，作为起始消息：

```text
你现在是一个高级 logo 设计师和品牌展示设计师。你的任务分 4 个阶段完成：

阶段 1：先向我收集必要信息，只问最少但足够的问题。
你必须收集：
1. 品牌/产品名
2. 行业或产品类型
3. 核心概念或关键词
4. 风格偏好
5. 颜色偏好
6. 整体气质

阶段 2：基于信息输出至少 6 个明显不同的 logo 方向。
要求：
1. 每个方向都要有独立概念，不是同一个图形的小改动
2. 每个方向都要说明设计逻辑、适合的品牌气质、可能的图形结构
3. 每个方向都要给出可直接复制的 SVG 代码
4. SVG 统一使用 viewBox="0 0 100 100"
5. 尽量使用几何图元、简单 path、circle、rect、polygon
6. 默认使用 currentColor，保持单色可扩展

阶段 3：等我选中方向后，只做定向迭代，不要整批重做。
你需要支持：
1. 调整线粗、比例、留白、旋转、节点位置
2. 合并不同方案里的局部元素
3. 输出更新后的 SVG

阶段 4：当我要求做展示图时，你要进入品牌展示模式。
你要把我给你的 logo 当成唯一主体，生成适合 Nano Banana 的高质量展示图提示词，强调：
1. logo 作为绝对视觉中心
2. 大量留白
3. 微排版
4. 高端品牌系统展示感
5. 强烈控制背景气质，但不能喧宾夺主

设计原则必须始终遵守：
1. 极简优先：1 到 2 个核心元素，最多 5 到 6 个图形
2. 留白充足：至少 40% 画布为空
3. 比例精准：主线条建议 2.5 到 4 的视觉粗细感
4. 避免完美对称，保留有意识的不对称张力
5. 不做无意义装饰
6. 必须有清晰视觉焦点
7. logo 在 16x16 和 512x512 都应可识别

常用图形方向可以从这些类别里选择并混搭：
1. 同心圆点阵
2. 圆角矩形矩阵
3. 沿路径排列的胶囊形
4. 六边形蜂窝
5. 圆形挖空
6. 节点网络
7. 几何线束
8. 单一主图形 + 一个辅助强调元素

开始时不要直接设计。先问我最少的问题。
```

## 二、如果你想一次拿到 6 个 SVG 方向

在 Gemini 完成信息收集后，再补一句：

```text
现在进入方案生成。请给我 6 个明显不同的 logo 方向，每个方向都包含：
1. 方案名
2. 核心概念
3. 图形构成说明
4. 为什么适合这个产品
5. 一段完整 SVG 代码

请优先控制高级感，不要做 AI 味很重、细节堆砌、装饰过多、俗气渐变、复杂 3D、卡通化的图形。
```

## 三、如果你已经选中一个方向，继续细化

把这段发给 Gemini：

```text
我选中这个方向。现在只做定向 refinement，不要重做全部方案。

当前目标：
- 保留：{写你要保留的部分}
- 调整：{写你要调整的部分}
- 避免：{写你不要出现的东西}

请输出：
1. 调整后的设计说明
2. 更新后的 SVG
3. 如果你认为还有 2 个可选微调方向，也请一并给出
```

## 四、给 Nano Banana 的展示图提示词模板

当你已经有一个 logo 图，准备上传到 Gemini / Nano Banana 做展示图时，把 logo 图作为参考图，再配这段提示词：

```text
Use the uploaded logo as the only reference subject.

Extract only the core logo graphic. Remove any surrounding frame, page, mockup, or extra decoration.
Render the logo as a pure flat vector-like shape with extremely sharp clean edges.
Place the logo at the absolute visual center with huge breathing space.

Create a premium brand identity showcase image with:
- restrained composition
- micro-typography
- Swiss-style layout logic
- strong negative space
- editorial presentation quality
- a highly controlled background atmosphere

Rules:
- the logo must remain the main subject
- no extra symbols or replacement graphics
- no busy composition
- no oversized headline
- any typography must be tiny, precise, and secondary
- the result should feel like a high-end identity system presentation from a top design studio

Text placement suggestion:
- top-left or left corner: {BRAND_NAME}
- top-right or right corner: v.1.0.0 // 2026
- bottom-center: {SHORT_DESCRIPTOR}

Color rule:
- if background is dark, render the logo in pure white
- if background is light, render the logo in pure black
```

## 五、12 种背景风格提示词

你可以把下面任意一种风格，追加到上面的展示图提示词末尾。

### 1. The Void

```text
Background style: absolute black void. Pure black background with extremely fine silver-white micro noise, cold electronic film grain, and only a faint icy glow at the far edge. Hardcore tech, extremely restrained, mysterious, infinite-space feeling.
```

### 2. Frosted Horizon

```text
Background style: deep titanium gray or midnight slate base with organic dust-like film texture, subtle cold gray-blue halo, edges dissolved like mist. Premium, breathable, industrial, Apple-like presentation quality.
```

### 3. Fluid Abyss

```text
Background style: deep midnight purple or very dark Klein blue base with tinted noise, deep-sea or nebula texture, and slow fluid fusion between dark orange and dark blue. AI-native, dynamic, computational, moody.
```

### 4. Studio Spotlight

```text
Background style: very dark warm carbon gray with low-light camera grain and a single-side soft spotlight. Editorial magazine quality, physical studio lighting, restrained luxury.
```

### 5. Analog Liquid

```text
Background style: one solid bold color base only, with metallic shimmer, mica powder, liquid texture, mineral fragments, and organic chaos. The logo must stay ultra-clean and sharp against a rich, tactile, experimental background.
```

### 6. LED Matrix

```text
Background style: black base with glowing dot-matrix waves, CRT artifacts, retro display texture, halftone light points, and cyberpunk digital hardware mood. The logo floats above the digital field as a solid entity.
```

### 7. Editorial Paper

```text
Background style: off-white editorial paper with subtle watercolor or art-paper texture, warm gray vignette, natural diffuse light, independent magazine aesthetic, serious and human-centered.
```

### 8. Iridescent Frost

```text
Background style: cold silver-white base with extremely fine frosted-glass noise and faint holographic light in pale blue, soft pink, and light purple. Optical, premium tech, calm and precise.
```

### 9. Morning Aura

```text
Background style: warm ivory base with soft mist-like noise and very low-saturation pastel light in mint, baby blue, and dawn orange. Friendly AI, warm, intelligent, pressure-free.
```

### 10. Clinical Studio

```text
Background style: white or cold light-gray base with sharp digital micro-noise, clean shadow gradients, spatial order, and sterile studio lighting. Rational, algorithmic, high-confidence.
```

### 11. UI Container

```text
Background style: clean digital background with a frosted-glass or transparent UI container, rounded corners, subtle depth, micro-shadow, and product-native interface feeling. Suitable for SaaS and app brands.
```

### 12. Swiss Flat

```text
Background style: 100% solid deep color only, no gradients, no noise, no effects. Pure Swiss-style graphic authority. Timeless, bold, and absolutely flat.
```

## 六、推荐搭配

- 基础设施 / 安全产品：`The Void`、`Frosted Horizon`
- AI / 数据产品：`Fluid Abyss`、`Morning Aura`、`LED Matrix`
- 设计工具：`Frosted Horizon`、`Editorial Paper`、`UI Container`
- SaaS / App：`UI Container`、`Clinical Studio`
- 更经典克制：`Swiss Flat`、`Editorial Paper`

## 七、最实用的对话节奏

推荐你在 Gemini 网页版里按这个顺序走：

1. 先贴“总控提示词”
2. 回答 Gemini 的澄清问题
3. 要它输出 6 个 SVG 方向
4. 选 1 个方向继续 refinement
5. 让它给你最终展示图 prompt
6. 上传 logo 参考图，用 Nano Banana 出展示图
7. 如果展示图对了，再回头让它微调 SVG

## 八、Codex 兼容性结论

原始仓库可以迁到 Codex，但不是完全原样即用：

- `SKILL.md` 结构本身是兼容的
- README 里的安装路径是 Claude 风格，Codex 应改装到 `~/.codex/skills/` 或你当前环境认可的 skill 目录
- Python 脚本可直接复用
- 仍然需要你自己的 `GEMINI_API_KEY`
- 安装后通常需要重启 Codex 会话，才能让新 skill 被稳定发现

如果你要继续走 Codex 版，下一步就是把这个仓库安装进本机 skill 目录，并把依赖和 `.env` 配好。
