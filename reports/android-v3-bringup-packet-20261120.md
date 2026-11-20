# 安卓精简 v3 首启验证 —— 「上机执行包」（S1–S5，主机侧准备完成，设备零写操作）

- 日期：2026-11-20（lane L4，主机 `xuqianhui`；项目 `/home/xuqianhui/y700-elden`）
- 目标设备：U2 **HA2EXB0E**（TB322FC / elden），**当前离线**（见 §1.1）
- 机械化形态：**`scripts/android-v3-bringup-walkthrough.sh`**（默认 `--dry-run`；`--apply` 才动设备）
- 上一轮全账：`reports/android-slim-v3-20261119.md`（§7/§8）、`TASKS/sessions/2026-11-19-安卓共存契约与v3精简上机.md` §3
- 本轮只做主机侧：**没有对设备做任何写操作**（fastboot/qdl/adb 写/flash 全未执行）；只做了只读探测（`lsusb`/`fastboot devices`/`adb devices`/`ping`/`ssh`）

---

## 0. 一页结论（数字先）

| # | 结论 | 证据 |
|---|---|---|
| 1 | **设备当前离线**（未枚举）：`lsusb` 无 `05c6:9008`/`18d1:*`、无 `/dev/ttyACM*`、`fastboot devices` 空、`adb devices` 只有**别的手机** `MDX5T20730009849`、主机无 MAC `02:1e:5e:ed:e1:02` 的 cdc_ncm 网卡 ⇒ 非坏机，需人项（插线 + 上电） | `reports/artifacts/android-v3-bringup-20261120/device-online-check.txt` |
| 2 | **`ping 192.168.7.1` 是假阳性**：`ip route get` 显示经手机热点网关 `192.168.42.129 dev enx027644563e50`，`ip neigh` 只有网关 MAC ⇒ 那台 `192.168.7.1` **不是本机平板**；`ssh` 22 端口超时。**以后不许用 ping 判设备在线** | 同上 |
| 3 | **BCB 现态无法离线复核**：最后一次有记录的写入是 2026-11-19 21:4x Linux 侧 `dd` 清 0（报告 §8，commit `100cacb7`），但盘上只留下**更早**的两件：`diag/misc-bcb-after.bin` = 16384 B **全 0**（20:40）、`diag/misc-before-v1boot.bin` = `bootonce-bootloader`（21:37）⇒ **21:4x 那次清 0 没有落盘备份（备份在设备 `/tmp`，重启即失）**。⇒ S1 必须现场重读 + 重清 + 读回校验 | `bcb-and-qbootctl.txt`、`git show 100cacb7` |
| 4 | **super 现态 = v1** 属「上一轮实测 + 之后无写」的推断（不是本轮实测）：11-19 21:3x 回刷 v1 后读回 `e3d0d26f…`，此后只发生 Linux 重启；本轮无法连设备 ⇒ **未复核**（S1 第一步即复核：读首 512 KiB → `android-super.py list` 应报 `system_a 5296 MiB`） | `reports/android-slim-v3-20261119.md` §8、本轮 S1 计划 |
| 5 | **上机件全部在位**（7 件 + 原厂 16 分片），sha 全部与登记一致（**O_DIRECT 口径**）；本轮**新造 1 件**：`out/android-v3-bringup-20261120/metadata_stock.img` = 29 372 416 B（28.01 MiB，`a735fbc7…`） | `pieces-inventory.txt`、`scripts/…walkthrough.sh --verify` 全 OK |
| 6 | ~~**1 件缺件**：S5 的 `console=ttyGS0` boot 件造不出来（原厂 `boot.img` = header v4，脚本只支持 v2）~~ → **2026-11-20 已解锁**：`scripts/boot-img-cmdline.py` 支持 v3/v4（等长原改 cmdline 窗口），件已造 `out/android-v3-bringup-20261120/boot-ttygs0-boot.img`（100663296 B，O_DIRECT `0dad04f1…`），全文件只差 `[44,57]` 14 B；**`fastboot` 是否认 = 需上机项**（AVB hash 失配 + vendor_boot cmdline 优先级） | `reports/bootimg-v4-cmdline-20261120.md` |
| 7 | **原厂 super/metadata 都是 8 分片**（`rawprogram_save_persist_unsparse0.xml`）：super 拼装后 15 607 586 816 B（**14.54 GiB**，3810446 扇区）；metadata 拼装后 **29 372 416 B**（7171 扇区）。已用 `scripts/android-super.py assemble` 复用现有封装，不新写刷写逻辑 | `gpt0-geometry.txt`、S2/S3 段 |
| 8 | **两处旧计划的技术错误已修**：① `qbootctl -a` 是**只读查询**（`get the active slot`），不是「设为 active」（设置 = `-s SLOT`）；② `metadata` 分区起点是 **5857704**，不是 5857672（后者是 `vbmeta_system_a`） | `bcb-and-qbootctl.txt`（strings 原文）、`gpt0-geometry.txt` |
| 9 | **新的硬门必须用 O_DIRECT**：本机页缓存污染使同一文件 buffered 连读 5 次**稳定但错**（v1 件读成 `637a9965…`，O_DIRECT = `e3d0d26f…` 正确）⇒ 旧「双 sha256 硬门」抓不到。已按硬规则 12 取证上交 `~/hw-stability/evidence/inbox/20261120-y700-elden-pagecache-sha-drift/` | `superdbg-sha-drift.txt` |

---

## 1. 现态核对（本轮实测 vs 记载）

### 1.1 设备在线判定（判据 = 不看 ping）

