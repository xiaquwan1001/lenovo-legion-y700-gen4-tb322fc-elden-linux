# 用户态镜像 13 组同名不同内容 —— 逐组裁定（2026-11-27，父代理）

- **性质**：主机侧 + 设备只读取证（`ssh elden` 算 sha/mtime，零写盘），设备由父代理独占期间完成。
- **输入**：`reports/userland-mirror-gate-20261127.md`（门落地轮，残留 = 13 组「待用户裁定权威归属」）、
  `scripts/check-userland-mirror.sh` 的 WHITELIST、`packaging/elden-userland/MANIFEST.tsv`。
- **唯一产物**：本文件（外加：`files/**` 快照、`scripts/**`、`rootfs/persistent-overlay/**`、`MANIFEST.tsv`、门脚本的白名单理由文本的同步改动）。

---

## §0 一页结论

| 项 | 修前 | 修后（现查） |
|---|---|---|
| 门 `--check` 汇总 | 同 sha 配对 **20** ｜ 白名单漂移(WARN) **14 对 = 13 组** ｜ 白名单外 **0** | 同 sha 配对 **35** ｜ 白名单漂移(WARN) **0** ｜ 白名单外 **0**（rc=0） |
| 13 组「待用户裁定」 | 13 组 | **0 组**（逐组有裁定 + 判据，见 §2） |
| `packaging/elden-userland/tools/verify.sh --offline` | FAIL=0（42 ok） | FAIL=0（42 ok） |
| `scripts/check-userland-mirror.sh --selftest` | OK | OK（反样本仍 FAIL=1，判别力未退） |
| doctor **§32** | PASS | PASS（`scripts/check-doctor.sh --only 32` → FAIL=0 WARN=0） |

**裁定口径（一句话）**：`files/**` 是**装机源**（`MANIFEST.tsv` 的 `repo_src` 全部指向它），
所以「谁是权威」只有两种结局 —— **A：`scripts/` 更新 ⇒ 把 `files/` 刷成部署源（设备仍是旧版，待部署）**；
**B：设备上跑的更新（已上机验证）⇒ 回灌 `scripts/` / overlay，让权威源追上设备**。
不存在「两边都对、保持不同」的第三条路。

**证据表（设备 sha 由 `ssh elden` 现算，前 16 位）**

| 组 | 设备 | `files/`（修前） | 权威源（修前） | 裁定 |
|---|---|---|---|---|
| `init` | `47af5f7d` | `47af5f7d` ✅ | overlay `073253e5` ❌ | **B** |
| `scale.sh` | 设备无此件 | `56fce085` | scripts `244da69b` | **A** |
| `slot-attr.py` | `2b004355` | `2b004355` ✅ | scripts `a9bd30ed` | **A** |
| `ath12k-load.sh` | `37ca2ec0` | `37ca2ec0` ✅ | scripts RETIRED 存根 | **A** |
| `camera-modules-load.sh` | `d1b0a9eb` | `d1b0a9eb` ✅ | scripts `e2264abf` | **B** |
| `charge-watch.sh` | `257b0125` | `4a8870f2` ❌ | scripts `257b0125` ✅ | **A** |
| `net-up.sh` | `c5d4dc35` | `c5d4dc35` ✅ | scripts `4dad8ea5` ❌ | **B** |
| `openrc-enable.sh` | `c89433b3` | `c89433b3` ✅ | scripts `deb55ceb` | **A** |
| `q28-boot-watchdog.sh` | `a85ec07a` | `a85ec07a` ✅ | overlay `709e9eb8` ❌ | **B** |
| `q28-watchdog.sh` | `1149f75c` | `1149f75c` ✅ | scripts `7ad0c823` | **A** |
| `sleep-bisect.sh` | `0f608860` | `0f608860` ✅ | scripts `92e995af` | **A** |
| `sleep-cumulative.sh` | `e1cebe18` | `e1cebe18` ✅ | scripts `53323d29` | **A** |
| `time-sync.sh` | `f82f3bf4` | `f82f3bf4` ✅ | scripts `c5736ac0` ❌ | **B** |
| `usb-gadget`（本轮新增，见 §4） | `ce045a95` | `ce045a95` ✅ | `initramfs/` `c95ff928` | **A** |

