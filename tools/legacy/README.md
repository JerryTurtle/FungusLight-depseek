# 历史脚本归档

2026-10-17从根目录移入7个脚本，保留制作过程。旧文档引用的同名根脚本现在位于此处。

- audit_assets.py、audit_assets_v3.py、inspect_assets.py：素材复核/预览，需本地完整原素材与Pillow。已修正工程根路径，仍输出到根目录策划输出，会覆盖复核文件。
- audit_execution_spec.py、enrich_game_plan.py、revise_plan.py、update_plan_review.py：早期策划检查/一次性改写，用仓库根目录为工作目录。不要直接重跑旧改写流程覆盖当前策划。

只做语法/路径检查验证归档，不为验证移动而执行会改写当前策划的历史脚本。
