# 上机手册（RUNBOOK-BRINGUP）— 任一单元从原厂状态到 mainline 持久直启

> 领域层活文档之一；文档分三层（领域 / 元 / 证据），定义与 SSOT 见 `INDEX.md` §2。
> **适用 = 任一 TB322FC / elden / SM8750(P) 单元**（台账 `DEVICE.md` §2.2）。它们**物理等价**，
> 唯一差异 = 容量 → GPT 数值；所有容量相关值**运行时读实际 GPT**。
> （文件历史：原 `BRINGUP-NEW-TABLET-2026-10-02.md`；“新机接力/旧机留 Android”的角色划分已作废。）
>
> 目标：把一个单元做到 **b 槽直启 mainline + 持久根**（G1 地基）。
> **默认策略（v3）**：Phase 0–3 **不动 a 槽**（零风险拿数据）；a 槽与 Android 专属分区**可事后回收**给 Linux
> （Phase B，见 §9）——用户已定 “**a 槽 Android 可以不要**”，回退靠 `backup/stock-259/` + EDL 全量包而不是槽位常驻。

---

## 0.0 开工前必填的单元参数（全文唯一随设备变化的部分）

| 变量 | 含义 | 怎么取 | 已知值 |
|---|---|---|---|
| `SN` | 序列号 | `fastboot getvar serialno` | U1=`HA2ABH62`；U2=`HA2EXB0E` |
| `CAP` | 容量档 | `adb shell getprop ro.boot.hwboardid` | U1=`12+256`；U2=`16+512`（实测 `SM8750P_16+512_13`） |
| BL 锁 | 解锁状态 | `adb shell getprop ro.boot.flash.locked` | U1=0、**U2=0**（两台均已 unlocked）→ **§0.5 对 U1/U2 均跳过** |
| `BLK` | LUN0 设备 | 主线内 `ls /dev/sd*` | 通常 `/dev/sda` |
| `SECTOR` | 扇区 | `blockdev --getss $BLK` | 4096 |
| `BACKUP_LBA` | 备份表起始 LBA | `scripts/gpt-dump.sh` 打印 | U1=`61390847`；**其他单元必须现 dump** |
| `LINUX_GIB` | Linux 分区大小 | **不预设固定值**：按 `DEVICE.md` §3 体量估算表定，**一次给足** | 512G 档建议 160–200；256G 档 64–96 |
| `BAK` | 备份目录 | 命名规范 | `backup/${SN}-${CAP}/`（**勿再叫 `new-tablet`**） |

```bash
export SN=<序列号> CAP=16+512 BLK=/dev/sda LINUX_GIB=<按 DEVICE.md §3.2 一次给足，勿预设>
export BAK="backup/${SN}-${CAP}"; mkdir -p "$BAK"
```
> 下文 `backup/new-tablet/` 一律读作 `$BAK`（保留原文仅为历史兼容）。

---

## 0. 主机侧资产（设备无关，对任一单元都成立）

| 资产 | 路径 | 说明 |
|---|---|---|
| **RAM 版内核**（首次 bring-up / 手术用） | `out/boot-elden-vk40-ram.img` | 纯 RAM 根，不依赖磁盘分区 |
| **持久版内核**（手术后用） | `out/boot-elden-vk40.img` | `elden_root=LABEL=linux17` |
| **b 槽直启包** | `bootslot-b/{boot_b_vk40-ram.img, boot_b_vk40.img, dtbo_b.img, vbmeta_b_flags3.img}` | 自签 AVB，`avb.key` 仅主机 |
| **全模块包** | `out/modules-7.2.0-debug-gba28ec16f01f-dirty.tar.gz` | strip 后 20M，1484 个 `.ko` |
| **相机模块包** | `out/camera-modules-*.tar.gz` | 20 个（外科部署用） |
| **持久 rootfs 归档** | `env-pass/backup-20261002/linux17-rootfs-20261002.tar.gz` | 3.44 GB / 30852 项 |
| **Waydroid Mesa** | `~/mesa-out/mesa-vendor-26.1.8_waydroid_arm64_only.tar.gz` | 已校验 |
| **EDL 救砖** | `qdl/build/qdl` + `~/下载/tb322fc/xbl_s_devprg_ns.melf` | 仅备用 |

> ⛔ **不得沿用任何其他单元的 GPT 二进制**（`backup/gpt/gpt_*_device.bin` 是 234 GiB 档的）——
> 容量不同而写旧表 = bootloop/不可启动（已有先例记录）。**每单元现 dump、现生成。**

