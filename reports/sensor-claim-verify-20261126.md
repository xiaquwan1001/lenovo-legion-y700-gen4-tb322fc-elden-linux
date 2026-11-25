# 「传感器驱动有问题」说法核实（lane S · 设备只读）

> 日期：2026-11-26（设备时钟 2026-11-25 23:00 CST 起本次 boot，报告日按主机日）
> 设备：`root@192.168.7.1`，在机 `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`，Debian 13 (trixie)，uptime 6:40
> 授权边界：**严格只读**。本 lane 未 enable/start/stop/mask 任何 unit、未 modprobe/rmmod、未写 `/sys`、未复现 #692。
> 唯一写入路径 = 本文件；原始日志 tee 在仓外 `/tmp/sensorlane/*.log`（01–18）。
> 反证声明：本轮**未**向 SSC 服务发任何 QMI/传感器请求 ⇒ 「svc 400 能否出数」= **未测**，不是「已测失败」。

---

## §1 结论（一页）

**「传感器驱动有问题」= 部分成立，但归因层是错的。**
按驱动去找会白费：**内核 / DTB / fastrpc / QRTR 四层实测健康**（adsp remoteproc running、
`qcom,non-secure-domain` 真在在机 DTB、`/dev/fastrpc-adsp` 存在且 owner 已对、QRTR svc 400 已注册）。
真正的缺口在**用户态**：现根是 **trixie 的 `iio-sensor-proxy` 3.7-3，不带 SSC 后端**（`ldd` 无 libssc、
`strings` 命中 0），且 **Debian 13 无 `libssc` 包**；以及**策略/时序层**：`hexagonrpcd` 因 #692 被 **mask**、
我们补丁版 unit 的别名/drop-in/固件根映射三件在设备上**全部缺失**。

### 判定表（说法 → 成立度 → 归因层 → 关键证据）

| # | 说法 | 判定 | 归因层 | 关键证据（命令 → 输出摘录） |
|---|---|---|---|---|
| C1 | 「传感器内核驱动缺失/坏了」 | **不成立** | 内核驱动（无需有） | `dmesg \| grep -icE 'ssc\|sns\|sensor'` → **0**；`/sys/class/remoteproc/*/state` → `adsp=running` `cdsp=running`；`/sys/bus/iio/devices/` 仅 `iio:device0`（`name=spmi-adc5-gen3`，只有 `in_temp3/in_voltage0/1`）⇒ **本机架构上不存在 AP 侧加速度计驱动**（7 颗传感器挂 SLPI 私有 I²C，`DEVICE/README.md` §1 表首行），`st_lsm6dsx.ko` 在模块树里但永远匹配不到设备 |
| C2 | 「ADSP fastrpc 前置（`qcom,non-secure-domain`）没进镜像」 | **不成立（已修）** | 内核 DTB | `stat -c %s /proc/device-tree/soc@0/remoteproc@6800000/glink-edge/fastrpc/qcom,non-secure-domain` → **`0`**（boolean 存在；**不是 strings 计数**，避 `PITFALLS #639`）；`ls -l /dev/fastrpc*` → `fastrpc-adsp`(10,264) **`fastrpc:fastrpc`**、`fastrpc-cdsp`、`fastrpc-cdsp-secure`（adsp **无** `-secure` 变体 = 非安全实例已建） |
| C3 | 「SSC 服务（svc 400）没起来」 | **不成立（但功能未验证）** | QRTR / SSC 服务 | `qrtr-lookup` → `400  1  0  5  21 Snapdragon Sensor Core service`；`qrtr-ns` = active(661, `-f 1`)；`CONFIG_QRTR=y`（内建）。**本 boot `journalctl -b \| grep -c hexagonrpcd` = 0** ⇒ svc 400 是在 `hexagonrpcd` **未运行**下就注册的 |
| C4 | 「用户态 SSC 栈缺件」 | **成立** | Debian 用户态 | `dpkg -l` → `iio-sensor-proxy 3.7-3`；`ldd /usr/libexec/iio-sensor-proxy` → 只有 `libgio/libglib`；`strings … \| grep -icE 'libssc\|ssc_'` → **0**；`apt-cache policy libssc2 libssc-bin` → **无输出**（trixie 无该包）；`ldconfig -p \| grep -i ssc` → 只有 `libnssckbi`（无关） |
| C5 | 「udev 传感器类型标签错」 | **成立（可复现的既有真因）** | 用户态 udev | 发行版 `/usr/lib/udev/rules.d/80-iio-sensor-proxy.rules` **一条 `ssc-*` 都没有**（3.7 版规则）；我们仓里的 `81-libssc-elden.rules`（`ssc-accel` + `ACCEL_MOUNT_MATRIX`）**不在设备上**（`/etc/udev/rules.d/` 只有 `60-uinput.rules` 与 `70-elden-dma-heap.rules`；`/usr/lib/udev/rules.d/` 的 60/80/90 全是发行版件）⇒ `udevadm info -q property /dev/fastrpc-adsp` 无 `IIO_SENSOR_PROXY_TYPE`、无 `ACCEL_MOUNT_MATRIX` |
| C6 | 「unit 时序/依赖有问题」 | **部分成立** | unit / 策略 | `hexagonrpcd` = **masked**（`/etc/systemd/system/hexagonrpcd.service -> /dev/null`）；`hexagonrpcd-adsp-sensorspd` = **not-found**（Debian 0.3.2 **不提供**该 wrapper，`dpkg -L` 只有 `hexagonrpcd{,-resume,-suspend}.service`）；设备上**没有** `hexagonrpcd.service.d/elden.conf`（放开 `AF_QIPCRTR`/`PrivateNetwork` 的 drop-in）、**没有**别名 symlink、**没有** served-root `/usr/share/qcom/sm8750/LENOVO/TB322FC`；发行版 `iio-sensor-proxy` = `Type=dbus` / `WantedBy=` 空 / **无** `After=hexagonrpcd*` |
| C7 | 「#692 是内核驱动 bug」 | **未证实（不可归因）** | 未定（PD/固件/驱动皆可能） | `/sys/fs/pstore/` **空**；无 Oops/panic；`journalctl --list-boots` 本次 6 个短 boot。缺取证通道 ⇒ 任何「驱动 bug」的断言都超出证据 |
| C8 | 「`/dev/fastrpc-adsp` 属主导致服务 Permission denied」 | **不成立（旧坑已消失）** | 用户态 udev 规则 | `60-hexagonrpcd.rules` = `SUBSYSTEM=="misc", KERNEL=="fastrpc-*", OWNER="fastrpc", GROUP="fastrpc", MODE="660"`，实测节点 owner 已是 `fastrpc:fastrpc` |

