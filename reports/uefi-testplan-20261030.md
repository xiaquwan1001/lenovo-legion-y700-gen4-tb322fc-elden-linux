# UEFI 上机执行单（2026-10-30）

> **配套总账**：`reports/uefi-consolidated-20261030.md`（事实 F1–F27 / 阻塞 B1–B10 / 资产 #1–#44）。
> **本文件是执行单，不是综述**：每一步都有「命令 → 判据 → 预期失败模式 → 回退」。
> **路线口径不变**：`TASKS` §4 N1 / §5 Q25 仍是「搁置」；本单**只为「拿回可见性」**这一件事上机，
> **不修 UFS、不写 a 槽、不动 `uefi_a`/`imagefv_a`、不改 GPT**。
> **本次未执行任何设备命令**；以下命令均为待用户执行。

---

## §0 目标与总判据（一页）

| 项 | 内容 |
|---|---|
| **本轮唯一目标** | **J1 = 屏上出字**（EDK2 DEBUG 行 / `Synchronous Exception` 块）——即复现 2026-10-05 |
| **次要目标** | J2 = 若出字，用 `memmap` 回答 B1（`0xD6ABB030` 是否在 MemMap 内）；J3 = 若 UFS 起来了，`map -r` 列卷 |
| **不做** | tiny DXE（B8）、刷 `uefi_a`/`imagefv_a`（路线 B）、GPT 手术、RmVmDxe/FDT 实验（第二步以后再说） |
| **镜像顺序** | **① E0（10-05 口径，无 cache 补丁）→ ② E1（+dodge patched UFSDxe）**，两者**都必须先按 `--base 0x10000000` 重打包** |
| **总时长预算** | 主机 15 min（校验 + 2 次 repack）+ 设备 20 min（2 发 + 回退），**每发前后各 1 次 `slot` 核查** |
| **失败即止** | 任一步现象与下表不符 ⇒ **停止重试**，保留现场（`getvar`、`lsusb`、屏幕录像、ABL 日志），按 `.pi/AGENT-OPS.md` §1 上报 |

**为什么不能直接 `fastboot boot` 现成镜像**（本次实测复算）：

| 镜像 | header | `kernel_addr` | 结论 |
|---|---|---|---|
| `uefi-built-20261024/{A,C,N}.img` | v3 | 0x0（v3 无此语义） | ❌ `PITFALLS` #387：本机 ABL 对 v3 **静默不交棒** |
| `uefi-visibility-20261026/{A2,N2}.img` | v3 | — | ❌ 同上 |
| `uefi-v0-20261027/{A2,N2}-v0.img` | v0 | **0x8000** | ❌ `PITFALLS` #418：`Booting OKAY` 但静默不交棒 |
| `uefi-e0e1-20261028/{E0,E1}-v0.img` | v0 | **0x8000** | ❌ 同上 ⇒ **必须先 repack** |

⇒ **本单第 2 步就是把这 4 枚 v0 重新打包到 `kernel_addr=0x10008000`**（载荷逐字节不变，只改 header）。

---

## §1 前置检查（全部只读，命令带 `timeout -k`）

### 1.1 主机侧（不碰设备，先跑完这一步再插线）

