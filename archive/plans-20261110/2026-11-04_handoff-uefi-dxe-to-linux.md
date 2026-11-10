# HANDOFF · 2026-11-04 收尾 —— UEFI 线：从「DxeCore 从未启动」到「DXE 全走完、只等一个 loader」

> 给**下一轮会话**的唯一入口文档。上一轮的规划在 `.pi/plans/2026-11-04_131500-新一轮待办规划.md`，
> 权威状态在 `TASKS/README.md` §5 的 2026-11-04 傍晚块，证据正文在 `reports/uefi-ramoops-channel-20261104R.md`。
> 本文只写「现在在哪、下一步做什么、怎么复现、别踩什么」。

---

## 0. 一句话状态

**UEFI 这条线已经跑通到 BDS 之后**：`DxeCore` 真启动、约 150 个 DXE 驱动全部 dispatch、**UFS 枚举成功（`BlockIo=119`）**、全程零异常；
唯一的缺口是**整机没有 ESP/FAT 启动分区**，BDS 没有可交接的目标 → 复位 → 落回原厂 recovery（二维码页）。
⇒ 下一轮只做一件事：**给 BDS 一个能从 `linux17`(ext4) 加载 Linux 的 loader**（首选零写盘方案 A）。

设备当前状态：**在 fastboot（`HA2EXB0E`，`18d1:d00d`）**，`boot_b` 全程未写（`fb55997c…`）。

---

## 1. 这一天被推翻/确立的关键结论

| # | 结论 | 证据 |
|---|---|---|
| 1 | **「DxeCore 从未启动」是伪结论**（11-04 早间那 11 发只拷 1 MiB 导致 FD 尾部是垃圾） | 屏上 `[D00]`+`&DxeMain`、`[D01]…[D08]`；`report §8` |
| 2 | `fixcopylen`（拷贝长度取构建期常量）**生效**：64 块 FNV 表 64/64 与主机期望一致 | 块 1–37 逐值相同、38–63 恒 `1DC99DC5`；`.pi/plans/next2/expected-blocktable-uefi-20261104R-r1.txt` |
| 3 | `0xD2B9B224` 同步异常 = **`QRKSDxe`**：它依赖 `gQcomScmProtocolGuid`/`ScmGetClientEnv`，SCM 客户端环境失败后调脏指针；ELR 不落在任何已装载区间 | r8 vs r10 单变量对照（剔除 QRKSDxe 后异常消失） |
| 4 | **UFS 枚举成功**：`BlockIo=119` | r11 |
| 5 | 唯一的 `SimpleFileSystem` = **LUN4 `modem_b`**（FAT，装 modem 镜像），**不是 ESP、绝不能写** | r12 设备路径 `HD(39,GPT,…,0x34180,0x15E00)` + `lun4-gpt-primary.bin` part39=`modem_b` |
| 6 | 屏末二维码页（`dsu.metro/recovery`）来自**原厂固件**，不是我们画的 | `GetLibProductString` 在本仓源码/`Binaries/`/构建产物里 ASCII+UTF-16 全 0 命中 |
| 7 | ramoops/pstore 通道**不可用**（在机 DT 只有 4 MiB，整区被清，`/dev/mem` 被 STRICT_DEVMEM 挡） | `PITFALLS #500` |
| 8 | 设备 `Binaries/` 里的**预编译 `ArmCpuDxe.efi`** 让异常处理器源码补丁无效（`--clean` 也不重建） | `PITFALLS #499` |

---

## 2. 本日 12 发上机（全部零写盘）清单

