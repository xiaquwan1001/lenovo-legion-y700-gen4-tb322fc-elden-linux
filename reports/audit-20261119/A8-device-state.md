# A8 — 设备只读现态详查（2026-11-19 23:07–23:12 CST）

> **审计代理**：A8-device（本文件作者）；**性质 = 只读**：未改仓库其它文件、未做 git 写操作、未改/未重启/未 mount rw 设备、无 apt 安装。
> 全部设备命令形态：`timeout -k 3 12 ssh -o BatchMode=yes elden '<cmd>'`（主机 `/home/xuqianhui/y700-elden`，`git rev-parse --show-toplevel` 首条已核对通过）。
> 结论口径：**【实测】**= 本轮亲自跑出的输出；**【未取证】**= 工具缺失/无法在本轮核实。计数与对照数据是实测，其余引用处都带指针。
> 前任代理轨迹说明：`ea539e…`（A2-best-state）与 `d698c9…`（A8-device）两个 jsonl **仅存 usage 元数据、无 assistant 文本**（`python3` 逐行 json 解析，32 行/条全部只有 `usage`），因此**无法并入其结论** → 该部分标 **【未取证】**；可用的等价结论见本文件 §8 与本轮 `README.md` §2（父会话实测）。

---

## 1. 内核与启动命令行【实测】

| 项 | 值 |
|---|---|
| `uname -a` | `Linux elden 7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0 #32 SMP PREEMPT Mon Nov 16 10:55:25 CST 2026 aarch64 GNU/Linux` |
| `/proc/cmdline` 根 | `elden_root=LABEL=linux`（2026-11-18 RAM 启动失败的对照口径 = label 写成 `linux17`） |
| 槽位/启动态 | `androidboot.slot_suffix=_b androidboot.verifiedbootstate=orange androidboot.force_normal_boot=1 androidboot.serialno=HA2EXB0E` |
| 面板 DT 参数 | `msm_drm.dsi_display0=qcom,mdss_dsi_elden_nt36523_csot_3k_dsc_vid:` |
| `/proc/device-tree/model` | `Lenovo Legion Y700 Gen4 ` |
| 其它 | `console=ttyGS0,115200 console=tty0 loglevel=8 panic=15 clk_ignore_unused pd_ignore_unused arm-smmu.disable_bypass=0`、`hqsysfs.pcba_stage=SOVP`、`silent_boot.mode=nonsilent` |
| 运行时长 | `up 32 min, 2 users, load average 0.06/0.03/0.05` |
| 时钟 | `2026年11月19日 星期四 23:07:53 CST`；`chronyc tracking` Reference ID `CA264012 (202.38.64.18)` Stratum 4 → **同步正常** |

## 2. 存储与根文件系统【实测】

命令：`lsblk -o NAME,SIZE,PARTLABEL`、`findmnt /`、`df -h /`

- `sda` 472.5G（UFS LUN0，GPT 主表所在），本次挂载的是 **`/dev/sda17` → PARTLABEL `linux17` 193G**，`findmnt /` = `ext4 rw,noatime`。
- `df -h /`：**190G 总量 / 6.2G 已用 / 176G 可用（4%）** → 与 `README.md` §2「minbase→resize2fs 190 G」一致。
- 其余 LUN（`sdb`/`sdc` = xbl 两套、`sde` 4G = 主固件 LUN、`sdd`/`sdf` = 小 GPT 段、`mmcblk0` 58.6G 外置/另一设备）与 `README.md` §2 描述一致。

> 注意：**`linux17` 为唯一 Linux 分区**。历史文档提到的 `linux18`（f2fs Alpine 回退根）在本轮 `lsblk` 中**不存在** → 说明「单分区 193G 合并」已落地（对照 `reports/audit-20261119/README.md` §2 与用户 2026-10-30 容量授权）。Alpine 秒级回退根因此已无本机副本【实测的否定结论】；等价回退物是否存在**未取证**（未做主机侧 `backup/` 核对，本节只读设备）。

## 3. systemd 与桌面链【实测】

| 命令 | 输出 | 判据 |
|---|---|---|
| `systemctl is-system-running` | `running` | 无 degraded |
| `systemctl --failed --no-legend` | 空（0 行） | FAIL=0 |
| `systemctl list-jobs --no-legend \| wc -l` | `0` | 无挂起 job |
| `systemctl is-active graphical.target` | `active` | 桌面目标达成 |
| `systemctl is-active greetd` | `active` | 登录器在跑 |

进程计数（`for p in …; do ps -eo comm | grep -cx $p; done`，项目口径写法）：