**一句话判据**：想恢复加速度计，**改内核没有收益**；`qrtr svc 400` 已在且 `hexagonrpcd` 被 mask 也没让它消失
（与 `reports/debian-root-accounts-sensors-20261026.md` §4「svc 400 未注册」的旧结论相反，见 §2.2 注），
所以**可以先用纯用户态件（libssc）验证 SSC 是否出数，从而绕开 #692** —— 这是本轮最有价值的路线发现。

---

## §2 逐层证据

### 2.1 内核层（判定：健康）

| 检查 | 命令 | 原始输出（摘） |
|---|---|---|
| remoteproc | `for s in /sys/class/remoteproc/*/state; do echo "$s => $(cat $s)"; done` | `remoteproc0 => running` / `remoteproc1 => running`；`name` = `adsp` / `cdsp` |
| adsp 起机 | `dmesg \| grep -iE 'remoteproc'` | `[0.597949] remoteproc0: powering up adsp` / `Booting fw image qcom/sm8750/adsp.mdt, size 8364` / `[1.149425] remoteproc0: remote processor adsp is now up` |
| fastrpc 挂到 adsp | 同上 | `[10.457697] qcom,fastrpc 6800000.remoteproc:glink-edge.fastrpcglink-apps-dsp.-1.-1: assigned reserved memory node adsp-rpc-remote-heap`；`compute-cb@3..8: Adding to iommu group 16..21` |
| **唯一告警** | 同上 | 告警全在 **CDSP**（`32300000.remoteproc`）：`no reserved DMA memory for FASTRPC` + `compute-cb@N: SMR mask 0x40 out of range for SMMU (0x2)`（各 12 行）。**adsp 侧无一条** |
| DT 属性（判据口径） | `stat -c %s /proc/device-tree/soc@0/remoteproc@6800000/glink-edge/fastrpc/qcom,non-secure-domain` | `0` ⇒ 属性**存在**（0 长 = DT boolean 真）；同路径 `compatible` = `qcom,fastrpc`，`glink-edge/label` = `lpass` |
| 对照（CDSP 也有） | 同命令，`remoteproc@32300000` | `0` |
| 设备节点 | `ls -l /dev/fastrpc*` | `crw-rw---- fastrpc fastrpc 10,264 /dev/fastrpc-adsp`；`10,263 /dev/fastrpc-cdsp`；`10,262 /dev/fastrpc-cdsp-secure` |
| 模块 | `lsmod \| grep fastrpc` | `fastrpc 45056 0` —— **引用计数 0** = 当前无人 attach（与 C6 一致） |
| 无 SSC 内核驱动 | `dmesg \| grep -icE 'ssc\|sns\|sensor'` | `0` |
| 内核配置 | `zcat /proc/config.gz \| grep -iE 'QRTR\|QCOM_Q6V5\|FASTRPC'` | `CONFIG_QRTR=y`、`QRTR_SMD/TUN/MHI=y`、`QCOM_Q6V5_PAS=y`、`QCOM_Q6V5_ADSP=m`、`QCOM_FASTRPC=m`、`RPMSG_QCOM_GLINK{,_SMEM}=y` |

