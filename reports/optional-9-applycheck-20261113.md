# 可选 9 条逐枚 `git apply --check`（B11，2026-11-13）

> 只读 lane。**没有 apply、没有编译、没有上机**。临时副本 `/tmp/b11-daily`（`cp -a build/daily`，
> HEAD `4da9a8b69fc`，13 G，可留可删）；patch 原件在 `/tmp/b11/p/`。
> 结论用**冲突裁决建议**，是否排期仍由 A22 裁决。

## §0 结果（rc 逐枚）

| 条目 | patchwork id | rc | 冲突落点 | 裁决建议 |
|---|---|---|---|---|
| #4 pinctrl qcom shutdown UAF | 14954301 | **0** | — | 可直接 apply（前向树/daily 都干净） |
| #5 uefisecapp GetNextVariableName 溢出 | 14951766 | **0** | — | 直接 apply |
| #6 dwc3-qcom `read_usb2_speed` hcd 判空 | 14956144 | **0** | — | 直接 apply；**先于 M3-1 v9 本地分支**（同文件） |
| #7 dwc3 host 等端口离开 RxDetect | 14957329 | **0** | — | 直接 apply |
| #8 camss v2 1/4 Kconfig | 14964184 | **1** | `drivers/media/platform/qcom/camss/Kconfig:5` | 人工解：payload v2 改过该 Kconfig 开关段，冲突是上下文级；建议**整组 4 枚一起手工移植**，不单枚硬塞 |
| #8 camss v2 2/4 vfe-4-1 RDI buffer size | 14964185 | **0** | — | 随组 |
| #8 camss v2 3/4 video.c always stop pipeline | 14964186 | **1** | `camss/camss-video.c:313` | 与 payload 的 `video_stop_streaming()` 改动正面重叠（和 0007/`0003` 同函数）；**手工移植时与 0007 一起看**，避免重复 stop 逻辑 |
| #8 camss v2 4/4 camss.c CSID 无匹配 VFE | 14964187 | **0** | — | 随组 |
| #9 drm/msm/dp enable 失败跳过 teardown | 14943452 | **1** | `drivers/gpu/drm/msm/dp/dp_display.c:1528` | payload 改过该函数；前向树（`build/m3v2-7.3rc7`）rc=0 ⇒ **优先落前向树**，daily 只在手工解冲突后落 |
| #10 UBWC 1/7 RGB 注释 | 14944889 | **0** | — | 只取 1/7 + 3/7（2/7 已知两树都 FAIL） |
| #10 UBWC 3/7 布局校验 | 14944891 | **0** | — | 同上 |
| #11 ath12k regulatory 先于 wiphy | 14952186 | **0** | — | 直接 apply；上机 `iw reg get` 回归 |
| #12 cmd-db probe race | 14944582 | **0** | — | 直接 apply |

汇总：**13 枚实测，10 枚 rc=0，3 枚 rc=1**（camss Kconfig / camss-video / dp_display），与 11-12 评估
「camss 2/4 冲突、dp 冲突、UBWC 只取 1/7+3/7」**逐条吻合**。

## §1 建议顺序（若 A22 放行）

1. 前向树 `build/m3v2-7.3rc7`：10 枚 rc=0 一次 apply（含 dp，前向树 rc=0）。
2. 手工组：camss v2 四连（daily）+ 0007 一起解；dp 的前向树已有、daily 后补。
3. 每组都按 `reports/upstream-merge-candidates-20261112.md` §4 的门 1（只编受影响 .o）→ 门 2（整树）→
   上机判据走；本 lane 未跑任何编译。

## §2 未完成

- **未 apply、未编译、未上机**（时间盒）。
- `build/daily` 是**副本**，不是工作树；今晚若要真 apply，建议在真树上重复本表作为复核。