| 进程 | 计数 | 说明 |
|---|---|---|
| greetd | **2** | 主进程 + session child（口径：≥1 即正常；2 = greeter 子进程） |
| phoc | 1 | 合成器 |
| phosh | 1 | shell |
| phosh-osk-stub | 1 | 虚拟键盘 |
| NetworkManager | 1 | |
| wpa_supplicant | 1 | |
| systemd-udevd | 1 | |

→ 四件套齐全，与 `reports/audit-20261119/README.md` §2「greetd + phoc + phosh + phosh-osk-stub」及 §5「回最优 Linux 桌面」记账一致。

### 3.1 六个 mask 状态【实测：全部 masked】

`for s in …; do systemctl is-enabled $s; done`（`rc=1` 因 masked 非 enabled，属预期）：

```
droid-juicer.service            masked
plymouth-start.service          masked
plymouth-quit.service           masked
plymouth-quit-wait.service      masked
plymouth-switch-root.service    masked
hexagonrpcd.service             masked
```

与 `PITFALLS` #694 / `PITFALLS/sessions/326-*.md`、`README.md` §5 记账一致。

## 4. 图形与 Mesa【实测】

| 项 | 值 |
|---|---|
| `/dev/dri` | `card0`、`renderD128`、`by-path`（DPU 已绑定，非 simpledrm） |
| `/sys/class/graphics/fb0/virtual_size` | `1904,3040`（3K 竖屏，与 `msm_drm.dsi_display0=…3k_dsc_vid` 一致） |
| `dpkg -l \| grep -ci mesa` | `10` |
| Mesa 版本 | `mesa-libgallium 26.1.6-1~bpo13+1`（`Status: install ok installed`）；`libegl-mesa0`/`libgl1-mesa-dri`/`libglx-mesa0` 同为 `26.1.6-1~bpo13+1` |

→ 与 `README.md` §2「Mesa 26.1.6（trixie-backports）」「fb0 1904×3040」逐项吻合。

## 5. 网络【实测 / 部分未取证】

```
ip -br a
lo      UNKNOWN  127.0.0.1/8 ::1/128
usb0    UP       192.168.7.1/24 fe80::1e:5eff:feed:e101/64
wlan0   UP       114.214.230.246/21 2001:da8:d800:5e64:21ab:6869:91a2:273e/64 fe80::6f71:db82:da2b:5db0/64

ip route
default via 114.214.224.1 dev wlan0 proto dhcp src 114.214.230.246 metric 600
114.214.224.0/21 dev wlan0 proto kernel scope link src 114.214.230.246 metric 600
192.168.7.0/24 dev usb0 proto kernel scope link src 192.168.7.1
```

- **默认路由经 wlan0**（IPv4），`usb0` = 保留 SSH 通道（192.168.7.0/24），双栈都已起。
- `iw dev wlan0 link` → **未取证**：设备上无 `iw`（`bash: iw: 未找到命令`）。替代实测：`/sys/class/net/wlan0/operstate` = **`up`**；`wlan0` 的 driver 链接 = `ath12k_wifi7_pci`，device = `../../../0000:01:00.0`。
- **频段/SSID/速率未取证**（需要 `iw` 或 `nmcli`；本轮未装任何包，符合只读约束）。`README.md` §2 记「ustcnet 5.8 GHz」——本轮未复核，标【未取证】。

## 6. 外设/子系统可达性【实测】

| 项 | 结果 |
|---|---|
| `/dev/fastrpc-adsp` | 存在：`crw-rw---- 1 fastrpc fastrpc 10,264`（另有 `fastrpc-cdsp` 10,262、`fastrpc-cdsp-secure` 10,261）→ 仅证明 **fastrpc 通道已建** |
| `ls /sys/bus/qrtr/devices` | **不存在该目录**（`没有那个文件或目录`）→ 本内核无 QRTR 总线，ADSP 上的 SSC/传感器链路未启用，与 `hexagonrpcd.service` masked 一致（对照 `INDEX.md` §0「hexagonrpcd 保持 mask 直到取证通道建好」、`PITFALLS` #692） |
| `aplay -l` | **未取证**：设备无 `aplay`（未装 alsa-utils）；音频卡枚举需要 `aplay`/`/proc/asound/cards`，本轮未复核 |
| `ls /dev/video*` | `video0`–`video16` 共 17 个节点（camss/venus 面已注册，未做流验证） |

## 7. 温度与供电【实测】

