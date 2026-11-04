# UEFI 2026-11-04R-r1：判据换成 ramoops（主机可读，不依赖看屏）

> 目的：收口上一发（2026-11-04 `fixcopylen`）的 `verdict=indeterminate`——那发唯一判据是屏上串口，
> 而设备「反复刷屏」导致一帧没取到。本发把同一条轨迹**同时**写进 Linux 的 pstore，回到 Linux 就能 `cat`。

---

> ⚠ 本通道已于 2026-11-04 14:1x 被实机证伪（pstore 全空，carveout 被清），见 §5；今后以屏上判据为准，见 §6。

## 1. 判据通道（为什么是 ramoops）

内核侧早已具备（本轮只读核实，未改内核）：

| 项 | 事实 | 证据 |
|---|---|---|
| 内核 config | `CONFIG_PSTORE=y / PSTORE_CONSOLE=y / PSTORE_PMSG=y / PSTORE_RAM=y` | `build/m1-73/.config:11032-11039` |
| DT 保留区 | `ramoops@c2000000`，`reg=<0 0xc2000000 0 0x800000>`，`record-size=0x200000`、`console-size=0x200000`、`pmsg-size=0x400000`，`no-map` | `build/m1-73/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts:1469-1476` |
| 可用性 | 同区域 2026-10-22 已用 `sysrq-trigger` 实测过「崩 → 重启 → `/sys/fs/pstore` 有记录」 | DT 注释 :1465-1466 |
| ECC | DT 未写 `ecc-size` ⇒ `ecc_info.ecc_size=0`，`persistent_ram_update_ecc()` 直接返回 ⇒ **不需要算 ECC** | `build/m1-73/fs/pstore/ram_core.c:121-143` |

record 区数量 = `(0x800000 − 0x200000 console − 0x400000 pmsg) / 0x200000 = 2` ⇒ **两个独立记录槽**：

| 槽 | 物理地址 | 谁写 | 回到 Linux 后 |
|---|---|---|---|
| `dprzs[0]` | `0xC2000000` | PrePi（`[F01]/[P01]…[P11]`、64 块 FNV 表、`LoadDxeCoreFromFv` 返回码） | `/sys/fs/pstore/dmesg-ramoops-0` |
| `dprzs[1]` | `0xC2200000` | DxeCore（`[D00]…[D04]` … 各相位点） | `/sys/fs/pstore/dmesg-ramoops-1` |

写入格式**逐字节照内核**（`persistent_ram_buffer{sig,start,size}` + `"====<sec>.<usec>-D\n"` 头，
`ramoops_read_kmsg_hdr()` 靠这个头认记录）：见 `patches/uefi/20261104R-pstore/000{1,2}-*.patch`。
写完即 `dc civac` 清到 PoC（PrePi/DxeCore 各一份，不依赖任何库）。

## 2. 本次产物

| 项 | 值 |
|---|---|
| 镜像 | `out/uefi-20261104R-r1.img`，**sha256 `e7f8b5445c05bd3c0c7a0a7d444e262bde66d1bc4b1faee6714525cc57b85e73`**，67 198 976 B |
| 构建 | `reports/artifacts/uefi-20261104R-r1/`（`manifest.txt` 记 12 个补丁 + repo head `6b6ac42a`） |
| FD | `03f2e1c61f7da308…`（4 MiB） |
| BootShim | `51a57a9e224fe017…`（与 fixcopylen 同一件：拷贝长度取构建期常量） |
| 打包 | header **v2 base 0**、`text_offset=0`、`flags=0xa`、`image_size=0x4000c0`；`only-kernel-differs` 校验通过 |
| **期望块表** | `.pi/plans/next2/expected-blocktable-uefi-20261104R-r1.txt`（8×8，主机侧从本镜像内 FD 算） |

新插桩（相对 fixcopylen 只多两条）：
- `20261104R-pstore/0001`：PrePi 的 `SbMark()` 与 64 块表每行同时落 `dprzs[0]`；新增 `SbPersist()`。
- `20261104R-pstore/0002`：DxeCore 的 `SbMark()` 同时落 `dprzs[1]`。

**刻意不带 `0002-dispatcher-dispatch-progress-dots`**：那是每 dispatch 一个点，会让屏幕无限滚动（正是 11-04 一帧未取到的原因）。本发只保留有限条标记，屏幕最终停在最后一个相位点。

## 3. 上机流程（零写盘）与读回