```sh
$ lsusb -d 05c6: ; lsusb -d 18d1: ; ls /dev/ttyACM*
（三者皆空；/dev/ttyACM*: No such file or directory）
$ timeout 10 fastboot devices        # 空
$ timeout 10 adb devices             # 只有 MDX5T20730009849（另一台手机，禁写）
$ for i in /sys/class/net/*/; do …   # eno1 / enx027644563e50 / lo / tailscale0
（无 MAC 02:1e:5e:ed:e1:02 ⇒ 设备 USB-NCM gadget 没枚举）
$ ip route get 192.168.7.1
192.168.7.1 via 192.168.42.129 dev enx027644563e50 src 192.168.42.97 uid 1000
$ timeout 20 ssh -o BatchMode=yes root@192.168.7.1 true
ssh: connect to host 192.168.7.1 port 22: Connection timed out
```

**判定：offline**（`DEVICE/README.md` §1.6 口径：未连接/未上电，不是坏机）。
⇒ **S1 的 Linux 侧动作与所有上机动作都需要人项**：插 USB + 上电（必要时按电源键）→ `sudo scripts/ncm-host-up.sh`。

### 1.2 BCB（`misc`）——「git 有记载」≠「盘上有证据」

| 证据 | 值 | 时点 |
|---|---|---|
| `out/android-slim-v3-20261119/diag/misc-bcb-after.bin`（16 KiB） | **nonzero=0（全 0）** | 11-19 20:40（EDL 清 0 后读回） |
| `out/android-slim-v3-20261119/diag/misc-before-v1boot.bin`（16 KiB） | `bootonce-bootloader` | 11-19 21:37（v1 上机前） |
| `reports/android-slim-v3-20261119.md` §8（commit `100cacb7`） | 「从 Linux 侧 `dd if=/dev/zero … bs=4096 count=1 conv=fsync`，读回 32 B 全 0」 | 11-19 21:4x |
| 该次的备份 | **设备 `/tmp/misc.bcb.bak`（重启即失）** ⇒ 主机无件 | — |

⇒ 结论：**BCB 绝大多数可能是 0，但没有主机侧可复核的当次证据**。S1 的第一步就是重读、重清、读回全 0（**reset 前的最后一步**）。

### 1.3 super 现态

- 记载（11-19 21:4x，Linux 侧读首 512 KiB + `scripts/android-super.py list`）：`system_a 5296 MiB`、7 个 `_a` 分区、metadata 校验 OK ⇒ **v1**（读回 sha `e3d0d26f…`）。
- 主机侧件 `out/android-min-20261118/pkg/super_min.img` = 8 893 497 344 B / `e3d0d26f…`（O_DIRECT 复核一致）。
- 本轮**未复核设备侧**（离线）。S1 用同一手法复核，判据写死：`system_a` 5296 MiB ⇒ v1 在机；3920 MiB ⇒ v3 在机（若已是 v3，则 S1 的前置要改写）。

### 1.4 槽位（Android 首启的前提，旧计划漏了）

ABL 只启 **active** 槽；本机 **a 槽 = Android、b 槽 = Linux**，而 11-19 21:4x 用户已切回 Linux（b）。
⇒ **S1 之前必须让 active = a**，否则 reset 只会再进 Linux（本脚本 `ensure_active_a()` 机械化，写 = `fastboot --set-active=a`，可回退 `--set-active=b`；**super/GPT 不动**）。

`qbootctl` 用法原文（`strings /opt/elden/mobian-rootfs/usr/bin/qbootctl`）：

```
    <no args>        dump slot info (default)
    -a               get the active slot          ← 只读查询（不是设置！）
    -s SLOT          set to active slot to SLOT   ← 真要设置用这条（走 BSG，本仓不用）
    -m [SLOT]        mark a boot as successful
    -u [SLOT]        mark SLOT as unbootable
    -n SLOT          check if SLOT is marked as successful
    -b SLOT          check if SLOT is marked as bootable
```

---

## 2. 主机侧「件」清单（sha256 = `dd iflag=direct | sha256sum`）

| 件 | 字节 | sha256 | 角色 |
|---|---|---|---|
| `out/android-min-20261118/pkg/super_min.img`（v1） | 8 893 497 344 | `e3d0d26fb3a6f97ec10e4533ea2d675a9693acb42bb10ddb9dd4cb897517e13c` | S1 在机 / 回退基线（2171264 扇区） |
| `out/android-slim-v3-20261119/new/super_min_v3.img`（v3） | 7 454 326 784 | `51eae1075fe159b02946a4e4e5548fa83bb5e861fb441244ac8dddc423bc6440` | 本轮主线件（1819904 扇区） |
| `out/android-slim-v3-20261119/new/super_dbg.img`（v3+adb 免授权） | 7 454 326 784 | `8b42f20dd8cc2205489c26c6f75ee9ec8ef5659aa3fdb41662cdf3b5ebf11085` | 取 logcat 备件 |
| `out/android-slim-v2b-20261119/new/super_min_v3.img`（v2b） | 9 165 602 816 | `98a88ea0aa82283822034d823751a3f3ef30aa44fba723516f6d26abb95adbfc` | **S4 二分件**（2237696 扇区；`system_a 5552 MiB`） |
| `out/android-v3-bringup-20261120/metadata_stock.img`（**本轮新造**） | 29 372 416 | `a735fbc74abf0d9695a1fc598128acc78184abc710224719825bbe16fca4722e` | S2 件（7171 扇区 @5857704） |
| `backup/official-rom-15.10.259/boot.img`（原厂 a 槽内核） | 100 663 296 | `b428a31dadc5db3f91620c1f4114f5ee7702e34e0789ed9bf84a878a49898f20` | a 槽启动链基线（**header v4**） |
| `out/boot-elden-vk192.img`（Linux b 槽） | 85 815 296 | `bdf47f5f3f8a49e8e1fd77557c10640dec8e00c76e46bd731503e162bbdb841b` | Linux 侧复原件（不在本轮写路径上） |

