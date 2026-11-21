# UEFI Mu「带 esp-first」重建 —— 盘点与重放（2026-11-21）

> 触发：2026-11-21 路 A 实测 `fastboot boot out/uefi-20261104R21-hostdiag-r1.img` = 「屏上有字、无 GRUB 菜单」，
> 判读为「R21（11-05）早于 R54（11-08）的 `bdsdxe-esp-first`」，`TASKS/README.md` §4 因此把
> 「重建带 esp-first 的 Mu」列为唯一方向。
> 本轮（主机侧、离线、零整编）把这条方向的前置条件全部实测复核了一遍。

## 0. 结论（三行）

1. **重放零冲突**：`patches/uefi/p69-recipe.txt` 的 **84 条补丁在正确基线上 100% 干净应用（`OK=84`，`FAIL=0`，`--3way` 用了 0 次）** ⇒ TASKS §4 记的「补丁基线 `42fe5637` ≠ 新克隆 HEAD `d31c2b8` ⇒ 逐条重放会冲突」这条**障碍不成立**。
2. **基线找错了仓**：配方基线是 **`sunflower2333/mu_wide_platforms@6b6ac42a`**（不是 `Project-Silicium/Mu-Silicium`）；盘上 `build/uefi-woa-prep/repos/7-mu-lenovo` 现在是 **Mu-Silicium `d31c2b8`**，84 条里有 **83 条的目标文件在该树里不存在** ⇒ 「两仓合并」其实是**「换回正确的仓」**，不是合并。
3. **更省的一条路（本轮新发现，未上机）**：**带 esp-first 的固件件一直躺在盘上** —— `reports/artifacts/uefi-20261110R70-p69/SM8750_EFI.fd`（2026-11-10）里 R54/R64/R68/R70 的判据串全部命中；用既有 repack 脚本**秒级**就得到可 `fastboot boot` 的件（`out-p69/uefi-preamble69-r1.img`，`38202e12…`，header v2 / `text_offset=0` / `flags=0xa` 断言通过）。⇒ **整编不是验证 esp-first 的前置**。

---

## 1. 盘点表（每行都附命令与原始输出）

