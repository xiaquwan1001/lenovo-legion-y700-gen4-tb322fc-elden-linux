# lane S3：SSOT 并入第二轮（TASKS 剩余 79 条 + 其它角度残留）

## 语境
项目根 /home/xuqianhui/y700-elden。第一轮已关闭 TASKS 61 条 + DEVICE/RESOURCES/PITFALLS 18 文件。
本轮处理剩余：`rg -l '★SSOT 待并入' TASKS/sessions DEVICE/sessions RESOURCES/sessions PITFALLS/sessions`
里**尚未变成「无（…，2026-11-05）」**的那些（上一轮实测 TASKS 剩 79 条：散文式目标 42 / 空标记「正文在下方」21 / 显式 PENDING 12 / 已并入带残留注记 4）。

## 硬约束
- 只改 `TASKS/README.md`、`DEVICE/README.md`、`RESOURCES/README.md`、`PITFALLS/README.md` 与上述 `sessions/*.md`；其它文件不动（不碰 INDEX/AGENTS/reports/archive/scripts/versions）。
- **edit 定点替换，禁整文件 write**；每批 ≤20 条落盘一次。
- 不动 2026-11-05 父进程新写的行：`TASKS §7` 头部四条（投递批次沿革 / 当前一页 / 未答项 / 归档复核口径）、`RESOURCES §3` 可清理标记表的 A8/B1–B4/H1。
- 分类处置规则：
  * **散文式目标/标题块** ⇒ 标「无（非结论型条目）」，不往 README 塞。
  * **空标记 /「正文在下方」** ⇒ 读该文件正文取一句结论并入对应节；若正文本身是过程叙事 ⇒ 标「无（过程叙事留 sessions/）」。
  * **显式 PENDING（未并入/待父会话/待批）** ⇒ **原样保留不动**，回执列名。
  * **已并入但带残留注记** ⇒ 保留注记内容，只把标记改成标准式。
- 不改状态词/编号/日期/数字口径；不新增任务 ID；表格不得拆行；每条并入 ≤2 行、每格 ≤600 字符；不写死计数。
- 不 git commit（父进程统一提交）。

## 交付
- `/home/xuqianhui/y700-elden/reports/ssot-merge-20261105-round2.md`（并入条数 by 角度 / 关闭标记数 / 保留 PENDING 清单 / 未处理残留 / 新增超长行=0 / check-doctor 结果）。
- 回执 ≤25 行。
