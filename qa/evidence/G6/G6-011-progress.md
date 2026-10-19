# G6-011 技能特效、传送门、文本与设置优化

- 构建：G6-011
- 日期：2026-10-19
- 范围：灯击/净光/灯雨、传送门、开场章节、设置页、近战判定、项目包清理。
- 结论：发布候选，不是 G6 通过；用户书面验收前保持 `in_progress`。

## 1. 技能特效与传送门

参考（只取通用做法与视觉方向，没有复制素材或 shader 代码）：

- [Pixel Slash shader](https://godotshaders.com/shader/pixel-slash-shader/)：分层弧线、边缘抖动、可见弧长。
- [Pixelated Portal](https://godotshaders.com/shader/pixelated-portal/) / [Portal shader](https://godotshaders.com/shader/portal-shader-inspired-by-portal-1/)：椭圆遮罩、边缘像素化、内部层次。
- [gdquest-demos/godot-visual-effects](https://www.repoportal.com/en/gdquest-demos-godot-visual-effects) 与 [VFX 2D Free](https://godotengine.org/asset-library/asset/5496)：2D 粒子/爆点分层。
- [Godot 2D 下雨效果](https://www.snm0516.aisee.tv/video/BV1H2421Z7dJ/): 落线/地面涟漪/目标预警。

实现：

- 灯击：弧宽从 ±1.18 扩到 ±1.36，内圈新增短弧/符文，保留残影、星形、粒子和前缘高光；命中范围 22→26、角度 90°→130°。
- 净光：新增三股正弦光丝、灯口旋转符文、光晕/端点亮环；保留原有贯穿光路、端部冲击和余辉。
- 灯雨：目标处新增旋转符文、落线雨幕、地面法阵；命中后新增光柱、三重冲击环、像素水花和 8 向光点。
- 传送门：椭圆只保留内部；新增呼吸光晕、地面反射、环绕光点、开口光缝与 1.5px 上下浮动，增强虚幻/悬浮感。
- 低特效/减少动态路径保留简化版本。

截图：`G6-011-light.png`、`G6-011-rain.png`、`G6-011-melee.png`、`G6-011-portal.png`。

## 2. 开场章节对齐

开场五页原来写“第一幕…第五幕”，与游戏实际章节（序章/第一章/第二章/第三章/终章）不一致。现改为：

1. 序章 · 灯与根
2. 第一章 · 断根
3. 第二章 · 排水
4. 第三章 · 王庭
5. 终章 · 灯根

截图：`G6-011-intro.png`。

## 3. 设置页简化

- 标题改为“设置”，去掉操作说明长文、“设置会自动保存”提示和每项长解释。
- 选项缩短为：全屏、低特效、减少动态、降低闪光、屏幕震动。
- 音量标签改为“音效 / 音乐”，面板缩为 340×330。
- 截图：`G6-011-settings.png`。

## 4. 近战上下方向内侧命中

`enemy_melee_hit()` 保留前方扇形，并新增垂直朝向的近距离内侧判定：面向上/下时，`lateral <= reach*0.56`、`distance <= reach*0.86` 的贴身目标也会被灯杖内侧扫中。`test_combat` 新增 “A02 vertical swing catches inner edge”，550/0。

## 5. 项目文件清理

- 删除 G6-001～G6-010 及 G7 的过程发布目录和 zip；保留当前 G6-011、门禁审核 G2_Review/G4 Acceptance 与锁定的 `deliverables/Release`。
- 详细清单在最终清理记录中。

## 验证

- 14 组套件：campaign95/g6_release39/g4_state48/g4_boss71/g4_death5/g4_visual15/g4_presentation48/save65/enemies73/dialogue175/props2464/pressure5/route9/skip9；test_combat550、restart2/8。
- 默认 route 707.8 秒/0 死亡；跳过 607.1 秒/0 死亡。
- 实机 N4-06：BGM playing、loop_mode=1、walls=0；传送门/灯击/净光/灯雨截图已目检。

## 限制

- 特效与传送门构图、Boss BGM 听感/音量、设置页仍需用户实机确认。
- 只重跑默认/跳过路线；8/8 矩阵仍是 G6-003 历史基线。
- 20 分钟真人时长、窗口化两结局、素材/音乐许可未完成。
