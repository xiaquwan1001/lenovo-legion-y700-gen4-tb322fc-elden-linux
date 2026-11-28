# iio-sensor-proxy 3.9：claim 竞态 + ALS 抖动 两条补丁与 arm64 deb（2026-11-28，lane S2 后续）

> 边界：**本轮零设备写入**。对设备只做只读查询（`ssh elden` 的 `objdump/dpkg-query/journalctl/sha256sum/cat`），
> 未装包、未重启任何服务、未改 udev/systemd/SSC。`--apply` **未执行**。仓内写入仅三处：
> `patches-userland/iio-sensor-proxy-20261128/`、`scripts/deploy-iio-sensor-proxy-patches.sh`、本文件。
> 无 git commit。外部命令一律 `timeout -k`。构建槽位：`build-slot take y700-elden:iio-proxy --jobs 8` → 用完 `drop`。
> 前置结论沿用 `reports/sensors-orientation-als-20261128.md` §1/§3（未重推）；本轮的**新**证据是 §1.2 那段真实 trace。

---

## §0 结论

| # | 派工项 | 结论 | 状态 |
|---|---|---|---|
| 1 | 缺陷 A（claim 竞态）补丁 | `Claim*()` 在 discovery 完成前**挂起**，发现完成后转成真 claim（登记 client、启采样、首读数后才回 invocation）；类型确实不存在时回 `G_DBUS_ERROR_NOT_SUPPORTED` | **PASS（已出补丁 + 交叉编过）** |
| 2 | 缺陷 B（ALS 抖动）补丁 | deadband `max(20 lux, 5%)` + ≥10 lux 持续 >1 s 生效 + **≤1 次/10 s、≤6 次/60 s** 硬预算；≥100 lux 真实变化 2 s 内放行；**首读无条件上报** | **PASS（已出补丁；用设备真实 trace 反演：282 → 6 次/60 s）** |
| 3 | arm64 deb | `iio-sensor-proxy_3.9-2elden_arm64.deb`，`file` = ARM aarch64，最高 GLIBC 符号 **2.38 ≤ 2.41**，`NEEDED` 与在机原件 **9/9 逐项一致** | **PASS** |
| 4 | 部署/回滚脚本 | `scripts/deploy-iio-sensor-proxy-patches.sh`：`--check` 只读自检、`--apply`（root+`CONFIRM=yes`）、`--rollback`（`apt-get install --reinstall iio-sensor-proxy=3.9-1`） | **PASS（本轮只跑 `sh -n` 与非 aarch64 拒跑门禁）** |
| 5 | 修法是否依赖 gsd-power 重启 | **不依赖**：代理重启后 gsd-power 会**自己**重新 `ClaimLight`（16:57:40 同一秒实证，claim 早于 discovery），补丁正是接住这一次 | **PASS（含 phosh 的例外，见 §6）** |

---

## §1 改前/改后行为判据

### 1.1 改前：这次拿到了**真实**抖动数字（上一轮取不到的部分）

`reports/sensors-orientation-als-20261128.md` §3.3 当时只能写"链路断、上报 0"，因为 ALS 在本 boot 大部分时间没被 enable。
本轮只读复查发现设备上 **18:04:21 起 ALS 真的跑起来了**（`Enabling sensor (…165) in 'on-change' mode`，随后 `Message 1025`
持续流入），到 18:09:44 客户端 `ReleaseLight` 才停。这段（301 s）完整落在 journal 里，可以当"改前"的权威口径：

| 指标 | 命令（只读） | 实测（18:04:42–18:09:43） |
|---|---|---|
| 驱动样本数 | `sudo journalctl -u iio-sensor-proxy --since 18:04:42 --until 18:09:43 \| grep -c "Light level sent by driver"` | **1507 条 / 301 s ≈ 5 Hz** |
| **代理上报次数/60 s** | `… --since A --until A+60s \| grep -c "Emitted light changed"`（取 3 个连续窗口） | **282 / 282 / 282** |
| 上报总数 | `… \| grep -c "Emitted light changed"` | **1410 / 301 s** |
| 不同 lux 值 | `… \| sed 's/.*applied): \([0-9.]*\).*/\1/' \| sort -u \| wc -l` | **31 个，0–544 lux** |
| 量化 | 相邻不同值差 | 16 lux |