```bash
cd ~/y700-elden
# P1 资产哈希（应逐条命中；任何一条不符 = 停止，先查原因）
timeout -k 5 60 sha256sum \
  reports/artifacts/uefi-e0e1-20261028/lenovo-y700g4-E0-v0.img \
  reports/artifacts/uefi-e0e1-20261028/lenovo-y700g4-E1-v0.img \
  reports/artifacts/uefi-v0-20261027/lenovo-y700g4-A2-v0.img \
  reports/artifacts/uefi-v0-20261027/lenovo-y700g4-N2-v0.img
# 期望：987bcde9…a16f2 / 1ae201c2…96540 / 2282953b…32b9b / 0cef239a…88025

# P2 现有 header 实读（确认「必须 repack」这条前提没变）
timeout -k 5 30 python3 - <<'EOF'
import struct, glob, os
for f in sorted(glob.glob("reports/artifacts/uefi-*/*.img")):
    d = open(f, "rb").read(4096)
    if d[:8] != b"ANDROID!": continue
    ps = struct.unpack_from("<I", d, 36)[0]
    hv = struct.unpack_from("<I", d, 40)[0]
    ka = struct.unpack_from("<I", d, 12)[0]
    print(f"{os.path.basename(f):30s} hv={hv} pagesize={ps} kernel_addr=0x{ka:x} -> {'OK' if ka==0x10008000 else 'NEED REPACK'}")
EOF

# P3 构建树在盘 + 状态（若走 §2 选项 B 才需要）
timeout -k 5 60 git -C build/uefi-woa-prep/repos/7-mu-lenovo log -1 --format='%h %ad %s'
timeout -k 5 60 du -sh build/uefi-woa-prep            # 期望 8.2G
timeout -k 5 30 sha256sum \
  build/uefi-woa-prep/repos/7-mu-lenovo/Platforms/PakalaPkg/Device/lenovo-y700g4/PatchedBinaries/UFSDxe.efi
# 期望 00ae059f…80ac1（= Mu 补丁件，E1 用的是另一枚 e76b555f，见总账 B3）
```

### 1.2 设备现状（必须现场核对，**不要相信文档快照**）

| 检查 | 命令 | 期望 / 判读 |
|---|---|---|
| **当前跑的是 m3v5-daily 测试镜像** | `ssh root@192.168.7.1 'uname -v; sha256sum /proc/config.gz 2>/dev/null \| head -1'` | `uname -v` = `#1 SMP PREEMPT Fri Oct 30 11:22:59`（= `reports/m3v5-onboard-20261030.md` §0）。**首次 SSH 可能失败**：`elden_early_gadget=1` 下 `usb0` 需 20–40 s 才起 |
| **`boot_b` 里到底是什么** | 主机侧：`timeout -k 5 30 sha256sum bootslot-b/boot_b.img` | 本次复算 = `55d06551…48d`，其 kernel 段 sha 与 `out/boot-elden-m3v5-daily.img` **逐字相同** ⇒ **`boot_b` 已被 10-30 的 m3v5 刷写覆盖**；`DEVICE/README.md` §1.1 的 10-29 快照（`b72866ef…` = vk181）**已过期**（本次只读，未改 DEVICE） |
| **回退件（必确认存在）** | `ls -l bootslot-b/boot_b-vk181-daily-signed-20261029.img bootslot-b/boot_b-f2fs-root.img` | 100 663 296 / 100 663 296；sha `b72866ef…d1e9` / `257266ec…14a4` |
| **失败后的落点** | 失败 `fastboot boot` 后设备会 **回落 stock Android 槽 a**（不是回 Linux）；回 Linux 需 `set_active b` + `reboot` | `PITFALLS` #387 / #418 |
| **GPT 备份（本轮不动 GPT，只作兜底确认）** | `ls -l backup/HA2EXB0E-16+512/gpt-20261025/ backup/HA2EXB0E-16+512/m8ab-restart-20261030/` | 双 LUN 双表都在（总账 §5 #39/#40）；**注意 `m8ab-restart-20261030/gpt-$d-$part.bin` 是 0 字节残留** |
| **槽状态基线（每发前记一次）** | `fastboot getvar current-slot`、`fastboot getvar slot-unbootable:b`、`fastboot getvar slot-retry-count:b` | 期望 `b / no / 6`；**若 `slot-unbootable:b=yes` 先 `fastboot set_active b` 修回再开始** |

---

## §2 构建侧：能不能直接复用？

### 2.1 结论（先答问题）