```bash
# 1) 前置：设备在 fastboot（本轮实测 product=elden_prc_wifi、current-slot=b）
fastboot devices
# 2) 断言（任何旧 shim 件都会被拒）
python3 scripts/uefi-repack-v2aligned.py --build-dir reports/artifacts/uefi-20261104R-r1 -o /tmp/x.img   # 末尾 assert-ok
# 3) 单发零写盘
fastboot boot out/uefi-20261104R-r1.img
# 4) 观察 60–300 s；无论停在哪一步，都不要长按断电 —— 先试 `fastboot reboot`（同一次 ABL 会话）
#    若 fastboot 已无应答：物理断电（**注意：冷起会清 DDR，本发记录随即丢失**，只能靠屏上标记判读）
# 5) 回到 Linux 后读记录
ls -l /sys/fs/pstore/ ; cat /sys/fs/pstore/dmesg-ramoops-0 /sys/fs/pstore/dmesg-ramoops-1
```

判读（三态，全部主机侧可判）：

| 观察 | 结论 |
|---|---|
| `dmesg-ramoops-0` 有 8 行块表，与期望表 **64/64 一致** | 拷贝长度修复生效（搬运侧已无问题） |
| `dmesg-ramoops-0` 末行是 `[P11]` + `0x0`，且 `dmesg-ramoops-1` 有 `[D00]` 起 | **DxeCore 真进场**（历史从未达成）⇒ 卡点已到 DXE dispatch/UFS |
| `dmesg-ramoops-0` 有块表但 `[P11]` 非 0（如 `0x8000…0E`） | 仍停在 `LoadDxeCoreFromFv` 之前（FV 发现/解压链） |
| 两个文件都没有 / 只有旧的内核记录 | 记录没落进 DDR（地址错/被 DXE 分配器覆盖/冷起清空）⇒ 退回色带判读或换地址重试 |

## 4. 2026-11-04 14:13 首次上机（r1）——结果与修正

- **载荷真被执行**：`Sending 1.497 s` + `Booting OKAY 10.112 s`（与 fixcopylen 逐秒同型）。
- **屏上真相（用户目视）：`synchronous exception at 0x…0d2b9224` + `recursive exception while dumping the cpu state`**
  ⇒ 11-04「反复刷屏」不是 kernel panic、也不是 ABL 回落，而是 **EDK2 自己的异常处理器在 dump 期间再次异常 ⇒ 无限重印**。
- **ramoops 通道证伪**：`fastboot reboot` 后 22 s 回 Linux（`boot_id ea859761`），`/sys/fs/pstore/` **全空**——连「上一 boot 的内核 console 区」都没留下；
  在机 DT 实测 `ramoops@c2000000` 只有 **4 MiB**（`reg = 0xc2000000 0x400000`，与 `build/m1-73` 树的 8 MiB 不一致）；`/dev/mem` 读被 `CONFIG_STRICT_DEVMEM=y` 挡。
  ⇒ 该 carveout 在 `fastboot boot → UEFI → fastboot reboot` 路径上被清（冷复位 / ABL / PrePi 的 0xFF 填充三者之一，未区分），本通道不成立。
- 现场：`reports/artifacts/uefi-boot-20261104R-r1/`、trial `reports/trials/20261104T061344Z-uefi-20261104R-r1.json`。

## 5. 第二发（r2）——判据回到屏上，但把屏**变慢**

件：`out/uefi-20261104R2-r1.img`，sha256 `6a31f243cd0ef06d07b9393860b37d0b11f18177b1c9b4519bef2ee2a2f835b8`
（= r1 补丁集 **去掉 DxeCore 持久化** + `patches/uefi/20261104R2-slow-serial/0001`：`SerialPortWrite()` 每字符忙等 ~3 M 次，屏显慢到能录像）。

要取的证据：`[P01]`–`[P11]` 打到哪条、`[D00]`–`[D04]` 是否出现、异常首屏的 `Synchronous Exception at` / `ESR` / `FAR` / `ELR`。
判读：出现 `[D00]` ⇒ DxeCore 真进场（历史首次），卡点转 DXE dispatch；只到 `[P11]` ⇒ 仍在 PrePi；提前停在 `[P0x]` ⇒ 早期内存/解压链。

## 6. 风险与回滚（两发共用）

- **零写盘**：`fastboot boot` 不改任何分区；`boot_b` 仍是 `fb55997c…`（`DEVICE/README.md` §1.1 首条）。
- **DDR 清空风险**：若 UEFI 挂死需要物理断电，ramoops 记录随之丢失（这是本通道唯一硬限制）。缓解 = 屏上标记同时存在，且本发刻意不再无限滚动。
- **DXE allocator 覆盖风险**：UEFI 自己的内存图是否把 `0xC2000000` 当可用 RAM 未核实；记录在每条标记后重写，最新状态总在。
- **回退**：`fastboot reboot`；若两槽都不起，`fastboot --set-active=b` + `fastboot reboot`（PITFALLS #484）。

