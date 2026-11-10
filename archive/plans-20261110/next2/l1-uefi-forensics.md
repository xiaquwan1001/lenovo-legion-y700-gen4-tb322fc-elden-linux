# L1：UEFI 实验取证（2026-11-04 fixcopylen 发，verdict=indeterminate）——只读主机侧调研

- 镜像：`out/uefi-20261104-fixcopylen.img`，sha256 `c0118018ccadec8a01af5a54437edf42af42893d7130988e46141c3d359ef624`（实测，见 A0）。

## A. 修拷贝长度是否生效（BootShim 反汇编核验）

**结论：生效。该发镜像内的 BootShim 就是 E0 修后版本（拷贝长度取构建期常量 + 清 cache 用「地址<上界」硬条件），非旧镜像。**

**A0. 镜像身份核验（不是旧货）**
- `sha256sum out/uefi-20261104-fixcopylen.img` → `c0118018ccadec8a01af5a54437edf42af42893d7130988e46141c3d359ef624`，与 trial JSON `reports/trials/20261104T024726Z-uefi-fixcopylen-r1.json` 的 `image_sha256` 及 `reports/artifacts/uefi-boot-20261104-fixcopylen/image.sha256` 逐字一致。
- `reports/artifacts/uefi-fixcopylen-20261104/SHA256SUMS`：`SM8750_EFI.fd e8d87fe5…`、`BootShim.bin 51a57a9e…`。
- `manifest.txt`：构建时间 `2026-11-04T09:59:37+08:00`、repo `7-mu-lenovo @ 6b6ac42a`、补丁列表首个就是 `patches/uefi/20261104-fixcopylen/0001-bootshim-copy-length-from-build-constants.patch`；`build.log` 末尾 `PROGRESS - Success`。

**A1. 反汇编（镜像内真实 shim，非仅 artifact）**

提取：out img 是 Android boot 镜像（头 8 B `ANDROID!`，`kernel_size=0x2533b1`），kernel 在 offset 0x1000 起、gzip 流；解出 0x4000c0 B 的 payload，其前 192 B 即 shim。命令：
`python3 -c "import zlib;d=zlib.decompressobj(31).decompress(open('out/uefi-20261104-fixcopylen.img','rb').read()[0x1000:0x1000+0x2533b1+4096]);open('/tmp/l1/kern_unpacked.bin','wb').write(d)"`
再 `aarch64-linux-gnu-objdump -D -b binary -m aarch64 --start-address=0x40 --stop-address=0xc0 kern_unpacked.bin`（等价地，artifact `reports/artifacts/uefi-fixcopylen-20261104/BootShim.bin` 反汇编逐指令一致，仅 repack 写的 header 字段不同，见 A3）。

镜像内 shim 关键指令（文件偏移 = 指令地址）：
```asm
0x40: 10000345  adr   x5, 0xa8          ; → _UefiBaseLit
0x44: f94000a5  ldr   x5, [x5]
0x48: eb05003f  cmp   x1, x5
0x4c: 54000260  b.eq  0x98 (_Entry)
0x50: 10000306  adr   x6, 0xb0          ; → _UefiSizeLit（构建期常量）
0x54: f94000c6  ldr   x6, [x6]          ; 长度 = 0x00400000，绝不读 offset16
0x58: a8c10c22  ldp   x2, x3, [x1], #16 ; _CopyLoop
0x5c: a8810ca2  stp   x2, x3, [x5], #16
0x60: f10040c6  subs  x6, x6, #0x10
0x64: 54ffffa1  b.ne  0x58
0x78: d50b7e27  dc    civac, x7         ; _CleanLoop
0x80: eb0800ff  cmp   x7, x8            ; x8 = UEFI_BASE+UEFI_SIZE
0x84: 54ffffa3  b.cc  0x78              ; 「地址 < 上界」硬条件（b.lo，非等值 b.ne）
0xa8: .quad 0xff300000   ; _UefiBaseLit  = UEFI_BASE
0xb0: .quad 0x00400000   ; _UefiSizeLit  = UEFI_SIZE
0xb8: .quad 0xff700000   ; _UefiEndLit   = BASE+SIZE
```
即：拷贝长度字面量 0x00400000（4 MiB，= FD 全长）、clean-to-PoC 循环为 `cmp x7,x8; b.cc` 有序比较。旧病根（`ldr x6,_StackSize` 即读被 repack 改写的 offset16 + `subs;b.ne`）已不复存在；全文也无「只拷 1 MiB」的 `0x300000` 等值比较（`rg -a 'cmp.*0x300000'` 无命中——且新代码根本没有这条指令）。

