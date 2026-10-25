# 驱动模块化 × Alpine→Mobian 迁移：交界面核对与落点改判（2026-10-26 续）

> 纯主机侧 + 设备只读（`ssh 192.168.7.1` 读文件/`rc-service status`/`mount -o ro`），**零写盘**。
> 承接：`reports/vk163-modular-20261026.md`（模块化上机）、`reports/mobian-migration-plan-20261021.md`（迁移方案 A/B/C/D）、
> `reports/mobian-rootfs-artifacts-20261026.md`（S2/S3 产物）、`packaging/elden-userland`（用户态真源）。
> 状态：**S4/S5/S6 仍未落地**；本报告只改「落点判据」+ 补齐 4 个原先「未证实」的门 + 抓出 1 个真实缺口。

---

## 0. 三条改判（先看这里）

| # | 原口径 | 本轮实测 | 影响 |
|---|---|---|---|
| **J1** | 迁移方案 §3.3：唯一 Linux 分区 ⇒ 只能「**原地覆盖** rootfs」，R2 = 覆盖后无 live 回退 | 2026-10-25 f2fs 手术后**已有两块 96 GiB**：`linux18` f2fs（现役根，29.4 G 用）+ `linux17` ext4（旧 Alpine 完整副本，28 G 用，`fastboot boot` 实测可起） | **落点 = `linux17`**。Alpine 留在 `linux18` 不动 ⇒ 回退 = 重启回 `boot_b`（秒级），R2 从「不可用级」降为「无风险」。**方案 §3.3 的路线① 作废** |
| **J2** | 迁移「不需要动 boot.img」（因为只换分区内容） | 根分区由 **cmdline 里的 `elden_root=LABEL=`** 决定（`initramfs/init:241-291`），cmdline 烧在 boot.img 里 | 换根**必须**换 boot 镜像。但可用 `fastboot boot`（零写盘）跑候选镜像 ⇒ **S7 变成一条命令**，不必写槽、不碰 AVB/qbootctl |
| **J3** | `hexagonrpcd-adsp-sensorspd` 是包提供（`services.tsv` 写成 `init=package`），U6「sid 0.4.0 是否含该入口」未证实 | sid `hexagonrpcd 0.4.0-2` **没有**这个二进制；但同一个 `/usr/bin/hexagonrpcd` 支持 `-s`（= attach sensorspd），且 README.Debian 文档化了 override 变量；Alpine 侧等价命令就是 `-f /dev/fastrpc-adsp -d adsp -s -R <fw>` | **不需要自编包**，用 systemd override 复刻。`services.tsv` 该行语义要改写（见 §4） |

---

## 1. J1 的证据（设备只读）

```
ssh root@192.168.7.1:
  /proc/cmdline        → elden_root=LABEL=linux18      # 现役根
  findmnt /            → /dev/sda18 f2fs 96G 29.4G 用 66.6G 免费
  blkid                → sda17 ext4 LABEL=linux17 / sda18 f2fs LABEL=linux18
  mount -o ro /dev/sda17 /mnt/l17:
      du -sh 28G；62 个顶层项；/etc/alpine-release = 3.24.2；/lib/modules 13 个目录
```
⇒ `linux17` 是 f2fs 手术前的**完整可起 Alpine 根**（`DEVICE/README.md` §1.1 口径：留作回退根）。
⇒ Debian 落 `linux17` 之后，**同一台机器同时具备**：Alpine(f2fs, 现役) + Debian(ext4, 候选) + 两个各自可起的 boot 镜像。
⇒ 新增前置：`linux17` 现有 28 G 旧根必须**先归档**（否则丢掉第二个回退点）。归档去向 = `backup/`（主机已有
`env-pass/backup-20261002/linux17-rootfs-20261002.tar.gz` 3.44 GB，可作对照；是否重打按实际差异决定）。

## 2. J2 的证据