⇒ 事实钉死：代理 3.9 是**逐样本直通**（≈282/60 s，且 1410/1507 = 94% 的样本都触发了一次 D-Bus 事件）。
这与上一轮"286 次跳变/60 s"的口径一致，现在有了 journal 级证据 + 原始序列落盘
（`patches-userland/iio-sensor-proxy-20261128/artifacts/trace-before-device-20261128.txt`，1507 行）。

### 1.2 判据表（沿用 §3.3，补"期望值"与"依据"）

| 指标 | 采集命令 | 改前（本轮实测） | 目标 | 补丁后（主机侧反演/预期） |
|---|---|---|---|---|
| SSC 层 lux 跳变次数 | `timeout -k 5 62 ssccli --sensor light --timeout 60 \| awk 'NR>1&&$NF!=p{c++}{p=$NF}END{print c+0}'` | 286（上轮）/ 282（本轮代理侧） | 不变（传感器层不改） | 不变 |
| 代理上报次数/60 s | `sudo journalctl -u iio-sensor-proxy --since "-1min" \| grep -c "Emitted light changed"` | **282** | **≤ 6** | **6**（用 1.1 的真实 trace 逐样本反演，见 §3） |
| `LightLevel` 唯一值数/60 s | `sudo dbus-monitor --system "type='signal',sender='net.hadess.SensorProxy'"` | 31（同一窗口） | ≤ 6 | ≤ 6（= 上报次数，属性只在放行时更新） |
| 背光写入次数/60 s | 100 ms 轮询 `/sys/class/backlight/aw99706-backlight/brightness` | 本 boot 那段窗口内 **0**（gsd 未把该 lux 流落到背光；链路另有一层断，见 §7） | **≤ 2** | **≤ 6 硬上限**；典型 1–2（去抖后值基本不变），**未上机实测** |

口径提醒（沿用上轮）：`dbus-monitor` 必须 root；`LightLevel` 是单播 `PropertiesChanged`，非 root 看不到。

---

## §2 补丁 0001：claim 竞态

文件：`patches-userland/iio-sensor-proxy-20261128/0001-claim-race-defer-Claim-until-discovery-finished.patch`
diffstat：`1 file changed, 188 insertions(+), 14 deletions(-)`（仅 `src/iio-sensor-proxy.c`）

### 2.1 根因（一句话复述，不重推）

D-Bus 名字在 `name_acquired_handler()` 里**先**被客户端看见，`find_sensors()` **后**跑。这中间到达的
`ClaimLight` 命中 `driver_type_exists()==FALSE` 分支：回成功、不启采样，**却已经把 sender 记进 `clients[]`**，
于是之后每次 claim 都 `already claimed device, no-op`，客户端没有理由重试。设备实证（本轮只读复核，同一秒）：

```
16:57:40 Handling driver refcounting method 'ClaimLight' for ambient light sensor device
16:57:40 Discovered 'ambient_light' sensor (5230347032368999062 3046173514946711665)
16:57:40 Found device /sys/devices/virtual/misc/fastrpc-adsp of type ambient light sensor at SSC light sensor
```

### 2.2 改法

1. `bus_acquired_handler()` 里就把 `sensor_startup_dbus_invocations_delayed[]` 和新增的 `pending_claims[]` 建好
   （原代码在 `name_acquired_handler()` 里才建 —— 那正是竞态窗口的起点）。
2. `Claim*()`：sender 已在 `clients[]` → 仍然 no-op 成功（幂等不变）；**类型尚未发现 → 进 `pending_claims[]` 挂起，
   不回 invocation、不写 `clients[]`**。
