# y700-elden — 内核/引导类失败与洞察（索引件；正文按主题拆分，2026-11-26）

> 拆的原因：单文件 199 KB / 346 条，docs-health 只能靠体量豁免放行；拆开后每件 ≤50 KB。
> 检索语义不变（`mem -t failure <关键词>` 走 `failures*.md` 通配，跨件命中）。
> 纪律：每条一段、`---` 分隔；新条目写进对应主题件。拆分前全文 = git 历史（`git log -- .pi/memory/failures-kernel.md`）。

| 主题件 | 覆盖 | 条数 |
|---|---|---|
| `failures-kernel-misc.md` | 其余（构建脚本、工具链、取证方法等） | 87 |
| `failures-kernel-slot-avb.md` | 槽位 / vbmeta / AVB 自签 / ABL-XBL / 密钥 | 79 |
| `failures-kernel-display.md` | DSI / DRM / panel / DPU / mdss-dispcc / 背光 | 66 |
| `failures-kernel-boot-flash.md` | 刷机 / fastboot / EDL / GPT / 分区与打包 | 61 |
| `failures-kernel-power-io.md` | 电源 / 休眠 / USB-typec 取电 / 文件系统 / 容器与内存 | 25 |
| `failures-kernel-gpu-comp.md` | GPU / Adreno / 合成器（phoc-phosh）/ Wayland | 19 |
| `failures-kernel-boot-uefi.md` | UEFI / EDK2-Mu / BDS / ESP / LinuxLoader（间接引导链） | 9 |

> 原头部口径（保留）：y700-elden — 内核/引导/显示类失败与洞察（355 条）。2026-11-09 从全局记忆 failures.md 下沉（全局现已迁到 ~/.pi/agent/memory/，旧目录在 ~/.pi/agent/_archive/2026-11-11-hermes-memory/），原文未改；全局序号对应 `~/.pi/agent/_archive/2026-11-09-memory-audit/failures.md.round5.orig`。
