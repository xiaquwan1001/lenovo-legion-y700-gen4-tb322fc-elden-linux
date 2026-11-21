# Mobian 第一件可提交物 —— 可执行 MR 方案（droid-juicer + mobian-recipes）2026-11-22

> 性质：**主机侧只读调查 + 补丁草案**。零设备动作、零发信、零 fork/push、零 `git commit`。
> 上游现查用 Salsa/GitLab REST（`curl --noproxy '*'`，带 `timeout -k`）；本机 curl 直连 salsa 可用（与 11-21 报告里「TLS 被阻断」不同，本轮 rc=0，见 §1 证据行）。
> 前置报告：`reports/distro-upstream-feasibility-20261121.md`（三家裁决）、`reports/mobian-upstream-firstpr-20261121.md`（6.18 不可落 + 首件草稿）。
> **本文的增量 = 上一轮草稿里 3 处「TODO/推测」被上游源码判掉，并且发现「放哪个仓」与 11-21 假设不同。**

---

## §结论（先看这 10 行）

| # | 结论 | 判据（可复跑） |
|---|---|---|
| 1 | **上游活仓确认**：droid-juicer = `gitlab.com/mobian1/droid-juicer`（id 41929225，master，最后活动 **2026-10-31**，v0.4.3）；mobian-recipes = `salsa.debian.org/Mobian-team/mobian-recipes`（id 71384，master，最后活动 **2026-10-22**） | `GET /api/v4/projects/41929225`、`GET /api/v4/projects/Mobian-team%2Fmobian-recipes` |
| 2 | **新事实（推翻 11-21 的落点假设）**：Mobian 的 `qcom-wip` 路线把 droid-juicer 配置**从 recipes 仓自己的 `devices/qcom/droid-juicer/` 覆盖进镜像**（`/usr/share/droid-juicer/configs`），**不是**只从 droid-juicer 仓取 | `devices/qcom/packages-base.yaml:35-37`（`source: droid-juicer` → `destination: /usr/share/droid-juicer/configs`） |
| 3 | **新硬坑（会静默造出坏 boot.img）**：`wip.toml` 顶层 `chipset = ""`，而 `bootloader.sh` 用 `if .chipset then … else ${DEVICE} end`，jq 里**空串是真值** ⇒ 顶层留空则 `DEVICE_SOC=""` ⇒ DTB 路径变成 `qcom/-lenovo-elden.dtb`。**必须**在 `[[device]]` 段写 `chipset = "sm8750"` | `bootloader.sh:46,54,66`；`printf '""' \| jq -r 'if . then "truthy" else "falsy" end'` → `truthy` |
| 4 | **11-21 草稿的两个 TODO 可关闭**：`version`/`dtb` **不用写**——不带 `dtb` 字段时 recipes 走「`cat vmlinuz dtb > kernel` + v0 header」路径，正是所有 wip qcom 设备的默认；`append` 也**不用写**（`mobile.root=` 由 recipes 自己拼） | `bootloader.sh:84,88`；`sm7150.toml` 全文只有 `[bootimg]` 6 个字段 + `[[device]]` |
| 5 | **`.mdt`→`.mbn` 是硬约束**（不是可选）：droid-juicer 对 `.mdt` 一律 squash 成单文件 `.mbn`，绝不拷 `.bNN` | droid-juicer `src/firmware.rs:305-308`（`if file.name.ends_with(".mdt") { destination.set_extension("mbn"); squash_file(...) }`） |
| 6 | **改板 DTS 成单文件 `.mbn` 这条路在本机被硬件/签名否掉了**：`cdsp_dtb.mbn`（单文件）**被 TZ 拒**（真机实测），stock SunP 用 split ⇒ **`configs/lenovo,elden.toml` 里不得包含 ADSP/CDSP 那几条**，它们必须由我方 `elden-firmware` 提供 split `.mdt`+`.bNN`。**这一条更正了 11-21 报告 §4.2 第 1 条的建议** | `DEVICE/README.md:187`（「split；`cdsp_dtb.mbn` 单文件被 TZ 拒」）、`PITFALLS/sessions/06-脚本工具.md:211`（TZ 拒，非 pas_id 问题）；在机 DTB `/tmp/vk192.dts:1777,6724` |
| 7 | **`qcom-wip` 是唯一「零改 build.sh」的入口**：`build.sh` 的 qcom 设备白名单是硬编码的 6 项，新 SoC 不在此列 | `build.sh:88-94`（`"sdm845"\|"sdm670"\|"sm6350"\|"sc7280"\|"sm7150"\|"qcom-wip"`） |
| 8 | **但 `qcom-wip` 不带内核包**：只有 `-support` 包才 `Depends: linux-image-6.18-<soc>`；wip 分支只装 `qcom-support-common`，内核必须由 `devices/qcom/packages/*.deb` 提供（`dpkg -i /srv/*.deb`） | `packages-base.yaml:18-33`；`qcom-support` 仓 `debian/control`（`sdm845-support → linux-image-6.18-sdm845` 等） |
| 9 | ⇒ **A 部分（不碰内核）真正能独立提交的只有 1 件**：droid-juicer `configs/lenovo,elden.toml`。recipes 的 `wip.toml` 条目**单独提交是死条目**（没内核 deb 建不出可启镜像），应与内核分支同批 | §4 MR 排序 |
| 10 | **风险项（未验证）**：Debian 侧 droid-juicer 打包分支 `packaging/forky` 的描述原文是「(Hopefully) temporary fork until droid-juicer supports upstream kernels again」 ⇒ 主线内核设备是否会踩到未明问题，**未验证**，提交前应先在 MR 描述里问一句 | `GET https://salsa.debian.org/api/v4/projects/118668`（agx/droid-juicer，description 原文） |

