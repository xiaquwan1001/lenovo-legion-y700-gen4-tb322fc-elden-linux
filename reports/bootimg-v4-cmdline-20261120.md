# boot-img-cmdline.py 支持 boot image header v4（lane A / P0-4，主机侧，2026-11-20）

**结论（数字先说）**

| 项 | 结果 |
|---|---|
| v4 解析 | 原厂 `backup/official-rom-15.10.259/boot.img`（= `out/android-root-20261119/verify/boot.img`，symlink）解析通过：`header_version=4`、`header_size=1584`、`page_size=4096`、`kernel_size=36731392`、`ramdisk_size=0`、`signature_size=0`、**原 cmdline 为空** |
| v4 重打包 | 产物 `out/android-v3-bringup-20261120/boot-ttygs0-boot.img`，**100663296 B（与原件同大小）**，O_DIRECT sha256 = `0dad04f1d2f41fc2126eb2bda045adec8c8dce3ad95535442e53369dfc0280af` |
| 逐字节差异范围 | O_DIRECT 全文件比对：**唯一差异区间 [44, 57]，共 14 B**（= `console=ttyGS0`），其余 100663282 B 全等 |
| v2 路径回归 | 同一输入同一参数，`HEAD` 版 vs 新版产物 **byte identical**（sha `dcd6f1bf…`），`--verify` 输出 diff 为空 |
| walkthrough S5 | 已改：件在则用、缺则打印「S5 不可用（缺件）」并给造件命令；`bash -n` 通过；dry-run 两条分支都演练过 |
| **需上机** | `fastboot boot` 是否接受该件（v4 + AVB hash 失配 + vendor_boot cmdline 优先级）**未验证，不得宣称可用** |

---

## 1. v4 与 v2 的字段/布局差异

来源：AOSP `system/tools/mkbootimg/include/bootimg/bootimg.h`（原文留证：`logs/bootimg-v4-20261120-113911/bootimg.h`，取自
`android.googlesource.com/platform/system/tools/mkbootimg/+/refs/heads/main/include/bootimg/bootimg.h`），
并用原厂件实测复核。

**v2（`boot_img_hdr_v2`，1660 B）**

| offset | 字段 |
|---|---|
| 0x000 | magic[8] = `ANDROID!` |
| 0x008 | kernel_size / kernel_addr / ramdisk_size / ramdisk_addr / second_size / second_addr / tags_addr / page_size |
| 0x028 | header_version / os_version |
| 0x030 | name[16] |
| 0x040 | cmdline[**512**] |
| 0x240 | id[32]（sha1+pad） |
| 0x260 | extra_cmdline[1024] |
| 0x660 | recovery_dtbo_size(4) / recovery_dtbo_offset(u64) / header_size(4) |
| 0x670 | dtb_size(4) / dtb_addr(u64) |
| 0x67C | —（v2 无） |

**v3/v4（`boot_img_hdr_v3` 1580 B，`boot_img_hdr_v4` = v3 + 4 B）**

| offset | 字段 | 与 v2 的关系 |
|---|---|---|
| 0x000 | magic[8] | 同 |
| 0x008 | kernel_size(4) | 同 |
| 0x00C | **ramdisk_size(4)** | v2 这里是 kernel_addr |
| 0x010 | **os_version(4)** | v2 这里是 ramdisk_size |
| 0x014 | **header_size(4)**（v4 实测 = **1584**） | v2 这里是 ramdisk_addr |
| 0x018 | reserved[4]（16 B，原厂实测全 0） | v2 这里是 second/tags/page 等 |
| 0x028 | **header_version(4)** | **与 v2 同位（40）** ⇒ 可用同一处判断版本 |
| 0x02C | **cmdline[1536]**（= BOOT_ARGS_SIZE 512 + BOOT_EXTRA_ARGS_SIZE 1024） | v2 的 cmdline 512 + id 32 + extra_cmdline 1024 被合并成一段 1536 |
| — | **没有** kernel_addr / ramdisk_addr / second_size / second_addr / tags_addr / dtb_* / recovery_dtbo / id | v3+ 全部删除（地址来自 vendor_boot / DTB） |
| 0x62C (1580) | **signature_size(4)**（v4 独有；原厂实测 = 0） | v2 无此字段 |