```
scripts/build-boot.sh:63   ROOTARGS="${ROOTARGS-elden_root=LABEL=linux17}"
out/boot-elden-vk152.manifest  cmdline=… elden_root=LABEL=linux17 …
out/boot-elden-vk163.manifest  cmdline=… elden_root=LABEL=linux18 …
initramfs/init:241-291     elden_root → findfs/blkid → mount -t <blkid TYPE> → switch_root /newroot /init|/sbin/init|/bin/sh
```
⇒ 候选 Debian 镜像 = 现有 vk163 构建 + `ROOTARGS=elden_root=LABEL=linux17`，**内核/DTB/ramdisk 三个变量全不动**
（`fastboot boot` 不需要签名/AVB，`PITFALLS #76/#387` 的 v3 header 坑不适用：沿用 v2 header 已验证）。
⇒ 回退：`PITFALLS #90/#406` —— `fastboot boot` 的镜像**会活过暖复位**，退回必须 `reboot2 bootloader` + `fastboot reboot`。

## 3. 模块化 × 迁移的四个交界面（本报告的主要增量）

### 3.1 模块树：`depmod -b` 主机侧可做（S4 自动化前提，已实测）

```
UTS=7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk163
out/modstage-vk163/lib/modules/$UTS/   1529 个 .ko / 89 MB
modinfo ath12k.ko → vermagic 7.3.0-rc7-debug-vk127-…-debug-vk163 SMP preempt mod_unload aarch64
cp -a out/modstage-vk163 /tmp/mstest && depmod -b /tmp/mstest $UTS   → rc=0，modules.dep.bin 198 KB
```
⇒ **S4 不需要 chroot/root**：`depmod -b <目标根> <UTS>` 即可（depmod 与 arch 无关）。
⇒ 硬约束不变：`CONFIG_MODVERSIONS` 未开（config 实测只有 `CONFIG_MODULE_UNLOAD=y`）⇒ **没有 CRC 门**，
   错配静默加载后 panic（`reports/kernel-abi-variants-20261020.md`）⇒ 迁移后必须防 Debian 装 `linux-image-*`
   （`check-pkgmap.sh` 的禁用项门已在做）。

### 3.2 谁负责加载模块：`/init` 保留为 pre-systemd lifeline（**省掉 7 类 unit 的一半**）

`/init` 的磁盘根分支现状（`initramfs/init:388-440`）：
- `init_mode=openrc` ⇒ 先做 usb0 gadget + udhcpd + sshd + 相机/载荷模块 + 起 ttyGS0/GS1，**最后** `exec /sbin/init`；
- 其它值（legacy）⇒ 自己拉起桌面（`start-desktop.sh`），不交棒。

⇒ **Debian 侧最优解不是把 lifeline 全翻成 systemd unit，而是给 `/init` 加一个 `systemd` 模式**：
   等价 openrc 分支的行为（交棒 PID1），但跳过 `start-desktop.sh`。这样：
- 恢复通道（usb0 192.168.7.1 + sshd + ttyGS1）在 **systemd 起来之前**就可用 —— 正是 R2/R1 最需要的性质；
- `payload-modules-load.sh` / `camera-modules-load.sh` 的**有序加载**保留（systemd 的 `modules-load.d` 不做顺序保证）。

Debian（glibc）侧 applet 可用性已实测（`busybox 1:1.38.0-3+b1`，动态链 glibc）：
```
qemu-aarch64 -L /opt/elden/arm64-sid ./usr/bin/busybox --list \
 | grep -E '^(blkid|findfs|switch_root|setsid|getty|udhcpd|insmod|mdev|depmod|modprobe)$'   → 10/10 命中
```
⇒ `/init` 在 Debian 根上**只需要**把 `busybox` 加进 apt 清单（已在），不需要换成 klibc 版本。
⚠️ 待办：`init_mode` 判定要认新值（现在只有 `openrc` vs 其它）；改动会同时影响 Alpine 现役根 ⇒ 属**双根兼容改动**，需单独一发验证。

