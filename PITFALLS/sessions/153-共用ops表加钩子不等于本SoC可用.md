# #489 · 共用 host-ops 表里加钩子 ⇒ 「钩子存在」不等于「本 SoC 可用」

日期: 2026-11-02
pi 会话 id: 01a19c09-0624-77a4-9612-428ce040917a（收尾轮，父会话）
主题: M6 B5 v2（drm/msm dsi bonded 命令路径）在重出时发现的门控缺陷；推广到「ops 表共享 + per-SoC 数据」这一结构
结论: 把新钩子塞进**被多个 SoC 共用**的 host-ops 表，再用 `ops->hook != NULL` 当「本 SoC 支持」的判据，等于让**所有**共享该表的 SoC 都走进新路径 —— 本机 SM8650 双 DSI 板会在面板 DCS 写上解引用 NULL 的 per-SoC 数据。判据必须是 **ops 存在 ∧ per-SoC 数据非空**
证据指针: `patches/upstream/m6-b5-v2-20261102/{GATES.md §0,logs/gate-sm8650-no-bonded.txt}`、`reports/m6-b5-v2-parent-review-20261102.md`
★SSOT 待并入: 已并入本文件（PITFALLS 索引 #489）

---

## 现象（缺陷形状）

`dsi_cfg.c` 里 `msm_dsi_6g_v2_9_host_ops` 是 **SM8650 与 SM8750 共用**的一张表（两者都报 6G v2.9），
v2 把新的 `.bonded_cmd_xfer` 加在这张表上，manager 侧这样判：

```c
	ops = msm_dsi_host_get_cfg_ops(dsi->host);
	return ops && ops->bonded_cmd_xfer;      /* ← 只看钩子在不在 */
```

而钩子内部第一件事就是取 per-SoC 数据：

```c
	const struct msm_dsi_bonded_cfg *bonded = msm_host->cfg_hnd->cfg->bonded;
	val |= bonded->err_clear_bits;           /* SM8650: bonded == NULL */
```

⇒ 树内 **`sm8650-ayaneo-pocket-s2`**（`qcom,dual-dsi-mode` + `qcom,sync-dual-dsi` + `qcom,master-dsi`）
在面板 DCS 写上就会进这条路径 ⇒ `NULL` 解引用。触发条件不是「有人用了新特性」，而是
「树内已经有板子同时满足 bonded + sync 且与 SM8750 共用 ops 表」。

## 为什么没被 v1 抓到

v1（2026-10-31 已投的 5 枚）的门控是 **SoC 特判**：

```c
	return msm_dsim_glb.is_sm8750 && IS_BONDED_DSI();   /* SM8650 天然安全 */
```

v2 按 reviewer 意见**去掉 `is_sm8750` 特判、改成「问 per-SoC 数据」** —— 方向是对的，但只把数据
搬进了 cfg 表，没有把数据接到判断上，于是把 v1 那道（丑但有效的）门一起删了。

## 修法与判据

```c
	ops = msm_dsi_host_get_cfg_ops(dsi->host);
	if (!ops || !ops->bonded_cmd_xfer)
		return false;

	return msm_dsi_host_get_bonded_cfg(dsi->host);   /* 新增 accessor */
```

静态判据（不依赖上机，可进门禁脚本）：

```bash
# 只有新 SoC 的条目带数据
grep -n '\.bonded = ' drivers/gpu/drm/msm/dsi/dsi_cfg.c          # 唯一命中 sm8750_dsi_cfg
# 共用表的条目里，非新 SoC 那条必然取不到数据
grep -n -A2 'MSM_DSI_6G_VER_MINOR_V2_9_0' drivers/gpu/drm/msm/dsi/dsi_cfg.c
```

## 教训（可推广）

- **「钩子在不在」只在「一表一 SoC」时才等价于「本 SoC 支持」**；共用表的场合必须再看 per-SoC 数据。
- 删 SoC 特判（`is_smXXXX`）是好事，但**必须把特判承载的信息迁到判断处**，不只是迁到数据表里
  —— 迁移只做一半，等价于删除保护。
- 这类缺陷**不会被编译器和 checkpatch 抓到**（指针非空判断在编译期成立），也不会被「新特性没上机」
  掩盖；唯一便宜的发现方式是**逐块列出「谁会走到这段新代码」**（本轮的判据：树内 6 块
  `qcom,dual-dsi-mode` 板，其中共享 v2.9 ops 表的就是 SM8650）。
- 反向推论：**「新增路径树内无使用者」这个 review 疑虑有时是伪命题** —— 真正的风险往往相反，
  即「有使用者，而且会被误伤」。查使用者时两条都要查：谁**需要**它、谁**会误入**它。
