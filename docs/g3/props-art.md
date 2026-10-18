# G3 交互物像素素材与待机动效（props-art）

本模块把 `campaign.gd` 里用 `draw_rect/draw_circle` 现画的灯座、宝箱、门、水管、灯环、导光装置等，替换为**真像素素材 + 待机动画 + 环境粒子**；同时把床铺、箱柜、书架、木箱、菌丛、火把等静态家具改为**直接复用原图集 `Complete.png` 的像素图块**，只叠加一层很薄的动画光效。所有坐标是 320×180 逻辑世界像素，运行时由 `world` 画布 4 倍最近邻放大。

- 数据：`game/assets/props/props_data.json`（schema_version=1，build=`59458e26ea62a10b`，由 `tools/gen_props.py` 确定性生成）
- 运行时：`game/scripts/prop_art.gd`（`extends RefCounted`，按需构建 `ImageTexture`，不新增 PNG 导入依赖）
- 自测：`game/scripts/test_props.gd`（headless，输出 `PROP_TEST checks=2162 failures=0`）
- 预览证据：`qa/evidence/G3/props/`（素材总表、逐件放大、家具表、世界合成图、调色板、测试日志）

## 1. 风格硬规则与调色板

1. 1px 深色轮廓：生成器在序列化前对每一帧执行外部描边（`K=#13120c`），测试逐帧验证“非发光边界像素的 4 邻域内必有深色轮廓”；发光像素（火苗/符文/余烬）豁免。
2. 有限调色板：全部 31 个颜色逐像素采样自 `game/assets/original/Tilesets/Complete.png`（生成器 `audit_palette()` 校验每个色值在图集中真实存在）；**每件素材全状态并集 ≤16 色**（测试强制），单状态通常 10~14 色。
3. 无抗锯齿/渐变：所有像素 alpha 只有 0 或 255（测试逐像素验证），没有半透明描边、没有渐变；灯光用 1px 抖动（dither）表现。
4. 整数坐标：绘制位置 = `pos.round() + anchor`，纹理按 1:1 世界像素绘制；粒子位置全部为整数。
5. 灯光暖黄、阴影冷暗：暖光 `y/Y/a/F/W`，冷金属/阴影 `M/m/l/q/L`，菌光 `z/Z`，土褐 `D/B/b/c/P/Q`，红 `R/r/T/o`，苔绿 `G/H/I/J`。
6. 每件 3~6 帧待机动画；`reduced_motion` 时固定在 `rest_frame`（第 0 帧，可读姿态）；`reduced_flash` 时避开 `flash_frames` 的最亮帧（环/导光/标记）。
7. 粒子 1~2px 硬像素、数量少、相位互不相同、完全确定性（同一 tick 必得同一结果）。

| 组 | 字符 = 色值 |
| --- | --- |
| 轮廓 ink | `k=#0e0b08 K=#13120c` |
| 金属 metal | `M=#242b2b m=#332e2e L=#4a5152 l=#4f4442 q=#748989` |
| 冷光 cold | `z=#9ab8bf Z=#cdf5ff` |
| 土褐 brown | `d=#411f0f D=#3e1d0c B=#864b12 b=#965d24 c=#ac7036 C=#c2903c` |
| 石 stone | `P=#b7a178 Q=#d7af89` |
| 暖光 warm | `w=#e5c996 y=#cfa545 a=#d7a453 Y=#ddc161 F=#f8ca66 W=#f8f8f8` |
| 红 red | `R=#94242d r=#b52727 T=#c93327 o=#ac552f` |
| 苔绿 green | `G=#424530 H=#234333 I=#2a5e36 J=#30793b` |

调色板截图：`qa/evidence/G3/props/palette_sheet.png`。

## 2. API 契约（与 Lead 集成一致）

