# G6-009 全局移除三色记录台素材

- 构建：G6-009
- 日期：2026-10-19
- 范围：N2-08 泵站控制室、N3-02 供给回廊；以及 `puzzle_console` 素材定义。
- 结论：发布候选，不是 G6 通过；用户书面验收前保持 `in_progress`。

## 修改

- 从 N2-08 删除 `p06_choice`「两处测量点」。
- 从 N3-02 删除 `p07_choice`「三段供给管线」。
- 全局审计：`puzzle_console` 只在这两个场景（以及 G6-008 已删除的 N1-06）使用；删除后数据中已无该 visual。
- 同时删除 `prop_art.gd` 中 `puzzle_console` 的 `CUSTOM_PROPS` 条目、标签偏移和绘制分支，移除 `props_data.json` / `gen_props.py` 的 `puzzle_choice -> puzzle_console` 别名，防止该素材再出现。
- P06 仍由 `v07`/`v08` 两个阀门完成；P07 仍由 `v09`/`v10`/`v11` 三个阀门完成；出口门槛 `M3&P06&S07`、`P07` 不变。没有删除谜题或改变主线门槛。
- `test_g4_campaign` 95/0 覆盖 P03/P06/P07 的阀门完成路径；默认 route 734.6 秒/0 死亡，跳过 635.4 秒/0 死亡。
- `test_props` 由 2470 降至 2464；已同步 `tools/test_g3_slice.py` 期望。

## 验证

- 14 组套件：campaign95/g6_release38/g4_state48/g4_boss71/g4_death5/g4_visual15/g4_presentation48/save65/enemies73/dialogue175/props2464/pressure5/route9/skip9；test_combat549、restart2/8。
- 截图 `G6-009-pump.png`（N2-08）与 `G6-009-supply.png`（N3-02）：原三色记录台位置已空出。

## 限制

- 只重跑默认/跳过路线；8/8 矩阵仍是 G6-003 历史基线。
- 泵站控制室、供给回廊画面与 P06/P07 阀门仍需用户实机确认。
- 20 分钟真人时长、窗口化两结局、素材许可未完成。
