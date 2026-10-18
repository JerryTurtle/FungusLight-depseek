# 素材来源与分发边界

## 引擎

Godot Engine 4.3 stable，MIT License。完整 MIT 文本见同目录 `Godot-MIT.txt`。

## 字体

- Fusion Pixel 12px（缝合像素）：SIL Open Font License 1.1，来源与完整许可见 `FusionPixel-OFL.txt` 与 `FusionPixel-components/`。
- Noto Sans SC：SIL Open Font License 1.1；仅 G2 审核台使用，发布包仍随附许可文本。

## 程序生成/项目内绘制

- 音效：项目内 Python 生成，生成流程见源工程 `tools/generate_sfx.py`。
- 交互物像素、粒子、灯光、UI 与代码：本项目内生成/编写。
- 开场五幕插画：由图像生成模型生成，经项目内裁切、调色与 96 色量化后使用；不含第三方素材，具体生成记录随源工程保留。
- HUD 技能/药剂图标：`tools/gen_hud_assets.py` 以像素网格程序生成，不使用第三方图标库。

## 原始 Fungus Cave 素材（重要）

- `Fungus Cave [16x16]` 的 Characters/Tilesets，以及由 Tilesets 裁切出的家具图块，来自项目提供的原始素材目录。
- 原始目录**未附可核实的再分发许可**，项目内 `game/assets/licenses/SOURCES.md` 已如实记录“不声称已获得商业分发许可”。
- 因此本发布包只作为项目委托方的验收构建；在用户或权利人确认授权范围之前，不应公开上传、商业分发或用于其他项目。
- 如果用户确认可分发，请把授权来源/范围补充到本文件；如果不可分发，应替换这些素材或用仅内部验收的包。

## 项目代码

项目代码采用根目录 `LICENSE`（Apache-2.0）所载条款；第三方引擎/字体/原始素材仍分别适用各自的许可与边界。