| 问题 | 答案 |
|---|---|
| `build/uefi-woa-prep` 能否直接复用？ | **能。** 8.2 GiB 在盘；`repos/7-mu-lenovo` 5.6 GiB、HEAD `6b6ac42a`、11 个 submodule 全就位、`Build/` 里有上次产物、工具链（clang-21 / mono / iasl / nuget ext-dep）均未换 |
| 需要重编 FD 吗？ | **不需要**（本轮目标是拿回可见性，E0/E1 的 FD 已经存在且 sha 与记录一致）。**只需 repack header**（纯主机、秒级） |
| 什么情况才必须重编？ | ① 要做 B9/配置表核对（把本机 62 条表编进 FD）；② 要换某个 `PatchedBinaries/*.efi`（如把 E1 的 `e76b555f` 换成仓库 `00ae059f`，或换回厂商 `fa561bf1`） |
| 重编耗时 / 风险 | 增量 14–15 s / 首构 60 s；**两个已验证的坑**：`stuart_build` 不通（F26）、`-n 26` 会 clang SIGSEGV（用 `-n 12`） |

### 2.2 选项 A（**推荐，本轮就走这条**）：只重打包 header，不编译

```bash
cd ~/y700-elden
mkdir -p /tmp/uefiboot-20261030 && cd /tmp/uefiboot-20261030

# A1 从 v0 镜像里取出 kernel 段（payload 逐字节不变）
timeout -k 5 120 python3 - <<'EOF'
import struct, os
SRC = os.path.expanduser("~/y700-elden/reports/artifacts")
for name, path in {
    "E0": "uefi-e0e1-20261028/lenovo-y700g4-E0-v0.img",
    "E1": "uefi-e0e1-20261028/lenovo-y700g4-E1-v0.img",
    "A2": "uefi-v0-20261027/lenovo-y700g4-A2-v0.img",
    "N2": "uefi-v0-20261027/lenovo-y700g4-N2-v0.img",
}.items():
    d = open(os.path.join(SRC, path), "rb").read()
    ps = struct.unpack_from("<I", d, 36)[0]
    ks = struct.unpack_from("<I", d, 8)[0]
    open(f"{name}.kernel", "wb").write(d[ps:ps+ks])
    print(name, "pagesize", ps, "kernel", ks)
EOF

# A2 重打包到 kernel_addr=0x10008000（PITFALLS #418）
for n in E0 E1 A2 N2; do
  timeout -k 5 60 python3 ~/y700-elden/scripts/mkbootimg.py \
    --kernel /tmp/uefiboot-20261030/$n.kernel \
    --ramdisk ~/y700-elden/reports/artifacts/uefi-e0e1-20261028/empty.ramdisk \
    --header_version 0 --pagesize 4096 \
    --base 0x10000000 --kernel_offset 0x8000 \
    --cmdline "" -o /tmp/uefiboot-20261030/$n-v0b.img
  echo "$n rc=$?"
done

# A3 验收：必须全部 kernel_addr=0x10008000，且 gunzip 能完整解开
timeout -k 5 60 python3 - <<'EOF'
import struct, gzip, hashlib, glob, os
for f in sorted(glob.glob("/tmp/uefiboot-20261030/*-v0b.img")):
    d = open(f, "rb").read(); ps = struct.unpack_from("<I", d, 36)[0]
    ks, ka = struct.unpack_from("<I", d, 8)[0], struct.unpack_from("<I", d, 12)[0]
    hv = struct.unpack_from("<I", d, 40)[0]
    g = gzip.decompress(d[ps:ps+ks])
    print(f"{os.path.basename(f):16s} hv={hv} kernel_addr=0x{ka:x} size={len(d)} payload={len(g)} sha={hashlib.sha256(d).hexdigest()[:16]}")
EOF
```

**验收位（硬要求）**：
- `hv=0`、`kernel_addr=0x10008000`、`payload=4194416`（E0/E1）或 `4194464`（A2/N2）——**四个数字任一不对就停**；
- 用 `scripts/grubfat-inspect.sh /tmp/uefiboot-20261030/E0-v0b.img` 确认 `_FVH` 在载荷偏移 152、PE/MZ 计数与记录一致（E0 = 33）；
- **把每枚新镜像的 sha256 现场写进本轮 record**（`scripts/trial.sh`），**禁止手抄到文档**。

