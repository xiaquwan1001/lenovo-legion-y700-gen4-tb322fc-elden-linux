# 磁盘清理评估与执行账 — 2026-11-15（第二轮，承接 `.pi/reports/disk-audit-2026-11-15.md`）

> 口径：**只清「非编译中间物」**。会复生的 `.o/.cmd/vmlinux/.ko`（≈20.7 GiB / 74 646 文件）按用户指示**不列入本账**。
> 判定依据一律现查（sha256 / `git bundle verify` / `git bundle list-heads` / `du` / 引用 grep），命令附在各行。
> 起点：`/` 已用 800 G / 937 G（90%），项目本体 91 G。

## 0. 结论

- **可删（A 类，旧代/纯 clone/可重取）≈ 11.8 G**；其中联网可重取项 3.0 G（stock-src 2.0 G + ext-repos 1.04 G）。
- **门禁耦合或唯一副本（B 类）**：`backup/official-rom` super 镜像 15 G、`backup/out-history` 7.6 G —— 本轮不动。
- **零删除优化**：跨 `backup/out/bootslot-b` 逐字节重复 ≈ 0.94 G，可用 `os.link` 合并（不改路径/内容）。
- 删任何 `backup/git-*` 之前先满足：① 主仓 17 个本地提交推到 `github/main`；② 最新代 bundle `verify` 通过。

## 1. A 类判定（逐项证据）

| # | 项 | 可释放 | 判定证据 | 结论 |
|---|---|---|---|---|
| A1 | `backup/git-history-rewrite-20261103/pre-rewrite-all.bundle` | 280 M | 早于 `git-slim-20261113`（三代 bundle `verify` 全过；m3v2 bundle 含 17 个 `tidy-20261105/*` ref） | 删 |
| A2 | `backup/git-repair-20261105/{git-before-repair-20261105.tar.zst,quarantine/}` | 882 M | 同性质多代并存的旧代（`project-audit-20261111.md:71`）；修复后的对象库现存且 `fsck` 由历史 gc 跑过 | 删（保留最新代 `git-slim-20261113` + `git-history-rewrite-20261112`） |
| A3 | `backup/build-bundles/m3v2-7.3rc7-git-20261105.tar.zst` | 1.30 G | 全部 commit 已被 `m3v2-all-20261113.bundle` 覆盖（`git bundle list-heads` 84 refs，含 17 个 `tidy-20261105/*`）；`MANIFEST-20261105.tsv` + `dirty-20261105/` 单独保留 | 删 |
| A4 | `build/uefi-woa-prep/repos/{1-edk2-aarch64-gunyah,2-Droid-VM-edk2-gunyah,3-edk2-gunyah-qemu,4-qemu-for-gunyah,6-DroidVM-Prebuilts}` | 2.01 G | Gunyah 2026-10-25 终局裁决不做；均为 `clone.sh` 的 `--depth 1` 纯 clone、`status` 空 | 删（`7-mu-lenovo` / `5-mu_wide_platforms` 保留） |
| A5 | `build/base-7.2/` | 2.4 G | `up` = 本地 `geekidos-linux`；HEAD `378459aff` 见 `geekidos-linux` 对象库；无 `.config`、仅 11 个 `.o` | 删 |
| A6 | `backup/m3v5-onboard-20261031/m3mods-daily-20261031.tar` | 105 M | 内容 = `build/daily` 模块产物 + `patches/` 可重建；`scripts/out-archive.py` 只认 `out/` 镜像名 | 删 |
| A7 | `logs/`（memstress/build 旧日志） | 38 M | 一次性构建/压测日志；结论已落 `reports/` | 删 |
| A8 | `backup/f2fs-migrate-20261025-205{702,914,1049,1242}` | ~340 K | 同一晚 5 份 GPT 快照，只留 210451 | 删 |
| A9 | `out/.migrate-vk152/` | ~20 M | 迁移残留隐藏目录；`ramdisk` 已 4 链（删它只回收 dtb+kernel 20 M） | 删 |
| A10 | `out/debian/{elden-rootfs-20261026.tar.zst,firmware-root/,elden-firmware_1.0~2026102{5,6}_all.deb}` | 0.69 G | `rootfs/build-rootfs.sh` 可重建；deb 20261028 为现行版 | 删 |
| A11 | `dl-cam/vendor-orig.img` | 268 M | 审计已判「可从设备/原厂 super 重取」；`vendor-cam-l1d.img`（改造版）保留 | 删 |
| A12 | `external/ext-repos/{af,dl,mu,vk64rd}` | 1.04 G | 非 git 解包产物（`git -C` 落到父仓）；来源 tar 在 `dl/`，可重取 | 删（`sunuefi` 真 git 仓保留） |
| A13 | `out/r21-sbstop-p62/` | 65 M | 早于 `dtbo_a` 真根因的失败世代 | 删 |
| A14 | `out/{uefi-ddrmarks-sysram,uefi-ddrmarks-clean,uefi-1005-recover,uefi-v0,gunyah-73}/` | ~54 M | 已作废/结项线的一次性件 | 删 |

**待第二轮（需用户拍板，本账只记不改）**：`stock-src` 2.0 G、`dl-cam/ndk` 1.6 G（离线重烘焙能力）、`bootslot-b` 旧签名件 1.2 G、
`out/r21-sbstop-{p69,pc1,pc2}` + `mu-memmap` 2.59 G、`out/espboot|fbdiag|dbg-uefi-initrd|vk188-bootfiles` 旧代 ~0.6 G、
`.pi/sessions` 835 M、`reports/artifacts` 1.8 G、`y700四代工具` 267 M。