**A3. 与 artifact `BootShim.bin` 的唯一差异 = repack 写 header（符合设计）**
逐字节 diff 192 B：仅 offset 8..31 不同——镜像内 `text_offset(offset8)=0`（保持 0，补丁要求满足）、`image_size(offset16)=0x004000c0`（repack 改写成载荷真实长度，ABL 需要）、`flags(offset24)=0xA`。artifact 原始 shim 此处是 `UEFI_SIZE=0x400000 / 0xA`。代码区 0x40 起完全一致。**注意：ABL 跳转用 `load_address + text_offset`，text_offset=0 正确；shim 自己不读这两个字段，repack 改写无害。**

## B. 主机侧重建 64 块 FNV 块表期望值

**已生成：`.pi/plans/next2/l1-expected-blocktable.txt`**（8 行 × 8 值，第 n 行第 m 列 = 块 n*8+m）。
- 数据源 = `SM8750_EFI.fd`（sha256 `e8d87fe5…`，即镜像内被 shim 拷贝的那份 FD——已验：镜像 boot 头 `kernel_size=0x2533b1`，gzip 解出 0x4000c0 B，其 `[0xc0:0x4000c0]` 与该 FD 逐字节一致）。
- 算法 = FNV-1a 32：`h=0x811C9DC5; 每字节 h=(h^byte)*0x01000193 (mod 2^32)`，每 64 KiB 块一个值——与 `patches/uefi/20261104-dxe/0013-prepi-block-fnv-table.patch` 的 `SbBlocks()`（PrePi.c，`SB_FD_BASE 0xFF300000 / SB_FD_SIZE 0x00400000`，块 0–63 逐字节）完全对应；在机打印为 8 个一行 + `\n\r`。
- 关键期望值（节选）：块0 `12CF66A1`、块1 `29075668`、块31 `233E2320`；块36–63 全为 `1DC99DC5`（FD 尾部填充块的 FNV 恒等值，正常非异常）。
- 判读：在机表前 4 行（块0–31）若对而历史「块0–15 对、16 起全错」消失 ⇒ E0 修拷贝生效；若仍从某块起错，第一个错块序号即坏起点。

## C. 「反复刷屏、看不清」三候选判据表

| 候选 | 机理 | 一票定性证据 | 辅助判据 | 本发已有事实的支持度 |
|---|---|---|---|---|
| ① DXE Dispatcher 循环（UEFI 侧） | dispatch 进度点（`patches/uefi/20261104-dxe/0002-dispatcher-dispatch-progress-dots.patch`）每调度一个驱动打一点；UFS/依赖死循环时屏上**固定节奏刷点/重复同段文本**，且永远不进 BDS、不加载 Linux | 屏幕内容是**重复的 `[D..]`/点串**；或 USB 在进入 Linux 前就应出现 UEFI 串口字符（本发串口判据一帧未取得，无法排除） | 时间特征：`Booting OKAY 10.1 s` 后立刻开始刷屏（≤11 s，早于任何内核解压完成的典型时延） | **时间上很紧**：10.1 s 内刚进 PrePi→DXE，刷屏若紧随 handoff 则 ① 权重大 |
| ② Linux 侧 kernel panic | FD 跑完 → ABL → 我们日常内核起来后 panic（如磁盘/rootfs/驱动崩），panic 时内核打印**满屏滚动** | 屏幕上是**内核 log 格式**文本（时间戳 `[ x.xxxxxx]`、`Kernel panic - not syncing`）或 pstore 里留有 panic 记录 | `dmesg -T`/`journalctl -b -1` 是否有上次 boot 的 panic；`/sys/fs/pstore/*` 是否有 `dmesg-ramoops-*` | trial 里「fastboot reboot 后仍未回 Linux」+「反复刷屏」与 panic-loop（如 initramfs 起不来→reboot 循环）高度兼容 |
| ③ ABL 回落 stock | ABL 对该 payload 校验失败/启动失败后回落原厂链路 → 反复进原厂动画/recovery 循环 | 屏幕出现**联想原厂 logo/动画/eRecovery 界面**而非文本 | fastboot 里看当前 slot 与开机后 `getprop ro.boot.image.slot`；回落时通常行为=起 Android，USB 会重新枚举成 adb（本发 300 s 无枚举，**与 ③ 不符**） | **弱**：无 USB 枚举、无 adb，③ 可能性最低 |