⇒ 内核与 DTB 这一层**没有任何缺口**；`DEVICE/README.md` §1.1「ADSP fastrpc 必须带 `qcom,non-secure-domain`
（vk190 起日常线才有）」的前置条件在本机（vk189）**已满足**。

### 2.2 QRTR / SSC 服务层（判定：注册 OK，功能未测）

- `systemctl is-active qrtr-ns` → `active`；进程 `root 661 /usr/bin/qrtr-ns -f 1`；
  journal 有一行 `qrtr-ns: nameserver already running, going dormant: Address already in use`（有第二个实例已占 AF_QIPCRTR，不影响查询）。
- `qrtr-lookup`（完整一次抓取见 `/tmp/sensorlane/09-qrtr-lookup.log`）关键行：

```
  Service Version Instance Node  Port
       400       1        0    5    21 Snapdragon Sensor Core service      ← SSC
       769       1        0    5    17 SLIMbus control service
        51       1       12    5    20 CoreSight remote tracing service
        24       1       67   10    10 Thermal mitigation device service
        15       1       32    5     1 Test service
```

  node 5 同表还挂 SLIMbus(769) / CoreSight(51) —— 与 ADSP 侧服务集合一致（**推断**；`qcom,remote-pid` 读作
  cell `2`，QRTR node id 的映射本轮未独立钉死，报告里不把它当硬结论）。
- **新事实（与旧文档冲突，需 SSOT 收口）**：`journalctl -b | grep -c hexagonrpcd` → **0**，
  即本 boot `hexagonrpcd` **从未运行**（masked），svc 400 仍然注册在案。
  `reports/debian-root-accounts-sensors-20261026.md` §4 的「SSC svc 400 未在 QRTR 注册 ⇒ 等 svc 400 上线」
  这条在**当前镜像 + 当前 mask 状态**下不成立（可能因 adsp 非安全域补丁到位后 ADSP 侧 sns 自行注册）。
  **功能是否可用仍未测**：要判定必须发一次 QMI/SNS 请求（见 §3 步骤 C，属风险边界）。

### 2.3 用户态（判定：这是真正的缺口）

