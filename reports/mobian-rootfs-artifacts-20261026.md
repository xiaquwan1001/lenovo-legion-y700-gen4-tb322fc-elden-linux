# Mobian 迁移物料（第一步）：apt 包映射表 + 自建固件包

> 日期：2026-10-26 ／ 纯主机侧（读设备 `/lib/firmware` 与 `/etc/apk` 侧已是历史清单），零写盘
> 关联：`reports/mobian-migration-plan-20261021.md` §4 的 **S2（包集翻译）/ S3（自建固件包）**
> 结论：**S2 与 S3 已交出可门禁的产物**——`rootfs/debian/pkgmap.tsv`（120 个 apk 全部定性）+
> `out/debian/elden-firmware_1.0~20261025_all.deb`（21 MB / 116 项，DT 固件名门禁全绿）。
> 仍未动的：S4（模块树）、S5（initramfs）、S6（systemd 落地）；S1（debootstrap）已于 10-25 完成。

## 0. 为什么先做这两步

`mobian-migration-plan` §0 的成本清单里，只有两项是**纯静态、可离线验证**的：
包集合翻译（120 行 apk → apt）和固件打包。其余（模块树、initramfs、systemd 落地）都要动设备。
S2/S3 做完之后，剩下的事才有「单一清单可依」。

## 1. S2 —— `rootfs/debian/pkgmap.tsv`

### 1.1 产物

| 文件 | 内容 |
|---|---|
| `rootfs/debian/pkgmap.tsv` | 127 行 = **map 97 / drop 23 / add 7**；四列 `apk  action  debian  note` |
| `rootfs/debian/tools/check-pkgmap.sh` | 4 段门禁（覆盖度 / 可解析 / 禁用项 / 生成物），离线跑 |
| `rootfs/debian/apt-list.txt` | 生成物：**107 个 Debian 包**（map+add 去重并集），rootfs 构建的唯一安装清单 |

### 1.2 门禁判据（`bash rootfs/debian/tools/check-pkgmap.sh`）

```
统计: map=97 drop=23 add=7  解析失败=0  apt 包数=107
生成: rootfs/debian/apt-list.txt（107 个包）
结果: FAIL=0 WARN=0
```

* **A 覆盖度**：`apk-world.txt` 每一行（先剥离 world 行里残留的 apk 签名后缀 `><Q1…=`）都必须有且只有一行映射；
* **B 可解析**：每个 Debian 包名都在 **sid 索引**里查得到（`apt-cache` 直读 `/opt/elden/arm64-sid` 的
  `var/lib/apt/lists` —— 与将来真正会装进去的索引同源，不用联网、不会因网页滚动漂移）；
* **C 禁用项**：任何行都不得映射到 `linux-image-*` / `firmware-qcom-soc`
  （前者没有本机板 DTS；后者没有 `sm8750` 目录，见迁移方案 §2 #1/#5）；
* **D 生成物**：`apt-list.txt` 与映射表同步。

### 1.3 关键映射（踩过或容易踩的）

| apk | Debian | 备注 |
|---|---|---|
| `iio-sensor-proxy` | `iio-sensor-proxy` **3.9-1** | **必须 sid**：trixie 的 3.7 源码无 `drv-ssc-*`，本机 `/sys/bus/iio` 恒空（传感器在 SSC 上） |
| `libssc` | `libssc2` (+ `libssc-dev`) | Debian 二进制包名是 `libssc2`，不是 `libssc`（实测 sid 索引） |
| `bluez-btmon` / `bluez-deprecated` | drop（bluez 已含） | `packages.debian.org/sid/arm64/bluez/filelist` 实测含 `/usr/bin/btmon`、`hciconfig` 等 |
| `gnome-bluetooth` | `gnome-bluetooth-sendto` | sid 拆包 |
| `fcitx5-gtk3/4` | `fcitx5-frontend-gtk3/4` | Alpine 与 Debian 命名不同（C11 中文输入法栈） |
| `mesa-dri-gallium` | `libgl1-mesa-dri` | A830 = freedreno，Mesa 版本由 sid 决定 |
| `elogind*` / `*-openrc` / `musl*` / `apk-tools` | drop | systemd-logind / glibc 取代 |
| `android-tools` | `adb` + `fastboot` | Debian 拆两包 |
| `qbootctl` | `qbootctl`（add） | 包自带 `qbootctl.service`，装完必须 `systemctl enable`（`PITFALLS #181`） |

### 1.4 已知缺口（不在本步解决）

* 自研包没有 Debian 化：`elden-hapticd` / `ffrumble` / `waydroid-sensord(-udp)` / `elden-ime-focusd` /
  `reboot2` 目前是**文件级**部署（`packaging/elden-userland/MANIFEST.tsv`），不是 `.deb`。
  迁移时按 MANIFEST 铺文件即可；要做成包是后续可选优化。
* `linux-image-*` 永远不从 Debian 装（自编内核 + 自建模块树），这一条以「禁用项」形式进了门禁。

## 2. S3 —— `elden-firmware` 自建固件包

### 2.1 产物