---

## §1 上游仓库实际结构与口径（现查，非记忆）

### 1.1 droid-juicer（`gitlab.com/mobian1/droid-juicer`）

```bash
timeout -k 5 40 curl -sS --noproxy '*' "https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer"
timeout -k 5 40 curl -sS --noproxy '*' "https://gitlab.com/api/v4/projects/41929225/repository/tree?ref=master"
timeout -k 5 40 curl -sS --noproxy '*' "https://gitlab.com/api/v4/projects/41929225/repository/commits?ref_name=master&per_page=12"
timeout -k 5 40 curl -sS --noproxy '*' "https://gitlab.com/api/v4/projects/41929225/merge_requests?state=opened"
timeout -k 5 40 curl -sS --noproxy '*' "https://gitlab.com/api/v4/projects/41929225/issues?state=opened"
```

实测：

| 项 | 值 |
|---|---|
| 仓根 | `configs/ src/ Cargo.toml README.md config.toml.sample droid-juicer.service droid-juicer.openrc .gitlab-ci.yml` |
| 版本 | `Cargo.toml` `version = "0.4.3"`（`[package] authors = Arnaud Ferraris`） |
| 配置落点 | `/usr/share/droid-juicer/configs`（`src/main.rs:17`），按 `/proc/device-tree/compatible` 逐条找同名 `.toml`（`main.rs:75-91`） |
| 配置 schema | 单一 `[juicer]` 表：`dynpart`(可选) / `firmware`(必填) / `folders`(可选) / `partdump`(可选，v0.4.3 新增) —— `src/firmware.rs:81-87` |
| 分区解析 | 依次试 `/dev/mapper/<p>` → `<p>_a` → `<p>_b` → `/dev/disk/by-partlabel/<p>` → `_a` → `_b`（`firmware.rs:92-112`）⇒ **写基名即可** |
| `.mdt` 处理 | squash 成单 `.mbn`（`firmware.rs:305-308`，`squash_file()` 见 `:152-213`） |
| `folders.destination` | `PathBuf::from(extract_path).join(destination)`（`firmware.rs:341`）⇒ 绝对路径覆盖前缀这一行为**在 ca5343a7 之后仍成立**（Rust `join` 语义） |
| 现有 configs | 19 个，命名 `vendor,model.toml`（如 `shift,axolotl.toml`、`google,sargo.toml`）；有 dynpart 的先例见 `shift,axolotl.toml`/`fairphone,fp5.toml` |
| 评审口径（从 commit/MR 读出来的） | ① 一 device 一 config，diff 只碰 `configs/*.toml`；② 近期 commit 全是「configs: …」小步（`a160267c` 之后 6 个 commit 里 5 个是 configs 改动）；③ CI 只有 `cargo fmt/clippy/build/test`（`.gitlab-ci.yml`），**没有 TOML schema 校验** ⇒ 靠人眼 + 真机；④ 未合并 MR 5 个里有 2 个是 Draft 挂了两年的设备 config（`!2` 2023、`!22` 2025）⇒ **要么一次提交干净，要么长期挂起** |