### 3.3 动态 musl 二进制：不是阻断项（原 T14 的「必重编无 recipe」已被 sources.tsv 取代）

设备实测 7 个 ELF：
| 二进制 | 链接方式 | 迁移处置 |
|---|---|---|
| `elden-hapticd` / `eldroid-sensord` / `ffrumble` / `reboot2` | **静态** | 直接搬 |
| `elden-ime-focusd` / `waydroid-sensord` / `waydroid-sensord-udp` | 动态，interp `/lib/ld-musl-aarch64.so.1` | 用 `out/ime-host/`、`out/sensord-host/` 的 glibc 产物（interp `/lib/ld-linux-aarch64.so.1`，`sources.tsv` 全部 `status=ok`） |

兜底（若临时想直接跑 musl 产物）：Debian `musl 1.2.6-1` 提供 `/lib/ld-musl-aarch64.so.1`。
⇒ `packaging/elden-userland/MANIFEST.tsv` 的 ELF 是**设备副本**（`repo_src=-`），迁移时按 sources.tsv 的 host 产物铺。

### 3.4 apt 清单：**抓到一个真实缺口**（S2 门禁覆盖不到的那一类）

`check-pkgmap.sh` 只保证「120 个 apk world 行都有映射」，不保证「服务实际用到的命令有包提供」。
离线依赖闭包模拟（主机可跑，3.3 s）：
```
apt-get -s --no-install-recommends \
  -o Dir::State::Lists=/opt/elden/arm64-sid/var/lib/apt/lists \
  -o Dir::State::status=/opt/elden/arm64-sid/var/lib/dpkg/status \
  -o Dir::Cache=/tmp/apsim -o APT::Architecture=arm64 \
  install $(grep -v '^#' rootfs/debian/apt-list.txt | tr '\n' ' ')
→ 674 个 Inst（闭包）
```
闭包内（**自动带入，不需改 apt-list**）：`systemd` / `udev` / `dbus` / `kmod` ✅
闭包外（**缺，必须补**）：

| 缺的包 | 谁需要（证据） | 提供的东西 |
|---|---|---|
| `python3` | `services.tsv:ssc-udp-relay` → `/usr/bin/python3 /usr/local/bin/ssc-udp-relay.py`；`waydroid` 的 `Depends:` 也含 python3 | `/usr/bin/python3`（`python3-minimal` 只提供 `python3 -> python3.14` 链接，解释器本体在 `python3.14-minimal`） |
| `libglib2.0-bin` | 脚本 8 处 `gdbus`、7 处 `gsettings` | `/usr/bin/gdbus` |
| `sysvinit-utils` | `pidof` 6 处 | `/usr/bin/pidof`（`procps` **不**提供） |
| `psmisc` | `killall`（`waydroid-*` 脚本族） | `/usr/bin/killall` |
| `alsa-ucm-conf` | UCM2 基线目录（自研 UCM 落在 `ucm2/Qualcomm/sm8750/`，顶层 include 来自此包） | `/usr/share/alsa/ucm2/**` |
| `ca-certificates` | `net-selfheal.sh` 信任链修复 + 所有 HTTPS | `/usr/sbin/update-ca-certificates`、`/etc/ssl/certs/ca-certificates.crt` |
| `login` | `/init` 的 `getty` 默认 `-l /bin/login`（现在显式 `-l /bin/sh`，但 systemd getty 会用到） | `/bin/login` |

⇒ **待做**：这 7 个走 `pkgmap.tsv` 的 `add` 行（`note` 写明「apk-world 里没有 = Alpine 侧由依赖自动带入 / 服务运行时依赖」），
   再由 `check-pkgmap.sh` 重新生成 `apt-list.txt`；并给门禁**加 E 段**（依赖闭包：必需命令 ↔ 提供包 ↔ 闭包内）。