原厂分片（`backup/official-rom-15.10.259/`，**只读引用，不动原件**）：

- super 1..8：405 504 / 1 650 688 / 1 041 178 624 / 12 266 729 472 / 12 533 760 / 598 352 352 / 1 536 172 032 / 147 382 272 B
  （sha 逐片见 `pieces-inventory.txt`；拼装 = 3810446 扇区 / 14.54 GiB）
- metadata 1..8：8 192 / 32 768 / 10 539 008 / 16 384 / 24 576 / 28 672 / 8 192 / 12 288 B
  （拼装 = 28.01 MiB；**已实际拼装并在位**）

几何（LUN0 主表现读，`gpt0-geometry.txt`）：

```
super        90504..5857671   5767168 扇区 = 22.000 GiB
metadata     5857704..5874087   16384 扇区 =  0.062 GiB（64 MiB）
misc         89992..90247         256 扇区
userdata     5972392..73277434
linux17      73277435..123871226  193.000 GiB
```

---

## 3. 缺件与重建命令

| 件 | 状态 | 重建命令 |
|---|---|---|
| `metadata_stock.img` | ✅ 本轮已造 | `python3 scripts/android-super.py assemble --xml backup/official-rom-15.10.259/rawprogram_save_persist_unsparse0.xml --label metadata -o out/android-v3-bringup-20261120/metadata_stock.img` |
| `super_stock_contig.img`（14.54 GiB，稀疏落盘 ~12.2 GiB） | ⬜ 缺件（S3 时按需现造，工作区余 169 G） | `python3 scripts/android-super.py assemble --xml <同一 xml> --label super -o out/android-v3-bringup-20261120/super_stock_contig.img`（期望 15 607 586 816 B） |
| `boot-ttygs0-boot.img`（S5；旧名 `boot_a_stock_ttygs0.img` 未用） | ✅ **2026-11-20 已造**（100663296 B，O_DIRECT `0dad04f1d2f41fc2126eb2bda045adec8c8dce3ad95535442e53369dfc0280af`；**仅 `fastboot boot`**） | ~~原厂 `boot.img` = header v4，脚本只支持 v2；路 A 扩脚本 v4（`header_size=1584`，cmdline @44 长 1536，等长原地替换）/ 路 B 改 `vendor_boot.img` 侧~~ → **路 A 已实施**：<br>`python3 scripts/boot-img-cmdline.py backup/official-rom-15.10.259/boot.img --append 'console=ttyGS0' -o out/android-v3-bringup-20261120/boot-ttygs0-boot.img`<br>细节、v2 回归、AVB 断言前后对照见 `reports/bootimg-v4-cmdline-20261120.md` |

---

## 4. S1–S5 上机执行包（逐步：命令 / 判据 / 失败判读 / 归档 / 时长）

> 所有步骤由 `scripts/android-v3-bringup-walkthrough.sh` 执行；下表 = 人读版。
> 通用纪律（脚本已机械化）：每条外部命令过 `timeout -k`；qdl 每条带 `-R`（=--skip-reset）+ 单独一发 `reset`；
> **reset 之前必须「清 BCB 4 KiB → 读回全 0」**；写前先读 live GPT 过 `android-linux-coexist-check.py`；
> 写后 = 设备端 `qdl sha256` + 读回 head/tail 各 16 MiB 逐字节（`--readback full` 可全量）。
> 每步归档：`logs/android-v3-<STEP>-<ts>/`（`commands.log`、`qdl.log`、`bcb-*.bin`、`observe.log`、`verdict.txt`、`logcat-all.log`、`pstore-grep.txt`）。

### S1 清 BCB + 置 active=a + v1 在机的首启观察（约 3–5 min）

```sh
sudo scripts/ncm-host-up.sh --check
ssh root@192.168.7.1 'uname -r; findmnt -no SOURCE,LABEL /'      # 判据：/ = LABEL=linux
ssh root@192.168.7.1 'qbootctl; qbootctl -a'                     # 判据：Active slot 行（只读）
ssh root@192.168.7.1 'dd if=/dev/disk/by-partlabel/super bs=4096 count=128' > super-head512k.bin
python3 scripts/android-super.py list super-head512k.bin         # 判据：system_a 5296 MiB ⇒ v1 在机
ssh root@192.168.7.1 'dd if=/dev/disk/by-partlabel/misc bs=4096 count=4' > bcb-before.bin   # 备份 + 判读
ssh root@192.168.7.1 'cp -f /dev/disk/by-partlabel/misc /tmp/misc.bcb.bak; \
     dd if=/dev/zero of=/dev/disk/by-partlabel/misc bs=4096 count=1 conv=fsync'
ssh root@192.168.7.1 'dd if=/dev/disk/by-partlabel/misc bs=4096 count=4' > bcb-after.bin      # 判据：nonzero==0
fastboot -s HA2EXB0E getvar current-slot ; fastboot -s HA2EXB0E --set-active=a              # 判据：current-slot: a
# 观察：adb -s HA2EXB0E（上限 600 s）→ 三条硬判据（§5）
```

