# 资产精简执行账（2026-11-11，用户裁决「可以精简删除」）

依据：`reports/project-audit-20261111.md` §2/§3/§4。**只删可再生/已被取代的件，不动 SSOT、回滚件、在机镜像。**

## §1 已执行删除（净释放 ≈ 4.0 GiB；`df /` 544 G→540 G used，可用 346→350 G）

| 路径 | 体积 | 删前 sha256 | 理由 |
|---|---|---|---|
| `env-pass/backup-20261002/linux17-rootfs-20261002.tar.gz` | 3.3 G | `59791e639b5db44893b2ca594de95398ea2508d074e298ff3d958847cdfc3c57` | 2026-10-02 的旧 Alpine rootfs 快照，已被 2026-10-26 Debian/Mobian 换根取代（现行根 `/dev/sda17` ext4 Debian）。目录删空后一并移走 |
| `dl-cam/stage/` | 108 M | —（目录内多个中间产物） | C5/U7 摄像头烘焙的中间暂存，可由 `scripts/waydroid-camera-bake.sh` 从 `dl-cam/ndk|sysroot|aosp` + `vendor-orig.img` 重跑再生 |
| `backup/kernel-git-repair-2026-10-10/` | 265 M | —（目录） | git 修复备份第 3 代，已被后续两代取代 |
| `backup/kernel-git-repair-2026-10-23/` | 290 M | —（目录） | 同上第 4 代 |
| `backup/git-history-rewrite-20261026/` | 163 M | —（目录） | 历史重写备份旧代，被 `git-history-rewrite-20261103`（保留）取代 |
| `patches/config-before-fragment-*.bak`（12 份删、留最近 1 份） | <1 M | — | fragment 应用前的自动备份；对应 fragment 均已合入现役 config |

## §2 复核后**不删**（与审计建议不同，理由在此）

| 路径 | 体积 | 不删理由 |
|---|---|---|
| `dl-cam/vendor-orig.img` | 256 M | **`scripts/waydroid-camera-bake.sh` 直接引用**（sha `6765bb49…`）⇒ 删了会让 C5 重烘焙脚本立刻失效，而原版 vendor 需从官方包再抽。降级为「保留」 |
| `dl-cam/ndk`（1.7 G）/`sysroot`（228 M）/`aosp`（118 M） | 2.0 G | NDK/AOSP 头文件只能从 Google 侧下载，本轮**外网不通**；删了就没有离线重烘焙能力 |
| `out/` 内 `uefi-20261104*` 作废件 | 257 M | 已在 `versions/out-images-sha256-20261105.tsv` 有 sha 行（H2 复算集），删除需同步改基线表；体积小于改表风险 ⇒ 暂留（下次 H2 轮一并处理） |
| `backup/f2fs-migrate-20261025-205702…210451`（5 份） | 各 28–136 K | 合计 <0.5 M，纯记账价值，删了无收益 |
| `backup/official-rom-15.10.259`（16 G）/`stock-259`/`fw`/`stock-elden` | — | 官方固件不可再生；`stock-259` 是逐分区提取件，与 16 G 原包互补 |
| `wt/reb-731`（13 G）、`build/daily|m3v2` 等、`bootslot-b/`+UEFI 回滚件 | — | 在机内核/模块的可复现源与回滚依赖，用户已在 11-05/11-10 裁决保留 |
| `backup/git-history-rewrite-20261103`（280 M）、`backup/git-repair-20261105`（882 M） | 1.16 G | 最新两代，保留一代现役 + 一代上代 |

## §3 复核后落地情况

- `scripts/check-doctor.sh` → **FAIL=0 WARN=6**（删除前后一致；WARN 均为既有在途豁免/账本例外/历史留白）。
- 目标盘 `df /`：可用 346 G → **350 G**。