---

## 0.5 Phase −1 — BL 解锁（**仅未解锁单元**，先于 Phase 0）

### ★ 权威顺序（2026-10-03 定稿；先读这段，下面的 A/A3/B/D 均为备选/历史）

**解锁不是目标，是 fastboot 迭代便利**：写分区/写 GPT/自签 boot 走 EDL（`qdl`）**不需要解锁**；
只有 `fastboot fetch` / `fastboot boot`（零写盘 RAM 验收）/ 切槽 / 高频迭代 boot_b 才需要解锁。
→ 所以：**任务只是采集/dump 的单元，保持 locked，不要为了「解锁」去折腾。**

**四代（TB322FC）解锁 = 一个版本门问题，没有第二条路。** 逐条按此走，别从签名文件开始猜：
（同一路已在**两台单元各自实测成功**：U1 `HA2ABH62` 2026-08-16、U2 `HA2EXB0E` 2026-10-03）

> **当前状态（勿再走 §0.5）**：U1、U2 均已解锁（`flash.locked=0`，实机核验 2026-10-03）。本节仅对**新到货的 locked 单元**适用。

```
0) 判版本门   adb shell getprop ro.build.display.id
     ≤ 1.1.11.073 / .076   → 解锁命令存在 → 跳到 3
     1.1.11.120            → ⛔ TRAP（显示成功但回滚）→ 先降级
     1.5.x（229/259/C16）   → 通道被堵 → 先降级           ← U2 本次即此路
1) 拍 locked 基线   scripts/bl-preunlock-evidence.sh <SN>   ← 擦机前唯一机会（Widevine L1 等）
2) 全量降级 1.1.11.073（用户操作 LTBox Simple Flasher，或 qdl 全 LUN）
     ★ 必须含 GPT（只写内容 = 版本布局错配→卡 logo）；只用 lolinet/官方包（4PDA 改包改 SN/bootload_sn，变砖）
     ★ Gen4 无 rollback-index 保护 ⇒ 降级安全；包在 ~/文档/TB322FU_ZUXOS_1.1.11.073/image/
3) 保持 fastboot、**中间不重启**：fastboot flash unlock sn_<64hex>.img（073 上可省）→ fastboot oem unlock
     → 屏出菜单 = 判定通过 → 音量下×2 + 电源确认（★ 擦 /data，不可逆）
4) fastboot flashing unlock_critical（又出一次菜单；`flashing unlock` 此 ABL 不认）
5) 校验 + 回填：getvar unlocked=yes / oem device-info 两个 true；flash.locked=0、verifiedbootstate=orange；
               重测 Widevine 回填 GAPS Q1/Q5
停手条件（任一即停，**不重复刷**）：Download is not allowed on locked devices / Unlock command not allowed /
   `oem unlock-go` 报 OKAY 但 getvar unlocked 仍 no（= 中了 .120 类 trap）
```

⇒ **已判死、不必再试**：四代 **1.5.x** 上的**任何** sn.img（官网申请 / 三代免签模板 / 第三方签名服务）——四代 ABL 换了内嵌 key 且不发公钥。
⇒ **动手前先 grep 本地既有结论**（本机型答案早在 2026-08 的记录里；流程教训 `PITFALLS` #87、复盘 `archive/topics/复盘-2026-10-03-BL解锁.md`）。

<details><summary>以下为历史备选路（A / A3 / B / D）与官方申请细节，保留作参考；已不走</summary>

> 判据：`adb shell getprop ro.boot.flash.locked` = `1`（或 `ro.boot.vbmeta.device_state=locked`、`verifiedbootstate=green`）→ 未解锁。
> **为什么要动它**：G1 要 `fastboot boot|flash boot_b|dtbo_b`；走官方途径时锁定态一律拒绝。
> **但「必须先解锁」并不成立** —— 取证见 `archive/topics/UNLOCK-BLOB-FORENSICS-2026-10-03.md`：
> ① 原厂 259 的 **AVB 主链就是谷歌公开的 AOSP testkey**（`avbtool info_image` → pubkey sha1 `2597c218…`）
>    ⇒ 自签 `boot`/`vbmeta` 本就被 ABL 认可；② `qdl` 走 EDL 写分区**不看 lock 位** ⇒ **G1 可以不等解锁**（路 C）。
> 解锁标志链用的是 **Lenovo 自签证书**（serial `804940DE79164B1A`，**不是**谷歌 key），但三代实物证明
> **SN 明文在偏移 `0x2048`、不在签名覆盖范围内 → 改 8 字节即可自造解锁文件**，无需申请（路 A）。