- **预期判据**：`sys.boot_completed=1` 且 `mCurrentFocus` 含 launcher ⇒ **之前 3 发失败很可能全是 BCB 污染**（对照：同一 v1 件在**旧 /data** 上曾两发 `sys.boot_completed=1`，出处 `reports/android-slim-v2-20261119.md` H1 行/§回退行）。
- **失败判读**（BCB confound vs 真失败）：
  - 落 **recovery** ⇒ **先读 `misc`**：BCB 非 0 = **confound，本次样本作废**（不是 Android 失败）；BCB 全 0 仍进 recovery = 真失败（走 S2）。
  - **卡 ZUXOS 动画不完成**（`boot_completed≠1` 且 adb 在）= 复现「system_server 段卡死」的真样本 ⇒ 抓 `logcat -d -b all` + `ls /data/system/preinstallapk`，继续 S2。
  - **卡 logo 后掉电/无 adb** = 早失败；读 `pstoredump`（grep `panic|oops` 命中 0 ⇒ userspace；≥1 ⇒ 内核段真失败）。
  - **落回 Linux（b 槽）** = 本次根本没启 Android（active 槽/BCB 问题），样本作废。
- 时长：3–5 min（不含观察 10 min 上限）。

### S2 回写原厂 metadata（约 5–8 min）

```sh
# 件：out/android-v3-bringup-20261120/metadata_stock.img（29372416 B, a735fbc7…）
# 进 EDL：fastboot -s HA2EXB0E oem edl（Android 侧 adb reboot edl；Linux 侧先 systemctl reboot bootloader）
qdl -s ufs -R $LOADER read 0/0+6 live-gpt0-primary.bin            # 写前门
python3 scripts/android-linux-coexist-check.py --gpt live-gpt0-primary.bin
qdl -s ufs -R $LOADER read 0/5857704+7171 metadata-pre.bin         # 回退基线
qdl -s ufs -R $LOADER write 0/5857704 metadata_stock.img sha256 0/5857704+7171 \
                       read 0/5857704+4096 head16m.bin read 0/5860779+4096 tail16m.bin
qdl -s ufs -R $LOADER write 0/89992 zero4k.bin read 0/89992+1 bcb-after.bin   # 清 BCB + 读回
qdl -s ufs $LOADER reset
```

- **预期判据**：设备端 sha256 = 主机 `a735fbc7…`；head/tail 逐字节一致；BCB 读回 nonzero=0；reset 后进 §5 判据。
- **失败判读**：`qdl` 报 `SAHARA: failed to read request` ⇒ 上一条 qdl 没带 `-R`（#674/#675，不是件坏）；sha 不符 ⇒ 先 `hw-heal`/`pcache-wash` 再复测（页缓存口径，§0-9），不要急着重刷。
- 时长：5–8 min（写 28 MiB ≈ 1 s + 读回 + 启动观察）。

### S3 原厂 super 对照（约 14–18 min）

```sh
python3 scripts/android-super.py assemble --xml $ROM/rawprogram_save_persist_unsparse0.xml \
        --label super -o out/android-v3-bringup-20261120/super_stock_contig.img   # 15607586816 B
qdl -s ufs -R $LOADER read 0/90504+128 super-head512k-pre.bin
qdl -s ufs -R $LOADER write 0/90504 super_stock_contig.img sha256 0/90504+3810446 \
                       read 0/90504+4096 head16m.bin read 0/3896854+4096 tail16m.bin
qdl -s ufs -R $LOADER write 0/89992 zero4k.bin read 0/89992+1 bcb-after.bin
qdl -s ufs $LOADER reset
```

- **预期判据**：设备端 sha256 = 主机；**原厂能进桌面 ⇒ 问题在我们的 super 内容**；原厂也不进 ⇒ 问题在 `/data`/GPT/设备态（先把 `userdata` 现态、BCB、active 槽三件排除干净）。
- **失败判读**：`reset` 后卡 logo（无 adb）且 BCB=0 且 pstoredump 无 panic ⇒ 原厂 super 也失败 ⇒ **不是 v3 内容问题**，转「设备态」分支；卡 recovery ⇒ 先看 BCB（若 ABL 自己写回 `boot-recovery`，说明 `boot_a`/recovery 链在起作用 = 另一类 confound）。
- 时长：14–18 min（写 14.54 GiB @~42 MiB/s ≈ 6 min + 读回/校验 + 观察）。
- 回退：`qdl write 0/90504 out/android-min-20261118/pkg/super_min.img`（v1，2171264 扇区）。

### S4 二分 v2b（约 8–10 min）

```sh
qdl -s ufs -R $LOADER write 0/90504 out/android-slim-v2b-20261119/new/super_min_v3.img \
        sha256 0/90504+2237696 read 0/90504+4096 head16m.bin read 0/2324104+4096 tail16m.bin
# 同样：清 BCB 读回 → qdl reset → 观察
```

- **预期判据**：v2b（池/AI/bgmusic 删、18 个 leaf 包留）**进桌面 ⇒ 18 个 leaf 包不是原因**，继续在「池删除/空目录占位」面二分；v2b 也卡 ⇒ 我们镜像侧的裁剪本身不是主因，优先跑 S2/S3。
- **失败判读**：同 S2/S3（BCB 先排除；`verdict.txt` 会写 `RECOVERY`/`EARLY_FAIL`/`FELL_BACK_LINUX`/`TIMEOUT`）。
- 时长：8–10 min。

### S5 日志通道（`console=ttyGS0`）——件已造（2026-11-20），**能否被 bootloader 接受 = 需上机项**

