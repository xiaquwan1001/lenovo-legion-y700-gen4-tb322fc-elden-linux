# 磁盘审计报告 — /home/xuqianhui/y700-elden（2026-11-15 06:10–06:25 CST）

> 审计员角色：**只审计、不删除、不移动、不提交、不 gc、不碰设备**。
> 本文件是本次唯一写入产物。所有 du/find 均带 `timeout`。
> 数字口径：`du -h -d1/-d2`（apparent blocks）现查；`df` 现查。

## 0. 一句话结论

- 仓库 **88 G**（`du -sh .` = 90G 含 .git/隐藏），主机 `/` **740G/937G = 84%，可用 150G**。
- 全部大头都**已被 `.gitignore` 排除且大多可复现**：`build/`(28G) + `wt/`(13G) + `out/`(6.0G) 属 `work` 区；
  `backup/`(31G) 属 `evidence` 区（不可再生）。
- **git 侧干净**：主仓 `status` 空、`stash list` 空；**唯一真正未落盘的东西**是 `build/daily` 的 19 个改动
  （其中 10 M + 9 ??）——但已有 `patches/local/20261113-daily-worktree/0001-…patch` 且**反向 `apply --check` 通过（rc=0）**，
  即当前工作区状态可逐字复原。另有 `build/m3v2-7.3rc7` 8 M + 1 ?? + **1 条 stash**。
- 按 2026-11-11/11-12 用户既有裁决（「大件先不动，`df /` 可用 < 100 G 才动」）：**当前 150 G 可用，不触发任何删除**。
  本次只给出：① 可安全做的**同内容硬链接去重 ≈ 0.9 GB**（不删文件、不改内容）；② 若将来要腾空间的动作排序与风险。

---

## 1. 分层 du（top 占用 + 性质）

### 1.1 d1（顶层）

| # | 路径 | 大小 | 性质 | git 状态 |
|---|---|---|---|---|
| 1 | `backup/` | 31 G | **evidence**：原厂固件/分区 dump/bundle/历史镜像归档 | `/backup/*` 忽略（`.gitignore:63`），18 个账本文件入库 |
| 2 | `build/` | 28 G | **work**：内核构建树/独立源树/EDK2-Mu 构建源 | `/build/` 忽略（`:35`） |
| 3 | `wt/` | 13 G | **work**：lane git worktree（`reb-731` 构建输出树） | `/wt/` 忽略（`:37`） |
| 4 | `out/` | 6.0 G | **work**：构建产物（`.manifest` 身份账入库） | `/out/*` 忽略（`:40`），230 件 manifest 入库 |
| 5 | `dl-cam/` | 2.5 G | **work**：相机 provider 交叉编译工作区（NDK/AOSP 头/vendor 镜像） | 部分纳管（231 文件入库），大件忽略 |
| 6 | `geekidos-linux/`（=`linux/`） | 2.1 G | **src**：GEEKiDoS v7.2-elden 上游 clone（detached `ba28ec16f`） | `/geekidos-linux/` 忽略（`:11`），自有 repo |
| 7 | `stock-src/` | 2.0 G | **src**：联想 GPL 源码 clone（kernel 1.5G + modules 528M + twrp 14M） | `/stock-src/` 忽略（`:13`） |
| 8 | `external/` | 1.9 G | **work/src**：外部构建工作区（ext-repos 1.2G / lc-cross 450M / alpine-sysroot / mesa-out） | `/external/` 忽略（`:38`） |
| 9 | `reports/` | 1.9 G | **evidence**：报告 + `artifacts/` 1.8G（354 个 UEFI/EDL 证据目录，1849 文件入库） | 入库；`artifacts/**/*.log`、`*.bin` 忽略（`:399-401`） |
| 10 | `bootslot-b/` | 1.5 G | **work**：自签 b 槽包 + `avb.key`（**含私钥，禁止入库**） | `/bootslot-b/*` 忽略（`:60`） |
| 11 | `.pi/` | 829 M | **ai**：agent 会话记录 `sessions/` 827M（336 个 jsonl） | `/.pi/sessions/` 忽略（`:92`） |
| 12 | `.git/` | 340 M | 主仓对象库（1 pack 320.75 MiB，18908 对象） | — |
| 13 | `logs/` | 38 M | 运行日志 | `/logs/` 忽略（`:43`） |
| 14 | `Y700-elden-linux/` | 28 M | 早期参考仓（远程 `xiaobai-Lethe/Y700-elden-linux`） | 忽略 |
| 其余 | `patches/ 12M`、`reference 6.1M`、`archive 3.0M`、`probes 2.5M`、`TASKS 2.2M`、`scripts 2.1M`、`initramfs 2.0M`、`PITFALLS 1.5M`… | < 12 M 各 | 文档/脚本/补丁（入库主体） | 入库 |

