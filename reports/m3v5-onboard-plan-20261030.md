# M3-1 v5 上机实验组准备（pristine 候选）— 2026-10-30

> 角色：physical-exec L1（`.pi/ORCHESTRATION.md` 三层协议）。**本轮只准备：不重启、不刷写、不写设备文件**；所有写设备与物理动作留给下一轮用户在场执行。
> 候选基线：`build/m3v5-pristine` = pristine 24a19b953e（Linux 7.3-rc7）+ v4×3 + v5×2（HEAD 34865c8915），静态/构建门禁已全绿（`reports/m3v5-prefetch-regression-20261030.md` G1–G5）。
> 设备事实（总管 22:1x + 本轮 L2-B 23:0x 只读实测）：SSH root@192.168.7.1 可达；`uname -r` = `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk172`（钉住）；`boot_id` = `b186674c-1754-4241-898a-ab44d05bd324`；`boot_b` = vk183-fastrpc（签后 sha `aedae5f1…`，权威 `DEVICE/README.md` §1.1）。
> **已知风险（已核验）**：在机 `/lib/modules/<UTS>` 内 4 个 `.ko` 被 m3v5-f2 版替换（原件备份设备 `/root/m3modbak-20261030/`）⇒ 基线不干净，A0 臂先复原。
> 原始日志：`reports/artifacts/m3v5-onboard-20261030/`（a0-*/a1-*/lead-verify-*，边做边落盘）。

## §0 一页结论

| 项 | 结果 |
|---|---|
| A0 基线核验（L2-B） | **PASS**：判据矩阵 13/13 yes；boot_b=权威 sha；两个回退件在且 sha 前缀匹配；4 个 .ko 备份齐全（4/4 与现网不同 = pre-f2 原件在备份、f2 版在网）；slot `_b`；GPT 主/备表 sha 已留档 |
| A1 候选构建（L2-A） | **PASS（带 2 条已记录偏差）**：Image.gz/dtb/4 个 .ko/boot.img 全产出；assert ABI 27/27 ok；vermagic 候选 vs 在机 **4/4 逐字一致**；banner 无 `+` |
| UTS 策略 | **钉住现有 UTS 复用模块树：可行**（先例 vk172/173 复现成功）；两条偏差：① pristine 无 elden DTS ⇒ DTB 取 m3v5-fix 同名件；② pristine 缺下游 DSI bonded 符号 ⇒ assert DSI 锚点失败，打包以 `SKIP_KERNEL_ASSERT=1`+记录绕过 |
| go/no-go | **GO（条件式）**：见 §4；候选属**实验内核**（pristine 上游血统，非 vk183 等价替换），屏幕可能黑/触屏相机传感器缺，判据全部走 ssh/串口不依赖屏幕 |
| L1 独立复核 | boot_b sha、dwc3 备份/现网 sha、slot、boot_id、7 个产物 sha、vermagic、banner——全部重跑吻合（`lead-verify-*.log`） |

## §1 A0 基线臂定义 + 回滚资产核验（L2-B 产出 + L1 复核）

### 1.1 boot_b 当前 sha 与回退件

| 资产 | sha256（前 8 位） | 判定 |
|---|---|---|
| 设备分区 `boot_b`（`dd \| sha256sum` 实测） | `aedae5f1`…`4765` | = `DEVICE/README.md` §1.1 权威（vk183-fastrpc）✅ |
| 主机 `bootslot-b/boot_b-pre-vk183-20261030.img` | `e6b1124c`…（= m3v5-f2 签后件） | 在 ✅ |
| 主机 `bootslot-b/boot_b-vk181-daily-signed-20261029.img` | `b72866ef`…（= 日常内核） | 在 ✅ |
| 主机 `out/boot-elden-vk183-fastrpc.img` | `30e6a4c4`…（AVB 原像） | 在 ✅ |
| `bootslot-b/boot_b.img`（可变工作副本） | = vk183 现值 | ⚠️ 禁当回退件（`doc-audit-20261030` P0-2） |

**当前槽位**：`_b`（`qbootctl`，`_a`/`_b` 均 Successful+Bootable）。**基线定义**：干净基线 = boot_b(vk183) + `/lib/modules/<UTS>` 内 4 个 `.ko` 为 `/root/m3modbak-20261030/` 原件。

