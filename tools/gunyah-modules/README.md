# Gunyah 主线侧模块源码（对应 build/gunyah-port 的外置模块）

这三个件是「TZ SIP → hyp boot info → 厂商 DTBO overlay → RM 可用」的实现，与在机验证过的
`.ko` 逐字同源（2026-10-24，见 `reports/gunyah-mainline-rm-up-20261024.md`）。

| 目录 | 作用 |
|---|---|
| `hypprobe/` | 只读探针：打 `arm_smccc_smc(0x02000609)`、校验 magic `0xC06B0071`、hexdump HBI 与 DTBO |
| `dtbo/` | 正式件：同上 + `kmemdup` 每个 DTBO + `of_overlay_fdt_apply()`（debugfs 导出 `elden-gunyah/dtboN`） |
| `rmtest/` | 静态 aarch64 程序：`open("/dev/gunyah")` + `ioctl(GUNYAH_CREATE_VM)` = 一次真实 RM RPC |

构建/部署/验证走 `scripts/gunyah-rm-bringup.sh`（它直接在 `build/gunyah-port` 里 `make M=`）。
前置：板 DTB 需带 `__symbols__`（`patches/gunyah/0001-arm64-dts-qcom-elden-enable-dtc-symbols.patch`），
否则 overlay 解析 fixups 一律 `-EINVAL`（PITFALLS #389）。
