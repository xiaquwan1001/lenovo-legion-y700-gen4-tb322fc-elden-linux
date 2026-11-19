# 设备可用性核查：U2 `HA2EXB0E` —— 「ABL 内存类硬件故障 / 全原厂态等送修 ⇒ 不再上机」作废（2026-11-19）

> **一句话结论**：**该口径已作废（其判据在 2026-11-17 18:5x 被撤回、19:2x 起被单变量实验推翻）**。
> 设备**没有任何硬件故障证据**，11-17 20:0x 已完整起 Android 16、11-18 19:0x 最小安卓包上机成功、11-19 深夜已回到「主线 Linux 能登入」。
> 现态唯一障碍 = **设备此刻没接主机/没上电**（本文 §3 实测），不是坏机，也**不需要送修**。

---

## 1. 旧口径 vs 新证据（逐条给日期与指针）

| # | 旧口径（作废） | 出处 + 日期 | 新证据（压过它） | 新证据出处 + 日期 |
|---|---|---|---|---|
| 1 | 「运行期大块内存访问不稳 = **唯一存活解释（硬件类）**」 | `reports/bl-stuck-20261117-device-window.md:103`（11-17 下午，原文已加删除线）；`DEVICE/service-repair-note-20261117.md`「补充观察」两条 | ① 该两条观察本身证伪：错误串自变 = 本机平台已知特性（`PITFALLS #482`）；`poke 32 MiB` 单发/无正控/地址未验证且 peek-poke 族有 secboot 门控（`#486`）。② 所有 DRAM 敏感操作**全绿**：96 MiB 分区设备端 `sha256`、12 分区 Firehose 读回、61.5 MiB 写 + 39/39 校验 | `reports/bl-stuck-20261118-forensics.md` §2/§7.3；`reports/bl-history-and-playbook.md` §1 修正框（11-17 18:5x） |
| 2 | 「全原厂 39/39 仍失败 ⇒ 失败点固定在 **ABL 的 load/authenticate**（硬件通路）」 | `DEVICE/service-repair-note-20261117.md` §判定（11-17 上午） | **单变量**：T1 只写 **88 KiB GPT**（boot/vbmeta/dtbo/39 固件零改动）⇒ 现象立刻从「`continue`/`boot` 全 `Device Error`」变成「ABL 真的去启动 → 联想 logo」。真因 = **非原厂 GPT**（LUN0 条目名 + LUN4 槽属性字节），**不在镜像、不在内存** | `reports/bl-stuck-20261118-forensics.md` §7.2（11-17 19:2x T1 / 20:0x T2-T3） |
| 3 | 「做完整包线刷（15.6 GiB / 73 分区 / 78 patch）仍起不来，再按本页报修」 | `DEVICE/service-repair-note-20261117.md:61` | 整包已刷 + `fastboot -w` ⇒ **Android 16 完整启动**：`TB322FC_CN_OPEN_USER_Q00041.1_W_ZUXOS_1.5.10.259_ST_260611`、`sys.boot_completed=1`、slot `_a`、`verifiedbootstate=orange` | `reports/bl-stuck-20261118-forensics.md` §7.1（11-17 20:02–20:04）；截图 `reports/artifacts/bl-stuck-20261118/recovered-screen.png` |
| 4 | 「期望维修动作 1. 主板级诊断 / 2. 更换主板」 | `DEVICE/service-repair-note-20261117.md` §判定「期望维修动作」 | 设备随后连续三次真实使用证明硬件可工作：adb 在线复核（`uname -r 6.6.118-android15`、`/data` 450 G）→ 最小安卓包 EDL 写 8.28 GiB @42.2 MiB/s 且设备端 sha 与主机一致 → 主线 Linux 6 GiB 根写入 + SSH 登入 | `INDEX.md` §0「卡什么」段（11-17 21:4x）；`TASKS/sessions/2026-11-18-安卓最小包上机成功与卡动画.md`（11-18 19:0x）；`TASKS/sessions/2026-11-19-主线恢复最小Linux与显示定位.md`（11-19 深夜） |
| 5 | 「④ 设备恢复可用」被当作 11-18 遗留待办（隐含「设备不可用」） | `TASKS/README.md` §4 2026-11-18 最小包条目 | 次日即已「可用」：设备被用于 3 次上机（含 EDL 写 6 GiB 根 + USB-NCM SSH 登入）；因此该项应改读为「**设备可用，遗留的是软件面**（显示/ADSP 未就绪、安卓卡动画）」 | `DEVICE/README.md` §1.6（本次新增）；`TASKS/README.md` §4 2026-11-19 条目 |
| 6 | 「是否需要送修」作为待决问题 | `reports/bl-stuck-20261118-forensics.md:84` 未排除项表第 4 行「T3 后仍失败 ⇒ 升级为硬件报修」 | 该行的触发条件**已被执行且未成立**（T3 = 整包原厂线刷 + `fastboot -w`，结果是完整启动）⇒ 报修口子**关闭** | 同上 §7.1；本文 §5 已就地标注 |