```gdscript
const PropArt = preload("res://scripts/prop_art.gd")
var prop_art = PropArt.new()   # 建议与 art/preferences 同期创建一次

# 自绘交互物（灯/宝箱/门/水管/灯环/导光/矿门/轨道/碎石/木桶）
prop_art.draw_prop(canvas, kind, pos, state, tick, prefs)

# 复用图集的静态家具（床/箱柜/木箱/纸张/书架/木桶/菌丛/火把/墙面板）
prop_art.draw_furniture(canvas, kind, pos, tick, prefs, state = {})

# 环境粒子/光场
prop_art.draw_ambient(canvas, kind, pos, tick, prefs)

# 标签应放的世界像素偏移（相对道具 pos；标签底边中心对齐到该点）
prop_art.label_anchor(kind) -> Vector2

# 每类环境效果每次调用允许的粒子上限（默认 24；low_effects 减半 12）
prop_art.particle_budget(prefs) -> int
```

`state` 键：`lit:bool`、`available:bool`（默认 true）、`scanned:bool`、`open:bool`、`dir:int(0..3)`、`correct:bool`、`complete:bool`、`near:bool`；可选 `beam:bool`（导光光束开关，默认 true，见 §3）。`prefs` 为 `presentation_settings.gd` 实例（含 `low_effects/reduced_motion/reduced_flash`），测试也接受同名字典。

`tick` 用现有 `combat.tick` 之类的整数帧计数（约 60/s）；数据里的 `hold` 以 tick 计（7~16 tick 换帧，约 4~8 fps）。

### 2.1 标签定位

`label_anchor(kind)` 返回世界像素偏移，例如灯座 `(0,-31)`、矿门 `(0,-36)`。`ui_layer` 是屏幕坐标时：

```gdscript
var world_point: Vector2 = pos + prop_art.label_anchor(kind)   # 标签底边中心
var screen_point: Vector2 = world_point * 4.0
# 再按现有 draw_object_labels 的方式居中绘制标签，底边对齐 screen_point
```

这样标签从原来“压在脚下”改为“悬在道具上方”，不会与灯罩/门头重叠。家具同样有 `label_anchor`（床 `(0,-47)`、书架 `(0,-36)` 等）。

### 2.2 near 高亮

`state.near = true` 时，`draw_prop` / `draw_furniture` 会在素材外框 1px 处画 5px 金色四角框（硬像素、无 AA）。Lead 不需要再画 `draw_arc` 选中圈。

## 3. 自绘交互物（`draw_prop`）

| kind | 尺寸 | anchor | label | 帧 | 颜色 | 状态语义 |
| --- | --- | --- | --- | --- | --- | --- |
| `lamp` | 16×30 | (-8,-26) | (0,-31) | lit 6 / unlit 4 | 12 | `lit`：熄灭=冷玻璃+灰烬反光；点亮=火焰+暖玻璃+金属反光 |
| `chest` | 20×16 | (-10,-14) | (0,-19) | closed 6 / open 3 / dim 3 | 14 | 交互宝箱（灯芯箱）：`open` 开盖暖光、`available:false` 冷暗不发光；缝隙呼吸光 |
| `door` | 20×32 | (-10,-29) | (0,-34) | sealed 4 / lit 5 / open 4 | 16 | 旧灯门；G3-010 起出口改用 portal，仅保留素材 |
| `pipe` | 34×18 | (-17,-11) | (0,-16) | idle 6 / scanned 5 | 15 | 旧水管：水滴/溅落循环（56 tick）、水位刻痕；`scanned:true` 刻痕被金/青高亮 |
| `ring` | 18×18 | (-9,-13) | (0,-18) | idle 6 / complete 5 | 12 | 初燃灯环：石环+火焰脉动；`complete:true` 更大火焰+浮游余烬 |
| `guide` | 16×26 | (-8,-23) | (0,-28) | 8 状态 × 5 | 14 | 导光装置：`dir` 0上/1右/2下/3左（与 `campaign.gd` 的 `DIR_VECTORS=[UP,RIGHT,DOWN,LEFT]` 完全一致），`correct:true` 暖金束、false 冷灰束；装置本体始终绘制 |
| `guide_target` | 18×18 | (-9,-12) | (0,-17) | on 4 / off 4 | 11 | 导光目标标记：`correct:true` 暖金亮起、false 冷色待机 |
| `mine_door` | 22×34 | (-11,-31) | (0,-36) | sealed 5 / sealed_scan 5 / lit 5 / open 5 | 16 | 旧木矿门，保留给其他矿道；G3-009 起切片边界不再使用 |
| `portal` | 28×38 | (-14,-36) | (0,-42) | sealed 3 / open 5 | 16 | G3-009 切片边界：棕石拱、砖缝、苔藓、符文；封印暗内芯+冷光点，开启绿边暖芯灯帘；慢动画 hold 16/14 |
| `rail` | 34×10 | (-17,-4) | (0,-9) | 4 | 10 | 矿道铁轨装饰，锈光/尘埃微动 |
| `rubble` | 16×10 | (-8,-7) | (0,-12) | 4 | 10 | 碎石堆，菌光呼吸+尘埃 |
| `barrel` | 14×18 | (-7,-16) | (0,-21) | 4 | 10 | 木桶（图集无干净木桶，见 §5.3），桶箍反光/尘埃 |