### 1.2 设备 4 个 .ko：备份原件 vs 现网（yes/no 表）

| 模块 | 备份 sha（/root/m3modbak-20261030/…） | 现网 sha（/lib/modules/<UTS>/…） | 相同 | 备份大小 |
|---|---|---|---|---|
| dwc3.ko | `c694eeac3fdb9d8d…` | `528d4dd89ff8b91d…` | **no** | 304 400 |
| dwc3-qcom.ko | `3c114021f22e6407…` | `7bff9135121c712c…` | **no** | 22 896 |
| typec_ucsi.ko | `9992946493eb7532…` | `b1bcaa382e44b59d…` | **no** | 88 824 |
| ucsi_glink.ko | `4bfa8835e57aab70…` | `1d242230700970e1…` | **no** | 18 944 |

判读：4/4 不同 = 备份是 pre-f2 原件、m3v5-f2 版仍在网（符合预期）。注：现网文件名是 `dwc3-qcom.ko`（连字符），备份保持设备目录结构 `drivers/usb/...`。A0 复原后以备份 sha 为判据。L1 已抽验 dwc3.ko 双侧 sha 吻合。

### 1.3 GPT/槽位只读快照（留档，未做任何写）

- GPT 主表（bs=4096 count=35）sha256 = `6afbaa756a1d30a5…432047`；备用表（尾部 34×4096B）= `c08bbcc4d5c6ef5a…8676f3`（首次备用表 dd 偏移按 512B 扇区算错，已按 `SIZE/8-34` 修正重跑，见 a0-gpt.log）。
- 分区表：18 分区，`linux17/linux18` 各 96G，空闲 1GiB；无异常。证据 `artifacts/a0-gpt.log`。
- 复现：`scripts/device-lock.sh -w 300 ssh root@192.168.7.1 "<上列只读命令>"`。

## §2 A1 候选内核构建（build/m3v5-pristine，L2-A 产出 + L1 复核）

### 2.1 UTS 策略：钉住现有 UTS 复用模块树 —— **可行（带 2 条偏差）**

- 做法（复现 vk172/173 先例）：`.config` 取 `build/m3v5-daily/.config`，`CONFIG_LOCALVERSION="-debug-vk127-00002-g24223e44ad80-dirty-debug-vk172"`（daily 自带、与在机 `/lib/modules` 目录名逐字一致），`LOCALVERSION=` 空环境防 `+`（`PITFALLS` #384 口径），`make olddefconfig` **必须带 `ARCH=arm64`**（#57）。
- 证据：olddefconfig 相对 daily 掉 5 个 `=m` 项（TOUCHSCREEN_NOVATEK_NVT36XXX_SPI / REGULATOR_WL2868C / VIDEO_GC08A8 / VIDEO_S5KJNS / VIDEO_GT9764；GUNYAH 本就 n 非掉项）；`check-abi-config.sh` rc=0 **27/27 ABI 敏感项一致**；4 个候选 `.ko` vermagic 与在机逐字一致（下表）；banner 无 `+`。
- **风险敞口（如实写明）**：MODVERSIONS 未开，UTS 同串不同树的结构体错位（#62/#83）仅由 27 项 ABI 锚点兜底；pristine 与在机模块树血统不同（m1-73 下游 vs pristine 上游），**候选属实验内核，非 vk183 等价替换**。
- 两条偏差：① pristine 无 elden DTS ⇒ `DTB_FILE` 用 m3v5-fix 的 `sm8750-lenovo-elden.dtb`（dtb 是数据侧、m1-73 血统，上游内核会忽略下游属性，实验组合可接受，已记录）；② pristine 上游 msm 无下游 bonded DSI 符号 ⇒ assert DSI 锚点失败，打包以 `SKIP_KERNEL_ASSERT=1` + 本记录绕过（其余锚点全过）。pristine `mhi_wwan_ctrl.c` 含历史 typo + ICE ⇒ 已在 `.config` 关 `CONFIG_MHI_WWAN_CTRL` 后重建。
- 完整模块树备胎方案（若上表 4/4 任一失配即启用）：`/tmp/m3v5pristine-mods` 已产出 **1632 个 .ko，1.9G，tar.gz 579M**，`modules_install` rc=0；部署时间 ≈ scp+depmod 数分钟。本轮**未部署**（写设备留给下轮）。

