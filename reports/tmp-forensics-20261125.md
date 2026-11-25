# /tmp 大件归属取证（只读取证 lane）— 2026-11-25

> 性质：**只读取证**。本 lane 未删除/移动任何文件（含 `/tmp`），无 git 写、无 ssh。
> 唯一写入 = 本文件。A/B 的删除/归档命令**仅供父代理复核后执行，本 lane 未执行**。
> 判据：证据不足 ⇒ **C 保留**（宁可留不能误删）。

## 0. 结论摘要

- 候选 12 项中：**A（y700-elden 且可重建）= 8 项 / ≈ 71.0 G**；**B（y700-elden 但可能是唯一证据）= 2 项 / ≈ 11.3 G**；**C（其他项目/不确定）= 2 项 / ≈ 5.6 G**。
- **C 的 2 项都指向另一个项目 `~/netease-mini-player`（网易云音乐播放器）**：`gu-test`（Gradle 构建缓存，daemon 日志 `currentDir=/home/xuqianhui/netease-mini-player/ui/android`）与 `ncm-cold-before`（cargo target，fingerprint 里全是 `netease-mini-player/core/crates/ncm-*`）。同族的 `ncm-cold-after`（2.2 G，不在候选单）也是该项目。**一律不碰。**
- A 里体量最大三项（`v3test` 15 G、`lpz` 16 G、`pkgtest` 17 G）全部是 2026-11-18/19 Android super 精简线的**重建/解包工作区**；`pkgtest/super.img` 与仓内 `out/android-min-20261118/pkg/super_min.img` **sha 完全相同**，直接是重复件。
- **纠正上一份盘点**：`reports/repo-slim-candidates-20261125.md:177` 称「`/tmp/lpz` 被 206 处报告/文档提及」——现查 `/tmp/lpz` 在报告/文档里**只有该报告自身 1 处命中**（`rg -n '/tmp/lpz' reports/ TASKS/ .pi/ INDEX.md HISTORY/ SESSIONS/`），该数字不成立。
- **顺带发现（本 lane 不修）**：`out/android-slim-v3-20261119/new/system_a.img` 现 sha = `0b400b93…`，而 `new/SHA256SUMS`/`MANIFEST.md` 记的是 `db74cd06…`；该文件 mtime 与 `super_dbg.img` 同为 11-19 21:18，疑为 debug 变体构建覆盖了 final。`super_min_v3.img` 仍 = `51eae107…`（未受影响）。`/tmp/rbex/system_a.img` 恰好是 MANIFEST 口径的 `db74cd06…` 副本，但可由 `rb/super_rb.img` 重提取（见 §8），故仍判 A。

## 1. 方法

逐项四问：① 内容指纹（标志文件 / `file` / super 分区名 / CACHEDIR.TAG / manifest / 日志里的项目路径）；② 时间与仓内引用（mtime ↔ 会话/报告；`rg <路径>` 命中给 file:line）；③ 归属；④ 仅 y700-elden 才判可重建性（原始输入路径 + 重建命令）。

- 归属判据**不看目录名语义**，只看内容里出现的项目路径、报告/会话里记录的命令、以及可复算的 sha。
- 所有命令套 `timeout -k`；未使用 `find /tmp -delete` 一类递归删。

## 2. /tmp/v3test — 15 G