### 1.2 d2（重点块内部）

**backup/ 31 G**

| 子块 | 大小 | 性质 |
|---|---|---|
| `official-rom-15.10.259/` | 16 G | 官方 259 全量线刷包（`super_4.img` 单件 12 G；`super_3/6/7/8` 合计 ~2.4 G；`NON-HLOS.bin` 350 M） |
| `out-history-20261105/` | 7.6 G | 114 件历史 `out/*.img` 归档 + `ARCHIVE.tsv` 逐件 sha256 + `ROLLBACK.sh` |
| `build-bundles/` | 1.3 G | `m3v2-7.3rc7-git-20261105.tar.zst` 1.3 G + `dirty-20261105/` 快照 + MANIFEST |
| `git-slim-20261113/` | 1.2 G | 3 个 `--all` bundle（main 540M / m3v2 413M / geekidos 315M） |
| `HA2EXB0E-16+512/` | 1.1 G | U2 单元备份（boot_b 历史 4 件 + stock 229M + unique 125M + m8ab 289M） |
| `git-repair-20261105/` | 882 M | `git-before-repair-…tar.zst` 715M + quarantine pack 209M |
| `git-history-rewrite-20261112/` | 789 M | 2 个 pre-rewrite main bundle |
| `fw/` | 782 M | 设备分区采集固件（`tb322fc-edl/` 599M EDL 包 + vendor/modem/bluetooth/dspso） |
| `git-history-rewrite-20261103/` | 280 M | pre-rewrite-all bundle |
| `stock-elden/` 262M / `avf/` 249M / `stock-259/` 247M | ~760 M | 分区子集/AVF 提取件（`SHA256SUMS` 齐） |
| `device-test-20261113/` 164M | 164 M | vk191 取证件（img + manifest） |
| `uefi-builds-20261106/` 87M、`corrupt-20261103/` 81M、`m3v5-onboard` 105M、`artifacts-bundle-20261105` 44M | ~320 M | UEFI 迭代件/坏件留存/模块 tar |
| 其余（`misc`/`slot-probe`/`gpt-*`/`f2fs-migrate-*`/`lun4-gpt`/`migration`） | < 10 M | 元数据 dump |

**build/ 28 G**

| 子块 | 大小 | 性质 |
|---|---|---|
| `daily/` | 13 G | **日常线内核树（`patches/current-tree` 指向它，在机 vk184→vk190 全出自此树）**；`.o` 6.24 G/11034 个、`.cmd` 0.58 G、`vmlinux*` 1.37 G、`arch/arm64/boot` 404 M |
| `uefi-woa-prep/` | 8.2 G | UEFI/Mu 构建源：`repos/7-mu-lenovo` 5.6 G（自有 fork，`.git` 1.4 G）+ `1-edk2-aarch64-gunyah` 1.5 G + qemu 198M + edk2-gunyah-qemu 165M + DroidVM-Prebuilts 148M；`tarballs/` 678 M |
| `m3v2-7.3rc7/` | 4.2 G | 7.3-rc7 lane 源树 + `.git` 562 M；`vmlinux*` 642 M；**8 M + 1 ?? 未提交** |
| `base-7.2/` | 2.4 G | 7.2 基线源树（`up` remote = 本地 `geekidos-linux`），`.git` 569 M，无 `.config`，仅 11 个 `.o` |
| `exp-cmdline/` 164M | 164 M | 两个实验 boot.img（**非 git 仓**） |
| `grub-arm64` 25M、`phosh/phoc-src-*` 32M、`gunyah-port-6.6-orig` 9M、`droidloom` 8M、`extmod` 6.3M、`a2-ln` 340K | ~85 M | 上游源码/实验树 |