> **为何不改成 `--header_version 3`**：10-05 那发 v3 真跳了，但 10-24/26 两次实测 v3 被静默忽略（B5，未解）；**本轮用 v0 是保守选择**，不要在首轮把两个变量混在一起。
>
> **两个无害变化，不要因此判失败**：① `ramdisk_addr` 会从 `0x1000000` 变成 `0x11000000`（base 变了，ramdisk 是 0 字节占位）；② `os_version`/`tags_addr` 用 `scripts/mkbootimg.py` 默认值。**只有 `kernel_addr` 是判据**（`#418`）。

### 2.3 选项 B（仅当要换二进制才做）：重编 FD + 重打包

```bash
cd ~/y700-elden/build/uefi-woa-prep/repos/7-mu-lenovo
export CLANG_BIN=/usr/lib/llvm-21/bin/            # 结尾斜杠必须有（否则 /usr/lib/llvm-21/binclang: not found）
export PATH=$HOME/.local/bin:$PATH

# B1 换件（例：把 PatchedBinaries/UFSDxe.efi 换成厂商 fa561bf1；先备份！）
D=Platforms/PakalaPkg/Device/lenovo-y700g4/PatchedBinaries
cp $D/UFSDxe.efi /tmp/UFSDxe.before.efi
cp ~/y700-elden/reports/artifacts/uefi-dxe-20261024/vendor-UFSDxe.efi $D/UFSDxe.efi

# B2 构建（CI 口径；超时 1800 s，单步 < 30 min）
timeout -k 10 1800 ./build_uefi.py -d lenovo-y700g4 -t RELEASE; echo "BUILD_RC=$?"
# 产物：Build/PakalaPkg/RELEASE_CLANGPDB/FV/SM8750_EFI.fd  (4 194 304 B)
#       Build/PakalaPkg/lenovo-y700g4.img                    (v3，需 §2.2 步骤 A2 重打包)

# B3 还原（不留副作用）
cp /tmp/UFSDxe.before.efi $D/UFSDxe.efi
```

**若 `build_uefi.py` 失败**（已知两条）：
1. `error 7000 / F002` 且日志尾部全是 `warning: Unrecognized content` ⇒ 是 `Trim` 不在 PATH，**别信 stuart 的输出**；改用直接 BaseTools 构建（完整命令与环境变量见 `uefi-visibility-rebuild-20261028.md` §1.4，**`-n 12`**，实测 ~44 s）；
2. `clang: error: clang frontend command failed with exit code 139` ⇒ 并发太高，降 `-n`。

**校验位**（重编后必须核）：
```bash
timeout -k 5 60 sha256sum Build/PakalaPkg/RELEASE_CLANGPDB/FV/SM8750_EFI.fd
timeout -k 5 120 python3 ~/y700-elden/scripts/ffs-extract.py \
  Build/PakalaPkg/RELEASE_CLANGPDB/FV/SM8750_EFI.fd --out /tmp/ffs-check >/dev/null
# 内层需先解 LZMA(GUID ee4e5898-3914-4259-9d6e-dc7bd79403cf)，fd 内有两处命中（0x9d8c 是假命中，真段在 ~0xd250）
timeout -k 5 60 sha256sum /tmp/ffs-check/0d35cd8e-DXE_DRIVER-PE32.bin
# 期望 = 你换进去的那枚（厂商 fa561bf1… 或 00ae059f…）——这是「换件真的进了 FV」的硬判据
```

---

## §3 上机步骤（逐步可复制；**每发只改一个变量**）

> 设备约定：实验单元 = **HA2EXB0E / U2（16+512）**；U1 不动。全程**零写盘**（只写 misc 槽属性）。
> 单条 fastboot 命令**逐条跑**，不批量（`AGENT-OPS` §2 / `PITFALLS` #3）。

### 3.0 每发前的就绪门（**必修，`PITFALLS` #376：每发重过**）