| # | 项 | 实测结果 | 判据命令（原样） |
|---|---|---|---|
| 1 | `build/uefi-woa-prep/repos/7-mu-lenovo` 身份 | **`Project-Silicium/Mu-Silicium` @ `d31c2b8`（`peridot: actually clean up MemoryMap (#2197)`），295 MB，工作区干净，6 个子模块全部未初始化** | `git remote -v` → `origin https://github.com/Project-Silicium/Mu-Silicium.git`；`git log --oneline -1`；`git submodule status` 六行全以 `-` 开头 |
| 2 | 该树是否含 `bdsdxe-esp-first` | **不含** | `grep -rn "EspFirst\|esp-first\|BOOTAA64" --include=*.c .` → 空 |
| 3 | 该树是否含 Pakala/elden 平台 | **只有 SEC 层**：`Silicon/Qualcomm/PakalaPkg/{PakalaPkg.dsc.inc,Library/PlatformSecLib/}`；**没有** `Platforms/PakalaPkg/Device/lenovo-y700g4`（我们的板级目录）。SM8750 设备只有 `Platforms/{Xiaomi/annibalePkg,OnePlus/dodgePkg,OnePlus/paganiPkg}` | `ls Silicon/Qualcomm/PakalaPkg`；`grep -rln PakalaPkg --include=*.dsc .` |
| 4 | 84 条补丁在该树的可应用性 | **83/84 有目标文件缺失**（唯一"命中"的是 `BootShim/BootShim.S` 那条） | `for p in $(grep '^patch' patches/uefi/p69-recipe.txt \| cut -f2); do … [ -e "$f" ] …` → `补丁总数=84 有缺失目标文件=83` |
| 5 | 配方真实基线 | **`mu_wide_platforms@6b6ac42a`（2026-10-05，`ci: allow DEBUG build type via workflow_dispatch input`）**，= `origin/main`（`3e1d0520 remove sm8650.json`）之上 2 个 CI 提交，**不在 main 祖先链**（上游重置过），但可按 SHA 取回 | `git fetch origin 6b6ac42a…` → `* branch 6b6ac42a… -> FETCH_HEAD`；`git merge-base --is-ancestor 6b6ac42a origin/main` → 否 |
| 6 | 基线判定的独立印证 | `p59` 构建归档 manifest 写 `repo_head=6b6ac42a…`，且该提交固定的子模块 SHA 与 manifest 逐字相同（`Binaries ce59dcf5…`、`MU_BASECORE 3609e51f…`） | `reports/artifacts/uefi-20261108R54-espfirst-p59/manifest.txt` + `git ls-tree 6b6ac42a \| awk '$1=="160000"'` |
| 7 | 上游仓现状 | `mu_wide_platforms` 现在**仍带** `Platforms/PakalaPkg/Device/lenovo-y700g4/`（391 个文件） | `git ls-tree -r --name-only FETCH_HEAD \| grep -c lenovo-y700g4` → `391` |
| 8 | esp-first 已存在于哪些世代 | 配方含 `espfirst` 的世代 = `p59…p69`、`pc1`、`pc1m`、`pc2`；**不含**的最高代 = `p58` | `grep -l espfirst patches/uefi/p*-recipe.txt` |
| 9 | 盘上已有的 esp-first **固件件** | `reports/artifacts/uefi-20261110R70-p69/`（11-10 14:25，`SM8750_EFI.fd` 4194304 B）解 LZMA 后命中 R54 五条判据串 + R64 + R68 + R70 | `python3 scripts/uefi-fv-strings.py … R70/SM8750_EFI.fd "esp blk=" "[K] pi n=" "[K] espb name=" R68LOG "R70"` → 各 1/1/1/3/1 |
| 10 | 同法生成的可引导件 | `out-p69/uefi-preamble69-r1.img` `38202e129af58cc9d20881115de192d5f988e05e08ed50a39992a761940c4fcc`（67194880 B）；`out-p65/uefi-preamble65-r1.img` `4d1ebc065558dc935207ca0d8c2cd0182e9ccdb70749cf0cd5adf3d6182e9b8a`（67194880 B，13:21 重生成后口径） | `scripts/uefi-r21-p7-ladder.sh --gen p69 --mkimg-only …` → `assert-ok: header v2, text_offset=0, flags=0xa, shim size literal=0x400000` |

### 1.1 两仓关系（把「需两仓合并」这条旧表述改掉）

| | `Project-Silicium/Mu-Silicium`（盘上 7-mu-lenovo） | `sunflower2333/mu_wide_platforms`（配方基线） |
|---|---|---|
| 子模块来源 | `Project-Silicium/Device-Binaries`、`microsoft/mu_basecore`… | `Project-Aloha/SurfaceDuoBinaries-fork`、`Project-Aloha/CrDK`、`Platforms/SurfaceDuoACPI`… |
| Pakala | 只有 `Silicon/Qualcomm/PakalaPkg`（SEC 库） | 有 `Platforms/PakalaPkg/`（含 `Device/lenovo-y700g4/` 板级包） |
| 配方补丁目标 | 不存在 | 存在 |

⇒ **不是两个仓都要**：`mu_wide_platforms` 自己就是「Mu + Pakala + 我们的板级包」的合并体；
旧表述「需两仓合并」应改成「树取错仓，换回 `mu_wide_platforms` 即可」（`TASKS/README.md` §4 已按本轮结论改）。

---

## 2. 已入账障碍的复核（要求：复核而非重述）