| 证据面 | 现查结果 |
|---|---|
| 内容指纹 | `ZUIEpos.apk`(391,898,290 B)、`ZuiAILens.apk`(166,144,953 B)、`ZuiNewBrowser.apk`(90,659,456 B)、`drop.txt`（4 个包名 `com.lenovo.tab_extreme`/`com.zui.ai.lens`/`com.zui.browser`/`com.ss.android.ugc.aweme`）、`launcher.db`/`launcher_2layer.db`/`l1.db`；`super_auto.img` 7,451,906,048 B、`super_test.img` 23,622,320,128 B（sparse，du 7.0 G）。两镜像 `strings` 命中 `system_a/vendor_a/product_a/system_ext_a/vendor_dlkm_a/system_dlkm_a/qti_dynamic_partitions_a`，**无 `linux17`**（纯 Android super）。 |
| 时间/引用 | mtime 11-19 19:36–19:54。会话 `.pi/sessions/2026-11-19T11-20-17-246Z_01a1f389-325e-7204-8f35-d80670139502.jsonl:339-341`：`mkdir -p /tmp/v3test` + 从 `out/android-min-avb-20261118/parts/system_a.img` `debugfs dump` 三个 APK/DB；`:385,:393` 造 `super_test.img`；`:422-423` 造 `super_auto.img`（lpmake）。报告仅 `reports/repo-slim-candidates-20261125.md:171` 泛列，无证据级引用。 |
| 归属 | **y700-elden**（android-slim-v3 去预装 lane）。 |
| 可重建性 | APK 输入源 `parts/` 已删（`reports/bigfile-verdict-20261120.md:6`），但可由 `backup/official-rom-15.10.259/super_1..8.img` 重拆（同报告 `:21` 给出 7/7 逐字节复现命令：`python3 scripts/android-super.py assemble … --label super --base-lba 90504` + `extract`）。`super_auto/test` 由 `out/android-slim-v3-20261119/work/system_v3/` 用 `lpmake` 重打（会话 `:385,:422` 原命令）。 |

**分级：A**（重建/验证中间件；final 件在 `out/android-slim-v3-20261119/new/`）。

## 3. /tmp/lpz — 16 G

| 证据面 | 现查结果 |
|---|---|
| 内容指纹 | `lpunpack-master/`（`README.md` = `lpunpack.py … extracting partition images from super`，即第三方 `unix3dgforce/lpunpack` 纯 Python 实现，`lpunpack.py` 33 KB）；`out/` 7 个分区明文：`system_a.img` 12,268,879,872 B（`file`=Linux ext4, UUID 40e7f3d1…）、`product_a` 1,041,178,624、`vendor_a` 1,536,176,128、`system_ext_a` 598,372,352、`vendor_dlkm_a` 147,382,272、`system_dlkm_a` 12,533,760、`odm_a` 1,650,688，另有 7 个 0 字节 `*-cow.img`；`cmp/system_ext_a.img` sha `ff1acb3a3cf071d3…` = `reports/bigfile-verdict-20261120.md` 表里的**原厂** system_ext sha；`t/` = 4 MiB/2 MiB 假分区 + 20 MiB `super.img`（lpmake→lpunpack 冒烟回路）。 |
| 时间/引用 | mtime 11-18 12:50–12:57（与 `out/android-super-20261118/` 同一上午）。`reports/android-super-format-20261118.md:206` 明确记录「独立交叉验证：`unix3dgforce/lpunpack`（948 行纯 python 第三方实现）」；`:251-252` 记录 14/14 MATCH 与第三方实现抽样一致；`:12` 记录原始 8 分片在 `backup/official-rom-15.10.259/super_*.img`。 |
| 归属 | **y700-elden**（Android super 格式对账 lane）。 |
| 可重建性 | 原始输入在仓内：`backup/official-rom-15.10.259/super_1..8.img`（14.53 GiB）。重建：`python3 scripts/android-super.py assemble --xml backup/official-rom-15.10.259/rawprogram_save_persist_unsparse0.xml --label super --base-lba 90504 -o /tmp/lpz/super-assembled.img`，再 `python3 lpz/lpunpack-master/lpunpack.py /tmp/lpz/super-assembled.img /tmp/lpz/out`（`t/` 冒烟件可用 `lpmake` 重造）。 |

**分级：A**。

## 4. /tmp/pkgtest — 17 G