### 2.2 产物与 sha256（out/m3v5-onboard/，L1 逐个复核）

| 产物 | 大小 | sha256 |
|---|---|---|
| Image.gz | — | `513db6c9a6e20591…93f7930f359` |
| sm8750-lenovo-elden.dtb | — | `0b614a3c58430280…a9a308` |
| typec_ucsi.ko | — | `8c0694e9efd1dffb…565d01db` |
| ucsi_glink.ko | — | `6b6049ad7a4c3a29…868dbf2a5` |
| dwc3.ko | — | `4a5b4365b534c98b…dda467ea` |
| dwc3-qcom.ko | — | `50875e2877c0ce36…f182156820c` |
| boot-elden-m3v5-onboard.img | 84 496 384 B | `b24a64bb2475b51b…1652b66`（未签名；`fastboot boot` 不需要签） |

构建 rc=0，`warning:`/`error:` = 0（a1-build.log）；manifest `kernel_release_matches_image=yes`。

### 2.3 assert-kernel-sane 结果

rc=0（SKIP 下）：config 锚点 ok / System.map ok / UTS 对齐 ok（需 `LOCALVERSION=` 传环境）/ 非陈旧 ok / **ABI 27/27 ok**；唯一 FAIL = DSI 锚点（pristine 血统真实差异，非构建错误，见 §2.1 偏差②）。日志 `a1-assert.log`。

### 2.4 vermagic 对比表（候选 4 个 .ko vs 在机模块树）

| 模块 | 候选 vermagic | 在机 vermagic | 逐字相同 |
|---|---|---|---|
| typec_ucsi.ko | `…-g24223e44ad80-dirty-debug-vk172 SMP preempt mod_unload aarch64` | 同 | **yes** |
| ucsi_glink.ko | 同上 | 同 | **yes** |
| dwc3.ko | 同上 | 同 | **yes** |
| dwc3-qcom.ko | 同上 | 同 | **yes** |

4/4 逐字一致（双侧 `modinfo -F vermagic`，L1 复核 4/4 吻合）；在机 `/proc/version` = 同串无 `+`。日志 `g7-host-vermagic.txt` / `g7-device-vermagic.txt` / `g8-banner.txt`。

## §3 臂矩阵

> 通用前置（每臂开工前过一遍）：① `scripts/device-lock.sh` 持有；② `scripts/trial.sh gate` 0/3（FAIL 即停）；③ 设备 ssh 可达。fastboot 一律**逐条**（#3）；零写盘优先 `fastboot boot`（#92/#93：持久变体才有功能级验证）；本机 ABL 无 `fastboot fetch`（#290），备份一律设备侧 `dd`。

### A0 基线复原（把 4 个 .ko 换回原版并核对 vk183）——写盘（模块+depmod），无物理动作

- 前置：§1.1/§1.2 全 yes；`/root/m3modbak-20261030/` 4 件在。
- 命令（逐条）：
  1. `ssh root@192.168.7.1 'mkdir -p /root/m3v5f2cur-20261030 && cp -a --parents /lib/modules/<UTS>/kernel/drivers/usb/dwc3/dwc3.ko /lib/modules/<UTS>/kernel/drivers/usb/dwc3/dwc3-qcom.ko /lib/modules/<UTS>/kernel/drivers/usb/typec/ucsi/typec_ucsi.ko /lib/modules/<UTS>/kernel/drivers/usb/typec/ucsi/ucsi_glink.ko /root/m3v5f2cur-20261030/'`（先把 f2 现网版备份走，A4 要用）
  2. `ssh root@192.168.7.1 'cp -a /root/m3modbak-20261030/drivers/usb/dwc3/dwc3.ko /lib/modules/<UTS>/kernel/drivers/usb/dwc3/'`（4 个模块逐条同型）
  3. `ssh root@192.168.7.1 'depmod -a 7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk172'`
  4. `ssh root@192.168.7.1 'sha256sum /lib/modules/<UTS>/kernel/drivers/usb/dwc3/dwc3.ko'`（4 个逐一，比对 §1.2 备份 sha）
