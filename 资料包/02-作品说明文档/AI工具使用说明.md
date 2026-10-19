# 《菌灯之下》AI 工具使用说明

> 说明本作品在开发、验证、打包与文档环节使用了哪些 AI 模型/工具、各自承担什么工作、人类如何参与，以及相关边界。本文只记录可核对的事实；仓库未逐轮记录模型版本号的部分，不虚构具体版本。

## 1. 总览

《菌灯之下》采用"AI 全流程开发 + 人类验收"的协作方式：

- **AI 承担：** 策划执行、系统设计、代码、关卡与剧情数据、美术整合与生成、音频合成、自动化测试、构建与打包、文档与 Git 提交。
- **人类承担：** 提出与修订需求、试玩反馈（G3～G6 共 12 轮）、H2/G4/G6 人工审核与签字验收。
- **交接机制：** 每轮以 Conventional Commits 提交并推送；`README.md`、`game/DEV_STATE.md`、`qa/gates.json` 与策划文首快照保持一致，任何 AI 模型可按文档接续。

## 2. 使用的模型与工具

### 2.1 核心 AI 环境

| 工具 / 模型 | 版本或标识 | 在项目中的用途 |
| --- | --- | --- |
| **DeepSeek Harness（DSH）** | 本会话运行环境 **0.2.1-rc.2** | AI 编码智能体的运行/工具编排环境；提供文件、终端、Git、Godot、图像等工具 |
| **DeepSeek 大语言模型** | 本会话模型标识 **`deepseek-flash`**；开发期逐轮版本未写入仓库 | 需求理解、方案设计、GDScript/Python 编写、测试分析与修复、文档撰写 |
| **DSH 会话日志** | `docs/与AI交互内容-2.md` 注明用户输入取自 DSH 会话日志 | 交互过程记录、用户原话提取、可追溯性 |

> 说明：项目开发横跨多个会话与额度周期，仓库只保留了"DSH 会话"这一层证据，没有逐轮保存模型版本号或推理参数。本文因此只把"DSH + DeepSeek 系模型"作为可核对结论，不声称某一条具体回复来自某个确切版本。

### 2.2 图像与视觉

| 工具 / 模型 | 配置或标识 | 用途 |
| --- | --- | --- |
| **图像生成模型（Gemini 后端）** | 本机 vision-imagen 桥接配置：`provider = gemini`，`imageModel = gemini-3.1-flash-image-preview` | 生成标题背景 `title_bg.png` 与开场五幕插画 `scene_01_cavern`～`scene_05_core` |
| **多模态视觉模型（Gemini 后端）** | `visionModel = auto` | 查看实机截图、对比特效/UI/场景、检查生成图是否符合像素风要求 |
| **项目内图像后处理** | Python 3.13 + Pillow 11.3.0（非 AI 模型） | 裁切 16:9、缩至 320×180、96 色量化、最近邻放大到 1280×720 |

> 说明：历史生成批次的具体模型版本/提示词未逐张写入仓库，只保留了"由图像生成模型生成，经项目内裁切、调色与 96 色量化"的来源登记（`Licenses/ASSET-RIGHTS.md`、`Licenses/SOURCES.md`）。生成图不包含第三方素材，但其再分发范围仍需用户确认。

### 2.3 工程与验证工具链

| 工具 | 版本 / 说明 | 用途 |
| --- | --- | --- |
| **Godot Engine** | 4.3 stable（`4.3.stable.official.77dcf97d8`），GL Compatibility | 游戏运行时与编辑器；headless 测试、导出、性能采样 |
| **Godot Windows 导出模板** | 4.3 stable | 生成 `FungusLight.exe` / `FungusLight.pck` |
| **GDScript** | Godot 4.3 | 游戏逻辑、战斗、关卡、UI、存档、测试驱动 |
| **Godot MCP 交互服务** | `game/autoload/mcp_interaction_server.gd`（开发期，发布包与源码包均排除） | 开发期读取场景树、截图、注入输入、检查运行时状态 |
| **Python** | 3.13.4 | 素材/音效生成、批量测试驱动、发布检查、哈希与清单 |
| **Pillow** | 11.3.0 | 像素道具、HUD 图标、生成图处理 |
| **PowerShell** | Windows PowerShell / pwsh | `tools/build.ps1`、`tools/package_release.ps1` 等构建与打包 |
| **Git / GitHub** | 仓库 `JerryTurtle/FungusLight-depseek`；发布时 89 次提交、标签 `v1.0.0`（资料包整理另计） | 版本管理、功能分支、提交/推送、发布 |
| **网络检索** | G6-011 期间的公开资料检索（Godot Shader、特效演示等） | 仅参考视觉方向，不复制素材或代码；出处记录在 README |

## 3. AI 参与的具体环节