> 「设备 = `files/` ✅」出现 9 次，说明 **`files/` 快照本身是准的**（没有脏快照），
> 修复集中在「权威源那一侧落后/超前」，不是「快照不可信」。

---

## §2 逐组裁定（判据 = 具体差在哪 + 为什么这边对）

### A 方向（`scripts/` 更新 → 刷 `files/`；设备待部署）

1. **`scale.sh`**（+8/−2）：`scripts/` 版多了 `export WAYLAND_DISPLAY=wayland-0`（缺它时 `wlr-randr` 找不到会话）
   和「phoc 只对整数 scale 精确上报」的 3 行警告（2.5 会被量化、g-c-c 显示 100%）。⇒ scripts 权威。
2. **`slot-attr.py`**（+24/−1）：`scripts/` 版加 **LUN 归属闸**（`--expect-lun 4`，非 LUN4 直接 rc=4），
   修的是「传错 `/dev/sda` 仍打印 written + CRCs fixed、rc=0」这个静默假成功洞。⇒ scripts 权威。
   设备侧 `bin/` 与 `sbin/` 两份同 sha（`MANIFEST` 两行都指向 `files/usr/local/bin/` 与 `sbin/`），本轮两处同步。
3. **`ath12k-load.sh`**（+30/−4）：`scripts/` 版是 **RETIRED 存根**（无 `ATH12K_LOAD_ALLOW=1` 一律 exit 2），
   正文修正了「sysfs `bind` 吃设备名不是路径」这个恒静默失效 bug；真源是 `scripts/ath12k-retry.sh`。
   设备侧仍是被审计判死的旧版 ⇒ 刷 `files/` 后下次装机/部署即换成存根（防误调用）。
4. **`charge-watch.sh`**（+163/−26，最大漂移）：`scripts/` 版 = 2026-11-26 上机后的 sag guard 版
   （阈值被实测改过：4.60 V→**4.40 V**、floor 500 mA），设备 **就是** scripts 这份（`257b0125`），
   `files/` 那份是 11-12 的旧快照（2405 B vs 9027 B）⇒ **`files/` 是错的装机源**，必须刷。
5. **`openrc-enable.sh`**（+6/−2）：`scripts/` 版把 `wifi-scan-refresh` 加进 DEFAULT、`elden-hapticd` 移出
   （`PITFALLS #354`：NM 连上后禁止自己周期扫描 ⇒ 候选表只剩当前 AP）。OpenRC 期件，但权威仍是 scripts。
6. **`q28-watchdog.sh`**（+48/−4）：`scripts/` 版 2026-11-17（Q28 账目的现行版）；设备侧是 840 B 的早期版。
7. **`sleep-bisect.sh` / `sleep-cumulative.sh`**（+8/−1、+7/−1）：`scripts/` 版加了 **LEGACY 头注**
   （判据：不删、降 legacy、新扫测用 `scripts/sleep-sweep.sh`），并写清保留理由（随 rootfs 发设备 + 设备侧真机工具）。
   头注是审计结论的载体 ⇒ 装机源该带上。
8. **`usb-gadget`**：见 §4。

### B 方向（设备/`initramfs` 更新 → 回灌权威源）

9. **`net-up.sh`**（`files/` +5/−33）：设备版有 `wifi_iface()` **动态探测**（Debian/systemd 的 `net.ifnames`
   ⇒ `wlp1s0`，而旧版写死 `wlan0` ⇒ 等 180 s 后 `net-up.service` failed、WiFi 不自动连，2026-10-26 实测）。
   `scripts/` 那份是写死 `wlan0` 的旧版 ⇒ **回灌**（这是本轮最有价值的一条：旧 scripts 版装上去就是故障配置）。
10. **`time-sync.sh`**（`files/` +3/−40）：设备版有 flock 串行化、`systemctl stop chronyd`（否则 `chronyd -q`
    以「Another chronyd may already be running」退出、时钟一步不跳）、12×20 s 重试、**HTTP Date 兜底**
    （UDP/123 被拦时仍能把时钟拨对，否则 apt TLS 全红）。`scripts/` 那份是 10-17 的裸 `chronyd -q` ⇒ 回灌。