| 证据面 | 现查结果 |
|---|---|
| 内容指纹 | `super.img` **8,893,497,344 B，sha256 `e3d0d26f…`**；`out/` 7 个分区：`system_a`(5,553,258,496)、`vendor_a`(1,537,212,416)、`product_a`(1,041,235,968)、`system_ext_a`(598,736,896)、`vendor_dlkm_a`(147,849,216)、`system_dlkm_a`(12,582,912)、`odm_a`(2,097,152)。`super.img` 内含 `system_a/vendor_a/product_a/system_ext_a/vendor_dlkm_a/system_dlkm_a/odm_a/qti_dynamic_partitions_a`。 |
| 时间/引用 | mtime 11-18 14:45。会话 `.pi/sessions/2026-11-18T02-55-07-074Z_01a1ec94-5741-7751-a6d6-3a08d0ec8063.jsonl:1556` 记录原命令 `cd /tmp && rm -rf pkgtest && mkdir pkgtest && … 把 super_min.img 补成 device 大小再解`。 |
| 归属 | **y700-elden**（与 `out/android-min-20261118/` 同 lane）。 |
| 可重建性 | **`/tmp/pkgtest/super.img` 与仓内 `out/android-min-20261118/pkg/super_min.img` sha 完全相同**（本轮实测两文件均 `e3d0d26fb3a6f97ec10e4533ea2d675a9693acb42bb10ddb9dd4cb897517e13c`），`out/` 是对它的解包产物；用同一 lpunpack 命令可随时重解。 |

**分级：A**（`super.img` 是仓内 pending 件的字节重复副本；`out/` 纯解包中间件）。

## 5. /tmp/ltbox-target — 5.8 G

| 证据面 | 现查结果 |
|---|---|
| 内容指纹 | 典型 cargo target：`CACHEDIR.TAG`（`created by cargo`）、`.rustc_info.json`、`debug/.fingerprint/`（1516 个子目录）、`debug/deps` 4.6 G、`debug/build` 497 M、`debug/ltbox` **649,058,208 B ELF 可执行**。 |
| 时间/引用 | mtime 11-18 17:02–17:07。`reports/ltbox-evaluation-20261118.md:3`「评估对象 `external/ext-repos/LTBox`（= `~/LTBox`）」、`:26-27`「`cargo build -p ltbox-gui --offline` → 44.8 s 产出 649 MB 可执行文件 `/tmp/ltbox-target/debug/ltbox`」、`:29` 记录首次需联网取 git 依赖。源码 `~/LTBox` 现存、`git status` 干净（HEAD `8f6d141c467e…`）。 |
| 归属 | **y700-elden**（本项目的 LTBox 评估 lane；源码属外部 repo，但 `/tmp` 产物是这次评估的构建缓存）。 |
| 可重建性 | `cd ~/LTBox && CARGO_TARGET_DIR=/tmp/ltbox-target cargo build -p ltbox-gui --offline`（本地 cargo 缓存已在；若 `--offline` 因 git 依赖失败，先 `cargo metadata` 一次联网）。 |

**分级：A**（纯编译缓存，报告已留存结论与 file:line）。

## 6. /tmp/super_corrupt_evidence.img — 7.0 G

| 证据面 | 现查结果 |
|---|---|
| 内容指纹 | 7,454,326,784 B，`file`=data；**sha256 `8f962be…`**，是 final `super_min_v3`（`51eae107…`）的位翻转变体；含 `system_a/vendor_a/product_a…`。 |
| 时间/引用 | mtime 11-19 20:25。会话 `.pi/sessions/2026-11-19T11-20-17-…jsonl:1013`：`cp out/android-slim-v3-20261119/new/super_min_v3.img /tmp/super_corrupt_evidence.img`（先备份被污染件再覆盖）；`:923` 重建出 `51eae107` 并覆盖。报告 `reports/android-slim-v3-20261119.md:140-144` 记录三哈希漂移与 11 字节差；**仓外证据目录** `~/hw-stability/evidence/inbox/20261119-y700-elden-super-bitflip/hashes.txt` 第一行直接引用 `/tmp/super_corrupt_evidence.img`，`offsets.txt` 给出 11 处 `offset old new`。 |
| 归属 | **y700-elden**（主机位翻转取证件，被 hw-stability MANIFEST/hashes 引用）。 |
| 可重建性/唯一性 | 该 8f962bee 镜像**本身只有这一份**（hw-stability 目录只有 hashes+offsets，无镜像）；但可由 `51eae107` 按 `offsets.txt` 的 11 处单字节改写重现。⇒ 先归档再删。 |

**分级：B**。

## 7. /tmp/super_rebuild.img — 7.0 G

