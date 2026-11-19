# 资源重审 — 按新口径「快速从原厂 Android → 能力完整 Linux」（2026-11-19）

> 范围：RESOURCES/、backup/、out/、bootslot-b/、dl-cam/、external/、patches/、reference/、versions/、packaging/、env-pass/（只读抽样，未改任何现有文件；未跑设备命令）。
> 判据基线：设备现态 = Debian 13 trixie 根（systemd PID1、greetd+phoc+phosh、内核 vk192）、现役根 label = **linux**（非 linux17/18）、Alpine 期件已不存在、Linux→fastboot 软路径不存在（PITFALLS #690）。
> 口径：**minbase 只是中间态**，不是目标态；为省体积牺牲标准组件（udev/phosh-osk 等）的叙述按缺口计。

---

## 1. 仍然有用（重建/补能力的现役资源）

| 资产 | 路径 | 大小 | 用途（新口径下） | 证据 |
|---|---|---|---|---|
| **官方 259 全量线刷包** | `backup/official-rom-15.10.259/` | 16 G | 救砖 / 固件提取 / super 基线；`backup/stock-259/` 是其 13 分区子集 | RESOURCES/README.md §2.3 行「官方全量线刷包」；抽样 sha 复核 ✅（`boot_a` d4772c11…、`vbmeta_a` 61b20210… 与 SHA256SUMS 行 3/4 一致） |
| **stock-259 双槽分区备份** | `backup/stock-259/` | 247 M | 刷 b 槽前的原厂回退源（boot/dtbo/init_boot/recovery/vbmeta 双槽） | 目录 ls 13 件；sha 抽样 ✅ |
| **EDL 全量包 + loader** | `backup/fw/tb322fc-edl/`（`~/下载/tb322fc` 软链）+ `~/edl/`（qdl v2.9 源码自建） | 599 M | 9008 救砖唯一通路（Linux→fastboot 软路径不存在，EDL 更关键） | RESOURCES/README.md §2.1「EDL 工具链」；`backup/fw/tb322fc-edl` 65 件 rawprogram/firehose |
| **厂商固件子集** | `backup/fw/{vendor,modem,bluetooth,dspso,gen80000_*}` | 782 M | 触屏(novatek)/WiFi(ath12k+peach BDF)/BT(brh*)/ADSP/CDSP/GPU zap——Debian 根补能力的第一来源 | `backup/fw/README.md` 各行（fw 命名→DT 路径对照表） |
| **b 槽自签 AVB 链** | `bootslot-b/avb.key` + `boot_b-vk192-linux17label-20261119.img`、`boot_b.img` | 1.7 G | b 槽 mainline 引导的签名权威；现役在机件 | `bootslot-b/README.md` §难点/现状表；`scripts/sign-boot-b.sh:14` 取 key |
| **现役 boot 镜像 + manifest** | `out/boot-elden-vk192.img` + `out/boot-elden-vk192.manifest` | 82 M | 设备在跑版本的构建身份 | manifest 行 5 `image_sha256=bdf47f5f…`，实测重算 **一致** ✅ |
| **GPT 手术表/快照** | `scripts/gpt-surgery-tb322fc.py`（范围外脚本，只引用）+ `backup/gpt/gpt_*_device.bin` + `backup/lun4-gpt-20261101/` + `out/edl-supermin-20261118/gpt{0,4}-{main,backup}.bin` | ~200 K | 分区重建/容量档适配 | `backup/gpt/` 4 件在盘；RESOURCES/README.md §2.2「GPT 快照（234 GiB 档专属）」 |
| **Debian rootfs 构建器 + 桌面 apt 清单** | `rootfs/debian/build-rootfs.sh` + `rootfs/debian/apt-list.txt`（149 行）+ `pkgmap.tsv` | — | 重建现役 trixie 根的**唯一权威配方**（含 phosh/greetd/iio-sensor-proxy/squeekboard/hexagonrpcd） | `apt-list.txt` 头注「由 check-pkgmap.sh 从 pkgmap.tsv 生成」；行 44 greetd / 102 phosh / 119 squeekboard / 58 iio-sensor-proxy |
| **用户态固化包（render 双 init）** | `packaging/elden-userland/`（services.tsv 唯一真源 + deps.tsv 抽象依赖词表 + systemd units 渲染） | ~小 | 解决「换 rootfs 静默丢自研能力」的根因；systemd 列即 Debian 现态所需 | `packaging/elden-userland/README.md` 三条硬规则；`MANIFEST.tsv` 含 `/etc/udev/rules.d/81-libssc-elden.rules` |
| **AVF 离线提取资产** | `backup/avf/`（crosvm/vm/microdroid_* + SHA256SUMS） | 249 M | G2 备选 VM 路线，离线可复原（`scripts/extract-avf-assets.sh`） | RESOURCES/README.md §2.2「AVF 资产」 |
| **自编 Waydroid bionic Mesa** | `external/mesa-out/mesa-vendor-26.1.8_waydroid_arm64_only.tar.gz`（11 .so，含 chip-id 魔数） | 6.9 M | G2 图形栈，重建 = `scripts/mesa-build.sh` | RESOURCES/README.md §2.2 行「Waydroid Mesa 26.1.8」 |
| **Waydroid 镜像 + vendor 烘焙链** | `~/下载/` GAPPS system.zip(1.17 G)+vendor.zip(77 M)（软链）+ `dl-cam/` HAL 交叉构建物（bionic ELF）+ `external/aosp-vndk33` | 639 M+74 M | 相机 HAL（dl-cam/out-cam 抽样 = aarch64/Android33 bionic ELF ✅ 可部署）与 vendor.img 烘焙 | `file dl-cam/out-cam/android.hardware.camera.provider@2.4-external-service` = bionic ELF ✅ |
| **内核树 bundle（版本账兜底）** | `backup/git-slim-20261113/{main,geekidos,m3v2}-all-20261113.bundle` | 1.2 G | geekidos-linux 已删后的唯一重建源 | RESOURCES/README.md §1.1 行「GEEKiDoS/linux ⛔2026-11-19 清理已删」，重建命令内联给出 |
| **U2 解锁前取证 / 设备独有 dump** | `backup/HA2EXB0E-16+512/`（c0-baseline、current-259、edl-20261118、boot_b-before-* 系列） | 1.2 G | 设备等价身份证据，不可再生 | `ls backup/HA2EXB0E-16+512` 各子目录 |
| **Gunyah 参照集** | `reference/gunyah-refs/`（g612 全 17 文件 + crosvm 切片） | 6.1 M（reference 总量） | 7.3 移植唯一参照，勿重下 | RESOURCES/README.md §1.5 ★行 |
| **env-pass 设备脚本** | `env-pass/scripts/envpass-provision.sh` 等 6 件 + `env-pass/tools/` | 60 K | 状态预检/模块 repack（幂等，--check 干跑过） | 目录 find 列表 |
| **Packaging out（固化 deb）** | `out/debian/elden-firmware_1.0~20261028_all.deb` | — | 固件落 `/lib/firmware` 的打包件 | `ls out/debian` |
| ~~Elden GPL 厂商源码~~ | ~~`stock-src/`~~ | （原 2.0 G） | **死指针**：已随 2026-11-16 A 类磁盘清理删除（INDEX.md:122），RESOURCES/README.md §1.1 首行的 ✅ 状态过期；反查厂商 compatible/固件名时需从 Lenovo GPL 官网重取 | 见本表 + INDEX.md §0 行 8 |