- 件在：`out/android-v3-bringup-20261120/boot-ttygs0-boot.img`（100663296 B，与原件同大小，全文件仅差 `[44,57]` 14 B；
  `scripts/boot-img-cmdline.py` 现已支持 header v3/v4；验收/回归/AVB 证据见 `reports/bootimg-v4-cmdline-20261120.md`）。
  缺件时 S5 会打印「S5 不可用（缺件）」并给造件命令（不再静默跳过）。
- 上机方式：`fastboot -s HA2EXB0E boot out/android-v3-bringup-20261120/boot-ttygs0-boot.img`（**零写盘**）；
  抓取：主机 `timeout -k 5 900 cat /dev/ttyACM0 > serial.log`（或设备侧 `scripts/install-serial-logger.sh`）。
- 判据：串口出现内核/init 输出；拿不到就退回 **pstoredump** 通道（本脚本 `pstore_triage`：`grep -acE "panic|oops|Unable to handle"`，命中 0 ⇒ userspace 卡死）。
- 时长：造件 10 min（一次投资）+ 每发 3–5 min。

---

## 5. 首启成功「三条硬判据」（缺一不算成功）

| # | 判据 | 命令 | 反例 |
|---|---|---|---|
| 1 | `sys.boot_completed = 1` | `adb -s HA2EXB0E shell getprop sys.boot_completed` | `0`/空 ⇒ system_server 未完成（11-19 首发的形态） |
| 2 | launcher 拿到焦点 | `adb -s HA2EXB0E shell 'dumpsys window \| grep -m2 -E "mCurrentFocus\|EnableScreen"'` | 焦点停在 `bootanimation`/`SystemUI` 启动页 |
| 3 | **无 recovery 循环** | `adb devices` 状态从不为 `recovery`；且连续两次复位都进同一处不算 | 落 `recovery` ⇒ 先读 `misc` 判 BCB confound |

辅助判据（同一批归档）：`pm list packages | wc -l`（v3 应明显少于 279）、
`ls -l /data/system/preinstallapk /data/system/waitpreinstallapp`、`logcat -d -b all`（唯一能分开 H1/H2 的输入）、
`pstoredump` grep（内核段 vs userspace 段）。

**判读决策树**（每步 reset 后）：

```
adb 在 + boot_completed=1 + launcher      → SUCCESS（写结论前先查 misc 是否被 ABL 改写）
adb 在 + boot_completed≠1                 → 卡动画（真样本）→ logcat + /data 检查
adb=recovery                              → 读 misc：非 0 ⇒ 样本作废（confound）；全 0 ⇒ 真失败
adb 从不出现（600 s）                      → 读 misc（同前）+ pstoredump：panic 有 ⇒ 内核段；无 ⇒ userspace/早失败
落到 b 槽 Linux                            → 本次没启 Android（active 槽/BCB）⇒ 修前提重来
```

---

## 6. 纪律门（脚本里已机械化，人工执行时也别漏）

1. **BCB 是最后一步**：`清 0 → 读回 nonzero==0 → 才 reset`；任何「起不来」样本，**先读 misc 再下结论**（11-19 三发里 2 发因此降级为无效样本）。
2. **qdl 每条 `-R`**，reset 单独一发；不加 `-f/--allow-missing`（会把缺件变成静默跳过，PITFALLS #669）。
3. **写前 live-GPT 门**：读 LUN0 LBA0..5 → `android-linux-coexist-check.py` + `super/metadata` 起始与容量核对（`super 90504+5767168` / `metadata 5857704+16384`）。
4. **写后双尺子**：设备端 `qdl sha256` + 读回 head/tail 逐字节；不一致先怀疑主机读路径（O_DIRECT / `pcache-wash`），再怀疑设备。
5. **主机件 sha 一律 O_DIRECT**（`dd iflag=direct | sha256sum`）：「连读两次一致」在本机不成立（§0-9）。
6. **设备锁 + 串行**：`scripts/lib-device-lock.sh`（`--apply` 时会取锁）；同一时刻只有一条安卓线在写。
7. **只认显式序列号**：`adb` 侧永不猜（本机总线上确实挂着别人的 `MDX5T20730009849`）；`qdl` 不认 serial ⇒ 已在 9008 时必须显式确认归属。
8. **不碰**：`backup/`（官方原件）、`out/android-slim-v3-20261119/new/`（只读引用）、`bootslot-b/`、`linux17`、`boot_b`、`vbmeta*`。

---

## 7. 本轮未做（需人项 / 明确不做）

1. **任何设备写操作**：`--apply` 未执行（qdl/fastboot/adb 写全未跑）。本轮只跑 `--dry-run` 与 `--verify` 自检。
2. **S5 造件**：缺 v4 改写器（不在本职范围，见 §3）。
3. **stock super 拼装**：14.54 GiB 稀疏件（实际 ~12.2 GiB）留到 S3 `--apply` 现造，避免现在白占磁盘。
4. **需人项**：设备上电 + 插线（S1 起全部依赖）；必要时按电源键；物理键操作与断电由人执行。

---

## 8. 与旧计划（`TASKS/README.md` §4 / 报告 §7）的差异（本轮更正）