**C2. pstore 前提核验（本仓内核树）**
**C2. pstore 前提核验（仓内 7.3-rc7 树，vk127 同源，硬证据已拿到）**
- 在机内核 = trial baseline `…-debug-vk127-00002-g24223e44ad80-dirty-debug-vk172` ⇒ 对应仓内树 `build/vk151`（`CONFIG_LOCALVERSION="-debug-vk127-00002-g24223e44ad80-dirty"`，build/vk151/.config:44；相邻 `build/m1-73/.config:44` 为 `-debug-vk127`）。
- `.config` 开了全套 pstore：`build/m1-73/.config:11032-11039` = `CONFIG_PSTORE=y / PSTORE_CONSOLE=y / PSTORE_PMSG=y / PSTORE_RAM=y`（`PSTORE_BLK` 未开，无需）。
- **在机 DT 已预留 ramoops 区域且实测可用**：`build/m1-73/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts:1469-1476` = `ramoops@c2000000 { reg=<0 0xc2000000 0 0x800000>; record-size=0x200000; console-size=0x200000; pmsg-size=0x400000; no-map; }`；紧邻注释（1465-1466 行）记录 2026-10-22 实测 `echo c > /proc/sysrq-trigger` 后 `/sys/fs/pstore` 留档。
- ⇒ **cmdline 无需 ramoops 参数**（DT 节点已足够，ramoops 驱动会从 reserved-memory 拿区域）；可见性判据：回到 Linux 后 `ls /sys/fs/pstore/` 应出现 `dmesg-ramoops-0` / `console-ramoops-0`；若为空先 `dmesg | grep -i -e ramoops -e pstore` 看驱动是否注册、`/proc/iomem | grep c2000000` 看保留区是否在。

判别流程（拿到任一屏帧即可分诊）：文本带 `\[.*\]` 内核时间戳 ⇒ ②；重复 UEFI 标记（`[D..]`/点串/FNV 块表重复打印）⇒ ①；图形化 logo/安卓界面 ⇒ ③。

## D. 下一发取证协议设计（≥2 方案 + 推荐）

背景约束：上一发唯一判读通道是屏上串口帧，而刷屏导致一帧未取到（trial JSON `judgement_channel`）；所以协议核心 = **让判据不依赖「单帧可读」**。

**方案 1：色带驻留 + 唯一色块图案（拍照可判读）**
- 内容：在 PrePi 关键里程碑（`[P10]` 前后、`DecompressFirstFv` 返回值）把整屏填成**纯色条带**（如：进 PrePi=绿、FD 拷贝完=蓝、LZMA 解压失败=红、进 DxeMain=白），每色停留 ≥3 s；且在屏角画**机器可判读的唯一像素图案**（如块表哈希低 16 位编码成 4×4 黑白格），一张照片即知是哪个构建、走到哪一步。
- 补丁点：`Platforms/AndromedaPkg/PrePi/PrePi.c` 已有 `SbMark/SbBlocks` 钩子（patches/uefi/20261104-dxe/0013、0014），在同一位置加 framebuffer 填色即可；fb 基址/分辨率可从 PrePi 现有的 display 初始化路径拿（镜像 cmdline 里已有 `console=ttyGS0…`，out img 头部 offset 0x40 可见）。
- 风险：fb 地址/ bpp 拿错 → 填错内存（可能踩 reserved 区）⇒ 只在已确认的 fb 上写；色带会盖掉文本日志 ⇒ 串口文本与色带**串行**（先打日志、后填色、停顿、再清屏），不要并行。
- 回滚：纯增量补丁，revert 单个 patch 文件即回退。
- 判读成本低：用户拍一张照，对比色卡即可定位失败阶段；唯一图案可判「是不是这发镜像」。

**方案 2：块表写到可回读位置（主机可验证，不需要人眼看屏）**
- 内容：PrePi 在 `SbBlocks()` 算完 64 块 FNV 后，把 64×4 B 的表**写到设备上一个掉电保留/主机可读的位置**，候选：① ramoops 保留区尾段（在机 DT 已留 `ramoops@c2000000`+8 MiB，UEFI 阶段 RAM 不清零，Linux 起来后经 pstore 读）；② 直接借 `pmsg-size=0x400000` 的 pmsg 区写一个带魔数的记录。再加一个**时间戳+构建 ID 魔数头**防串发。
- 补丁点：`SbBlocks()` 返回后新增 `SbPersistTable()`：往 `0xC2400000`（record 区内偏移）写 `"ELD1" + magic + 64×u32`。风险最低：只写已 reserved 的 no-map 区，不碰设备。
- 风险：若 UEFI 阶段后 XBL/ABL 重启路径清了这块 RAM（热重启通常不清；只有 cold reset 清）→ 读不到；缓解：镜像同地址双写 + 下发前先在已知可用内核上验一次「热重启后该地址残留」。
- 回滚：revert 单 patch。
- 判读：**完全无需拍照**；只要设备能回到 Linux（哪怕回落后才回），`/sys/fs/pstore/` 里就能看到 UEFI 写的块表，与 `l1-expected-blocktable.txt` 比对 ⇒ 直接回答 A/B 两问。