**wt/ 13 G**：`wt/reb-731/` = `build/m3v2-7.3rc7` 的 linked worktree（`.git` 文件 76 B → `build/m3v2-7.3rc7/.git/worktrees/reb-731`），
HEAD `ec74c4795a`（detached，= tag `vk185`），`status` 干净；`.o` 6.15 G/10948 个、`.cmd` 0.58 G、`vmlinux*` ~1.2 G、`arch/arm64/boot` 403 M。

**out/ 6.0 G**：`debian/elden-rootfs-20261026.tar.zst` 605 M、`r21-sbstop-pc{1,2,69}` 各 641 M、`espboot-20261108` 166M、
`stage-debian` 135M、`fbdiag` 122M、23 个 `*.img` 合计 1.7 G、`grub-2026111*`/`phoc-syncobj-*`/`uefi-*` 等实验输出若干。

**dl-cam/ 2.5 G**：`ndk/android-ndk-r25c` 1.6 G、`sysroot` 205M、`aosp` 118M、`hw-interfaces` 43M（6 M 未提交）、
`vendor-orig.img` + `vendor-cam-l1d.img` 各 268 M、`libcxx` 5.4M、`out-cam` 3.8M。

---

## 2. 逐块可复现性判定（复现命令 / 证据）

| 块 | 判定 | 复现命令或证据 |
|---|---|---|
| `build/daily`（13 G） | **源可复现；输出可重建** | 源 = HEAD `4da9a8b69f`（7.3.1 + payload v2）+ `patches/local/20261113-daily-worktree/0001-daily-worktree-state-vk190.patch`（274 KB，38 文件/+8976−15）。**证据（现跑）**：`git -C build/daily apply --check --reverse <绝对路径>/0001-…patch` → **rc=0**（反向能打 = 与当前工作区逐字一致）。配置 = `patches/config-daily-c2-suspend-20261113`。重建：`scripts/build-kernel.sh Image.gz dtbs`（`KDIR=build/daily`，ccache 已启用） |
| `wt/reb-731`（13 G） | **完全可复现（提交在 tag 里，树干净）** | `ec74c4795a` ∈ `refs/tags/vk185`（`git -C build/m3v2-7.3rc7 tag --contains ec74c4795a` → `vk185`）；重建：`git -C build/m3v2-7.3rc7 worktree add wt/reb-731 vk185` + `KDIR=wt/reb-731 scripts/build-kernel.sh Image.gz dtbs`（`.config` 在树内，325 566 B，2026-11-08）。对应镜像在档：`out/boot-elden-vk185-adsp.img` + `.manifest` |
| `build/m3v2-7.3rc7`（4.2 G） | **源可复现（提交 + patch 均在档）** | HEAD `e18a4a66eb` = 分支 `wl8board`；8 个脏文件的改动行数与 saved daily patch **逐文件相同**（`dwc3-qcom.c 31=31`、`phy-qcom-qmp-combo.c 26=26`、`gcc-sm8750.c 4=4`；`sm8750.dtsi 4 vs 5`，差 1 行属上下文/额外 hunk）；`include/linux/phy/phy-qcom-qmp-usb-ss.h` 同在校内 patch（intent-to-add）。**另有 1 条 `stash@{0}`（WIP on no branch，9d66f26fef）内容未核，见 §4** |
| `build/base-7.2`（2.4 G） | **可复现（纯 clone，无本地产出）** | `git -C build/base-7.2 remote -v` → `up /home/xuqianhui/y700-elden/geekidos-linux`；HEAD `378459aff`；`ls build/base-7.2/.config` 不存在；`find … -name '*.o' \| wc -l` = 11 → 重建：`git clone geekidos-linux build/base-7.2 && git -C build/base-7.2 checkout 378459aff` |
| `build/uefi-woa-prep/repos`（7.5 G） | **可复现（clone URL 在档）**，但 **7-mu-lenovo 有 3 个本地改动** | `repos/clone.sh` 逐条列 URL；`7-mu-lenovo` = `xiaquwan1001/mu_wide_platforms`（自有 fork，可重克隆）。**注意**：`status` = `M Common/MU_TIANO`（子模块指针/模式）+ `?? …RmVmDxe.efi.orig-mu`、`?? …UFSDxe.efi.orig-mu` → 删前须先把这两件 `.orig-mu` 落盘 |
| `build/uefi-woa-prep/tarballs`（678 M） | **需人判断** | 含 Lenovo/Qcom 分发包（`acpi.tgz`、`binaries.tgz`、`crdk`、`mfconfig`）——**来源非 git**，`clone.sh` 不覆盖 |
| `build/exp-cmdline`（164 M） | **可复现（= out 镜像副本）** | 两个文件 `boot-elden-vk187b-noruntime.img` / `-ramoopsfix.img`；同类件在 `out/` 与 `backup/out-history-20261105/` 有档（`ARCHIVE.tsv` 可核） |
| `out/*.img`（23 件 1.7 G） | **半可复现** | 每件有 `out/<name>.manifest`（身份账入库），归 `versions/vk-kernel-identity.tsv`（138 行）。重建依赖对应内核树 + `scripts/build-boot.sh`，但**历史镜像不是字节可复现**（ccache/时间戳/工具链漂移）→ 按证据对待 |
| `out/debian/elden-rootfs-*.tar.zst`（605 M） | **可复现** | `rootfs/debian/build-rootfs.sh`、`rootfs/build-rootfs.sh` |
| `out/r21-sbstop-pc{1,2,69}`（各 641 M） | **需人判断** | SB 停止实验的三份整包产物；生成脚本见 `scripts/`（r21 相关），未逐一核 |
| `backup/official-rom-15.10.259`（16 G） | **不可再生（保留）** | `RESOURCES/README.md:192`：「官方全量线刷包…2026-11-03 从 `~/文档` 收归项目」；`reports/asset-slim-20261112.md:46`：11-11 裁决「官方固件不可再生 ⇒ 保留」；`backup/stock-259/SHA256SUMS` 为其 13 分区子集校验表 |
| `backup/out-history-20261105`（7.6 G） | **不可删（门禁耦合）** | `scripts/out-archive.py` 头注 + `ARCHIVE.tsv` 逐件 sha256；`scripts/vk-identity.py` 与 `check-doctor §5d` **扫这个目录**，删/压会破版本账（`asset-slim:49`） |
| `backup/fw/`（782 M） | **不可再生（真机采集）** | `backup/fw/README.md`：来源 = 真机 UFS 分区 `probe.sh` 采集 + EDL 包；`backup/lun4-gpt-*/SHA256SUMS`、`backup/avf/SHA256SUMS` 齐 |
| `backup/git-slim-20261113`（1.2 G） | **不可再生（历史保险），但内容多为旧代** | 3 个 `--all` bundle；`reports/git-slim-exec-20261113.md` 有生成命令与 `git bundle verify` 判据 |
| `backup/git-repair-20261105`（882 M）/`git-history-rewrite-2026{1103,1112}`（1.07 G） | **需人拍板（多代并存）** | `reports/project-audit-20261111.md:71` 已判「同一性质多代并存，最新已验证…可归档或删旧代」 |
| `backup/HA2EXB0E-16+512`（1.1 G） | **不可再生（U2 单元专有）** | `SHA256SUMS.unlock`；`DEVICE/README.md` 设备等价原则 = 备份按 `(SN, 容量)` |
| `backup/device-test-20261113`（164 M） | **证据（保留）** | vk191 在机取证件（`boot-elden-vk191.img` + `.manifest`）；`reports/device-session-20261113-vk191.md` |
| `bootslot-b/`（1.5 G） | **不可再生（含 `avb.key` 私钥）+ 部分可复现** | 5 件 `boot_b-*.img`；重建需私钥重新签名 → 私钥本身不可再生 |
| `geekidos-linux/`（2.1 G） | **可复现（远程可达）** | HEAD `ba28ec16f` ∈ `origin/v7.2-elden`（`branch -r --contains`）；远程 = `git@github.com:GEEKiDoS/linux.git` + `git.ustc.edu.cn/xqh/y700-elden-kernel.git` |
| `stock-src/`（2.0 G） | **可复现（GitHub clone + `blob:none`）** | `android_kernel_lenovo_sm8750` → `lenovo-basements/…`；`-modules` → 同 org；clean |
| `external/ext-repos`（1.2 G） | **部分可复现** | `sunuefi` 为 git 仓（clean）；`af`/`dl`/`mu`/`vk64rd` 为**非 git 目录**（解包产物，含 `armadaos-freedom.tar.gz` 189 M）→ 需人判断 |
| `external/lc-cross/lc-src`（450 M） | **需人判断** | libcamera 交叉构建工作区，非 git 目录 |
| `external/alpine-sysroot`（94 M）/`aosp-vndk33`（74 M）/`mesa-out`（40 M） | **可复现（下载/重建）** | sysroot 可由 alpine 镜像重建；`rootfs/build-sysroot.sh`、`rootfs/build-mesa-a830.sh` |
| `dl-cam/ndk`（1.6 G） | **可复现（Google 官方下载）** | `dl-cam/ndk/source.properties` = `android-ndk-r25c`（可再下载） |
| `dl-cam/{sysroot,aosp,libhidl,hw-interfaces}` | **可复现（克隆 + 重烘焙）** | `libhidl`→ `mirrors.tuna.tsinghua.edu.cn/git/AOSP/platform/system/libhidl`；`hw-interfaces`→ `mirrors.ustc.edu.cn/aosp/platform/hardware/interfaces`（`[blob:none]`）；`dl-cam/build-cam-provider.sh` 产出 `out-cam/` |
| `dl-cam/vendor-*.img`（各 268 M） | **需人判断** | 设备 vendor 分区镜像副本（orig / cam-l1d）；可从原厂包 `super` 或设备重取，但未核 sha |
| `reports/artifacts`（1.8 G，354 目录） | **证据（不可删；1849 文件已入库）** | `git ls-files reports/artifacts \| wc -l` = 1849；`build.log`/`*.bin` 被 `.gitignore:399-401` 排除（未入库的 log/bin 属取证原件） |
| `.pi/sessions`（827 M，336 个 jsonl） | **不可再生（会话证据）** | 忽略规则 `:92`；`INDEX.md` §0 用 `scripts/recent-sessions.sh` 读它 |

