# M6 DSI-PHY v3 —— 已投（2026-11-26T05:20:49Z = CST 13:20:49）

| 项 | 值 |
|---|---|
| 线程形态 | **新线程**（无 `In-Reply-To`；Jianfeng 指出 v2 那封 11-17 信 thread 断裂/subject 空） |
| 收件人 | To `linux-arm-msm`；Cc `dri-devel`/`freedreno`/`lkml`/robin.clark/lumag/abhinav.kumar/jesszhan0024/sean/marijn.suijten/dmitry.baryshkov、**liujianfeng1994@gmail.com（Tested-by 提供者）** |
| Message-ID | `<20261126052049.1544229-1-xiaqinghuan@mail.ustc.edu.cn>` |
| 结果 | **`Result: 250`**（1 封，全收件人接受；日志 = `logs/sent-*.txt` 由 SEND.sh 落盘） |
| 内容 | v2 的 `diff --git` 段**逐字节相同**（`cmp`）；仅 `[PATCH v3]` 代次 + `Tested-by: Jianfeng Liu <liujianfeng1994@gmail.com>` + `Changes since v2` |
| 门禁（投前，父代理独立复跑） | `git apply --check` rc=0 · checkpatch（geekidos-linux 全历史树）`0 errors, 0 warnings, 0 checks` · `SEND.sh --dry-run` OK |
| lore 复核 | **✅ 已归档两处**：`/linux-arm-msm/`（线程页标题/MID 逐字、`Tested-by` 在档、3 条 `Link:` 齐）与 `/dri-devel/`（同一 MID，05:21:13Z） |

## 下一步

1. ~~lore 归档命中后回填~~ **已完成（2026-11-26T05:2xZ 父代理 web_fetch 复核两处）**。
2. patchwork 摄取滞后属正常（口径：lore 为准）。
3. 盯 Dmitry Baryshkov（评审人）与 Jianfeng 的后续；若维护者要求与其它补丁合批，按 §7 口径回信。

## 2026-11-28 06:2xZ（D10 lane 独立扫到，父代理记账）

- **Dmitry Baryshkov 2026-11-27T20:26:52Z 回帖给 `Reviewed-by: Dmitry Baryshkov` + `Cc: <stable@vger.kernel.org>`**（挂在本 v3 线程，见
  `reports/comms-track-20261128.md` §4/§1-9）。⇒ 我方版本次轮不改（R-b 由维护者取件时带上），**不道谢、不重投**；
  若需要 v4（例如 Krzysztof 提 binding 问题）则把该 R-b 一并带进封面。
- 同窗口礼貌补记：`coresight MODULE_DEVICE_TABLE` 的 James Clark `Reviewed-by:` 已在 v2（13:31Z）内闭合；`iris v4l2-compliance` 的 Bryan 意见另见 `patches/upstream/v4l2-compliance-iris-20261127/SENT.md`。