| 项 | 旧说法 | 本轮更正 | 依据 |
|---|---|---|---|
| S1 的槽位前提 | 「清 BCB 后 `qbootctl -a` + `reboot`」 | **`qbootctl -a` 是只读查询**；要启 Android 必须先把 **active 槽置 a**（`fastboot --set-active=a`），否则 reset 只回 b 槽 Linux | `qbootctl` strings 原文 |
| metadata 几何 | 报告 §1.1 把 `metadata` 归在 `5857672..5972391` | `metadata` 分区 = **5857704..5874087**（64 MiB）；**5857672 是 `vbmeta_system_a`**；原厂件从 5857704 起 7171 扇区 | `gpt0-geometry.txt` |
| 原厂 super/metadata 的写法 | 「回写原厂 metadata.img（29 MB）」「刷原厂 super（8 段）」 | 都是**分片**，本仓现有封装 = `scripts/android-super.py assemble`；拼装后单发 `qdl write`（与上一轮 super 写法一致） | `rawprogram_save_persist_unsparse0.xml` |
| S5 可行性 | 「造带 `console=ttyGS0` 的 boot 件」 | ~~造不出（原厂 boot.img = header v4，脚本只支持 v2）~~ → **已造出**（2026-11-20）；剩「fastboot 是否认」= 需上机项（AVB hash 失配 / vendor_boot cmdline 优先级） | `reports/bootimg-v4-cmdline-20261120.md` |
| 主件校验口径 | 「两次独立 `sha256sum` 必须一致」 | 不够：**buffered 读会命中同一份被污染的页缓存**；必须 O_DIRECT/先 wash | `superdbg-sha-drift.txt` |
| 设备在线判据 | （历史上有 `ping` 通就以为在线） | **ping 会假阳性**（经手机热点路由到别处）；判据 = `lsusb 05c6:9008/18d1`、gadget MAC、`fastboot/adb` 序列号、`ssh` | `device-online-check.txt` |

---

## 9. 落盘清单（本轮）

- 脚本：**`scripts/android-v3-bringup-walkthrough.sh`**（`--dry-run` 默认 / `--apply` / `--verify` / `--step` / `--readback full` / `--observe-timeout`）
- 报告：本文件
- 产物：`out/android-v3-bringup-20261120/metadata_stock.img`（29 372 416 B，`a735fbc7…`）
- 证据：`reports/artifacts/android-v3-bringup-20261120/{device-online-check,pieces-inventory,bcb-and-qbootctl,gpt0-geometry,superdbg-sha-drift}.txt|.log`、`dryrun-full.log`
- 跨项目取证（硬规则 12）：`~/hw-stability/evidence/inbox/20261120-y700-elden-pagecache-sha-drift/{MANIFEST.md,observation.txt}`
- 自检记录：`scripts/android-v3-bringup-walkthrough.sh --verify` = 7/7 件 OK + 16 分片齐备；`--dry-run` rc=0（S1–S5 全部打印计划）

---

## 10. 只读预演回执（2026-11-20 19:07，`--verify` + `--dry-run` 实跑）

**结论数字先**：`--verify` rc=0、**41.36 s**、7/7 件 sha 全 OK + 原厂 16 分片齐备；`--dry-run` rc=0、**50.40 s**、S1–S5 全部打印完毕；**零设备写入**（qdl/fastboot/adb 写命令一条都没发；`[dry]` 行 **52** 条（S1 13 / S2 12 / S3 13 / S4 11 / S5 3）+ 判据行）。设备现态仍是 **fastboot `HA2EXB0E`**（与预演前一致），总线上另一台 `MDX5T20730009849` 在 adb（PITFALLS #371 预期内）。

### 10.1 S1–S5 逐步：命令 / 预期输出 / 失败回落

> 命令均为 `--apply` 真执行形态；`QDL=$HOME/edl/qdl/build/qdl`、`L=$HOME/下载/tb322fc/xbl_s_devprg_ns.melf`、`TAB=root@192.168.7.1`、`S=HA2EXB0E`。
> **⚠ 手抄注意**：脚本 `run()`/`logc()` 用 `$*` 打印，**远端命令的引号被吞**（见 §10.3 F1）——下面已按真实 argv 加回单引号，照抄请用本表，别照抄 `commands.log`。

**S1 清 BCB + 置 active=a + v1 在机首启（预期 3–5 min；前置需 **Linux 侧**）**

| # | 命令 | 预期输出 | 失败回落 |
|---|---|---|---|
|1|`ssh $TAB 'uname -r; findmnt -no SOURCE,LABEL /'`|`6.x-elden` + `/dev/disk/by-partlabel/root…`|ssh 不通 ⇒ 设备不在 Linux（现 fastboot）⇒ 见 §10.2 顺序问题|
|2|`ssh $TAB 'qbootctl 2>&1 \| head -24; qbootctl -a 2>&1'`|`Active slot: a` + 槽表|为 `b` ⇒ 第 6 步 `--set-active=a`|
|3|`ssh $TAB 'dd if=/dev/disk/by-partlabel/super bs=4096 count=128'` > `super-head512k.bin`；`python3 scripts/android-super.py list …`|`system_a … 5296 MiB`（= v1 在机）|尺寸对不上 ⇒ 在机不是 v1，先回刷 v1 再谈首启|
|4|`ssh $TAB 'dd if=/dev/disk/by-partlabel/misc bs=4096 count=4'` > `bcb-before.bin` → `bcb_judge`|`size=16384 nonzero=0 command=''` ⇒ 干净|`boot-recovery`/`bootonce-*` ⇒ **本次样本无效**，先清 0 重来|
|5|`ssh $TAB 'cp -f /dev/disk/by-partlabel/misc /tmp/misc.bcb.bak; dd if=/dev/zero of=/dev/disk/by-partlabel/misc bs=4096 count=1 conv=fsync'` → 读回 16 KiB|`nonzero=0`|`nonzero≠0` ⇒ **不要 reset**，重做第 5 步|
|5b|`ssh $TAB 'python3 /tmp/slot-attr.py --allow-wrong-lun --device /dev/sde set a --retry 7 --no-unbootable --successful'`（仅当 byte6 ∉ {0x7a,0x7b}）|byte6 `0x82 → 0x7a`|复位后仍非 0x7a/0x7b ⇒ **不要 reset**（PITFALLS #695）|
|6|`fastboot -s $S getvar current-slot`；`!=a` 则 `fastboot -s $S --set-active=a`|`a`|回退 = `--set-active=b`（写 GPT 属性，super 零改动）|
|7|`ssh $TAB 'sync; reboot'` → 轮询 `adb -s $S`（≤600 s）|`sys.boot_completed=1` + `mCurrentFocus` 含 launcher ⇒ SUCCESS|见 §10.1 末 fail 分类表|