**镜像布局**

* v2：`header(1660, 补齐到 page) | kernel | ramdisk | second | recovery_dtbo | dtb`
* v3/v4：`header(补齐到 **4096**) | kernel | ramdisk | boot signature(signature_size)`
  —— **v4 的 bootconfig 在 `vendor_boot.img`，不在 `boot.img`**（bootimg.h 注释原文见 §6）。
  原厂件因此是「4096 头 + 36731392 B kernel（补齐到 36732928）」，boot image **本身在 0x2309000 = 36737024 结束**；
  之后紧跟 3 个 `AVB0` vbmeta（见 §5）。

## 2. 代码改动点（`scripts/boot-img-cmdline.py`，367 行）

| 行号 | 改动 |
|---|---|
| 20–24 | 文档：新增 `--dump` 用法与 v3/v4 支持说明、AVB/bootconfig 边界 |
| 49–61 | 常量：`HEADER_V3_SIZE=1580`、`HEADER_V4_SIZE=1584`、`BOOT_V3V4_PAGE=4096`、`V3V4_CMDLINE_OFF=44`、`V3V4_CMDLINE_LEN=1536`、`V4_SIGNATURE_SIZE_OFF=1580`、`HEADER_VERSION_OFF=40` |
| 64–66 | `_pages()` 辅助 |
| 78–118 | **新增 `parse_v3v4()`**：v3/v4 头解析 + kernel/ramdisk/boot signature/尾部不透明区切分（tail = VBmeta 链等） |
| 124–126 | `parse()` 入口：`header_version = u32@40`，`>=3` 直接转 `parse_v3v4()`（**v0/v1/v2 的既有代码一字未改**，仍在 128 行之后） |
| 167 | v2 返回 dict 追加 `header_version=`（供 `--dump`/摘要打印，不影响 v2 打包路径） |
| 171–196 | `verify()`：v3/v4 分支要求**逐字节全等**（v3/v4 无 id 字段可跳过）；v2 分支保持原逻辑（跳过 576..608 id） |
| 198–218 | **新增 `repack_v3v4()`**：整文件拷贝 + 只写 `[44, 1580)` 的 cmdline 窗口（NUL 补齐），**后置条件硬校验**：总大小不变、窗口外逐字节相同 |
| 221–224 | `repack()`：`v3v4` 走 `repack_v3v4()`，否则原 `mkbootimg.py` 调用（v2 路径零改动） |
| 253–289 | **新增 `dump_header()`**：`name=value` 逐行表（供前后 diff） |
| 291–293 | 新增 `--dump` 选项（`304` 起为 `dump_header()` 调用） |
| 300–316 | `--show` 增加 `header_version`（311 行）/ `signature` / `tail(vbmeta等)` 行（v2 输出其余行不变，只多一行 `header_version : 2`） |
| 336–356 | 自检段（`328` 为 cmdline 长度上限按版本切换）：v3/v4 改为核 `kernel/ramdisk/signature/tail` + `payload_rest`（窗口外 100661716 B）+ `header_fields` + `file_size`；v2 仍核 `kernel/ramdisk/dtb/second/recovery_dtbo` |

**为什么 v4 不做「重排布局」式重打包**：v4 `boot.img` 没有任何「总长」字段（bootconfig 在 vendor_boot），
原厂件在 boot signature 之后还挂 VBmeta 链 ⇒ 重排必须靠猜尾部边界。唯一改动就是 header 的 1536 B cmdline 窗口，
等长原地替换既能保证「signature 段 / bootconfig / 尾部原样」，也能逐字节自证。

## 3. 前后对照表（原厂件 → 产物）

命令：