| 检查 | 输出 |
|---|---|
| `dpkg -l \| grep -iE 'libssc\|iio-sensor-proxy\|hexagon\|qmi\|qrtr'` | `hexagonrpcd 0.3.2-2`、`libhexagonrpc0.3 0.3.2-2`、`iio-sensor-proxy 3.7-3`、`libqmi-glib5 1.36.0-1`、`libqrtr1 1.1-2+b1`、`qrtr-tools 1.1-2+b1`（**无 libssc***） |
| `apt-cache policy libssc2 libssc-bin libssc-dev` | **空输出** = Debian 13 无该包（`PITFALLS #325` 结论复现） |
| `apt-cache policy iio-sensor-proxy` | 已装 3.7-3 / **候选 3.7-3**（trixie/main 唯一）⇒ 仓内正常途径拿不到 3.9 |
| `ldd /usr/libexec/iio-sensor-proxy` | 仅 `libgio-2.0.so.0`、`libglib-2.0.so.0`（**无 libssc/libqmi**） |
| `strings /usr/libexec/iio-sensor-proxy \| grep -icE 'libssc\|ssc_'` | `0` ⇒ 二进制里**没有 SSC 后端代码**（3.7 源码无 `drv-ssc-*.c`，与 `TASKS/sessions/2026-10-21-Mobian迁移可行性评估.md` §3 一致） |
| `ldconfig -p \| grep -i ssc` / `find / -maxdepth 4 -name 'libssc*' -o -name ssccli` | 只有无关的 `libnssckbi.so`；**无 libssc、无 ssccli** |
| IIO 设备 | `ls /sys/bus/iio/devices/` → `iio:device0`；`cat .../name` → **`spmi-adc5-gen3`**；通道 = `in_temp3_input`、`in_voltage0/1_input`（PMIC ADC，**不是**加速度计） |
| `iio_info` | **未安装**（`libiio-utils` 缺）⇒ 该条检查无法执行（记为未测，不写成通过） |
| udev 规则 | `/etc/udev/rules.d/` = `60-uinput.rules`(92 B) + `70-elden-dma-heap.rules`(50 B，我们的) ⇒ **无 `81-libssc-elden.rules`**；`/usr/lib/udev/rules.d/` = 发行版 `60-hexagonrpcd.rules`(85 B)、`80-iio-sensor-proxy.rules`(1746 B)、`90-brightnessctl.rules`(205 B) |
| 发行版 80 规则内容 | 全是 `SUBSYSTEM=="iio"`/`hwmon`/`input` 的 `iio-*` 类型，**零条 `ssc-*`** |
| `udevadm info -q property /dev/fastrpc-adsp` | 只有 `DEVPATH/DEVNAME/MAJOR/MINOR/SUBSYSTEM=misc` ⇒ **无 `IIO_SENSOR_PROXY_TYPE`、无 `ACCEL_MOUNT_MATRIX`** |
| `monitor-sensor` | `timeout -k 3 12 monitor-sensor` → **`Waiting for iio-sensor-proxy to appear`**（12 s 内无任何 SensorProxy 事件） |
| D-Bus | `busctl --system list \| grep -iE 'hadess\|sensor'` → 只有 `net.hadess.PowerProfiles` ⇒ **`net.hadess.SensorProxy` 名字不在总线上** |
| 状态未被我改变 | 前：`is-active=inactive`、`NRestarts=0`；后：`is-active=inactive`、`Result=success`、`NRestarts=0`；`journalctl -b -u iio-sensor-proxy` → `-- No entries --` ⇒ **monitor-sensor 没有触发 D-Bus 激活**，设备状态零变化 |

### 2.4 unit / 时序层（判定：部分成立）

```
$ systemctl list-unit-files | grep -iE 'hexagon|sensor|iio|qmi|qrtr'
hexagonrpcd-resume.service        enabled  enabled
hexagonrpcd-suspend.service       enabled  enabled
hexagonrpcd.service               masked   enabled
iio-sensor-proxy.service          static   -
qrtr-ns.service                   enabled  enabled

$ systemctl is-enabled hexagonrpcd-adsp-sensorspd   → not-found
$ ls -l /etc/systemd/system/ | grep -iE 'hexagon|sensor|iio'
hexagonrpcd.service -> /dev/null     (另: droid-juicer + 4 个 plymouth 也已 mask)
```

三层缺失（与 `rootfs/debian/stage.sh:241-300` 的构建意图逐条对不上）：

1. **drop-in 缺**：`/etc/systemd/system/hexagonrpcd.service.d/elden.conf` 不存在
   ⇒ 即使去掉 mask，Debian 包单元的 `RestrictAddressFamilies=none` + `PrivateNetwork=yes`
   仍会让它建不出 `AF_QIPCRTR` socket（2026-10-26 实测过，`PITFALLS` 同族结论）。
2. **别名 unit 缺**：`hexagonrpcd-adsp-sensorspd.service` 未建 symlink ⇒ `render.py` 渲染出的
   `After=hexagonrpcd-adsp-sensorspd.service` 是**静默失效依赖**（正是 `stage.sh` 注释里担心的那类）。