3. discovery 结束（`name_acquired_handler()` 末尾）/热插拔 `add`：`pending_claims_start()` 把挂起的 claim
   转成真 claim —— 每个 sender 只登记一次 watch、放进 delayed invocation 列表、
   `driver_set_polling(TRUE)`；**invocation 仍按上游契约在首个读数后才回**。
4. discovery 结束但该类型真的不存在 / 传感器被移除：`pending_claims_fail()` 回 `G_DBUS_ERROR_NOT_SUPPORTED`，
   客户端可重试 —— 而不是像原来那样"假装成功"。
5. `Release*`：先 `pending_claim_remove(..., TRUE)` 把挂起项撤销并按旧语义回成功；`client_vanished` 则丢弃（不回）。

### 2.3 为什么这样不破坏"真 claim"的幂等语义

| 场景 | 3.9 原行为 | 补丁后 | 是否等价 |
|---|---|---|---|
| 传感器已发现，首次 claim | 登记 watch、启采样、首读后回成功 | **完全走同一段代码，未改一行** | 等价 |
| 同一 sender 重复 claim（已登记） | `already claimed, no-op` + 回成功 | 同（查的是同一个 `clients[]`） | 等价 |
| 同一 sender 在 discovery 窗口里连发两次 claim | **第二次** no-op，第一次"假成功" | 两次 invocation 都在首读后回；`clients[]` 只登记 1 次 watch | 更严格（1 sender ≤1 watch 不变） |
| claim 后紧接 Release（窗口内） | 回成功、claim 状态残留 | `pending_claim_remove` 撤销挂起项、回成功，不启动采样 | 修正（不再残留） |
| 类型根本不存在 | 回成功（**这就是 bug**） | 回 `NOT_SUPPORTED` | 有意改变（"失败可重试"） |
| 传感器在 discovery 后被热插拔 | 见 `sensor_changes()` 原有逻辑 | 额外先 flush `pending_claims`，其余不变 | 叠加 |

关键点：**挂起期间不写 `clients[]`**，所以"幽灵 claim"这个状态在新代码里**不可达**；
而一旦写进 `clients[]`，所有既有语义（refcount、Release、vanished、`PROP_*` mask）与 3.9 逐字节一致。

---

## §3 补丁 0002：ALS deadband + 限频

文件：`patches-userland/iio-sensor-proxy-20261128/0002-light-deadband-rate-limit-light-level-reports.patch`
diffstat：`1 file changed, 85 insertions(+), 2 deletions(-)`（仅 `src/iio-sensor-proxy.c`，落点 `light_changed_func()`）

### 3.1 规则（`light_changed_func()`，常量集中在文件顶部）

| 规则 | 值 | 作用 |
|---|---|---|
| 首读 | 无条件上报 | 不能挡 claim 首读 / `maybe_notify_sensor_startup_finished()` |
| deadband | `delta >= max(20 lux, 5% of 上次上报值)` | 16 lux 量化抖动被吃在带内 |
| 保持时间 | `delta >= 10 lux` 且距上次上报 `> 1 s` | 慢变（黄昏/远处灯）不会永远卡住 |
| 限频 | 两次上报至少 **10 s**（⇒ ≤6 次/60 s） | 把"逐样本直通"变成"每分钟 ≤6 次" |
| 快速通道 | `delta >= 100 lux` 时 **2 s** 即可 | 真开/关灯不迟钝 |
| 硬预算 | 任意滑动 60 s 内 **≤6 次**（6 槽时间戳环） | 即便快速通道频繁触发，也**从构造上**封顶 |
| 单位切换 | `uses_lux` 变化立刻上报 | 与原语义一致 |

`previous_level` 只在**放行时**更新 ⇒ `LightLevel` 属性值稳定在"上次上报值"，与上报次数同源（判据表第 3 行）。

### 3.2 用设备真实 trace 反演（不是拍脑袋）

脚本：`artifacts/sim-real-trace.py`，输入：`artifacts/trace-before-device-20261128.txt`（1.1 的 1507 条真实样本）。

