# init/systemd vs OpenRC 调查 — 只读，2026-10-11

> 只读调查：未改 SSOT、未写设备。设备侧仅只读核实（`ssh root@192.168.7.1`，device-lock 内）。
> 证据：`archive/topics/USERLAND-STACK-2026-10-05.md`、`archive/topics/DT-UI-2026-10-05.md`、
> `PITFALLS` #89/#103/#106/#150/#164–#172/#173、`TASKS` G1-25/26/27/28、§5 Q24/Q28、`.pi/AGENT-OPS.md`。

## 0. 一句话结论

**不切。** 当前真实卡点（Q28 冷起显示、#106 进 GUI 卡死、Q24 熄屏×相机、Waydroid）**全部是内核/驱动/显示链问题**，
没有任何证据表明 systemd 能改善其中任何一条的可诊断性或修复路径；切换反而会给正在进行的
Q28「同一镜像冷起确定性门」实验**引入新的 PID1/时序变量**（#168 已把 `/init` 时序列为待定性杠杆）。
2026-10-06 既有裁决（清会话账用 greetd/phrog/elogind，不换发行版、Ubuntu 排除）**无需修正**——
且该裁决的核心动作已落地：设备上 `greetd`/`elogind` 均在跑（本次只读核实），G1-28 亮度核心链路已解。

## 1. 设备现状（只读核实，192.168.7.1，U2）

- PID1=`/init`（comm=init），`/etc/elden-init-mode=openrc` → inittab → OpenRC；无 systemd。
- `rc-status default`：dbus/elogind/greetd/seatd/iio-sensor-proxy/networkmanager/polkit/rtkit/qbootctl 全 started
  （rmtfs failed 为已知非阻塞）；`rmtfs`、`hexagonrpcd-adsp-sensorspd` 正常。
- cmdline：`clk_ignore_unused pd_ignore_unused panic=15 printk.devkmsg=on elden_nocamera=1`。

## 2. 逐卡点判断（①）

| 卡点 | 根因（已定案） | systemd 能否改善？ | 依据 |
|---|---|---|---|
| **Q28 冷起显示（NOCARD/STORM）** | 内核 DSI：~0.86s `DSI PLL lock failed`（NOCARD）/ 首条 DCS cmd-DMA hang（STORM）；无 card0 | **不能，且有害** | NOCARD 发生在 DSI host probe（用户态未起）；STORM 后的 hang 连 RAM-only 无桌面一例也冻死（#172）⇒ 与会话/init 无关。journal 换不来 card0。切换 PID1 = 给 #168 的「`/init` 时序是否杠杆」确定性实验混入新变量 |
| **#106 进 GUI 整机卡死** | 内核死挂（APSS 硬看门狗被永久禁用）；挂死时 USB gadget 消失 | **基本不能** | systemd-coredump 只抓**用户态**崩溃，抓不到内核 soft lockup/hang；已有等价或更强的自动取证：`softlockup_panic=1 + all_cpu_backtrace + panic=20 + ramoops 4MiB + pstore-catch`（TASKS §5 #106 行）——这就是「自动带回栈」的现实现，且比 coredump 覆盖内核态。systemd `RuntimeWatchdogSec` 只是用户态喂狗，喂的是被永久禁用的硬件看门狗路径，无证据可用。唯一**未证实**的小收益：journal 持久化到 /var 可能比 page-cache 吞掉的 stdout 日志（G1-33）多留死前用户态日志——无实测证据，不写成"能" |
| **Q24 熄屏×相机** | `{camcc,cambist}` 配对 + 熄屏 → RPMh `mxc.lvl` 投 0 → 硬复位（#173） | **不能** | 纯内核电源域；用户态只触发 `ScreenSaver.SetActive`。已固化互斥操作口径（`cam-mode.sh`），任何 init 都改不了 |
| **Waydroid 传感器/Play** | 容器 vendor 镜像/bionic Mesa/Play Integrity（G2） | **不能** | 与宿主 init 无关；Alpine 包本就有 openrc 服务与 `waydroid-sensors-systemd` 子包，排序差异不是卡点 |
| **G1-25/28 会话账（历史卡点）** | elogind 无 session/VT、busybox poweroff | **已解决，无需 systemd** | greetd 真会话已让 `Session.SetBrightness` 走通（G1-28 候选 A 实机取证）；关机链 `fix-logind-poweroff.sh` 已修。systemd-logind 能替代 elogind 但收益=0，代价见 §3 |
| **G1-26/27 深色/accent** | GTK3 主题名语义 | **不能** | 换 init 与 GTK 主题解析零关系 |