别名（`props_data.json.aliases`，可直接把 `prologue.json` 的 `kind` 传进来）：`rest→bed`、`socket→lamp`、`reward→ring`、`exit→portal`、`end→portal`、`crate→crates`、`crate_single`/`crates_small`、`mushroom→mushroom_red`、`lore`/`note→papers`、`storage`/`storage_door→door`、`panel`/`wall_panel_green→wall_panel`。

`guide` 的光束由 `draw_prop` 自动绘制（长度 26px，`low_effects` 16px；`reduced_motion` 静止；`reduced_flash` 去白芯）：光束原点为 `pos+(0,-17)`，四方向 `GUIDE_DIRS={0:上,1:右,2:下,3:左}`，与 `campaign.gd` 的 `DIR_VECTORS` 一致。若 Lead 保留现有 `draw_guide_beams()`（它按目标点画连线/流光），请传 `state.beam=false` 避免双光束；若改用本模块的 26px 光束则不传。`prologue.json` 里 N1-02 的三个导光装置已经带 `dir/solution/target/color`；Lead 只需按解谜规则算 `correct = (当前 dir == solution)` 传入即可，`color` 字段本模块暂未使用（可选后续做颜色键控）。

## 4. 家具：直接复用 Complete.png（`draw_furniture`）

| kind | 图集裁切 rect @ 偏移（相对 pos） | label | near | 动画叠加 |
| --- | --- | --- | --- | --- |
| `bed` | (9,339,31,45) @ (-15,-44) | (0,-47) | (-16,-45,32,46) | 暖色浮尘 3 + 红柱反光 |
| `chest_closed` | (7,241,20,15) @ (-10,-14) | (0,-18) | (-11,-15,22,16) | 箱缝呼吸暖光（F/Y/y）+ 微光 |
| `chest_open` | (39,241,20,15) @ (-10,-14) | (0,-18) | (-11,-15,22,16) | 箱内暖光抖动 + 上浮微尘 |
| `crates` | (32,471,48,25) @ (-24,-24) | (0,-26) | (-25,-25,50,26) | 尘埃 + 箍环反光 |
| `crate_single` | (32,479,16,17) @ (-8,-16) | (0,-20) | (-9,-17,18,19) | 2 粒尘埃 |
| `crate_stack` | (96,461,32,35) @ (-16,-34) | (0,-37) | (-17,-36,34,37) | 尘埃 |
| `papers` | (1,444,14,16)@(-8,-17) + (2,433,13,10)@(-14,-23) + (37,453,7,7)@(4,-14) | (0,-26) | (-15,-25,30,26) | 3 粒尘埃 + 纸角反光 |
| `shelf` | (112,414,16,34) @ (-8,-32) | (0,-36) | (-9,-35,18,38) | 顶部青书反光 + 尘埃 |
| `barrel` | 手绘 `barrel` 道具（见 §5.3） | (0,-21) | (-8,-17,16,18) | 同 `draw_prop("barrel")` |
| `mushroom_red` | (0,397,23,19) @ (-11,-18) | (0,-21) | (-13,-20,26,21) | 孢子 3 |
| `glow_mushroom` | (82,448,12,13) @ (-6,-12) | (0,-14) | (-8,-13,16,14) | 青绿脉冲光 + 孢子 2 |
| `torch` | (65,425,17,22) @ (-8,-21) | (0,-24) | (-9,-23,18,24) | 火焰 3 帧 + 火星 + 暖光斑（`state.lit=false` 时不画火焰） |
| `wall_panel` | (47,687,16,16) @ (-8,-16) | (0,-19) | (-9,-18,18,18) | 绿色宝石脉冲光（`state.lit=false` 熄灭） |
| `wall_panel_red` | (47,703,16,16) @ (-8,-16) | (0,-19) | (-9,-18,18,18) | 红色警示脉冲 |
| `wall_panel_cyan` | (47,719,16,16) @ (-8,-16) | (0,-19) | (-9,-18,18,18) | 青色冷却脉冲 |