| 窗口 | 3.9 直通 | 补丁后（逐样本反演） |
|---|---|---|
| 0–60 s | 283 | **6** |
| 最后 60 s | 284 | **6** |
| 全程 301 s | 1410 | 31（≈6.2/min，等于预算上限） |
| 恒定光照（合成，320 lux） | 1 | **1**（不抖就不动） |

另用合成 trace 做正反判断（`artifacts/sim-deadband.py`）：iid 抽 31 个观测值 → 292→**6**；±16 lux 随机游走 → 222→**6**；
"关灯/开灯 3 次 + 抖动"→ 133→**6**。
诚实标注：journal 时间戳只有 **1 s** 分辨率，反演里把同秒样本均匀铺开；真实毫秒级节奏会略有出入（量级不变）。

### 3.3 已知取舍（进 §7 残留风险）

- 快速通道（≥100 lux / 2 s）在**极端**闪烁 trace 下仍可能让上报密度短时变高，但**硬预算 6/60 s 封顶**。
- 反向代价：光照真实变化若小于 deadband 且不足 1 s，会被吞掉（预期行为）；真实大变化最坏延迟 10 s（≥100 lux 时 2 s）。

---

## §4 交叉构建与 ABI 核对（原始输出）

构建脚本（可复现、无 root/chroot）：`patches-userland/iio-sensor-proxy-20261128/build-arm64-deb.sh`
sysroot：**`out/sysroot-trixie-arm64`**（`sys_root`）+ 三件 overlay（trixie 无 `libssc` 包；仓内 sysroot 亦无 polkit/`udev.pc`），
详见该脚本头注释与同目录 `README.md`。命令：

```
build-slot take y700-elden:iio-proxy --jobs 8      # id=180306-4060285-y700-elden_iio-proxy
JOBS=8 timeout -k 10 900 bash build-arm64-deb.sh  # → Linking target src/iio-sensor-proxy（rc=0，无 warning）
build-slot drop 180306-4060285-y700-elden_iio-proxy
```

原始输出（`artifacts/abi-check.log`）：

```
## file
artifacts/iio-sensor-proxy-3.9-2elden-arm64.bin: ELF 64-bit LSB pie executable, ARM aarch64,
  version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux-aarch64.so.1, for GNU/Linux 3.7.0

## max GLIBC symbol version (ours)
GLIBC_2.17
GLIBC_2.34
GLIBC_2.38            ← 设备 glibc 2.41-12+deb13u4，2.38 ≤ 2.41 ✔

## NEEDED (ours) vs 设备 /usr/libexec/iio-sensor-proxy（ssh 只读）
  libgio-2.0.so.0 / libgobject-2.0.so.0 / libglib-2.0.so.0 / libgudev-1.0.so.0 / libm.so.6
  libpolkit-gobject-1.so.0 / libssc.so.2 / libc.so.6 / ld-linux-aarch64.so.1
IDENTICAL (9/9)       ← diff 无输出

## artifacts
af9171823a2c3b1d396880552d02dc7abb827db5e2c99cc400e150b357513b05  iio-sensor-proxy_3.9-2elden_arm64.deb (45788 B)
e20e690d884aab7b8f889244e37e2c65bf9f387daddb3de23d28a83ecfcd584c  iio-sensor-proxy-3.9-2elden-arm64.bin (156552 B，= 从 deb 里解出的那个文件)
设备原件 sha256 dbe9ee038ce5811417fc4f5c1f302c4961c279da26cafb92fee607572ecc69e6（仅作对照）
```

- qemu 烟测（`qemu-aarch64 -L <trixie sysroot>`）：`iio-sensor-proxy --help` / `monitor-sensor --help` 均正常（rc=0）。
- 数据文件零漂移：新包里的 `80-iio-sensor-proxy.rules`、`net.hadess.SensorProxy.conf`、`.policy`、`iio-sensor-proxy.service`
  与设备在机 3.9-1 的四个文件 **byte-identical**（`diff` 无输出）⇒ 上机只换二进制，不碰 udev/unit/polkit。
