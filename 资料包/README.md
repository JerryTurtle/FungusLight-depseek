# 《菌灯之下》交付资料包

**版本：** v1.0.0 / G6-012　|　**日期：** 2026-10-19　|　**平台：** Windows 64 位

本目录按用户要求整理为三部分，**编号即阅读/使用顺序**：

| 顺序 | 目录 | 内容 | 入口 |
| --- | --- | --- | --- |
| 1 | [01-游戏安装包](01-游戏安装包/) | 可运行的完整游戏发布包（免安装 zip，解压即玩） | [安装与运行说明](01-游戏安装包/安装与运行说明.md) |
| 2 | [02-作品说明文档](02-作品说明文档/) | 作品说明（玩法、环境、依赖、操作）+ AI 工具使用说明 | [作品说明](02-作品说明文档/作品说明.md)、[AI工具使用说明](02-作品说明文档/AI工具使用说明.md) |
| 3 | [03-源码压缩包](03-源码压缩包/) | 完整源码 zip（含 AI 开发交互过程记录与汇总） | [源码包说明](03-源码压缩包/源码包说明.md)、[AI交互过程记录](03-源码压缩包/AI交互过程记录/) |

## 快速开始

1. 解压 `01-游戏安装包/FungusLight-G6-012-Release.zip` 到任意可写目录。
2. 双击 `Game/开始游戏.cmd`（或 `Game/FungusLight.exe`）。
3. 操作：WASD 移动，鼠标左键灯击、右键净光，1 护灯、2 灯雨，空格闪避，E 交互，Q 观察，R 药剂，Esc 暂停。
4. 不需要安装 Godot、Python 或任何运行库；不需要联网。

## 目录结构

```text
资料包/
├── README.md                        本文件
├── SHA256SUMS.txt                   两个发布 zip 的 SHA256
├── 01-游戏安装包/
│   ├── FungusLight-G6-012-Release.zip   正式 Windows 发布包（81,622,223 字节）
│   └── 安装与运行说明.md
├── 02-作品说明文档/
│   ├── README.md
│   ├── 作品说明.md                  玩法/运行环境/依赖/操作/已知问题/校验
│   └── AI工具使用说明.md            模型与工具、辅助环节、人机分工、生成内容清单
└── 03-源码压缩包/
    ├── 源码包说明.md
    ├── FungusLight-G6-012-Source.zip    源码 + 文档 + 证据 + AI 记录
    ├── SHA256SUMS.txt
    └── AI交互过程记录/
        ├── README.md
        ├── 与AI交互内容-汇总.md         54 轮合并汇总（先读）
        ├── AI交互列表-35组.md
        ├── 开发历史-G0到G3-001.md
        ├── 与AI交互内容-策划.md
        ├── 与AI交互内容-1.md
        ├── 与AI交互内容-2.md
        └── 与AI交互内容-3.md
```

## 校验

| 文件 | SHA256 | 大小 |
| --- | --- | --- |
| `01-游戏安装包/FungusLight-G6-012-Release.zip` | `FCEC62C9CCD11759AF30E8532C72AD26B31D1608BA186390DAC8969D20EB25BF` | 81,622,223 字节 |
| `03-源码压缩包/FungusLight-G6-012-Source.zip` | `B5BFB567FA086AE07F27591EE664FA22A8E68B25E6C62640606508419F11543F` | 23,980,308 字节（22.87 MiB） |

```powershell
Get-FileHash .\01-游戏安装包\FungusLight-G6-012-Release.zip -Algorithm SHA256
Get-FileHash .\03-源码压缩包\FungusLight-G6-012-Source.zip -Algorithm SHA256
Get-Content .\SHA256SUMS.txt
```

发布包内 exe/pck 哈希、逐项清单见 `01-游戏安装包` 内 `QA/SHA256SUMS.txt` 与 `qa/evidence/G6/G6-012-final-package.txt`。

源码包：1,329 个文件（解压后 55,196,682 字节，含目录项），源快照 `8513034`；包含 `game/`、`tools/`、`docs/`、`qa/`（文本证据）、`策划输出/`、`交付文档/`、`AI交互记录/`，排除截图与缓存；完整清单见包内 `SOURCE-MANIFEST.txt`。

## Git 管理

- `资料包/` 下的说明文档、两个发布 zip 与校验文件均纳入 Git（Conventional Commits 提交）。
- 发布包的**解压目录** `deliverables/G6-012-Release/`、`deliverables/G6-012/` 等构建产物仍按项目约定不提交，只保留本地。
- 源码 zip 可由 `python tools/package_delivery.py` 从已跟踪文件重建；脚本会校验游戏 zip 哈希并重写两个 `SHA256SUMS.txt`。
- 历史标签：`v1.0.0`；G6 验收记录：`qa/G6-approval.md`；包位置迁移记录：`qa/evidence/G6/G6-012-package-move.md`。

## AI 与人工分工（摘要）

- **AI（DeepSeek Harness / DSH + DeepSeek 系模型）** 完成策划执行、代码、关卡、美术整合、音频合成、自动化验证、打包与文档。
- **图像生成/识图** 使用 Gemini 后端的 image/vision 桥接，生成标题背景与开场五幕，并用于查看实机截图。
- **人类** 提出需求与 12 轮试玩反馈，完成 H2、G4、G6 三次人工审核；G6 已签署通过。
- 详细模型/工具清单与边界见 [AI工具使用说明](02-作品说明文档/AI工具使用说明.md)。

## 重要边界

- **无安装器/无代码签名**：发布形态为便携 exe + pck，SmartScreen 可能提示未知发布者。
- **原始素材与生成图许可未确认**：`Fungus Cave [16x16]`、标题/开场生成图与 Boss BGM 的再分发范围需用户或权利人确认；在确认前请仅用于本项目验收，不要公开商业分发。
- **自动时长 ≠ 真人时长**：默认自动路线 707.7 秒、跳过 607.4 秒，不代表 20 分钟真人体验；G6 通过来自用户签署，不是 AI 自评。
- **G5 单独阶段被跳过**：无地区音乐、无完整按键重设；详见作品说明 §7。

## 相关入口

- 源码仓库：`https://github.com/JerryTurtle/FungusLight-depseek`（`origin`，标签 `v1.0.0`）
- 发布说明：`deliverables/FINAL-RELEASE.md`
- 阶段门槛：`qa/gates.json`
- 人工验收：`qa/H2-approval.md`、`qa/G4-approval.md`、`qa/G6-approval.md`
