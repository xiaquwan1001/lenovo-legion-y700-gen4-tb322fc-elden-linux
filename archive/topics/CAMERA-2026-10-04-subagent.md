# CAMERA-2026-10-04 — 相机匹配基线与冷启自动加载（主机侧交付）

> 承接 `CAMERA-2026-10-02.md` §2/§4 与 `STOCK-CAMERA-GRAVITY-2026-10-02.md`。
> 本轮**只做主机侧**：产出与内核同构建的镜像/模块、冷启自动加载、更新部署脚本、给出验收步骤。
> 未刷机、未重启、未 SSH 设备。旧 archive 不改。

## 0. 结论先行（数字）

| 产物 | 路径 | 大小 | sha256 |
|---|---|---|---|
| 持久变体 boot | `out/boot-elden-vk49.img` | 92,377,088 B (88.1 MiB) | `249ee683…0c` |
| 纯 RAM 变体 boot | `out/boot-elden-vk49-ram.img` | 92,377,088 B | `ddeb5735…6c` |
| b 槽签名镜像 | `out/boot_b-vk49.img` | 100,663,296 B (96 MiB) | `1c44343c…cc` |
| 相机模块包 | `out/camera-modules-7.2.0-debug-g5a70ade46a88.tar.gz` | 9,055,008 B (8.6 MiB) | `7cd5835c…aa` |

- 内核 `uname -r` = **`7.2.0-debug-g5a70ade46a88`**（`#46 SMP PREEMPT Sun Oct 4 12:31`）。
- 模块 **20/20** vermagic = `7.2.0-debug-g5a70ade46a88 SMP preempt mod_unload aarch64`（与内核逐字节同源）。
- 镜像内核与设备 `uname` 一致；DTB 含全部相机节点（`s5kjns/gc08a8/gt9764/qcom,sm8750-camss/wl2868c`）。
- 冷启自动加载已入 ramdisk：`/init` 在 `switch_root` **之前**调用加载器 → 持久与纯 RAM 两种变体都自动生效。
- 旧缺口"rootfs 无相机模块自动加载"**已闭环**。

## 1. 与上一轮的关键差异

| 项 | 2026-10-02 | 本轮 |
|---|---|---|
| 内核 | `gba28ec16f01f-dirty`（已淘汰） | `g5a70ade46a88`（当前树，`make kernelrelease` 确认） |
| 模块包 | `…gba28ec16f01f-dirty`（旧，insmod 必失败） | `…g5a70ade46a88`（同构建） |
| 交付方式 | 运行时 scp + insmod | **ramdisk 内置 + 冷启自动加载**（零写盘路径） |
| 依赖闭包 | 17 `.ko`，手动 insmod 序 | 20 `.ko`，`modules.dep`（主机预生成）+ modprobe 解析 |
| 部署脚本 | 硬编码 KV / insmod | 动态 KV + 校验设备 `uname` 不匹配即拒绝 + 复用加载器 |

闭包从 17→20：新增 `leds-qcom-flash` 及其依赖 `led-class-flash`、`v4l2-flash-led-class`
（`leds-qcom-flash` 现列入 ROOTS，sensor 的 `flash-leds` 异步依赖）。

## 2. 构建与校验证据

构建（`flock /tmp/y700-kbuild.lock` 包住，避免与他人 kbuild 冲突）：

```bash
flock /tmp/y700-kbuild.lock -c 'cd linux && make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- modules'
flock /tmp/y700-kbuild.lock -c 'STAGE=/tmp/camera-modstage bash scripts/package-camera-modules.sh'
```

`modinfo -F vermagic` 全 20 模块 = `7.2.0-debug-g5a70ade46a88…`；解 `out/boot-elden-vk49.img`
内核流后 `strings`：

```
Linux version 7.2.0-debug-g5a70ade46a88 (…) #46 SMP PREEMPT Sun Oct 4 12:31:00 CST 2026
7.2.0-debug-g5a70ade46a88 SMP preempt mod_unload aarch64
```

ramdisk 第二段（camera 层，追加在已知可用 `rootfs-overlaid.cpio.gz.bak-vk48` 之后）含
20 个 `.ko` + `lib/modules/<KV>/modules.dep` + `usr/local/sbin/camera-modules-load.sh` + 覆盖后的 `init`。

**镜像体积纪律**：vk49 = 88.1 MiB < boot 分区 96 MiB；签名后 pad 到 96 MiB。
（构建中曾误将 camera 版 ramdisk 又当 base 叠加一次 → 镜像涨到 101 MB 超分区，已用
`BASE=out/rootfs-overlaid.cpio.gz.bak-vk48` 从干净基座重建修正。**重跑叠加务必显式指定 BASE**。）