## 4. J3 的证据与改写

```
/tmp/debs/hexagonrpcd_0.4.0-2_arm64.deb 文件清单：
  /usr/bin/hexagonrpcd, /usr/libexec/hexagonrpc/{hexagonrpcd,chrecd}
  /usr/lib/systemd/system/hexagonrpcd{,-suspend,-resume}.service
  ← 没有 hexagonrpcd-adsp-sensorspd 这个二进制/unit
man hexagonrpcd.1:  -s 「Attach to sensorspd」；-f <dev>；-d <DSP>；-R <root of served files>
README.Debian:      可 override  hexagonrpcd_device (/dev/fastrpc-adsp) / hexagonrpcd_dsp (adsp)
                    / hexagonrpcd_fw_dir (/var/lib/droid-juicer/sensors/) / hexagonrpcd_extra (-s)
```
Alpine 现役等价物（设备只读实测）：
```
/etc/init.d/hexagonrpcd-adsp-sensorspd:
  command_args="-f /dev/fastrpc-adsp -d adsp -s"   (+ -R $hexagonrpcd_fw_dir)
/usr/share/hexagonrpcd/hexagonrpcd-adsp-sensorspd.conf:
  hexagonrpcd_fw_dir=/usr/share/qcom/sm8750/LENOVO/TB322FC
```
⇒ Debian 侧 = `hexagonrpcd.service` 的 drop-in：
```
[Service]
Environment=hexagonrpcd_device=/dev/fastrpc-adsp hexagonrpcd_dsp=adsp \
            hexagonrpcd_extra=-s hexagonrpcd_fw_dir=/usr/share/qcom/sm8750/LENOVO/TB322FC
```
**新事实（S3 的固件包要核）**：传感器 DSP 目录是 `/usr/share/qcom/sm8750/LENOVO/TB322FC`
（设备实测存在，**550 KB**：`sns_reg.conf` + `config/` + `registry/`，属主 `fastrpc:fastrpc`），
而 `elden-firmware` 包当前内容是 `/lib/firmware/**` ⇒ **该路径不在包内**。
迁移前必须把这个目录（或 `droid-juicer` 产物）补进 S3 物料，否则传感器链在 Debian 上必死。
⇒ `services.tsv` 里 `hexagonrpcd-adsp-sensorspd` 的 `init=package, exec=/usr/bin/hexagonrpcd-adsp-sensorspd` 语义改为
  「`init=package` + 由 `hexagonrpcd.service` drop-in 承担」，`iio-sensor-proxy` 的 `after` 要指到 `hexagonrpcd.service`。

## 5. 驱动模块化剩余面（与迁移的先后）

现状 `patches/config-vk163-modular-20261025`：payload 全 `=m`，但下列仍 `=y`（实测 grep）：
`DRM_MSM / DRM_PANEL_NOVATEK_NT36536 / DRM_PANEL_BRIDGE / QRTR / ARM_SMMU / QCOM_LLCC / SCSI_UFS_QCOM /
PHY_QCOM_QMP_PCIE / PCIE_QCOM / SOUNDWIRE / I2C_QCOM_GENI / SPI_QCOM_GENI / PINCTRL_SM8750 /
INTERCONNECT_QCOM_SM8750 / QCOM_RPMH / ARM_QCOM_CPUFREQ_HW`；`QCOM_SSC_BLOCK_BUS` 未设。
⇒ **判定：迁移落地前不要翻 DRM/panel 成 `=m`**（`fragment-modular-video.config` 保留不用）。
   理由：显示一旦是模块，模块树缺失/加载顺序错 = 看起来像砖；而 Q28 显示链本身是未结项风险。
   顺序建议：**先 Debian rootfs 能起（显示走 `=y` 的旧路径）→ 再单独一发 video 模块化 A/B**（单变量原则）。

## 6. 建议的执行序（最小风险优先，全部可回退）