说明：

- **床铺/储藏箱不重画**：`bed`、`chest_closed`、`chest_open` 只在 `furniture` 表里存在，没有同名的自绘道具（测试强制检查 `kinds` 里没有 `bed`），避免出现两套互相冲突的床/箱。`draw_prop("bed", ...)` 会自动转调家具绘制，因此契约里的 `bed` 仍然可用。
- **交互宝箱仍用自绘 `chest`**：Lead 要求“宝箱交互态”保留手绘；`chest_closed/chest_open` 是静态储藏箱家具图块，`chest` 是灯芯箱交互态（暖光/暗态）。
- `wall_panel*` 的裁切是 16×16 砖墙底上的装置面板（原图即如此），请贴在墙段/墙面格上使用；`qa/evidence/G3/props/props_world_mock.png` 给出了贴在墙块上的示例。
- 家具图块来自原图集的任意像素位置，裁切 rect 已逐个核对；测试用真实 PNG 校验裁切合法、非空、背景透明（wall_panel 例外，允许砖底），且 offset 落在 `near_rect` 内。
- `lore`/`note` 别名映射到 `papers`，`prologue.json` 新增的“矿工刻录/补给单”类阅读物可直接用。

## 5. 环境粒子与光场（`draw_ambient`）

| kind | base_count | 颜色 | 行为 |
| --- | --- | --- | --- |
| `spores` | 12 | `z,Z,w` | 洞穴/菌丛上方 1px 孢子：每 2 tick 上升 1px，横摆 ±1px，26px 范围 |
| `dust` | 8 | `P,Q,l` | 家具旁尘埃：贴地 8px 内横向漂移，40px 范围 |
| `drip` | 2 | `Z,z,q` | 水管滴水：12px 下落到地面 + 3px 溅落，循环 56 tick，两个相位错开 28 |
| `ember` | 5 | `F,Y,y` | 灯座/火把余烬：上浮 20px 暖色火星 |
| `light_pool` | 1（光场） | `a,y` | 地面灯光呼吸：18×5 椭圆，2~3 层抖动硬像素，alpha ≤0.18，无渐变 |
| `sway` | 1（光场） | `y,a` | 吊灯摆动光锥：长 26px、每 24 tick 摆 ±2px，1px 抖动 |

