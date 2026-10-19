# 《菌灯之下》交付资料包

**版本：** v1.0.1 / G6-013（兼容性修复）　|　**日期：** 2026-10-20　|　**平台：** Windows 32 位 / 64 位

本目录按用户要求整理为三部分，**编号即阅读/使用顺序**：

| 顺序 | 目录 | 内容 | 入口 |
| --- | --- | --- | --- |
| 1 | [01-游戏安装包](01-游戏安装包/) | 可运行的完整游戏发布包（免安装 zip，解压即玩；含 32/64 位双构建） | [安装与运行说明](01-游戏安装包/安装与运行说明.md) |
| 2 | [02-作品说明文档](02-作品说明文档/) | 作品说明（玩法、环境、依赖、操作）+ AI 工具使用说明 | [作品说明](02-作品说明文档/作品说明.md)、[AI工具使用说明](02-作品说明文档/AI工具使用说明.md) |
| 3 | [03-源码压缩包](03-源码压缩包/) | 完整源码 zip（含 AI 开发交互过程记录与汇总） | [源码包说明](03-源码压缩包/源码包说明.md)、[AI交互过程记录](03-源码压缩包/AI交互过程记录/) |

## 快速开始

1. 解压 `01-游戏安装包/FungusLight-G6-013-Release.zip` 到任意可写目录。
2. 双击 `Game/开始游戏.cmd`：64 位系统自动选 `64/FungusLight.exe`，32 位系统自动选 `FungusLight.exe`（默认 32 位构建）；首次失败会自动再尝试 ANGLE/D3D11。也可直接双击 `Game/FungusLight.exe`（32/64 位 Windows 均可运行）。
3. 操作：WASD 移动，鼠标左键灯击、右键净光，1 护灯、2 灯雨，空格闪避，E 交互，Q 观察，R 药剂，Esc 暂停。
4. 不需要安装 Godot、Python 或任何运行库；不需要联网。老显卡黑屏可用 `Game/兼容模式启动.cmd`，仍失败运行 `Game/系统检查.cmd`。

## 兼容性修复（G6-013）

- 新增 Godot 官方 x86_32 构建，32 位 Windows 不再因 64 位 exe 无法加载而直接失败；默认主 exe 为 32 位，64 位在 `Game/64/`。
- 智能启动器自动选架构；原生 OpenGL 失败时自动重试 `--rendering-driver opengl3_angle`（ANGLE/D3D11）。
- 新增 `兼容模式启动.cmd`、`系统检查.cmd`、启动信息/诊断文件；发布前验证 ANGLE 与原生 GL 标题截图逐像素一致。
- 窗口按屏幕可用区缩放居中；≤2 线程/老 iGPU 首次运行自动低特效/减少动态。
- 玩法、H2 动作/握持/命中范围、剧情与 G6-012 用户签署内容不变。详见发布包 `Docs/兼容性说明.md`。

## 目录结构