---

## 3. 未提交改动 / stash / 被忽略的大文件

### 3.1 未提交改动清单（**未提交、未删、未 stash 任何东西**）

| 仓库 | 脏项 | 内容 |
|---|---|---|
| **主仓** `/home/xuqianhui/y700-elden` | **0** | `git status --porcelain` = 0 行；`git stash list` = 空 |
| **`build/daily`**（m3v2 的 linked worktree） | **19**（10 M + 9 ??） | M: `arch/arm64/Kbuild`、`sm8750-lenovo-elden.dts`、`sm8750.dtsi`、`gcc-sm8750.c`、`phy-qcom-qmp-combo.c`、`llcc-qcom.c`、`tsens.c`、`dwc3/{core,dwc3-am62,dwc3-qcom}.c`、`drivers/virt/{Kconfig,Makefile}`；??: `arch/arm64/gunyah/`、`arch/arm64/include/asm/gunyah.h`、`drivers/virt/gunyah/`、`include/linux/gunyah.h`、`include/linux/gunyah_qtvm.h`、`include/linux/phy/phy-qcom-qmp-usb-ss.h`、`include/uapi/linux/gunyah.h` |
| **`build/m3v2-7.3rc7`** | **9**（8 M + 1 ??） | M: `sm8750.dtsi`、`gcc-sm8750.c`、`phy-qcom-qmp-combo.c`、`llcc-qcom.c`、`tsens.c`、`dwc3/{core,dwc3-am62,dwc3-qcom}.c`；??: `include/linux/phy/phy-qcom-qmp-usb-ss.h`；**stash@{0}** = `WIP on (no branch): 9d66f26fef Merge tag 'vfs-7.4-rc3.fixes.2'…`（内容未展示，按纪律不动） |
| `wt/reb-731` | 0 | 干净（= tag `vk185` 逐字） |
| `geekidos-linux` | 0 | detached `ba28ec16f`，干净 |
| `build/base-7.2` / `build/a2-ln` / `stock-src/*`(2) / `Y700-elden-linux` / `dl-cam/libhidl` / `external/ext-repos/sunuefi` | 0 / 0 / 0 / 0 / 0 / 0 | 全干净 |
| **`build/uefi-woa-prep/repos/7-mu-lenovo`** | **3** | M `Common/MU_TIANO`（子模块指针）；?? `Platforms/PakalaPkg/Device/lenovo-y700g4/Binaries/QcomPkg/Drivers/RmVmDxe/RmVmDxe.efi.orig-mu`、`…/PatchedBinaries/UFSDxe.efi.orig-mu`（自改二进制前留的 `.orig-mu` 原件） |
| **`dl-cam/hw-interfaces`** | **6 M** | `camera/common/1.0/…/HandleImporter.cpp`、`camera/device/3.4/default/ExternalCameraDevice{,Session,Utils}.cpp`、`camera/provider/2.4/…`、`2.7/…`，合计 **+266/−14**（64-bit 外置相机 provider 的本地改造） |

