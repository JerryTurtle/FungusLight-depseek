# G3-006 序章—菌洞切片、像素 UI 与交互物专项

日期：2026-10-17。构建：G3-006（源码与包一致；包哈希见 `G3-006-hashes.txt`，PCK `FB83BA...C8314B`，EXE 仍为同一 Godot 运行时 `66B26A...AB7B13`）。

## 本轮完成

1. **像素中文字体**：接入 SIL OFL 1.1 的方舟像素字体（Ark Pixel 12px，简体中文，2026.10.16 版），关闭抗锯齿、hinting 与子像素定位；游戏 UI 字号统一为 12 的整数倍（24/36）。G2 审核台继续使用 Noto Sans SC，保持 H2 已审工具排版不变。
2. **底部 RPG 对话框**：新增 `game/scripts/dialogue_box.gd`，对白固定在画面下部（1280×720 时面板 (48,504,1184,176)），含名字牌、逐字打字机、▼ 闪烁、`E / 回车 / 空格 / 左键` 推进、`Tab` 跳过、M1 二选一同框选项页；选项页不能跳过，不会替玩家代选。原居中菜单仅保留标题/暂停/读档/切片边界。
3. **交互物像素化与待机动效**：新增 `tools/gen_props.py`、`game/assets/props/props_data.json`、`game/scripts/prop_art.gd`。灯座/宝箱/门/水管/灯环/导光装置/矿门改为自绘像素素材；床铺/箱柜/木箱/书架/纸张/菌丛/火把/墙面装置直接复用原图集 `Complete.png` 裁切；叠加火光、缝隙呼吸光、尘埃、孢子、滴水、余烬、灯池等 6 类粒子与 3～6 帧待机动画。低特效减半、减少动态冻结、降低闪光降亮。修复“床铺视觉套用到矿口安全灯座”的映射问题，恢复点为灯具/床两种视觉。
4. **菌洞切片扩展**：新增 N1-01 菌洞入口与 N1-02 导光间（数据 `prologue.json`）：
   - N1-01：矿口安全灯座、矿工刻字（L01 回声）、E04（T1×2＋T2×1，投孢者首次进入主线）。
   - N1-02：E05（T1×2）、E06（T5×2）、三座导光装置 P02（E 转向、beam 连通、全部对准才开门）；断灯线回声 L02；切片边界移到菌根深处。
   - 遭遇改为数据驱动生成；新增出生点避让（不生成在玩家身上）与重叠脱困保护；非法旧坐标不再硬编码于代码。
5. **正常输入路线回放**：新增 `game/scripts/route_test.gd` 与 `tools/test_g3_slice.py`。路线把全部操作以 `Input.parse_input_event + flush` 注入引擎（WASD、E、Q、左/右键、R、空格、鼠标位置），按真实 60Hz 固定步推进，不传送、不直接写旗标/奖励。
6. **兼容与证据**：新增 `campaign.tscn`、`capture_tour.tscn` 等开发入口；`test_campaign` 扩展到 126→129 项（A16 对话冻结/恢复、阻断存档），保存快照扩展 P02/E04～E06。

## 验证证据

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| 序章/切片状态与引擎接线 | 129 项通过 | `G3-006-campaign-tests.log` |
| 存档磁盘/恢复/坏档 | 65 项通过 | `G3-006-save-tests.log` |
| 敌人专项（T2/T3/T4/T5/EL1） | 35 项通过 | `G3-006-enemies-tests.log` |
| 对话框组件 | 167 项通过 | `G3-006-dialogue-tests.log` |
| 交互物素材/粒子 | 2089 项通过 | `G3-006-props-tests.log` |
| 正常输入快速路线 | 8 项通过；模拟 89.6 秒、23 段、0 死亡、min HP 66、12 次闪避、1 次治疗 | `G3-006-route.json`、`G3-006-route-tests.log` |
| 汇总 | 6/6 通过，失败 0 | `G3-006-checks.json` |
| 原生导出集成 | 118 项通过（Godot 视口事件，非 OS 键鼠） | `G3-006-integration.json/.log` |
| 审核台导出回归 | 50 项通过 | `G3-006-review/checks.json` |
| 30/60/144 回放 | 360 物理步一致，暂停冻结 | `G3-006-framerate-summary.json`、`G3-006-replay-*` |

