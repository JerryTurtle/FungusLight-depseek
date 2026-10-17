# 来源登记

- `assets/original/Characters/*.png`：用户工作目录 `Fungus Cave [16x16]/Characters` 原样复制。原目录未附许可。仅作为本地开发输入；不声称已获得商业分发许可。哈希、尺寸在 `qa/asset_manifest.json`。
- `assets/fonts/NotoSansSC.ttf`：Google Fonts 的 Noto Sans SC，SIL Open Font License 1.1。来源 https://github.com/google/fonts/tree/main/ofl/notosanssc ，许可全文随包 `NotoSansSC-OFL.txt`。
- `assets/fonts/ArkPixel12px-zh_hans.ttf`：方舟像素字体（Ark Pixel Font）12px 比例宽度简体中文版，SIL Open Font License 1.1，版权 TakWolf。来源 https://github.com/TakWolf/ark-pixel-font ，版本 2026.10.16（发布包 `ark-pixel-font-12px-proportional-ttf-v2026.10.16.zip` 内 `ark-pixel-12px-proportional-zh_hans.ttf`）。用途：G3 起游戏内 UI/对白像素文字；导入参数关闭抗锯齿、hinting 与子像素定位，字号只使用 12/24/36。许可全文 `ArkPixel-OFL.txt`。审核台继续使用 Noto Sans SC，避免 H2 已审工具排版变化。
- 程序与配置：本项目生成。
- Godot 4.3：MIT，导出模板来源官方 `godotengine/godot-builds` 的 `4.3-stable` 发布。

## G2-001 新增

- `assets/original/Tilesets/Complete.png`：用户提供的 `Fungus Cave [16x16]/Tilesets/Tileset - Complete 16x16.png` 原样复制，128×736；最近邻原尺寸采样，继承原素材授权待核实状态。
- `scripts/world_art.gd`：基于原角色切片的躯干/脚部偏移与程序灯杖、靶，全部在引擎绘制，不修改原PNG。这是动作初稿，不代表完整动作美术验收。
- `assets/audio/{swing,hit,cast,hurt}.wav`：本项目 `tools/generate_sfx.py` 确定性合成，无外部采样，单声道44.1kHz/16bit PCM。音效v1，使用正弦叠加与种子固定的噪声、包络生成；主观音色和实际听感待G2审核。

G2-004纠正：已撤销躯干拆分与G2-003追加手臂，当前使用完整原角色帧，仅重绘原图手部2×2区域实现与武器的遮挡；没有新肢体素材或PNG编辑。武器/靶/护壳碎片仍为程序绘制。

G2-006新增 `assets/audio/{shell_break,shield_hit,rain_impact}.wav`：本项目generate_sfx.py原创程序合成，无第三方采样，44.1kHz单声道16bit PCM；原四音频保持字节不变。新增火花、轮廓和数字均为引擎程序绘制，无新增位图。