| 证据面 | 现查结果 |
|---|---|
| 内容指纹 | 7,454,326,784 B；**sha256 `51eae1075fe159b02946a4e4e5548fa83bb5e861fb441244ac8dddc423bc6440`**，与 `out/android-slim-v3-20261119/new/super_min_v3.img` **逐字节相同**。 |
| 时间/引用 | mtime 11-19 20:24；会话 `…01a1f389…:915`（`lpmake … -o /tmp/super_rebuild.img` 三次哈希）、`:923`（`cp /tmp/super_rebuild.img new/super_min_v3.img`）；`reports/android-slim-v3-20261119.md:144` 记录「重新 lpmake 三次一致 = 51eae107」。 |
| 归属 | **y700-elden**。 |
| 可重建性 | 仓内已有同 sha 成品；需要时用 `out/android-slim-v3-20261119/work/` + `lpmake` 重打。 |

**分级：A**（纯重复件）。

## 8. /tmp/rbex — 3.9 G

| 证据面 | 现查结果 |
|---|---|
| 内容指纹 | `system_a.img` 4,110,417,920 B，`file`=Linux ext4, volume name "system"，**sha `db74cd06…`**（= `new/SHA256SUMS` 里 system_a 的 sha）。 |
| 时间/引用 | mtime 11-19 20:22；会话 `…01a1f389…:871-872`：`python3 scripts/android-super.py extract out/android-slim-v3-20261119/rb/super_rb.img /tmp/rbex --partition system_a --sparse` → `extracting system_a 4110417920 B -> /tmp/rbex/system_a.img`；`:878` 起 `cmp -l /tmp/rbex/system_a.img new/system_a.img`；`reports/android-slim-v3-20261119.md:103`「round-trip 出的 system_a 与 new/system_a.img 逐字节相同」。 |
| 归属 | **y700-elden**。 |
| 可重建性 | 输入在仓内：`out/android-slim-v3-20261119/rb/super_rb.img`（本轮实测仍 `51eae107…`）。重建 = 会话 `:871` 原命令；耗时 ~5 s。 |

**分级：A**。
（注：`rb/super_rb.img` 仍是 51eae107，rbex 的 db74cd06 可由它重提取；见 §0 顺带发现——`new/system_a.img` 现为 0b400b93，MANIFEST 已陈旧。）

## 9. /tmp/csiphy2 — 3.7 G

| 证据面 | 现查结果 |
|---|---|
| 内容指纹 | `build/` 3.7 G 内核编译产物（`build-W1.log` 从 `SYNC include/config/auto.conf` 起）；`git/` 稀疏源码树（HEAD `86e8cece56e9…` "v25 01-03 prefix"，只含 `drivers/phy/qualcomm/phy-qcom-mipi-csi2-{3ph-dphy.c,core.c}` + 头）；`old-0002.patch`（12,845 B，与 `patches/upstream/camss-csiphy-24-20261115/0002-…` **逐字节相同**）；`out/0001-0002` 为 v2 草稿，与归档 `patches/upstream/camss-csiphy-24-v2-20261117/` 的 diff **仅 Subject 一行**（`[PATCH]` vs `[PATCH v2 2/2]` 换行）；`table-diff.txt`「lane_regs_sm8750 105 条 / 与 x1e80100 地址序列相同 / 13 条不同」；`v25-01..03.patch`。 |
| 时间/引用 | mtime 11-17 15:31–15:49；`reports/misc-20261117.md:5`「camss CSIPHY 2.4.0 delta 对账复核（`patches/upstream/camss-csiphy-24-20261115/`）」、`:12`（103/103 全等、差 13）；最终 v2 系列已归档在 `patches/upstream/camss-csiphy-24-v2-20261117/`（11-18 10:23–10:26）。 |
| 归属 | **y700-elden**（相机 CSIPHY 2.4.0 上游 lane）。 |
| 可重建性 | 唯一产物（patch）已归档在 `patches/upstream/camss-csiphy-24-20261115/`（old-0002 逐字节）与 `patches/upstream/camss-csiphy-24-v2-20261117/`（out/0001-0002 仅 Subject 差一行）；`v25-01..03.patch` 是拼 patch 用的 diff 片段；`build/` 随时可重编；源码树可从主线重取。 |

**分级：A**（3.7 G 里 3.7 G 全是 `build/` 编译产物）。

## 10. /tmp/gu-test — 3.3 G

