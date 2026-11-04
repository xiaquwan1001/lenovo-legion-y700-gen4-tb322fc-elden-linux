# UEFI 2026-11-04R-r1：判据换成 ramoops（主机可读，不依赖看屏）

> 目的：收口上一发（2026-11-04 `fixcopylen`）的 `verdict=indeterminate`——那发唯一判据是屏上串口，
> 而设备「反复刷屏」导致一帧没取到。本发把同一条轨迹**同时**写进 Linux 的 pstore，回到 Linux 就能 `cat`。

---

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

## 4. 风险与回滚

- **零写盘**：`fastboot boot` 不改任何分区；`boot_b` 仍是 `fb55997c…`（`DEVICE/README.md` §1.1 首条）。
- **DDR 清空风险**：若 UEFI 挂死需要物理断电，ramoops 记录随之丢失（这是本通道唯一硬限制）。缓解 = 屏上标记同时存在，且本发刻意不再无限滚动。
- **DXE allocator 覆盖风险**：UEFI 自己的内存图是否把 `0xC2000000` 当可用 RAM 未核实；记录在每条标记后重写，最新状态总在。
- **回退**：`fastboot reboot`；若两槽都不起，`fastboot --set-active=b` + `fastboot reboot`（PITFALLS #484）。