| 旧说法（TASKS §4 / 报告 §7） | 本轮裁决 | 证据 |
|---|---|---|
| ①「上游 Mu-Silicium 无 Pakala/y700 平台 ⇒ **需两仓合并**」 | **半对：需换仓，不需合并** | §1 第 3/7 行；`mu_wide_platforms` 现成带 `Device/lenovo-y700g4` |
| ②「补丁基线 `42fe5637` ≠ 新克隆 HEAD `d31c2b8` ⇒ **逐条重放会冲突**」 | **不成立**：`42fe5637` 既不是配方基线也不是 Mu-Silicium 的 HEAD（该 SHA 在本地两棵树里都不存在）；正确基线 `6b6ac42a` 上 **84/84 干净通过** | `git cat-file -t 42fe5637` → `fatal: Not a valid object name`（两棵树都试过）；`replay-status.tsv` → `OK=84` |
| ③「仓内/归档的 Mu 件只到 R21 ⇒ 能读 ESP 的件已不可用」 | **不成立**：`reports/artifacts/` 里 `p59…p69`、`pc1`、`pc2` 的 `SM8750_EFI.fd` 都在，且 `p59` 起就含 esp-first | §1 第 9 行；`ls -d reports/artifacts/uefi-2026*` |
| ④「需重取 Mu-Silicium（229 MB）+ 设备二进制后重打补丁」 | **部分成立但代价被高估**：仓 146 MB（浅）+ 3 个必需子模块 `MU_BASECORE` 90 MB / `Common/MU_TIANO` 8.4 MB / `Silicon/Arm/MU_TIANO` 6 MB，全程 ~6 min | §3 复现序列 |
| ⑤「R21 早于 R54 ⇒ 不把 FAT ESP 当候选」 | **保留（未推翻）**：本轮纯主机，无新设备证据；只把「拿不到 esp-first 件」这个前置解除 | `reports/uefi-bslot-plan-20261121.md` §7 |

---

## 3. 84 条逐条裁决

口径：基线 `6b6ac42a` + 三个子模块，按 `p69-recipe.txt` 顺序 `git apply --check` → `git apply`；
「直接过」= 干净 `git apply --check` 通过并已应用；「需重基」= 只能 `--3way` 或失败。
**本次 `需重基` = 0 条、`丢弃` = 0 条、`已在新头部存在` = 0 条**（基线就是配方基线，不存在"新头部"）。

原始件：`build/uefi-woa-prep/merge-espfirst-20261121/replay-status.tsv`（逐条）+ `replay.log`（git 原始输出）。

