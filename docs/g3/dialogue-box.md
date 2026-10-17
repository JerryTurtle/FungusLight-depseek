# G3-006 底部 RPG 对话框（DialogueBox）设计与集成

状态：组件与 headless 自测完成（`DIALOGUE_TEST checks=167 failures=0`）；`campaign.gd` 的接入由 Lead 完成，本组件不依赖也不修改 campaign、graybox、review 或 project.godot。

## 1. 文件

| 文件 | 说明 |
| --- | --- |
| `game/scripts/dialogue_box.gd` | 自包含底部对话框组件（`class_name DialogueBox`，`extends Control`） |
| `game/scripts/test_dialogue.gd` | headless 自测（`extends SceneTree`） |

字体不随组件打包：组件从 theme / `ThemeDB.fallback_font` 读取项目像素字体（方舟像素 12px），并复制一份关闭抗锯齿、hinting、亚像素定位。Lead 在 `boot.gd` / `graybox.gd` 设置的 `ThemeDB.fallback_font = load("res://assets/fonts/ArkPixel12px-zh_hans.ttf")` 会自动生效；若项目 theme 显式提供非引擎默认字体，则优先使用 theme 字体。

## 2. 布局（整数像素，固定屏幕下部）

设计基准：1280×720、`canvas_items` 拉伸。组件挂在视口原点，按 `get_viewport_rect().size` 换算；左右边距固定 48px，底部 40px，面板高 176px。

| 元素 | 1280×720 | 1920×1080 |
| --- | --- | --- |
| 面板 | `(48,504) 1184×176` | `(48,864) 1824×176` |
| 名字牌（叠在面板左上） | `(76,482)`，高 44，宽度 `max(96, 名字宽@24px + 40)`；上 22px 露出面板外 | `(76,842)`，同规则 |
| 名字文本 | `(92,487) 68×34`，字 24 | 同 x/y 规则 |
| 正文 | `(80,538) 1088×112`，字 24，行高 34，最多 3 行 | `(80,898) 1728×112` |
| 右下操作提示 | `(553,654) 651×18`，字 12，右对齐 | `(841,1014) 1003×18` |
| 选项页提示语 | `(80,514) 1120×68`，字 24，最多 2 行 | `(80,874) 1760×68` |
| 选项行（2 行） | 行高 34，行首 y=584 / 618；命中区 `(72,582)/(72,616) 1136×38` | y=944 / 978；命中区宽 1776 |
| ▼ | 右下角面板内 `(panel.right-52, panel.bottom-46)`，9×6 像素三角 | 同规则 |

- 面板：先填 2px 深色外描边，再内缩 2px 填深青黑半透明底 `(0.050,0.095,0.105, α0.93)`，再画 1px 暖金内高光与四角 2px 金色短臂。全部 `draw_rect` 硬边，无圆角、无渐变、无抗锯齿。
- 名字牌：2px 深色外框 + 1px 暖金描边，左侧 3px 说话人色条。
- 正文左对齐、`AUTOWRAP_WORD_SMART` 自动换行（中文不手动插 `\n`），行间距按字体实测补足到 34px。
- 选项页与对白共用同一个底部框（2 个选项时面板矩形完全相同）；选项多时面板向上加高，底边不变。

## 3. 配色

| 名称 | 值 | 用途 |
| --- | --- | --- |
| 面板底 | `0.050,0.095,0.105,0.93` | 深青黑半透明 |
| 面板外描边 | `0.020,0.043,0.050,0.98` | 2px |
| 暖金内高光/名字牌描边 | `0.847,0.694,0.416,0.85` | 1px |
| 四角装饰 | `0.914,0.804,0.553,0.75` | 2px 短臂 |
| 正文 | `0.945,0.906,0.816` | 暖白 |
| 提示 | `0.560,0.682,0.624` | 青灰 |
| 选项选中 | `1.000,0.878,0.600` | 暖金 |
| `岚` | `#e8c274` 暖金 | 名字 + 色条 |
| `绒` | `#a6c47c` 苔绿 | 同上 |
| `伤员` | `#a9d6d2` 浅青 | 同上 |
| `提示` | `#7ed3b2` 青绿 | 同上 |
| 未知名字 | `#f2e8d4` 暖白 | 同上 |

字体字号只用 12 的整数倍：正文/名字/选项 24，操作提示与小字 desc 12。

## 4. 状态机

```
CLOSED --show_line--> REVEALING --tick() 播完--> WAITING
REVEALING --E/回车/空格/左键--> WAITING（只补全，不发 advance）
WAITING --E/回车/空格/左键--> advance_requested（后续由调用方 show_line/close）
REVEALING/WAITING --Tab--> skip_requested（跳段语义由 campaign 决定）
CLOSED --show_choices--> CHOICES --E/回车/左键--> choice_selected(id)
CHOICES --Tab--> 被吞掉，绝不发射 skip_requested
```

