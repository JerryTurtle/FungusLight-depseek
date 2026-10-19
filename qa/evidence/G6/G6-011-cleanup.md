# G6-011 过程发布包清理

- 已删除：G0～G4 过程构建、G6-001～G6-010 全部过程包/QA/源目录与 zip、G7 过程包与 zip、临时导入目录。
- 已保留：
  - `deliverables/G6-011-Release/` 与 `deliverables/FungusLight-G6-011-Release.zip`：当前候选。
  - `deliverables/G2_Review/`、`G2_Review-G2-007.zip`、`G2-007-check/`：G2 门禁审核。
  - `deliverables/G4-001-Acceptance/` ～ `G4-008-Acceptance/` 及 zip：G4 验收留档。
  - `deliverables/Release/`：运行中的 G6-003 门禁版本，未终止进程、未覆盖。
- 例外：`deliverables/G6-010-Release/Game/debug.log` 被其他进程占用，文件夹暂时无法完全删除；其余 G6-010 内容已清理，待占用释放后删除。
- 历史证据未删除，仍在 `qa/evidence/`。