**方案 3（次选）：USB ACM 早期输出**
- 内容：PrePi/BootShim 阶段把现有 SerialPortWrite 同步打到 USB CDC-ACM（平台已有 DWC3，cmdline 已是 `console=ttyGS0,115200`）；主机侧 `timeout 600 script -c "picocom /dev/ttyACM0"` 全程录屏。
- 风险最高：UEFI 阶段需自己枚举 USB gadget（写 DWC3 寄存器，PITFALLS 已有「写错 UFS UIC 寄存器可致链路不可恢复」同类风险，TASKS/README.md:45）；且若刷屏根因正是 UEFI 侧，ACM 也同样循环。回滚同上。

**推荐：方案 2 为主、方案 1 为辅同一发携带**。理由：方案 2 把判据从「人眼拍照」变成「主机 diff 文件」，正好补上本轮 verdict=indeterminate 的缺口；色带只需在 `[P10]/[R]/[D00]` 三个点各一色，增量小。两者都只写 reserved/已初始化区域、都单 patch 可回滚，符合零写盘纪律。投递判据：块表 64/64 与 `l1-expected-blocktable.txt` 一致 + `[R]` 状态 = 0 ⇒ A/B 定案；色带停在红色 ⇒ LZMA 解压失败定位到块表错行。

## E. 设备回 Linux 后只读抓取清单

按顺序执行（全部只读，不写分区；`P=本地存档目录`）：

```bash
# 1. boot_b 未变核验（零写盘声明复核）：boot 分区不挂载、用块设备直读
#    找 boot_b 的分区号：lsblk -o NAME,SIZE,PARTLABEL /dev/sda
PART=$(lsblk -rno NAME,PARTLABEL /dev/sda | awk '$2=="boot_b"{print $1}')
sudo dd if=/dev/sda$PART bs=4M count=1 status=none | sha256sum   # 与 2026-11-04 之前的 boot_b 基线比对（若先前无基线，本命令即为建基线）
lsblk -rno NAME,PARTLABEL,PARTUUID,SIZE /dev/sda | grep -E 'boot|uefi|imagefv|abl'  # 确认 uefi_a/imagefv_a 未被动

# 2. 槽位属性（qbootctl，只读 status）
qbootctl ctl get-current-slot && qbootctl ctl get-target-boot-slot
qbootctl halt-reboot-status 2>/dev/null; qbootctl ctl get-suffix $(qbootctl ctl get-current-slot) 2>/dev/null
# 或走 misc 抽象层： qbootctl hal-info 2>/dev/null   # unbootable/retry-count/active 一并读
# （fallback: sudo hexdump -C /dev/disk/by-partlabel/misc | head -40，对照 boot_control 结构）

# 3. 上次启动残迹：journal + dmesg
journalctl -b -1 -n 200 --no-pager | tee P/journal-prev-boot.log   # 若 -b -1 即本次实验 boot 则命中
journalctl --list-boots | tail -5
dmesg | grep -i -E 'ramoops|pstore|extcon|dwc3|ufshc' | tee P/dmesg-hints.log
cat /proc/cmdline; uname -a; cat /proc/boot_id 2>/dev/null || cat /proc/sys/kernel/random/boot_id

# 4. pstore 清单与导出（优先！）
ls -la /sys/fs/pstore/ | tee P/pstore-list.log
sudo cp -a /sys/fs/pstore/* P/ 2>/dev/null    # 文件内容在 /sys/fs/pstore 下可直接 cat
dmesg | grep -i ramoops                        # 驱动注册信息（区域 c2000000+0x800000 应出现）
```

- 期待产物：`P/dmesg-ramoops-*`（上次 panic 的 dmesg ⇒ 直接判 C 表候选②）、`console-ramoops-0`（内核 console 尾部）、`pmsg-ramoops-0`；若 §D 方案 2 已上，`dmesg-ramoops` 同区域还应有 UEFI 块表魔数 `ELD1`。
- 对照点：baseline `boot_id` 上次 = `bf8d2fb1-558f-438c-97f4-b9629170ec58`（reports/artifacts/uefi-boot-20261104-fixcopylen/baseline.txt）；`journalctl --list-boots` 里找 11-04 10:47 后是否新增过 boot 记录——**有新 boot 记录 ⇒ 曾经起过 Linux（候选②强）**；完全没有 ⇒ 支持候选①/③。

## 未完成 / 卡点
- 均无硬卡点。C 表①的时间轴推断（10 s 内即刷屏）基于 `boot.txt` 单次计时，样本 n=1，仅作权重参考。
- §E 的 qbootctl 子命令名以设备上实际版本为准（`qbootctl --help` 先跑一遍），清单里已给 misc hexdump fallback。
- §D 方案 2 的「热重启后 c2000000 区域是否残留」未实测（需上机），已列为先决验证步骤。