> 结论：**没有任何改动被提交或清理**。`build/daily` 状态已有 `patches/local/20261113-daily-worktree/` 逐字快照（反向 apply rc=0）；
> `dl-cam/hw-interfaces` 的 266 行改造**没有任何异地副本**（只存在于该工作树 + `dl-cam/out-cam/` 产物）→ 属「删除前必须先落盘」项。

### 3.2 被 `.gitignore` 忽略的大文件（>50 M，抽样 top）

| 大小 | 文件 | 忽略来源 |
|---|---|---|
| 12.3 G | `backup/official-rom-15.10.259/super_4.img` | `.gitignore:63 /backup/*` |
| 1.75 G | `build/daily/vmlinux.o` | `:35 /build/` |
| 1.54 G | `backup/official-rom-15.10.259/super_7.img` | `:63` |
| 1.04 G | `backup/official-rom-15.10.259/super_3.img` | `:63` |
| 715 M | `backup/git-repair-20261105/git-before-repair-20261105.tar.zst` | `:63` |
| 688 M / 686 M | `build/daily/vmlinux.unstripped` / `build/daily/vmlinux` | `:35` |
| 605 M | `out/debian/elden-rootfs-20261026.tar.zst` | `:40 /out/*` |
| 598 M | `backup/official-rom-15.10.259/super_6.img` | `:63` |
| 367 M ×2 | `backup/official-rom…/NON-HLOS.bin`、`backup/fw/tb322fc-edl/NON-HLOS.bin` | `:63`（**内容相同、未硬链接，见 §5.1**） |
| 320 M / 162 M / 160 M | `build/m3v2-7.3rc7/vmlinux{,.unstripped,.o}` | `:35` |
| 293 M | `backup/git-history-rewrite-20261103/pre-rewrite-all.bundle` | `:63` |
| 268 M ×2 | `dl-cam/vendor-orig.img`、`dl-cam/vendor-cam-l1d.img` | 部分纳管规则 |
| 209 M | `backup/git-repair-20261105/quarantine/pack-84fbc913….pack` | `:63` |
| 189 M | `external/ext-repos/dl/armadaos-freedom.tar.gz` | `:38 /external/` |
| 147 M | `backup/official-rom…/super_8.img` | `:63` |
| 110 M | `backup/m3v5-onboard-20261031/m3mods-daily-20261031.tar` | `:63` |