| 路 | 做法 | 依据 / 风险 | 优先级 |
|---|---|---|---|
| **A 自造解锁 blob** | 模板改字段：**A1** `0x2048` 写 `ro.serialno`（三代工具箱原法）· **A2** 改 `Bootloader_SN Part1+Part2`（= 本机 `ro.boot.bootload_sn` 两段 32 hex；本技能早前记录法，见 `PITFALLS` #83） | 零成本、失败不改设备状态；**四代 1.5.x 已实测无效**（ABL 换 key + 高固件不开放解锁命令） | ⛔ **已判死**（仅对 ≤1.1.11.073 或三代机有意义） |
| **A3 第三方签名 blob** | `backup/HA2EXB0E-16+512/sn-neko-zuxos.img`（356 B，`lenovobl.neko.ink` 选 **ZUX OS** + 本机 64 位 `Bootloader_SN`）→ `flash unlock` → `oem unlock` | 结构自洽、SN 绑定正确，但 **2026-10-03 实测 `oem unlock` 在 259 上被拒**（离线 18 组合验签全败 ⇒ 四代 ABL 换 key）。取证 §5 | ⛔ **已判死**（不再买/不再求） |
| **B 官网 `sn.img`** | 见 ② | 要账号/大陆邮箱/审核；1 号·年 3 台；**与 A3 同一道门 ⇒ 1.5.x 上同样无用** | ⚪ 仅旧固件（≤.073/.076）才值得申请 |
| **C 不解锁，走 EDL** | `qdl/build/qdl` + `xbl_s_devprg_ns.melf`（`fastboot oem edl` 进 9008） | 写分区/写 GPT 不受 lock 位限制；AVB 用 testkey 自签即被接受。**管线已就绪（2026-10-03 验证全绿）**：`scripts/build-locked-chain.sh`（从本单元 stock dump 自动读参数 → testkey 重打全链：vbmeta_b 顶层 2597c218 + chain boot:3 + recovery:1/vbmeta_system:2 原样 + 14 条原厂 props；`--follow_chain_partitions` 验证全绿）。⚠ **现有 `bootslot-b/` 的 fc1e3b33 自造密钥链不适用 locked**（green 态过不了 root-of-trust），必须用本管线重新生成 | ✅ **保留资产**（locked 单元/回锁场景；U2 已不需要） |
| D 社区「免解重签包」 | `restore-259/重签包/`（**第三方改过的 `abl`**，与原厂差 229109 B） | 引第三方闭源引导器，与「只用自己引导链」冲突；只给 root 不给 fastboot 写权限 | ⛔ 应急 |

> ★ **2026-10-03 实测结论（U2/HA2EXB0E）：实际走通的是「降级路」——第 5 条**。
> 1.5 高版本（259/Android16）下第三方 blob 的 `oem unlock-go` 失败（四代 ABL 换 key）；
> **线刷降级到出厂 `TB322FU_ZUXOS_1.1.11.073`（Android15）后，直接 `fastboot oem unlock` 一次成功**（无需 sn.img）。
> `getvar unlocked: yes`、`oem device-info: Device unlocked=true / critical unlocked=true`（orange）。
> 代价：解锁+降级擦 `/data`、Widevine L1→L3。详见 `PITFALLS` #86。
> **路 C 管线仍保留**（`scripts/build-locked-chain.sh`，对未解锁单元或将来回锁场景有用；U2 已不需要）。

**A 路生成命令**（SN 现读、不写死；模板来自本地 `y700四代工具/解BL/Y700 三代解锁工具箱by某贼.zip`）——⚠ 四代 1.5.x 已实测无效，仅对 ≤1.1.11.073 或三代机型参考：

```bash
SN=$(adb -s <SERIAL> shell getprop ro.serialno | tr -d '\r'); B=backup/${SN}-16+512; mkdir -p "$B"
unzip -p "y700四代工具/解BL/Y700 三代解锁工具箱by某贼.zip" bin/res/sn.img > "$B/sn-selfgen.img"
python3 - "$B/sn-selfgen.img" "$SN" <<'EOF'
import sys
p, sn = sys.argv[1], sys.argv[2].encode()
d = bytearray(open(p,'rb').read()); d += b'\0' * (0x2048 + len(sn) - len(d))
d[0x2048:0x2048+len(sn)] = sn
open(p,'wb').write(d); print('SN@0x2048 =', sn.decode(), 'size', len(d))
EOF
```