- 组件只发信号，不自动关闭、不替调用方推进；收到 `advance_requested` / `choice_selected` 后由调用方决定下一句、关闭或提交选择。
- 打开/关闭时的 `paused` 由调用方维护，组件从不修改 `paused`/combat；组件自身 `process_mode = ALWAYS`，即使树级暂停也继续播放打字机。
- 同一次 `InputEvent` 对象重复传入只处理一次（最近 32 个实例 id 去重，`close()` 清空），避免输入分发重复导致二次推进/二次确认。

## 5. API

```gdscript
signal advance_requested
signal skip_requested
signal choice_selected(id: String)

enum State { CLOSED, REVEALING, WAITING, CHOICES }
var state: int  # 只读

func show_line(speaker: String, text: String) -> void
func show_choices(prompt: String, options: Array) -> void  # [{id,label,desc}, ...]
func reveal_all() -> void
func is_revealing() -> bool
func is_waiting() -> bool
func is_choices() -> bool
func is_open() -> bool
func close() -> void
func tick(delta: float) -> void          # 确定性计时入口
func handle_input(event: InputEvent) -> bool  # true = 已消费，调用方应 set_input_as_handled()
```

只读诊断接口（集成/测试用）：`get_panel_rect()`、`get_nameplate_rect()`、`get_body_rect()`、`get_hint_rect()`、`get_prompt_rect()`、`get_option_rects()`、`get_nameplate_visible()`、`get_speaker()`、`get_full_text()`、`get_visible_chars()`、`get_body_label()`、`get_name_label()`、`get_hint_label()`、`get_prompt_label()`、`get_option_labels()`、`get_body_line_count()`、`get_hint_text()`、`get_prompt_text()`、`get_name_text()`、`get_name_color()`、`is_arrow_visible()`、`get_options()`、`get_selected_index()`、`get_selected_id()`、`get_draw_count()`、静态 `speaker_color(speaker)`。
`layout_for(viewport_size)` / `clear_layout_override()` 只用于测试/特殊视口，不参与正常游戏布局。

## 6. 输入约定（配合 campaign 的事件循环）

campaign 现有 `_unhandled_input` 会先处理 Esc，再在 `paused or overlay.visible` 时提前返回，并把 E/空格/左键交给战斗。接入顺序必须是：

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    # 1) 对话框优先吞事件，避免同时触发战斗/交互/暂停。
    if dialogue.is_open() and dialogue.handle_input(event):
        get_viewport().set_input_as_handled()
        return
    # 2) 原有 Esc/移动/战斗逻辑
    ...
```

- 组件只消费自己处理的键鼠（见下表），其余事件返回 `false`，不会影响 campaign 的原有分支。
- 需要鼠标悬停切换选项，必须把 `InputEventMouseMotion` 也转发给 `handle_input`（只转发按键/点击则只能用键盘或点击确认）。
- Esc 组件不消费：若希望对话期间 Esc 不打开暂停菜单，由 campaign 在 Esc 分支先判断 `dialogue.is_open()`（建议直接忽略或留给后续设计）。
- 对话打开期间 campaign 仍应设置自己的 `paused = true` 并清空 `commands`，组件不负责冻结战斗。

| 场景 | 输入 | 组件行为 |
| --- | --- | --- |
| 对白显示中（REVEALING） | E / 回车 / 小键盘回车 / 空格 / 左键 | 补全当前句，不发信号 |
| 对白完整（WAITING） | E / 回车 / 小键盘回车 / 空格 / 左键 | `advance_requested` |
| 对白中 | Tab | `skip_requested`（补全或完整均可） |
| 选项页 | W/↑、S/↓ | 上下切换（循环），吞事件 |
| 选项页 | 鼠标移动 | 悬停到某行即选中该行（不确认） |
| 选项页 | E / 回车 / 小键盘回车 | 确认当前选中，发 `choice_selected(id)` |
| 选项页 | 左键 | 点在选项行：选中并发 `choice_selected(id)`；点空白：吞掉、不确认 |
| 选项页 | Tab / 空格 | 吞掉、无任何信号（Tab 不能替玩家做选择） |
| 已关闭 | 任意 | 返回 `false`，不消费 |

## 7. 打字机与 ▼

- 速度 `CHARS_PER_SECOND = 50`（需求 45~55 字/秒）；`tick(delta)` 累加字符数，按 Unicode 字符逐个 `substr` 显示。
- 组件 `_process(delta)` 只转调 `tick(delta)`；若调用方也要手动 tick，先 `set_process(false)`，否则会双倍速。
- 播完进入 WAITING 后 ▼ 以 1 秒周期闪烁（前 0.6s 显示、后 0.4s 隐藏）；右下 12px 提示在显示中为「E / 回车 / 空格 显示全部　Tab 跳过」，完整后改为「…继续…」。

## 8. 集成示例（供 Lead 改造 campaign）

```gdscript
var dialogue = preload("res://scripts/dialogue_box.gd").new()