| 阶段 | AI 做的工作 | 主要产物 / 证据 |
| --- | --- | --- |
| 策划与需求分析 | 分析 79 张原始素材、确认本机 Godot 4.3、给出 3 版玩法方向（回合 → 即时 → 单角色俯视动作 RPG）、补齐动作/成长/剧情/验收规格 | `策划输出/菌灯之下_游戏开发策划方案.md`；策划聊天 8 轮记录 |
| 素材复核 | 逐帧检查角色图集、地图拼接、放大版差异，建立切片/脚底锚点/用途分配 | `策划输出/素材清单.json`、`素材复核.json`、逐帧复核图；`qa/evidence/G0/asset_manifest.json` |
| 工程与架构 | 建立 Godot 工程、60Hz 固定步战斗模型、数据驱动动作/敌人/关卡、存档契约、审核台 | `game/project.godot`、`game/data/*.json`、`game/scripts/*.gd` |
| 战斗系统 | 八向移动、四向灯击、净光/护灯/灯雨、闪避、护壳/破壳、孢毒/毒区、同帧互击与稳定结算 | `combat_model.gd`、`campaign_combat.gd`、`actions.json`；`test_combat` 550 项 |
| 敌人与 Boss | T1～T6、EL1/EL2、2200 HP 三阶段母体、预警几何与阶段转换 | `enemies.json`、`test_enemies` 73 项、`test_g4_boss` 71 项 |
| 关卡与剧情 | 5 章 37 节点 37 遭遇、9 个机关、S01～S10/L01～L20、两结局、证据门禁 | `prologue.json`、`campaign.gd`、`campaign_state.gd`；route/skip 各 9 项 |
| 美术生产 | 自绘像素道具/粒子/传送门/UI 图标；生成并量化标题与开场插画；统一像素风与碰撞体 | `prop_art.gd`、`props_data.json`、`gen_props.py`、`gen_hud_assets.py`、`game/assets/title|intro` |
| 音频 | Python 确定性合成 7 个音效 + 1 首 29.09 秒循环 Boss BGM，无第三方采样 | `tools/generate_sfx.py`、`game/assets/audio/*.wav`、`G6-010-bgm.json` |
| 自动化验证 | 模型测试、原生导出输入、30/60/144 帧回放、A15 压力、存档 65 项、跨进程读档、路线矩阵、干净目录启动、PCK 审计 | `qa/evidence/G0`～`G6`（1,993 份文件）；`qa/gates.json` |
| 发布与打包 | 五目录布局、PCK 审计、哈希、发布说明、清场、Git 标签 | `deliverables/G6-012-Release/`、`qa/evidence/G6/G6-012-*` |
| 文档与交接 | README/DEV_STATE/策划快照同步、已知问题、操作说明、AI 交互记录整理 | `README.md`、`game/DEV_STATE.md`、`docs/`、本资料包 |

## 4. 人机分工与审核机制

| 角色 | 职责 |
| --- | --- |
| 人类（项目方） | 提出需求与修改意见；试玩并反馈 12 轮 G6 问题；在关键节点做通过/不通过判断；签署验收 |
| AI（DSH 编码智能体） | 在授权范围内实现、测试、修复、打包；如实记录失败与限制；不代替人类签字或伪造验收 |

**三个硬性人工审核点：**

1. **H2（G2 后动作/特效审核）**：用户 2026-10-17 明确表示"H2 已通过，无问题"；记录见 `qa/H2-approval.md`。
2. **G4（完整主线时长/体验）**：用户确认 20 分钟目标并同意 G4 通过；记录见 `qa/G4-approval.md`。
3. **G6（最终发布验收）**：用户在 `qa/G6-approval.md` 勾选"通过"并签名 `JeryTurtle`（日期按原文 2026.10.49）；`qa/gates.json` 据此将 G6 标为 `passed`。

**AI 不得做的事（项目中已执行）：** 不代填/代签人工验收、不把自动测试当真人体验、不在失败时写通过、不删除历史证据、不提交个人存档/日志。

## 5. AI 生成内容清单

| 类别 | 内容 | 生成方式 | 位置 |
| --- | --- | --- | --- |
| 代码 | GDScript 52 个文件约 12,211 行；Python/PowerShell 工具 31 个 | AI 编写 | `game/scripts/`、`tools/` |
| 数据 | 动作、敌人、37 节点/遭遇、剧情/机关/奖励/存档配置 | AI 编写 JSON | `game/data/` |
| 像素道具/特效/UI | 自绘道具 137 帧、家具裁切 15 种、6 类环境粒子、HUD 图标、传送门/灯击/净光/灯雨特效 | 项目代码/Python 程序化绘制 | `prop_art.gd`、`props_data.json`、`gen_props.py`、`gen_hud_assets.py` |
| 生成图 | 标题背景 1 张、开场五幕 5 张（1280×720） | 图像生成模型 + 项目内量化 | `game/assets/title/`、`game/assets/intro/` |
| 音频 | 7 个音效 WAV + 29.09 秒 Boss BGM | Python 确定性合成 | `game/assets/audio/`、`tools/generate_sfx.py` |
| 文档 | README、DEV_STATE、操作/验收/已知问题、策划、交互记录 | AI 撰写，人类审阅 | `README.md`、`docs/`、`策划输出/`、本资料包 |