| 件 | sha256（前 8） | 用途 | 结果 |
|---|---|---|---|
| `out/uefi-20261104R-r1.img` | `e7f8b544` | ramoops 持久化判据 | 通道证伪（pstore 全空） |
| `out/uefi-20261104R2-r1/r2.img` | `6a31f243` / `23b48a83` | 慢速屏显（3M spins/char，scale3） | 读到 `0xD2B9B224` + Recursive 循环 |
| `out/uefi-20261104R3-r1.img` | `cdea96ef` | 慢速降到 40k | 未上机 |
| `out/uefi-20261104R4-r1.img` | `a9efd603` | 异常处理器打 ESR/FAR | 无效（预编译 CpuDxe，见 #8） |
| `out/uefi-20261104R5-r1.img` | `fe0f0c8f` | `[D00]` 后打 `&DxeMain` | **确诊 DxeCore 真进场** |
| `out/uefi-20261104R6-r1.img` | `85879134` | 异常处理器打镜像名 | 未上机（同 #8 放弃） |
| `out/uefi-20261104R7-r1.img` | `331fb365` | `[I] base/size` + ConOut no-op | 约 90 条装载表 |
| `out/uefi-20261104R8-r1.img` | `4c0a2c19` | `[I]` 带模块名 + `[E] start` | 定位到最后启动的驱动 |
| `out/uefi-20261104R9-r1.img` | `28658a3c` | `--rmvmdxe vendor` 对照 | 崩溃未移 ⇒ Gunyah 非根因 |
| **`out/uefi-20261104R10-r1.img`** | `23dab1f4` | **剔除 QRKSDxe** | **突破：DXE 全走完、零异常** |
| **`out/uefi-20261104R11-r1.img`** | `db7c1b35` | BDS 打 `BlockIo`/`SFS` 句柄数 | **BlockIo=119，SFS=1** |
| **`out/uefi-20261104R12-r1.img`** | `8db0aecd` | 打 SFS 的 device path | **SFS = modem_b** |

构建产物（manifest+sha+FD）在 `reports/artifacts/uefi-20261104R{1,2,3,4,5,6,7,8,9,10,11,12}-r1/`，上机现场在 `reports/artifacts/uefi-boot-20261104R*-r1/`，trial JSON 在 `reports/trials/20261104T*.json`。

---

## 3. 下一轮第一步（建议直接照着做）

### 目标
让 BDS 交出 Linux：从 `linux17`（ext4，LABEL=linux17）加载 `/boot/vmlinuz*` + DTB + initrd，`root=LABEL=linux17`。

### 方案 A（首选，**零写盘**）
把 loader 打进我们自己的 FD，由 BDS 直接 `LoadImage` 启动。

1. **拿 arm64 GRUB**（standalone）：
   - 本机 `grub-mkstandalone`/`grub-mkimage` 有，但 **`/usr/lib/grub/arm64-efi` 不存在**（`grub-efi-arm64-bin` 未装）。
   - 装包：`sudo apt install grub-efi-arm64-bin`（需要网络/代理，见全局 AGENTS 的代理注意）；
     或 `grub-mkstandalone --format=arm64-efi --modules="ext2 part_gpt linux normal search" --output=grubaa64.efi "boot/grub/grub.cfg=grub.cfg"`。
   - `grub.cfg` 只需：
     ```
     set timeout=0
     menuentry "elden mainline" {
       search --label --set=root linux17
       linux /boot/vmlinuz root=LABEL=linux17 rw console=tty0
       devicetree /boot/<dtb>
       initrd /boot/<initrd>
     }
     ```
     （实际内核文件名/DTB 名以设备 `/boot` 为准，`ls /boot` 现查）
2. **让它被启动**（两条可选，任选其一）：
   - ① 复用已有插桩：`patches/uefi/20261104R11-bdsprobe` 已经把 BdsDxe 改过，可在 BDS 入口改成「把 FD 内嵌的 grub 镜像 LoadImage + StartImage」；
   - ② 更省事：`MdeModulePkg/Universal/BdsDxe` 里用 `EfiBootManagerBoot` 加载一个**内存镜像**（`LoadImage(TRUE, …, NULL, grub_buf, grub_size, &h)`），device path 传 `NULL` 即可（BootPolicy=TRUE 时 EDK2 允许无路径的内存镜像）。
   - 落点：`scripts/uefi-build-variant.sh --patch patches/uefi/20261104R13-loadergrub/0001-*.patch`。
3. 构建后仍走既有断言：`scripts/uefi-repack-v2aligned.py` 末尾 `verify_built_image()` 会校验 shim 字面量（旧件一律拒）。
4. **判据**：屏上出现 Linux 内核日志/桌面；若 GRUB 读不了 ext4，退 B。

### 方案 B（退路，写盘）
GPT 手术新增 200–500 MB FAT ESP（`linux17` 有数据不宜缩），GRUB 装进去，BDS 自动发现。
必须先备份 GPT（`scripts/slot-attr.py`/既有 dump 流程），并准备回退。

### 明确不要做
- **不要**把 `modem_b` 当 ESP（350 MB FAT，装 modem 镜像，写坏=基带废）。
- **不要**再用 `QRKSDxe` 进 FV（除非先修 SCM 客户端环境）。
- **不要**再指望 ramoops/DDR 标记做取证通道（都已被证伪）。