以下 ①→⑤ 为官方（B 路）与通用校验步骤；**A 路只把 `sn.img` 换成 `sn-selfgen.img`**。

### ① 不可逆项先拍证（纯读，零风险；解锁会永久改变下面几项）

```bash
scripts/bl-preunlock-evidence.sh <SN>     # 落盘 backup/<SN>-<CAP>/pre-unlock/，并打印申请表要填的两项
```
采集内容：全量 `getprop`、`/dev/block/by-name`、传感器清单、`settings`、**Widevine 级别**
（`sys.lenovo.widevine_security_level`，本机现 **L1**；解锁后预期永久降 L3，这是 `GAPS` Q1/Q5 的「标准答案」）。

### ② 官网申请 sn.img（需你的联想账号 + 大陆邮箱，助手不能代办）

| 项 | 值 / 说明 |
|---|---|
| 入口 | **https://www.zui.com/iunlock**（联想平板解锁唯一官方入口；实测可直连） |
| 表单 | 序列号 SN（8 位，= `adb shell getprop ro.serialno`，也见 fastboot 屏显 `SERIAL NUMBER`）+ **ZUX OS 必填** `Bootloader_SN`（= `getprop ro.boot.bootload_sn`，64 位 hex） |
| 限额 | 1 账号 / 年 3 台；每日额度有限（社区口径：0 点后申请成功率高）；**Gmail 可能收不到附件** |
| 产物 | 审核通过邮件附件 `sn.img` → 存 `backup/<SN>-<CAP>/sn.img`（**一机一码、可重复使用，永久保留**） |

### ③ 解锁（你按键，命令逐条给；**勿批量**——PITFALLS #1）

```bash
mv <邮件下载目录>/sn.img backup/<SN>-<CAP>/ && cd backup/<SN>-<CAP>/   # 路径不含中文
cd /home/xuqianhui1001/y700-elden && adb -s <SN> reboot bootloader      # 或关机后 音量下 + 电源
fastboot getvar all | grep -iE "serialno|unlocked|secure|product"       # 核 DEVICE STATE - locked
fastboot flash unlock sn.img                                            # ⚠️ OKAY 只代表「传输被接受」，不代表验签通过
fastboot oem unlock-go                                                  # ★真正的判定在这里；屏显菜单：音量键选 UNLOCK，电源键确认
```
→ 设备自动重启 + 全盘擦除 + 加密重启，**约 3–5 分钟，全程勿拔线**。
（`fastboot flash unlock` 的目标在分区表里没有对应条目，由 ABL 特殊处理 —— 属正常，见 `backup/<SN>-*/pre-unlock/by-name.txt`。）

### ④ 校验 + 副作用回填

```bash
fastboot getvar unlocked                 # yes（或屏显 DEVICE STATE - unlocked）
adb shell getprop ro.boot.flash.locked        # 0
adb shell getprop ro.boot.verifiedbootstate   # orange
adb shell getprop sys.lenovo.widevine_security_level   # 记录新值，回填 GAPS Q1
```
副作用（登记用）：保修失效 / FOTA 不可用 / 开机解锁警告 / Widevine L1→L3 / TEE 类（指纹支付、银行 App）受影响。
**a 槽系统与 `abl` 分区内容不变**（只写 unlock 标志 + 擦 `/data`）→ 不影响 Phase 0–3；root 需重做（`env-pass/`）。

### ⑤ A/B 两路都被挡下时（新版屏蔽解锁指令，1.5 系已知风险）

失败特征串（来自本项目 EDL 技能）：**`Download is not allowed on locked devices`** = ABL 版本较新/不认此 blob → 先降级再试。
`fastboot flash unlock` 报 unsupported / 无响应 → **不为解锁停摆**：直接转 **C 路（EDL）**推 G1
（写分区、写 GPT、写自签 boot 都不需要解锁标志）。若确实要 fastboot 写权限，再回退旧版 ZUXOS
（`restore-259/` + `qdl` + `xbl_s_devprg_ns.melf`）后重试 A/B。资产均已在项目内，不额外下载。

---

</details>

## 1. Phase 0 — 信息采集（Android + fastboot）