| # | 补丁（相对 `patches/uefi/`） | 落点 | 裁决 |
|---|---|---|---|
| 1 | `20261104-fixcopylen/0001-bootshim-copy-length-from-build-constants.patch` | 主仓 | 直接过 |
| 2 | `20261104-prepi/0001-prepi-screen-serial-step-marks.patch` | 主仓 | 直接过 |
| 3 | `20261104-dxe/0004-prepi-print-loaddxecore-status.patch` | 主仓 | 直接过 |
| 4 | `20261104-dxe/0010-prepi-fd-fnv-checkpoints.patch` | 主仓 | 直接过 |
| 5 | `20261104-dxe/0013-prepi-block-fnv-table.patch` | 主仓 | 直接过 |
| 6 | `20261104-dxe/0003-prepi-lib-loaddxecore-marks.patch` | Common/MU_TIANO | 直接过 |
| 7 | `20261104-dxe/0005-prepi-lib-fv-discovery-marks.patch` | Common/MU_TIANO | 直接过 |
| 8 | `20261104-dxe/0006-fwvol-process-fvfile-marks.patch` | Common/MU_TIANO | 直接过 |
| 9 | `20261104-dxe/0007-fwvol-guided-section-status.patch` | Common/MU_TIANO | 直接过 |
| 10 | `20261104-dxe/0001-dxemain-screen-serial-step-marks.patch` | MU_BASECORE | 直接过 |
| 11 | `20261104R5-dxebase/0001-dxemain-print-own-address.patch` | MU_BASECORE | 直接过 |
| 12 | `20261104R7-loadmap/0001-dxecore-loadmap-and-noop-conout.patch` | MU_BASECORE | 直接过 |
| 13 | `20261104R8-names/0001-dxecore-names-and-start-marks.patch` | MU_BASECORE | 直接过 |
| 14 | `20261104R10-noqrks/0001-exclude-qrksdxe.patch` | 主仓 | 直接过 |
| 15 | `20261104R13-loaderstart/0001-bdsdxe-start-fv-linuxloader.patch` | MU_BASECORE | 直接过 |
| 16 | `20261104R14-avbprobe/0001-qcommodulepkg-avb-screen-probes.patch` | 主仓 | 直接过 |
| 17 | `20261104R15-noavbprobe/0001-visible-serial-probes-noavb-path.patch` | 主仓 | 直接过 |
| 18 | `20261104R16-dtboclamp/0001-dtbo-load-by-total-size.patch` | 主仓 | 直接过 |
| 19 | `20261104R17-bootmarkers/0001-bootlinux-markers-empty-dtbo.patch` | 主仓 | 直接过 |
| 20 | `20261104R18-haltbeforejump/0001-halt-before-kernel-jump.patch` | 主仓 | 直接过 |
| 21 | `20261104R19-nvmarkers/0001-avb-bootlinux-nv-markers.patch` | 主仓 | 直接过 |
| 22 | `20261104R19-nvmarkers/0002-bdsdxe-print-prev-marker.patch` | MU_BASECORE | 直接过 |
| 23 | `20261104R20-stage-bisect/0001-sbstop-stage-bisect.patch` | 主仓 | 直接过 |
| 24 | `20261104R21-hostdiag/0001-fastboot-host-visible-diag.patch` | 主仓 | 直接过 |
| 25 | `20261104R2-slow-serial/0001-fb-serial-slow-write.patch` | 主仓 | 直接过 |
| 26 | `20261105-diagentry/0001-diag-entry-probe.patch` | 主仓 | 直接过 |
| 27 | `20261105-finebisect/0001-cmdboot-fine-bisect.patch` | 主仓 | 直接过 |
| 28 | `20261105-vsbisect/0001-verifiedboot-bisect.patch` | 主仓 | 直接过 |
| 29 | `20261105-vsbisect/0002-cmdboot-report-vs-abort.patch` | 主仓 | 直接过 |
| 30 | `20261105-vsbisect/0003-preamble-bisect.patch` | 主仓 | 直接过 |
| 31 | `20261105R2-vsstop-fix/0001-vs-stop-inline-parse.patch` | 主仓 | 直接过 |
| 32 | `20261105R4-preamble2-bisect/0001-preamble2-bisect.patch` | 主仓 | 直接过 |
| 33 | `20261105R5-probemode/0001-probe-mode-switch.patch` | 主仓 | 直接过 |
| 34 | `20261105R6-probe-orthogonal/0001-sbprobe-orthogonal.patch` | 主仓 | 直接过 |
| 35 | `20261105R7-probe-markonly/0001-sbprobe-markonly.patch` | 主仓 | 直接过 |
| 36 | `20261106-vsstop35/0001-vsstop35-findbootableslot-tail.patch` | 主仓 | 直接过 |
| 37 | `20261106R2-gate-outwrite/0001-gate-findbootableslot-diagnostic-write.patch` | 主仓 | 直接过 |
| 38 | `20261106R3-bootlinux-eb/0001-bootlinux-eb-bisect.patch` | 主仓 | 直接过 |
| 39 | `20261106R4-real-boot/0001-real-boot-silent-default-and-drop-deadloop.patch` | 主仓 | 直接过 |
| 40 | `20261106R5-jump-banner/0001-forced-jump-banner.patch` | 主仓 | 直接过 |
| 41 | `20261106R11-lia-tail/0001-lia-tail-bisect.patch` | 主仓 | 直接过 |
| 42 | `20261106R12-probemode-guard/0001-probemode-only-with-token.patch` | 主仓 | 直接过 |
| 43 | `20261106R13-skip-usbstop/0001-skip-fastbootusbdevicestop.patch` | 主仓 | 直接过 |
| 44 | `20261106R17-faulthandler-image/0001-faulthandler-one-line-image-attr.patch` | Silicon/Arm/MU_TIANO | 直接过 |
| 45 | `20261106R18-rehook-exception/0001-bdsdxe-rehook-exception-handler.patch` | MU_BASECORE | 直接过 |
| 46 | `20261106R19-fbconsole-bound/0001-fbconsole-bounded-draw.patch` | 主仓 | 直接过 |
| 47 | `20261106R20-faultattrs/0001-faulthandler-esr-far.patch` | Silicon/Arm/MU_TIANO | 直接过 |
| 48 | `20261106R21-fblazyinit/0001-fbconsole-lazy-init.patch` | 主仓 | 直接过 |
| 49 | `20261106R22-restore-eb/0001-restore-eb-banner-status.patch` | 主仓 | 直接过 |
| 50 | `20261106R23-ddr-checkpoint/0001-ddr-checkpoint-eb-jump.patch` | 主仓 | 直接过 |
| 51 | `20261106R24-blackbox-map/0001-platformmemmap-blackbox-window.patch` | 主仓 | 直接过 |
| 52 | `20261106R25-fbbudget-fullpanel/0001-fbbudget-full-panel.patch` | 主仓 | 直接过 |
| 53 | `20261106R26-preeb-dtdiag/0001-preeb-dt-diagnostic.patch` | 主仓 | 直接过 |
| 54 | `20261106R27-fbscroll/0001-fbscroll-bounded-clear.patch` | 主仓 | 直接过 |
| 55 | `20261106R28-fbexplicit-init/0001-fb-init-explicit.patch` | 主仓 | 直接过 |
| 56 | `20261106R29-fbgeometry/0001-fbconsole-pixel-semantics.patch` | 主仓 | 直接过 |
| 57 | `20261106R30-faultdump/0001-faulthandler-two-tier-dump.patch` | Silicon/Arm/MU_TIANO | 直接过 |
| 58 | `20261106R31-logfsdump/0001-console-ring-to-logfs.patch` | 主仓 | 直接过 |
| 59 | `20261106R32-ringshared/0001-ring-shared-and-posteb-dump.patch` | 主仓 | 直接过 |
| 60 | `20261107R33-true-nobs/0001-eb-true-nobs-and-markers.patch` | 主仓 | 直接过 |
| 61 | `20261107R34-screenmarks/0001-screen-stage-markers.patch` | 主仓 | 直接过 |
| 62 | `20261107R35-fastboot-branch/0001-branch-marks.patch` | 主仓 | 直接过 |
| 63 | `20261107R36-fastboot-loopmark/0001-loopmark.patch` | 主仓 | 直接过 |
| 64 | `20261107R38-cached-dump/0001-cached-dump.patch` | 主仓 | 直接过 |
| 65 | `20261107R39-ebscreen/0001-eb-phase-screen-marks.patch` | 主仓 | 直接过 |
| 66 | `20261107R40-noclear/0001-faulthandler-no-clear.patch` | Silicon/Arm/MU_TIANO | 直接过 |
| 67 | `20261107R41-noebdump/0001-drop-posteb-dump-and-pph-marks.patch` | 主仓 | 直接过 |
| 68 | `20261107R42-normalboot/0001-drop-orphan-bootintofastboot.patch` | 主仓 | 直接过 |
| 69 | `20261107R43-bootpath-proof/0001-bootpath-cmdline-tag.patch` | 主仓 | 直接过 |
| 70 | `20261107R44-cmdline-witness/0001-cmdline-tag-witness.patch` | 主仓 | 直接过 |
| 71 | `20261107R45-initcalldebug/0001-cmdline-initcall-debug.patch` | 主仓 | 直接过 |
| 72 | `20261107R47-wdogoff/0001-wdog-disable-before-jump.patch` | 主仓 | 直接过 |
| 73 | `20261107R48-wdogstrong/0001-wdog-bite-disable-pet-before-preeb.patch` | 主仓 | 直接过 |
| 74 | `20261107R49-wdogarchscm/0001-wdog-arch-and-scm-disable.patch` | 主仓 | 直接过 |
| 75 | `20261107R46-nosdcc/0001-exclude-sdccdxe.patch` | 主仓 | 直接过 |
| 76 | `20261107R53-nosdcc-all/0001-sdccdxe-apriori-and-components.patch` | 主仓 | 直接过 |
| 77 | `20261108R54-espfirst/0001-bdsdxe-esp-first.patch` | MU_BASECORE | 直接过 |
| 78 | `20261108R61-hoist-exchook/0001-bdsdxe-hoist-exception-rehook.patch` | MU_BASECORE | 直接过 |
| 79 | `20261109R64-pidicensus/0001-bdsdxe-partition-census-and-esp-by-name.patch` | MU_BASECORE | 直接过 |
| 80 | `20261109R66-beacon2/0001-bdsdxe-raw-sector-beacon-v2.patch` | MU_BASECORE | 直接过 |
| 81 | `20261109R67-panelhold/0001-bdsdxe-panel-counts-and-hold.patch` | MU_BASECORE | 直接过 |
| 82 | `20261110R68-trace/0001-bdsdxe-beacon-v3-trace-and-stage-fix.patch` | MU_BASECORE | 直接过 |
| 83 | `20261110R69-prepi-hold/0001-prepi-stage-hold.patch` | 主仓 | 直接过 |
| 84 | `20261110R70-prepi-timing/0001-prepi-timing-bands.patch` | 主仓 | 直接过 |

