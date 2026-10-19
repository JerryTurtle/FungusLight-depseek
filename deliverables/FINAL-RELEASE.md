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
- `FungusLight-G6-012-Release.zip`：完整发布包

## 校验

见 `SHA256SUMS.txt`。

## 保留的门禁/验收包

- `G2_Review/`、`G2_Review-G2-007.zip`、`G2-007-check/`
- `G4-001-Acceptance/` ～ `G4-008-Acceptance/` 及对应 zip
- `Release/`：G6-003 门禁版本，仍被进程占用

## 清理说明

G0～G4 过程构建、G6-001～G6-011 过程包、G7 过程包及 zip 已删除。`G6-010-Release` 当前仍有游戏进程运行，文件被占用，无法删除；关闭该进程后可移除该目录。