```bash
adb devices
adb shell getprop | grep -iE 'hwboardid|ro.product.name|ro.build.fingerprint|ro.boot.hardware'
adb reboot bootloader
# 逐条执行（本机 fastboot 讨厌批量）
fastboot getvar current-slot
fastboot getvar unlocked
fastboot getvar product
fastboot getvar partition-size:boot_b      # 期望 0x6000000 (96 MiB)
fastboot getvar partition-size:dtbo_b      # 期望 0x2000000 (32 MiB)
```
记录 build fingerprint / hwboardid / serialno，**当场写入 `DEVICE.md` 台账**（填 §0.0 的 `SN`/`CAP`）。
本 runbook **不要求**特定容量档；确认是 `TB322FC_SM8750P_*` 即可继续。

---

## 2. Phase 1 — 备份（b 槽原厂分区 + GPT）

### 2.1 fastboot fetch 将被覆盖的 b 槽分区（**必做**）

```bash
mkdir -p "$BAK"
fastboot fetch boot_b   "$BAK"/boot_b.img
fastboot fetch dtbo_b   "$BAK"/dtbo_b.img
fastboot fetch vbmeta_b "$BAK"/vbmeta_b.img
```
（a 槽不动，无需备份；`fastboot fetch` = 只读，无风险。b 槽原厂三件套是本 runbook 的**唯一回退手段**，必须先取。）

### 2.2 GPT dump（需先 RAM 启动 mainline，见 Phase 2）

在 Phase 2 设备进入 mainline 后执行：

```bash
scp scripts/gpt-dump.sh root@192.168.7.1:/tmp/
ssh root@192.168.7.1 'PREFIX=/tmp/gpt-new sh /tmp/gpt-dump.sh'
scp root@192.168.7.1:/tmp/gpt-new-primary.bin "$BAK"/gpt_main0.bin
scp root@192.168.7.1:/tmp/gpt-new-backup.bin  "$BAK"/gpt_backup0.bin
```
校验：`python3 scripts/gpt-surgery-tb322fc.py list --main "$BAK"/gpt_main0.bin --backup "$BAK"/gpt_backup0.bin`
→ 应看到 16 个分区、free slots 16–31，并打印**本单元的** `backup_lba` 与 `userdata` 大小
（256G 档 `userdata` ≈ 211 GiB；512G 档 ≈ 470 GiB —— **以实际输出为准，不预设**。

---

## 3. Phase 2 — b 槽直启「RAM 版 vk40」（首次上机，零写盘）

> ⚠️ **本 Phase 的「RAM 版」= 纯 RAM 变体（无桌面/会话服务，`findmnt /`=`rootfs`）**，只用于硬件/引导首验。
> **功能/服务级验收（桌面、PipeWire、蓝牙音频、Waydroid）必须用持久根**（Phase 4/5）或 `fastboot boot` **持久变体**（零写盘，见 `PITFALLS` #93）。

只覆盖 **b 槽**（原厂已备份）：

```bash
cd ~/y700-elden
fastboot --set-active=a
fastboot flash dtbo_b   bootslot-b/dtbo_b.img
fastboot flash boot_b   bootslot-b/boot_b_vk40-ram.img
fastboot flash vbmeta_b bootslot-b/vbmeta_b_flags3.img
fastboot --set-active=b
fastboot reboot
```
**期望**：设备自己进 mainline（~9s），`ping 192.168.7.1` 通、`ssh root@192.168.7.1` 进、
`findmnt /` = `rootfs`（RAM）。此时 `dmesg | head` 应显示 Adreno/NT36536 等。

> ⚠️ **`fastboot boot` 跳过 flash 时会卡 logo**：stock `dtbo_a/b` 含 76 个 Android overlay，`fastboot boot` 时 ABL 会把它合并进内核 DT → 模型/面板不匹配 → 卡联想 logo 后回 fastboot。
> 所以**要么按上面刷 blank `dtbo_b`，要么先用 `fastboot flash dtbo_b out/dtbo-dummy.img`**（2026-10-03 U2 实测）。
> ⚠️ 每次 b 槽启动失败 ABL 会把 `boot_b` 的 `tries_remaining` 扣 1（`scripts/slot-attr.py show`）；扣到 0 则 b 被标 UNBOOTABLE。b 槽能稳定启动后跑一次 **`python3 scripts/slot-attr.py mark-successful b`**（把 `succ=1`/`retry=7` 写回 GPT），否则反复调试会把 b 槽试到不可启动。

**失败**（回 fastboot，不是砖）→ 回退：
```bash
fastboot --set-active=a
fastboot flash boot_b   "$BAK"/boot_b.img
fastboot flash dtbo_b   "$BAK"/dtbo_b.img
fastboot flash vbmeta_b "$BAK"/vbmeta_b.img
fastboot reboot
```

