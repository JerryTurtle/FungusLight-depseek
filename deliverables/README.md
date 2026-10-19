# 发布包目录

当前最终发布（用户已签署通过）：

- `G6-012-Release/`
- `FungusLight-G6-012-Release.zip`
- `SHA256SUMS.txt`、`FINAL-RELEASE.md`

保留的门禁/验收留档：

- `G2_Review/`、`G2_Review-G2-007.zip`、`G2-007-check/`
- `G4-001-Acceptance/` ～ `G4-008-Acceptance/` 及对应 zip
- `Release/`：G6-003 门禁版本，仍被进程占用

清理说明：

- 已删除 G0～G4 过程构建、G6-001～G6-011 过程包、G7 过程包及 zip。
- `G6-010-Release/` 中仍有 G6-010 游戏进程运行，debug.log/包文件被占用，暂时无法删除；关闭该进程后可移除。
- 历史证据仍保留在 `qa/evidence/`。
