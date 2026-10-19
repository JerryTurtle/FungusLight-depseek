# G6-010 传送门、墙壁、Boss BGM 与指引分隔符

- 构建：G6-010
- 日期：2026-10-19
- 范围：全场景传送门/出口、房间墙位、N4-06 Boss 战 BGM、顶部指引。
- 结论：发布候选，不是 G6 通过；用户书面验收前保持 `in_progress`。

## 1. 传送门只保留椭圆

- `tools/gen_props.py` 的 `portal_base()` 只绘制椭圆开口与 K 轮廓，删除石质门框、门楣、侧柱、门槛和门框符文。
- 重新生成 `props_data.json`；`sealed` 3 帧、`open` 5 帧均无外框。
- `campaign.draw_portal()` 的碰撞/通行提示不变；截图 `G6-010-portal.png` 与 `G6-010-boss.png` 可见只有椭圆与内部光幕。

## 2. 墙壁更少、位置更多样；Boss 房无墙

- 37 个房间全部重新排墙：多数房间由 2～4 面墙降为 **0～1 面**，按房间序号保留不同的原墙（左/右、上/下），不再所有房间共用同一组柱子。
- N1-02、N2-10、N3-05 因路线机器人稳定性和旧测试交互，保留原墙；其余房间大幅让空。
- **N4-06 核心室与 N4-07 尾声：walls = []**，Boss 战不再有内部墙。
- 默认 route 752.2 秒/0 死亡；整段跳过 651.4 秒/0 死亡。

## 3. Boss 战 BGM

- 新增 `game/assets/audio/boss_theme.wav`：29.09 秒、44.1kHz、立体声、原创合成管弦/铜管/定音鼓/军鼓，D 小调、132 BPM，循环段。
- `combat_audio.gd` 新增 `music` 播放器，`LOOP_FORWARD`；`play_boss_music()`/`stop_music()`。
- `campaign.update_boss_music()`：进入 N4-06 播放，离开/回标题停止；设置面板的音效音量同时控制 BGM。
- 实机检查：N4-06 `music.playing=true`、`loop_mode=1`、Boss 房 walls=0。
- 证据 `G6-010-bgm.json`；音频 SHA256 `342CAD66…61E26D28`。

## 4. 顶部指引分隔符

- 顶部 `hud.text` 从 `章节 / 房间` 改为 `章节  .  房间`；截图 `G6-010-boss.png` 中显示“终章 · 灯根  .  核心室”。

## 验证

- 14 组套件：campaign95/g6_release39/g4_state48/g4_boss71/g4_death5/g4_visual15/g4_presentation48/save65/enemies73/dialogue175/props2464/pressure5/route9/skip9；test_combat549、restart2/8。
- `test_g6_release` 新增 Boss BGM 加载/循环断言，39/0。
- PCK 审计将 `assets/audio/boss_theme.wav` 列入必需文件。

## 限制

- 只重跑默认/跳过路线；8/8 矩阵仍是 G6-003 历史基线。
- 所有房间墙位、椭圆传送门、Boss BGM 音量/听感、顶部 `.` 仍需用户实机确认。
- 20 分钟真人时长、窗口化两结局、原始素材/生成图许可未完成。