- `particle_budget(prefs)`：默认 24；`low_effects=true` → 12（减半）；`reduced_motion`/`reduced_flash` 不减少数量（`reduced_motion` 只冻结运动）。
- `ambient_count(kind, prefs)`：`base_count` 在 `low_effects` 时 `ceil(base/2)`，再受 `particle_budget` 上限约束；光场恒为 1。
- `ambient_positions(kind, pos, tick, prefs)` 是纯函数，供测试/回放使用：返回本帧所有 1px 粒子位置（光场返回空数组）；`reduced_motion` 等价于把 tick 固定为 0，所以静止但仍保留可读的散布。
- 推荐配对（Lead 按对象调用即可）：灯座 → `light_pool`+`ember`；床铺/宝箱 → `dust`（床可再加 `light_pool`）；门/传送门 → `sway`+`light_pool`；水管 → `drip`；菌丛/洞穴 → `spores`；矿道 → `dust`+`spores`。

## 6. 集成方法（示意，不修改 campaign.gd）

```gdscript
var prop_art = preload("res://scripts/prop_art.gd").new()

func draw_objects() -> void:
    preload("res://scripts/enemy_warnings.gd").draw(objects_layer, combat)
    for object in progress.node().objects:
        var pos := Vector2(object.pos[0], object.pos[1])
        var st := {}
        match object.kind:
            "lamp", "socket": st = {"lit": progress.has("S01"), "near": is_nearest(object)}
            "chest": st = {"open": progress.has("core"), "available": not progress.has("core"), "near": is_nearest(object)}
            "rest": st = {"near": is_nearest(object)}
            "exit", "end", "door":
                st = {"available": not object.has("requires") or progress.has(object.requires),
                      "near": is_nearest(object)}
            "pipe": st = {"scanned": progress.has("pipe"), "near": is_nearest(object)}
            "reward": st = {"complete": progress.has("M1"), "near": is_nearest(object)}
            "guide":
                var dir := int(object.dir)
                st = {"dir": dir, "correct": dir == int(object.solution), "available": true}
            "guide_target": st = {"correct": selected_guides.has(object.guide)}
            "mine_door":
                st = {"available": progress.has("E03"), "scanned": progress.has("scanned"),
                      "open": false, "near": is_nearest(object)}
            _: st = {"near": is_nearest(object)}
        prop_art.draw_prop(objects_layer, object.kind, pos, st, combat.tick, preferences)
        # 环境层按对象单独调用：
        match object.kind:
            "lamp", "socket":
                prop_art.draw_ambient(objects_layer, "light_pool", pos + Vector2(0, 13), combat.tick, preferences)
                prop_art.draw_ambient(objects_layer, "ember", pos, combat.tick, preferences)
            "pipe":
                prop_art.draw_ambient(objects_layer, "drip", pos + Vector2(17, 9), combat.tick, preferences)
```

标签：

```gdscript
func draw_object_labels() -> void:
    var font := ThemeDB.fallback_font
    for object in progress.node().objects:
        var pos := Vector2(object.pos[0], object.pos[1])
        var label: String = object.name
        var at: Vector2 = (pos + prop_art.label_anchor(object.kind)) * 4.0
        var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
        at.x = clampf(at.x - width / 2.0, 8, 1272 - width)
        ui_layer.draw_rect(Rect2(at + Vector2(-4, -24), Vector2(width + 8, 24)), Color(0.035, 0.045, 0.04, 0.85))
        ui_layer.draw_string(font, at + Vector2(0, -6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f4dfab"))
```

其他：

- 家具也可批量调用：`for kind in ["bed", "chest_closed", "shelf", ...]: prop_art.draw_furniture(objects_layer, kind, pos, combat.tick, preferences)`。
- 绘制顺序仍按 Lead 现有规则（`objects_layer` 在 `world` 之上、`ui_layer` 屏幕层）；本模块所有绘制都是整数坐标 + `ImageTexture`，父画布的 `TEXTURE_FILTER_NEAREST` 会继承，无需额外设置。
- `prefs` 直接传现有 `preferences`；不需要新建设置项。
- 若个别对象需要固定朝向/镜像，请用 `dir` 或拆 kind 处理，不要给画布加负缩放（会破坏 1px 像素对齐）。

## 7. 生成、测试与证据

