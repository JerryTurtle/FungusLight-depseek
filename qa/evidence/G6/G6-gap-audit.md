# 《菌灯之下》G6 发布闭环差距审计（只读）

- 审计时间：2026-10-18（Asia/Shanghai）。
- 审计对象：工作区 `C:\Users\shandian\Documents\AI\FungusLight-depseek`。
- 代码快照：`HEAD a63e255`（`feat(g4): 近战粒子重做、导光箭头移除与敌人不回血`）＋ **未提交、审计期间仍在进行的 G4-009/G6 修复改动**（本审计快照时间 **2026-10-18 18:46:44**）。当前 dirty 文件：`game/project.godot`、`boot.gd`、`campaign.gd`、`campaign_state.gd`、`graybox.gd`、`combat_model.gd`、`world_art.gd`、`route_test.gd`、`game/data/prologue.json`、`tools/gen_g4_content.py`、`tools/test_g4_routes.py`；未跟踪 `qa/evidence/G4/G4-009-*.json|md`。**这些修复未提交、未构建、未测试，不计为已满足**；涉及行号/哈希均为该快照，后续改动后须复核（见 §0.1）。
- 审计性质：**只读**。未修改 `game/` 下任何文件，未运行游戏或测试，未写通过结论；本文件不改变 `qa/gates.json`，其 **G5、G6 仍为 `not_started`**。
- 审计依据：根 `README.md`（§1/§2/§7/§8）、`game/DEV_STATE.md`、`qa/gates.json`、`策划输出/菌灯之下_游戏开发策划方案.md`（§8.1、§9.1～§9.4、G6 行 625/636/729/744/748/756/758/762/764/774/776），以及下列代码/构建/交付物。
- 工作区证据基线：G0～G4 证据在 `qa/evidence/G0..G4`；`qa/evidence/G5`、`qa/evidence/G6` 在本次审计前均不存在（本次仅新建本文件）。
- 快照哈希（SHA256，便于复核；G4-009 未提交，后续变更会使部分哈希失效）：

| 对象 | SHA256 |
| --- | --- |
| `game/scripts/campaign.gd` | `84125878996C0B043A42FB832212F95A285D84DAC4090C67B1DB5C21A184D87C` |
| `game/scripts/boot.gd` | `D87593850D0E529ED978D8D56E53A3D4805FEEB4FF9539DA8E314780B773AAAD` |
| `game/scripts/save_store.gd` | `0CCD71B548E8E074004EF9C10083E53AF64E4C81DE3B5E72ACA7B689789827CF` |
| `game/scripts/settings_panel.gd` | `FC5711F9746451D1FA4BE6A1C121C1D3E5D5F08E9B0FBA10E366046DB3F2EE93` |
| `game/scripts/review.gd` | `0DE692D770211FDADE3B264802141C6EF55B0081D8F0B2FD0DB3E7BC13331869` |
| `game/export_presets.cfg` | `E400767963E82D9E6DB40A64CF7640ED96D206C8EB945687FDD31C91E4FFF566` |
| `tools/build.ps1` | `43B2CEC75030B81E5A01F5EE6B40A683864650D57B69A3738F3671B9877BC2AB` |
| `game/project.godot` | `90D20FA4C22D5AA5E8D41A4AAB29AA8A6F92D461F04DD9E03E8F343795518435` |
| `game/assets/licenses/SOURCES.md` | `1D1C608E1ABEDEDBC38C208ACDBA5524C50BC56AEFE6092EC59BBCCED5C3D910` |
| `qa/gates.json` | `FA8371D2FA2750E05970845AC45E2145356C73FA15CA95A137AB4DE65E5139B7` |
| `deliverables/G4-008/FungusLight.pck` | `C56C72532B531DBA54040D83DF38F4FA8E3C3E300EE1B2BB2A7FADA79CB1115C` |

标记约定：**[AI]** = AI 可用 headless/静态/包内审计验证；**[USER]** = 必须用户最终验收；**[AI+USER]** = AI 可证逻辑/静态，体验、环境或法律结论必须用户确认。等级仅用于 G6 差距管理，不代表阶段判定。

## 0. 摘要（不是通过结论）

G6 发布闭环尚未具备交付条件，且其前置 G5 尚未开始（`qa/gates.json` 的 `G5`、`G6` 均为 `not_started`）。已具备的是：G0～G4 的粗粒度技术证据、`save_store.gd` 的 65 项磁盘级存档检查、双结局/支线/跳过路线的引擎输入回放，以及可运行的 Windows 导出链。缺口集中在“发布面”：旧 `deliverables/G4-008` 包会带调试/测试/MCP 开发服务器资源；死亡菜单、键位/完整设置项、章节统计/制作名单、`deliverables/Release/{Game,Source,Docs,QA,Licenses}` 布局、发布文档/许可链与最终人工验收记录仍缺。审计期间工作区已见部分在途修复（release 入口门禁、项目名/版本、设置入口、槽位信息、结局前档，见 §0.1），但均未提交/构建/验证，本表不据此认定满足。

建议按 §9.4 归级（供 Lead 排期，不在此写通过）：

| 级别 | 数量 | 编号 |
| --- | --- | --- |
| 阻断（发布前必须清零） | 8 | B1 发布入口/调试面、B2 旧包内置 MCP autoload、B3 设置/键位不可达、B4 菜单闭环缺口、B5 交付布局缺失、B6 许可链不明、B7 G5 未开始、B8 最终人工验收记录缺失 |
| 主要 | 10 | M1 继续/槽位信息、M2 自动存档时机、M3 Esc/ending 边界、M4 HUD/日志、M5 音乐缺失、M6 导出/构建流程、M7 报告/日志路径、M8 结局统计、M9 UI 级自动化空缺、M10 打包卫生 |
| 次要 | 6 | m1 槽位原名、m2 过期文档/开发文案、m3 版本/图标、m4 目录独立度、m5 工具固定路径、m6 代码签名 |

> 说明：B2 是**现有 G4-008 包**的事实；当前 `project.godot` 已无 `[autoload]`，但本机仍存在被 `.gitignore` 忽略的 `game/autoload/mcp_interaction_server.gd`，且任何编辑器/`godot_run_project` 会话可能再次写入 autoload。发布导出必须做“导出前断言 + 导出后 PCK 审计”，不能只看源码当前状态。

### 0.1 审计期间观察到的在途修复（未提交/未验证）

审计开始后工作区出现另一路正在进行的修复。以下只记录“源码已见改动”，**不计为 G6 已满足**，必须经提交→构建→发布包→用户验收后重审：