| 证据面 | 现查结果 |
|---|---|
| 内容指纹 | Gradle 用户目录：`wrapper/dists/gradle-{9.3.1-all,9.3.1-bin,8.14.3-bin}`（830 M）、`caches/` 2.5 G、`daemon/9.3.1/daemon-2411954.out.log`、`kotlin-profile/`、`native/`；`CACHEDIR.TAG`。 |
| 时间/引用 | mtime 11-21 12:46–12:47。**daemon 日志** `daemon/9.3.1/daemon-2411954.out.log:45-47`：`currentDir=/home/xuqianhui/netease-mini-player/ui/android`；fingerprint 里也全是该路径。仓内 `rg gu-test` 仅命中上一份盘点报告与派发计划。 |
| 归属 | **其他项目：`~/netease-mini-player`（网易云音乐播放器，Android UI）**。 |
| 可重建性 | 不判（非本项目）。 |

**分级：C（不碰）**。

## 11. /tmp/trixie-sysroot — 2.6 G

| 证据面 | 现查结果 |
|---|---|
| 内容指纹 | `root/etc/os-release` = `Debian GNU/Linux 13 (trixie)` 13.8；`root/usr/bin/aarch64-linux-gnu-gcc-14` 等交叉工具链；`apt/`（665 M，`sources.list` = `deb [arch=arm64] https://mirrors.ustc.edu.cn/debian trixie main`）；`cross.txt`/`cross2.txt` = meson cross-file（`c='aarch64-linux-gnu-gcc'`、link args 指向本 sysroot）。 |
| 时间/引用 | mtime 11-23 19:20–22:02。`reports/rime-completer-userdir-20261124.md:192`（`qemu-aarch64 -L /tmp/trixie-sysroot/root`）、`:329-330`（`--sysroot=/tmp/trixie-sysroot/root`）；`reports/d3-ime-userdir-fallback-20261124.md:101-102,:117`；`INDEX.md:108`（「trixie arm64 chroot 编译环境 = `/tmp/trixie-sysroot/`（789 包闭包，可复用）」）。会话 `.pi/sessions/2026-11-23T09-34-49-255Z_…jsonl` 记录 `mkdir -p /tmp/trixie-sysroot/...` + `apt-get -o Dir=/tmp/trixie-sysroot/apt` 安装。 |
| 归属 | **y700-elden**（IME/rime 交叉编译 lane）。 |
| 可重建性 | 用同一 apt 口径重建：`mkdir -p /tmp/trixie-sysroot/{apt,root}`，`apt-get -o Dir=/tmp/trixie-sysroot/apt -o Dir::Etc::sourcelist=sources.list … install gcc-14-aarch64-linux-gnu libc6-dev:arm64 pkg-config …`（源 = USTC trixie main，`apt/` 内已有索引/包缓存可加速）。 |

**分级：A**（工具链缓存；但注意 §12 风险：两份报告把该路径当「现存可用」写进可复跑命令）。

## 12. /tmp/ncm-cold-before — 2.3 G

| 证据面 | 现查结果 |
|---|---|
| 内容指纹 | cargo target：`CACHEDIR.TAG`（`created by cargo`）、`.rustc_info.json`、`debug/` 2.3 G、`debug/examples/c2_sampling*`；**fingerprint 路径直接写出 `~/netease-mini-player/core/crates/ncm-domain`、`ncm-playback`、`ncm-api-rs`、`ncm-cli`、`ncm-ffi`、`ncm-plugin`**。 |
| 时间/引用 | mtime 11-19 21:45。仓内 `rg ncm-cold` 只命中 `reports/repo-slim-candidates-20261125.md:173`（当时未做归属核验，写成「可重生」）。 |
| 归属 | **其他项目：`~/netease-mini-player`**（"ncm" = Netease Cloud Music 域模型 crate 前缀）。 |
| 可重建性 | 不判（非本项目）。 |

**分级：C（不碰）**。同族 `/tmp/ncm-cold-after`（2.2 G，不在候选单）同项目、同样不碰。

## 13. 三张表

### A = 确认 y700-elden 且可重建（建议删，≈ 71.0 G）