补充：MR `!36`「configs: update fw paths according to the mainline conventions」（2026-06-07，Draft）把路径改成 `qcom/<soc>/<Vendor>/<device>`、`qca/<Vendor>/<device>`。**这条对我方有利**：SM8750 的主线约定（上游 `sm8750-mtp.dts` 用 `qcom/sm8750/adsp.mbn`，无 vendor 子目录）与该 MR 不冲突；我们写 `qcom/sm8750/...` 即可，不必等它。

### 1.2 mobian-recipes（`salsa.debian.org/Mobian-team/mobian-recipes`）

```bash
timeout -k 5 40 curl -sS --noproxy '*' "https://salsa.debian.org/api/v4/projects/Mobian-team%2Fmobian-recipes"
timeout -k 5 40 curl -sS --noproxy '*' "https://salsa.debian.org/api/v4/projects/71384/repository/tree?ref=master&path=devices/qcom&per_page=100"
timeout -k 5 40 curl -sS --noproxy '*' "https://salsa.debian.org/api/v4/projects/71384/repository/files/devices%2Fqcom%2Fpackages-base.yaml/raw?ref=master"
```

实测结构（`devices/qcom/`）：

```
configs/{sc7280,sdm670,sdm845,sm6350,sm7150,wip}.toml
droid-juicer/.gitkeep          ← 空目录，就是给 wip 设备放 droid-juicer 配置的位置
packages/.gitkeep              ← 空目录，放额外 .deb（dpkg -i）
bootloader.sh extract-bootimg.sh extract-parts.sh
packages-{base,lomiri,phosh,plasma-mobile}.yaml
```

关键路径/口径（逐行）：

| 事实 | 位置 |
|---|---|
| qcom 设备白名单（新 SoC 不在内） | `build.sh:88-94` |
| `qcom-wip` → `device=wip`，读 `configs/wip.toml` 的 `pagesize` | `build.sh:89-93` |
| wip 走 `qcom-support-common` + `openssh-server`，**不装 `{{device}}-support`** | `packages-base.yaml:18-21` |
| wip 额外装 `packages/*.deb` | `packages-base.yaml:24-33` |
| wip 把 `devices/qcom/droid-juicer/` 覆盖到 `/usr/share/droid-juicer/configs` | `packages-base.yaml:35-37` |
| boot.img：SoC 取值与 per-device 覆盖 | `bootloader.sh:46,54` |
| cmdline 拼装（`mobile.qcomsoc`, `mobile.root`, `init=/sbin/init`） | `bootloader.sh:59,88-92` |
| DTB 路径 `…/qcom/<soc>-<vendor>-<model>[-<variant>].dtb` | `bootloader.sh:66` |
| 只有 `dtb_offset` 存在时才 `--dtb`；否则 `cat vmlinuz dtb > kernel`（= v0 附加 DTB 路线） | `bootloader.sh:84,88` |
| CI：改 `devices/qcom/*` 会触发 qcom 设备 job | `.gitlab-ci/devices.yml:1-11` |