---

## 4. 复现「一次上机」的标准动作（已验证 12 次）

```bash
# 0) 设备在 Linux 时进 fastboot（12–22 s）
ssh root@192.168.7.1 'reboot bootloader'
fastboot devices                      # 期望 HA2EXB0E  fastboot

# 1) 发件（零写盘；先看断言）
cd /home/xuqianhui/y700-elden
fastboot boot out/uefi-20261104R12-r1.img    # 换成目标件

# 2) 采集：屏上慢速滚动（每字符 ~33 ms，scale=3），末尾拍 10–20 行
#    判据行： [Pxx] / [Dxx] / [I] name base size / [E] start / [B] BlockIo / [S] path

# 3) 回收
fastboot reboot          # 若 fastboot 已无应答 ⇒ 长按电源断电重启
#    回 Linux 后确认：boot_id、boot_b sha 未变（DEVICE/README.md §1.1）
```

构建模板（补丁顺序有依赖，务必按此顺序）：

```bash
scripts/uefi-build-variant.sh reports/artifacts/<新名> --scale 3 \
  --patch patches/uefi/20261104-fixcopylen/0001-*.patch \
  --patch patches/uefi/20261104-prepi/0001-*.patch \
  --patch patches/uefi/20261104-dxe/{0004,0010,0013,0003,0005,0006,0007,0001}*.patch \
  --patch patches/uefi/20261104R5-dxebase/0001-*.patch \
  --patch patches/uefi/20261104R7-loadmap/0001-*.patch \
  --patch patches/uefi/20261104R8-names/0001-*.patch \
  --patch patches/uefi/20261104R10-noqrks/0001-*.patch \
  --patch patches/uefi/20261104R2-slow-serial/0001-*.patch
python3 scripts/uefi-repack-v2aligned.py --build-dir reports/artifacts/<新名> -o out/<新名>.img
```

---

## 5. 这一轮新踩的坑（下轮开工前扫一眼）

全部在 `PITFALLS/sessions/162-UEFI进DXE之后的取证纪律.md`（#498–#502），要点：

1. **屏满后任何带 `\n` 的屏上打印都会二次异常** ⇒ `Recursive exception` 无限重印；异常报告只用 `\r`，或把 `gST->ConOut->OutputString` 换 no-op。
2. **设备 `Binaries/` 里的预编译 `ArmCpuDxe.efi`** 让异常处理器源码补丁对运行时无效 —— 改完必查 `grep -c "<新串>" Build/.../AARCH64/ArmCpuDxe.efi`。
3. **ramoops 不能跨 `fastboot boot` 取证**（在机 DT 4 MiB、整区被清、`/dev/mem` 被挡）。
4. `uefi-build-variant.sh --patch` 必须**绝对路径**；在已应用补丁 A 之上生成补丁 B，要 `git apply A && git add -A` 再编辑再 `git diff`。
5. **进 DXE 之后只留标记不够**：要留「带名字的 load map + 每次 `CoreStartImage` 前的 `[E]`」；ELR 不落在任何已装载区间时不要归因到驱动代码（野地址）。
6. 本轮另记：`BdsDxe`/`Image.c`/`Dispatcher.c` 里用 `AsciiSPrint`/`SerialPortWrite`/`ConvertDevicePathToText` 都必须**自己加 `#include`**；本树 `EFI_FILE_INFO` **没有 `VolumeLabel` 字段**。

---

## 6. 未动的旁支（下轮可并行，非阻塞）

- **邮件**：sashiko 已回 2 High + 8 Medium（dwc3 3/3 两条 High 优先），v7 材料待做；`read-mail-ustc.py` 的 `OUR_IDS` 写死、`--folders` 引号、patchwork 归档复核口径三处待修（见 `.pi/plans/next2/l4-mail-truth.md`）。
- **文档**：`TASKS/README.md` 巨型行下沉（184 KB → 目标 ≤60 KB）未开始。
- **SunUEFI 自研 UFS 栈移植**（`.pi/plans/next2/l2-uefi-xiaomi-assets.md` §B.5）—— 现在我们自己的 UFSDxe 已能枚举，**优先级下调**。
- **原厂恢复链路**：我们不改 `boot_b`，随时可 `fastboot reboot` 回 Linux；`modem_b`/`recovery_b` 一律不动。
