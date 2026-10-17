"""Finalize technical records only after measured G2 checks pass; never approve H2."""
from qa_paths import evidence_path
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
stress = json.loads((evidence_path('G2-007-stress-summary.json')).read_text(encoding='utf-8'))
review = json.loads((evidence_path('G2-007-review/checks.json')).read_text(encoding='utf-8'))
package = json.loads((evidence_path('G2-007-package-check.json')).read_text(encoding='utf-8'))
assert review['checks'] >= 50 and review['failures'] == 0 and package['passed']
assert stress['nodes_range'][0] == stress['nodes_range'][1] and stress['enemies_range'] == [6,6]
assert all(x['average_fps'] >= 59 for x in stress['profiles'].values())
assert stress['private_bytes']['last5min_max_mib']-stress['private_bytes']['last5min_min_mib'] < 3, 'Inspect memory growth before closing G2'

rows = []
for key,title in [('standard','标准'),('low','低档')]:
    x = stress['profiles'][key]
    rows.append(f"| {title} | {x['average_fps']:.2f} | {x['minimum_5s_fps']:.2f} | {x['maximum_engine_frame_ms']:.2f} ms | {x['frames_over_50ms']} |")
mem = stress['private_bytes']
ws = stress['working_set']
report_path = evidence_path('G2-007-gate-report.md')
report = report_path.read_text(encoding='utf-8').split('## 最终验收补记')[0]
report += '\n## 最终验收补记\n\n'
report += f"完整运行 {stress['elapsed_seconds']:.3f} 秒；{stress['cpu']} / {stress['video_adapter']}，1280×720、Compatibility。\n\n"
report += '| 档位 | 平均 FPS | 最低 5 秒 FPS | 最大引擎帧间隔 | >50ms 帧数 |\n| --- | --- | --- | --- | --- |\n'+'\n'.join(rows)+'\n\n'
report += f"节点始终 {stress['nodes_range'][0]}；对象范围 {stress['objects_range']}；敌人始终 6，弹体范围 {stress['projectiles_range']}，效果范围 {stress['effects_range']}。最后 5 分钟 OS 私有内存 {mem['last5min_min_mib']:.2f}～{mem['last5min_max_mib']:.2f} MiB，工作集 {ws['last5min_min_mib']:.2f}～{ws['last5min_max_mib']:.2f} MiB，没有观察到持续累积；这不是对任意时长绝无泄漏的承诺。详见 stress-summary.json 与原始采样。\n\n"
report += '549 项模型检查、118 项战斗集成、50 项审核集成与干净目录重启恢复通过；最终包 30/60/144 FPS 回放一致。G2 技术检查通过，H2 待人工审核，G3 未开始。系统级键鼠自动操作受工具限制未完成；主观听感与操作体验仍由 H2 审核。\n'
report_path.write_text(report,encoding='utf-8')