- `boot.gd`：新增 `if not OS.is_debug_build(): → campaign`，release 导出默认进入主线，debug 导出仍保留审核台/测试入口（部分回应 A1/A2；发布包验证、campaign 内部环境钩子与 PCK 调试脚本仍待处理）。
- `project.godot`：`config/name="菌灯之下"`、`config/version="G6-001"`、新增 `config/description`（回应 A5 的一部分；仍无图标）。
- `campaign.gd`：标题改为“菌灯之下”并移除开发切片文案；新增“设置”入口（标题/暂停/F1）；无自动档时“继续”置灰；读取菜单显示槽位地点/时长并禁用空槽；结局页新增“读取结局前存档（自动备份）”；运行报告改用 `application/config/version`（部分回应 B1/B2/B3/B5/B7/D1；死亡菜单、章节记录显示、制作名单、设置项/键位仍未变）。
- `campaign_state.gd`：快照 `build_id` 改为读取 `application/config/version`。
- `route_test.gd` / `tools/test_g4_routes.py`：构建号从 G4-008 更新为 G4-009（仍写死，不是命令行参数）。
- `game/data/prologue.json`：build_id→G4-009，若干导光/火把/记录点位置调整（不改变本轮 G6 结构差距结论；G4-009 提交后需重跑内容/路线）。

上述改动与 `qa/evidence/G4/G4-009-*.json|md` 均未提交；旧 `deliverables/G4-008` 发布候选包与 `qa/gates.json` 均未更新，G5/G6 仍 `not_started`。

## 1. 逐项差距

### A. 入口与调试/测试面

| 编号 | 检查项 | 现状（已有） | 缺失 / 风险 | 级别 | 验证归属 | 建议自动化测试/命令 |
| --- | --- | --- | --- | --- | --- | --- |
| A1 | 默认入口 | `game/scenes/boot.tscn` → `boot.gd`；**审计快照已见 release 门禁**：`OS.is_debug_build()` 为假（release 导出）时直接加载 `campaign.gd` 并打印 `RELEASE_BOOT campaign`（`boot.gd:6-11`）；debug 导出/无参数仍加载 `review.gd`（G2 审核台） | 修复未提交、未导出验证；旧 `deliverables/G4-008` 仍是 review 默认；release exe 未验证；debug 导出保留审核台是预期，但发布必须只出 release 预设 | 阻断 B1-1（待验证） | **[AI]** 可测 | release 构建无参数启动（headless 可用则用），断言 stdout 含 `RELEASE_BOOT campaign`、不含 `G2_REVIEW_READY`；`grep -n "is_debug_build" game/scripts/boot.gd`；`python tools/check_release_package.py` 校验预设 |
| A2 | 发布构建隐藏/禁用调试入口 | `boot.gd` 的 release 门禁会忽略所有 demo/test 开关；但 `campaign.gd:48` 仍读 `FUNGUS_SAVE_DIR`（可重定向存档目录）、`campaign.gd:80` 仍响应 `--campaign-capture`（写环境变量指定 PNG）；`route_test.gd` 仍读 `FUNGUS_BRANCH/ENDING/M1..M4/SKIP_DIALOGUE/SIDEQUEST`；PCK 仍会打包测试/采集/审核脚本（A3） | release 门禁只覆盖 boot 入口，未覆盖 campaign 内部环境/参数钩子；若保留 `--script` 能力，包内测试脚本仍可被显式调用；需把 release-only 判定下沉到 campaign/采集代码，或从 PCK 排除这些资源 | 阻断 B1-2（部分修复） | **[AI]** 可静态+headless 测 | `grep -R "get_cmdline_user_args\|FUNGUS_" game/scripts` 对照 release 白名单；release 构建运行 `-- --campaign-capture` 断言不写文件；`check_release_package.py` 断言 PCK 无调试脚本 |
| A3 | 导出资源中的调试/测试代码 | G4-008 PCK（156 文件）包含 `.gdc`：`test_campaign/test_combat/test_dialogue/test_enemies/test_g4/test_g4_boss/test_g4_campaign/test_g4_death/test_pressure/test_props/test_review/test_save`、`route_test`、`capture_fx/capture_g4/capture_tour`、`stress_driver/stress_review`、`review/review_store`、`enemy_arena`、`asset_preview`，以及 `scenes/capture_*.tscn` | 发布包内完整携带测试/采集/审核代码与场景；即使入口隐藏，仍可被命令行或后续改动触达；不满足“隐藏并禁用”的最低要求 | 阻断 B2-1 | **[AI]** 可验证 | `python tools/check_release_package.py G6-001`（解析 PCK 文件表，断言不含上述前缀）；导出预设加 `exclude_filter="scripts/test_*、scripts/route_test.gd、scripts/capture_*、scripts/stress_*、scripts/review*.gd、scripts/enemy_arena.gd、scenes/capture_*"` |
| A4 | MCP 开发服务器 autoload | 现有 `deliverables/G4-008/FungusLight.pck` 的 `res://project.binary` 中可见 `autoload/McpInteractionServer` = `*res://autoload/mcp_interaction_server.gd`，且 PCK 含编译后的 `autoload/mcp_interaction_server.gdc`（190KB 源脚本在本机 `game/autoload/`，被 `.gitignore` 忽略） | 该包启动时会加载 MCP 交互服务（开发/调试服务）；这属于必须清除的调试入口，且是网络侧面/额外进程行为。当前源码 `project.godot` 无 `[autoload]`，但导出前若不检查，任何编辑器/`godot_run_project` 会话都可能重新加入 | 阻断 B2-2 | **[AI]** 可验证（PCK 解析+导出前断言） | 导出前 `Select-String game/project.godot '\[autoload\]'` 必须无匹配；`python tools/check_release_package.py` 断言 PCK 无 `autoload/` 且 `project.binary` 不含 `McpInteractionServer`；`.gitignore` 保留 `game/autoload/`，CI 不生成 |
| A5 | 产品标识/版本（快照已部分修复，最新见 §0.1；本行“现状”为审计初段） | `project.godot:4` `config/name="菌灯之下 · 开发验证"`；无 `config/version`、无 `config/icon`；标题打印 `G2_REVIEW_READY G2-007`；`campaign.gd:543` 写死 `"build":"G4-005"`；`review_store.gd:2` 写死 `G2-007` | 窗口标题/任务栏显示“开发验证”；无版本、无图标（Godot 默认图标）；构建号多处写死且不一致，发布追溯困难 | 主要 M3-1 | **[AI+USER]** 静态可查，图标/观感用户确认 | `check_release_package.py` 断言 `project.binary` 中 name/version/icon；`grep -R "G[0-9]-[0-9]\{3\}" game/scripts` 人工核对；发布版标题截图由用户确认 |
| A6 | 无开发机路径依赖（运行期） | `campaign.gd` 主线只使用 `res://`/`user://` 与 `FUNGUS_SAVE_DIR`；正式运行代码未见 `C:/...`；`user_storage.gd` 使用系统用户目录/exe 旁后备 | 测试/采集脚本含 `res://../qa/...`（若进发布包则形成仓库相对路径写入）；`tools/build.ps1:4` 与多数 Python 工具写死本机引擎路径（构建机限定，换机需改）；README 已声明，但发布文档需明确 | 主要 M6-1 | **[AI+USER]** 静态/PCK 可查，换机由用户 | `grep -R "C:/\|Users/\|res://\.\./qa" game --include=*.gd` 应仅测试/采集脚本；`check_release_package.py` 断言不含这些脚本；干净目录启动由用户复核 |