- 包版本 `3.9-2elden`（> 在机 `3.9-1`，也 > 前一轮本地包 `3.9-1elden`），Depends 与 3.9-1 对齐并含 `libssc2 (>= 0.4.2)`。

---

## §5 上机一次要验哪几步（交父代理/用户；本轮未执行）

前置：设备锁 `scripts/device-lock.sh`；`#692` 取证通道（`dmesg -w` 落盘或串口）就位；**不启 hexagonrpcd**。

```
scp patches-userland/iio-sensor-proxy-20261128/artifacts/iio-sensor-proxy_3.9-2elden_arm64.deb \
    scripts/deploy-iio-sensor-proxy-patches.sh root@elden:/root/
ssh root@elden 'sh /root/deploy-iio-sensor-proxy-patches.sh --check \        # 只读，看改前基线
     --deb /root/iio-sensor-proxy_3.9-2elden_arm64.deb'
ssh root@elden 'EXPECT_SHA256=af917182… CONFIRM=yes sh /root/deploy-iio-sensor-proxy-patches.sh --apply \
     --deb /root/iio-sensor-proxy_3.9-2elden_arm64.deb'
```

然后按 §1.2 逐项测（脚本 `--check` 会打印这些命令）：

1. **A 是否修好（核心）**：`systemctl restart iio-sensor-proxy` 后
   `sudo journalctl -u iio-sensor-proxy -b | grep -cE "Turning deferred claim|Enabling sensor"` ≥1，
   且 `grep -c "already claimed device, no-op"` **不再新增**（这个 restart 在新代码里必须落到"挂起→转真 claim"）；
   同时 `busctl … get-property … HasAmbientLight` = true、`LightLevel` ≠ 0。
2. **B 是否生效**：`sudo journalctl -u iio-sensor-proxy --since "-1min" | grep -c "Emitted light changed"` **≤6**
   （改前 282）；`LightLevel` 唯一值 ≤6；背光写入（100 ms 轮询 60 s）**≤2**。
   ⚠ 该窗口必须与 §1.1 同样的"ALS 真在跑"前提；若背光这条仍为 0，先查 gsd→背光链路（§7 第 4 条），不是补丁问题。
3. **claim 幂等回归**：`sudo busctl --system call … ClaimLight` 两次 → 第二次日志必须出现
   `already claimed device, no-op` 且回成功（证明真 claim 幂等未被破坏）；再 `ReleaseLight` 后 `Enabling sensor` 计数不再涨。
4. **ABI/装入**：`dpkg -l iio-sensor-proxy` = 3.9-2elden；`sha256sum /usr/libexec/iio-sensor-proxy` = `e20e690d…`；
   `objdump -p` NEEDED 9 项不变。
5. 失败即回滚：`sh /root/deploy-iio-sensor-proxy-patches.sh --rollback`（`apt-get install --reinstall iio-sensor-proxy=3.9-1`）。

---

## §6 缺陷 A 的修法**不依赖** gsd-power 重启（派工项 5）

**结论：不依赖。** 证据链（全部只读）：

1. `16:57:40` 代理被 `systemctl restart`，**同一秒**日志里就出现
   `Handling driver refcounting method 'ClaimLight'`，而 gsd-power 进程（pid 96406，`:1.654`）**从未重启**
   （见 `reports/sensors-orientation-als-20261128.md` §1.3 第 2/3 条）⇒ 名字一回来，客户端**自己**就重新 claim。
2. 也就是说：重启代理后的 claim **确实会发生**，3.9 只是把它扔进了 `driver_type_exists==FALSE` 分支；
   补丁 0001 把这一次 claim 变成真 claim（挂起→discovery 完成→启采样→首读后回 invocation）。
   ⇒ 重启代理后 gsd-power 的 ALS **会自动恢复**，无需重启会话、无需重启 gsd。