---

## 4. 结论：总占用 / top5 可释放项 / 不可删项 / 需人拍板项

### 4.1 总占用

- 仓库 **90 G**（`du -sh .`）；`/` 侧 **740 G 已用 / 150 G 可用（84%）**。
- 分类合计：`work`（build+wt+out+dl-cam+bootslot-b+external+exp）≈ **53 G**；`evidence`（backup+reports）≈ **33 G**；`src`（geekidos+stock-src+Y700-elden-linux）≈ **4.2 G**；`ai`（.pi）0.83 G；主仓 `.git` 0.34 G。

### 4.2 Top5 可释放项（大小 + 复现命令 + 风险）——**本次均未执行**

| # | 项 | 可释放 | 复现命令 | 风险 |
|---|---|---|---|---|
| 1 | `wt/reb-731` 整树（构建输出占 ~12.2 G） | **13 G** | `git -C build/m3v2-7.3rc7 tag --contains ec74c4795a` → `vk185`；重建 `git -C build/m3v2-7.3rc7 worktree add wt/reb-731 vk185 && KDIR=wt/reb-731 scripts/build-kernel.sh Image.gz dtbs` | **低—中**：树干净、提交在 tag、镜像在档；但用户 11-05/11-10 裁决「保留（回滚依赖）」；且 `scripts/lane.sh` 按 `WT_ROOT` 找 lane worktree → 删前核 lane 脚本引用 |
| 2 | `build/daily` 构建中间物（`.o` 6.24 G + `.cmd` 0.58 G + `vmlinux*` 1.37 G） | **≈8 G**（源/`.config` 全留） | `make -C build/daily clean`（或用 `scripts/build-kernel.sh` 重建；源状态复原判据 = `git -C build/daily apply --check --reverse <abs>/patches/local/20261113-daily-worktree/0001-daily-worktree-state-vk190.patch` **rc=0**（本次已实测），配置 `cp patches/config-daily-c2-suspend-20261113 build/daily/.config`） | **中**：`build/daily` 是**日常线在役树**（`patches/current-tree`），清后首次全量重建 + ccache 冷启动；11-11 用户裁决保留其增量构建能力 |
| 3 | `build/uefi-woa-prep/repos`（7.5 G，`7-mu-lenovo` 5.6 G 为主） | **7.5 G** | `bash build/uefi-woa-prep/repos/clone.sh` + `clone2.sh`（URL 在脚本里）；`7-mu-lenovo` 源 = `xiaquwan1001/mu_wide_platforms` | **中**：① 7-mu-lenovo 有 3 个本地改动（2 个 `.orig-mu` 未跟踪 + 子模块指针）**先落盘**；② `tarballs/` 678 M 是 Lenovo/Qcom 分发包，非 git 可复现 → 单独保留 |
| 4 | `build/base-7.2` | **2.4 G** | `git clone geekidos-linux build/base-7.2 && git -C build/base-7.2 checkout 378459aff`（`up` remote 现指向本地 `geekidos-linux`；无 `.config`、无产出） | **低**：纯基线 clone；但历史上有「`build/*` 删除前先 bundle」铁律，且它可能是某轮 A/B 基线 → 建议先核 `reports/` 引用 |
| 5 | `dl-cam/ndk`（1.6 G）+ `dl-cam/vendor-*.img`（0.5 G） | **≈2.1 G** | NDK 重取：Google `android-ndk-r25c`（`dl-cam/ndk/source.properties` 有版本）；vendor 镜像需从原厂包/设备重取（未见 sha 账） | **中**：NDK 删除后「离线无网时无法重烘焙相机 provider」（11-11 保留理由）；vendor 镜像可复现性未核 ⇐ 需人判断 |

