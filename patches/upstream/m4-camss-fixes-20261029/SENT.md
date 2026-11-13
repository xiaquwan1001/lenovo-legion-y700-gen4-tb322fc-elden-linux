# 投递记录（2026-10-29 20:31 +0800，用户批准）

- 系列：`[PATCH 0/3] media: camss: three fixes for the CSID power and VFE streaming paths`
- **To**：`linux-media@vger.kernel.org`
- **Cc**：Mauro Carvalho Chehab `<mchehab@kernel.org>`、Bryan O'Donoghue `<bryan.odonoghue@linaro.org>`、
  Vladimir Zapolskiy `<vladimir.zapolskiy@linaro.org>`、Loic Poulain `<loic.poulain@oss.qualcomm.com>`、
  `linux-arm-msm@vger.kernel.org`、`linux-kernel@vger.kernel.org`
  （收件人由 `scripts/get_maintainer.pl` 在 `build/m4-base` 上按改动文件算出）
- 投递方式：`git send-email`（USTC SMTP，非手写 patch），4 封 **`Result: 250`**
- Message-ID：
  - `20261029123107.28705-1-xiaqinghuan@mail.ustc.edu.cn`（0/3 cover）
  - `20261029123107.28705-2/-3/-4-xiaqinghuan@mail.ustc.edu.cn`（1/3、2/3、3/3）
- **lore 归档复核**（按 Message-ID 取 raw）：`/all/` **4/4 HTTP 200**，封面 Subject/From 逐字核对通过
- 内容边界（cover 明写）：不含 SoC 使能 / DT binding / CSIPHY 改动；九枚「add SM8750 support」已按
  2026-10-29 列表承诺撤下
- 投递前门禁见 `GATES.md`（pristine `git am` 3/3、`checkpatch --strict` 3/3 0E0W0C、camss 目录 `W=1` 0 warning）
- 待办：盯 review（Bryan / Vladimir / Mauro）；**未上机**（2/3 改变缓冲校验行为）

## ★2026-11-13 复核更正：本目录三枚已被自己的 v2 系列替代，投递意图作废

patchwork 现查（`api/1.2/patches/<id>/`）：
- 本目录三枚 `14924247`(2/3) / `14924248`(1/3) / `14924249`(3/3) 全部落在 **`linux-arm-msm`** 项目，
  状态一律 **`handled-elsewhere`**、`archived=False` ⇒ **没有被 media 维护者采纳**（不是「在审」）。
- 真正的替代载体 = **系列 1197609** `media: camss: CSID power-on unwind and VFE stream handling`
  （**v2**，2026-10-31，`linux-media`，两枚 `state=new`）：
  - `[v2,1/2] 14928873` = 本目录 `0001`（csid unwind）
  - `[v2,2/2] 14928872` = 本目录 `0002`+`0003` 合并（pipeline stream on/off 抽 helper；
    **失败即 `camss_video_subdevs_set_stream(video, false)` 回退** = `0003` 的全部内容）
- ⇒ 后续只跟 1197609 v2 的 review，**不要再投本目录任何一枚**（会与自己撞车）。
- 全账：`reports/b2-camss-0003-recheck-20261113.md`；同时纠正 B2 原报告「10-29 已投且无反对 ⇒ 不重投」
  —— `handled-elsewhere` 的语义是「本项目不管」，不是「在审」。