## 8. 2026-11-04 下午（r1→r8，八发零写盘）最终链条

| 发 | 件 | 关键变化 | 结果 |
|---|---|---|---|
| r1 | `out/uefi-20261104R-r1.img` | 判据写 ramoops（PrePi+DxeCore 两个 record zone） | 载荷执行；pstore 回读**全空** ⇒ 通道证伪（见 §4） |
| r2 | `…R2-r1` | 慢速屏显 3M spins/char + scale3 | 屏变成「缓慢滚动」，读到 `Synchronous Exception at 0xD2B9B224` + `Recursive exception` 无限重印 |
| r3 | `…R3-r1` | 慢速降到 40k spins/char | 未上机（被 r2 结论取代） |
| r4 | `…R4-r1` | 异常处理器补 ESR/FAR/SP | **无效**：运行时用的是设备 `Binaries/` 里**预编译 CpuDxe**，源码补丁不生效（PITFALLS #499） |
| r5 | `…R5-r1` | `[D00]` 后打 `&DxeMain`；异常改 no-scroll | **决定性证据**：`[D00]=0xD4CA7D90`、`[D01]…[D07]` 全出、64 块表与主机期望一致 ⇒ **DxeCore 真进场** |
| r6 | `…R6-r1` | 尝试异常处理器打镜像名 | 未上机（同 #499 问题，放弃该路线） |
| r7 | `…R7-r1` | `[I] base/size`（RELEASE 可见）+ `ConOut` 换 no-op | 屏给出约 90 条装载表；崩溃前最后 `[E] start` = `QRKSDxe` |
| r8 | `…R8-r1` | `[I]` 加模块名、`CoreStartImage` 前打 `[E]` | 完整 load map（QCOM 驱动逐个 init）→ `RmVmDxe`(Gunyah) 报 `Merge Overlay: -3 / Gunyah Interface init error: Load Error / Skipping RmVmProtocol Install` → `QRKSDxe` 启动瞬间 `Synchronous Exception at 0xD2B9B224` |

**本日结论（UEFI 线）**：
1. 「DxeCore 从未启动」**已被推翻**（那是只拷 1 MiB 的伪结论）；`fixcopylen` 的 4 MiB 拷贝链收口。
2. DXE dispatch 已经在跑真实 QCOM 驱动（SCM/PMIC/Clock/PIL/UFS/Display/USB/I2C…），缺件集中在 `CPU_Vectors region`、`SCM mailbox 14`、`SE_Fuse`。
3. 崩溃点 `0xD2B9B224` 三次实验逐字节相同，且**不落在任何已装载镜像区间** ⇒ 不是某驱动代码内的正常指令，而是被跳进的野地址（坏函数指针 / `0xFF` 填充区）；最后被启动的是 `QRKSDxe`，其前 `RmVmDxe` 初始化失败是最大嫌疑（协议没装上，调用方拿到空/脏指针）。
4. 下一发（未做，设备已回 Linux）：`--rmvmdxe vendor` 或直接剔除 `RmVmDxe`/`QRKSDxe` 看崩溃是否移位；若移位即定位到 Gunyah 依赖链。**判据仍是屏停住 + 最后一条 `[E]`。**

## 9. 2026-11-04 晚：**R10 突破 —— UEFI 首次跑到底、无异常**

- 变体 = r8 全量插桩 **+ 剔除 `QRKSDxe`**（`DXE.inc` 注释；`FVMAIN.Fv` 里 `QRKSDxe` 计数 2→0）。
- 结果：`[D00]..[D08]` 全出、约 **150 条** `[I]/[E]` 配对（QCOM 平台驱动 + EDK2 通用驱动全部 dispatch），
  `usb_repeater_reset → ssusb_phy_init_success lane:0x0`（UEFI 侧 USB PHY 起来），
  **全程无 `Synchronous Exception`**；末端 `GetLibProductString: Product string is NULL ×3` 之后进入图形界面
  （白箭头 + 扳手/螺丝刀 + 二维码 = Android recovery 类 UI）。
- **`0xD2B9B224` 的归属定案**：`QRKSDxe`。它的字符串里只有 `gQcomScmProtocolGuid - Fail %d` /
  `ScmGetClientEnv - Fail %d` / `IQRKS_CheckLicenseKP`，而 `MailboxDxe` 已报 `Failed to locate SCM protocol for
  Mailbox 14` ⇒ SCM 客户端环境失败后调用了脏/空指针，`ELR` 落在任何已装载区间之外（野地址）。