落点分布：主仓 63 条 / `MU_BASECORE`（MdeModulePkg）13 条 / `Common/MU_TIANO`（EmbeddedPkg）4 条 /
`Silicon/Arm/MU_TIANO`（ArmPkg）4 条。

---

## 4. 未决点（本轮无法闭合，按代价排序）

1. **p65 / p69 两件都还没上机** —— 判据（ESP 是否被 BDS 认作候选）只在设备上成立。
   预期现象：屏上应出现 `[K] esp blk=<n>` / `[K] esp fs=<n>` / `[K] esp ld=0 i=<n>`，随后 GRUB 菜单。
   p69 额外有 PrePi 25 s ×3 停留（`R70`），**"看起来卡住"是设计行为**，别当失败断电。
2. **`esp-none` 分支的上机形态差异未解**：2026-11-09 `p61` 的 flashed 形态实测 `[K] esp fs=1` → `esp none`
   （`PITFALLS #575`：补丁没进执行件 / 分支没走到，两解释未分）。本次是 RAM 形态（`fastboot boot`），
   与 p59/p60 的上下机形态一致，但**flash 形态的风险仍在**。
3. **`R62`（连所有句柄后重扫）在配方里被 SKIP**：p69 走的是 `R54` 的"逐个 BlockIo 句柄 `ConnectController`"。
   若上机看到 `fs=0`，下一发应改用 `pc1/pc2` 世代（`pc1 = R71`）而不是再改 p69。