```bash
timeout -k 5 120 python3 scripts/boot-img-cmdline.py out/android-root-20261119/verify/boot.img --dump > /tmp/before.txt
timeout -k 5 120 python3 scripts/boot-img-cmdline.py out/android-v3-bringup-20261120/boot-ttygs0-boot.img --dump > /tmp/after.txt
diff -u /tmp/before.txt /tmp/after.txt
```

| 字段 | 原件 | 产物 | 判定 |
|---|---|---|---|
| file_size | 100663296 | 100663296 | SAME |
| magic | ANDROID! | ANDROID! | SAME |
| header_version | 4 | 4 | SAME |
| header_size | 1584 | 1584 | SAME |
| page_size | 4096 | 4096 | SAME |
| name | '' | '' | SAME |
| **cmdline** | **''（空，0 B）** | **'console=ttyGS0'（14 B）** | **唯一变更** |
| extra_cmdline | '' | '' | SAME（v3+ 无此字段） |
| os_version | 0x0 | 0x0 | SAME |
| kernel_size | 36731392 | 36731392 | SAME |
| kernel_sha256 | 55d1056dd3d11e8c… | 55d1056dd3d11e8c… | SAME |
| ramdisk_size / sha | 0 / e3b0c442…（空） | 0 / e3b0c442… | SAME |
| signature_size / sha | 0 / e3b0c442…（空） | 0 / e3b0c442… | SAME |
| **tail_size / sha**（VBmeta 链等） | 63926272 / `5d9d572f368da1ea…` | 63926272 / `5d9d572f368da1ea…` | SAME |
| payload_rest（窗口外全文件） | — | sha `3e4f8a889a670b97…`（100661716 B） | 与原件 SAME |
| file sha256（O_DIRECT） | `b428a31dadc5db3f…98f20` | `0dad04f1d2f41fc2…0af` | 有意不同（cmdline） |

结构化复核（不依赖本脚本的独立实现）：`logs/bootimg-v4-20261120-113911/step4-odirect-compare.log`

```
A 100663296 B sha256 b428a31dadc5db3f91620c1f4114f5ee7702e34e0789ed9bf84a878a49898f20  .../verify/boot.img
B 100663296 B sha256 0dad04f1d2f41fc2126eb2bda045adec8c8dce3ad95535442e53369dfc0280af  .../boot-ttygs0-boot.img
DIFF ranges: 1
  [44, 57]  (14 B)
union: [44, 57]  (14 B)
```

（O_DIRECT：`python3 logs/bootimg-v4-20261120-113911/odirect_compare.py A B`，缓冲全部 `mmap` 页对齐、`O_RDONLY|O_DIRECT`；
交叉验证 `dd bs=1M iflag=direct | sha256sum` 得同一 sha。）

## 4. v2 回归（逐字节不变）

```bash
git show HEAD:scripts/boot-img-cmdline.py > /tmp/bootimg-old/boot-img-cmdline.py
cp scripts/mkbootimg.py /tmp/bootimg-old/
timeout -k 5 300 python3 /tmp/bootimg-old/boot-img-cmdline.py out/boot-elden-vk192.img --append 'efi=noruntime' -o /tmp/v2-old.img
timeout -k 5 300 python3      scripts/boot-img-cmdline.py out/boot-elden-vk192.img --append 'efi=noruntime' -o /tmp/v2-new.img
cmp /tmp/v2-old.img /tmp/v2-new.img     # ⇒ 无输出（IDENTICAL）
```

实测（`logs/bootimg-v4-20261120-113911/step2-v2-regression.log`）：两产物同 85815296 B、sha `dcd6f1bf18292627…`;
`cmp` = IDENTICAL；`--verify` 两次输出 diff 为空。

## 5. AVB 断言探针（`fastboot boot` 风险的量化）

`logs/bootimg-v4-20261120-113911/avb_probe.py`（hash descriptor 解析要点：`image_size(u64)` + `hash_algorithm` 是
**char[32]** + plen/salt_len/digest_len/flags(u32×4) + reserved[60]）：