### B. 标题—继续—读取—存档—暂停—死亡—结局—返回标题闭环

| 编号 | 检查项 | 现状（已有） | 缺失 / 风险 | 级别 | 验证归属 | 建议自动化测试/命令 |
| --- | --- | --- | --- | --- | --- | --- |
| B1 | 标题界面 | 快照 `campaign.gd:152` 起：标题“菌灯之下”、五章/两结局文案、新游戏、继续（无自动档时置灰“暂无自动存档”）、读取存档、**设置**、退出；新游戏覆盖自动槽有确认；已移除“G3 开发切片”文案 | 仍缺“操作说明”“制作名单”“版本/构建信息”；“继续”仍固定 auto 而非“最近可恢复档”；新游戏不选空槽（固定覆盖 auto、保留手动槽）；标题未在发布包内验证 | 阻断 B4-1（部分修复） | **[AI+USER]** | `test_g6_release.gd` 断言标题菜单含 新游戏/继续/读取/设置/操作说明/退出、无“开发切片”，无 auto 时继续置灰；release 包截图用户确认 |
| B2 | 继续 / 最近档 | 快照：无 auto 时“继续”按钮 disabled 并显示“暂无自动存档”（`campaign.gd:164-170`）；`load_game("auto")` 对缺失/损坏给出恢复备份或返回菜单（`campaign.gd:384` 起） | 仍只读 auto，不扫描 manual_1～3 取最近可恢复档；auto 损坏时错误菜单未验证；“返回”落到读取菜单而非标题 | 主要 M1-1（部分修复） | **[AI]** | `test_g6_release.gd`：隔离目录构造 auto 缺失/损坏(有/无 bak)/有效四态，断言按钮状态和恢复路径；`python tools/test_save.py G6-001` |
| B3 | 读取菜单 | 快照 `show_load_menu`（`campaign.gd:434` 起）用 `slot_label()` 显示“自动存档/手动存档 N · 区域 · mm:ss”，空槽禁用；失败仍可按原因恢复/备份/返回 | 损坏但存在的槽在 `slot_label` 中因 `load_slot` 失败被显示为“（空）”，无法区分空槽与坏档；无结局/章节元数据；UI 级坏档恢复未验证 | 主要 M1-2（部分修复） | **[AI+USER]** | `test_g6_release.gd` 构造空/有效/损坏槽断言标签与禁用状态；用户复核可读性 |
| B4 | 保存入口 / 覆盖 / 双槽隔离 | `save_game`（`367` 起）将快照交 `save_store`；手动覆盖需 `confirmation_required` 确认；暂停菜单可保存到 3 个手动槽（`449` 起）；自动槽由事件/休息/切图/成长/结局写；`SaveStore` 仅写目标槽；65 项磁盘检查含“槽隔离/备份/损坏/版本/写入失败”（`game/scripts/test_save.gd`，证据 `qa/evidence/G4/G4-008-save-tests.log`） | UI 层未验证“两个存档互不覆盖”的全流程（模型层已强）；自动存档未在“清除精英/Boss 危险后”立即触发（N1-03/EL1、N4-06/Boss 清场仅写内存旗标，之后需靠下一检查点）；`safety()` 的 `no_elite_battle` 硬编码 `true`（`campaign.gd:355`） | 主要 M2-1 | **[AI]** 可测（模型+场景流程） | `python tools/test_save.py G6-001`；新增场景级：slots 交替保存→互相读取→断言不串档；新增“Boss 清场后自动档存在”断言；`grep "no_elite_battle"`（当前 `campaign.gd:355` 硬编码 true）改真实判断 |
| B5 | 暂停菜单 | 快照 `show_pause`（`449` 起）：继续、保存到 手动 1～3、读取存档、**设置**、返回标题（二次确认说明未保存影响）；`dirty` 有提示 | 仍缺“操作说明”；“退出游戏”只能返回标题再退出（可接受但需说明）；无“保存到自动槽”入口（自动槽由系统写） | 主要 M4-1（部分修复） | **[AI+USER]** 代码/文本 AI 可测，体验用户 | `test_g6_release.gd` 断言菜单项；`test_release_flow` 走暂停→保存→读取→返回标题 |
| B6 | 死亡界面 | 死亡时 `clear_menu("灯光暂熄")` + 段落 + 单一按钮“从当前区域重试”（`campaign.gd:823-826`）；`retry_from_room()` 恢复到当前房间检查点，`G4_DEATH_TEST` 5 项覆盖支路 B 重试语义 | 缺“读取存档”“返回标题”（策划 §9.1 明确要求三项）；Esc 在覆盖层 `resume()` 的语义风险（B8） | 阻断 B4-2 | **[AI]** 可测（菜单文本+流程） | `test_g6_release.gd`：构造 hp=0 → 断言死亡菜单含 重试/读取/返回标题；点击各按钮断言状态；`python tools/test_g3_slice.py G6-001`（现含 death 5 项） |
| B7 | 两结局/尾声 | `show_ending_choice`（`547` 起）要求已压制 E30，未选结局时以底部对话框显示“恢复共生/封存撤离”两项；`choose_ending`（`563`）写 `END_RESTORE/END_SEAL`+S10/S11 并保存 auto；`show_credits`（`593` 起）显示对应尾声文案、本次用时、返回标题、读取结局前存档（自动备份）/继续探索；引挚路线矩阵 A_restore/B_seal/A_alt_seal/B_alt_restore/C05/C06 8/8 通过（`qa/evidence/G4/G4-008-route-matrix.json`） | 结局页仍缺“章节记录/制作名单”（只显示 `elapsed_text`，`chapter_times` 不进界面）；`elapsed_text` 用会话时间，读档后与 `progress.seconds` 不一致；报告已改用 config version，但仍写 `user://g4_run.json`（绕过 `user_storage` 兜底）且文件名为 g4_run；发布包内两结局未验证 | 阻断 B4-3 | **[AI+USER]** 逻辑/文本/统计字段 AI 可测；结局感染力与两结局各体验一次必须用户 | `test_g6_release.gd` 断言结局页包含 用时/章节记录/返回标题/加载结局前档；`python tools/test_g4_routes.py`（需参数化 build 编号与输出路径）；新增 `test_ending_stats.gd` 验证读档后 `effective_seconds` 展示 |
| B8 | 返回标题 / 窗口关闭 | 暂停→返回标题二次确认（`419-423`）；`_notification` 窗口关闭确认，未保存提示（`campaign.gd:83` 起）；Esc 在暂停覆盖层可 `resume()`（`677` 附近） | 返回标题不写自动/不提示“最后自动档位置”；关闭窗口确认后“返回当前进度”能回对话/成长选择（已有）；Esc 在读取/死亡/结局覆盖层会直接 `resume()`，行为需按界面语义明确 | 主要 M3-2 | **[AI]** 可测 | `test_g6_release.gd`：各覆盖层 Esc 行为断言；窗口关闭流程在引擎内发 `NOTIFICATION_WM_CLOSE_REQUEST` 断言菜单 |
| B9 | 焦点丢失自动暂停 | `campaign.gd:79` 起：`focus_exited` 且 running、无覆盖层、无对话时 `show_pause()`；`resume()` 清空输入缓存与指针 | 缺设置界面时的暂停路径；没有自动化验证“重新聚焦后不自动吃掉一次攻击”；对话中失焦不额外暂停（依赖对话本身已 paused=true） | 主要 M3-3 | **[AI]** 可测（引擎内信号/状态），实际焦点切换用户 | `test_g6_release.gd`：模拟 `focus_exited`/恢复，断言 `paused`、命令清空；真机 Alt+Tab 由用户复核 |
| B10 | HUD / 任务证据 / 成长装备界面 | HUD：节点名、生命/上限、专注、药剂、时间、当前目标（`campaign.gd:833`）；Boss 状态行（`837`）；世界内名牌/小地图；成长 M1～M4、6 装备、Q1/Q2 在状态层实现 | HUD 无护盾数值/技能冷却（§9.1 明确）；无“证据与任务日志”界面（Q1/Q2、S 事件、机关状态只能靠场景/对白）；无装备/成长查看界面；`current_goal` 对白驱动但无历史回看 | 主要 M4-1 | **[AI+USER]** 字段/函数 AI 可查，界面体验用户 | `test_g6_release.gd` 断言 HUD 文本含 生命/护盾/专注/药剂/冷却/目标（按实现后）；新增 `test_journal_ui.gd`；用户复核信息可读性与遮挡 |