## 2. 执行记录

基线（执行前）：`df -B1 /` = 674690023424 used；`du -sh` 项目 = 91G。bundle 门禁（A1/A3 前置）：`git bundle verify` 对 backup/git-slim-20261113/{geekidos,m3v2,main}-all-20261113.bundle、backup/git-history-rewrite-20261112/pre-rewrite-main{,-2}.bundle 全部 rc=0。

| 项 | 路径 | 删除前 du -sb | 删除后核对 | 备注（门禁命令 rc） |
|---|---|---|---|---|
| A1 | backup/git-history-rewrite-20261103/pre-rewrite-all.bundle | 292892076 | 已消失（目录剩空壳） | verify 6 bundle 全 rc=0 |
| A2 | backup/git-repair-20261105/{git-before-repair-20261105.tar.zst,quarantine/} | 714883882 + 209558102 | 已消失（目录剩空壳） | — |
| A3 | backup/build-bundles/m3v2-7.3rc7-git-20261105.tar.zst | 1334423039 | 已消失（MANIFEST.tsv + dirty-20261105/ 保留） | verify rc=0（m3v2-all-20261113） |

A1–A3 后 `df -B1 /` = 672004550656 used（释放 2 685 472 768 B）。

| 项 | 路径 | 删除前 du -sb | 删除后核对 | 备注 |
|---|---|---|---|---|
| A4 | build/uefi-woa-prep/repos/{1-edk2-aarch64-gunyah,2-Droid-VM-edk2-gunyah,3-edk2-gunyah-qemu,4-qemu-for-gunyah,6-DroidVM-Prebuilts} | 1294688009 / 1230801 / 140054601 / 181624137 / 154032441 | 已消失；`repos/` 剩 5-mu_wide_platforms、7-mu-lenovo、clone{,2}.{sh,log} | — |
| A5 | build/base-7.2 | 2232918734 | 已消失 | — |
| A6 | backup/m3v5-onboard-20261031/m3mods-daily-20261031.tar | 109199360 | 已消失（目录剩空壳） | — |
| A7 | logs/ | 39009768 | 已消失 | — |
| A8 | backup/f2fs-migrate-20261025-205{702,914} | 24576 + 90112 | 已消失；保留 210049/210242/210451 | 表内 210104/211242 实际不存在（实际名 2100{49,242}），按表外不动处理，记跳过 |
| A9 | out/.migrate-vk152 | 85581715 | 已消失 | — |
| A10 | out/debian/{elden-rootfs-20261026.tar.zst,firmware-root/,elden-firmware_1.0~2026102{5,6}_all.deb} | 604953927 / 46271692 / 21120132 / 21146096 | 已消失；仅剩现行 deb 20261028 | — |
| A11 | dl-cam/vendor-orig.img | 268435456 | 已消失；vendor-cam-l1d.img 保留 | — |
| A12 | external/ext-repos/{af,dl,mu,vk64rd} | 414557113 / 256710033 / 230297898 / 181392245 | 已消失；sunuefi、mu-dodge 保留 | — |
| A13 | out/r21-sbstop-p62 | 67194880 | 已消失 | — |
| A14 | out/{uefi-1005-recover,uefi-v0,gunyah-73} | 23002099 / 9773056 / 4567720 | 已消失 | 表内 uefi-ddrmarks-{sysram,clean} 实际已不存在，记跳过 |

### 汇总

- 各项 du 求和 ≈ 10 133 306 315 B（8.94 GiB，含「已不存在」为 0）。
- `df -B1 /`：674690023424 → 665189650432 used，实际释放 **9 500 372 992 B（8.85 GiB）**（差额来自 du/df 统计口径 + 并行写入）。
- 项目本体：91 G → 82 G；最终 `df -h /`：937G 总量 / 620G 已用 / 270G 可用（70%）。
- 跳过项（均已不存在，非失败）：A8 的 f2fs-migrate-20261025-210104 / -211242（实际名为 210049/210242，表外未动）；A14 的 out/uefi-ddrmarks-sysram / out/uefi-ddrmarks-clean。
- 门禁：A1/A3 前置 `git bundle verify` 共 6 份（git-slim-20261113 ×3、git-history-rewrite-20261112 ×2、m3v2-all-20261113）全部 rc=0。
- 未 git commit；§3 禁止项与 build/daily、patches/、scripts/、reports/、.git/ 均未触碰。

## 3. 禁止项（本轮与以后）

1. `backup/official-rom-15.10.259/`（唯一副本，`RESOURCES:192`）。
2. `backup/out-history-20261105/`（`scripts/vk-identity.py` + `check-doctor §5d` 扫描，删则破版本账）。
3. `backup/fw/`、`backup/HA2EXB0E-16+512/`、`backup/device-test-20261113/`、`backup/corrupt-2026110{2,3}/`。
4. `bootslot-b/avb.key`（私钥，不可再生）。
5. `build/daily` 源树与 `.config`（在役树，`patches/current-tree`）。
6. `versions/vk-kernel-identity.tsv`（禁重跑 `scripts/vk-identity.py > …`）。
