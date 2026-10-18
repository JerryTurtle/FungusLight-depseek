# G6-001 发布候选进度报告

- 日期：2026-10-18
- 构建：G6-001
- 状态：**AI 发布验证完成，等待用户最终验收**。G6 在 `qa/gates.json` 保持 `in_progress`，不称整款游戏已交付完成。
- 依据：用户要求完成 G4-009 五项修复后直接进入 G6；G5 单独阶段按用户指示跳过，发布必需的回归/设置/打包并入本轮，音乐与完整按键重设列为已知边界。

## 完成内容

1. G4-009 五项修复（初燃余烬/轻震、灯头火焰、导光光束、37 节点重叠、四分之一像素+刷新率插值移动）已提交并推送 `0cce256`。
2. 发布入口：`boot.gd` 以 `OS.is_debug_build()` 区分；release 默认主线并打印 `RELEASE_BOOT campaign`，忽略 `--enemy-arena/--review-test/--campaign-capture` 等调试开关；debug 构建保留 G2 审核台。
3. PCK 剔除：测试、采集、审核、压力、replay、enemy arena、main/asset_preview 场景、MCP autoload 与 review manifest；发布 PCK 仍含数据/字体/音效/主场景。
4. 闭环：标题（新游戏/继续置灰/读取/设置/退出/构建号）、暂停（保存 3 槽/读取/设置/返回标题）、死亡（重试/读取/返回标题）、两结局（统计/制作信息/返回标题/读取结局前自动备份）、读取菜单槽位时间与空槽禁用、坏档备份恢复。
5. 设置：全屏、低特效、减少动态、降低闪光、音效音量；ConfigFile 独立持久化。当前不提供按键重设。
6. 运行报告改到 `user_storage` 的 `run_report.json`；结局页显示章节记录。
7. 交付布局：`deliverables/Release/{Game,Source,Docs,QA,Licenses}` + zip；Source 去缓存/去 MCP autoload；Licenses 含项目 Apache-2.0、Godot MIT、字体 OFL、素材来源与再分发边界。
8. 发布包无个人存档/日志；干净目录、路径含空格的启动通过。

## 验证结果

| 项 | 结果 |
| --- | --- |
| 全量引擎套件 | campaign 88、g6_release 31、g4_state 34、g4_boss 8、g4_death 5、g4_visual 12、save 65、enemies 35、dialogue 175、props 2450、pressure 5、route 9、skip_route 9；失败 0 |
| 路线矩阵 | A_restore/B_seal/A_alt_seal/B_alt_restore/C05/C06/sidequests/skip 8/8；正常 484.6 秒、跳过 434.2 秒、0 死亡 |
| 导出 QA 原生集成 | 118/118 |
| G2 审核台 | 50/50（QA 构建，保留 H2 基准） |
| 导出 QA G6 流程 | 31/31（标题/双槽/坏档/死亡/两结局/设置持久化） |
| 30/60/144 回放 | 360 步逐 tick 一致；30.00/60.00/144.37 实测 |
| 发布 PCK 审计 | 必需资源齐、无 test/capture/review/autoload/MCP/开发路径 |
| 干净目录启动 | 通过；`RELEASE_BOOT campaign`，无调试入口、无个人文件、无截图副作用 |
| 布局/哈希 | 五目录、Docs/Licenses/QA/SHA256SUMS 完整；Game exe/pck 哈希匹配 |

## 发布物

- 目录：`deliverables/Release/`
- 压缩包：`deliverables/FungusLight-G6-001-Release.zip`
- exe SHA256：`66B26AD96DF7458EA917B632A73AC7C88BB058DB24DBD11A457FD50435AB7B13`
- pck SHA256：`7D6C3402A7A780566066FEF499BC72DB6728AA8C9B25CF1F755DBA7B20506DAA`
- zip SHA256：以最终重打包后的 `qa/evidence/G6/G6-001-final-package.txt` 为准

## 限制与待用户验收

- G5 单独阶段跳过：无地区/Boss 音乐、无完整按键重设；只有 7 个程序音效。
- 原始 Fungus Cave 素材再分发许可未确认；当前包按项目验收用途交付，公开/商业分发前必须由用户或权利人确认。
- 自动验证不是真人键鼠/显示器/音频/Alt+Tab 体验；20 分钟为用户已确认目标，不是 60 分钟。
- 用户需按 `docs/g6/release/验收说明.md` 完成干净目录两结局/双槽/坏档/设置/全地图体验，并在 `qa/G6-approval.md` 书面确认。确认前 G6 不标 passed。