**S2 回写原厂 metadata（29 372 416 B；预期 5–8 min；需 EDL）**

| # | 命令 | 预期输出 | 失败回落 |
|---|---|---|---|
|1|（件在位，跳过 assemble；缺则）`python3 scripts/android-super.py assemble --xml backup/official-rom-15.10.259/rawprogram_save_persist_unsparse0.xml --label metadata -o out/android-v3-bringup-20261120/metadata_stock.img`|29372416 B，sha `a735fbc7…`|拼装尺寸不符 ⇒ 查 xml 分片连续性（R6 口径 1..8 连续）|
|2|`fastboot -s $S oem edl` → 等 `lsusb -d 05c6:9008`|EDL 已枚举|120 s 未枚举 ⇒ exit 3 人项（按键/插线）|
|3|`$QDL -s ufs -R $L read 0/0+6 live-gpt0-primary.bin` → `python3 scripts/android-linux-coexist-check.py --gpt …` + 内联 GPT 解析|`gate super: live 90504..5857671 … OK`、`gate metadata: live 5857704..5874087 … OK`|任一 MISMATCH ⇒ `die` 不写（表变了）|
|4|`$QDL -s ufs -R $L read 0/5857704+7171 metadata-pre.bin`|回退基线落盘|读失败 ⇒ 不写|
|5|`$QDL -s ufs -R $L write 0/5857704 metadata_stock.img sha256 0/5857704+7171 read 0/5857704+4096 head16m read 0/5860779+4096 tail16m`|设备端 sha = `a735fbc7…`；head/tail `cmp` 一致|sha 不符或 cmp 不符 ⇒ rc=1，**先怀疑主机读路径**（O_DIRECT/pcache-wash）再怀疑设备|
|6|BCB 清 0 + 读回（同 S1 第 5 步，走 EDL 写 `0/89992` 4 KiB 零）|`nonzero=0`|≠0 ⇒ 不 reset|
|7|`$QDL -s ufs $L reset` → 轮询 adb ≤600 s|boot_completed=1 + launcher|fail 分类见下|

**S3 原厂 super 对照（15 607 586 816 B = 14.54 GiB；预期 14–18 min；需 EDL）**

| # | 命令 | 预期输出 | 失败回落 |
|---|---|---|---|
|1|`python3 scripts/android-super.py assemble --xml … --label super -o out/android-v3-bringup-20261120/super_stock_contig.img`|**15607586816 B**（=3810446×4096；稀疏落盘 ~12.2 GiB，工作区余 203 G）|尺寸不符 ⇒ 不写|
|2|`fastboot -s $S oem edl` → 等 9008|EDL|同 S2|
|3|`$QDL … read 0/0+6` + coexist-check（带 `--super-img`）|GPT 门 OK|MISMATCH ⇒ 不写|
|4|`$QDL -s ufs -R $L read 0/90504+128 super-head512k-pre.bin`|回退快照|—|
|5|`$QDL -s ufs -R $L write 0/90504 super_stock_contig.img sha256 0/90504+3810446 read 0/90504+4096 head read 0/3896854+4096 tail`|设备端 sha = 主机 sha；head/tail 一致|不符 ⇒ rc=1 不 reset|
|6|BCB 清 0 + 读回 → `$QDL -s ufs $L reset`|`nonzero=0`|≠0 ⇒ 不 reset|
|7|观察 ≤600 s|**原厂进桌面** ⇒ 问题在我们的 super 内容；**原厂也不进** ⇒ 问题在 /data/GPT/设备态|回退：`$QDL -s ufs -R $L write 0/90504 out/android-min-20261118/pkg/super_min.img`（v1，2171264 扇区）|

**S4 二分 v2b（8 741 MiB，system_a 5552 MiB；预期 8–10 min；需 EDL）**

| # | 命令 | 预期输出 | 失败回落 |
|---|---|---|---|
|1|`$QDL … write 0/90504 out/android-slim-v2b-20261119/new/super_min_v3.img sha256 0/90504+2237696 read 0/90504+4096 read 0/2324104+4096`|设备端 sha = `98a88ea0…`；head/tail 一致|不符 ⇒ rc=1；回退 = S3 的 v1/原厂件任一路径|
|2|BCB 清 0 → 读回 → `reset` → 观察|同三条判据|—|
|3|读法|v2b 成功 ⇒ 18 个 leaf 包不是原因（删池/AI 才是）；失败 ⇒ 走「只占位不删」臂|—|

**S5 日志通道 `console=ttyGS0`（零写盘，`fastboot boot`；需 fastboot 现态）**