```bash
# S0-a 设备在 Linux 且能 ssh（拿基线：内核身份 + 槽状态）
timeout -k 5 20 ssh -o ConnectTimeout=8 root@192.168.7.1 'uname -v; uptime'
# S0-b 录屏开始（手机/相机，60 fps）——10-05 的异常字块会刷屏，事后逐帧看
echo "!! 现在开始录像，然后再进 bootloader !!”
# S0-c 进 fastboot（两条路，优先①）
timeout -k 5 20 ssh root@192.168.7.1 'reboot2 bootloader'   # ① 内核 PSCI SYSTEM_RESET2
timeout -k 5 20 adb reboot bootloader                      # ② 备选
# S0-d 等 ≥12 s 再探（PITFALLS #368：刚硬复位 ~11 s 内下发 ⇒ 不进 fastboot 且 USB 全不枚举）
sleep 12
timeout -k 5 20 fastboot devices          # 必须看到序列号；看不到就停（见 §4 失败模式 F0）
timeout -k 5 20 fastboot getvar current-slot
timeout -k 5 20 fastboot getvar slot-unbootable:b
timeout -k 5 20 fastboot getvar slot-retry-count:b
# 期望 b / no / 6；若 unbootable=yes：timeout -k 5 20 fastboot set_active b
```

### 3.1 发 1：E0（10-05 口径，无 cache 补丁）

```bash
timeout -k 5 30 sha256sum /tmp/uefiboot-20261030/E0-v0b.img   # 记下（写进 record）
timeout -k 10 120 fastboot boot /tmp/uefiboot-20261030/E0-v0b.img
# 从这条命令开始计时，前 3 s 内盯 USB
```

**立即判据（< 5 s）**：

| 输出 | 判读 | 下一步 |
|---|---|---|
| `Booting FAILED (usb_read failed: No such device)` + `lsusb` 不再见 `18d1/05c6` | ✅ **真交棒**（负载已开始执行） | 看屏幕 + 等 90 s |
| `Booting OKAY [N s]` 且 `fastboot devices` **仍应答** | ❌ **ABL 没跳**（header/base 或 handoff 条件不符） | **停**，不要重试；回 §2 核 header（参 `PITFALLS` #387/#418） |
| `fastboot: error: Couldn't parse image header` 等 | ❌ repack 出错 | 停，查 §2 A3 |

### 3.2 发 1 的观察窗（90 s）

```bash
# 每 5 s 一次，共 ~18 次；任一步命中即记时间戳
for i in $(seq 1 18); do
  date +%T; timeout -k 2 4 lsusb | grep -Ei '18d1|05c6|17ef|1d6b' || echo "  (USB 空)"
  sleep 5
done
```

**结果分类**（三选一，不存在第四种）：

| A | **屏幕出字**（白字/异常块/EDK2 banner） | **J1 达成** → 直接进 §3.3，抢在刷屏前读完最后 10–15 行 |
| B | 全程联想 logo，无切换，~80–90 s 后以 `17ef:7f3d`（stock Android）出现 | 与 10-26 同（F25）→ **J1 未达成**；停，不要连发；按 §5 回退并保留录像 |
| C | 黑屏/花屏/卡死（>120 s 无任何变化） | **人工断电**（长按电源 10 s），然后按 §5 回退；现象要完整记录（这是新失败模式） |

### 3.3 发 2：E1（E0 + dodge `UFSDxe.patched.efi`）——**仅当发 1 出字（结果 A）才做**

```bash
# 回到 fastboot（若上一发已回落 Android：先 adb reboot bootloader；若仍在 UEFI/黑屏：长按断电后重走 §3.0）
timeout -k 5 20 fastboot devices
timeout -k 5 30 sha256sum /tmp/uefiboot-20261030/E1-v0b.img     # 记下
timeout -k 10 120 fastboot boot /tmp/uefiboot-20261030/E1-v0b.img
```

**E1 专项判据**（对照发 1，只差 `UFSDxe` 一枚）：

