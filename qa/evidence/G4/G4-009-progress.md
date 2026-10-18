# G4-009 进度报告

- 日期：2026-10-18
- 构建：G4-009
- 状态：完成本轮五项反馈修复；G4 保持通过。G6 发布开发随后开始。
- 基线：G4-008 已推送（`a63e255`）。本轮不改变 20 分钟时长目标。

## 完成内容

1. 初燃（净光）粒子停留延长、增加余烬与短震屏；移除后段过大的灰色圆环。
2. 灯杖灯头加入深色灯罩、暖色玻璃与动态火焰/火星。
3. 导光间已对准光束加宽、加亮，保留无箭头方向提示。
4. 全 37 节点重叠审计与修复；标签在对话/暂停/标题隐藏，并避开小地图/状态栏。
5. 四分之一像素角色渲染 + 显示刷新率插值，修复向右行走的整像素跳变感；补修卡死返回仍回血的遗漏。

## 验证

- 全量引擎套件：campaign 88、g4_state 34、g4_boss 8、g4_death 5、g4_visual 12、save 65、enemies 35、dialogue 175、props 2450、pressure 5、route 9、skip_route 9，失败 0。
- 路线：正常 484.6 秒、跳过 434.2 秒，0 死亡。
- 静态重叠审计：37 节点视觉/碰撞/出生点/标签风险 0。
- 截图：标题、营地、火焰、初燃释放、初燃余烬、导光间、N1-07、N2-08。
- 未做：真实显示器手感复核、玩家对火焰/震屏强度的主观确认；这些留给用户试玩。

## 文件

- 代码：`game/scripts/graybox.gd`、`world_art.gd`、`campaign.gd`、`combat_model.gd`、`boot.gd`、`campaign_state.gd`、`route_test.gd`、`game/data/prologue.json`、`tools/gen_g4_content.py`、`tools/audit_overlaps.py`、`game/scripts/test_g4_visual.gd`。
- 证据：`qa/evidence/G4/G4-009-*`。