11. **`q28-boot-watchdog.sh`**（`files/` +5/−15）：设备版判据是「存在任一 `cardN`」，并把卡名写进日志；
    旧版只认 `/sys/class/drm/card0`，而 UEFI/GRUB 路径下 efifb 先注册 card0 再注销、msm 拿 **card1**
    ⇒ 一次完全正常的启动被判「坏发」并自动重启（2026-11-16 实测）⇒ 回灌 overlay。
12. **`camera-modules-load.sh`**（`files/` +1）：设备版多一行 `MODDIR=$(readlink -f "$MODDIR")`，
    `scripts/` 那份是 10-17 批量拷贝时的旧代（差 1 行，无功能差语义）⇒ 以设备为准回灌，避免装机源改行为。
13. **`init`**（`files/` +33/−347）：**`initramfs/init` == `files/init` == 设备（`47af5f7d`，678 行）**，
    `rootfs/persistent-overlay/init` 是 364 行旧代（缺 phase-aware 工具清单、缺 Debian 根/dbus 分支）。
    SSOT 本来就写在 `initramfs/init` 头注里（`rootfs/build-rootfs.sh:65` 也从它 `sed` 出 `/init`），
    overlay 副本是历史第二份 ⇒ **回灌成同 sha**，并把 `initramfs/` 加进门的 POOL_DIRS（三处同 sha 从此机器守）。

---

## §4 门的加固（防「裁定完又漂回去」）

1. `POOL_DIRS` 增加 `initramfs/`：`/init` 与 `usb-gadget` 从此**三处**（`files/`、overlay/initramfs、`initramfs/`）同 sha 才配对。
2. 白名单 13+1 条的**理由文本全部改写**为裁定结论（含方向与「设备待部署」标记），不再是「待用户裁定权威归属」。
   保留条目本身有明确用处：`tools/sync-from-device.sh` 会把 `files/` 拉回**设备现态**（A 方向那 8 件设备还是旧版），
   届时应为 WARN「设备待部署」而不是 FAIL；同条目若再漂成第三种内容，人一眼能看出是已知面。
3. 修 `scripts/doctor/32-userland-mirror.sh` 的 `ROOT` 推导 bug：`$(dirname "$0")/..` 得到 `scripts/`（不是仓根）
   ⇒ 直接 `bash scripts/doctor/32-userland-mirror.sh` 会假 FAIL「缺 scripts/check-userland-mirror.sh」；
   改成 `/../..`（经 `check-doctor.sh` 时 `ROOT` 由外部给，不受影响）。

**判别力自证（防恒 PASS）**：`--selftest` 仍造反样本（同名不同内容且不在白名单）⇒ `rc=1`；正样本 `rc=0`。现查 `SELFTEST OK`。

---

## §5 待办（本轮未做，明确列）

| # | 待办 | 判据 | 需设备 |
|---|---|---|---|
| U1 | **部署 A 方向 8 件到设备**：`scale.sh` / `slot-attr.py`(bin+sbin) / `ath12k-load.sh`(存根) / `charge-watch.sh`(已是) / `openrc-enable.sh` / `q28-watchdog.sh` / `sleep-bisect.sh` / `sleep-cumulative.sh` | 设备逐件 sha == `MANIFEST.tsv` 行；随后 `tools/sync-from-device.sh` 重生成 MANIFEST 仍字节同（= 快照与设备对齐） | 是（只装不激活） |
| U2 | **`usb-gadget` 的 GS1 激活**：文件已刷成含 `acm.GS1` 的版本，但**激活 = 重新 bind gadget**（会掉 usb0 网络 = 掉 SSH 通道）⇒ 只能随下次重启生效，或在有第二条通道（真机键盘/串口）时做 | 重启后 `/sys/class/tty/ttyGS1` 存在；主机见 `/dev/ttyACM1` | 是（且需第二条通道） |
| U3 | `verify.sh`（**在线档**）跑一次 section F，确认设备 ↔ MANIFEST 逐字一致 | `verify.sh elden` FAIL=0 | 是 |

> 注：`ath12k-load.sh` 不在 `MANIFEST.tsv`（审计已把它移出装机名单），部署它属「防误调用」的额外动作，不计入 U1 判据。

---

## 收尾: 13 组同名不同内容全部裁定并落地（门 35 配对 / 0 漂移 / 0 FAIL，verify --offline 42 ok / doctor §32 绿），U1–U3 三项设备侧动作明确留给设备窗。