**验证清单（此步就要过 = G1 验收矩阵的硬件部分）**：显示/触屏、SSH、WiFi（若要）、CPU/温度、`ls $BLK*`、**`dmesg` 里原厂固件加载（ADSP / WCN / GPU zap / 触屏 FW）无失败**。
OOB 串口：`bash scripts/serial-run.sh 'uname -r; id'`。

> ★ **持久根（Phase 4/5）熄屏稳定性**：**未解 / 间歇性**。根因已锁定为单模块 **`cambistmclkcc-sm8750`**（相机 BIST MCLK 时钟控制器）× DT 电源域耦合（H1/D1/D2/H2 四种改法均未根治）；**无相机模块态安全**。**规避必须保留**（禁空闲熄屏 + 不自动加载相机模块：cmdline `elden_nocamera=1` + `idle-delay=0`）。样本数/实验矩阵以 `TASKS.md` §5 Q24 与 §1 G1-22/G1-33 为准（本文件不维护状态）。
> 规避（旧内核/未确认时用）：
> ```bash
> # 持久根上（拿到 phoc 的 session bus 后）
> DBUS_SESSION_BUS_ADDRESS=$(tr '\0' '\n' </proc/$(ps -eo pid,args|awk '/[p]hoc -v/{print $1;exit}')/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p') \
>   gsettings set org.gnome.desktop.session idle-delay 0
> ```
> 并把它（或 phosh caffeine 常开）写进 `scripts/start-desktop.sh`，随 rootfs 归档固化。
> ⚠️ **不要在只能靠 SSH 进入的持久系统上做“把 idle-delay 改成 10”这类实验**——会直接把自己锁在外面。

---

## 4. Phase 3 — GPT 手术（从 mainline 写 UTC LUN0）

先 **dump GPT**（§2.2），然后在主机生成新 GPT：

```bash
cd ~/y700-elden
# 容量按 DEVICE.md §3.2 一次给足（256G 档 64–96；512G 档 160–200）；输入必须是本单元自己的 dump
python3 scripts/gpt-surgery-tb322fc.py build \
  --main "$BAK"/gpt_main0.bin \
  --backup "$BAK"/gpt_backup0.bin \
  --out-prefix "$BAK"/gpt_new --linux-gib "$LINUX_GIB" --linux-name linux17
```
把产物送进设备并写入（**主表 seek=0；备表 seek=backup_lba，值由 `list` 打印**）：

```bash
NEW_BLBA=$(python3 scripts/gpt-surgery-tb322fc.py list --main "$BAK"/gpt_new_main0.bin | sed -n 's/.*backup=\([0-9]*\).*/\1/p' | head -1)
scp "$BAK"/gpt_new_main0.bin   root@192.168.7.1:/tmp/
scp "$BAK"/gpt_new_backup0.bin root@192.168.7.1:/tmp/
ssh root@192.168.7.1 "dd if=/tmp/gpt_new_main0.bin   of=$BLK bs=4096 seek=0          conv=notrunc; \
                      dd if=/tmp/gpt_new_backup0.bin of=$BLK bs=4096 seek=$NEW_BLBA conv=notrunc; \
                      partprobe $BLK; ls -l /dev/disk/by-partlabel/"
```
**回读校验**：再 dump 一次并 `list`，确认 `linux17` 末扇区 = `last_usable`、CRC 自检通过。

> ⚠️ **Android 侧后果**：`userdata` 变小后里面的 f2fs 仍自认大容量 → a 槽首次启动会 bootloop。
> 两条出路（按“a 槽可弃”新前提）：
> - **A（默认）不保留 Android**：不管 a 槽，直接当纯 Linux 机用；回退 = `backup/stock-259/` + EDL 全量刷。
> - **B 暂时保留 a 槽**（做 Q5 真机对照取证期间需要）：`fastboot erase userdata && fastboot erase metadata` 重建 `/data`。
>   先例：U1 手术后重建 `/data` 146.4 GiB + FBE 正常（`archive/topics/复盘-2026-09-30-日.md`）。
> **无论 A/B，覆盖 a 槽前先把 `TASKS.md §6` §4 第 2 条的“真 Android 对照取证”做完（不可复得）。**

---

## 5. Phase 4 — 建 `linux17` 并恢复持久 rootfs

在 RAM 版 mainline 里：