> 口径纪律：**「硬件结论四道门」没过就不许写硬件**（`RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md` §1.2）。
> 11-17 那一轮的错误是**只验了 GPT「可解析」，没验「逐字节回原厂」**——教训已入 `RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md` §6 事故回放。

---

## 2. 仓库内残留扫描（本次核查动作）

```sh
grep -rn "等送修" . --include=*.md     # 修前：0 命中（仓里从未出现这个表述）；修后只有本次新增的「已作废」句子命中（均已带作废前缀）
grep -rn "送修\|不再上机" . --include=*.md
```

命中的段落原本全部已带「作废/历史/反面教材」定性，**唯一没带作废抬头的是送修单文件本身**——本次已补（见 §5 改动清单）。
另有 3 处「未定因 / 硬件报修口子」的旧表格行未标结案，本次一并就地标注（`bl-stuck-20261118-forensics.md:84`、`bl-history-and-playbook.md` BL-09/BL-10）。

---

## 3. 设备在线判定（2026-11-19 实测，**只读**）

| 探测 | 命令 | 结果 | 判读 |
|---|---|---|---|
| USB 描述符 | `lsusb` | 只有 root hub / cdc gadget(自己)/ASUS AURA/两只鼠标/NuPhy dongle/**`12d1:108a` Huawei ELS-AN00** | **无 `05c6:9008`（EDL）、无 `18d1:d00d`（fastboot）、无 `05c6:*` Qualcomm 复合设备** ⇒ U2 未连接 |
| 总线拓扑 | `lsusb -t` | Bus001 Port1 = `cdc_ncm`+`cdc_acm`（= 主机自身 USB gadget，给 P40pro 共享网/串口用）；Port11 Dev9 = `rndis_host`（华为手机） | 同上，无平板 |
| 内核日志 | `dmesg \| grep -iE "usb\|qcom\|9008\|fastboot"` | **空**（当前会话读不到 dmesg，需 sudo，本次按约束跳过） | 该列**无判据**，不参与结论 |
| adb | `timeout 15 adb devices` | `MDX5T20730009849 device`（P40pro 手机）、`emulator-5554 device`（安卓模拟器）| **无 `HA2EXB0E`** ⇒ U2 未在 Android 侧在线。⚠ 这两个都不是本机，**禁一切写操作** |
| fastboot | `timeout 15 fastboot devices` | 空 | 未在 fastboot |

**判定**：设备 **离线**（未插 USB 或未上电），**不是故障、不是坏机**。
⇒ 一切「等设备修好」的表述都不成立；要推进只需要**人做一次物理动作**（§4 第 1 步）。

---

## 4. 下一步上机计划（可执行；写操作单列待确认）

> 顺序原则：先只读确认在线 → 再零写盘实验 → **写操作一律排到最后并等用户确认**。

**0）人项（只有这几件必须是用户动手）**
1. 给 U2 接 USB 数据线（主机侧已插好的端口不动）+ 按电源键上电。
2. 若屏上停在引导菜单/fastboot，按项目惯例口头告知即可（agent 不代按物理键）。
3. 若设备已在 Linux、需要换槽/断电冷起，同样是用户按键动作。

**1）在线确认（只读，5 条命令，任一命中即「在线」）**

```sh
timeout 15 lsusb | grep -E '05c6:9008|18d1:d00d|05c6:90'   # EDL / fastboot
timeout 15 fastboot devices                                 # → HA2EXB0E  fastboot
timeout 15 adb devices                                      # → HA2EXB0E  device
timeout 10 sudo scripts/ncm-host-up.sh                      # 起 USB-NCM 宿主侧（幂等）
timeout 10 ssh -o BatchMode=yes -o ConnectTimeout=5 root@192.168.7.1 'uname -r; findmnt -no SOURCE /'  # 主线 Linux
```

**2）主线 Linux 面（当前主任务：显示未通）**
- 判据（`DEVICE/README.md` §1.1 首条）：`ssh root@192.168.7.1` 可登入 + 内核 UTS `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0` + `findmnt /` = `LABEL=linux`。
- 第一件事：`python3 scripts/slot-attr.py show | grep boot_b`（看 retry 是否被扣）→ `python3 scripts/slot-attr.py mark-successful b`（**写槽元数据，需用户确认**）。
- 显示实验（**零写盘**，不改任何分区）：`out/min-restore-20261119/dp-port2-experiment.patch` 摘掉 `&dpu_intf0_out` 的 `remote-endpoint` → `make dtbs`（`-j26`）→ `scripts/build-boot.sh` 重打 → `timeout 120 fastboot boot <件>`。
  **先跑一发 `test-ctrl`（= `out/boot-elden-vk192.img` 原件）** 确认 RAM 启动本身仍可用，再试 nodp 件（11-19 两次 RAM 启动都没枚举 USB，不能当否证）。
- 桌面层（`resize2fs` 扩到 193 GiB + `daily-baseline`）需先有显示/网络，排在显示之后。

**3）安卓 a 槽面（只读取证优先）**
- 现态：a 槽 = 11-18 瘦身 Android，wipe 后**卡 ZUXOS 动画**（未取证）。
- 只读取证：`adb -s HA2EXB0E logcat` / recovery logcat / `ttyGS0`（`scripts/acm-sh.py`）；`adb shell getprop sys.boot_completed`。
- **写操作（需用户确认后才做）**：`scripts/android-min-build.sh` 干净瘦身 v2、`scripts/android-ksu-flash.sh --apply`（KSU+vbmeta_a）、`fastboot -w`。

**4）最小件是否还在盘（本次已核，全部在位）**

| 件 | 路径 | 大小 | 用途 |
|---|---|---|---|
| 主线最小根（含 `/init`+gadget） | `out/min-restore-20261119/rootfs-minbase-gadget-20261119.ext4.img` | 6.0 GiB | EDL 重写 LBA 73277435（sha `abf96ec4…`） |
| 安卓最小 super | `out/android-min-20261118/pkg/super_min.img` | 8.28 GiB | a 槽最小安卓（设备端已验证 sha 一致） |
| 显示实验件 | `out/min-restore-20261119/dp-port2-experiment.patch` | 1 KB | 零写盘 RAM 启动 |
| 上机脚本 | `scripts/{ncm-host-up.sh,acm-sh.py,slot-attr.py,build-boot.sh}` | — | 均在位可执行 |

**5）需用户确认的写操作清单（本次一件都没做）**
`slot-attr.py mark-successful b`、`fastboot boot`（零写盘但占设备）、EDL 任何 `write`、`fastboot flash`、`fastboot -w`、`android-ksu-flash.sh --apply`、`android-slim-v2-plan.sh --apply`、`hide-android-partitions.sh --apply`。

---

## 5. 本次改动清单（文档-only）

| 文件 | 改动 |
|---|---|
| `DEVICE/service-repair-note-20261117.md` | 顶部加 `> 作废（2026-11-19）` 抬头；更正「当前状态」为「已能起 Android / 现为 Linux 最小根」；保留全部历史段 |
| `DEVICE/README.md` | §1.1 首条补「不需要送修（判据 + 指针）」；**新增 §1.6 设备当前可用性与下一步上机判据** |
| `INDEX.md` | §0「做到哪」块补设备可用性一行（离线≠坏机 + 本文指针） |
| `TASKS/README.md` | 11-19 待办首条补「设备可上机，判据 = …」；11-18 条目 ④ 由「设备恢复可用」改读为「设备可用，遗留是软件面」 |
| `reports/bl-stuck-20261118-forensics.md` | §3 未排除项表第 4 行标注「触发条件已执行且未成立 ⇒ 报修口子关闭」 |
| `reports/bl-history-and-playbook.md` | BL-09/BL-10 两行补 `2026-11-19 已定因` 结案句（真因 = 非原厂 GPT） |
| `RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md` | §6 事故回放第 2 条补「该单已于 2026-11-19 标作废」 |
| `reports/device-status-20261119.md` | 本文件（新增） |