- 判据：4/4 sha == 备份 sha；`lsmod` 行数不异常；ssh 存活。**注**：换 `.ko` 不影响当前已加载模块，重启后才生效；boot_b 未动（仍是 vk183），**A0 后设备重启即回干净基线**。
- 停止条件：任一 sha 不匹配、`depmod` 报错、ssh 失联 ⇒ 停，保留现场，回总管。
- 物理动作：无。

### A1 零写盘 `fastboot boot` 候选件 —— 写盘仅限模块预置；boot 本体零写盘

- 前置：A0 已做（含 f2 版备份到 `/root/m3v5f2cur-20261030/`）；主机 `out/m3v5-onboard/` sha 复核过；`scripts/trial.sh gate` 通过。
- 命令（逐条）：
  1. 模块预置（写盘）：把 `out/m3v5-onboard/{typec_ucsi,ucsi_glink,dwc3,dwc3-qcom}.ko` scp 到设备对应 `/lib/modules/<UTS>/kernel/...` 路径（先 `cp -a` 存 `~/.bak`），sha256sum 校验 == §2.2，`depmod -a <UTS>`（#74：udev 会按 modalias 自动加载，本实验正是要它）。
  2. `ssh root@192.168.7.1 'reboot bootloader'`（设备已 uptime 3h+，非刚复位场景，不触 #368；预期 USB 掉线 ~10 s）
  3. 主机 `fastboot devices`（逐条；预期列出序列号）
  4. 主机 `fastboot boot out/m3v5-onboard/boot-elden-m3v5-onboard.img`（**不写盘**；预期 `Booting OKAY` 后 USB 变 `1d6b:0104`，**60–90 s 才重新枚举**，#391）
  5. `ssh root@192.168.7.1 'uname -v; cat /proc/sys/kernel/random/boot_id; lsmod | wc -l'`
- 判据：新 `boot_id`；`uname -v` ≠ vk183 的 `#1 … 19:00:42`（候选构建时间戳）；banner 版本串仍 = 钉住 UTS；ssh 存活；`dmesg` 无 `Call trace`/`BUG:`。
- 停止条件：`fastboot devices` 空 >60 s（#368 处置 → 用户 POR，见 §4 U1）；boot 后 180 s ssh 不通 ⇒ POR 一次重试，再失败执行 A4。
- 物理动作：仅失败兜底时（U1）。

### A2 功能臂：双口 role switch —— 前置 = A1 成功启动候选

- 布点（ssh，逐条；tracer=nop）：
  1. `ssh root@192.168.7.1 'cd /sys/kernel/tracing && echo nop > current_tracer && echo "p:usbrole usb_role_switch_set_role sw=\$arg1 role=\$arg2" > kprobe_events && echo 1 > events/kprobes/usbrole/enable'`
  2. 持久写盘（#363：不用 nohup，后台循环自写）：`ssh root@192.168.7.1 'rm -f /root/usbrole.log; (while true; do cat /sys/kernel/tracing/trace_pipe >> /root/usbrole.log 2>/dev/null; sleep 2; done) & echo started'`
  3. 基线计数：`dmesg | grep -icE 'PPM init'; dmesg | grep -icE 'failed to get usb role switch'`（在机基线 = 0/0）
- **用户插拔（U2，物理动作）**：长边口拔→插一次、短边口拔→插一次，每次间隔 ≥20 s。
- 判据（ssh 取证）：
  - `/sys/class/typec/` 含 `port0`、`port1`、`port1-partner`（partner 节点随插拔出现/消失）；`cat port0|port1/{data_role,power_role}` 随插拔翻转；
  - `/sys/class/udc/a600000.usb/state` 变化（configured↔not attached）；
  - `wc -l /root/usbrole.log` >0 且 role 明细含 `host`/`device` 两侧；`usb_role_switch_set_role` 命中次数 ≥ 插拔次数；
  - `PPM init` / `failed to get usb role switch` 计数 = 0（f2 修复语义保持）。
- 停止条件：kprobe 注册失败（符号不在 ⇒ 降级方案：轮询 `/sys/class/typec/*/{data_role,power_role}` 到 `/root/usbrole.log`，判据同）；port0/port1 缺任一 ⇒ 停，回 A4，绑定性结论记「未上机」。

### A3 冷 POR —— 用户动作（U3）