| 项 | du | 重建依据 | 建议命令（父代理复核后执行） |
|---|---|---|---|
| `/tmp/v3test` | 15 G | §2：APK 可从 `backup/official-rom-15.10.259/super_*.img` 重拆；test 镜像可 `lpmake` 重打 | `timeout -k 10 600 rm -rf /tmp/v3test` |
| `/tmp/lpz` | 16 G | §3：`backup/official-rom-15.10.259/super_1..8.img` + `scripts/android-super.py assemble` + `lpunpack.py` | `timeout -k 10 900 rm -rf /tmp/lpz` |
| `/tmp/pkgtest` | 17 G | §4：`super.img` = `out/android-min-20261118/pkg/super_min.img`（sha `e3d0d26f…`）字节重复 | `timeout -k 10 900 rm -rf /tmp/pkgtest` |
| `/tmp/ltbox-target` | 5.8 G | §5：`cd ~/LTBox && CARGO_TARGET_DIR=/tmp/ltbox-target cargo build -p ltbox-gui --offline` | `timeout -k 10 600 rm -rf /tmp/ltbox-target` |
| `/tmp/super_rebuild.img` | 7.0 G | §7：与 `out/android-slim-v3-20261119/new/super_min_v3.img` 同 sha `51eae107…` | `timeout -k 10 300 rm -f /tmp/super_rebuild.img` |
| `/tmp/rbex` | 3.9 G | §8：`scripts/android-super.py extract out/android-slim-v3-20261119/rb/super_rb.img /tmp/rbex --partition system_a --sparse` | `timeout -k 10 300 rm -rf /tmp/rbex` |
| `/tmp/csiphy2` | 3.7 G | §9：patch 已归档 `patches/upstream/camss-csiphy-24-v2-20261117/`；`build/` 可重编 | `timeout -k 10 300 rm -rf /tmp/csiphy2` |
| `/tmp/trixie-sysroot` | 2.6 G | §11：apt Dir 口径重建（USTC trixie arm64） | `timeout -k 10 300 rm -rf /tmp/trixie-sysroot`（先读 §14 风险 2） |
| **合计** | **≈ 71.0 G** | — | — |

### B = y700-elden 但可能是唯一证据（归档后再删，≈ 11.3 G）

| 项 | du | 唯一性 | 建议命令（先归档、核 sha 后再删） |
|---|---|---|---|
| `/tmp/super_corrupt_evidence.img` | 7.0 G | sha `8f962bee…` 只有这一份；`~/hw-stability/evidence/inbox/20261119-y700-elden-super-bitflip/hashes.txt` 按此路径引用 | `cp -a /tmp/super_corrupt_evidence.img ~/hw-stability/evidence/inbox/20261119-y700-elden-super-bitflip/ && sha256sum ~/hw-stability/evidence/inbox/20261119-y700-elden-super-bitflip/super_corrupt_evidence.img`，确认 = `8f962bee…` 后 `timeout -k 10 300 rm -f /tmp/super_corrupt_evidence.img` |
| `/tmp/b9` | 4.3 G | `out/0001..0006` 是 aw86927 **v1** 补丁（sha `f2e0d58d…`，仓内 `patches/` 无同 sha 件）；`tree/` 有 10 个未归档驱动改动（`gcc-sm8750.c` gdsc `PWRSTS_RET_ON`、`llcc-qcom.c` `res_ways`、`tsens.c` 去 `__init`、`dwc3/{core,qcom,am62}.c`），`repo/` HEAD `5f1a30b7…` 为该系列末枚 | `git -C /tmp/b9/tree diff > /home/xuqianhui/y700-elden/backup/b9-tree-dirty-20261113.diff && tar --zstd -cf /home/xuqianhui/y700-elden/backup/b9-20261113.tar.zst -C /tmp b9/out b9/msg5 b9/repo`，确认归档后 `timeout -k 10 600 rm -rf /tmp/b9` |
| **合计** | **≈ 11.3 G** | — | — |

### C = 其他项目或不确定（不碰，≈ 5.6 G）