gate_path = root/'qa/gates.json'
gates = json.loads(gate_path.read_text(encoding='utf-8'))
gates['build_id'] = 'G2-007'
gates['G0']['caveat'] = 'Original native export used isolated APPDATA. G2-007 later verifies normal-environment launch and portable fallback persistence; normal AppData remains restricted on this automation host.'
gates['G1']['caveat'] = 'G1 native integration injects viewport events, not OS keyboard events. Later G2-007 verifies default-environment startup and portable fallback persistence. Original G1 evidence remains historical.'
gates['G2']['status'] = 'passed'
gates['G2']['remaining'] = []
gates['G2']['caveat'] = 'H2 subjective approval pending. Default environment launch/persistence verified via writable portable fallback; normal user directories restricted on this host. Native input events tested; OS gameplay automation unavailable. Stress binary and final package differ only in documented non-load-increasing visual/clipboard finishing changes.'
evidence = ['G2-007-tests.log','G2-007-integration.json','G2-007-check-framerate-summary.json','G2-007-review/checks.json','G2-007-stress-summary.json','G2-007-stress.json','G2-007-stress-os-memory.json','G2-007-stress-build-hashes.txt','G2-007-package-check.json','G2-007-grip-review.png','G2-007-gate-report.md','G2-007-source-hashes.json']
gates['G2']['evidence'] += [evidence_path(x).relative_to(root).as_posix() for x in evidence if evidence_path(x).relative_to(root).as_posix() not in gates['G2']['evidence']]
gates['H2'] = {'status':'pending_human_review','build_id':'G2-007','human_approval':None,'package':'deliverables/G2_Review/动作审核.exe','instructions':'deliverables/G2_Review/开始审核.md'}
gate_path.write_text(json.dumps(gates,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

state_path = root/'game/DEV_STATE.md'
state = state_path.read_text(encoding='utf-8')
state = state.replace('## 正在进行','## G0/G1 历史实现与验证')
state = state.replace('2026-10-17，当前 G2 开发中，G1 已通过，构建 G2-006。G0 技术检查完成，有环境限制见下。','2026-10-17，当前 G2-007 技术检查已通过，H2 待人工审核，G3 禁止开始。审核包：deliverables/G2_Review/动作审核.exe。最终报告：qa/G2-007-gate-report.md。')
state = state.replace('3. 开始制作 G2 真实动作、音效和 H01～H06 审核台。','3. G2-007 技术检查已完成。检查当前构建的用户聊天反馈或人工 review.json；不要把 qa-review、clean 验证目录中的测试反馈当成人工结论。')
state = state.replace('4. G2 技术验证完成提交人工 H2，未经明确批准不得进入 G3。','4. 六项 H2 尚未获得用户明确通过。没有当前构建的明确批准不得进入 G3；等待期间仅处理审核反馈/证据维护，不重复已通过测试或批量制作后续内容。')
state = state.replace('正常桌面默认目录启动仍待验证。','G2-007 已修复普通启动并验证便携后备目录保存/重启恢复，详见本轮报告。')
state = state.split('## G2-007 审核台与技术收尾')[0]
state += '\n## G2-007 审核台与技术收尾\n\n'
state += '- 已完成 H01～H06 原生审核台、两分钟巡览、播放/停帧/方向/尺度、设置、自由试打、问题截图与反馈保存/导出/复制。四向动作、三法术、盾/雨/护壳、预警及两种背景共用正式组件。保留用户认可的 G2-005 握杖，不新增肢体。\n'
state += '- 修复顶部相机/像素采样、净光射线与杖头连接、近击预警阶段、扫描重置、自由试打暂停、点击位置锁存、PC 日志启动退出、用户目录不可写时的后备保存和剪贴板短暂占用。\n'
state += '- 549 模型 / 118 战斗集成 / 50 审核集成通过；最终 30/60/144 回放一致。中文命名干净包通过完整检查，普通环境下保存与重启恢复通过。\n'
state += f"- 900 秒完整负载完成，标准/低档平均 {stress['profiles']['standard']['average_fps']:.2f}/{stress['profiles']['low']['average_fps']:.2f} FPS；节点稳定，最后 5 分钟私有内存 {mem['last5min_min_mib']:.2f}～{mem['last5min_max_mib']:.2f} MiB。初轮负载干扰证据不作最终结论，版本范围与长帧见报告。\n"
state += '- 当前环境反馈使用 deliverables/G2_Review/用户数据/reviews/G2-007；正常可写环境优先系统用户目录。真实交付记录均未审核，human_confirmed=false。不要导入 QA 人工结论。\n'
state += '- H2 已提交等待用户：动作自然度、声画力度、可读性与真实操作体验。用户此前“很完美”只认可握杖；未自动扩大为整个 H2。G3、主线、Boss 和最终验收未完成，自动化保留，但待审状态不变时保持安静。\n'
state_path.write_text(state,encoding='utf-8')
print('G2 technical records finalized; H2 remains pending human review.')
