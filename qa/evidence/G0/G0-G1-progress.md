# 阶段证据 2026-10-16

## G0 技术检查
- Godot 4.3 stable / Compatibility；匹配官方 Windows x64 模板已安装。
- 12 张角色 PNG 导入，Cleric 的 12 个区域、脚底与调色板已登记 `asset_manifest.json`。
- 中文字体 Noto Sans SC 和 OFL 许可随包；实际窗口文字完整可见。
- G0-001 已导出，在 `qa/clean-run/G0-001` 运行并取得 `g0-export-window.png`、`g0-export-window.log`。
- 导出程序在自动化受限上下文不能写普通 AppData。仅为测试把 APPDATA 指向工作区隔离目录后，退出码 0，用户写探针成功、原生 OpenGL 渲染截图成功。未改 ACL 或系统安全设置。常规桌面首次启动与默认用户目录持久化仍是后续发布检查项。
- 受限上下文另记录 DirectInput 和系统证书读取错误；此版本不承诺手柄或网络功能。键鼠真实交互尚未自动操作验证。
- G0 检查允许进入灰盒阶段，不代表发布条件全部通过。

## G1-001
- 实现独立固定步模拟，真实输入和自动测试共用 `combat_model.step`。
- 八向移动、四向近战/去重、净光释放消费/阻墙、闪避时间线、追击者基础前摇攻击、受击保护与重试。
- `g1-initial-tests.log`：228 断言通过，包括四向各25次挥击、归一化位移、挥空不回能、光束阻墙、闪避无敌边界、前摇取消免费、20次模型重置。
- 这是部分场景与边界检查，不等价 A01～A09 全部通过。
- 当前结算顺序仍是玩家后敌人，尚未实现同帧批次互击；角色间实体碰撞、绕障寻路、动态门、弹体扫掠与持续区未完成。
- 输入缓存需进一步检查拒绝输入覆盖与末段边界；显示层时序与实际判定仍需对齐验证。
- 尚无真实声音、四向攻击姿态或 H2 审核结果；不得开始 G2 或 G3。

## 重现
`python tools/audit_project.py`

`& 'C:/Software/Godot_v4.3-stable_win64.exe/Godot_v4.3-stable_win64_console.exe' --headless --path game --script res://scripts/test_combat.gd --quit-after 300`

`./tools/build.ps1 -BuildId G1-001`

`python tools/smoke_export.py G1-001`