## 3. 切换的真实代价与风险（②）

**成本（均为重建/重验证量级）：**
1. rootfs 管线：`rootfs/fix-image-adsp.sh` 等现装 OpenRC/init.d；`scripts/openrc-enable.sh`、`/etc/elden-init-mode`、inittab 交接全部重写。
2. initramfs `/init`：需保生命线（usb0/sshd/ttyGS0）后 `switch_root` 直交 systemd，或 initramfs 内带 systemd——交接路径全部重验。
3. 会话栈：`polkit-elogind`→polkit(systemd-logind)、phosh 需 `phosh-systemd` 单元（Alpine edge 有）、greetd 配置迁移、`fix-logind-poweroff.sh` 作废。
4. **最大的隐性代价**：Q28/Q24 全部进行中的 A/B 与确定性实验（vk86/vk90–93 台架、`LOCALVERSION=-vk64` GOOD 台架）在换 PID1 后**基线作废，需全量重跑**（PITFALLS #162/#169 的教训：环境变量一变，旧 verdict 全部不可信）。

**风险：**
- **musl + systemd 是 Alpine 非官方路径**：Alpine 官方祝福的是 OpenRC(+elogind)；systemd 打包不完整、无上游支持承诺，pmOS 26.06 的 systemd 是靠整套 pmaports 设备包集成的——我们没有那套集成层。
- 回退手段：现状有天然回退（`/etc/elden-init-mode=legacy`、boot_a 备份镜像）；systemd 化一旦破坏可启动性，恢复靠 `fastboot boot` + 重打 rootfs，回退窗口比现在差。
- **区分两类问题**：既往 U1–U7 是「Alpine 用户态/会话会账 bug」（已由 greetd+elogind+fix 脚本清掉），**不是**「OpenRC 本身的问题」——把它们记到 systemd 头上是归因错误。

## 4. 对照 2026-10-06 既有裁决（③）

裁决原文：「要清会话账就换 greetd/phrog/elogind 或 pmOS/Mobian，不换发行版，Ubuntu 排除」。
**无新证据需要修正，且有两点强化：**
1. 裁决首选方案（greetd+phrog+elogind）**已在机落地**（greetd started，G1-28 核心链路已解）——无需动 init 即可继续收 Phrog/滑块 UI 联动尾。
2. `PITFALLS #172`（2026-10-10）新增证据：**RAM-only 无桌面也数秒冻死** ⇒ 当前卡点与会话栈彻底无关，进一步否定「换 systemd/换 init 对当前卡点有帮助」。

## 5. 若切要改哪些文件/步骤 + 回退（仅当未来驱动主线结束后另评）

- 步骤：① rootfs 侧装 `systemd openrc-systemd-互斥包 + polkit + phosh-systemd 单元`；② 重写 `rootfs/fix-image-adsp.sh` 为 unit 装法（脚本模板已有）；③ `initramfs/init` 改为 `switch_root` 后由 systemd 接管（保留 usb0/sshd 前置，写成 systemd 单元）；④ `scripts/openrc-enable.sh`、`/etc/elden-init-mode`、`fix-logind-poweroff.sh` 下线；⑤ **全量重跑 Q28/Q24 台架基线**（新 PID1 = 新变量）。
- 回退：另打 boot_a 镜像（OpenRC 版）；设备侧保留 `/etc/elden-init-mode` 分支机制即可双路径并存；`fastboot boot` 零写盘可随时回旧路径验证。

## 6. 建议

**不建议现在切 systemd：所有当前卡点无一条有证据能被它改善，切换只会在 Q28/Q24 实验关键期引入新变量并作废既有基线；会话账已由 greetd+elogind 清掉，保持现 Alpine+OpenRC 路径，把精力留在驱动主线（Q28/Q24）。**