## 3. 冷启自动加载方案

- 新增 `scripts/camera-modules-load.sh`：幂等；`depmod` 仅在无 `modules.dep` 时兜底；
  先 `camcc-sm8750`/`cambistmclkcc-sm8750`/`i2c-qcom-cci`/`wl2868c-regulator`，再 `qcom-camss`，
  最后 `leds-qcom-flash`/`gt9764`/`s5kjns`/`gc08a8`；`modprobe` 按 `modules.dep` 自动排序依赖。
  输出 `[camera] done: N media, M video nodes`。
- `rootfs/init` 在 `switch_root` 前调用（`timeout 20 … >/run/camera-modules.log`，非致命）。
  放在 `switch_root` 前可确保释放 initramfs 时无 ramdisk 文件被占用（insmod 返回即已
  `module_init`，sensor 的异步 probe 只是被**排程**，后续仍能用已加载模块）。
- 新增 `rootfs/build-camera-overlay.sh`：把模块+加载器+`/init` 作为**第二段 cpio** 追加到
  现有 ramdisk（内核按序解包并用后段覆盖同名文件），不重建 Alpine 根。

## 4. 部署脚本更新（备选：不刷 boot、不重启）

`scripts/deploy-camera-modules.sh`：

- KV 取 `patches/camera-kver`（已更新为 `7.2.0-debug-g5a70ade46a88`），否则 `make kernelrelease`。
- 传输前先 `uname -r` 校验设备运行内核；**不匹配直接拒绝**（避免旧 bug：insmod vermagic 失败）。
- 解包到 `/lib/modules/<KV>/` → 安装加载器 → 调 `camera-modules-load.sh` → 采证据。
- `ONLY_COPY=1` 只拷贝不加载。

## 5. 用户验收步骤

### 5.1 零写盘优先（设备已在 fastboot，current-slot b）

```bash
# 首选：持久根 + 相机自动加载（有桌面/全部系统服务）
fastboot boot ~/y700-elden/out/boot-elden-vk49.img

# 备选：纯 RAM（无桌面，仅验证内核/模块/sensor probe）
fastboot boot ~/y700-elden/out/boot-elden-vk49-ram.img
```

上机后（SSH `root@192.168.7.1` 或串口）采集：

```bash
cat /run/camera-modules.log                       # 应见 [camera] loaded … / done: N media
dmesg | grep -iE 'camss|csiphy|cci|s5k|gc08|gt9764|wl2868|titan|dependency cycle'
ls -l /dev/video* /dev/media* /dev/v4l-subdev*
ls /sys/bus/i2c/devices/ | sort
media-ctl -p
v4l2-ctl --list-devices
```

### 5.2 判据

**成功（最小目标 = sensor 探测 + subdev/media graph 注册）**：
- `/run/camera-modules.log` 无 `WARN: modprobe … failed`，以 `[camera] done:` 收尾。
- `/sys/bus/i2c/devices/` 出现 `0-0056`(s5kjns)、`1-0031`(gc08a8)、`0-000c`(gt9764)。
- `/dev/media0` 存在；`media-ctl -p` 列出 `s5kjns`/`gc08a8` 子设备并 link 到 csiphy/csid/vfe。
- dmesg 有 camss probe 成功；`Fixed dependency cycle(s) with …/camera@56 ↔ isp@ad27000`
  可容忍（见 §6）。

**失败**：
- 无 `/dev/media*` 且 dmesg 见 sensor `-EPROBE_DEFER`/`-517` 循环 → 查供电
  （wl2868c LDO1/4/7）、MCLK3/4、reset-gpio。
- `modprobe` 报 `invalid module format` → 内核与模块不同构建（KV 不一致），重做 §2。
- 无 `/lib/modules` 相关错误但无 sensor → 检查 `/init` 钩子是否在 ramdisk（本次已内置）。

### 5.3 可选：刷 b 槽（先经 5.1 验证后再做）

```bash
fastboot flash boot_b ~/y700-elden/out/boot_b-vk49.img   # 已用 bootslot-b/avb.key 签名，公钥 sha1 fc1e3b33
fastboot reboot
```

`out/boot_b-vk49.img` 已 pad 到 96 MiB 并带 AVB hash footer，匹配 `vbmeta_b_flags3.img` 的
`boot` 链描述符（`scripts/sign-boot-b.sh`）。

## 6. fwnode 依赖环 warning 判断