Mobian 官方 Porting 页（本轮现查 200 OK，正文命中）确认三句：「add the appropriate parameters to … `/devices/qcom/configs/wip.toml`」「write a config for **droid-juicer** … place config in `/usr/share/droid-juicer/configs`」「Mobian ships LTS kernel versions … while some **not-LTS** kernel versions can be made available in the **staging** section」。
⇒ 与 11-21 报告一致：LTS 不是第一件 MR 的硬阻塞；**但 kernel 必须有 Debian packaging**。qcom-linux 现查 50 个分支，7.x 系列在跑（`mobian-sdm670-7.3` 2026-11-17、`wip/tiol/7.4-sdm845` 2026-11-06），**无任何 sm8750 分支**。

---

## §2 MR-1（今天可提，不碰内核）：droid-juicer `configs/lenovo,elden.toml`

### 2.1 仓库/分支/文件

- 仓：`gitlab.com/mobian1/droid-juicer`
- 基线：`master`（0.4.3）
- 新文件：`configs/lenovo,elden.toml`（**文件名 = 第一条 compatible**，`main.rs:88-91` 逐条比对；`lenovo,elden` 在 `/proc/device-tree/compatible` 里排第一，见在机 DTB `/tmp/vk192.dts`）
- 提交信息建议：
  ```
  configs: add Lenovo Legion Y700 Gen4 (TB322FC)

  SM8750 board, DT compatible "lenovo,elden". Firmware is taken from the
  stock modem/bluetooth/persist partitions plus the dynamic "vendor"
  partition of "super"; sensors DSP tree is placed under
  /usr/share/qcom/sm8750/LENOVO/TB322FC where hexagonrpcd expects it.

  Not tested on this device yet (board support is being upstreamed).
  ```
  （Reviewer 会当成「未实测声明」；我方也不该写 Tested-by。）

### 2.2 文件内容（相对 11-21 草稿的修改）

11-21 的 `patches/distro/mobian-20261121/droid-juicer/lenovo,elden.toml` 结构正确（`[juicer]` + `firmware` + `folders`，`folders` 虽在文件后半仍处于 `[juicer]` 表作用域内——TOML 表作用域延伸到下一个表头），但**有 2 处必须改**：

1. **删掉 ADSP/CDSP 那一条（关键，不是风格问题）**：droid-juicer 对 `.mdt` 一律 squash 成单文件 `.mbn`，而本机 **单文件 `cdsp_dtb.mbn` 实测被 TZ 拒**（`DEVICE/README.md:187`、`PITFALLS/sessions/06-脚本工具.md:211`）。写成 `.mdt` 条目会产出**设备根本不 request、也不敢用**的 `.mbn`，同时把「需要 split 固件」这个真需求藏起来。
   ⇒ 正确做法：config **只管不依赖签名分段的件**（GPU/触屏/功放/BT/传感器树），ADSP/CDSP 的 split 件由我方 `elden-firmware` 包分发（同 `rootfs/debian/elden-firmware/`）。**11-21 报告 §4.2 第 1 条「把板 DTS 改成 `.mbn`」与这条实测冲突，以本条为准。**
2. **`ath12k` bdf 目录名待核**：`PEACH` 是 dmesg 里的内部名（`DEVICE/README.md:188` 记的是 `modem_a/peach`），主线 ath12k 的请求路径由 hw params 决定 ⇒ **保留 `ath12k/PEACH/hw2.0` 但在 MR 描述里写明「待上机 dmesg 确认」**，别写成已验证。
3. **`vendor/etc/sensors/sns_reg_config` 来源未实地 ls**（11-21 已标 TODO）：MR 里要么保留 TODO 注释（对上游不礼貌），要么**先跑 §3 的取证命令**再定 `partition = "vendor"` / `"odm"`。

其余（GPU `qcom/sm8750/gen80000_*`、触屏 `novatek_ts_csot_3k_fw.bin`、功放 `awinic/y700-gen4-speakers.bin` ← `aw882xx_acf.bin` 改名、BT `qca/brh*20.*` + `tmel_peach_20.elf`、传感器树绝对路径）证据都在 11-21 草稿的逐条判据里，可直接用。

**diff 草案**（以 11-21 草稿为基线，只列要改的 hunk）：