4. **整编的可复现性仍受 `PITFALLS #510` 限制**（FD 含 `__DATE__/__TIME__`）⇒ 判等只比关键字串，不比 sha。
5. **`--base` 依赖**：默认 base `reports/artifacts/uefi-posctrl-20261103/boot_b-live.img` 已被资产清理删除，
   本轮改用 `out/uefi-20261104R21-hostdiag-r1.img`（同基座，`only-kernel-differs` 断言通过）。
   这条依赖应写进 ladder 脚本的默认回退链（现回退找 `out/r21-sbstop-p*/uefi-preamble*-r1.img`，**盘上已无**）。

---

## 5. 下一步（一条命令 + 判据）

**优先做这条（零编译、零写盘、10 分钟量级，需物理键进 fastboot）：**

```sh
cd /home/xuqianhui/y700-elden
# 设备侧（用户物理键：长按电源 10 s → 音量上+电源）进 fastboot 后：
timeout 300 fastboot boot build/uefi-woa-prep/merge-espfirst-20261121/out-p65/uefi-preamble65-r1.img
```

- 预期产物路径：无（零写盘；RAM 载荷）。
- 判据（按序，任一不成立即停）：
  1. `fastboot` 侧 `Sending boot.img (~64 MB) OKAY` + `Booting OKAY [~10 s]`；
  2. 屏上出现 `[K] esp blk=` / `[K] esp fs=` 行（scale 4）；
  3. **出现 GRUB 菜单** ⇒ esp-first 链打通，`gates` 的下一步变成「GRUB 读 linux17:/boot」；
  4. 出现 `[K] esp none` 或退回 `fastboot continue` 形态 ⇒ 记 `p65` 为负结果，改试 `out-p69`（带 R70 台阶停留，可看停在哪一步）；
  5. 40 s 内无任何画面变化且 fastboot 无应答 ⇒ 按 `PITFALLS #387/#418` 判「ABL 拒收」，等 25 s 判停手，长按电源回 Linux。
- 回退：`fastboot reboot`（b 槽 `boot_b` 未动，sha 仍应 `740d431b…`）；本轮不写任何分区。

**只有在需要改 UEFI 代码时才整编（空载窗口）：**

```sh
cd /home/xuqianhui/y700-elden
REPO=$PWD/build/uefi-woa-prep/merge-espfirst-20261121/tree \
timeout -k 10 2400 scripts/uefi-r21-p7-ladder.sh --gen p69 --mkimg-only --rebuild --outdir out/r21-sbstop-p69
```

