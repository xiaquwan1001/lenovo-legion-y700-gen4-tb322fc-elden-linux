# SSC 传感器用户态部署尝试（2026-11-26 08:2x–09:1x）—— 装包成功、出数失败、**并触发一次可复现的启动硬崩循环**

> 授权：用户 2026-11-26「用户登录了。全部允许」⇒ 本轮按放行动作执行（含 #692 风险面）。
> 设备：U2 `HA2EXB0E`（TB322FC），在机日常核 `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`。
> 结论先行：**包与 udev 规则都装对了，但加速度计仍不出数**；原因是 **SSC 的 `registry` 传感器需要 `hexagonrpcd` 供给**，
> 而 `hexagonrpcd` 在本机是 #692 的硬崩路径。本轮**实测复现了该硬崩**（5 次连崩），并已把设备恢复到安全态。

---

## 1. 做了什么（按时间）

| 时刻 (CST) | 动作 | 结果 |
|---|---|---|
| 08:21 | elden DTS v9 投递（keyring 已解锁） | 3/3 `Result: 250`，lore 3/3 归档（`SENT.md`） |
| 08:26 | `scripts/deploy-ssc-sensors.sh --from-debian`（第 1 次） | 下载成功；**sha256 步骤有 bug**（三组 sha 被拼成一个文件名）⇒ FATAL，未装 |
| 08:28 | 修脚本 sha256 行（逐件校验） | 本地 `bash -n` 过 |
| 08:29 | 重跑 `--from-debian` | 三包 `dpkg -i` 成功（`libssc2 0.4.4-2.1` / `libssc-bin` / `iio-sensor-proxy 3.9-1` 覆盖 3.7-3）；udev 规则装好；**`HasAccelerometer` 未变 true** ⇒ 脚本 FATAL 退出 |
| 08:30 | 诊断 | udev 属性正确（`IIO_SENSOR_PROXY_TYPE=… ssc-accel …`、`ACCEL_MOUNT_MATRIX` 在）；`iio-sensor-proxy` 日志：`'registry' sensor unavailable after 30s, is hexagonrpcd running?` |
| 08:31 | `ssccli --sensor accelerometer` | **挂住到超时（rc=124，0 行输出）** ⇒ SSC 服务在册但不答 QMI（缺 registry） |
| 08:32 | 备 served root（`/var/lib/droid-juicer/sensors`）：仓内 `backup/stock-elden/vendor-etc-sensors`（139 份 config json）+ 设备 `persist` 分区 `/sensors/registry` | 3.3 MB 就位 |
| 08:33 | 解除 `hexagonrpcd` 的 mask（**这一步是错的，见 §3**），写 drop-in `-f /dev/fastrpc-adsp -d adsp -s -R /var/lib/droid-juicer/sensors` + 放开 `AF_QIPCRTR` | `ExecStart` 读回正确 |
| 08:34 | `systemctl start hexagonrpcd` | **SSH 立刻断，整机硬崩**（用户目视：phosh 转圈卡住 → 关机） |
| 08:36–08:44 | 设备进入**开机硬崩循环**（5 个短 boot，日志都止于启动第 1 秒的 journal flush） | 用户物理 POR 到 BL |
| 08:45 | 主机侧 `fastboot boot` 零写盘救援镜像（cmdline 追加 `systemd.mask=…`） | 但镜像来自 `out/boot-elden-vk192.img`，其 cmdline 仍写 `elden_root=LABEL=linux17`，而现根 LABEL 是 **`linux`**（`PITFALLS #728`）⇒ 落在 initramfs shell（该 initramfs 自带 SSH，可从 192.168.7.1 进） |
| 08:46 | 在 initramfs 里 mount `/dev/sda17` 修根：mask `hexagonrpcd{,-suspend,-resume}` + `iio-sensor-proxy`、删 `default.target.wants/hexagonrpcd.service`、删 drop-in、删 `81-libssc-elden.rules`、`sync` + `reboot -f` | 09:46 前恢复正常：`systemctl is-system-running`=running、`graphical.target`=active、`--failed`=0、phoc/phosh 各 1 |

---

## 2. 关键新事实（可复用）

1. **`libssc` 单独不够**：`qrtr svc 400` 在册、`libssc` 能连上，但 iio-sensor-proxy 报
   `'registry' sensor unavailable after 30s, is hexagonrpcd running?` ⇒ **传感器 registry/config 是由 `hexagonrpcd` 以「served files」方式供给 DSP 的**，
   没有它 SSC 不返回传感器列表。⇒ 2026-11-26 早轮报告里「**可用纯用户态 libssc 绕开 #692**」的设想 **被实测否证**。
2. **`hexagonrpcd` 的 Debian unit 不能直接用**：`ExecStart=/usr/bin/hexagonrpcd` 无参数（等于不用 `-f`/`-s`/`-R`），且
   `PrivateNetwork=yes` + `RestrictAddressFamilies=none` 会挡 `AF_QIPCRTR` ⇒ 必须 drop-in；但**一旦带 `-s` 就会 attach sensorspd** = #692 的硬崩面。