- 现象：`dmesg` 报 `Fixed dependency cycle(s) with …/camera@56 ↔ isp@ad27000`。
- 根因：`camera@56` 同时 `power-domains = <&camcc CAM_CC_TITAN_TOP_GDSC>` 且 `port` 的
  `remote-endpoint` 指向 camss（`sm8750.dtsi` 的 `isp@ad27000`），与 camss 对 camcc/GDSC 的
  引用形成 fw_devlink 设备链接环。
- **判断：本轮不处理，属可容忍 informational warning。** 内核 fw_devlink 会**主动打破环**并打印
  `Fixed dependency cycle(s)`；它不阻止 probe，只是在建立设备链接时中断一环。若 §5.2 看到 sensor
  正常注册即为"无需处理"的实证。
- 仅当出现 sensor **持续 `-EPROBE_DEFER` 不 probe** 时再处理：让 sensor 的 `endpoint` 单向
  （已单向）并确保 GDSC 单一 owner（一般由 camss 持有，sensor 仅 `power-domains` 引用）。
  改动点在 DT，非本轮范围。

## 7. 剩余缺口（超出本轮）

| 缺口 | 说明 | 规模 |
|---|---|---|
| camss 实际出流（VFE/CSID 抓帧） | 主线 ISP best-effort；`v4l2-ctl --stream-mmap` 取帧、3A/拍照 | **大，本轮未做** |
| 前后摄同时起 | 两 sensor 各自 CSIPHY/CCI，理论可共存，未验 | 小 |
| 持久盘 rootfs 内模块 | 仅放 ramdisk；持久根 `/lib/modules/<KV>` 未离线更新（冷启从 ramdisk 加载，不影响） | 小 |
| 相机 tuning/EEPROM | 出流之后 | 大 |

**本轮闭环 = "模块与内核匹配" + "冷启自动加载" + "部署脚本适配"；"实际出流"明确留待下一轮。**

## 8. 本轮改动文件

- 新增：`rootfs/build-camera-overlay.sh`、`scripts/camera-modules-load.sh`、`scripts/package-camera-modules.sh`
- 修改：`rootfs/init`、`scripts/deploy-camera-modules.sh`、`patches/camera-kver`
- 产物（`out/`，gitignore）：`boot-elden-vk49{,-ram}.img`、`boot_b-vk49.img`、
  `camera-modules-7.2.0-debug-g5a70ade46a88.tar.gz`、`rootfs-overlaid-camera.cpio.gz`、
  基座备份 `rootfs-overlaid.cpio.gz.bak-vk48`

---

## 9. 上机首验发现并修复：modules.dep 格式与 kmod 不兼容（2026-10-04）

**现象**：`fastboot boot out/boot-elden-vk49.img` 后 `lsmod` 只有
`camcc_sm8750`/`cambistmclkcc_sm8750`/`i2c_qcom_cci`/`wl2868c_regulator` 四个（均无依赖），
`qcom-camss` 与所有 media/sensor 模块缺失；`/dev/media*`、`/dev/video*` 不存在。

**根因（决定性）**：设备用的是 **kmod 34.2**（`/sbin/modprobe -> /bin/kmod`），
其 `modules.dep` 依赖项必须是**完整相对路径**（`kernel/.../x.ko`），且带 `modules.dep.bin` 索引。
本 bundle 的 `modules.dep` 由 `modinfo -F depends` 生成，是**裸模块名**（`videodev mc v4l2-async …`）
→ kmod `modprobe qcom-camss` 解析依赖失败，报 `FATAL: Module qcom-camss not found`。
无依赖的 4 个模块可按左列路径直接加载，故恰好卡在第一个有依赖的模块。

**复现/确认**：在设备上对有依赖问题的 staging 树跑一次 kmod `depmod -b`，再
`modprobe --show-depends qcom-camss` → 正确列出完整 `insmod …mc.ko …videodev.ko …qcom-camss.ko`。

**修复**：
1. `scripts/camera-modules-load.sh`：**无条件** `depmod -a "$KV"`（不再信任随包 modules.dep；
   kmod depmod 在设备上生成正确格式，20 模块 <1s）。
2. `scripts/package-camera-modules.sh`：改为用 kmod `depmod` 在规范布局上生成
   `modules.dep` + `modules.dep.bin`（弃用 `modinfo -F depends` 的裸名写法）。

**重打包产物（2026-10-04 13:50，内核未变 g5a70ade46a88）**：
`out/boot-elden-vk49.img`=`b98487b7de`、`vk49-ram`=`68932e7401`、
`boot_b-vk49.img`=`ae15737410`、`camera-modules-…tar.gz`=`25cc6c474a`。
（首版 vk49 = `249ee683`/`ddeb5735`/`1c44343c` 因该 bug 不可用，已被替换。）