- **注意**：`GetLibProductString` 在本仓源码与 `Binaries/` 里**都搜不到** ⇒ 屏幕末段的那个 UI 来自**原厂固件**（我们的 payload 在 BDS 之后复位/回落）。也就是说：**UEFI 跑完了，但没交出 Linux**。
- 遗留缺件（按对「能不能引导 Linux」的相关度排序）：
  1. `UFSDxe` 启动后立刻 `Error getting gEfiKernelProtocolGuid handle, Status: 0xE` —— 该协议由 **`Platforms/QcomModulePkg`**（`Include/Protocol/EFIKernelInterface.h`）提供，而本 Mu 构建**不含 QcomModulePkg**；
  2. `CPU_Vectors region not present in cfg file`、`SCM protocol for Mailbox 14`、`QUSS clock node`、`i2c:12`；
  3. `RmVmDxe`(Gunyah) 仍失败但不致命。

## 10. 下一发（R11，已构建待上机）

`out/uefi-20261104R11-r1.img`（sha `db7c1b35…`）= R10 + `patches/uefi/20261104R11-bdsprobe`：
在 **BdsDxe 入口**打印 `[B] BlockIo=<n>` 与 `[B] SimpleFileSystem=<n>`（RELEASE 下 DEBUG 全空，这是唯一能在屏上回答「UFS/分区枚举出来没有」的办法）。
判读：`BlockIo ≥ 1` ⇒ UFS 枚举成功，下一发直接上「从 UFS 引导 Linux」；`BlockIo = 0` ⇒ 存储栈仍是真卡点，转去补 `gEfiKernelProtocolGuid` 提供者（QcomModulePkg/UFSDxe 依赖）。

## 11. R11/R12 结果：**UFS 枚举成功，但整机没有 ESP**

R11（`out/uefi-20261104R11-r1.img`，sha `db7c1b35…`）屏上：

```
[I] BlockIo: 119
[I] SimpleFileSystem: 1
```

R12（`out/uefi-20261104R12-r1.img`，sha `8db0aecd…`）把那个唯一的 FAT 卷打印出来：

```
[S] VenHw(D3F1985-F107-4AB5-DE39-68DCA7AD32CEA)/HD(39,GPT,347B1061-E3EC-30E1-D8BB-C89066CA82A,0x34180,0x15E00)
```

**解码**：`HD(39, … start=0x34180, size=0x15E00)`（4096 B 扇区）对照 `reports/artifacts/uefi-ddrcut-20261101/lun4-gpt-primary.bin`：

| 分区 | 名字 | 起始 LBA | 大小 |
|---|---|---|---|
| **part 39** | **`modem_b`** | `0x34180` | 89 599 扇区（≈350 MB） |

⇒ 唯一的 SimpleFileSystem 是 **LUN4 上的 `modem_b`**（Qualcomm modem 分区是 FAT，里面装 `image/*.mbn`），
**不是 ESP，也绝不能拿来当 ESP**（刷坏 = 射频/基带全废）。

**结论：整机不存在 ESP/FAT 启动分区** ⇒ Mu BDS 枚举完 UFS 后没有可交接的目标 ⇒ 复位 ⇒ ABL 起原厂 recovery（`dsu.metro/recovery` 二维码页，该字符串在本仓与 `Binaries/` 里 0 命中，确认来自原厂固件）。
`gEfiKernelProtocolGuid 0xE`（`QcomModulePkg` 才提供）与 `CPU_Vectors region not present` 都不阻断枚举，只影响「原厂那套 kernel 交接」。

### 三条可行路线（按「零写盘优先」排序）

| 路线 | 做法 | 写盘 | 风险/代价 |
|---|---|---|---|
| **A（推荐，零写盘）** | 把 **standalone GRUB arm64**（内嵌 `grub.cfg` + `ext2/fat/linux` 模块）或自写最小 loader 打进我们的 FD，由 BDS `LoadImage` 直接启动；GRUB 用 `ext2` 模块读 **`linux17`（ext4）** 的 `/boot/vmlinuz*` + `dtb` + `initrd`，`root=LABEL=linux17` 交接 | 无 | 需要解决「FV 内 app 的 device path / 启动方式」（可复用 BdsDxe 插桩：BDS 入口直接 `LoadImage` 一个 FV 内文件或内存镜像） |
| B | GPT 手术新增 200–500 MB FAT ESP（写盘），GRUB 装进去，BDS 自动发现 | 有（可回退） | 需要备份 + 回退脚本；`linux17` 已有数据不宜缩 |
| C | 复用现有分区做 ESP | 有 | `modem_b` 绝对不行；`recovery_b`(100 MB) 会破坏原厂恢复；`toolsfv`(1 MB)/`logfs`(8 MB) 太小 |