### C. 存档层（模型级已强，UI/发布级待补）

| 编号 | 检查项 | 现状（已有） | 缺失 / 风险 | 级别 | 验证归属 | 建议自动化测试/命令 |
| --- | --- | --- | --- | --- | --- | --- |
| C1 | 槽位/隔离/覆盖/备份/损坏/版本/写入失败 | `save_store.gd`：SLOTS=manual_1/2/3+auto；白名单字段；`is_safe` 六项严格 bool；临时文件写入+回读；旧档 `.bak`；`load_slot` 返回 `backup_available`；版本不兼容明确文案；`test_save.gd` 65 项覆盖空槽、路径穿越、安全门、四槽读写、覆盖确认、备份、槽隔离、非法版本、缺字段、药剂非法、损坏主档→备份、坏档不毁备份、临时文件、IO 失败保留旧档（证据 `qa/evidence/G4/G4-008-save-tests.log`） | 模型层不是发布级：未覆盖“UI 场景下双槽互不覆盖/坏档恢复/首次运行/读档后统计”；`no_elite_battle` 硬编码；未做断电级事务保证（README 已声明，可保留为已知限制） | 已有（模型）/主要（UI） | **[AI]** 模型可测；UI 流程新增测试 | `python tools/test_save.py G6-001`；新增 `test_g6_release.gd` 的存档段：隔离目录 + 损坏 auto + 有效 bak，走 `load_game("auto")` 菜单并断言恢复按钮 |
| C2 | 用户目录与路径 | `user_storage.gd` 依序尝试 `user://`、`LOCALAPPDATA/FungusLight/`、Documents/FungusLight/、exe 旁“用户数据/”；设置 `presentation.cfg`、存档 `saves/`、审核反馈 `reviews/G2-007/` 分开存放；`project.godot` 自定义用户目录 `FungusLight` | 运行报告 `user://g4_run.json` 绕过 `user_storage` 兜底；设置/存档/反馈同根不同子目录（严格“独立用户目录”未达成）；exe 旁后备写入需要发布文档说明；G4-008-Acceptance 已出现运行后写入的 `用户数据/saves/auto.json(+bak)` 与 `debug.log`，说明验收运行会在包目录落个人数据 | 主要 M7-1 | **[AI+USER]** 路径逻辑 AI 可测；用户机器可写性/杀软必须用户 | 新增 `test_g6_release.gd`：以临时 `APPDATA`/隔离目录启动，断言 saves/settings 落在用户目录且不落仓库；`python tools/check_release_package.py` 断言发布包无 `用户数据/`、`*.json` 个人档；用户真机复核 |
| C3 | 版本兼容/迁移 | `SCHEMA=1`；版本不符返回“存档版本不兼容”；读档失败可恢复备份；不静默清档 | 无迁移实现（策划允许“明确提示或迁移”，当前为提示）；版本号仅 `schema_version`，无游戏版本/构建关联 | 次要 m2-1 | **[AI]** 可测 | `test_save.py` 已覆盖不兼容；发布前补一条 `build_id` 不匹配策略说明 |

### D. 设置与键位（G5 范围，G6 发布必需）