- 前置：A2 取证已 `scp` 回主机；设备当前态已记录（boot_id/uptime）。
- 命令：用户断电（长按电源 ~10 s 或拔线）→ 等 30 s → 开机。
- 判据：≤180 s ssh 恢复；`boot_id` 换新；`uname -v` 仍为候选（RAM 内核已去、应回 **vk183**：`#1 SMP PREEMPT Fri Oct 30 19:00:42`）；4 个 `.ko` 现网 sha == A1 预置版（磁盘未动）或 == A0 原件（若 A1 未预置）；`scripts/trial.sh record --reset cold` 落 record。
- 停止条件：180 s 不通 ⇒ 用户再 POR 一次；仍不通 → EDL/串口升级路径（`RUNBOOK-BRINGUP`）。

### A4 回滚 —— 写盘（视情况含刷写），恢复路径两条

- **路径①（首选，不刷写）**：boot_b 仍是 vk183（A1 `fastboot boot` 未写盘）⇒ 只恢复模块：把 A1 预置的候选 4 `.ko` 换回 `/root/m3modbak-20261030/` 原件（或按需回 f2 版 `/root/m3v5f2cur-20261030/`），`depmod -a`，`reboot` → 干净 vk183 基线。判据：`uname -v` = vk183、4 sha == §1.2 备份 sha、typec 端口在。
- **路径②（boot_b 被标 unbootable / 需刷回，先备份）**：`dd if=/dev/disk/by-partlabel/boot_b | 收回主机留档`（备份手段 #290）→ `fastboot flash boot_b bootslot-b/boot_b-pre-vk183-20261030.img`（**逐条**）→ 读回 sha == `e6b1124c…`（写后读回校验）→ 重启。
- 停止条件：flash 后读回 sha 不符 ⇒ 停，保留现场，上报。

## §4 go/no-go 表 + 一次性执行单

### go/no-go（下一轮执行前逐行过）

| # | 条件 | 状态 |
|---|---|---|
| 1 | boot_b = 权威 vk183 sha | ✅ GO |
| 2 | 两个回退件在（pre-vk183 / vk181-daily） | ✅ GO |
| 3 | 4 个 .ko 原件备份齐全且 sha 对上 | ✅ GO |
| 4 | 候选 Image/dtb/4 .ko/boot.img sha 复核 | ✅ GO（L1 独立复核） |
| 5 | vermagic 4/4 + ABI 27/27 | ✅ GO |
| 6 | GPT/槽位快照留档 | ✅ GO |
| 7 | device-lock / trial gate 通道 | ✅ GO |
| 8 | 已知风险敞口 | ⚠️ 条件项：候选为 pristine 血统 ⇒ 面板可能黑（缺 bonded DSI）、触屏/相机 sensor/WL2868C 稳压器 5 个 `=m` 缺失；**A1/A2 判据全部走 ssh/串口，不依赖屏幕**；异树模块 #83 风险由 27 锚点兜底、失败表现预期为 probe 失败/trace，出现 `list_del corruption` 类即立即 A4 |

### 用户在场动作一次性执行单

| # | 动作 | 时机 | 预期现象 | 失败处置 |
|---|---|---|---|---|
| U1 | 物理按键进 fastboot（音量下+电源，仅当 `reboot bootloader`/fastboot 枚举失败兜底） | A1 步骤 2–3 失败时 | 屏幕出 fastboot 菜单；主机 `fastboot devices` 列出 | 仍无 → POR（断电 30 s 开机），回报 |
| U2 | 双口插拔：长边口拔→插、短边口拔→插（各一次，间隔 ≥20 s） | A2 布点完成后 | 插入时 partner 节点出现、role 翻转；拔出时消失 | `usbrole.log` 无新增行 ⇒ 停止插拔，保留现场，走 A4 |
| U3 | 冷 POR：断电 → 等 30 s → 开机 | A2 取证完成后 | 开机 ≤180 s ssh 恢复、面板出 vk183 | 180 s 不通 → 再 POR 一次；仍不通 → 升级 |
| U4 | 硬断电（设备不回退/`reboot` 挂死时） | 任意臂异常 | 断电后 USB/串口全静 | 30 s 后开机走 A4 路径② |

