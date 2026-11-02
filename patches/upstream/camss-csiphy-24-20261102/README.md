# camss CSIPHY 2.4.0 lane 表（SM8750）—— 单枚，**备料，不发**

- 来源：`patches/upstream/m4-camss-series-20261028-v2/0002-...`（原 9 发系列 2/9），**内容零改动**。
- 重切基线：公开 **Linux v7.4-rc1 = `6628e7d4c6`**（真 Linus commit，`git am` 干净应用；7.3-rc7 的 `24a19b953` 已不是最新基线）。
- 规模：2 文件 **+125 −0**（`camss-csiphy-3ph-1-0.c` +124、`camss.h` +1）。
- 门禁（编排者独立复跑，见 `logs/`）：`checkpatch --strict` **0E/0W/0C（149 行）**；
  `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j26 W=1 drivers/media/platform/qcom/camss/` **rc=0 / 0 warning**。

## ★为什么不能单独投（2026-11-02 复核新增结论）

本枚在 **v7.4-rc1 树内没有使用者**：`CAMSS_8750` 这个 `enum camss_version` 值只由 `csiphy_init()` 的
`switch` 使用，而赋值方是 `camss.c` 的 `camss_resources[]` 表项 —— 公开树里**没有任何 SM8750 表项**
（`git show 6628e7d4c6:.../camss.c | grep -c 8750` = **0**；`camss.h` 里也还没有 `CAMSS_8750`）。
⇒ 单投时评审的第一句话仍会是「who sets CAMSS_8750 / 使用者呢」。

`reports/camss-delta-20261102.md` §3 第 1 条原写「4 枚独立小修可先投」需按此更正：

| 4 枚「独有」 | 现状 |
|---|---|
| csid power-on unwind | **已于 2026-10-29 投出并归档**（`patches/upstream/m4-camss-fixes-20261029/` 1/3，MID `20261029123107.28705-2`） |
| video DMA 连续性 + prepare 钩子 | **同上**（2/3，`...-3`） |
| video 起流失败回退 | **同上**（3/3，`...-4`） |
| **csiphy 2.4.0 lane 表（本目录）** | **不独立** —— 依赖 Hangxiang Ma 的 SM8750 camss 使能系列（`[v6 0/7]`）落地 |

⇒ 正确落点 = **作为回帖/增量挂到 Hangxiang 的 v6 线程**（或等其 SoC 资源表被接受后单独发），
**不要自成线程**；本批 **不发**（投递仍需用户按系列批准）。

## 复跑

```bash
cd /home/xuqianhui/y700-elden
git -C build/b5-v2 worktree add -f /tmp/wt-camss6628 6628e7d4c6 -b tmp/camss-csiphy-24
cd /tmp/wt-camss6628
git am --keep-cr /home/xuqianhui/y700-elden/patches/upstream/camss-csiphy-24-20261102/0001-*.patch
cp /home/xuqianhui/y700-elden/build/m4-base/.config .
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j26 olddefconfig     # 必须带 ARCH=arm64，否则 ARCH_QCOM 被抹掉
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j26 W=1 drivers/media/platform/qcom/camss/
git show 6628e7d4c6:drivers/media/platform/qcom/camss/camss.c | grep -c 8750   # = 0 ⇒ 树内无使用者
```