| vbmeta @ | 描述符 | 覆盖区间 | 原件 | 产物 |
|---|---|---|---|---|
| 0x2309000 | part=`boot`, image_size=36737024 | `[0, 0x2309000)` | MATCH | **MISMATCH** |
| 0x23098c0 | part=`generic_kernel`, image_size=36731392 | `[4096, 4096+36731392)`（kernel 载荷） | MATCH | MATCH（kernel 未动） |
| 0x230d000 | part=`boot`, image_size=36753408（AVB footer 指向它） | `[0, 0x230d000)` | MATCH | **MISMATCH** |

⇒ cmdline 改动必然让 boot 的两个 hash descriptor 失配；vbmeta 是 OEM 私钥签名，**本仓不能重签**（也不应去绕过）。
所以：该产物**只用于 `fastboot boot`（零写盘）**，能否被接受取决于设备解锁/verity 状态 —— 见 §7 需上机项。

## 6. vendor_boot 侧的 cmdline（v4 的真 cmdline 常常在这里）

只读探测 `backup/official-rom-15.10.259/vendor_boot.img`（同 96 MiB，`VNDRBOOT`，header_version=4，page_size=4096）：

```
cmdline = video=vfb:640x400,bpp=32,memsize=3072000 nosoftlockup console=ttynull \
          qcom_geni_serial.con_enabled=0 bootconfig
bootconfig(232 B) 尾部含 androidboot.serialconsole=0
页面布局：header 4096 | vendor_ramdisk 8633118 @4096 | dtb 6505470 @8638464 |
          ramdisk_table 108 @15147008 | bootconfig 232 @15151104
```

⇒ 即使 boot.img 侧追加了 `console=ttyGS0`，若 ABL 只取 vendor_boot 的 cmdline（v4 常见行为），则本件不产生串口日志。
这条与 AVB 一起，是本件的两个**需上机**不确定点。

## 7. 复现命令（全部主机侧，零设备写操作）

```bash
cd ~/y700-elden
SRC=out/android-root-20261119/verify/boot.img          # = backup/official-rom-15.10.259/boot.img（只读）
OUT=out/android-v3-bringup-20261120/boot-ttygs0-boot.img

# 1) 看原 cmdline + 完整字段表
timeout -k 5 120 python3 scripts/boot-img-cmdline.py "$SRC" --show
timeout -k 5 120 python3 scripts/boot-img-cmdline.py "$SRC" --dump

# 2) 结构往返自检（v4：逐字节全等）
timeout -k 5 120 python3 scripts/boot-img-cmdline.py "$SRC" --verify

# 3) 造件（append 单个 token）
timeout -k 5 300 python3 scripts/boot-img-cmdline.py "$SRC" --append 'console=ttyGS0' -o "$OUT"

# 4) 产物复核：dump 必须含新 token 且其余字段与原件相同；总大小相同
timeout -k 5 120 python3 scripts/boot-img-cmdline.py "$OUT" --dump
timeout -k 5 120 python3 scripts/boot-img-cmdline.py "$OUT" --verify
stat -c%s "$SRC" "$OUT"          # ⇒ 100663296 / 100663296

# 5) O_DIRECT 逐字节比对 + sha（不用 buffered sha 单独下结论）
L=logs/bootimg-v4-20261120-113911
timeout -k 5 600 python3 $L/odirect_compare.py "$SRC" "$OUT"        # ⇒ DIFF ranges: 1 / [44,57]
timeout -k 5 600 python3 $L/odirect_compare.py --sha "$SRC" "$OUT"
timeout -k 5 300 dd if="$OUT" bs=1M iflag=direct 2>/dev/null | sha256sum

# 6) AVB 断言
timeout -k 5 300 python3 $L/avb_probe.py "$SRC"
timeout -k 5 300 python3 $L/avb_probe.py "$OUT"

# 7) walkthrough S5（dry-run，只打印）
timeout -k 10 300 bash scripts/android-v3-bringup-walkthrough.sh --dry-run --step S5 --no-sha
timeout -k 5 60 bash -n scripts/android-v3-bringup-walkthrough.sh
```