3. **served root 缺**：`/usr/share/qcom/sm8750/LENOVO/TB322FC` 不存在，而 `hexagonrpcd` 的
   `-R` 默认就是 `/usr/share/qcom/` ⇒ 就算起来也喂不出 `sensors/config` 与 persist registry。
4. **版本漂移**：`stage.sh:244` 注释写「Debian 的 hexagonrpcd **0.4.0**」，设备实装 **0.3.2-2**；
   二进制支持 `-s`（`/usr/bin/hexagonrpcd --help` → `-s  Attach to sensorspd`、`-R DIR` 默认 `/usr/share/qcom/`），
   但 `dpkg -L hexagonrpcd` **不提供** `hexagonrpcd-adsp-sensorspd` 可执行体 ⇒
   `packaging/elden-userland/services.tsv:43` 那行 `ExecStart=/usr/bin/hexagonrpcd-adsp-sensorspd`
   在 Debian trixie 上是**不存在的路径**（语义真源需按 0.3.2 改写）。
5. 发行版 `iio-sensor-proxy.service`：`Type=dbus`、`BusName=net.hadess.SensorProxy`、`Restart=no`、
   `WantedBy=`（空）、`After=` 里**没有** `hexagonrpcd*` ⇒ 我们那枚「等 QRTR svc 400」的
   `hooks/iio-sensor-proxy.pre`（2026-11-25 已暂挂、且 hooks 目录曾整体未安装）依旧不在链上。

### 2.5 证据边界

- `journalctl --list-boots` 本次仅 6 个 boot（最早 2026-11-25 20:16 CST）；`/sys/fs/pstore/` **空**；
  `journalctl -b | grep -c 'iio-sensor-proxy'` = **0**、`grep -c hexagonrpcd` = **0** ⇒
  本 boot **没有**传感器相关用户态记录，历史上也拿不到 #692 的内核现场（`PITFALLS #325` 的结论仍成立）。
- 未执行：任何 QMI/SNS 请求、`ssccli`、`hexagonrpcd -s`、unit start/stop、`udevadm trigger`、
  `monitor-sensor` 之外的用户态唤起。**「svc 400 能否返回 sensor 列表」= 未测**。

### 2.6 文档侧对账：「传感器驱动有问题」历史上具体指哪件事

按时间序，这句话在不同阶段被用来指**完全不同层的四件事**，混用是漂移的根源：

| 时间 | 当时真正的问题 | 归因层 | 现状（本轮实测） |
|---|---|---|---|
| ≤2026-10-26 | `qcom,non-secure-domain` 只在 `build/vk151` 未提交工作区 ⇒ 在机 DTB 只建 `fastrpc-adsp-secure`（「修复从未进镜像」）。`TASKS/README.md` G1-34 行 | 内核 DTB | **已修**：属性在在机 DTB（C2） |
| 2026-10-27 | `HasAccelerometer=false` 真因 = udev 缺 `ssc-accel`（`PITFALLS #451` / `PITFALLS/sessions/114-*`）+ `iio-sensor-proxy` 挂错 target 造成 ordering cycle（`#453`）；`qrtr-lookup` 400 当时已在（`#443`），不是内核/DSP/固件 | 用户态 udev / unit | 两件在设备上**都缺**（C5、C6） |
| 2026-11-19 | **#692**：`hexagonrpcd` attach ADSP sensor PD ⇒ 整机硬崩（无 Oops/pstore、journal 截断）⇒ mask；`#694` 掉电链 | 未定（PD/固件/驱动皆可能） | 仍 masked；**机制未证实**（C7） |
| 2026-11-25 | `TASKS/README.md` D16：`verify.sh` 发现我们 patch 过的 unit **从未部署**（真因 = hooks 缺 shebang）、重根后发行版件回退；并明写「**加速度计当前是故意关的**，要恢复必须先解决 #692」 | 构建/部署 / 策略 | 与本轮 C4–C6 完全吻合 |

⇒ 结论：**「传感器驱动有问题」这句话在历史上的每一次具体所指，都不是内核传感器驱动**（除 #692 机制未知外）。
最近一次（D16）已经把它定性为「故意关的 + 用户态栈缺件」，本轮把这句话的归因层用实测钉死在
**Debian 用户态（libssc/iio-sensor-proxy） + 部署层（rule/drop-in/served root）**。

---

## §3 最小闭环路径（加速度计 → 自动旋转）