| 步 | 动作 | 门禁 | 写盘？ |
|---|---|---|---|
| **M1** | `pkgmap.tsv` 补 7 个 `add` 行 → 重生成 `apt-list.txt`；`check-pkgmap.sh` 加 E 段（闭包门） | `FAIL=0`；闭包模拟里 7 个提供包全部命中 | 否 |
| **M2** | `linux17` 旧 Alpine 根归档（`backup/…/linux17-rootfs-20261026.tar.zst`），归档 sha 双向核对 | `tar -d` 零差异 | 读设备 |
| **M3** | S4：`elden-firmware_*.deb` + `depmod -b` 装进**目标根暂存树**；`out/stage-debian/` | vermagic 逐字、`modules.dep` 无 not found、DT `firmware-name` 全覆盖 | 否 |
| **M4** | S6：18 个 systemd unit + `hexagonrpcd` drop-in + `/init`（`systemd` 模式）铺进暂存树；`systemd-analyze verify` | 单元语法 + 语义红线 5 条 | 否 |
| **M5** | 在 chroot 里装 `apt-list`（需 root：`scripts/host-arm64-chroot.sh` 同款前提）→ 出 rootfs tarball | `dpkg --print-architecture=arm64`；`/sbin/init` 存在 | 否 |
| **M6** | 候选镜像 `ROOTARGS=elden_root=LABEL=linux17` → `fastboot boot`（零写盘） | `findmnt / = sda17`、`ps -p1 = systemd`、桌面目视、`qbootctl` 不参与 | **零写盘** |
| **M7** | 绿了才写 `boot_b`（先 `dd` 备份 + `slot-attr.py show` 基线） | 连续 3 次 reboot `retry` 不减、`succ=1` | 是（需备份） |

## 7. 复现命令（全部主机侧/只读）

```bash
# J1：两块根 + 现役根
ssh root@192.168.7.1 'cat /proc/cmdline; findmnt -no SOURCE,FSTYPE,SIZE,USED,AVAIL /; blkid | grep linux1'

# 3.1 模块树 depmod（不需要 root）
cp -a out/modstage-vk163 /tmp/mstest && depmod -b /tmp/mstest \
  7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk163 && echo rc=$?

# 3.2 Debian busybox applet 覆盖
curl -sSO https://mirrors.ustc.edu.cn/debian/pool/main/b/busybox/busybox_1.38.0-3+b1_arm64.deb
dpkg-deb -x busybox_*.deb /tmp/bbx && qemu-aarch64 -L /opt/elden/arm64-sid /tmp/bbx/usr/bin/busybox --list

# 3.4 apt 依赖闭包（离线，3.3 s）
apt-get -s --no-install-recommends \
  -o Dir::State::Lists=/opt/elden/arm64-sid/var/lib/apt/lists \
  -o Dir::State::status=/opt/elden/arm64-sid/var/lib/dpkg/status \
  -o Dir::Cache=/tmp/apsim -o APT::Architecture=arm64 \
  install $(grep -v '^#' rootfs/debian/apt-list.txt | tr '\n' ' ') | grep -c '^Inst'
```

## 8. 未解 / 待核

- `linux17` 上的 28 G 旧根是否与 `env-pass/backup-20261002/linux17-rootfs-20261002.tar.gz` 有实质差异（决定归档策略）。
- `squeekboard 1.43.1-2.1` 是否仍提供 `sm.puri.OSK0` 控制面（U5，未验；`elden-ime-focusd` 依赖）。
- Debian `phoc/phosh 0.58.0` 上两枚补丁的行为（U1/U2，只能上机）。
- `net-selfheal.sh` 的 `*.apk-new` 段落要改指 `.dpkg-new/.dpkg-dist`（当前在 Debian 上是死循环 = 无害但失效）。
- 本报告**没有**启动任何设备写操作；设备留在「Alpine f2fs 现役根 + boot_b=f2fs-root」安全态。