3. **`#692` 已在 U2 上复现**：`systemctl start hexagonrpcd`（带 `-s`）后 SSH 立即消失、整机掉电，接着 5 次「phosh 转圈 → 关机」的
   硬崩循环，每次 journal 只到启动第 1 秒（与 #694 同签名）。
4. **循环的放大原因**（本轮的操作失误）：`hexagonrpcd.service` 在 `default.target.wants/` 里**本来就是 enabled**（2026-11-19 起），
   只是被 mask 压着；我 `systemctl unmask` 后没 disable ⇒ **每次开机自启** ⇒ 循环。教训见 `PITFALLS #732`。
5. 救援路径要记住两条：① `fastboot boot` 零写盘镜像的 cmdline 可能是**旧 LABEL**（`linux17` vs 现 `linux`）⇒ 会落 initramfs；
   ② 落 initramfs 不是死局——**该 initramfs 自带 SSH**，可 mount `sda17` 直接修根。

---

## 3. 我的操作失误（如实记录）

- 解除 `hexagonrpcd` 的 mask 之前**没有检查它是否 enabled**（`default.target.wants/` 有链接），也没有「先改 unit 再启」的顺序保护。
  正确做法应是：先 `systemctl disable hexagonrpcd`（或保持 masked），只在**单次手动 `systemctl start`** 里试 `-s`，且事先接受硬崩。
- 触发硬崩后的一段时间里，我在主机侧反复试 SSH（无效），没意识到设备已进入**开机即崩**的循环——这段本可以更早用 serial + `systemd.mask=` 救援。
- 已在 `scripts/deploy-ssc-sensors.sh` 里加硬护栏（见下），并把本条写进 `PITFALLS #732`。

---

## 4. 现在的设备状态（安全态，已验证）

```
systemctl is-enabled hexagonrpcd hexagonrpcd-suspend hexagonrpcd-resume iio-sensor-proxy
masked / masked / masked / masked
systemctl is-system-running = running；graphical.target = active；systemctl --failed = 0
pgrep -x phoc = 1；pgrep -x phosh = 1
/etc/udev/rules.d/ = 60-uinput.rules 70-elden-dma-heap.rules（我们的 81-libssc-elden.rules 已移除）
/etc/systemd/system/hexagonrpcd.service.d/ 已删除
```
包仍在（`libssc2 0.4.4-2.1`、`libssc-bin`、`iio-sensor-proxy 3.9-1`）+ apt pin/hold 已写；`/var/lib/droid-juicer/sensors` 3.3 MB 内容留着（无害）。
⇒ 现状 = **与部署前等价的功能面**（无加速度计），但用户态件已就位，等真解。

---

## 5. 要真正做通加速度计，还缺什么（按代价排序）

1. **取证通道（前置，必须先做）**：`/dev/ttyACM0` 是 USB gadget，硬崩会连它一起没；`/sys/fs/pstore` 空（ramoops 窗口未修）。
   ⇒ 物理串口（UART）或修 ramoops，才能把 #692 的崩溃点抓出来。**没有这条，任何 `-s` 尝试都是盲试**。
2. **`registry`/config 的真正来源**：本机 `/vendor` 已不存在（GPT 手术删了 Android 分区），现用
   `backup/stock-elden/vendor-etc-sensors` + `persist` 拼的 served root **是否与出厂一致未验证**（DSP 可能因 config 不匹配再次崩）。
   可用对照 = `reports/c0-android-baseline-20261011.md` 的 42 传感器清单 / `backup/HA2EXB0E-16+512/c0-baseline/`。
3. **`hexagonrpcd -s` 的崩溃点**：拿到取证通道后，用 `systemd.mask=` 救援 + 单次 `start` 二分（先不带 `-s`、再带 `-s`、再换 registry 内容）。
4. **Waydroid 侧**（C4/A14）不依赖这条：容器传感器走宿主 UDP relay + `ssccli`（`PITFALLS #431`），但那同样需要 `ssccli` 能出数 ⇒ 仍卡在 2/3。

---

## 6. 证据文件

- `reports/artifacts/sensors-ssc-20261126/pre-check.txt`（部署前 15 项矩阵）
- `reports/artifacts/sensors-ssc-20261126/deploy.txt`（第一次，sha256 bug）
- `reports/artifacts/sensors-ssc-20261126/deploy2.txt`（第二次，装包成功、`registry` 报错）
- `reports/artifacts/sensors-ssc-20261126/crash-boots.txt`（5 个短 boot 的 journal 尾部）
- `out/rescue-20261126/boot-rescue-sscmask.img`（救援镜像，kernel/ramdisk/dtb 与 vk192 逐字节相同，只改 cmdline）