```diff
--- /dev/null
+++ b/configs/lenovo,elden.toml
+[juicer]
+dynpart = "super"
+firmware = [
+    # ADSP / CDSP are deliberately NOT listed here: their DT firmware names are
+    # the split "qcom/sm8750/{adsp,cdsp}.mdt" + "*_dtb.mdt" form, because a
+    # single-file *_dtb.mbn is rejected by the secure world on this board.
+    # droid-juicer only ever produces a squashed single .mbn for .mdt inputs,
+    # so these blobs are shipped by the board firmware package instead.
+    { partition = "vendor", origin = "firmware", destination = "qcom/sm8750", files = [
+            { name = "gen80000_zap.mbn" },
+            { name = "gen80000_gmu.bin" },
+            { name = "gen80000_sqe.fw" },
+            { name = "gen80000_aqe.fw" },
+        ] },
+    { partition = "vendor", origin = "firmware", destination = ".", files = [
+            { name = "novatek_ts_csot_3k_fw.bin" },
+        ] },
+    { partition = "vendor", origin = "firmware", destination = "awinic", files = [
+            { name = "aw882xx_acf.bin", rename = "y700-gen4-speakers.bin" },
+        ] },
+    { partition = "modem", origin = "image/peach", destination = "ath12k/PEACH/hw2.0", files = [
+            { name = "amss20.bin", rename = "amss.bin" },
+            { name = "aux_ucode20.elf", rename = "aux_ucode.bin" },
+            { name = "phy_ucode20.elf", rename = "m3.bin" },
+            { name = "bdwlan.elf", rename = "board.bin" },
+            { name = "qdss_trace_config_v2.cfg", rename = "qdss_trace_config.bin" },
+            { name = "regdb.bin" },
+        ] },
+    { partition = "modem", origin = "image", destination = "ath12k/PEACH/hw2.0", files = [
+            { name = "tmel_peach_20.elf", rename = "tmel.bin" },
+        ] },
+    { partition = "bluetooth", origin = "image", destination = "qca", files = [
+            { name = "brhbtfw20.tlv" },
+            { name = "brhbtnv20.bin" },
+            { name = "brhperifw20.tlv" },
+            { name = "brhperinv20.bin" },
+        ] },
+    { partition = "modem", origin = "image", destination = "qca", files = [
+            { name = "tmel_peach_20.elf" },
+        ] },
+    { partition = "vendor", origin = "etc/sensors", destination = "/usr/share/qcom/sm8750/LENOVO/TB322FC/sensors", files = [
+            { name = "sns_reg_config", rename = "sns_reg.conf" },
+        ] },
+]
+folders = [
+    { partition = "vendor", destination = "/usr/share/qcom/sm8750/LENOVO/TB322FC/sensors", folders = [
+            { name = "etc/sensors/config" },
+        ] },
+    { partition = "persist", destination = "/usr/share/qcom/sm8750/LENOVO/TB322FC/sensors", folders = [
+            { name = "sensors/registry/registry" },
+        ] },
+]
+# Not covered here on purpose (self-authored / derived assets, not vendor
+# extractable): awinic/y700-gen4-haptic.bin, ath12k/PEACH/hw2.0/board-2.bin
# (concatenation of bdwlan.e01..e41), qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin.
```

### 2.3 提交前本机取证命令（把 §2.2 的三个 TODO 一次性判掉）

> 全部是主机侧；其中 `ls /dev/mapper` 一条需要设备（列在「需上机」里，不阻塞主机侧其余判据）。