```bash
ssh root@192.168.7.1
# 1) 格式化新分区（用 PARTLABEL 更稳；名字=linux17）
mkfs.ext4 -L linux17 /dev/disk/by-partlabel/linux17
mkdir -p /mnt/new && mount /dev/disk/by-partlabel/linux17 /mnt/new
```
主机推 rootfs 归档并解包：

```bash
scp env-pass/backup-20261002/linux17-rootfs-20261002.tar.gz root@192.168.7.1:/tmp/
ssh root@192.168.7.1 'tar xzf /tmp/linux17-rootfs-20261002.tar.gz -C /mnt/new && sync && df -h /mnt/new'
```
再把**本轮的模块包**叠加进去（与 vk40 同 vermagic）：

```bash
scp out/modules-7.2.0-debug-gba28ec16f01f-dirty.tar.gz root@192.168.7.1:/tmp/
ssh root@192.168.7.1 'tar xzf /tmp/modules-7.2.0-debug-*.tar.gz -C /mnt/new && depmod -b /mnt/new 7.2.0-debug-gba28ec16f01f-dirty'
```

---

## 6. Phase 5 — 切持久镜像（b 槽直启，固化成"开机即 Linux"）

```bash
cd ~/y700-elden
fastboot --set-active=a
fastboot flash boot_b bootslot-b/boot_b_vk40.img     # 已签名的持久版
fastboot --set-active=b
fastboot reboot
```
**期望**：自己进 Linux，`findmnt /` = `/dev/sda17`（或新分区号），Phosh 桌面自启。
之后改内核不再需要 fastboot：`scripts/flash-b.sh out/boot-elden-vkNN.img --reboot`。

---

## 7. Phase 6 — 接力主线任务的验证清单

| 项 | 命令 | 期望 |
|---|---|---|
| 内核 | `uname -r` / `cat /proc/version` | 以镜像内嵌 `LOCALVERSION=-vkNN` + `vkNN.manifest` 为准（vk42 起 uname 与版本名分离） |
| 模块 | `lsmod \| wc -l` | 模块可加载（1484 个在手） |
| 显示 | `ls /dev/dri`；Phosh 起来 | card0/renderD128 |
| Waydroid 图形 | 部署 `~/mesa-out` 包 + `waydroid session start` | SurfaceFlinger running（Mesa 26.1.8） |
| Waydroid 网络 | `waydroid status` 的 IP | 不再是 UNKNOWN（vk40 已含 netd IPv6/XFRM） |
| 相机 | `v4l2-ctl --list-devices` + `media-ctl -p` | media0 + video0-16 + subdev |
| 音频 | `amixer -c0 cset numid=8 on; speaker-test` | **✅ 出声已验收**（G1-4，vk43+）；裸 ALSA 默认路由 `scripts/audio-alsa-init.sh` |
| 温控 | `scripts/thermal-watch.sh`（主机推） | trip 70/82/90/105 |
| 基准 | `bash scripts/bench-run.sh`（G1-8） | 出 CPU/GPU 分数 |

---

## 8. 迭代快环（kexec / 模块热载 / Linux→fastboot）

> 2026-10-04 起。目标：把「改一行驱动 → 重启 → fastboot」从 20–40 min 压到 30 s–2 min。
> 统一入口 **`scripts/iterate.sh`**（根目录 `build.sh`/`pack.sh`/`cycle.sh` 为兼容保留）。

| 环 | 命令 | 何时用 | 代价 |
|---|---|---|---|
| **0 模块热载** | `scripts/iterate.sh mod <driver-dir>` | 改的是 `=m` 驱动的 `.c`/寄存器序列 | **~30 s，不重启** |
| **1 DTB** | `scripts/iterate.sh dtb --boot` | 改 DTS（pinctrl/regulator/面板时序） | `make dtbs` 秒级 + `--boot` ~1 min（**kexec 不传 DT**，见下） |
| **2 内核** | `scripts/iterate.sh kernel` | 改 `=y` 代码 / 新补丁 | 全量编译（ccache 暖后复用）+ kexec ~2–5 min |
| **3 RAM 兜底** | `scripts/iterate.sh ram` | 零写盘取证 / 回退验证 | fastboot boot（**需主机 USB**） |

**前置（一次性）**：应用模块化片段，否则环 0 不可用——
```bash
FRAG=patches/fragment-modular.config SNAP=patches/config-vk50-modular \
  bash scripts/apply-kernel-fragment.sh
bash scripts/iterate.sh kernel --boot      # 全量重编一次；此后驱动改动走环 0
```

