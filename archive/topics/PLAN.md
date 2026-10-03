# 下一阶段规划 — TB322FC "elden" （立项 2026-09-29 夜；**状态更新 2026-09-30 夜**）

> 入口见 `INDEX.md`；技术细节见 `HANDOFF.md`；坑见 `PITFALLS.md`；**最新依赖分层看 `ROADMAP-dep-2026-09-30.md`**。
> 本轮基线：`out/boot-elden-vk19.img`（root = `/dev/sda17` 65 GiB, LABEL `linux17`）。

> ⚠️ **状态横幅（2026-09-30 20:30）**——本文件的阶段划分已基本走完，保留作为历史规划：
> - **阶段 0（Android 重建 /data + KSU）✅ 完成**（`/data` 146.4G FBE + a 槽 KSU 全链）。
> - **阶段 1 桌面 ✅ 基本完成**（dbus/UPower/时间/NM/foot/squeekboard **均已完成**；1.6 DPI 缩放已定 **2.5**）。
> - **阶段 2.3 双槽直启 ✅**、**2.4 熄屏挂死 ✅（已修，非挂死）**、**2.5 充电 ✅（QCOM battmgr 已工作，实测 77% Charging）**。
> - **阶段 3**：触觉 ✅（vk19）；音频 tplg / TF 卡 仍为独立深坑；新增 B2 刷新率（见 ROADMAP）。
> - 下表“现场侦察”为 **2026-09-29 旧快照**，已不反映当前状态（当前是 b 槽直启 Linux）。

---

## 现场侦察（已确认，本轮实测）

| 项 | 状态 |
|---|---|
| `current-slot` | **a**（b 槽是坏的，见 `HANDOFF §20`） |
| `sda16 userdata` | **全 0**（前 4 MiB 零字节）→ 已被 `fastboot erase userdata` 擦除 |
| `sda13 metadata` | **全 0** → 加密 key 已清 |
| Android | **未重建**：还没进过 Android 首次启动 |
| 主线 root | `/dev/sda17` 63.4G / 余 59.2 GiB ✅ |
| 备用 root | `/dev/sde79`（label `linux`）+ vk11 可回退 ✅ |
| 电池 | 4.17 V（**主线不充电，长任务前先在 Android 充满**） |

---

## 阶段 0 ✅ 已完成（2026-09-30）：让 Android 重建 `/data`

**为什么**：`sda16` 已是 146.4 GiB，但里面没有文件系统——首次进 Android 时 `fs_mgr`
才会创建 f2fs + 加密。做完这一步，"缩 userdata + 加 linux 分区"才算真正完成。

**前置**：`backup/dtbo_a.img`（原厂 32 MiB, sha256 `45f51790…929a7`）—— 写回真 dtbo，
避免 ABL 的 AVB 描述符不匹配（dummy dtbo 是给主线用的）。

**同时把 Android 侧一次刷好（含 KSU）** —— 详见 `restore-259/AVB-KSU-2026-09-29.md`：
本机已 unlocked（`verifiedbootstate=orange` + `veritymode=disabled`），**改过的 `abl` 不必刷**；
a 槽全链用同一把 key `2597c218`（设备本来就信任）即自洽。

**用户逐条执行**（该机 fastboot 讨厌批量；**先确认槽位**，见 `PITFALLS §60`）：

```bash
cd ~/y700-elden
fastboot --set-active=a                     # ★ 必须先做：fastboot boot 失败会把槽翻到 b
fastboot flash dtbo_a          backup/dtbo_a.img                     # 原厂 dtbo
fastboot flash init_boot_a     restore-259/KSU/init_boot.img        # KSU
fastboot flash vbmeta_a        restore-259/KSU/vbmeta.img           # 与 init_boot 严格配套
fastboot flash vbmeta_system_a restore-259/重签包/vbmeta_system_a.img
fastboot flash recovery_a      restore-259/重签包/recovery_a.img
fastboot reboot
```

**验收**：Android 首次启动 2–5 min → 「设置 → 存储」显示 ≈**146 GB**；
装 `restore-259/KSU/KernelSU_v3.2.5_32525-release.apk` → 打开应显示 KSU 已生效；
`~/android-backup/` 里的 Hollow Knight + Limbus 可还原。

**若 bootloop 卡 logo / 回到 fastboot**：不是砖。按 `restore-259/AVB-KSU-2026-09-29.md` 第三节
用 `backup/stock-259/` 原样回退（每个分区都有 sha256）。

**回主线**：Android 里 `adb reboot bootloader`（或物理键）→
```bash
fastboot --set-active=a
fastboot flash dtbo_a out/dtbo-dummy.img
fastboot flash dtbo_b out/dtbo-dummy.img
fastboot boot out/boot-elden-vk12.img
```

---

## 阶段 1 ★★（推荐）：桌面对齐 —— 从"能起来"到"能用"

现在有 59 GiB 空间，装包不再是问题。痛点（`HANDOFF §22.8` 遗留 + 本轮观察）：