| 现象 | 判读 | 下一步 |
|---|---|---|
| 与 E0 **完全相同**（同 PC、同回溯） | dodge 补丁对本机 UFS 层**无效** | 停；结论 = link/PHY 层假设弱化 |
| `ufs_error_log 11/3b/55` **消失**，但出 `Synchronous Exception`（`ESR 0x96…05`） | link 层修好、**卡在 SMMU 层** | 下一步转向 SMMU（B2/`UFS.c+2326`），**不要**写 tiny DXE |
| 出现 `SimpleFileSystem` 句柄 / `map -r` 列分区 | **UFS 全通**（历史首次） | 立即存证（拍照/录像 + `dh -p`） |
| **新** PC（不在 `UFSDxe+0x13224`） | dodge 专属路径引入新问题（PMIC/Clock 体系不同） | 记 PC + 模块名，回退 E0 |

### 3.4 若 E0/E1 都无字（结果 B/C）：只加一个变量的下一步

按**成本从低到高**，每次只动一个：

1. **A2-v0b（厂商 UFSDxe + cache 补丁 shim）** —— 验证「厂商件 vs dodge 件」：`fastboot boot /tmp/uefiboot-20261030/A2-v0b.img`；
2. **N2-v0b（纯 Mu + cache 补丁）** —— 隔离 UFSDxe 变量；
3. **CI 双跑构建**（B5 候选②，`uefi-samechip-tablet-display-20261028.md` §4.2 的 E-1）：需重编，**本轮不建议**；
4. 硬件串口（UART）/`UsbSerial`（上游建议的 ACM Gadget 属这一层）——**单独立项**，不是本轮。

---

## §4 判据与预期失败模式（含 `PITFALLS` 引用）

| # | 阶段 | 判据 | 预期失败模式 | 引用 |
|---|---|---|---|---|
| **F0** | 进 fastboot | `fastboot devices` 有序列号 | 刚硬复位 ~11 s 内发 `reboot2 bootloader` ⇒ 不进 fastboot 且 **USB 全不枚举**（无串口无 fastboot）⇒ 只能人工断电 | #368（+ #376「每发重过就绪门」） |
| **F1** | `fastboot boot` 交棒 | USB 掉线 = 真交棒 | `Booting OKAY` 但 fastboot 仍应答 = **没跳**：① header v3/v4 ② `kernel_addr` 不在 DRAM（`0x8000`） | #387 / #418 |
| **F2** | 交棒后 0–60 s | 屏上出字 或 至少 USB 重新枚举 | 全静默（无屏无 USB 无 fastboot）—— 10-26 实测就是此形态 | `uefi-n2-v0-attempt-20261026.md` §0 |
| **F3** | 回落 | ~80–90 s 后出现 `17ef:7f3d`（stock Android 槽 a） | 长时间不回落 / 循环重启 ⇒ 人工断电 + 保留现场 | #387 |
| **F4** | 回 Linux | `uname -v` 回到基线（m3v5 `#1 … Oct 30 11:22:59`） | **普通 `reboot`/暖复位会让 `fastboot boot` 镜像活下来**（看起来回了、实际还是测试内核） | #401/#406 |
| **F5** | 槽状态 | `slot-unbootable:b=no`、`current-slot=b` | 失败后 `b=yes` + `current-slot=a`（不修就下次莫名起 Android） | #387 |
| **F6** | 复位深度取证（回退后，可选） | `pstore`/`ramoops` 里的 `SYSTEM_RESET2 vendor` 行 | ramoops 在 POR 后不清零 ⇒ 行会被交错写坏，需抗噪锚点 + 与上一发归档比对；`panic=15` 会让失败内核 15 s 后自动重启（≈ 回落时间的一部分） | #374–#377；`PITFALLS/sessions/06-脚本工具.md`（panic=15 复发条目） |
| **F7** | 观察手段 | 录像 60 fps + 事后逐帧 | 字号小 + 刷屏快（10-05 已踩）⇒ 不录像等于白做 | `uefi-visibility-rebuild-20261028.md` §5.1 |

---

## §5 回退（每发都必须能回到可用 Linux）