**kexec 热重载**（`--kexec`，kernel 默认；**⚠️ 本机已定论不可用**）：
- ⚠️ **2026-10-05 定论**：`kexec -s -l` 装载成功，但 `kexec -e` **硬挂整机**（无 panic / 无看门狗 / pstore 空，需物理复位）；
  挂死分支点**尚未定位**（旧"串口戛然而止"不可用——`console=ttyGS0` 是 USB gadget，跨不过 kexec）。
  **日常改用 `--boot`（fastboot 零写盘）/ `--flash`。**
- ⚠️ **DTB 不能走 kexec**：`kexec_file_load(2)` 无 DTB 形参，新内核 FDT 由**运行内核的 live DT** 重建
  （`drivers/of/kexec.c: of_kexec_alloc_and_setup_fdt`）⇒ `--dtb` 是空操作，`iterate.sh dtb` 环经 kexec 不成立。
- 前置已就绪：内核 `CONFIG_KEXEC_FILE=y`（`KEXEC_SIG` 关）、设备 `kexec-tools 2.0.32`。
- 关键约束：**只能喂未压缩 `Image`**（`Image.gz` 不行）；`scripts/kexec-boot.sh` 已处理。
- 先验安全：`scripts/kexec-boot.sh --load-only`（只加载不切换）；失败时当前内核照常运行。
- 首测务必用**与运行内核同源（同 config、同 `LOCALVERSION`）且已知可启**的内核，并保留 `to-fastboot.sh` + `fastboot boot` 作为带外回退。
- 取证与根因分析：`archive/topics/KEXEC-2026-10-05.md`。

**Linux → fastboot**（必要时）：`scripts/to-fastboot.sh [--flash out/x.img] [--boot out/x.img]`
- 走 PSCI vendor reset（`eldroid-bootctl reboot bootloader`，vk41+）——这是唯一可靠路径；
  `cycle.sh --soft` 不再落 fastboot，`cycle.sh --fastboot`（misc BCB）ABL 不认（PITFALLS #65/#66）。
- `--flash` 先在 Linux 内 `dd` 写 boot_b 再重启（无需主机 fastboot 参与写盘）。

**每条 boot 镜像都有 manifest**：`out/boot-elden-<ver>.manifest`（内核/DTB/config/ramdisk 哈希 + cmdline +
`mkbootimg` argv + 两个 git HEAD），解决「vk49 打包命令丢失」。构建即生成，应随提交进 git。

---

## 9. 回退（任一步）

| 目的 | 命令 |
|---|---|
| 回 stock Android | `fastboot --set-active=a; fastboot reboot`（a 槽全程未动）= 回 G2-S0 |
| 恢复 b 槽原厂 | `fastboot flash boot_b/dtbo_b/vbmeta_b "$BAK"/*` |
| 恢复原 GPT | `dd` 写回 `"$BAK"/gpt_{main0,backup0}.bin`（主 seek=0、备 seek=**本单元** `backup_lba`） |
| 救砖 | EDL：`qdl/build/qdl ~/下载/tb322fc/xbl_s_devprg_ns.melf ...`（见 `restore-259/README.md`） |

---

## 10. Phase B（可选）— 回收 Android 专属分区给 Linux

> 目的：一次解决容量（而不是二次缩 `userdata`）。**仅在 G1 全绿 + 已做 Q5 取证 + EDL 备份在手时执行。**

```
可回收候选（同型号同布局，具体以本单元 GPT 为准）：
  super_a / super_b      ← 大块（原厂 system/vendor/product 所在）
  boot_a / dtbo_a / recovery_a / vbmeta_a
  metadata / misc / oemdrv 类本地数据分区
不可动：xbl* / abl* / tz* / hyp* / modem / ddr / 安全存列（Q6/SOTP）—— 动=砖
流程：先 `list` 导出全表 → 生成新表 → 主表 seek=0 + 备表 seek=backup_lba → **读回 md5 与分区表校验**
回退：写回本次 dump 的 `"$BAK"/gpt_{main0,backup0}.bin`；最坏 EDL（`qdl/build/qdl` + `~/下载/tb322fc/`）
```

---

## 11. 待你拍板（仅两项，均为容量/目标参数）

1. **`LINUX_GIB` 具体值**：上机后用 `du` 实测各组成回填 `DEVICE.md` §3.1（GAPS Q7），再定；默认按上界一次给足。
2. **本次目标**：只到 Phase 2（RAM 零写盘验收）还是走到 Phase 5（持久 Linux + Waydroid）？
