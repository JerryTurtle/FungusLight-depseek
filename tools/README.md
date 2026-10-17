# 工具索引

从仓库根目录运行；先读根README的阶段与证据规则。

| 类别 | 工具 | 注意事项 |
| --- | --- | --- |
| 构建 | build.ps1 | 必须给新BuildId；需Godot4.3与Windows导出模板 |
| 专项 | test_combat.py、test_save.py | 直接调用Godot；日志编号目前固定，勿覆盖历史证据 |
| 原生 | test_export_input.py、test_review.py、replay_framerates.py | 先构建相同BuildId；不是系统键鼠操作 |
| 性能 | stress_review.py、summarize_stress.py | 约15分钟；汇总含固定G2路径，先核对 |
| 打包 | smoke_export.py、test_review_package.py | 阅读参数，后者只针对已有G2审核包 |
| 资源 | audit_project.py、generate_sfx.py | 会覆盖清单/音频，不是无副作用检查 |
| 环境/快照 | install_templates.py、snapshot_source.py | 安装模板/源码zip；快照依赖对应报告 |
| 历史收尾 | finalize_g2.py | 会重写报告与门槛，不能直接重跑覆盖H2批准和G3状态 |
| 归档 | legacy/ | 早期根目录脚本，见[说明](legacy/README.md) |

换机器检查工具中的引擎绝对路径与Python imports。本轮同步修改构建/验证的证据输出路径，游戏运行实现保持不变。

证据统一使用qa_paths.py的evidence_path(name)按G0～G6路由，无阶段前缀的早期资产清单归G0。PowerShell构建用同一规则。用户数据仍在qa/runtime-profile，本机副本/模板移入qa/local。旧路径映射见qa/maintenance/path-migration.json。