- thermal：55 个 zone，全部可读，**最高 = `pm8550ve-d-thermal`/`pm8550ve-f`/`pm8550ve-g`/`pm8550vs-j`/`pmih0108`/`pm8550` 均 37.0 °C**；CPU 大核 `cpu-0-2-1-thermal` 36.9 °C、`cpuss-0-0` 33.8 °C；GPU `gpuss*` 30.6–31.4 °C；`ddr-thermal` 31.2 °C。空闲态无热点（阈值面未见 trip 触发，未读 trip_point）。
- power_supply：`qcom-battmgr-bat` **capacity=100, status=Charging**；`ucsi-source-psy-pmic_glink.ucsi.01` Charging、`.02` Not charging；`qcom-battmgr-usb`/`-wls` 无 capacity（非电池）。

## 8. dmesg 摘要（`dmesg | grep -iE 'error|fail|deferred' | tail -20`）【实测】

| 类别 | 条目 | 判读 |
|---|---|---|
| 已知良性 | `faux_driver regulatory: Direct firmware load for regulatory.db failed with error -2` + `cfg80211: failed to load regulatory.db` | 缺无线管制库；只影响监管域，不影响连通（wlan0 已 up 并持 IP） |
| 已知良性 | `qcom_pmic_glink: Failed to create device link (0x180) with supplier a600000.usb / 5-0042 / 5-0043` | USB-C 角色切换的 device link 告警，非致命（usb0 正常） |
| 已知 | `snd-sc8280xp sound: ASoC: Parent card not yet available, widget card binding deferred` | 声卡绑定延迟（未验证是否最终成功 → 音频面 **未取证**，见 §6） |
| 关注 | `ath12k_wifi7_pci 0000:01:00.0: failed to set mhi state: POWER_ON(2) / failed to start mhi: -110 / failed to power up / failed to create soc 0 core / probe with driver ath12k_wifi7_pci failed with error -110`（7.6 s） | **WCN7861 首次 probe 失败 -110**，但运行时 `wlan0` 的 driver 仍是 `ath12k_wifi7_pci` 且已 up → 存在后续重试成功/或 probe 后走恢复路径；**是否重试成功需 `dmesg | grep ath12k` 全量或 `journalctl -b -k \| grep ath12k` 复核 → 本轮未取证**。这是本轮最值得跟进的单点。 |
| 关注 | `[init] WARNING: payload-modules-load failed/timed out`（9.3 s） | 自研 init 的 payload 模块装载超时；与 `deploy-modules.sh` 部署面相关，细节未取证 |
| 关注 | `[ 1364.05 / 1364.12] [drm:dpu …] vblank timeout: 400000` + `wait for commit done returned -110`（2 次） | DPU 两次 vblank 超时（up≈1364 s 时）；当前 `fb0`/桌面仍在，属**偶发显示抖动**，根因未取证 |
| 低优先 | `failed while handling packet from 10:-2`（0.8 s）、`amba 109ab000.tn: deferred probe pending: (reason unknown)`（20 s） | 启动早期杂项 deferred |

## 9. 与「历史最优 Linux 模式」的差距表

目标定义 = `reports/audit-20261119/README.md` §2 一句话：**`boot_b` 持久件 + `linux17`（193 G，label `linux`）+ minbase→resize2fs 190 G + 49 包日用基线 + Phosh/Mesa 26.1.6 桌面**。

| 项 | 现状（本轮实测） | 目标 | 差 | 动作 / 现成脚本 |
|---|---|---|---|---|
| 内核版本 | vk189-suspend `7.3.1-debug…#32`（`g4bdf1711b5c0`） | vk192 构建件（`README.md` §2 记账） | **可能落后一版**：`uname` 标 vk189，README 标 vk192 → **两处口径不一致，未取证谁对** | 只读核对：`scripts/build-kernel.sh`（构建）+ `deploy-modules.sh`（整套 `/lib/modules/<UTS>`）；版本账核对促 `scripts/vk-identity.py` **禁重跑**（项目记忆），改用 `versions/*.tsv` 对照 |
| 根分区 | `/dev/sda17` = `linux17` 193 G，用 4% | 同 | 无差 | — |
| Alpine 回退根 | `linux18` 已不存在 | 等价回退物（boot_b 签名镜像 + 主机备份） | **未取证**（本轮只读设备） | 主机侧核对 `backup/<SN>-<容量档>/`（`DEVICE/README.md`） |
| 桌面四件套 | greetd/phoc/phosh/phosh-osk-stub 全 1（greetd 2），graphical.target active | 同 | 无差 | 复核可用 `scripts/deploy-desktop-shell.sh --check`（期望 MISS=0，**本轮未跑**，见 §9 注） |
| 图形 | card0 + renderD128，fb0 1904×3040，Mesa 26.1.6 | 同 | 无差 | `scripts/mesa-deploy.sh`（如需回滚/重装） |
| 网络 | wlan0 up + IPv4/IPv6 + 默认路由；usb0 保留 | 同 | 无差 | — |
| 时间 | chrony 已同步（2026-11-19） | 同 | 无差 | — |
| 无线固件 | `ath12k_wifi7_pci` 首 probe -110（后续 up） | 无 -110 的干净 probe | **差** | 未设脚本；取证入口 `journalctl -b -k \| grep ath12k`、`dmesg \| grep -i mhi`；固件部署面 `scripts/deploy-bt-suspend-guard.sh` 邻近（WCN 面）不在本轮范围 |
| 音频 | `snd-sc8280xp` 绑定 deferred，`aplay` 缺失 | 声卡可用 | **未取证** | `scripts/deploy-modules.sh`；验证需 `aplay -l`（未装 alsa-utils） |
| 传感器/SSC | 无 QRTR 总线，hexagonrpcd masked | （G1 未结项项）启用需取证通道先行 | 按设计暂缓 | `PITFALLS` #692 前置清单 + 技能 `y700-adsp-ssc-sensors-bringup` |
| systemd 健康 | running / failed 0 / jobs 0 | 同 | 无差 | `scripts/check-doctor.sh`（主机侧门禁） |
| 6 个 unit mask | 全部 masked | 同（本轮审计前动作已落地） | 无差 | `PITFALLS` #694 |