排序原则：**先走「不碰 ADSP PD」的用户态路线**（可绕开 #692），把高危动作推到最后且需放行。

| 步 | 动作 | 代价 | 风险 | 是否触发 #692 | 判据 |
|---|---|---|---|---|---|
| **A** | 部署 `81-libssc-elden.rules`（仓内 `packaging/elden-userland/files/etc/udev/rules.d/`，`ssc-accel/ssc-proximity/ssc-light/ssc-compass` + `ACCEL_MOUNT_MATRIX="-1,0,0;0,-1,0;0,0,1"`）+ `udevadm control --reload` + `udevadm trigger --subsystem-match=misc --action=change` | ~2 min，需一次写 `/etc/udev/rules.d` | **低**：当前发行版 80 规则无 `ssc-*`、无 `SYSTEMD_WANTS`，触发不会拉起任何 unit（与 2026-10-27 环境不同，需在装 3.9 规则后复查） | 否 | `udevadm info -q property /dev/fastrpc-adsp` 出现 `IIO_SENSOR_PROXY_TYPE=ssc-accel…` + `ACCEL_MOUNT_MATRIX` |
| **B** | 搞到 **带 SSC 后端的用户态件**（二选一）：**B1** 源码自建 `libssc` + `iio-sensor-proxy 3.9 -Dssc=true`；**B2** 混源装 forky/sid 的 `libssc2` + `iio-sensor-proxy 3.9` | **B1 ≈1–2 h**（主机 arm64 chroot 交叉，设备零写；依赖齐：`libqmi-glib-dev 1.36.0-1`、`libprotobuf-c-dev`/`protobuf-c-compiler 1.5.1-1` 均在 trixie 源）；**B2 ≈10 min** | **B1 低**（不动设备）；**B2 中**（sid 件拉 glib 依赖漂移，可能牵动桌面链；`DEVICE` §1.1 硬约束② 正是这条） | 否 | `ldd /usr/libexec/iio-sensor-proxy \| grep libssc` 命中；`ssccli --help` 可用 |
| **C** | **首次真触 SSC**：`ssccli --sensor accelerometer`（libssc 经 QRTR 直连 svc 400，**不 attach fastrpc PD**） | ~10 s | **未知/中**：这是本机第一次向 ADSP 传感器服务发 QMI 请求；与 #692 的 `-s` attach 路径不同，但**无取证通道**（pstore 空；`/dev/ttyACM0` 是 USB gadget，崩了随整机消失） | **可能**（须放行 + 先落盘证据） | 出现连续真值（历史参考值 Z≈9.61 m/s²）⇒ **svc 400 可用，可完全绕开 #692** |
| **D** | 仅当 C 失败：`hexagonrpcd -s` attach ADSP sensor PD（或补回 `stage.sh` 的 drop-in/别名/served-root 三件后 `systemctl start`） | 30 min（含三件缺失补齐） | **高 = #692 本体**（硬崩整机，~1 min 自回 Linux） | **是** | 前置条件（缺一不可）：① 另一条物理串口 **或** 修好 ramoops 窗口（本机 `pstore` 空，因守卫拒掉与 initrd 重叠的 zone）；② `nohup dmesg -w > /var/log/dmesg-attach.log &`；③ 单变量、只 start 该 unit、不动服务链/桌面 |
| **E** | 自动旋转收尾：`busctl get-property … net.hadess.SensorProxy HasAccelerometer/AccelerometerTilt` 三真 + Phosh 自动旋转开关（设置持久化）；四姿态复标 `ACCEL_MOUNT_MATRIX` | 20–40 min（含标定） | 低（纯用户态；注意 `PITFALLS #371` 别动 DPMS 相关 proxy） | 否 | `HasAccelerometer=true`、倾斜设备 `AccelerometerTilt` 变化、屏幕随姿态转；**不要**用 `AccelerometerOrientation`（常态 `undefined`，`#114` 判据口径） |

**推荐执行顺序**：A（可先做，低风险） → B1（主机侧，零设备写） → **C（需放行）** → 视 C 结果决定是否 D。
C 若成功，则 `TASKS/README.md` D16「传感器要恢复必须先解决 #692」这条**依赖关系可作废**（不必解 #692 也能出数），
这将是本轮最省代价的收口路径。