## 2. 过时 / 不可用 / 「最小化执念」件（逐条 + 建议，**只建议不动手**）

| 资产 | 证据 | 为什么过时 | 建议 |
|---|---|---|---|
| `packaging/elden-userland/files/init`（手写 PID1 `/init` 快照） | 行 531/533：`mdev=$(findfs LABEL=linux17 …)`；注释「partition 17 = linux17」 | ① 指向已删分区 **linux17**（现役 label=linux）；② Alpine 期**手写 /init** 正是新口径要废弃的形态（systemd 已是 PID1）；③ 该文件是 OpenRC/Alpine 采集件 | **归档**：在 `MANIFEST.tsv`/services.tsv 中按「历史采集件」标记，渲染管线已由 systemd 模板取代，勿再部署 |
| `rootfs/persistent-overlay/`（含 `elden-hapticd.initd`、`apk-world.txt`、手写 init） | `ls rootfs/persistent-overlay`：`apk-world.txt`（apk 世界文件）、`*.initd` | Alpine 期产物（apk/initd）；设备上 OpenRC/apk 已不存在 | **归档**（保留文本作为服务语义考据；权威已在 packaging/elden-userland 的 systemd 渲染） |
| `external/alpine-sysroot/`（94 M） | `usr/lib/ld-musl-aarch64.so.1` **不存在**（实测 open 失败），只剩 include 头 | musl 交叉 sysroot 的 lib 已残缺；新口径用户态 = glibc/Debian（工具链 `~/toolchains/aarch64-linux-musl-cross` 时代已过） | **归档/删**：include 集合可由 Debian `libc6-dev-arm64-cross` 替代；确认 `phoc-work`/`lc-cross` 构建不再引用后清 |
| `out/android-slim-v2-20261119/`（237 M）与「edl-supermin」叙事 | `du`：slim 237 M vs `android-min-avb-20261118` 15 G | 「为省体积做 slim」= 典型最小化执念产物；minbase 仅排查中间态 | **归档**：目录名与 README 均应注明「中间态，非目标态」 |
| `bootslot-b/boot_b-minbase-labellinux-20261119.img`（96 M） | 文件名即 minbase+labellinux | minbase 档 boot 件，作为「快速排查通道」保留有价值，但**不是目标态**产物 | **保留**（近期现役排查件），但在 `bootslot-b/README.md` 现状表里标注定位 |
| `bootslot-b/boot_b-vk192-linux17label-20261119.img` | 文件名含 **linux17label** | 与现役 label=linux 矛盾的当日变体（cmdline 指向 linux17），现态下引导会找不到根 | **归档**：与 `boot_b.img`(现役) 区分，防误刷；台账加 label 字段 |
| `bootslot-b/boot_b-vk127/128/129/145/151/152/163/181/185/187b…`（10 件 × 96 M ≈ 0.9 G） | ls 逐一列出 | 历史 b 槽 dump，vk 号都在 `versions/vk-kernel-identity.tsv` 有账 | **归档到 out-history 式目录**（或按 B3 先例保留 1–2 个里程碑 + 全部 manifest），需逐号过账后批 |
| `out/SUPERSEDED.md` 所列 uefi-20261104 世代 | 该文件判据：旧 shim 拷贝长度 bug，「上机结论全伪」 | 已判死世代 | **已归档/删**（状态正确，无需动作；确认无镜像残留即可） |
| `backup/corrupt-20261103/boot-elden-m3v5-daily.img`（81 M） | 目录名 corrupt | 2026-11-02 静默损坏两件之一（zlib CRC 失败，sha 与 manifest 不符） | **删**（RESOURCES/README.md §3.5 已记「重建或删除后本条收口」） |
| `backup/rawdump.img`（257 M，未压缩） | §3.3 P2-b 状态 ⬜ | 可压缩归档的旧项 | **压缩归档**（维持原建议，等批） |
| `backup/fw/README.md` 固件命名注 | 「现有 rootfs 放的是 adsp.mbn.zst，命名不符」 | 描述的是 Alpine 期 rootfs 布局；Debian 根按 DT 路径放置（apt/固件 deb 已解决） | **改注**（范围外文件，本报告只登记：README 需加「Debian 侧见 out/debian/elden-firmware deb」一句） |
| `backup/stock-259/SHA256SUMS` 按仓库根相对路径写 | 行 1 `e7062378…  backup/stock-259/abl_a.img`，在目录内 `sha256sum -c` 13 件 FAILED open | 校验文件**只能在仓库根**跑，目录内跑全失败——不是数据损坏，是易踩坑写法 | **保留**，建议头注加一行「cd 仓库根执行」 |
| `versions/vk-ledger-known-issues.tsv` 行 357/361/365（vk164/vk168/vk174） | 引用 `LABEL=linux17` | 台账历史行，与现役 label 无冲突（是账不是指令） | **保留**（账目不改历史），但新台账行不得再写 linux17 |
| `backup/fw/tb322fc-edl` 与 `~/下载/tb322fc` 双入口 | §2.3「2026-11-03 收归项目，原路径留软链」 | 非过时，仅提醒双入口 | 保留 |
| `external/ext-repos` 中 UEFI 判死线（sunuefi/mu 等） | §1.6/§2.3 | G1-29 观察线未立项 | **保留**（202 M 总量小，观察资产） |