| 编号 | 检查项 | 现状（已有） | 缺失 / 风险 | 级别 | 验证归属 | 建议自动化测试/命令 |
| --- | --- | --- | --- | --- | --- | --- |
| D1 | 设置入口可达性 | 快照已加入主线入口：标题“设置”（`campaign.gd:172`→`open_settings` 411）、暂停“设置”（459）、F1/ESC 处理（712 起），`on_settings_closed` 按 running 回标题/暂停；`graybox.gd`/`review.gd` 仍保留各自入口 | 修复未提交/未导出验证；设置面板内容仍只有 4 项（D2）；标题/暂停返回目标需在发布包验证；对话中 F1 被禁止（符合预期） | 阻断 B3-1（部分修复） | **[AI]** 可测（场景内 F1/菜单断言） | `test_g6_release.gd`：标题/暂停断言“设置”、模拟 F1 断言面板可见、关闭后回正确页面；`grep -n "settings" game/scripts/campaign.gd` 应非空 |
| D2 | 设置项完整度 | 低特效、减少动态、降低闪光、音效音量 4 项；`presentation.cfg` 独立保存，失败有提示 | 缺窗口/全屏、总音量/音乐音量（当前无音乐）、按键重设、恢复默认；无难度（策划不要求自增未测难度，可保持）；无“应用/取消”与窗口即时应用 | 阻断 B3-2 | **[AI+USER]** 代码/配置 AI 可测，音画体验用户 | 新增 `test_g6_settings.gd`：ConfigFile 键位齐全、非法值钳制、设置/存档独立；用户验收全屏/音量/按键手感 |
| D3 | 键位重设/冲突/恢复默认 | 全部输入写死 `physical_keycode`（18 处 `physical_keycode` 引用，`project.godot` 无 `[input]`）；没有 InputMap action | 完全缺失按键重设；要实现需先迁移到 `InputMap` 动作（移动/交互/攻击/法术/闪避/暂停/对话推进），再提供重设 UI、冲突检测、恢复默认、持久化 | 阻断 B3-3 | **[AI+USER]** 动作表/重设逻辑 AI 可测，键位手感用户 | 新增 `test_g6_settings.gd` 断言 action 集合/默认绑定/重绑持久化/冲突拒绝/恢复默认；`python tools/test_export_input.py G6-001` 回归原生输入 |
| D4 | 设置持久化/独立目录 | ConfigFile 独立文件；错误提示；`changed` 信号即时更新音效音量/低档绘制 | 快照主线已有入口；设置内容仍只有 4 项；无窗口模式持久化；`settings` 与 `saves` 同根不同子目录（见 C2）；未见发布包重启读回 | 主要 M4-2 | **[AI+USER]** | `test_g6_settings.gd` 重启式读回断言；用户重启游戏验证 |
| D5 | 暂停/焦点/输入冲突 | 焦点丢失暂停（B9）；`settings_was_paused` 恢复仅 graybox；`resume()` 清缓存 | 快照主线已加入设置路径，需验证暂停/恢复状态；对话/覆盖层 Esc 行为需按界面语义统一；焦点恢复后“不自动吃一次攻击”未自动化 | 主要 M3-3 | **[AI+USER]** | `test_g6_release.gd` 焦点/暂停/覆盖层 Esc 断言；用户 Alt+Tab 实测 |

### E. 内容/数据/资源/两结局（AI 可验证为主）

| 编号 | 检查项 | 现状（已有） | 缺失 / 风险 | 级别 | 验证归属 | 建议自动化测试/命令 |
| --- | --- | --- | --- | --- | --- | --- |
| E1 | 数据引用完整性 | 本次只读校验 `game/data/prologue.json`：37 节点、37 遭遇、16 events、9 puzzles、24 dialogue 组/52 行；出口 target 全部存在；对话/事件/机关/支线/guide 引用 0 错误；逐句有说话人与非空文本；无 TODO/占位/测试对白；最长对白 53 字（适配底部对话框 3 行预算）；`props_data.json` 含运行时道具；PCK 含 `data/prologue.json`、`assets/props/props_data.json`、FusionPixel 字体、7 个音效 | 该检查是本次审计脚本的临时校验，未落为仓库测试；无“全节点资源引用/可加载”自动断言（现有 campaign 测试只查出口 target 和最终房）；`rong/wounded` 属 `world_art` 绘制，发布包需按代码保障 | 已有（证据）/主要（自动化缺口） | **[AI]** | 新增 `tools/check_content.py`（或扩 `test_g4_campaign.gd`）遍历 37 节点：对象/id/退出落点/对话/事件/机关/道具 kind/音频文件存在；`python tools/test_g3_slice.py G6-001` |
| E2 | 两结局逻辑 | `campaign_state.set_ending/ending_id`；N4-06 结局对象需 E30；`show_ending_choice` 两项；`choose_ending` 写互斥旗标+保存；`qa/evidence/G4/G4-008-route-matrix.json` A_restore/B_seal/A_alt_seal/B_alt_restore/C05/C06 均 9 checks/0 failures（正常输入回放，非真人） | 发布包内两结局未验证；快照工具把 `build_id`/输出改为 G4-009，但仍写死、非 CLI 参数；结局后“加载结局前档”入口已加（B7）但需验证；用户必须两个结局各走一次并确认文案/氛围 | 阻断（发布验证）/主要 | **[AI+USER]** 逻辑 AI；体验必须用户 | `python tools/test_g4_routes.py`（需参数化 build/路径）；新增 `test_g6_release.gd` 分别 `choose_ending("restore"/"seal")` 断言 credits 文案/旗标/存档；用户实机各通关一次 |
| E3 | 全部地图资源 | 37 节点数据驱动；route_test 正常 487.4s / 跳过 437.5s 全主线回放；PCK 含数据/道具/字体/音效 | “全部地图资源”未做逐节点“进入并加载资源”断言；无发布包内逐节点冒烟；场景美术/碰撞/传送门用户复核 | 主要 M9-1 | **[AI+USER]** 资源可 AI 扫；地图观感用户 | 新增 `test_all_nodes.gd`：遍历 content.nodes 调 `load_room()`，断言无缺失纹理/道具/音频、出生点可走、出口落点存在；用户按 G4 验收顺序完整走图 |
| E4 | 内容完成度/音乐 | 37 节点/37 遭遇/5 章/两结局/9 机关/6 装备/2 支线；G4 用户确认约 20 分钟（README、`G4-006-progress.md` 记录）；音频仅 7 个程序音效，**无地区/Boss 音乐** | 发布版“完整游戏”仍缺音乐（G5 计划项，G6 完整交付风险）；制作名单/证据日志缺失（B7/B10）；节奏/重复感用户判断 | 主要 M5-1 | **[USER]**（音乐质量）/AI 可查资产 | `python tools/audit_project.py`（会重写 G0 清单，慎用）；新增音频清单断言；用户完整游玩与听感确认 |
| E5 | 字体与中文 UI | FusionPixel 12px（OFL，README 记录全项目缺字 0）；正文/名字/选项 24、提示 12；底部对话框 175 项测试（G3-006 起）；HUD/名牌透明+描边 | 发布版需再次确认全流程缺字、重叠、缩放可读；默认窗口 1280×720；无 UI 缩放设置 | 已有/主要 | **[AI+USER]** 缺字可脚本查，观感用户 | `test_dialogue.gd`/`test_props.gd` 回归；新增全 UI 字形覆盖测试；用户截图/实机确认 |

### F. 构建/导出/交付布局