```text
资料包/
├── README.md                        本文件
├── SHA256SUMS.txt                   G6-013 游戏 zip + 源码 zip 的 SHA256
├── FungusLight-Gameplay-演示视频.mp4  G6 实机演示（97.3 秒，1280×720，含音轨）
├── 01-游戏安装包/
│   ├── FungusLight-G6-013-Release.zip   当前正式包（32/64 位，135,786,194 字节）
│   ├── FungusLight-G6-012-Release.zip   历史签署包（G6-012，81,622,223 字节，保留审计）
│   └── 安装与运行说明.md
├── 02-作品说明文档/
│   ├── README.md
│   ├── 作品说明.md                  玩法/运行环境/依赖/操作/已知问题/校验
│   └── AI工具使用说明.md            模型与工具、辅助环节、人机分工、生成内容清单
└── 03-源码压缩包/
    ├── 源码包说明.md
    ├── FungusLight-G6-013-Source.zip    当前源码 + 文档 + 证据 + AI 记录（24,007,687 字节）
    ├── FungusLight-G6-012-Source.zip    历史源码包（保留审计）
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
| `01-游戏安装包/FungusLight-G6-013-Release.zip` | `09C16BE205C60B584BFFB6323F7B2F9408E0017BB4FA18134A9D9F487B17FA47` | 135,786,194 字节（129.5 MiB） |
| `03-源码压缩包/FungusLight-G6-013-Source.zip` | `863A5629883CA5A4255523EE3E6CCDCEFA2FE1AF6C9A035FD9635811544B93D8` | 24,007,687 字节（22.90 MiB） |
| `FungusLight-Gameplay-演示视频.mp4` | `E79E7940036909C348E0282709D34B5428BCFBBFC2DE5B5B42337580F9162C32` | 41,836,200 字节（39.90 MiB） |

演示视频为 G6-012 实机录制（H.264 1280×720/60fps + AAC 音轨，97.3 秒），G6-013 未改玩法画面，继续有效。校验：

```powershell
Get-FileHash .\01-游戏安装包\FungusLight-G6-013-Release.zip -Algorithm SHA256
Get-FileHash .\03-源码压缩包\FungusLight-G6-013-Source.zip -Algorithm SHA256
Get-FileHash .\FungusLight-Gameplay-演示视频.mp4 -Algorithm SHA256
Get-Content .\SHA256SUMS.txt
```

发布包内 32/64 位 exe/pck 哈希、逐项清单见 `01-游戏安装包` 内 `QA/SHA256SUMS.txt` 与根 `qa/evidence/G6/G6-013-final-package.txt`。

源码包：1,346 个文件（解压后 55,252,758 字节，含目录项），源快照 `b5502b2`；包含 `game/`、`tools/`、`docs/`、`qa/`（文本证据）、`策划输出/`、`交付文档/`、`AI交互记录/`，排除截图与缓存；完整清单见包内 `SOURCE-MANIFEST.txt`。

## Git 管理

- `资料包/` 下的说明文档、两个当前发布 zip（游戏 + 源码）、历史 G6-012 zip、实机演示视频与校验文件均纳入 Git（Conventional Commits 提交）。
- **Git LFS：** 135.8 MB 的完整游戏 zip 超过 GitHub 单文件 100 MB 限制，只有该文件使用 Git LFS 跟踪（`.gitattributes` 已配置）。克隆/拉取前请安装 `git-lfs` 并执行 `git lfs install`；源码 zip、历史 G6-012 zip 与演示视频仍为普通 Git 文件。
- 发布包的**解压目录** `deliverables/G6-013-Release/`、`deliverables/G6-013/`、`deliverables/G6-013-32/` 等构建产物按项目约定不提交，只保留本地。
- 源码 zip 可由 `python tools/package_delivery.py` 从已跟踪文件重建；脚本会校验游戏 zip 哈希并重写两个 `SHA256SUMS.txt`。
- 历史标签：`v1.0.0`（G6-012）；G6-012 验收记录：`qa/G6-approval.md`；G6-013 兼容性验收模板：`qa/G6-013-approval.md`（待用户填写）；包位置迁移记录：`qa/evidence/G6/G6-012-package-move.md`。

## AI 与人工分工（摘要）

- **AI（DeepSeek Harness / DSH + DeepSeek 系模型）** 完成策划执行、代码、关卡、美术整合、音频合成、自动化验证、打包与文档。
- **图像生成/识图** 使用 Gemini 后端的 image/vision 桥接，生成标题背景与开场五幕，并用于查看实机截图。
- **人类** 提出需求与多轮试玩反馈，完成 H2、G4、G6-012 三次人工审核；G6-012 已签署通过；G6-013 兼容性包待 32 位/老电脑实机验收。
- 详细模型/工具清单与边界见 [AI工具使用说明](02-作品说明文档/AI工具使用说明.md)。

## 重要边界

- **无安装器/无代码签名**：发布形态为便携 exe + pck，SmartScreen 可能提示未知发布者。
- **32 位/老电脑兼容边界**：Windows XP 不受支持；Windows 7/8.1 为 best-effort；32 位进程 2 GB 地址空间；只有 D3D9、无 D3D11 的显卡仍无法通过 ANGLE 启动。详见 `Docs/兼容性说明.md`。
- **原始素材与生成图许可未确认**：`Fungus Cave [16x16]`、标题/开场生成图与 Boss BGM 的再分发范围需用户或权利人确认；在确认前请仅用于本项目验收，不要公开商业分发。
- **自动时长 ≠ 真人时长**：G6-012 默认自动路线 707.7 秒、跳过 607.4 秒，不代表 20 分钟真人体验；G6 通过来自用户签署，不是 AI 自评。
- **G5 单独阶段被跳过**：无地区音乐、无完整按键重设；详见作品说明 §7。

## 相关入口

- 源码仓库：`https://github.com/JerryTurtle/FungusLight-depseek`（`origin`，标签 `v1.0.0`）
- 发布说明：`deliverables/FINAL-RELEASE.md`
- 阶段门槛：`qa/gates.json`
- 人工验收：`qa/H2-approval.md`、`qa/G4-approval.md`、`qa/G6-approval.md`、`qa/G6-013-approval.md`（待填）
