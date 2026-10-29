# #469 对照上游必须取**最新 revision**：线程里出现的 vN 可能落后十几版

## 结论（2026-10-29 实测）

- lane 做「我方 camss v3 vs 上游」对照时，用的是评审线程里出现的 **v6**（`20260721-…-v6`），
  结论「重叠 5/9」。
- 真正的最新是 **`[PATCH v23 00/15] media: qcom: camss: Add Kaanapali support`**
  （Hangxiang Ma，2026-10-28，series msgid `20261028-kaanapali-camss-v23-*@oss.qualcomm.com`），
  **同一系列已迭代 23 版**、覆盖面更大（15 枚：PHY 3 + CAMSS 8 + DTS 4）。
- 更关键：v23 的 changelog 明写
  「**Replace the CSID AUP/RUP union with separate reg_update/addr_update field pairs**」
  —— 与我们 0004（csid-980 的 `reg_update/rup_update/aup_update` 三联 + 锁）**同一处代码**。
  若按 lane 的 v6 结论只「放弃 0001/0004/0008」，再基于 v6 发 0003/0007，评审很可能直接指出「v23 已经做了」。

## 定式

① 判「上游有没有做这件事」前，先用 **`SUBJECT` 检索自己的 INBOX + 列表归档**取**最新 vN**
   （本项目最快路径：`read-mail-ustc.py --days 7 --grep "<关键词>"`，再按 Subject 里的 `v<N>` 取最大）。
② 看 **cover letter 的 changelog**，不要只看 patch 数量：本次唯一的重合点（CSID AUP/RUP）是在
   `Changes in v23:` 里写出来的，patch 标题看不出来。
③ 结论里必须写明「对照的 revision + 该 revision 的日期/msgid」；只有旧 revision 时写「未取到最新 revision」。