> 补充（**零风险、不删文件**）：`backup/official-rom-15.10.259/NON-HLOS.bin`(350 M) 与 `backup/fw/tb322fc-edl/NON-HLOS.bin`
> **sha256 完全相同**（`5d411ac0263ad968…`）但**两个 inode**；`backup/fw/tb322fc-edl/*` 与官方包同名同尺寸合计 **563 MB**（`boot.img` 除外）。
> 做法（沿用 `reports/asset-slim-20261112.md` 的 `os.link` 手法）：先 sha256 全量确认 → `os.link` 同 inode，可回收 **≈0.5 GB**，路径与内容都不变、完全可逆。
> 另：`backup/` 现有 47 个已硬链接文件、apparent 额外 0.88 GB 已被去重（无需再动）。

### 4.3 不可删项

1. `backup/official-rom-15.10.259/`（16 G）——官方 259 全量线刷包，不可再生（`RESOURCES:192`、`asset-slim:46`）。
2. `backup/out-history-20261105/`（7.6 G）——**被 `vk-identity.py` + `check-doctor §5d` 扫描**，删除会破版本账门（`out-archive.py` 头注、`asset-slim:49`）。
3. `backup/fw/`（782 M）、`backup/HA2EXB0E-16+512/`（1.1 G）、`backup/stock-259/`+`avf/`+`stock-elden/`（758 M）——真机采集/单元专有。
4. `backup/device-test-20261113/`（164 M）——vk191 在机取证件（对应 `reports/device-session-20261113-vk191.md`）。
5. `bootslot-b/`（1.5 G）——含 `avb.key` 私钥（不可再生，且禁止入库）。
6. `reports/artifacts/`（1.8 G）——表态证据（1849 文件已入库，`*.bin`/`*.log` 原件）。
7. `build/daily` 的**源树与 `.config`**（不含 `.o`）——在役日常线树（`patches/current-tree` = `build/daily`）。
8. `build/uefi-woa-prep/tarballs/`（678 M）——非 git 来源的 Lenovo/Qcom 分发包。
9. 主仓入库内容 + `.git`（340 M）+ `versions/vk-kernel-identity.tsv`（138 行版本账）——**禁重跑 `scripts/vk-identity.py > …`**（会清空整表）。
10. `.pi/sessions/`（827 M）——会话证据（`INDEX.md` §0 核实流程依赖它）。

### 4.4 需人拍板项