| 文件 | 内容 |
|---|---|
| `rootfs/debian/elden-firmware/paths.txt` | 内容清单（3 个目录 + 5 个文件/通配），排除 `*.bak/*.tmp` |
| `rootfs/debian/elden-firmware/name-map.tsv` | DT `firmware-name` → 内核**实际请求路径**的改写表（当前 2 条：BT 的 `qca/` 前缀） |
| `rootfs/debian/elden-firmware/build.sh` | `--check / --stage / --deb / --all`；源可以是设备（ssh+rsync）或本地目录 |
| `out/debian/elden-firmware_1.0~20261025_all.deb` | **21 MB，116 个文件**，sha256 `3f7533d6…bebd227f` |

包内容：`qcom/sm8750/**`（adsp/adsp_dtb/cdsp/cdsp_dtb 分段、`gen80000_{zap,sqe,gmu,aqe}`、4 个 jsn、
**自编 `Lenovo-Y700-Gen4-tplg.bin`**）、`ath12k/PEACH/hw2.0/**`（amss/board-2/board/m3/regdb/tmel/aux_ucode）、
`awinic/`（haptic + speakers ACF）、`novatek_ts_csot_3k_fw.bin`、`qca/brh*`（BT 固件/ NVM / peri）。

### 2.2 门禁（`bash rootfs/debian/elden-firmware/build.sh --all`）

```
== deb → out/debian/elden-firmware_1.0~20261025_all.deb
  21M  sha256=3f7533d6…
  条目数 116 ✓
  解包后 DT 固件检查 ✓
rc=0
```

* **A DT 覆盖**：把板 DTS 的每条 `firmware-name` 当契约逐条查（`.mdt` 还要求有 `.bNN` 分段，
  允许 `.zst` 压缩变体）——本轮实测 7 条全部命中；
* **B 排除备份**：`*.bak/*.tmp` 不进包（设备上有手工备份的 `brhbtnv20.bin.bak`）；
* **C 条目一致**：`dpkg-deb -c` 的数据文件数 = 暂存树文件数；
* **D 解包复核**：把 deb 解到临时目录后再跑一遍 A（防「文件在暂存树但没进包」）。

### 2.3 两条新事实

1. **BT 固件名与 DT 不一致**：DT 写 `firmware-name = "brhbtnv20.bin", "brhbtfw20.tlv"`，
   但 `btqca` 代码里请求的是 **`qca/brhbtfw20.tlv` / `qca/brhbtnv20.bin`**
   （设备 dmesg 逐字：`QCA Downloading qca/brhbtfw20.tlv`）。所以固件包必须提供 `qca/` 下的名字；
   DT 名只作注释。这条如果没记下来，换发行版后表现就是「文件在、驱动报 -ENOENT」。
2. **不能用 `firmware-qcom-soc` 顶替**：trixie filelist 只有 sdm845/sm8250/sm8550/sm8650/x1e80100/sc8280xp，
   **没有 sm8750**。所以自建包不是「优化」，是**必需**。

### 2.4 三个实现坑（都已修，写在脚本注释里）

* `while read … < paths.txt` 里调用 `ssh`（不带 `-n`）会吞掉循环 stdin ⇒ 只处理清单第一行，
  包内容静默只剩 `qcom/sm8750`（本地 rsync 源时不会复现，只在设备源上出现）；
* 设备是 Alpine，`busybox tar` 对 `-T -`（从 stdin 读文件清单）支持不全 ⇒ 改用 `rsync --files-from`；
* `dpkg-deb -c` 不列 `DEBIAN/*`，条目数比对要按「数据文件」计数。

## 3. 与后续步骤的接口

| 步骤 | 输入（已有） | 还缺什么 |
|---|---|---|
| S4 模块树 | `out/modstage-vk163/lib/modules/<UTS>`（本轮模块化产物，1539 `.ko`） | 解包到目标根 + 目标根里 `depmod -a`（需要 arm64 chroot 里跑 depmod，或用主机 kmod 的 `depmod -b`） |
| S5 initramfs | 仓库 `initramfs/init`（已支持 f2fs/blkid）+ `scripts/build-initramfs.sh full` | Debian 侧 `initramfs-tools` hook（把 `qcom/sm8750` 固件与 **tplg** 带进 initramfs；tplg 必须在用户态前加载） |
| S6 systemd | `packaging/elden-userland/out/units/systemd`（18 个 unit，已渲染） | 目标根里铺文件 + `systemctl enable`（qbootctl / greetd / iio-sensor-proxy / wifi-scan-refresh 四条语义红线） |

## 4. 复现命令

```bash
# S2 门禁（离线，读 /opt/elden/arm64-sid 的 sid 索引）
bash rootfs/debian/tools/check-pkgmap.sh          # FAIL=0 WARN=0，并重写 apt-list.txt

# S3 固件包（默认从设备 /lib/firmware 取，可 SRC=<dir> 换本地源）
bash rootfs/debian/elden-firmware/build.sh --check   # 只验 DT↔文件
bash rootfs/debian/elden-firmware/build.sh --all     # stage + deb + 包内复核
```