3. `systemctl restart iio-sensor-proxy` 从"必然制造幽灵 claim"（16:57:40 = 1/1 失败）变成**安全操作**，
   前提是本补丁已装（这也是 §3.2 里"补丁 0001 必须先落地"的原话）。

**必须写清的例外（phosh / accel）**：phosh 0.46 的 `claim_or_release_accelerometer()` 在
`claim == self->claimed` 时直接 return，代理重启后它**不会**重新 `ClaimAccelerometer`
（§1.3 第 4 条，实测 claim 计数不增）。⇒ **加速度计在代理重启后仍需客户端侧动作**（重启会话 / 触发一次 Release），
补丁 0001 只能修"代理侧不该丢的那次 claim"，**不能**替客户端发起 claim。本补丁不假装修了这一条。

---

## §7 残留风险 / 未做

1. **未上机**：本轮的"改后"数字 = 真实 trace 的主机反演（§3.2），不是设备实测。`--apply` 未执行。
2. **挂起语义的代价**：挂起的 claim 仍按上游契约"首读后才回 invocation"。若传感器 enable 成功但**永不出数**
   （如 SSC 侧 `ssc_light_set_polling()` 的 `measurement_id` 二次锁），客户端的 `ClaimLight` 会**挂住**而不是回成功。
   这与上游对正常 claim 的既有行为一致，但确实把"挂住"从少见路径扩大到重启路径。上机第 1 步就该看住这条。
3. **错误码变化**：类型真的不存在时由"假成功"改为 `G_DBUS_ERROR_NOT_SUPPORTED`。若某客户端把它当致命错误，
   表现会与 3.9 不同（但 3.9 的"假成功"正是本 bug 的一半）。
4. **背光 ≤2 未证实**：改前窗口里背光写入是 **0**（不是抖动小，是 gsd 那一侧没把 lux 落到 `aw99706-backlight`），
   说明 `lux → 背光` 之间还另有一层断链（与上轮 §3.1 一致）。补丁只保证"上报 ≤6/60 s"，**不能**保证背光 ≤2；
   ≤2 需要上机实测，若超标就把 `LIGHT_EMIT_MIN_INTERVAL_US`/硬预算调大（一个常量）。
5. **快速通道**：`>=100 lux` 2 s 放行在极端闪烁下会让上限逼近硬预算 6/60 s（不会突破）。
6. **构建侧**：`-Wl,--allow-shlib-undefined` 只为解决 `libssc.so → libqmi-glib.so.5 → libmbim-glib.so.4` 在 sysroot 内
   解析不到的问题；`NEEDED` 9/9 一致降低了风险，但**不等于**运行期可解析，需 `--check` 在机上确认。
7. sysroot 的 glibc 是 `2.41-12+deb13u5`，设备是 `u4`（同 2.41 上游）；`libgudev` sysroot 是 238，设备 `238-6`（同 soversion 0）。
8. 未改：udev 规则（`ssc-accel` 缺口仍在，见 `reports/sensor-libssc-prep-20261126.md`）、SSC registry、gsd-power、phosh。

---

## §8 产物

```
patches-userland/iio-sensor-proxy-20261128/
  0001-claim-race-defer-Claim-until-discovery-finished.patch   +188/-14
  0002-light-deadband-rate-limit-light-level-reports.patch     +85/-2
  README.md
  build-arm64-deb.sh
  artifacts/iio-sensor-proxy_3.9-2elden_arm64.deb              45788 B  af917182…
  artifacts/iio-sensor-proxy-3.9-2elden-arm64.bin             156552 B  e20e690d…（= deb 内文件）
  artifacts/abi-check.log
  artifacts/trace-before-device-20261128.txt                   1507 条真实 lux 样本
  artifacts/sim-real-trace.py / sim-deadband.py                反演脚本
scripts/deploy-iio-sensor-proxy-patches.sh
reports/iio-proxy-patches-20261128.md（本文件）
```