```bash
cd /home/xuqianhui/y700-elden
# 1) compatible（判文件名）—— 从在机 boot.img 里抽 FDT 再反编译（本轮实跑 rc=0）
python3 - <<'EOF'
d=open('out/boot-elden-vk192.img','rb').read()
i=d.find(b'\xd0\x0d\xfe\xed')          # FDT magic，实测在 0x51b1000
open('/tmp/vk192b.dtb','wb').write(d[i:])
print('fdt at', hex(i))
EOF
dtc -I dtb -O dts /tmp/vk192b.dtb > /tmp/vk192b.dts 2>/tmp/dtc.err; echo rc=$?
grep -n 'compatible = "lenovo,elden"' /tmp/vk192b.dts
# 2) boot.img 头（判 bootimg 段，已实测：kernel 0x8000 / ramdisk 0x1000000 / tags 0x100 / pagesize 0x1000 / v2 / dtb_size 0）
python3 - <<'EOF'
import struct
d=open('out/boot-elden-vk192.img','rb').read(0x100)
print(d[:8], [hex(x) for x in struct.unpack('<10I', d[8:48])], 'dtb_size', struct.unpack('<I', d[48:52])[0])
EOF
# 3) 固件实际名字（判 files/rename；对照在机 DTB 与 vendor 目录）
grep -n 'firmware-name' /tmp/vk192b.dts
ls -l backup/fw/modem/image/ backup/fw/modem/image/peach/ backup/fw/bluetooth/ | head -40
# 4) 分区实名（判 partition 基名）
cat backup/fw/README.md; ls backup/fw/tb322fc-edl/ | head
# 5) 本地 23 条源文件命中复核（11-21 已有脚本，复跑即可）
python3 - <<'EOF'
import tomllib,pathlib
c=tomllib.load(open('patches/distro/mobian-20261121/droid-juicer/lenovo,elden.toml','rb'))['juicer']
print('firmware entries', len(c['firmware']), 'folders', len(c.get('folders',[])))
EOF
```

**需上机（本轮禁止，登记为后续）**：

```sh
ls /dev/disk/by-partlabel | grep -E '^(modem|bluetooth|persist|super)(_a|_b)?$'
sudo make-dynpart-mappings /dev/disk/by-partlabel/super
ls /dev/mapper/vendor_a/etc/sensors/ /dev/mapper/odm_a/etc/sensors/    # 判 sns_reg_config 在 vendor 还是 odm
dmesg | grep -iE 'ath12k|PEACH|request_firmware|Direct firmware load'
```

### 2.4 提交前自检清单（MR 描述里逐条贴结果）

| # | 检查 | 判据 |
|---|---|---|
| 1 | TOML 可解析 | `python3 -c "import tomllib;tomllib.load(open('configs/lenovo,elden.toml','rb'))"` rc=0 |
| 2 | 只含 `[juicer]` 一个表 + 合法键（`dynpart/firmware/folders/partdump`） | `src/firmware.rs:81-87` 逐字段对照 |
| 3 | 每个 `partition` 都是本机 `/dev/disk/by-partlabel` 实名的**基名** | 设备侧 `ls /dev/disk/by-partlabel` |
| 4 | 每个 `files[].name` 在源分区里真实存在 | `backup/fw/**` 现查 + 设备侧 `ls` |
| 5 | `destination` 与 DT `firmware-name` / 驱动硬编码路径逐字一致 | 在机 DTB `firmware-name` + `btqca` 的 `qca/` 前缀 |
| 6 | 没有把自编资产伪装成「抽取」 | 三条明写在注释里（haptic/board-2/tplg） |
| 7 | 没有超过 1 个 device 的改动 | `git diff --stat` 只有 1 个新文件 |
| 8 | **config 里没有任何 `.mdt` 条目**（否则产出会被 TZ 拒的单文件 `.mbn`） | `grep -c '\.mdt' configs/lenovo,elden.toml` = 0 |
| 9 | 描述里写清「未上机验证」+「ADSP/CDSP split 固件走 board firmware 包」 | MR 描述 |

### 2.5 被拒时的备选（按可能性排序）

| 可能的拒绝理由 | 备选 |
|---|---|
| 「先让 board DTS 进树，否则固件路径无意义」 | 把 config 改成只覆盖**不依赖板 DTS 名字**的部分（`qca/`、`awinic/`、触屏根目录件、传感器树），ADSP/CDSP/GPU 那三条留给后续 MR；同时推 elden DTS v8（`reports/mainline-upstream-audit-20261122.md` §3） |
| 「don't add untested device configs」（有 `!2`/`!22` 长期挂 Draft 的先例） | 走「先合 recipes 侧、等我们自己出过一次 Mobian 镜像再回填 droid-juicer」的顺序；或用 Draft MR 挂 issue 说明进度 |
| 「ath12k 路径不对 / 不该硬编码 PEACH」 | 掉落 ath12k 两条，WiFi 走我们自己的固件包（ath12k bdf 本来就是发行版常客） |
| 「传感器的绝对路径绑定 hexagonrpcd 实现」 | 掉落 `folders` 两条，只保留 `/lib/firmware` 部分（sensors 在 Mobian 上目前没有打包先例） |
| 干脆不收 | 退到 **recipes-only**：`devices/qcom/droid-juicer/lenovo,elden.toml`（同一份内容），Mobian 自己的 wip 流程能用；社区其他人（Nura 不可投，但 Redroid/自建镜像可用）仍可复用 |