## 6. 过程记录与可追溯性

| 记录 | 内容 | 位置 |
| --- | --- | --- |
| 54 轮交互汇总 | 策划 8 轮 + 开发 25/41/7 条记录合并为 54 轮，用户要求保留原意、AI 回复简写 | `docs/与AI交互内容-汇总.md`（资料包内同名副本） |
| 原始聊天记录 | `与AI交互内容-策划.md`、`-1.md`、`-2.md`、`-3.md` | `docs/`；资料包 `03/AI交互过程记录/` |
| 35 组交互列表 | 按会话阶段归纳的请求/回应/结果表 | `docs/history/AI-interaction-log.md` |
| 开发历史 | G0～G3-001 的详细开发过程 | `docs/history/development-through-G3-001.md` |
| 逐轮验证证据 | 测试日志、JSON 报告、截图、哈希、验收记录 | `qa/evidence/G0`～`G6`（1,993 份） |
| 阶段门槛 | G0～G6 状态、证据路径、人工批准 | `qa/gates.json` |
| 当前交接 | 已实现清单、边界、下一步、动作参数、存档契约 | `README.md`、`game/DEV_STATE.md`、策划文首快照 |

## 7. 验证与证据链

- **自动化规模：** G6-012 共 14 组引擎套件 0 失败（campaign 95、g6_release 39、g4_state 48、g4_boss 71、g4_death 5、g4_visual 15、g4_presentation 48、save 65、enemies 73、dialogue 175、props 2464、pressure 5、route 9、skip 9），另有 `test_combat` 550、跨进程 restart 写 2/读 8。
- **路线：** 默认 707.7 秒 / 0 死亡；整段跳过 607.4 秒 / 0 死亡；8/8 矩阵（G6-003 历史基线）619.3～728.3 秒。
- **发布检查：** PCK 只读审计、五目录布局、干净目录 headless 启动、Game 目录无个人存档/日志、SHA256 绑定。
- **性能基线：** G2-007 900 秒负载，标准/低档平均 59.90/60.00 FPS，节点 112 稳定，最后 5 分钟私有内存 364.02～364.66 MiB（历史构建基线）。

## 8. 可复现性与复现建议

1. 用 Godot 4.3 stable 导入 `game/project.godot`，或直接解压发布包运行 `Game/FungusLight.exe`。
2. 需要修改素材时，先读 `tools/README.md` 与对应生成脚本；`gen_props.py`、`generate_sfx.py`、`gen_hud_assets.py` 是确定性生成器，依赖 Python 3.13 + Pillow 11.3。
3. 改战斗先跑 `python tools/test_combat.py`；改存档跑 `test_save.py`；改内容跑 `python tools/test_g3_slice.py <新编号>`；导出前跑 `tools/build.ps1 -BuildId <新编号>`。
4. 不要直接运行 `tools/finalize_g2.py`：它会重写历史报告/门槛。`tools/` 中部分脚本含本机绝对引擎路径，换机需逐项核实。
5. 发布前按 `qa/evidence/G6/G6-012-release-organization.md` 与 `tools/check_release_package.py` 复核 PCK、布局与哈希。

## 9. 边界与声明

- **模型版本：** 本文记录的是"可核对的环境 + 工具"，不是逐轮模型调用审计；未在仓库出现的版本号不做推断。
- **生成内容版权：** AI 生成图的版权/再分发范围需由用户或权利人确认；原始 Fungus Cave 素材许可未核实，本项目仅作验收构建。AI 不能代替权利人作出授权结论。
- **自动化不等于真人验收：** 自动测试使用 headless/引擎输入注入，不能替代真实键鼠、显示器刷新率、音频设备与人为观感判断；G6 的通过来自用户签署，而非 AI 自评。
- **无个人数据：** 本资料包与源码包不包含个人存档、日志、账号、密钥或本机绝对路径（历史证据中的原环境绝对路径保持原样，仅作记录）。
- **AI 的角色：** AI 是开发工具与执行者；作品的立项、需求、验收与发布决定由人类作出。

## 10. 相关文件

- [作品说明（简版）](作品说明.md)
- [源码包说明](../03-源码压缩包/源码包说明.md)
- 源码包内 `AI交互过程记录/`：54 轮汇总、原始记录、35 组交互列表、开发历史
- 源码包内 `qa/evidence/`：逐轮测试与验收证据
- `qa/gates.json`、`qa/H2-approval.md`、`qa/G4-approval.md`、`qa/G6-approval.md`：阶段状态与人工批准