**明确的高危清单（需父代理/用户放行后才可做）**：
- 步骤 C（首次 QMI 触碰 SSC）——无取证通道。
- 步骤 D 的任何形式（`hexagonrpcd -s`、去 mask、`systemctl start hexagonrpcd`）——#692 本体。
- 任何「在 live 系统上 stop/disable 危险 unit」的动作（`PITFALLS #327`：live 停 `droid-juicer` ~40 s 掉电）。

---

## §4 需用户干预项

1. **放行步骤 C**（`ssccli --sensor accelerometer`，一次 QMI/SNS 请求）。理由：它是唯一能判定
   「svc 400 是否真可用」的手段，且**不需要** attach ADSP PD；但本机无崩溃取证通道
   （`/sys/fs/pstore` 空、`/dev/ttyACM0` 随整机崩溃一起消失）。若拒绝，本轮结论就只能停在
   「svc 400 已注册、功能未测」。
2. **若要走 D（#692 路线），必须先给一条崩溃可观测通道**，二选一（都需用户/父代理决定）：
   ① 另一条物理串口（非 USB gadget，或屏幕拍照机位）；② 修 ramoops 窗口使其不与 initrd 重叠。
   在通道就绪前，`hexagonrpcd` 应保持 mask（当前状态即安全态）。
3. **B 路线的形态选择**：允许 `apt` 混入 forky/sid 源装 `libssc2`+`iio-sensor-proxy 3.9`（10 min，但 glib 依赖
   可能牵连桌面），还是走源码自建（1–2 h、设备零写、可复现）。**建议后者**（与 `DEVICE` §1.1 硬约束② 同向，
   且能固化进 `packaging/elden-userland` 门禁）。
4. **是否需要一次重启窗口**：A/B/E 完成后要判「冷起即有三真」（历史教训：`#451`+`#453` 都是冷起才暴露），
   需设备空闲时段 + 允许重启。

---

## 附：复现命令（全部只读，逐条可重跑）

```sh
S='ssh -o ConnectTimeout=5 -o BatchMode=yes root@192.168.7.1'
# 内核层
timeout -k 3 25 $S 'for s in /sys/class/remoteproc/*/state; do echo "$s => $(cat $s)"; done; cat /sys/class/remoteproc/*/name'
timeout -k 3 25 $S 'stat -c "%s %n" /proc/device-tree/soc@0/remoteproc@6800000/glink-edge/fastrpc/qcom,non-secure-domain'
timeout -k 3 25 $S 'ls -l /dev/fastrpc*; lsmod | grep fastrpc; dmesg | grep -icE "ssc|sns|sensor"'
# QRTR / SSC
timeout -k 2 8  $S 'qrtr-lookup | grep -E "^ *(400|769|51) "'
timeout -k 3 25 $S 'journalctl -b | grep -c hexagonrpcd; systemctl is-active qrtr-ns'
# 用户态
timeout -k 3 25 $S 'dpkg -l | grep -iE "libssc|iio-sensor-proxy|hexagon"; apt-cache policy libssc2 libssc-bin'
timeout -k 3 25 $S 'ldd /usr/libexec/iio-sensor-proxy; strings /usr/libexec/iio-sensor-proxy | grep -icE "libssc|ssc_"'
timeout -k 5 40 $S 'timeout -k 3 12 monitor-sensor; systemctl is-active iio-sensor-proxy'
timeout -k 3 25 $S 'udevadm info -q property /dev/fastrpc-adsp; ls /etc/udev/rules.d/ /usr/lib/udev/rules.d/ | grep -iE "ssc|iio"'
# unit / 时序
timeout -k 3 25 $S 'systemctl list-unit-files | grep -iE "hexagon|sensor|iio|qrtr"; ls -l /etc/systemd/system/ | grep -iE "hexagon|sensor|iio"'
timeout -k 3 25 $S 'systemctl show iio-sensor-proxy -p Type -p BusName -p After -p WantedBy'
```

原始输出归档（仓外）：`/tmp/sensorlane/{01-dmesg,02-remoteproc,03-dt-fastrpc,04-qrtr,05-units,06-pkgs,07-iio,08-iio-proxy,09-qrtr-lookup,10-libssc,11-procs,12-userland-root,13-journal,14-monitor-sensor,15-dbus,16-hexagonrpcd-cfg,17-node-pstore,18-unit-timing}.log`