| # | 问题 | 方案 | 依赖 | 状态 |
|---|---|---|---|---|
| 1.1 | **没有 system dbus** → NM/UPower 都起不来 | `/init`/`start-desktop.sh` 里启动 `dbus-daemon --system` + 修 helper 权限 | 无 | ✅ 2026-09-30 |
| 1.2 | 状态栏**没有电池** | 起 **UPower**（`qcom-battmgr-bat` 驱动 OK；实测 71% Charging） | 1.1 | ✅ 已具备（待目视确认图标） |
| 1.4 | **时间显示 1970**（PMIC RTC **只读，`hwclock -w` 报 ENODEV**） | 开机 `time-sync.sh`：等默认路由→`chronyd -q` 步进→`chronyd` 常住；tz=Asia/Shanghai | WiFi | ✅ 2026-09-30 |
| 1.5 | 只有 Settings，没有终端/输入法 | 装 `foot`（✅ 已装 1.27.0 +ime）；确认 phosh 应用网格可见；squeekboard ✅ | 网络 | 🟡 已装，待目视确认 |
| 1.3 | 状态栏**没有 WiFi 图标**，WiFi 是手工 `wpa_supplicant+udhcpc` | 装 **NetworkManager**，`nmcli` 接管 wlan0；保留 `net-up.sh` 作回退（**有断网风险，先备份配置**） | 1.1 | ✅ 2026-09-30 |
| 1.6 | DPI / 1904×3040 缩放 | `phoc.ini` scale 或 GNOME text-scaling；Squeekboard 高度 | — | ✅ 已定 **2.5**（目视确认；Displays 面板比例行恒显 100% 为 phosh 小瑕疵） |
| 1.7 | **睡眠挂死**（见 `PITFALLS §64`） | ① `mem_sleep=s2idle` 已写进 `/init`；② 关空闲灭屏（`idle-delay=0`）；③ 用 `rtc wakealarm` 受控测 s2idle | 无 | ✅ 内核未暴露 `mem_sleep`/`/sys/power/state` 为空 → 无法触发 suspend |

**取包方式（二选一）**
- **A（推荐）**：手机热点开着 → 设备 `apk add` 直连 Alpine 仓库（`/etc/apk/repositories` 已配 `latest-stable`）。
- **B**：USB-NCM 走主机代理（主机 `192.168.7.2`，需给设备配 `http_proxy`）——无需热点。

**验收**：状态栏同时有 WiFi + 电池 + 正确时钟；能开终端、能用虚拟键盘输命令。

---

## 阶段 2 ★：网络与稳定（可选，看你要把它当"日常机"还是"实验机"）

- **2.1 WiFi 长稳压测**：按 `HANDOFF §22.6` 方法（`logger` 打点 + pstore 取证），至少 30 min 长 ping / 一次大流量下载。
- **2.2 掉电问题**：主线不充电（PMIC charger 未驱动）→ 决定是
  (a) 接受"Android 充满再进主线"，还是 (b) 花力气驱动 charger（`HANDOFF` 未列入待办，成本高）。
- **2.3 双槽直启**：把自编 boot 写进某槽，摆脱 `fastboot boot`。需绕 AVB（`restore-259` 有改过的 abl/vbmeta 思路）——**收益中等、风险中高**，非必要不做。
  → **已打通（2026-09-29）**：**b 槽直启 Linux 成功**（自签 key `fc1e3b33…` + `vbmeta_b` flags=3），
  开机自进 Linux、~5s 到 SSH；槽位状态在 **GPT attribute** 而非 misc，已 `slot-attr.py mark-successful b` 根治（`boot_b=0x7f`）。资产/测试/回退见 `bootslot-b/README.md`，结论见 `HANDOFF §24`。
  待办：把 `add_hash_footer` 并进 `pack.sh`（以后改内核只需 `fastboot flash boot_b`）。
- **2.4 熄屏挂死取证 ✅ 已结案（2026-09-30）**：实测**根本不是 suspend**（无睡眠内核，`/sys/power/state` 为空）；
  根因是**系统 dbus 没跑 + launch-helper 权限错**（gsd-power 起不来）→ 已修，电源键双向↔醒正常。
  （历史规避 `idle-delay=0` 已不需要。）
- **2.5 充电 / 电源驱动 ✅ 已工作（2026-09-30）**：QCOM battmgr 已工作，实测电池 77% Charging（不再净掉电）。
  历史疑虑（“主线不充电”）已解除。

---

## 阶段 3 ★（硬骨头，各自独立，想做再单独立项）

| 项 | 现状 | 卡点 |
|---|---|---|
| **音频出声** | ADSP 已通 | 需自编 ALSA tplg（MI2S→aw88461）——见 `HANDOFF §15` |
| **TF 卡** | 认卡、裸读写 OK | `sdhci-msm` 的 DMA/cache 一致性 bug（buffered 写读回 CORRUPT）→ 要改内核 |
| **蓝牙配对 / 165Hz** | 部分 | `HANDOFF §9`；**触觉 ✅ 已完成**（AW86937 CONT，vk19） |

---

## 建议顺序

```
阶段 0（用户执行，~15 min + Android 初始化）
   → 阶段 1.1/1.2/1.4（我能做，改 /init + 脚本，一次重启验证）
   → 阶段 1.3/1.5/1.6（装包，需要网络）
   → 再决定 阶段 2 / 阶段 3
```

**理由**：阶段 0 是上一步手术的收尾，不做等于留个"Android 会 bootloop"的雷；
阶段 1 花小力气把设备变成"能用"，且全部复用现有 `pack.sh` 迭代链路（改镜像 → `fastboot boot` → 验证），风险低。
阶段 3 都是独立深坑，随时可单独开。