| # | 命令 | 预期输出 | 失败回落 |
|---|---|---|---|
|1|（件已在位 100663296 B；O_DIRECT sha = **`0dad04f1d2f41fc2126eb2bda045adec8c8dce3ad95535442e53369dfc0280af`**）|sha 稳定两次|漂移 ⇒ 主机读路径/硬件存疑（硬规则 12），不上机|
|2|`python3 scripts/boot-img-cmdline.py <件> --show \| grep -F console=ttyGS0`|cmdline 含 `console=ttyGS0`|不含 ⇒ 重造件|
|3|`python3 scripts/boot-img-cmdline.py <件> --verify`|v4 窗口外逐字节全等|非 0 ⇒ 不上机|
|4|`timeout -k 5 300 fastboot -s $S boot <件>`|`OKAY`|`FAILED (remote: …)` ⇒ 记**需上机项未通过**（AVB hash 失配 / vendor_boot cmdline 优先），不改代码臆测|
|5|`timeout -k 5 900 cat /dev/ttyACM0 > serial.log`|内核 log 或 Android init 输出|无输出 ⇒ 回退 pstoredump 通道（`pstore_triage`）|

### 10.2 ⚠ 现态阻塞（必须先做物理动作）：S1 在当前 fastboot 现态下 `--apply` 会 **exit 3**

- `S1` 只调 `ensure_linux`，**没有 `ensure_edl` 分支**；`ensure_linux` 在 `APPLY=1 && 现态≠linux` 处直接 `die … 3`。
  因此 **设备现在 fastboot 在线 ⇒ S1 无法起步**，S1 依赖的三件事（linux 侧取证、BCB 清 0、boot_a 属性复位）**全部拿不到**。
- 顺序含义（人定，脚本不自适应）：**现在是 fastboot**，唯一免物理动作的入口是 **S5**（`fastboot boot`，零写盘）或 **S2/S3/S4**（`fastboot oem edl` 进 EDL）。
  要跑 **S1** 必须先让设备进 Linux（启 b 槽 = PSCI vendor reset 路径，`ensure_edl` 里 `systemctl reboot bootloader` 那条）——**属物理动作，须用户执行**。
- 建议：本轮先从 fastboot 走 **S5**（零写盘、拿串口 log）或 **S2→S3→S4**（EDL 链），S1 留到用户把设备送回 Linux 侧之后。这一条不改脚本，只作为执行顺序的人工裁决记录。

### 10.3 预演暴露的 4 个脚本缺陷（只记录，本轮未改代码）

| 编号 | 现象 | 影响 | 建议改法（下轮） |
|---|---|---|---|
|F1|`run()`/`logc()` 用 `$*` 打印，**丢失远端命令的引号**：`ssh $TAB 'uname -r; findmnt …'` 打印成 `ssh … root@192.168.7.1 uname -r; findmnt -no SOURCE,LABEL /`|手抄执行会在**主机**上跑 `findmnt`；`sync; reboot` 打印成裸 `ssh … sync; reboot`|打印用 `printf '%q '` 或把远端命令显示成带单引号的字面量（本报告 §10.1 已手工修正）|
|F2|`pstore_triage()` 在非 linux 现态**直接 `return 0` 且无 verdict**|S2/S3/S4 全程在 EDL/fastboot 侧失败时，「真失败 vs BCB 污染」的三分类**静默缺失**，日志里看不出「没查」还是「查了干净」|非 linux 时写 `verdict.txt: PSTORE_SKIPPED(state=…)`，让归档自证|
|F3|dry-run 下 `commands.log` **不完整**（BCB 清 0、boot_a 复位、`--set-active=a` 不进 log，因为走的是 `*)`/dry 分支不走 `run()`）|归档不能当执行清单用（S1 只有 5 行）|dry 分支也 `logc` 一条 `[dry-plan] …`|
|F4|`bcb_read` 在非 linux/EDL 现态 `: > $out; return 1`，`bcb_judge` 只打「未取到」|`--apply` 时 S1 会以 exit 3 结束，但**日志里看不出是「设备现态不对」而非 BCB 真有问题**|`bcb_read` 失败时把现态写进 `verdict.txt`|

### 10.4 本轮实测数字（来自真实输出）

| 项 | 值 |
|---|---|
|`git rev-parse --show-toplevel`|`/home/xuqianhui/y700-elden`（身份相符）|
|`--verify` 退出码 / 耗时|`0` / **41.36 s**|
|`--verify` 件校验|7/7 OK（v1 `e3d0d26f…`、v3 `51eae107…`、v3_dbg `8b42f20d…`、v2b `98a88ea0…`、metadata `a735fbc7…`、boot_a `b428a31d…`、linux_boot_b `bdf47f5f…`），两次 O_DIRECT 读 sha 全部一致（无 DRIFT）|
|原厂分片|`super_1..8` + `metadata_1..8` 齐备|
|`--dry-run` 退出码 / 耗时|`0` / **50.40 s**|
|打印的 `[dry]` 行数|**52**（S1 13 / S2 12 / S3 13 / S4 11 / S5 3）；`commands.log` 合计 23 行（dry 下不完整，见 F3）|
|设备写入数|**0**（无 qdl write / fastboot flash / adb 写；预演后 `fastboot devices` 仍 `HA2EXB0E fastboot`）|
|缺陷项|0 缺件、0 缺工具；S3 stock super 件按设计**故意缺**（现造，省 12.2 GiB）|
|S5 件 O_DIRECT sha|`0dad04f1d2f41fc2126eb2bda045adec8c8dce3ad95535442e53369dfc0280af`（100663296 B）|
|归档目录|`logs/android-v3-S{1..5}-20261120-190709/`（`commands.log` 各 5/6/7/5/0 行）|
|峰值负载|`uptime` → `load average: 7.85, 6.80, 4.06`（预演为 sha 顺序 I/O，非构建；未取构建锁、未编译）|
