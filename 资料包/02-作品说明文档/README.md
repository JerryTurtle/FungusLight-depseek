# 02 · 作品说明文档

本目录包含《菌灯之下》的作品与 AI 创作资料。当前玩法基线为 G6-012，兼容性构建为 G6-013。

## 参赛说明 Word 文档

- [参赛说明 Word 文档](../../deliverables/competition-doc/菌灯之下_游戏参赛说明.docx)：8 页、6 张实机截图，面向评委介绍背景、玩法、特色、AI 创作过程与改进案例。
- [可编辑源稿](参赛说明.md)；生成器为 `tools/build_competition_doc.py`。使用含 python-docx 的 Python 与 PATH 中的 ffmpeg，执行 `python tools/build_competition_doc.py` 可重建 Word。
- Word、视频抽帧与排版检查产物均保存在已忽略目录，不纳入 Git；截图使用原实机证据或既有演示视频，不生成替代游戏画面。
- 验证记录：`qa/maintenance/competition-doc-check.json`。本次仅制作说明文档，不创建新游戏构建。

既有说明资料：

| 顺序 | 文档 | 内容 |
| --- | --- | --- |
| 1 | [作品说明.md](作品说明.md) | 作品概览、故事、玩法介绍、运行环境、依赖说明、操作方式、已知问题、验证与校验 |
| 2 | [AI工具使用说明.md](AI工具使用说明.md) | 使用的 AI 模型/工具、辅助开发环节、人机分工、生成内容清单、过程记录与边界 |

## 快速结论

- **怎么玩：** WASD 移动，鼠标左键灯击、右键净光，1 护灯、2 灯雨，空格闪避，E 交互，Q 观察，R 药剂，Esc 暂停。
- **怎么跑：** 解压 `01-游戏安装包/FungusLight-G6-013-Release.zip`，双击 `Game/开始游戏.cmd`。
- **依赖：** 运行游戏零外部依赖；源码需要 Godot 4.3 stable，素材生成脚本需要 Python 3.13 + Pillow 11.3。
- **AI 工具：** DeepSeek Harness（DSH）编码智能体 + DeepSeek 系模型；图像生成与识图使用 Gemini 后端的 image/vision 桥接；Godot 4.3、Python、PowerShell、Git 为工程工具链。
- **人工验收：** H2、G4、G6 均有人类通过记录，G6 已签署。

## 相关目录

- [01 · 游戏安装包](../01-游戏安装包/安装与运行说明.md)
- [03 · 源码压缩包](../03-源码压缩包/源码包说明.md)
- [资料包总索引](../README.md)
