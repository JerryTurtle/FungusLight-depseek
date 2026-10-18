# 验证目录

| 目录/文件 | 用途 |
| --- | --- |
| gates.json | 当前门槛与证据索引 |
| H2-approval.md | 用户批准，允许G3 |
| evidence/G0/ | 素材/启动与早期环境验证 |
| evidence/G1/ | 灰盒战斗、输入/碰撞/回放 |
| evidence/G2/ | 已审动作、审核台、负载与交付验证 |
| evidence/G3/ | 存档及后续切片验证 |
| evidence/G4/ | 五章主线/两结局/路线矩阵与G4-009试玩修复 |
| evidence/G5/ | 未单独执行（用户指示跳过，发布必需项并入G6） |
| evidence/G6/ | 发布入口/PCK/布局/干净目录/G6流程/最终验收记录 |
| G4-approval.md | 用户20分钟时长与G4通过记录 |
| G6-approval.md | 用户最终验收待填写模板 |
| maintenance/ | 目录验证、旧路径映射与原文件SHA256 |
| local/ | 本机复现副本、模板包、探针，Git忽略 |
| runtime-profile/ | 隔离测试用户数据，Git忽略 |

最新报告：[G2](evidence/G2/G2-007-gate-report.md)、[G3](evidence/G3/G3-001-progress.md)、[G4-009](evidence/G4/G4-009-progress.md)、[G6-001 发布候选](evidence/G6/G6-001-progress.md)。证据按字节保留，历史内容旧路径通过[迁移表](maintenance/path-migration.json)查找，不改写测量记录。G6 在用户填写 `G6-approval.md` 前保持 in_progress。

工具使用tools/qa_paths.py按阶段输出；门槛与批准文件位置不变。新验证用新编号，不覆盖历史结论、不用测试反馈替代人工批准。