| 编号 | 检查项 | 现状（已有） | 缺失 / 风险 | 级别 | 验证归属 | 建议自动化测试/命令 |
| --- | --- | --- | --- | --- | --- | --- |
| F1 | 导出预设 | `game/export_presets.cfg` 单预设“Windows Desktop”，`export_filter="all_resources"`，`include_filter="data/*.json"`，`exclude_filter=""`，`binary_format/embed_pck=false`，`export_path="../deliverables/G0-001/FungusLight.exe"`（陈旧），无 name/version/icon、无 custom features、无 QA/Release 双预设 | 发布包一次性带全部资源（含 A3/A4 调试脚本/MCP autoload）；陈旧 export_path 与 build.ps1 的显式路径并行，易误导出；无 release 特性标记可用于门禁；exe+pck 两文件需在文档中明确 | 阻断 B2-1 | **[AI]** 可测 | 新增 `presets/release`（exclude 调试）+ `presets/qa`（include，custom_features=qa）；`python tools/check_release_package.py G6-001` 断言预设产物 |
| F2 | 构建脚本 | `tools/build.ps1`：参数 BuildId；导入→导出 Windows Desktop→复制 `assets/licenses`→G3-* 才生成 Play-Prologue/Enemy-Arena cmd→对 exe/pck 计算 SHA256；证据日志写 `qa/evidence/<stage>` | 无“导出前门禁”（autoload/项目名/测试脚本/版本）；无 Release 目录组装、Docs/QA/Source、zip/校验清单；无 PCK 内容审计；无 release 运行冒烟；引擎路径写死本机（已文档化但换机必改） | 主要 M6-1 | **[AI]** 可测（脚本运行后断言） | `./tools/build.ps1 -BuildId G6-001` 后运行 `python tools/check_release_package.py G6-001`、`python tools/test_export_input.py G6-001`；新增 `powershell tools/package_release.ps1 -BuildId G6-001`（待建） |
| F3 | 交付布局 | 现有 `deliverables/G4-008/`（exe+pck+licenses）与 `G4-008-Acceptance/`（cmd+docs+evidence+licenses+zip）；`deliverables/Release/` **不存在** | 策划 §9.4 要求固定 `deliverables/Release/Game/`、`Source/`、`Docs/`、`QA/`、`Licenses/`；当前只有阶段验收包；无 G4 源码快照（`snapshot_source.py` 可生成，但依赖 gate-report、且输出到 `deliverables/<id>-source.zip`）；无发布 QA 目录 | 阻断 B5-1 | **[AI]** 目录/文件可测 | 新增 `tools/package_release.ps1` + `tools/check_release_layout.py`；断言五目录及必需文件（exe/pck/启动说明/工程打开位置/QA 报告/许可/哈希） |
| F4 | 打包卫生 | `G4-008-Acceptance/` 内含 `用户数据/saves/auto.json`、`auto.json.bak`、`debug.log`（运行后落入包目录；`user_storage.gd` 的 exe 旁后备所致） | 发布包/验收包不得带个人存档、机器日志、运行产物；需在干净新目录运行或先清理；这与“不提交个人档”约定一致但当前包已违反 | 主要 M10-1 | **[AI]** 可测（打包前扫描） | `check_release_package.py` 扫描 `用户数据/`、`*.json`（saves 结构）、`*.log`、`*.tmp`；打包脚本用干净临时 profile 运行后再打包 |
| F5 | 干净目录运行 | `tools/smoke_export.py` 能用隔离 `APPDATA` 启动导出包并截图（`--capture`，debug 入口）；`test_review_package.py` 做过干净目录 G2 审核包 | 无 G6 版干净目录发布冒烟（默认入口、标题、新游戏、设置、双槽、坏档、两结局）；`smoke_export` 依赖 debug `--capture`；发布包需在无仓库/无 Godot/Python 的目录验证 | 阻断 B5-2 | **[AI+USER]** 自动可测启动/路径；用户真机最终 | 新增 `tools/test_clean_release.py G6-001`：复制 Release 到临时目录→隔离 APPDATA→启动→断言用户目录产生 settings/saves、无仓库路径写入、退出码 0；用户在同机/新机复核 |
| F6 | 证据与构建关联 | `SHA256SUMS.txt`、hashes 文件、G4-008 验收 zip；`qa/evidence/G4/G4-008-route-matrix.json` | 路线矩阵工具当前写死 `build_id=G4-009` 和固定输出路径（`tools/test_g4_routes.py`，未参数化到 CLI）；`qa/evidence/G4/G4-008-checks.json` 的 `log` 字段写死 G3 路径（`qa/evidence/G3/G4-008-*.log`）；G6 需“exe/pck 哈希 + 构建号 + 证据”一一对应 | 主要 M6-2 | **[AI]** | 把 build id/输出路径参数化；`check_release_package.py` 生成 release manifest（hash/build/commit/gates）；`python tools/test_g3_slice.py G6-001` |
| F7 | 代码签名/分发形态 | 无签名配置（`codesign/enable=false`）、无安装器；exe+pck 两文件 | 用户机器 SmartScreen/杀软可能拦截；分发形态（zip/安装器/便携）未定；需用户确认；不是阻断但影响首次启动体验 | 次要 m6-1 | **[USER]** | 用户实机首次运行；如需签名/安装器由用户决定工具与证书 |

### G. 文档与许可

| 编号 | 检查项 | 现状（已有） | 缺失 / 风险 | 级别 | 验证归属 | 建议自动化测试/命令 |
| --- | --- | --- | --- | --- | --- | --- |
| G1 | 发布 Docs | `docs/g3/*`、`docs/g4/acceptance/*`（运行、操作、验收说明、checklist）；根 README（开发交接）；`G4-Acceptance.md` 含操作表/验收顺序 | 无 `Docs/` 发布文档：启动方式（exe+pck 必须同目录）、工程打开位置、设置/存档位置、故障排查、许可说明；现 acceptance 文档仍写“G4 待人工时长确认/尚未标 passed”（`G4-Acceptance.md:5`），与 gates/README 的 passed 矛盾；`G4-Checklist.md` 标题 G4-006、`G4-验收记录.md` 标题 G4-001 且未填写 | 阻断 B5-3 | **[AI+USER]** 文件存在/文本可测；说明准确性用户 | 新增 `Docs/操作说明.md`、`Docs/验收说明.md`、`Docs/已知问题.md`；`check_release_layout.py` 校验；文档一致性可脚本 grep 版本/构建号；用户按说明首次运行 |
| G2 | 发布 QA / G5/G6 证据 | `qa/evidence/G0～G4`；`qa/README.md` 仅列到 G3；`qa/gates.json` 的 G5/G6 `not_started`；G5 范围（全量回归、音频/音乐、设置/键位、难度、资源清理、性能）无证据 | 无 G5 报告/性能 10 分钟负载/G6 发布验证；`qa/README.md` 未更新 G4～G6；发布 QA 目录缺失；G5 未完成则 G6 不经 G5 直接做属跳跃 | 阻断 B7-1 | **[AI]** 文件/门禁可测 | `python -c` 读 gates 断言 G5/G6 状态；G5 完成后运行 `python tools/stress_review.py G6-001`、`replay_framerates.py`、`test_g3_slice.py`；补 `qa/evidence/G5|G6` 报告与索引 |
| G3 | 许可链 | `game/assets/licenses/`：FusionPixel-OFL、NotoSansSC-OFL、SOURCES.md、FusionPixel-components（ark/cubic/galmuri 许可）；根 `LICENSE` Apache-2.0；音频为程序生成；SOURCES 记录 Godot MIT 来源 | **原始 `Fungus Cave [16x16]` Characters/Tilesets 明确“原目录未附许可…不声称已获得商业分发许可”**（SOURCES.md:3,11），props 的家具裁切继承该状态；发布 `licenses/` 未含 Godot MIT/COPYRIGHT 全文、未含项目 LICENSE；审核台 Noto 字体与 FusionPixel 的随包关系需 Docs 说明 | 阻断 B6-1 | **[AI+USER]** 文件/文本 AI 可查；授权有效性与分发范围必须用户/权利人确认 | `check_release_package.py` 断言 `Licenses/` 含 项目 LICENSE、Godot COPYRIGHT/MIT、字体 OFL、SOURCES；用户确认原素材授权或替换/限定用途；不得由 AI 代替授权结论 |
| G4 | 来源/生成记录 | SOURCES.md 分项登记；`qa/asset_manifest.json`（G0）记录原图尺寸/哈希/许可待核实；生成音频/道具说明 | 生成器版本/哈希未进发布 Docs；素材来源与发布包哈希未绑定；原文授权结论不可由 AI 生成 | 主要 M6-3 | **[AI+USER]** | 生成 release manifest（包含 SOURCES 哈希/生成器版本/资源清单）；用户确认 |
| G5 | 文档版本一致性 | README 快照 2026-10-18、DEV_STATE 2026-10-18、`qa/gates.json` 顶层 `build_id` 仍为 `G2-007`；G4 `evidence.iteration=G4-008` | 顶层 build_id 未随 G4/G6 更新；campaign/campaign_state 已改读 config version，`review_store.gd` 仍 G2-007（审核台）；旧验收文档（G4-Acceptance/Checklist/验收记录）标题/结论过期；审计期间 G4-009 未提交；发布前需统一版本/构建号/日期 | 主要 M6-3 | **[AI]** | `grep -R "G[0-9]-[0-9]\{3\}"` 人工/脚本核对；发布 manifest 单一数据源 |