| 项 | du | 归属 | 判据 |
|---|---|---|---|
| `/tmp/gu-test` | 3.3 G | 其他项目：`~/netease-mini-player` | Gradle daemon 日志 `currentDir=/home/xuqianhui/netease-mini-player/ui/android`（`/tmp/gu-test/daemon/9.3.1/daemon-2411954.out.log:45-47`） |
| `/tmp/ncm-cold-before` | 2.3 G | 其他项目：`~/netease-mini-player` | cargo fingerprint 路径 `netease-mini-player/core/crates/ncm-{domain,playback,api-rs,cli,ffi,plugin}` |
| （附）`/tmp/ncm-cold-after` | 2.2 G | 其他项目：同上 | 与 before 同构；不在候选单，仅备查 |

## 14. 风险与待办（供父代理）

1. **B 两项的归档动作会写仓内 `backup/`**（b9 的 diff/tar.zst）——本 lane 未执行；若父代理不想写仓，可改存 `/home/xuqianhui/hw-stability/evidence/` 或外置。
2. **`trixie-sysroot` 虽判 A，但 `reports/rime-completer-userdir-20261124.md:329-330` 与 `reports/d3-ime-userdir-fallback-20261124.md:101-102` 把 `/tmp/trixie-sysroot/root` 当现存路径写进「可复跑」命令**；删后这两条命令复跑前需先按 §11 重建。若近期还要复跑 IME/rime 验证，建议暂缓删或重建后再删。
3. **`out/android-slim-v3-20261119/new/system_a.img` sha 与 MANIFEST/SHA256SUMS 不符**（现 `0b400b93…` vs 记 `db74cd06…`，mtime 11-19 21:18 与 `super_dbg.img` 同刻）——这是 `out-artifacts.tsv:11` 标 pending/禁删的目录，属 SSOT 一致性问题，建议另开 lane 复核（很可能需重生成或更新 MANIFEST）；本 lane 只记录，不处理。
4. **未审计项**：候选单外 `/tmp` 还有大量 1.9–2.2 G 的 `dwc3-*/gate-*/hap-*/muxes-v2/*-verify` worktree（上一份报告估 ≈40 G），本 lane 未逐项定归属；它们多数在 `build/elden-tree` 的 `git worktree list` 里，处理前须 `git worktree prune`。
5. **上一份盘点的两处口径修正**：① `/tmp/lpz`「206 处提及」不成立（实为 1 处，即该报告自身）；② 该报告把 `gu-test`/`ncm-cold-*` 归入「安卓 super 重建/验证镜像 ≈80 G」，实测这两族属 `~/netease-mini-player`，不应计入本项目可回收量。

## 15. 证据索引（本轮现查命令）

```bash
du -sh /tmp/* | sort -h | tail -20
ls -la --time-style=long-iso /tmp/{v3test,lpz,pkgtest,ltbox-target,b9,rbex,csiphy2,gu-test,trixie-sysroot,ncm-cold-before}
file /tmp/{lpz/out/system_a.img,rbex/system_a.img,pkgtest/out/system_a.img}
strings -n 5 /tmp/pkgtest/super.img | grep -E '^[a-z_]+_a$|^metadata$'
sha256sum /tmp/pkgtest/super.img out/android-min-20261118/pkg/super_min.img      # e3d0d26f… 两边相同
sha256sum /tmp/super_rebuild.img out/android-slim-v3-20261119/new/super_min_v3.img  # 51eae107… 相同
sha256sum /tmp/super_corrupt_evidence.img                                        # 8f962bee…
sha256sum /tmp/rbex/system_a.img out/android-slim-v3-20261119/new/system_a.img   # db74cd06… vs 0b400b93…（MANIFEST 陈旧）
git -C /tmp/b9/tree log -1 --format='%H %s'; git -C /tmp/b9/tree diff --name-only | wc -l   # 116（10 M + 106 D 稀疏）
git -C ~/LTBox log -1 --format='%H %s'; git -C ~/LTBox status --short
grep -a 'currentDir=' /tmp/gu-test/daemon/9.3.1/daemon-2411954.out.log | head
grep -arl 'netease-mini-player' /tmp/ncm-cold-before/debug | head
rg -n '/tmp/lpz' reports/ TASKS/ .pi/ INDEX.md HISTORY/ SESSIONS/      # 仅 repo-slim-candidates:177 自身
rg -n 'super_corrupt_evidence|super_rebuild|/tmp/rbex|/tmp/v3test' .pi/sessions/2026-11-19T11-20-17-*.jsonl
```