引用：`PITFALLS` **#3**（fastboot 逐条，禁批量封装）、**#368**（早期 `reboot2` 下发 ⇒ USB 全不枚举，只能人工断电）；连带 #391（`fastboot boot` 后 USB 变 `1d6b:0104` 且 60–90 s 才枚举，别误判硬挂）、#92/#93（功能级测试必须持久变体）、#290（无 `fastboot fetch`，备份用设备侧 `dd`）、#74（模块进持久根会被 udev 自动加载）、#62/#83（vermagic 同串≠同构建，异树风险敞口）。

## §5 编排记录

- 2 个 L2 同步派发（`Promise.allSettled`，无 background）：L2-A=`impl-worker`（A1 构建+vermagic），L2-B=`verify-worker`（A0 只读预检），`custom.ustc-pool/ustc-worker`，23:06 双双返回。
- ⚠️ 两个 L2 的 `agents.run` 返回 `status=completed` 但 result 文本为**空**（重演 ORCHESTRATION §7「自报不可信」；本轮产物经 ls/read 验证为真实存在，但回执通道不传文本）⇒ L1 按 `ls`/`read` + 独立重跑关键门验收：产物 sha ×7、vermagic ×4、banner、manifest、设备 boot_b/dwc3 双侧 sha、slot、boot_id 全部亲自重跑吻合（`lead-verify-sha.log` / `lead-verify-device.log`）。
- 本轮硬边界遵守：设备侧仅只读命令（uname/dd|sha256sum/sha256sum/lsmod/dmesg/cat/qbootctl 读/sgdisk -p），零 reboot/flash/写设备文件；boot_b/槽位/GPT 未改。

---

## §6 A1 实测结果（2026-10-30 23:31–23:52，总管执行；判据 FAIL/未证实）

> 说明：本节由总管在准备 lane 之外直接执行（用户「设备就绪、循序渐进、只在需要用户干预处停」）。
> 原始证据：`reports/artifacts/m3v5-onboard-20261030/{a0-restore,a1-deploy-ko,a1-fastboot-boot,a1-failure-evidence,a4-restore-baseline}.log`。

### 6.1 实际执行序列

| 步 | 动作 | 结果 |
|---|---|---|
| A0 | 备份当前 4 个 `.ko` → `/root/m3v5f2cur-20261030/`，再从 `/root/m3modbak-20261030/` 复原原件 + `depmod` | **OK**，4/4 sha 回到备份值（`c694eeac…`/`3c114021…`/`99929464…`/`4bfa8835…`） |
| A1-a | 把 `out/m3v5-onboard/*.ko`（候选）scp 到设备并覆盖同 4 个路径 + `depmod` | **OK**，设备侧 4/4 sha = 候选 sha（`4a5b4365…`/`50875e28…`/`8c0694e9…`/`6b6049ad…`） |
| A1-b | `fastboot boot out/m3v5-onboard/boot-elden-m3v5-onboard.img`（sha `b24a64bb…`，零写盘） | **`Sending OKAY / Booting OKAY`**；`product=elden_prc_wifi`、`unlocked=yes`、`slot=b` |
| A1-c | 等待 SSH 重新枚举（180 s + 追加轮询） | **FAIL**：始终超时；`lsusb` 无平板设备；用户目视 = **卡在联想 logo** |
| A4-a | 用户长按电源强制关机 → 正常开机 | **回到 vk183**：`uname -v = #1 SMP PREEMPT Fri Oct 30 19:00:42 CST 2026`，新 `boot_id = f2f62012…` |
| A4-b | 从 `/root/m3modbak-20261030/` 复原 4 个 `.ko` + `depmod` | **OK**，4/4 sha = 原件（基线复原） |

**当前状态**：`boot_b` 未动（= vk183，`aedae5f1…`）；`/lib/modules/<UTS>` 4 个 `.ko` = 原件；设备正常运行 Debian。**没有写盘副作用遗留**（除 `/root/` 下两份备份目录，属计划内）。

### 6.2 判据与结论

- 判据（§3 A1）：新 `boot_id`、`uname -v` 变化、banner 仍为钉住 UTS、SSH 存活、dmesg 无 `Call trace`/`BUG:` ⇒ **全部未取得**（连 USB 枚举都没有）。
- **结论：A1 = 未通过（启动期即失联，根因未证实）**。不能据此否定 v5 代码：候选是 **实验内核**（pristine 上游血统、缺下游 DSI、config 掉 5 个 `=m`），失败可能是打包/实验台架问题。