---

## §3 MR-2（第二阶段，与内核分支同批）：mobian-recipes `wip.toml` + droid-juicer 副本

### 3.1 三处改动（一次 MR，缺一不可）

| # | 文件 | 内容 | 为什么必须同批 |
|---|---|---|---|
| 1 | `devices/qcom/configs/wip.toml` | 追加一个 `[[device]]` 段（见下） | 不给条目，`-t qcom-wip` 不知道该造什么 dtb |
| 2 | `devices/qcom/droid-juicer/lenovo,elden.toml` | MR-1 的同一份文件 | `packages-base.yaml:35-37` 只从这个目录覆盖 |
| 3 | `devices/qcom/packages/*.deb` | 至少 `linux-image-<ver>-sm8750`（我方 7.4 分支 + Debian packaging）；可选 `elden-firmware`（board-2/haptic/tplg） | wip 路线不带 `-support` 包，**没有内核 deb 就建不出可启镜像** |

### 3.2 `wip.toml` 追加片段（可直接粘）

```toml
[[device]]
vendor = "lenovo"
model = "elden"
# top-level `chipset` is empty in this file and jq treats "" as truthy, so the
# per-device value is mandatory here (bootloader.sh:46,54).
chipset = "sm8750"
```

`[bootimg]` **不要动**（`wip.toml` 的 `[bootimg]` 是全局默认；`sm7150.toml`/`sdm670.toml` 的实测值与之一致：`base 0 kernel 0x8000 ramdisk 0x1000000 second 0 tags 0x100 pagesize 4096`）。也不要在 `[[device]]` 里写 `bootimg = {...}` 覆盖——我们与全局默认**逐字段相同**（`out/boot-elden-vk192.img` 头实测，见 §2.3）。

`append` 不写：`mobile.root=` / `mobile.qcomsoc=` / `init=` 由 `bootloader.sh:59,90-92` 拼；本机特有的 `elden_root=LABEL=linux17`、`androidboot.slot_suffix=_b` 是**本机分区布局产物**，不进上游 recipes。

```diff
--- a/devices/qcom/configs/wip.toml
+++ b/devices/qcom/configs/wip.toml
@@ -33,3 +33,9 @@
 [[device]]
 vendor = ""
 model = ""
+
+# Lenovo Legion Y700 Gen4 (TB322FC), SM8750
+[[device]]
+vendor = "lenovo"
+model = "elden"
+chipset = "sm8750"
```

### 3.3 为什么不能拆成「先把 wip.toml 合了再说」

- `build.sh` 对 `qcom-wip` 一定会跑 `bootloader.sh`，后者要 `linux-version list` 有内核 + `/usr/lib/linux-image-<ver>/qcom/sm8750-lenovo-elden.dtb` 存在（`bootloader.sh:52,66`）。
- CI：改 `devices/qcom/*` 会触发 qcom 设备 job（`.gitlab-ci/devices.yml:1-11`），**提交即红**，reviewer 会当成没测过。
- ⇒ 结论：MR-2 的前置是内核分支（`wip/<user>/7.4-sm8750`，抄 `wip/tiol/7.4-sdm845` 的形状 + cherry-pick qcom-linux 的「Add Debian packaging」提交 `28d219039c63`），**这是第二阶段的真正工作量，不属「不碰内核」范围**。

### 3.4 如果将来要做「一等公民」（`-t sm8750`）还差什么

