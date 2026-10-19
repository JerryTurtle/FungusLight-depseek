# G6-012 发布包位置迁移记录

- 日期：2026-10-19
- 原因：按用户要求整理交付资料包，把发布 zip 从 `deliverables/` 移入按顺序组织的 `资料包/`。
- 旧路径：`deliverables/FungusLight-G6-012-Release.zip`
- 新路径：`资料包/01-游戏安装包/FungusLight-G6-012-Release.zip`
- 文件内容：**未改变**；SHA256 仍为 `FCEC62C9CCD11759AF30E8532C72AD26B31D1608BA186390DAC8969D20EB25BF`，字节数仍为 81,622,223。
- 本地解压目录：`deliverables/G6-012-Release/` 保留（未纳入 Git），作为本地发布目录；正式交付以 `资料包/01-游戏安装包/` 的 zip 为准。
- 同步更新：`README.md`、`game/DEV_STATE.md`、策划文首快照、`qa/gates.json`（`package_zip`）、`deliverables/README.md`、`deliverables/FINAL-RELEASE.md`、`deliverables/SHA256SUMS.txt`。
- 未修改：`qa/G6-approval.md` 的用户签署原文（签署发生在迁移前，路径为历史路径）；`qa/evidence/G6/G6-012-final-package.txt` 等历史证据保持原样，避免改写验收记录。
- 说明：本次只调整交付包位置与文档索引，**没有重新构建游戏、没有改变 exe/pck、没有改变 G6 结论**。
- 新增交付资料包：`资料包/`（01 安装包、02 作品说明与 AI 工具说明、03 源码 zip + AI 交互记录），校验见 `资料包/SHA256SUMS.txt`。