### H. 发布验证清单（G6 要求 → 当前状态）

策划 §9.4/G6 原文要求逐项对照：

| G6 验证项 | 当前状态 | 缺口/下一步 | 归属 |
| --- | --- | --- | --- |
| 发布入口/调试入口 | 快照 boot release 门禁已加（待发布包验证）；旧 G4-008 包仍是审核台默认 | A1/A2：release 包无参数断言 RELEASE_BOOT、PCK 无调试脚本；campaign 内部 env/参数钩子待处理 | AI+用户 |
| 干净解压目录首次启动 | **未验证（release）**；G4-008 验收包曾在包目录运行并写入 `用户数据/`、`debug.log` | F5：发布包复制到空目录+隔离 APPDATA 启动；用户真机首次启动 | AI 部分/用户最终 |
| 新游戏 | 已有（`new_game`+苏醒，G4 引擎测试）；快照标题覆盖自动槽确认、手动槽保留 | 发布入口修复后重测；新游戏选空槽未实现（B1）；用户实机 | AI+用户 |
| 设置保存 | 快照主线已加“设置”入口（标题/暂停/F1）；设置面板仍仅 4 项、无键位 | D1/D2/D3/D4：入口验证+完整设置+键位+持久化；重启复验 | AI+用户 |
| 两个存档互不覆盖 | 模型 65 项强；UI 未验 | C1/B4：UI 双槽流程+坏档；用户实机 | AI+用户 |
| 损坏档恢复 | 模型有（备份/恢复按钮代码）；快照读取菜单显示槽位/禁用空槽，坏档仍显示为“（空）”；UI 未见测 | C1/B2：continue/读档坏档流程；用户实机 | AI+用户 |
| 暂停/重试 | 快照暂停含设置/保存/读取/返回标题；死亡仍仅重试 | B6：死亡补读取/返回标题；用户实机 | AI+用户 |
| 全部地图资源 | 数据引用 0 错误（本次审计）；路线回放覆盖主线 | E3：逐节点加载/资源断言；用户完整走图 | AI+用户 |
| 两结局 | 逻辑/路线矩阵已有；快照结局页增加“读取结局前存档（自动备份）”；发布包内未验 | E2/B7：发布构建两结局+章节记录/制作名单；用户各通关一次 | AI+用户 |
| 反馈/日志路径 | 运行报告写 `user://g4_run.json`（绕过兜底）；设置/存档分路径；审核反馈仅审核台 | C2/M7：统一用户目录、可写性、反馈路径（若保留）；用户确认 | AI+用户 |
| 无开发路径依赖 | 主线运行代码仅 res/user；测试/采集脚本含 `../qa`（应排除）；构建工具含本机引擎路径 | A6/B2：PCK 排除+干净目录；文档写明换机改工具路径 | AI+用户 |
| 两结局/存档/设置/重试/资源全可用 | 见上 | 上述全部清零后用户验收 | 用户 |
| 用户最终验收明确通过 | **无结构化记录**：`gates.json` G4 无 `human_approval`；G4 验收文档未填写/结论过期；README/DEV_STATE/G4-006-progress 仅文字声称用户确认 20 分钟 | 建立 `qa/G6-approval.md`（构建号/exe+pck 哈希/日期/逐项结论），gates 增 `G6.human_approval`；用户书面确认后才可称交付完成 | 用户 |

## 2. AI 可验证 vs 必须用户最终验收

### 2.1 AI 可验证（headless/静态/包内解析，无需用户操作）
- 入口路由与 release 门禁：`OS.is_debug_build()` 分支的 release 行为（无参数→campaign，`RELEASE_BOOT campaign` 标记）；参数/环境变量白名单；PCK 文件表/`project.binary` 解析（本审计已用只读方式验证过旧 G4-008 包的内置 autoload 与调试脚本）。
- 包内容纯净：无 `autoload/`、无 `test_*/route_test/capture_*/stress_*/review*/enemy_arena/asset_preview`、无 `用户数据/`/`*.log`；含 `data/prologue.json`、`assets/props/props_data.json`、字体、音效。
- 数据/资源：37 节点引用、出口 target、对话/事件/机关/支线、props kind、音频/字体存在、无 TODO/占位。
- 存档模型：`test_save.gd` 65 项（已有）；UI 场景下的槽位隔离/坏档恢复/首次运行（建议新增）。
- 菜单/状态闭环（场景 headless）：标题/暂停/读取/死亡/结局的按钮文本与状态；双结局旗标/尾声文案/统计字段；返回标题；窗口关闭确认；Esc/焦点行为。
- 设置模型：设置项集合、ConfigFile 独立写入/读回、键位 action 集合/重绑/冲突/默认。
- 构建与布局：导出预设字段、release 目录五件套、启动说明/工程打开位置存在、SHA256/构建号/证据关联。
- 字体缺字扫描、全节点资源加载（建议新增）。
- 现有证据回归：`test_g3_slice.py`（campaign/save/enemies/dialogue/props/pressure/route/skip）、`test_g4_routes.py`（两结局/支线/跳过矩阵）、`test_export_input.py`（原生输入 118）、`replay_framerates.py`、`test_review.py`（审核台，若保留）。