func _ready() -> void:
    ...
    add_child(dialogue)                       # 直接挂 Node2D 也可，组件自撑满视口
    dialogue.advance_requested.connect(advance_dialogue)
    dialogue.skip_requested.connect(finish_dialogue)
    dialogue.choice_selected.connect(choose_growth)

func show_dialogue() -> void:
    var lines: Array = progress.content.dialogues[progress.active_event]
    dialogue_index = clampi(dialogue_index, 0, lines.size() - 1)
    overlay.hide()                            # 旧居中菜单只留给标题/暂停/存档
    paused = true
    dialogue.show_line(str(lines[dialogue_index][0]), str(lines[dialogue_index][1]))

func advance_dialogue() -> void:
    dialogue_index += 1
    if dialogue_index >= progress.content.dialogues[progress.active_event].size():
        finish_dialogue()
    else:
        show_dialogue()

func finish_dialogue() -> void:
    if progress.active_event == "M1":
        paused = true
        dialogue.show_choices("初燃 · 选择一项强化", [
            {"id": "melee", "label": "灯击伤害 +15%", "desc": "18 → 21"},
            {"id": "light", "label": "净光伤害 +15%", "desc": "24 → 28"},
        ])
        return
    dialogue.close()
    progress.finish_event()
    start_encounters()
    resume()

func choose_growth(option: String) -> void:
    dialogue.close()
    if not progress.finish_event(option): return
    apply_growth()
    ...
```

要点：
- `show_choices` 之后不要自动选择或超时选择；M1 跳过对白只会进入选项页，选项页 Tab 被吞。
- `choice_selected` 回调里先提交 `progress.finish_event(option)`，失败则保持选择页（重新 `show_choices`）。
- 组件关闭后 campaign 自己的 `paused` 才复位；两者不要互相代管。

## 9. 限制

- 正文最多显示 3 个排版行（1280 宽约 135 个汉字），超出会被 `max_lines_visible` 截断；现有序章最长句约 81 字，余量充足。更长文本需调用方拆成多条 `show_line`。
- 选项提示语最多 2 行（68px）；建议传入短标题（如「初燃 · 选择一项强化」），详细说明放在前面对白里。
- 选项页按 M1 两行设计；2 行时与对白共用 176px 面板，3 行会把面板向上加高 34px，超过 3 行不作保证。
- 无立绘、无语音、无历史回看、无逐字气泡音；不做 Esc/关闭按钮。
- 组件使用 `ThemeDB.fallback_font` 的副本，不做运行时换字体热更新（重新赋值 fallback 后下一次 `show_line` 会重新解析）。

## 10. 自测

```powershell
godot --headless --path game --script res://scripts/test_dialogue.gd
```

输出：`DIALOGUE_TEST checks=167 failures=0`（exit code 0）。覆盖：

1. 面板 1280×720 / 1920×1080 都在屏幕下部，左右 40~48px、底部 24~40px、整数像素、不越界；名字牌叠在面板左上且不越界；
2. 名字/正文/操作提示/选项提示字号（24/24/12/24）与字体来源（ThemeDB 方舟像素），说话人四色 + 未知暖白，名字牌宽度随名字；
3. 打字机 0.02s/字（50 字/秒）、0.1s/5 字、1.0s/50 字、播完进入 WAITING；`reveal_all()` 立即补全；同一次事件重复传入不会二次补全/推进；
4. E/回车/空格/左键都能推进；显示中只补全不推进；`advance_requested` 语义正确、组件不自动关闭；
5. Tab 在对白中发 `skip_requested`，同一事件只发一次；选项页 Tab 被吞且不发跳过信号；
6. 选项页 W/S/↑/↓（含循环）、鼠标悬停切换（不确认）、E/回车/左键确认、点击空白/空格不确认、重复确认不二次发射；
7. 约 114 字长文本在 1280 宽折成 3 行、1920 宽 2 行，行高 34px，文本高度不超过正文区且无手动换行；
8. ▼ 闪烁节奏（0.7s 灭 / 1.1s 亮）；`close()` 后隐藏、不再消费输入、无残留信号；
9. headless 下对白/选项两条 `_draw` 分支真实执行；挂到 `Node2D` 父节点自动布局；组件从不改 `SceneTree.paused`。

注意：headless 哑窗口默认 64×64，与内容缩放 1280×720 叠加会把全局字体 oversampling 变成 0.05，字体度量放大 3 倍；测试脚本先把 `root.size` 设为 1280×720 再断言，与实机窗口一致（oversampling=1）。写其他 headless UI 测试时也需要同样处理。