```powershell
# 重新生成数据与全部预览（确定性，不依赖时间）
python tools/gen_props.py

# 引擎内自测（headless，勿用 GUI）
godot --headless --path game --script scripts/test_props.gd
# 期望最后一行：
# PROP_TEST checks=2162 failures=0
```

测试覆盖（2162 项，0 失败；G3-009 增加自绘传送门后仍通过）：

- JSON schema/build/palette；所有 kind/别名/家具/粒子条目存在；
- 每个变体 3~6 帧、hold/rest/flash 合法、行数/行宽/字符 ∈ 调色板、单件并集 ≤16 色；
- 每帧构造 `ImageTexture` 并逐像素比对：尺寸、alpha 仅 0/255、颜色与调色板完全一致；
- 每帧 1px 深色轮廓（发光像素豁免）；
- 动画相位 `tick/hold % 帧数` 不越界；`reduced_motion` 冻结在 rest；`reduced_flash` 避开 flash 帧；
- `state → variant` 映射（灯/宝箱/门/水管/环/导光 8 态/目标/旧矿门 4 态/传送门 2 态）；
- 家具裁切对真实 `Complete.png` 的合法性、透明边、offset/near/label/fx 坐标；
- 全部环境粒子的预算、低特效减半、整数坐标、边界、确定性、reduced_motion 静止、正常档有位移；
- 别名与 `prologue.json` 的所有对象 kind（跳过 NPC `rong`）均可解析；
- 真实 `_draw` 冒烟：在 headless 画布中实际调用 `draw_prop`/`draw_furniture`/`draw_ambient`（含 low_effects/reduced_motion/reduced_flash 路径），确认绘制路径无脚本错误且计数增加。

证据文件（全部由生成器/实跑产生）：

| 文件 | 用途 |
| --- | --- |
| `qa/evidence/G3/props/props_sheet.png` | 全部自绘道具、所有状态与帧 |
| `qa/evidence/G3/props/kind_<kind>.png` | 单件 8× 放大（11 张） |
| `qa/evidence/G3/props/furniture_sheet.png` | 全部家具裁切 + 待机光效静止帧 |
| `qa/evidence/G3/props/props_world_mock.png` | 用原图集地板/墙 + 角色 + 全部道具/家具/粒子的 320×180 合成图（4×） |
| `qa/evidence/G3/props/palette_sheet.png` | 实际使用调色板色卡 |
| `qa/evidence/G3/props/prop_test.log` | headless 自测命令与输出 |
| `qa/evidence/G3/props/tileset_*.png`、`src_*.png`、`probe_*.png` | 图集裁切核对过程记录 |

## 8. 已知限制 / 后续

1. `wall_panel*` 自带 16×16 砖墙底（原图如此），应贴在墙段；若 Lead 需要“漂浮装置”或不同墙底，需要另做透明裁切（当前不做像素级去背，避免破坏原图风格）。
2. `barrel` 在 Lead 提示的 `c5,r26-28` 实际是墙火把/发光菌，图集中没有背景透明的独立木桶；因此木桶为同调色板自绘 14×18，家具 API 通过 `prop` 字段转调。若后续发现更合适的原图块可替换。
3. 导光装置的 `color`（amber/moss/teal）字段尚未使用：当前统一暖金=正确、冷灰=错误。若解谜需要三色键控，可按 `state` 扩展调色板键。
4. 家具裁切沿用原图集的半透明/阴影像素（原素材自带），未逐像素改为二值 alpha；这不影响 4× 最近邻观感，但测试只对自绘道具强制二值 alpha。
5. `reduced_flash` 目前通过跳过高亮帧与降低光场 alpha 实现，没有做全屏闪白屏蔽（本模块无全屏特效）。
6. 集成后需由 Lead 更新根 `README.md`、当前策划文首 `HANDOFF_SNAPSHOT` 与 `game/DEV_STATE.md`；本文件只负责素材/绘制模块本身。