| 项 | 大小 | 待决问题 |
|---|---|---|
| `backup/git-*` 多代并存（`git-repair-20261105` 882M + `git-history-rewrite-20261103` 280M + `…1112` 789M + `git-slim-20261113` 1.2G） | 3.15 G | 最新代（1113 slim bundle）已验证可 `bundle verify` ⇒ 旧三代是否可弃（`project-audit-20261111.md:71` 已建议归档旧代） |
| `backup/official-rom` 的 `super_*.img`（15 G） | 15 G | 是否按 `asset-slim:46` 方案 ①压 `tar.zst`（`super_4` 压缩率仅 1.68 ⇒ 省 ~6 G）或 ②只留 unbrick 必需分区（~1 G）；风险 = EDL 恢复前需解压 |
| `build/daily` 19 个未提交改动 | — | 是否 commit/tag（现存 patch 快照 + 反向 apply 判据；但持久保险仍是 commit）。**提交与否 = 用户决定，本次未提交** |
| `build/m3v2-7.3rc7` 的 **`stash@{0}`** | — | 内容未展示（`WIP on no branch`），是否还有用；与之并存的 8 个脏文件已由 daily patch 覆盖 |
| `dl-cam/hw-interfaces` 6 M 未提交（+266/−14） | — | **无异地副本**；是否导出成 patch 存 `patches/`（相机 64-bit provider 改造） |
| `dl-cam/vendor-{orig,cam-l1d}.img`（各 268 M） | 0.5 G | 可复现性未核（无 sha 账） |
| `external/ext-repos/{af,dl,mu,vk64rd}`（~760 M，非 git） | 0.76 G | 解包产物（含 `armadaos-freedom.tar.gz` 189 M），来源/可否重取不明 |
| `external/lc-cross/lc-src`（450 M） | 450 M | libcamera 交叉工作区，非 git |
| `build/uefi-woa-prep/repos/7-mu-lenovo` 2 个 `.orig-mu` | — | 未跟踪的二进制原件；随 clone 清理会丢失 |
| `build/exp-cmdline`（164 M） | 164 M | 两个实验 img，是否已被 `out/`/`out-history` 覆盖（同名件在档） |
| `out/r21-sbstop-pc{1,2,69}`（各 641 M） | 1.9 G | 三份 SB 停止实验整包，是否仍有取用需求 |
| `.pi/sessions`（827 M / 336 件） | 0.83 G | 是否按保留窗口裁剪（属项目记忆政策，非磁盘问题） |

---

## 5. 审计取证命令（可复跑，均带 timeout）

```sh
cd /home/xuqianhui/y700-elden
timeout 60 du -sh . ; timeout 120 du -h -d1 . | sort -rh | head -30
df -h /home/xuqianhui
timeout 60 git status --porcelain | wc -l ; timeout 30 git stash list
timeout 30 git worktree list ; timeout 30 git -C build/m3v2-7.3rc7 worktree list
git -C build/daily rev-parse --short HEAD        # 4da9a8b69f
git -C wt/reb-731 rev-parse --short HEAD         # ec74c4795a
git -C build/m3v2-7.3rc7 tag --contains ec74c4795a   # vk185
git -C build/daily apply --check --reverse "$PWD/patches/local/20261113-daily-worktree/0001-daily-worktree-state-vk190.patch"; echo rc=$?
git -C build/daily status --porcelain | wc -l    # 19
git -C build/m3v2-7.3rc7 status --porcelain      # 8 M + 1 ??
find build/daily -name '*.o' -printf '%s\n' | awk '{s+=$1;n++} END{printf "%d files %.2f GB\n",n,s/1073741824}'
git -C build/uefi-woa-prep/repos/7-mu-lenovo status --porcelain
git -C dl-cam/hw-interfaces status --porcelain
sha256sum backup/official-rom-15.10.259/NON-HLOS.bin backup/fw/tb322fc-edl/NON-HLOS.bin
stat -c '%i %h %s %n' backup/official-rom-15.10.259/NON-HLOS.bin backup/fw/tb322fc-edl/NON-HLOS.bin
git check-ignore -v backup/xxx out/xxx build/xxx wt/xxx external/xxx geekidos-linux/xxx stock-src/xxx bootslot-b/xxx logs/xxx .pi/sessions/x.jsonl
```

*（本报告未删除/移动任何文件，未执行 commit/gc/clean，未触碰任何设备。）*