截图：`G3-006-title/camp/storage/dialogue/choice/dialogue-lore/mine-corridor/mine-entrance/light-room-enemies/light-room-solved/light-room-open.png`。
素材合成与逐件预览：`qa/evidence/G3/props/`（`props_world_mock.png` 为首选）。

## A15～A18 / C01 / C03 覆盖

- **A16 对话/暂停**：对话打开时模拟冻结、安全存档被拒绝、跳过/关闭后恢复推进，已由 `test_campaign` 与对话框自测覆盖；暂停冻结沿用 30/60/144 回放。
- **A17 存档/资源**：存档 65 项 + 序章快照字段一致性；新增 P02、E04～E06 快照校验与读档后导光装置恢复。
- **A18 切片闭环**：快速路线在真实引擎输入下完成 N0-01→N1-02，教学、机关、剧情、战斗、自动存档均在同一条路线内；路线记录分段耗时。
- **C01 里程碑**：M1 跳过/重复/读档不重复发奖仍由 `test_campaign` 覆盖。
- **C03 演出恢复**：逐句跳过、窗口关闭取消、选项页恢复对话/选项均已覆盖；未做整段 Tab 跳过的独立引擎用例（组件层已覆盖 Tab 信号）。

## 未完成与不可宣称

- **A15 全场景压力**：仅覆盖所有节点出生点/交互点可达与角色在窄口中的实际移动；动态门、环形障碍、多波拥堵与离屏攻击压力仍缺专项。
- **10～15 分钟时长**：本轮 AI 快速路线 89.6 秒（含 0.9 秒/句模型化对白停留），不是人类首次游玩时间；按策划节点预算估算的人类时长尚未实测。G3 不能宣称已满足 10～15 分钟。
- **T3/精英主线应用**：本轮只把 T2 接入主线；T3 曾在试验中加入 E06 后因路线稳定性回退，T3/EL1 仍在敌人专项场，需在后续关卡配置与压力测试中再接入。
- **存档兼容性**：遭遇字段从 4 项扩为 7 项，G3-005 旧开发档会被判为未知字段/不一致而拒绝；这是开发构建的显式失败，不是坏档静默迁移。
- **真人验收**：本轮没有启动交互式真人试玩；截图为真实窗口渲染，操作证据来自引擎输入注入，不能替代 OS 键鼠/真人体验。
- 对话框仍未做立绘、历史回看与语音；审核台刻意保留 Noto Sans SC。

## 文件

新增：`game/scripts/dialogue_box.gd`、`test_dialogue.gd`、`prop_art.gd`、`test_props.gd`、`route_test.gd`、`capture_tour.gd`、`game/assets/props/props_data.json`、`tools/gen_props.py`、`tools/test_g3_slice.py`、`game/scenes/campaign.tscn`、`capture_tour.tscn`。
修改：`game/scripts/campaign.gd`、`campaign_state.gd`、`test_campaign.gd`、`game/data/prologue.json`、`game/project.godot`（仅字体/无 autoload）、`game/scenes/boot.gd`、`graybox.gd`、`review.gd`、`settings_panel.gd`、`.gitignore`。
字体许可与来源：`game/assets/licenses/ArkPixel-OFL.txt`、`SOURCES.md`。

## 下一项（G3-007）

1. 扩展矿道有效内容与遭遇配置，按真实人类操作记录分项时间，目标达到 10～15 分钟，不靠拖速/加血。
2. 将 T3（以及经策划允许的精英原型）接入连续主线与窄口/活动区/A15 压力；补动态门与环形障碍。
3. 补整段跳过、奖励/任务/资源联合回读、坏档显式恢复的引擎级用例；导出包再做一次真人可读入口与截图。
4. 更新门槛与接续快照前，G3 保持 `in_progress`。