| 缺口 | 位置 | 备注 |
|---|---|---|
| `build.sh` 白名单加 `sm8750` | `build.sh:88-94` | 一行 |
| `devices/qcom/configs/sm8750.toml` | 新建（内容 = wip.toml 里那段） | 文件名即 chipset，不写 `chipset` 行（`sm7150.toml` 无此行） |
| `sm8750-support` 元包 | `Mobian-team/devices/qcom-support` `debian/control` | 依赖 `linux-image-<ver>-sm8750` + `qcom-support-common`；可同时把 `wip` 的「手动 deb」债清掉 |
| 板 DTS 进 mainline | `reports/mainline-upstream-audit-20261122.md` M3-DTS 行 | 否则 dtb 只能来自我们的分支 |

---

## §4 已落盘件与状态

| 件 | 路径 | 状态 |
|---|---|---|
| droid-juicer 配置草稿（11-21） | `patches/distro/mobian-20261121/droid-juicer/lenovo,elden.toml` + `README.md` | ✅ 可作 MR-1 底稿；按 §2.2 三处改 |
| wip.toml 片段草稿（11-21） | `patches/distro/mobian-20261121/mobian-recipes/wip.toml.snippet` + `README.md` | ⚠ **需按本文 §3.2 改**：`chipset` 必须写在 `[[device]]` 里；`version`/`dtb`/`append` 三个 TODO 删除（已是确定结论） |
| 本文 | `reports/mobian-mr-plan-20261122.md` | 本轮产出 |

---

## §下一步可执行清单（带代价/判据）

| 顺序 | 动作 | 代价 | 判据（做完怎么知道对） |
|---|---|---|---|
| 1 | 按 §2.2 改 `lenovo,elden.toml`（**删 ADSP/CDSP 条目**；ath12k 路径标「待 dmesg 确认」） | 30 min 主机 | TOML 解析 rc=0；`grep -c '\.mdt'` = 0；每个 destination 都能对上一个 DT `firmware-name` 或驱动硬编码路径 |
| 2 | 跑 §2.3 的 1)–4) 取证，把三个 TODO 判成事实（ath12k 路径 / sns_reg_config 来源 / 分区基名） | 1 h 主机 | 每条 TODO 变成一行「命令 + 输出」；仍判不掉的写成 MR 描述里的显式问题 |
| 3 | 在本地 fork（**需用户授权建 fork，本轮禁止**）提交 MR-1，描述含 §2.4 九条自检 + 「未上机」+「split 固件走 board 包」 | 1 封 MR | 维护者回「LGTM」或提出具体缺口；CI 绿（只有 fmt/clippy/test） |
| 4 | 与 MR-1 并行：准备 elden DTS v8（2 枚：`qcom.yaml` + v7 原文）投递（证据已在 `patches/upstream/elden-dts-v8-prep-20261121/`） | 1 封邮件 | patchwork 出现 v8 且 `14991580` 转 superseded |
| 5 | 内核分支（第二阶段，属 B 部分主线工作）：`wip/<user>/7.4-sm8750` = 7.4-rc3 + 我们的 payload + `debian/`（cherry-pick `28d219039c63`） | 3–6 人日 | `debian/rules build` 出 `linux-image-*-sm8750`；`linux-version list` 见到；dtb 落在 `/usr/lib/linux-image-*/qcom/` |
| 6 | MR-2（wip.toml + droid-juicer 副本 + `packages/*.deb`） | 1 封 MR + 上面的内核件 | `./build.sh -t qcom-wip -s` 出镜像；`dmesg` 里 `Direct firmware load … failed` = 0 |
| 7 | 需要问上游的一句（写在 MR-2 描述里）：「Debian 打包分支描述写着 'until droid-juicer supports upstream kernels again' ⇒ 主线内核设备当前有什么限制？」 | 1 句话 | 拿到明确回答或指向 issue |

**不做（明确划掉）**：6.18 LTS 重基（`reports/mobian-upstream-firstpr-20261121.md` §1 已证不可落）；Nura/pmaports（AI 政策红线）；UBports（Halium 与 G1 相反）。