- 预期产物：`out/r21-sbstop-p69/uefi-preamble69-r1.img`（+ 同目录 `SM8750_EFI.fd`、`manifest.txt`、`build.log`）。
- 判据：① `SM8750_EFI.fd` mtime ≥ 构建开始（`PITFALLS #494`）；② `scripts/uefi-fv-strings.py <FD> "esp blk="` = 1；
  ③ repack 打印 `assert-ok: header v2, text_offset=0, flags=0xa`；④ 不比 sha（`#510`）。
- 需要更多子模块（`Binaries`/`Common/MU`/`Features/*`/`Platforms/CranePkg`/`Platforms/SurfaceDuoACPI`/openssl）
  才能真的过 `stuart_build`；本目录只初始化了打补丁必需的三个，整编前按 `README.md` §5 补。

---

## 6. 证据与复跑

| 件 | 路径 |
|---|---|
| 可复现树 + 复现序列 | `build/uefi-woa-prep/merge-espfirst-20261121/`（`README.md` §2 逐条命令） |
| 重放驱动 | `build/uefi-woa-prep/merge-espfirst-20261121/replay.sh`（`--check-only` 支持只测不落） |
| 逐条裁决原始件 | 同目录 `replay-status.tsv`、`replay.log` |
| 两件可引导件 | 同目录 `out-p65/uefi-preamble65-r1.img`、`out-p69/uefi-preamble69-r1.img` |
| 既有构建归档（本轮未重建） | `reports/artifacts/uefi-20261110R70-p69/`、`…/uefi-20261109R66-p65/` |
| 世代复现入口 | `scripts/uefi-r21-p7-ladder.sh --gen {p59,p65,p69,pc1,pc2}` |

复跑最小集（~6 min，纯主机）：

```sh
cd /home/xuqianhui/y700-elden
build/uefi-woa-prep/merge-espfirst-20261121/replay.sh          # 需树已在位（README §2 步骤 1–4）
awk -F'\t' '/^#/ {next} {c[$3]++} END {for (k in c) printf "%s=%d\n", k, c[k]}' \
  build/uefi-woa-prep/merge-espfirst-20261121/replay-status.tsv  # 期望 OK=84
```

## 7. ★2026-11-21 晚 上机实测（p65 一发，零写盘）：**UEFI 真交棒起来了，但没有完整 GRUB 菜单**

```
fastboot boot build/uefi-woa-prep/merge-espfirst-20261121/out-p65/uefi-preamble65-r1.img
  Sending 'boot.img' (65620 KB) OKAY [1.479s] / Booting OKAY [10.063s]
→ 约 40 s 后 ssh 通、uptime 0 min（新起），root = /dev/sda17 LABEL=linux，graphical.target active
```

内核侧硬证据（`scripts/uefi-boot-trial.sh:240` 定义：该 token **只有 UEFI R43+ 才写**）：

```
/proc/cmdline = … elder_root=LABEL=linux androidboot.slot_suffix=_b
                   androidboot.serialno=51318dc0 androidboot.baseband=apq
                   elden_bootpath=uefi initcall_debug
```

ABL 侧 `logfs seg0` 本次记录 = `Fastboot=1` → `Booting from slot (_b)` → `BootLinux: factory_build = 0`
（= 我们喂进去的 RAM 件，不是原厂件）。

**用户目视：没有出现完整的 GRUB 菜单。** 与内核侧互证的一处不吻合必须记账：
`dmesg` 有 `efi: UEFI not found.`、`/sys/firmware/efi` 不存在 ⇒ 内核**不是**经 EFI-stub 交接；
运行 cmdline 也没有 grub.cfg 里的 `root=LABEL=…` / `elden_boot=grub`
⇒ 更可能是 **Mu 自己的 LinuxLoader 读了 `boot_b` 直接起核**，而不是 ESP 里的 GRUB 菜单那一路。

未闭合（下轮要取的就是这两条）：
- ESP 里的 `EFI/BOOT/BOOTAA64.EFI`（我们的 GRUB）到底被 BDS 执行了没有 —— 判据 = 屏上 `[K] esp blk=` / `[K] esp fs=`；
- 若被执行却没出菜单：是 `grub.cfg` 路径（ESP 用 `/grub/grub.cfg`，而 `linux17:/boot/grub/grub.cfg` 是另一份）
  还是 gfxterm/console 输出没地方显示。