### 6.3 证据边界（为什么根因仍未定）

1. **串口没有抓到这一发**：主机在 23:36 前后重启，`elden-serial-logger` 在 23:43:36 才重新 open；且 `/var/log/elden-serial/ttyACM0.log` 自 2026-10-24 起就没有内核输出（今天只有 open/closed 标记）⇒ 可能日志端口（ACM0）不是控制台端口（另有 ACM1），**串口通道本身待确认**。
2. **pstore 空**：`/sys/fs/pstore/` 无条目（DTS 无 `ramoops record-size`，早前已登记），拿不到 panic 记录。
3. **候选内核与 initramfs 不配套（首要可疑点）**：候选 `.config` 里 `CONFIG_USB_DWC3=m`、`USB_DWC3_QCOM=m`、`TYPEC_UCSI=m`、`PHY_QCOM_QMP_COMBO=m`，而本次用的 `out/initramfs-full-elden.cpio.gz` 内**不含任何 dwc3/ucsi/phy 模块**（仅 10 个 `.ko`），cmdline 又带 `elden_early_gadget=1` ⇒ early gadget 阶段无模块可用，USB 全程不枚举与现象一致；显示侧还叠加 pristine 缺下游 DSI（本就预期黑屏/停在 OEM logo）。

### 6.4 下一发的必要条件（复启判据）

1. **先验串口**：确认哪个 `/dev/ttyACM*` 是内核控制台（需 sudo 读口或改 logger 端口），并做一次**已知良好内核**（vk183 正常重启）的抓取验证；未验证串口前不再盲试。
2. **内核 + 模块 + initramfs 三者配套**：改用 `build/m3v5-pristine` 自己的模块树（已产出 1632 `.ko` / 579M tar），并**用不同 UTS**（如 `-m3v5x1`）落到独立 `/lib/modules/<新UTS>`，避免覆盖日常模块树；initramfs 要么内嵌该 UTS 的启动必需模块，要么去掉 `elden_early_gadget=1` 让 udev 在 switch_root 后加载。
3. **判据去显示依赖**：全部走串口 + USB 网络；显示失败不计入 A1 判据（候选缺 DSI 是已知偏差）。
4. 仍坚持零写盘 `fastboot boot`；A2 插拔/A3 POR 由用户执行。

---

## §7 第二发（2026-10-31 上午，m3v5-onboard-b）：P1–P5 全过，P6 再败 —— USB 仍零枚举，根因仍不在 early gadget 缺模块

> 执行：physical-exec L1 + 2 L2 同步派发（本节由 L1 落盘）。原始证据：`reports/artifacts/m3v5-onboard-20261030b/`。

### 7.1 P1–P5 结果（全部 PASS，L1 独立复核）

| Gate | 结果 | 关键数字 |
|---|---|---|
| P1 模块清单 | ✅ | gadget 最小集闭包 **14 个 .ko**（核心 7：dwc3/dwc3-qcom/qmp-combo/qmp-usb/aux-bridge/typec_ucsi/ucsi_glink；ucsi_glink 依赖闭包追加 pmic_glink、rpmsg_core、pdr_interface、qcom_pdr_msg、qmi_helpers、glink_smem 等）；`p1-modlist.log` |
| P2 initramfs | ✅ | `out/initramfs-m3v5x1.cpio.gz` sha `de859e0c…`；解包 .ko=14；`modules.dep` 含 dwc3；**init sha 未变**（diff 空）；并修 initramfs 内 `usr/local/sbin/usb-gadget`（非 SSOT）在 wait_udc 前 modprobe 上述模块 —— 这是新发现：**/init 无任何模块加载机制，只塞 .ko 不会自动加载** |
| P3 打包 | ✅ | `out/boot-elden-m3v5-onboard-b.img` 88 260 608 B，sha `a144e5ce…`；manifest ramdisk 回读 sha 与源一致；cmdline 含 `elden_early_gadget=1 elden_q28_nowd`；SKIP_KERNEL_ASSERT=1（DSI 锚点已知偏差） |
| P4 模块树 | ✅（UTS 抉择=复用） | `/tmp` 已被清 ⇒ 重建 staging（`make modules_install` 仅 2 s，1632 .ko），tar 1.9 G 存 `…b/m3v5pristine-mods.tar`；独立 UTS 方案作废（>40 min 全量重建且作废 A1 pinned-UTS Image/ABI 27 锚点） |
| P5 设备部署 | ✅ | 整树备份 `/root/m3mods-daily-20261031.tar`（109 MB，双侧 sha `ae1dd534…` 一致 + 主机留档）；4 个候选 .ko 部署后 sha 4/4 == `out/m3v5-onboard/*.ko`；`depmod -a` ok；未重启、未刷写 |
| trial gate | ✅ | GATE=OK；boot_b succ=1 |