## 3. 缺口（按能力；「重建时缺什么 / 清单错什么」）

### 3.1 清单类硬缺口
- **`rootfs/debian/apt-list.txt` 行 84–85 `libssc2` / `libssc-bin` 在 Debian 13 trixie 不存在**（判据基线给实；pkgmap.tsv 行 163 的映射基于 sid 索引，头注索引 `arm64-sid` 也与现役 trixie 不一致）。⇒ 传感器链（SSC）重建时这两行会直接 apt 失败：需改为源码编译 libssc（上游 git + `81-libssc-elden.rules` udev 规则已在 packaging `MANIFEST.tsv` 留存）或换 trixie 索引重生成清单。
- **`apt-list.txt` 无 `udev` 行**（grep 0 命中）——Debian 里 udev 不是 systemd 的硬依赖物，须显式列；minbase 档 `apt-list-min.txt` 同样没有 udev/`dbus`/`openssh` 以外的桌面件属设计内，但**目标态清单必须含 udev**。
- **`apt-list.txt` 无 `phosh-osk-stub`**（grep 0 命中；有 squeekboard 行 119）——若走 phosh-osk-stub（设备无物理键盘的 OSK 现役选型）则缺；若坚持 squeekboard 需在 pkgmap 里注明为何。**不得为「最小」省 OSK**。
- `apt-list.txt` 头注索引 `/opt/elden/arm64-sid`（2026-11-07 生成）——套件应改 trixie 并重跑 `check-pkgmap.sh` 重生成，防包名漂移（libssc 即实证）。

