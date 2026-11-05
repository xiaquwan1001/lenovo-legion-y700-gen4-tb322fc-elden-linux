# lane V：全仓数据完整性校验（带重试定性）

## 语境
项目根 /home/xuqianhui/y700-elden，HEAD 干净（开工前确认）。本机 2026-11-05 已发生 3 起静默数据损坏
（out/boot-elden-m3v5-daily.img、build/b5-v2 文件名位翻转+基对象不可读、.git pack 校验和不符）；
用户已把 BIOS 改回保守设置并另派稳定性测试 agent。**本轮要求：凡校验一律「失败重试一次」再定性**，
把「瞬时读错」与「真损坏」分开记录。

## 硬约束
- **只读**：不得修改/删除/移动任何既有文件；不 git commit；不上机；不发邮件。
- 只允许**新建**自己的交付文件。
- 每条结论带可复现命令；未证写「未证」。中文输出。时间盒 ≤40 分钟，超时就落盘并如实报未完成范围。

## 校验矩阵（每项都跑，结果进表）
1. **git 仓库**：项目根 `.`、`geekidos-linux`、`build/m3v2-7.3rc7`、`build/base-7.2`、`build/daily`（若是 worktree 会共享 .git，注明即可）。
   每仓跑：`git fsck --full --no-dangling`、`git count-objects -v`、`git verify-pack -v .git/objects/pack/*.idx | tail -2`、`git rev-parse HEAD`。
   **失败重试**：同一命令重跑一次；仍失败才判红。注意 build/* 多为浅克隆（.git/shallow），缺父提交属预期，别当损坏。
2. **产物镜像**：`out/*.img`（129 件 / 9.43 G）逐个 sha256sum，与对应 `out/*.manifest` 记录的镜像 sha 比对（先看一个 manifest 的字段名）；
   无 manifest 的单列「无基线」。**不一致时**：再算一次 sha256 并比对两次结果——两次不同 = 读取不稳定；仍不一致 = 疑似真损坏（再用 `dd iflag=direct` 抽读同区域做第三次对照）。
3. **备份/封存件**：`backup/build-bundles/*.tar.zst`（`zstd -t`）、`backup/git-repair-20261105/*.zst`、全部 `backup/**/SHA256SUMS`
   （`sha256sum -c`，只跑存在对应文件的条目；缺失单列）、`reports/artifacts/**/SHA256SUMS`。
4. **文本层稳定性**：`git ls-files -z patches versions scripts | xargs -0 sha256sum > /tmp/t1` 跑两遍比对；
   另检查是否有 0 字节文件、`.patch` 里不含 `diff --git` 的异常件。
5. **不可及**：在机 boot_b / GPT 等设备侧本轮不校验（如实标注）。

## 交付
- `/home/xuqianhui/y700-elden/reports/integrity-audit-20261105.md`：§0 一句话结论（几红几黄）+ §1 汇总表（项/件数/失败数/重试后恢复数/真损坏数）+ §2 逐条异常（路径、期望 vs 实测、重试结果、定性）+ §3 未覆盖范围 + §4 复核命令。
- 机器账 `/home/xuqianhui/y700-elden/reports/integrity-audit-20261105.tsv`（列：scope\tpath\texpected\tactual\tretry_result\tverdict）。

回执 ≤25 行：交付路径 + 关键数字（红/黄/恢复数）+ 复核命令。
