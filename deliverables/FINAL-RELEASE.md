# 《菌灯之下》最终发布

- 版本：G6-012
- 打包日期：2026-10-19
- 开发状态：开发任务已完成，最终发布包已整理。
- 验收状态：用户已在 `qa/G6-approval.md` 勾选“通过”并签名（JeryTurtle，日期按原文 2026.10.49）；`qa/gates.json` 的 G6 已标记 `passed`。逐项字段/哈希栏未填写，哈希见 `SHA256SUMS.txt`。

## 发布内容

- `G6-012-Release/`
  - `Game/`：Windows 可执行文件与 PCK
  - `Source/`：当前工程源码
  - `Docs/`：操作、验收、已知问题
  - `QA/`：测试检查、截图、证据与验收记录
  - `Licenses/`：资产与音乐许可说明
- `FungusLight-G6-012-Release.zip`：完整发布包，已纳入 Git

## 校验

见 `SHA256SUMS.txt`。

## 清理说明

G0～G4 过程构建、G6-001～G6-011 过程包、G7 过程包、G6-010/G6-003 旧包、G2/G4 门禁/验收副本均已删除；历史证据保留在 `qa/evidence/`。本地仅保留 G6-012 发布目录与 zip。