### 7.2 P6 实测（10:26–10:32）：FAIL，与第一发同一失败模式

1. `reboot bootloader` → `fastboot devices` 出 `HA2EXB0E`；`fastboot boot out/boot-elden-m3v5-onboard-b.img` → `Sending OKAY / Booting OKAY`。
2. SSH 轮询 300 s+ **不通**；`lsusb` **无平板设备（连 1d6b:0104 gadget 都没有）**。
3. 串口（ttyACM0 = ttyGS0 gadget 控制台）新增仅 32 行 = **旧内核（vk183）shutdown 过程** + `serial closed`，**候选内核零输出**（gadget 没起来 ⇒ ttyGS0 控制台不存在，符合闭环）。`p6-serial-delta.log`。

### 7.3 判读（重要：本发已排除一个假设）

- 本发 initramfs **已含** gadget 全套模块且 usb-gadget 会主动 modprobe，early gadget 仍零枚举 ⇒ **「initramfs 缺 dwc3 模块」不是（唯一）根因**。失败在更早环节：候选内核在 gadget probe 前已死/挂，或 pristine 内核对 SM8750 平台基本启动（时钟/pinctrl/内存）就有问题。
- 串口通道受制于同一 gadget（ttyGS0），设备失联时**没有任何独立观测面**（无外部 UART、pstore 无 ramoops）——这是结构性的取证盲区。
- 下一发前置：**先验平台最小可启动性**（pristine + 最小 config + `earlycon`/纯 RAM busybox 变体 + 不依赖 gadget 的观测），或先在 QEMU/无设备侧排除 v5 补丁 panic。在拿到独立于 USB 的观测面前，继续 `fastboot boot` 无信息量。

### 7.4 现场与恢复

- 零写盘：boot_b 未动（仍 vk183 `aedae5f1…`）；设备停在候选内核（黑屏/无 USB）。**恢复 = 用户长按电源 ~10 s 强制关机 → 再开机**，即回 vk183 基线（`/lib/modules` 4 个 .ko 当前为候选版，回基线后如需干净可从 `/root/m3mods-daily-20261031.tar` 或 `/root/m3modbak-20261030/` 复原 + `depmod -a`）。
- record：`reports/trials/20261031T023348Z-m3v5-onboard-b-fastbootboot.json`（verdict=fail, reset=warm）。

### 7.5 恢复实测（总管，2026-10-31 10:40–10:45）

- 用户长按电源 → 正常开机后：`uname -v = #1 SMP PREEMPT Fri Oct 30 19:00:42 CST 2026`（vk183）、新 `boot_id = 34244956…`、SSH 正常。
- **模块树已整树回滚并核验**：用设备的 `/root/m3mods-daily-20261031.tar`（sha `ae1dd534…`，与主机留档一致）解回 `/lib/modules/<UTS>` + `depmod -a` rc=0；`.ko` 计数 **1639**；4 个关键模块 sha 全部回到日常原件（`c694eeac…`/`3c114021…`/`99929464…`/`4bfa8835…`）。证据 `reports/artifacts/m3v5-onboard-20261030b/rollback-modules.log`。
- 主机侧留档：`backup/m3v5-onboard-20261031/m3mods-daily-20261031.tar`（109 MB，不入 git）；1.9 G 的 staging tar 已删（`make modules_install` 2 s 可重建）。
- **结论：设备已回到完全干净基线**（boot_b vk183 + 日常模块树 + ssh/typec 正常）。