### 3.2 按能力的资源缺口
| 能力 | 现有资源 | 缺口 |
|---|---|---|
| **显示** | vk192 boot 件 ✅、`reference/vendor-display-sm8750/`、armadaos 0154/0155 补丁线索（§1.8） | Q28 冷起 NOCARD 未闭（§1.8 明示本仓缺 0154/0155，需手动 apply 验证） |
| **网络（WiFi/BT）** | `backup/fw/modem/peach/amss.bin`+BDF、`vendor/etc/wifi`、ath12k 本地重试补丁（§1.2） | 缺「ath12k 命名转换后入 deb」的固化物：fw README 自注「命名待验证」；无 `firmware-ath12k` 打包件 |
| **音频** | dspso/adsp.mdt、aw882xx_acf→awinic 改名法（fw README §补充）、alsa-init 脚本 | tplg 链在 Debian 根的落位无清单条目（apt-list 无 pipewire 相关确认项外的 UCM 细目） |
| **传感器** | udev 规则 81-libssc-elden.rules ✅（packaging）、hexagonrpcd 在 apt-list 行 55 | **libssc2/libssc-bin 缺包**（§3.1）；`env-pass/scripts/sensor-send-termux.sh` 依赖的 UDP 假源链是新口径下的临时态，真源 = libssc 编译路线 |
| **触觉** | `scripts/elden-hapticd.c` + `awinic/y700-gen4-haptic.bin` 线索、packaging services | hapticd systemd unit 已可渲染 ✅；缺 ffrumble 的源（README 自认「当前 ffrumble 就是不可重建资产」） |
| **相机** | `dl-cam/` bionic HAL 件 + `external/lc-cross` libcamera 工作区 | dl-cam 产物是 **bionic/Android33 ELF**，只服务 Waydroid 容器；主线 Linux 侧相机（camss + libcamera deb 化）无打包件 |
| **Waydroid** | 镜像 zip、mesa 26.1.8 包、vendor 烘焙技能、haptic 固化链 | gap：`/mnt/Samsung/waydroid-build` 树已随盘清空 ⇒ vendor.img 再烘焙只能靠 `reference/waydroid-buildtree/` + 两个 USTC 仓重拉（550 G 重建代价已在 §2.3 注明） |
| **上游化** | `reference/gunyah-refs/`、`reference/upstream-*` 四套快照、patches/ | `external/ext-repos/mu*` 的 MIGRATION-LOST 件（mu_wide_platforms 1.0 G 等）仍未重取（§1.6 ⚠ 注） |

### 3.3 流程缺口（新口径下必须补的清单外事实）
- **Linux→fastboot 软路径不存在**（PITFALLS #690：长按电源 10s → 音量上+电源）——任何「reboot 到 bootloader」脚本/文档叙述都要按此改写；`rootfs/reboot2.c` 与 packaging 里 reboot2 引用属 Alpine 期件（§2 已计）。
- 现役根 label=linux：`boot_b-minbase-labellinux-*` 已对齐，但 `boot_b-vk192-linux17label-*` 与 `files/init` 的 linux17 残留是仅有的两处错标（§2）。

## 4. 抽样完整性结论
- sha 抽验 3 件全对：`out/boot-elden-vk192.img` = manifest ✅、`stock-259/boot_a|vbmeta_a` = SHA256SUMS ✅。
- 未发现数据级损坏新增；已损坏件（corrupt-20261103）已在 §3.5 台账登记。
- 「过时」主要形态不是坏文件，而是**叙事错位**：minbase 当终点、linux17 残留、Alpine 期采集件未降级为归档。

（本轮零改动、零设备命令；以上处置均为建议。）
■ 结束