**件登记（写入 `reports/artifacts/android-v3-bringup-20261120/pieces-inventory.txt` 同级口径）**

| 文件 | 字节 | sha256（O_DIRECT） | 说明 |
|---|---|---|---|
| `out/android-v3-bringup-20261120/boot-ttygs0-boot.img` | 100663296 | `0dad04f1d2f41fc2126eb2bda045adec8c8dce3ad95535442e53369dfc0280af` | v4 原厂 boot + cmdline `console=ttyGS0`，**仅 `fastboot boot` 用** |

## 8. walkthrough 脚本 S5 段改动（`scripts/android-v3-bringup-walkthrough.sh`）

| 行号 | 改动 |
|---|---|
| 12–14 | 头部注释：S5 从「缺 v4 改写器」改为「v4 已支持，件由 S5 自己造/核」，指向本报告 |
| 55–56 | `ROM`/`ART` 改 `${VAR:-default}`（便于演练缺件分支，默认行为不变） |
| 655–704 | S5 重写：件在 ⇒ `sha_direct` 报 sha → `--show` 抓 cmdline 断言 `console=ttyGS0` → `--verify` → `fastboot boot` → 抓 ttyACM0；件缺 ⇒ **`WARN S5 不可用（缺件）`** + 解释（v4 布局/等长改写）+ 造件命令 + 「不造件就摘掉 S5」；并把 AVB 失配与 vendor_boot cmdline 两个风险显式打印 |
| 715 | 计划行 `S5 日志通道(缺件)` → `S5 日志通道(ttyGS0 件)` |

验证输出：`bash -n` rc=0；dry-run 件在位分支（`logs/.../step7…`）与缺件分支（`ART=/tmp/art-empty`，`logs/.../step8…`）均按预期。

## 9. 需上机（本报告不宣称可用）

1. `fastboot -s <SN> boot out/android-v3-bringup-20261120/boot-ttygs0-boot.img` 是否返回 `OKAY`
   —— v4 header 改写 + 两个 boot hash descriptor 失配，能否被接受的唯一判据是实测。
2. 若 OKAY：串口是否出现内核 log（`console=ttyGS0` 是否生效 vs vendor_boot 的 `console=ttynull` / `qcom_geni_serial.con_enabled=0`）。
3. 失败时的备用路径（不在本轮实施）：改 `vendor_boot.img` 的 cmdline、或走 bootconfig（`androidboot.*`），
   或回到 pstoredump 通道（walkthrough `pstore_triage`）。

## 10. 留证清单

`logs/bootimg-v4-20261120-113911/`：

| 文件 | 内容 |
|---|---|
| `step1-dump-verify.log` | v4 `--dump`/`--verify` + v2 `--verify`/`--show` |
| `step2-v2-regression.log` | HEAD 版 vs 新版 v2 产物 `cmp` IDENTICAL + `--verify` diff 空 |
| `step3-v4-append.log` | v4 `--append 'console=ttyGS0'` 自证 + 产物 dump/verify |
| `step4-odirect-compare.log` | O_DIRECT 逐字节比对（差异仅 `[44,57]`）+ 双实现 sha |
| `step5-avb-probe.log` | 三个 vbmeta hash descriptor 的前后 MATCH/MISMATCH |
| `step6-walkthrough-syntax.log` | `bash -n` + `--help` 头部 |
| `step7-walkthrough-dryrun-S5.log` | S5 dry-run（件在位分支） |
| `step8-walkthrough-missing-piece.log` | S5 缺件分支演练（`ART=/tmp/art-empty`） |
| `step9-determinism.log` | 同源同参数重跑 → 产物 sha 与已落盘件 `IDENTICAL`（确定性） |
| `step10-final-state.log` | 源件未改动（sha `b428a31d…` / mtime 2026-06-18）+ `git status` |
| `bootimg.h` | AOSP bootimg.h 原文（字段布局引用源，sha256 见 `sha256sum` 输出） |
| `odirect_compare.py` / `avb_probe.py` | 上面两个独立复核工具（可复跑） |