```bash
# R1 失败后设备通常已自行回落到 stock Android 槽 a；从 Android 回 fastboot：
timeout -k 5 20 adb devices && timeout -k 5 20 adb reboot bootloader
timeout -k 5 20 sleep 12 && timeout -k 5 20 fastboot devices

# R2 把 active 槽修回 b（写 misc，不碰任何镜像分区）
timeout -k 5 20 fastboot set_active b
timeout -k 5 20 fastboot getvar slot-unbootable:b        # 期望 no
timeout -k 5 20 fastboot reboot

# R3 验证真的回了 baseline（关键：不能只看“开机了”）
sleep 30
timeout -k 5 20 ssh -o ConnectTimeout=8 root@192.168.7.1 'uname -v; findmnt -n / -o SOURCE,FSTYPE'
# 期望 uname -v = "#1 SMP PREEMPT Fri Oct 30 11:22:59"（m3v5）；根 = /dev/sda17 ext4 LABEL=linux17

# R4 假如 R2/R3 都不成（设备不回落 / 循环重启 / 黑屏）
#   → 人工长按电源 10 s；再不行进 EDL（PBL 9008）只读确认 GPT/分区仍在（不写）
#   → 真需重刷 boot_b：fastboot flash boot_b bootslot-b/boot_b-vk181-daily-signed-20261029.img
#      （sha b72866ef…d1e9；写前先 fastboot getvar current-slot 确认在 b，写后读回校验）
```

> **禁止**：本轮**不** `fastboot flash` 任何分区（除非 R4 已升级为“设备不可用”）；**不**动 `uefi_a`/`imagefv_a`/GPT。

---

## §6 「上机前必须人做的动作」清单（agent 做不了）

- [ ] **1. 人在设备旁**，能做长按电源 10 s 硬断电（本轮至少 2 发，失败时只能这样退出）。
- [ ] **2. 准备录像设备**（另一部手机/相机，**60 fps**），在按回车前开始录，直到回落完成——否则异常字块无可回溯。
- [ ] **3. 插线用短边数据口**（`a600000.usb`）；长边口只用于充电。当前 m3v5 是**双 role switch 未绑定**状态（`reports/m3v5-onboard-20261030.md` §1.2），**拔插后若 `usb0` 没起，需等 30 s 再试**。
- [ ] **4. 接受一个明确后果**：失败的那一发会让设备**回落到 stock Android 槽 a**（不是回 Linux），需要一次 `fastboot set_active b` + `reboot` 才回来（~1 min）。
- [ ] **5. 确认实验单元**：只用 **HA2EXB0E（U2, 16+512）**；U1 不参与；其它设备级实验（含 `fastboot`/EDL）本轮不并行（设备锁串行）。
- [ ] **6. 确认“可以搞坏一次启动”**：dodge 二进制自带警告 “These Patches are Outdated & Unstable!”；E1 可能出现**新的**崩溃点（不写盘，但会丢一次启动）。
- [ ] **7. 确认不需要本次拿到 UFS 结论**：本轮只看“能不能出字”；UFS 修不修得好看 E1 结果再定（可能仍需上游/串口）。

---

## §7 记录与收口（不做这步等于没做）

1. **每发一条 record**（无 record 不得写 verdict）：
   ```bash
   timeout -k 5 30 scripts/trial.sh record --label uefi-e0-20261030 \
     --image /tmp/uefiboot-20261030/E0-v0b.img --reset por \
     --verdict "J1=未达成; USB 全静默; ~85s 回落 stock a" \
     --note "kernel_addr=0x10008000; UFSDxe=00ae059f…; 录像=xxx.mp4"
   ```
   复位类型必填（`por`/`cold`/`warm`）；本轮失败样本**必须标真实复位类型**（#374/#376）。
2. **记录字段**（最少）：镜像路径 + **sha256** + `kernel_addr` + 槽前后状态 + `uname -v` 前后 + 屏幕现象（A/B/C）+ 回落耗时 + 所用 `UFSDxe` 的 sha（E1 特别重要，总账 B3）。
3. **结论写成三值**：`J1 达成 / 未达成 / 未上机`；**不得**写“已修复”。
4. **收口后回写**（父 agent）：`TASKS` §4 N1 / §5 Q25 的增量口径、`PITFALLS` 新坑（若有）、`INDEX` 指针；本执行单本身不改 SSOT。