### 2.2 必须用户最终验收（AI 不可替代）
- 在用户 Windows 机器上，从干净目录双击发布包首次启动；安装/解压/杀软/SmartScreen/权限可写性。
- 完整游玩（≥20 分钟有效主线）的节奏、内容量、难度、可读性；两结局各完整走一次并确认文案/氛围/统计。
- 双槽实际保存/读取互不覆盖、坏档恢复、覆盖确认、返回标题/退出提示的可用性与安全感。
- 设置/键位/音量/全屏/低特效/减少动态的实际手感与重启保持；Alt+Tab 焦点暂停不吞输入。
- 视觉（UI 遮挡/字体/像素/动画）、听觉（音效；音乐若补）、H2 已审动作/握持/时序/相机/特效体验未被破坏。
- **许可与分发范围**：原始 Fungus Cave 素材授权（或替换/限定个人使用）、字体 OFL 与引擎 MIT 随包、项目 LICENSE；是否允许商业分发。
- 发布形态（zip/安装器/便携）、代码签名、分发渠道。
- **最终书面验收**：构建号+包哈希+日期+逐项结论，写入 `qa/G6-approval.md` 与 `qa/gates.json` 的 `G6.human_approval`；AI 不得代写/代签。

## 3. 建议的自动化测试命令（新增项标“待建”）

现有工具（未在本次只读审计中执行；执行会写 `qa/evidence`，由 Lead 在对应构建上运行）：

```powershell
# 全量场景/状态/存档/对话/道具/压力/路线（按 G6 编号输出证据）
python tools/test_g3_slice.py G6-001

# 双结局/支线/第二章双顺序/整段跳过矩阵（当前快照写死 G4-009；需参数化 build id 与输出路径）
python tools/test_g4_routes.py

# 存档 65 项（模型层）
python tools/test_save.py G6-001

# 原生导出输入/场景（先构建相同编号；当前依赖 --integration 调试入口）
./tools/build.ps1 -BuildId G6-001
python tools/test_export_input.py G6-001

# 审核台回归（若发布仍保留审核台资源；建议发布包剔除后改为 QA 构建运行）
python tools/test_review.py G6-001

# 30/60/144 渲染回放一致
python tools/replay_framerates.py G6-001

# 10 分钟代表负载（G5/G6 性能证据）
python tools/stress_review.py G6-001

# 导出包启动冒烟（当前带 --capture 调试入口；G6 版建议仅默认入口+隔离 APPDATA）
python tools/smoke_export.py G6-001

# 发布入口回归（release 预设导出后）：无参数启动应进入 campaign/标题，
# 期望 stdout 含 RELEASE_BOOT campaign，不得出现 G2_REVIEW_READY/G2_READY；
# 传入 --enemy-arena/--campaign-capture 等应被 release 门禁忽略（待补断言）。
.\deliverables\G6-001\FungusLight.exe --quit-after 120
```

建议新增（待建）：

```powershell
# 1) 发布包/PCK 审计：入口、调试资源、autoload、个人数据、必需资源、Licenses/Docs/QA/哈希
python tools/check_release_package.py G6-001
python tools/check_release_layout.py G6-001

# 2) G6 发布流程 headless 回归：标题/继续/读取/双槽/坏档/暂停/死亡/两结局/返回标题/设置/键位
python tools/test_release_flow.py G6-001
#   内部执行：godot --headless --path game --script res://scripts/test_g6_release.gd
#   （settings/键位断言可拆到 scripts/test_g6_settings.gd）

# 3) 干净目录发布冒烟：复制 Release 到临时目录，隔离 APPDATA，默认入口启动并断言用户路径
python tools/test_clean_release.py G6-001

# 4) 全节点资源/引用/加载：遍历 37 节点断言资源、出生点、出口落点、对话/事件/机关/道具/音频
python tools/check_content.py

# 5) 导出前门禁（防止 MCP autoload/开发名/调试脚本进入包）
powershell -File tools/preflight_release.ps1 -BuildId G6-001
```

发布验证顺序（建议）：G4-009 提交并回归 → G5 完成（音频/音乐、设置/键位、全量回归、性能）→ 修复本审计 B 级阻断 → 构建 release 预设 → PCK/布局/干净目录自动化 → 引擎路线回归（含两结局/跳档）→ 用户实机验收（填写 G6 记录）→ gates 更新为 awaiting_review/passed 仅在用户明确通过后。

## 4. 必须用户确认后放行的关键结论

1. **发布入口**：默认双击进入游戏标题，不再进入审核台；调试/测试入口在 release 中不可达。
2. **包纯净**：PCK 不含 MCP autoload、测试/采集/审核/竞技场脚本，不含个人存档/日志。
3. **设置/键位**：标题与暂停都能打开设置；窗口/全屏/音量/低特效/减少动态/闪光有效；按键可重设、冲突提示、恢复默认、重启保持。
4. **菜单闭环**：标题（新游戏/继续/读取/设置/操作说明/退出）→ 游戏中暂停（保存/读取/设置/返回标题）→ 死亡（重试/读取/返回标题）→ 结局（恢复/封存、有效时长/章节记录、返回标题、加载结局前档）→ 返回标题，全部可用。
5. **存档**：双槽互不覆盖、覆盖确认、坏档提示并恢复备份、版本不兼容不崩溃不清档。
6. **交付物**：`deliverables/Release/Game|Source|Docs|QA|Licenses` 齐全，含启动方式与工程打开位置、QA 报告、来源许可、哈希。
7. **许可**：原始素材授权/替换结论由用户确认；字体/引擎/项目许可随包。
8. **人工验收记录**：用户明确通过 G6 构建（构建号+exe/pck 哈希），写入批准文件后，才可对外称交付完成。

## 5. 审计限制

- 本审计仅做只读文件检查与 PCK 只读解析（读取 G4-008 的 `FungusLight.pck` 文件表与 `project.binary`），**未启动 GUI 游戏、未运行现有测试**；建议命令均未执行，执行证据需另存新编号。
- 审计期间工作区持续 dirty（本审计收尾快照 2026-10-18 18:46:44；11 个文件被另一路 G4-009/G6 修复修改，另有未跟踪 `qa/evidence/G4/G4-009-*.json|md` 与本次 `qa/evidence/G6/`）。该在途修复未提交、未构建、未测试，本文只把其标注为“部分修复（待验证）”，不改变 G5/G6 门槛状态；后续提交后需按新哈希/行号复核。
- 本文不对游戏质量、许可有效性或“完整游戏”作通过结论；`qa/gates.json` 未修改，G5/G6 仍为 `not_started`。
- 未做真人可玩性、音乐听感、键位手感、两结局体验、干净机器/杀软与商业分发授权判断；这些必须由用户最终验收。
