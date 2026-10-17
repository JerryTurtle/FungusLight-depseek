# G3-007 UI/素材反馈修正与切片复验

日期：2026-10-17。构建：G3-007。对应玩家反馈八项：字体缺字、文字背景、绒名字位置、粒子过飘、尸体不消失、矿工刻字位置、矿道墙壁贴图、导光方向不可读。

## 八项修正

| # | 反馈 | 处理 | 证据 |
| --- | --- | --- | --- |
| 1 | 像素字体“燃”等字无法显示 | 原方舟像素字体实测缺 12 个常用字（即、奖、执、擎、然、燃、窗、紫、聚、苔、药、避），改用同为 TakWolf 的**缝合像素字体 Fusion Pixel 12px**（SIL OFL 1.1）；全项目文本缺字 0，`燃`等已正常显示 | `test_dialogue` 新增字形覆盖断言；`G3-007-storage.png`、`G3-007-choice.png` |
| 2 | 像素字体背景应为透明 | 世界物件名牌与顶部 HUD 去掉深色底框，改为 4px 深色描边 + 透明底；HUD 面板 alpha 归零，文字直接叠在场景上 | `G3-007-camp.png`、`G3-007-storage.png` |
| 3 | “绒”字覆盖人物 | 绒的名字锚点单独设为头顶上方，不再使用默认物件锚点 | `G3-007-rong-label.png` |
| 4 | 粒子过于飘逸，要安静/静谧 | 孢子/尘埃/余烬数量减半（孢子12→7、尘埃8→5、余烬5→3），上浮与横移速度放慢 2～3 倍，透明度降至 0.32～0.45；家具光效同步降亮，灯光呼吸幅度减小；低特效/减少动态规则保留 | `G3-007-guides-unsolved.png` 等截图；`test_props` 2059 项 |
| 5 | 敌人尸体应延时消失 | 新增尸体停留 210 tick（3.5 秒）后 45 tick 淡出，然后不绘制；T1/T2/T3/T4/EL1 与孢囊、教学靶均适用 | `G3-007-corpse-visible.png` → `G3-007-corpse-gone.png`；`test_campaign` 新增立即显示/延迟淡出/最终消失三项 |
| 6 | 矿工刻字应先清敌、位置应在出口旁 | 将 N1-01“矿工刻字”从 (74,60) 移到东侧出口旁 (278,146)；交互仍需安全状态（清敌后），读字后即可出门 | `G3-007-lore-exit.png`；路线回放走该点 |
| 7 | 墙壁下没有瓦片贴图 | 矿道墙原来使用图集 (4,36)（带黑/水面的窗格），整面墙呈黑块；改为完整砖墙格 (2,1)，墙壁上下都有贴图 | `G3-007-lore-exit.png`、`G3-007-guides-unsolved.png` |
| 8 | 导光装置旋转方向不明显 | 未对准时也始终绘制高亮短光束与箭头（方向即当前朝向），光束从灯头而不是脚底发出；名牌追加当前方向“（上/右/下/左）”，三座装置保留各自颜色 | `G3-007-guides-unsolved.png` 与 `G3-007-guides-solved.png` |

## 验证

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| 序章/切片状态与引擎接线 | 132 项通过 | `G3-007-campaign-tests.log` |
| 存档磁盘/恢复/坏档 | 65 项通过 | `G3-007-save-tests.log` |
| 敌人专项 | 35 项通过 | `G3-007-enemies-tests.log` |
| 对话框（含字形覆盖） | 175 项通过 | `G3-007-dialogue-tests.log` |
| 交互物/粒子 | 2059 项通过 | `G3-007-props-tests.log` |
| 正常输入快速路线 | 8 项通过；84.6 秒、23 段、0 死亡 | `G3-007-route.json`、`G3-007-route-tests.log` |
| 汇总 | 6/6 通过，失败 0 | `G3-007-checks.json` |
| 原生导出集成 | 118 项通过 | `G3-007-integration.json/.log` |
| 审核台导出回归 | 50 项通过 | `G3-007-review/checks.json` |
| 30/60/144 回放 | 360 步一致，暂停冻结 | `G3-007-framerate-summary.json`、`G3-007-replay-*` |
| 导出包画面 | `FungusLight.exe -- --campaign --campaign-capture` 与源码画面一致 | `G3-007-package-camp.png` |

包：`deliverables/G3-007`（`Play-Prologue.cmd` / `Enemy-Arena.cmd`）。PCK 哈希 `E41BA53D36FBEEB1CC9E3C29101979450A574A54C95A7CD1F6680C7F9327B297`；EXE 仍为同一 Godot 运行时 `66B26A...AB7B13`。

截图：`G3-007-title/camp/storage/rong-label/lore-exit/dialogue/choice/guides-unsolved/guides-solved/corpse-visible/corpse-gone/package-camp.png`。

## 字体与许可

- `assets/fonts/FusionPixel12px-zh_hans.ttf`：Fusion Pixel Font 12px 简体中文，SIL OFL 1.1，版权 TakWolf，版本 2026.10.16；来源 https://github.com/TakWolf/fusion-pixel-font 。
- 许可全文 `FusionPixel-OFL.txt`；上游组件许可（Ark Pixel、Cubic 11、Galmuri）随包在 `FusionPixel-components/`。
- 导入关闭抗锯齿、hinting、子像素定位；游戏字号只使用 12/24/36。G2 审核台继续使用 Noto Sans SC。

## 未完成与不可宣称

- G3 仍为 `in_progress`：10～15 分钟人类首次游玩时长未实测；T3/精英主线连续应用、A15 全场景压力、整段跳过与奖励联动回读、真人验收仍缺。
- 本轮截图为真实窗口渲染；路线是引擎输入注入（非 OS 键鼠），对白停留为模型化，不能替代真人试玩。
- 交互物与“安静粒子”的观感由截图验证，仍需玩家最终确认；若仍偏飘可继续降低 counts/alpha，但不改变战斗信息可读性。
- 遭遇字段仍为 7 项，G3-005 旧开发档会被显式拒绝。