> §9 注：`deploy-desktop-shell.sh --check` 会占 SSH 若干秒且可能触发设备侧只读扫描；**本轮以 15 分钟落盘为硬约束未跑**，故四件套判据用 §3 的进程计数 + `graphical.target is-active` 替代（两者等效但不完全等价于脚本的 MISS 计数）。

## 10. 「Android 分区未受影响」的证据

判据命令：`lsblk -o NAME,SIZE,PARTLABEL`（本轮全文输出见 §2 采集过程）。关键行（**逐字取自本轮实测**）：

```
sda10        22G super
sda13        64M metadata
sda16     256.7G userdata
sde12        96M boot_a
sde45        96M boot_b
sda1          3M proinfo        (未动)
sda6         32M persist        (未动)
sda8f        512K keystore      (未动)
```

推论链（只读证据，未做任何写/挂载）：

1. `super` = **22 G**、`userdata` = **256.7 G**、`metadata` = **64 M** 三者尺寸与 `README.md` §2「全部原样保留」一致，无 GPT 尺寸漂移 → 动态分区/用户数据布局未变。
2. `boot_a`（`sde12`, 96 M）与 `boot_b`（`sde45`, 96 M）**成对存在**，且当前 cmdline `androidboot.slot_suffix=_b` → Linux 走 b 槽、a 槽留给安卓，符合「共存契约」（`TASKS/README.md`、`reports/audit-20261119/A5-forks.md` 的 `boot_a↔boot_b` 物理互斥项）。
3. 本轮**未执行** `mount`、`fastboot`、`dd`、`reboot`、`qbootctl`、`slot-attr.py`、`slot-switch.sh` → 设备侧写面为零改动（代理约束 + 命令清单自证）。
4. `verifiedbootstate=orange` 属既有解锁态，非本轮引入。

**局限性（显式声明）**：上述是**分区表/尺寸层面的未受影响证据**，不是内容校验（未做 `sha256`/`fastboot getvar` 读数，且项目规则禁止对 >200 MB 文件跑 sha256）。`super`/`userdata` 的文件系统内部一致性**未取证**。

---

## 11. 采集缺项汇总（本轮未能取证，均因工具缺失或约束）

| 缺项 | 原因 | 复核方式 |
|---|---|---|
| 前任 A2/A8 结论 | 两个 jsonl 仅含 usage 元数据，无文本 | 需要 fabric 侧原始事件流（不在 `~/.pi/agent/sessions/`） |
| `iw dev wlan0 link` | 设备无 `iw` | `nmcli dev wifi` 或装 iw（**禁止本轮安装**） |
| `aplay -l` | 设备无 `aplay` | 装 alsa-utils 后跑，或 `cat /proc/asound/cards` |
| ath12k 是否重试成功 | 未跑全量 `dmesg \| grep ath12k` | `journalctl -b -k \| grep -i ath12k` |
| 内核 vk189 vs vk192 口径 | 文档与 `uname` 不一致 | `versions/*.tsv` 只读对照 |
| `deploy-desktop-shell.sh --check` MISS 计数 | 时间盒约束 | 下轮跑该脚本（只读 --check） |
| Android 分区**内容**未受影响 | 只读约束 | 需要时用 `fastboot getvar`/GPT 读回（写面，需授权） |

收尾: A8 设备只读现态已落盘 reports/audit-20261119/A8-device-state.md（systemd 全绿、6 mask 齐、Android 分区零改动；3 项未取证已登记）。
