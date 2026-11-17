# 设备窗口 2026-11-17 16:02–16:50：卡 BL 恢复尝试全账（**未恢复，已停手保留现场**）

> 用户口径（本轮）：设备已上机、已充电；**不要再读/推断电量**、不把电量当阻塞理由；第一优先级 = 让系统回到可登录/可 adb。
> 本文件 = 本轮全部动作与判据。零发信、零内核改动。工具：`fastboot -s HA2EXB0E`、`~/edl/qdl/build/qdl`（tag v2.9）、
> `~/edl/bkerler-edl/edl.py printgpt`、`scripts/logfs-decode.py`。取证件 = `reports/artifacts/bl-stuck-20261117/`（42 MB + `SHA256SUMS.txt`）。

## 0. 结论（先数字）

1. **未恢复**：2026-11-17 16:02→16:47 共 **11 次启动尝试**（`continue` ×4、`boot` ×5、EDL `reset` 冷起 ×3 窗口），**全部失败**，失败字符串在两次之间**自变**：
   `Failed to load image from partition: Device Error` / `Failed to load/authenticate boot image: Load Error` / `… Device Error`。
2. **软件侧已排除 7 类**（逐条有独立判据，见 §2）：镜像内容、GPT、槽属性、lock/verity 状态、vbmeta 链与 dtbo 一致性、ABL 本体、存储读路径。
   ⇒ **剩下的强候选 = 运行期内存/加载通路（疑似硬件），与 11-16 夜「EDL `poke` 32 MiB 不返回」同族**；已按全局规则 12 上交 hw-stability（不在本项目深挖）。
3. **本轮对设备只产生两类写**：① `fastboot --set-active`（槽元数据，可逆，已复原为 `b`）；② `fastboot flash boot_b bootslot-b/boot_b.img`
   —— 写入后 **qdl 设备端 sha256 = `06c081ca…` = 主机件逐字节相同**，即**没有改变内容**（等价于无效写，也已证明写路径正确）。

## 1. 现态（2026-11-17 16:47 `getvar`，件 = `artifacts/bl-stuck-20261117/getvar-20261117-1647.txt`）

| 项 | 值 |
|---|---|
| `current-slot` | **b**（本轮先设 a 排查过，已复原） |
| `slot-unbootable:a/b` | no / no |
| `slot-retry-count:a/b` | 6 / 7 |
| `slot-successful:a/b` | no / no（**`--set-active` 会把 successful 清零，这是正常语义，不是损坏**） |
| `unlocked` / `oem device-info` | `yes`、`Device unlocked: true`、`Device critical unlocked: true`、`Verity mode: false` |
| BL 版本（logfs） | `BOOT.MXF.2.5.1-00240.1-PAKALA-1.104055.4`、`SocPakalaLAA`、`Secure Boot: On`、hwid `SM8750P_16+512_13`、config `PRC`、UFS 512 GB / DDR 16 GB |

## 2. 逐条排除（每行 = 一条判据 + 命令/证据）

| # | 候选 | 判据 | 结论 |
|---|---|---|---|
| 1 | boot 镜像内容坏 | `qdl sha256 4/321824+24576` → `06c081ca…`（= `bootslot-b/boot_b.img`） | **排除**（内容与主机件逐字节相同） |
| 2 | 写路径坏 / 上次写没落地 | `fastboot flash boot_b` 后再 `qdl sha256` 仍 `06c081ca…` | **排除** |
| 3 | GPT 坏 | `edl.py printgpt`：5 个 LUN 全解析，`boot_a/boot_b/vbmeta_a/b/dtbo_a/b` 全在、长度正常（boot 96 MiB、dtbo 32 MiB） | **排除** |
| 4 | 槽属性导致 ABL 拒绝 | `b` 曾 `unbootable=yes/retry=0` ⇒ `--set-active=b` 后 `unbootable=no/retry=7`；冷起后 retry 7→6（**证明 ABL 真的尝试并失败**） | **排除**（属性已复位，仍失败） |
| 5 | lock / verity | `oem device-info`：unlocked=true、critical=true、`Verity mode: false` | **排除** |
| 6 | vbmeta 链 / dtbo 不一致 | `vbmeta_b` 读回 = `07-16` 备份 `e974ebab…`（**未变**）；`avbtool info_image`：`Flags: 3`（verification_disabled+hashtree_disabled）、chain `boot` → key `fc1e3b33…`；`dtbo_b` = 32 MiB AVB hash-footer 件，`Original image size: 4096`、key `fc1e3b33…`，与 vbmeta 的 dtbo 描述符（4096 B）一致；`vbmeta_a` **全 0**（a 槽 UEFI 期的既定状态） | **排除** |
| 7 | ABL 本体被改坏 | `abl_a` sha = `e7062378…` = `backup/fw/tb322fc-edl/abl.elf`（stock）；`abl_b` sha = `811489f0…` = `backup/stock-259/abl_b.img`，且 **11-16 取证件逐字节相同**（`cmp` rc=0）；两槽 ABL 都是 stock，无我们的 patch | **排除** |
| 8 | 存储读路径坏 | `boot_b`/`vbmeta_a`/`vbmeta_b`/`dtbo_b`/`misc`/`logfs`/`xbl_sc_logs`/`abl_a`/`abl_b`/`xbl_config_a/b` 共 12 个分区经 Firehose 读出，`sha256` 稳定、大小正确；96 MiB 一次 `sha256` 由**设备端**算完 | **排除**（读路径+96 MiB DRAM 缓冲在 Firehose 下正常） |
| 9 | **镜像大小/落点** | 用 **2.4 MB** 的 `out/uefi-ddrmarks-clean-20261102/uefi-v0.img` 做 `fastboot boot` ⇒ **同样 `Device Error`** | **排除**「只有大镜像才失败」 |
| 10 | 槽相关（dtbo_a vs dtbo_b 处理不同） | `--set-active=a` 后 `fastboot boot out/boot-elden-vk192.img` ⇒ 同样 `Device Error` | **排除** |

## 3. 未能取到的判据（说明边界）

- **失败时的 ABL 日志拿不到**：`logfs` 里只有 **10 个有效启动段，全部是「成功交接」**（`BootLinux` + `Start EBS`），
  其中段 0（slot `_b`）就是我们自己 cmdline（`elden_root=LABEL=linux17 … androidboot.slot_suffix=_b`）并**带一行**
  `avb_slot_verify.c:913: ERROR: vbmeta_b: Public key used to sign data rejected.` —— 但该段**随后照常起动**
  （unlocked ⇒ 只告警）；`xbl_sc_logs` 128 KiB **全 0**（未启用）。⇒ 今天的失败**没有**留下段级记录（ABL 只在交接成功时落 logfs）。
- EDL 无 `peek`（`PITFALLS #486`）⇒ 无法直接读写 DDR 做内存正控。

## 4. 与已知 PITFALLS 的关系（为什么这次不归到已知项）

| 已知项 | 是否解释本轮 |
|---|---|
| `#1`「`fastboot boot` 失败后进脏态 ⇒ `fastboot reboot bootloader` 可清」 | **试过无效**（reboot bootloader 后同一失败） |
| `#523`「同一固件会话连打会致后续 `Load Error`」 | **试过换会话无效**（EDL reset / reboot bootloader 多次） |
| `#508`「32 MiB 全 0 dtbo > 24 MiB 上限 ⇒ Load Error」 | 与「`continue`(Device Error) + 2.4 MB 镜像也失败 + 换槽仍失败」不符 |

## 5. 恢复动作（按代价升序，**需要用户**的已标注）

1. **【需人·物理】完全断电**：长按电源 **15–20 s** 至完全黑屏 → **等 10 s** → **只按电源键**开机（不插 USB）。
   预期 A：进系统（问题自愈）；预期 B：仍落 fastboot ⇒ 排除「DDR 训练/上电残留」，进入 2。
2. **【需人拍板】stock 引导链重刷（EDL，我可执行）**：用官方 `~/文档/TB322FC_15.10.259/rawprogram*.xml` 只刷
   `xbl/xbl_config/abl/uefi/boot/dtbo/vbmeta`（**不碰** `elden-*`/`linux17`/`super`/GPT）。
   回退件齐备：GPT 双表 dump、`bootslot-b/boot_b.img`（`06c081ca…`）、`backup/stock-259/*`。
   代价：若变砖风险窗口 = 写 `xbl` 期间断电（可 EDL 重入）。
3. **【需人拍板】换 Android 优先**：把 stock `boot.img`+`vbmeta` 刷到 a/b 槽 ⇒ 先拿到「能进系统」，
   Linux 侧再用我们的产物重建（`boot_b`/ESP 件都在库）。
4. **【用户外部】硬件判定**：若 1 无效且 2 也无效，则按规则 12 的证据走 hw-stability / 保修线，不在项目内继续深挖。

## 6. 本轮写操作清单（全部可逆，已复原）

1. `fastboot --set-active=b` → 后 `a` → 后 `b`（最终 = `b`，与 11-16 结束态一致）。
2. `fastboot flash boot_b bootslot-b/boot_b.img`（内容 = 设备现值，qdl 读回 `06c081ca…` 一致）。
3. `fastboot oem edl` ×3、`qdl reset` ×3（只进出 9008，不写 flash）。
4. **未**写：GPT、xbl、xbl_config、abl、uefi、vbmeta、dtbo、linux17、eldenesp。
