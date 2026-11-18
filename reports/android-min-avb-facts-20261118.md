# 精简安卓全量包的 AVB / 虚拟 A/B / 去预装 事实与风险（S2）

- 日期：2026-11-18（主机侧，**零设备操作**：无 adb / fastboot / EDL / 写分区）
- 设备现态：U2 `HA2EXB0E`，原厂 Android 16 完整启动（`ZUXOS_1.5.10.259_260611_PRC`），slot `_a`，`verifiedbootstate=orange`
- 输入包：`backup/official-rom-15.10.259/`（16 G，第三方转包的原厂 259）
- 本报告只写 `reports/`、`scripts/`（新文件）、`out/android-min-avb-20261118/`；未改 SSOT、未 commit
- 标注口径：**[实测]** = 本机命令/文件/设备证据；**[机制]** = 上游源码或本项目已记录机理；**[推断]** = 由上面两者推出、尚未上机
- **并列 lane 交叉引用**：`reports/android-super-format-20261118.md`（S1）已把 `super_1..8` 的封装格式/空洞/`lpmake` 往返验证做穷；本报告与之**不重叠**（本报告 = AVB 链 / 虚拟 A-B / 去预装边界），只在两处交叉：① 它已把 `lpmake/lpunpack` 编好放在 `~/bin/`（本报告 Q5 据此修正）；② 它的「只删预装可释放 6.53 GiB」是**逻辑字节**，本报告 §4.4 的 **6.24 GiB** 是 `debugfs` 删完后 ext4 **实回收块数**（两者口径差 1.4% 去重 + 它多算了 `/system/etc/bgmusic`）

---

## 0. 一页结论（先数字）

| # | 结论 | 等级 |
|---|---|---|
| 1 | 包内 super 的分区表**能完整解出**：LP geometry/metadata 三份 checksum 全对；14 个逻辑分区（7 个基础 `*_a` + 7 个 `*-cow`），合计 **14.905 GiB**，落在 22528 MiB 的 `super` 里 | 实测 |
| 2 | **3 份 LP metadata 互不相同**：slot0 = `_a` 代 + COW、slot1 = `_b` 代 + COW、slot2 = 出厂代（只有 `_a`，`_b` 全 0 长度）。init 选哪一份由 `ro.boot.slot_suffix` 决定（a→slot0，b→slot1） | 实测 + 机制 |
| 3 | `/metadata`（64 MiB，f2fs）在包里**基本是空的**：没有 `otapackage/`、没有 snapshot 状态 ⇒ 只要不改 GPT/不刷带 pending OTA 的件，就**不需要**先清 misc/`bootctl` | 实测 |
| 4 | 现在跑 Android 的是 a 槽，`vbmeta_a` = 包内 `vbmeta.img` 逐字节（sha `55929c15…`，key `8fcb864f`，**Flags 0**，descriptor 覆盖 boot/recovery/vbmeta_system 链 + dtbo/init_boot/vendor_boot 的 hash + odm/vendor/vendor_dlkm/system_dlkm 的 hashtree） | 实测 |
| 5 | **本机在 orange（解锁）态下 ABL 不执行校验结果**：同一台机、`vbmeta_a` 保持原厂 Flags 0（描述符指向 `8fcb864f` 的 boot），而 `boot_a` 换成用 **`1e54e86e` 这把另一把钥匙**签的件，照样开机进 Linux（29.2 s）。⇒ 「只重签 vbmeta_a、boot 签名要不要一致」的答案是**不必**（本项目现役 b 槽更是长期如此：`vbmeta_b`=`fc1e3b33`+Flags 3，`boot_b`=`1e54e86e`） | 实测 |
| 6 | Flags 语义（AOSP 原文）：bit0 `HASHTREE_DISABLED` = 关掉 dm-verity；bit1 `VERIFICATION_DISABLED` = **连描述符都不解析**。`--flags 3` = 两者都关 ⇒ ABL 不会看 boot/dtbo/hashtree 任何描述符 | 机制 |
| 7 | 去预装的**实测回收量**：在 system 副本上删 `/system/preinstall`（联想预装 3.27 GiB 逻辑量）+ `/system/etc/AI`（qwen 模型 2.8 GiB 逻辑量）⇒ ext4 实回收 **6 391.89 MiB = 6.24 GiB**（fs 从 99.7% 满 → 48% 占用），e2fsck 复查 0 错误 | 实测 |
| 8 | 原厂各分区都是「刚好塞满」构建（free blocks 全部 <0.4%），且带 `shared_blocks`（去重）特征 ⇒ **`resize2fs -M` 收不动**（实测只从 2 949 079 → 2 687 555 块，因为共享块不能搬）；要真缩必须 **mkfs + 重建** | 实测 |
| 9 | 包内 `gpt_main4.bin`（出厂 GPT）把 **`boot_b` 标成 `UNBOOTABLE`**（attribute byte6=0xf3；`boot_a`=0x77 ACTIVE+SUCCESSFUL）。刷全量包会**复位槽属性** ⇒ 现役 **b 槽 Linux 方案会被清掉** | 实测 |
| 10 | 「缩 super」有两种口径，**别混**：**(a) 只让包小** = 不改 LP metadata，把逻辑分区重打包成 sparse/只写有数据的段（包体从 14.5 GiB → ~4–5 GiB，**零 GPT 风险**）；**(b) 让设备上的 super 真变小** = 改 LP metadata + 动 LUN0 GPT 并把 `vbmeta_system_a/b`、`metadata`、`rawdump`、`pstoredump`、`userdata` 全部前移（**要动 userdata ⇒ 等于换机重装**，且与本仓 `GPT-MINIMAL-DESIGN` P2「删 super 给 Linux」冲突） | 实测 + 推断 |
| 11 | **slot0 与 slot1 的 extent 完全重合**（`product_a` 与 `product_b` 都是 `1695776@6144`，其余同理）⇒ 包里的 b 槽**没有独立数据**，只是同一批物理 extent 的“改名副本” | 实测 |
| 12 | **解包管线已自证**：拿 `odm` 走 `add_hashtree_footer` 重建，得到的 **root digest 与原厂描述符逐字节相同**（`3bac79e4…`）⇒ extent 映射无误、avbtool 用法无误；`vbmeta_a-flags1.img`（路线 A）已生成并 `verify_image` 通过 | 实测 |

---

## 1. 复现方法（本轮新增脚本，全部只读源包）

| 脚本 | 作用 | 典型命令 |
|---|---|---|
| `scripts/android-lpdump.py` | 解析分段 super：LP geometry / 3 份 metadata / 分区表 / extents / checksum / 文件系统探测 / 按分区还原镜像 | `python3 scripts/android-lpdump.py --verify --probe`；`--slot 1`；`--extract system_a --outdir out/android-min-avb-20261118/parts` |
| `scripts/android-rom-segassemble.py` | 把线刷 XML 里一个分区被拆成多段的情况拼回整镜像（含空洞按 0） | `python3 scripts/android-rom-segassemble.py --label metadata --out out/android-min-avb-20261118/metadata.img` |
| `scripts/android-img-inventory.py` | 用 `debugfs` 只读遍历 ext4 分区镜像，出 TSV 清单 + 目录/文件体积 Top（不需 root/loop） | `python3 scripts/android-img-inventory.py --img <img> --out <tsv> --summary` |
| `scripts/android-ext4-slim-test.py` | 在**副本**上按清单删子树（`debugfs -w`）+ `e2fsck -fy` 回收，量真实 freed blocks | `python3 scripts/android-ext4-slim-test.py --img <副本> --inv <tsv> --drop /system/preinstall /system/etc/AI` |

产物落点：`out/android-min-avb-20261118/`（`lpdump.txt`、`parts/*.img` 7 个基础分区共 **15.6 GB ≈ 14.5 GiB**、`inv-*.tsv`、`slim-test.txt`、`avb-facts-vbmeta.txt`、`metadata.img`、`vbmeta_a-flags1.img`）。

**关键实现坑（已踩，写在这里防复发）**
1. 段的 `start_sector` 是 super 的**绝对 LBA**（本包起点 = 90504 = GPT 里 `super.first_lba`），换算 super 内偏移要减起点；段与段之间**有空洞**，禁止 `cat` 拼接。
2. LP extent 的 `num_sectors/target_data` 单位是**底层 512 B 扇区**，不是 geometry 的 `logical_block_size=4096`。交叉验证：`product_a` 首 extent `target_data=6144` ⇒ 字节 3 145 728 = `super_3.img` 在 super 内的起点，而其 +1024 正是 ext4 superblock。用 4096 算会得到 88 GiB 的 `system`（荒谬值）。
3. LP 布局（本包实测，与 liblp 常量一致）：`0..4095` reserved、`4096` primary geometry、`8192` backup geometry、`12288` 起 3 份 primary metadata（每份 65536）、`208896` 起 3 份 backup metadata，合计 `405504` = 99×4096 = `super_1.img` 全长。三份 checksum（geom/header/tables）**全部校验通过**。
4. 已知事实里「metadata checksum 验不过」的原因是清零长度取错：header 里 checksum 是 **32 B 字段**（偏移 12..44），`sha256(zeros 覆盖该 32 B)` 即命中（`header_checksum_ok=True`）。
5. ext4 判定：superblock 在 +1024，`s_magic` 在 **+1080**，字节序 `53 ef`（`0xEF53`）。

---

## 2. A. AVB 链条

### 2.1 事实表（全部 `avbtool info_image` 实测；原件 = `backup/official-rom-15.10.259/`）

| 镜像 | 大小 | 公钥 sha1 | Flags | Rollback (loc) | 描述符（按类） |
|---|---|---|---|---|---|
| `vbmeta.img`（→`vbmeta_a`） | 64 KiB 分区 | `8fcb864f…` Lenovo | **0** | 0 (loc 0) | **链**：boot→loc3、recovery→loc1、vbmeta_system→loc2（三者 key 同为 `8fcb864f`）；**hash**：dtbo(23 348 092 B)、init_boot(2 465 792 B)、vendor_boot(15 155 200 B)；**hashtree**：odm、system_dlkm、vendor、vendor_dlkm；+14 条原厂 prop |
| `vbmeta_system.img`（→`vbmeta_system_a`） | 64 KiB 分区 | `8fcb864f…` | **0** | **1 777 939 200** (loc 0) | **hash**：pvmfw(774 144 B)；**hashtree**：product(1 024 667 648 B)、system(**12 079 427 584 B**)、system_ext(588 845 056 B)；+12 条原厂 prop |
| `bootslot-b/vbmeta_b`（设备在役，=`backup/vbmeta_b-20261110.img`） | 64 KiB | **`fc1e3b33…`（自签旧钥）** | **3** | 0 | **链**：boot→loc3（key `fc1e3b33`）；**hash**：dtbo |
| `bootslot-b/boot_b.img`（在役 Linux 件） | 96 MiB 分区 | **`1e54e86e…`（自签新钥 `bootslot-b/avb.key`）** | 0 | 0 | 只有自身 hash footer |

关键推论（都已在设备上发生过）：
- **[实测]** `vbmeta_b` 的链指向旧钥 `fc1e3b33`，而 `boot_b` 用新钥 `1e54e86e` 签名（钥不一致），设备仍每日常规启动 ⇒ **orange 态下链级 key mismatch 被容忍**（logfs 里的 `avb_slot_verify.c:913 ERROR: vbmeta_b: Public key used to sign data rejected` 就是这条，之后照常 `BootLinux`）。
  - ⚠️ **文档漂移**：`bootslot-b/README.md` 仍写「公钥 sha1 `fc1e3b33…`」，而现役 `avb.key` 的公钥是 **`1e54e86e…`**（`avbtool extract_public_key` 实测；`avb.key` mtime 2026-10-18 08:33）。且 `bootslot-b/vbmeta_b_flags3.img` / `vbmeta_b_flags0.img` **已不在仓里**（只剩 `backup/vbmeta_b-20261110.img`）。本轮未改 README（SSOT 只读），只在此登记。
- **[实测]** 2026-11-10 的对照实验（`reports/artifacts/uefi-flashed-20261110-174233-ctrl-vbmeta-a-orig-flags0/`）：`vbmeta_a` 刷回**包内原厂 vbmeta.img 逐字节**（sha `55929c15…`，Flags 0，链指向 `8fcb864f`），`boot_a` = `out/bootmark-a-test.img`（`1e54e86e` 签名），结果 **`VERDICT=RECOVERED T=29.2 s`** 起 Linux，cmdline 带 `elden_bootmark=a` 证明真的从 `boot_a` 起。
  ⇒ **解锁态下「vbmeta_a 是否与 boot_a 同钥」「hash 是否匹配」都不影响 ABL 交棒。**
- **[实测]** 同一轮里 `vbmeta_a=Flags3` 的那一发是 `NO_RECOVERY`（`…161412-vbmeta-a-flags3/verdict.txt`），但当时 `dtbo_a` 还是原厂 Android DTBO —— 该失败的归因是 **`dtbo_a` overlay**（`reports/uefi-dtbo-a-rootcause-20261110.md`），**不是** Flags3。判读时别把这两件事混起来。

### 2.2 ABL 在 orange 下到底检查什么（上游源码 + 本机证据对齐）

**AOSP/libavb（`external/avb/libavb/avb_vbmeta_image.h`，原文）**
```
AVB_VBMETA_IMAGE_FLAGS_HASHTREE_DISABLED     = (1 << 0)   /* hashtree image verification will be disabled */
AVB_VBMETA_IMAGE_FLAGS_VERIFICATION_DISABLED = (1 << 1)   /* verification will be disabled and descriptors will not be parsed */
```
- bit1 置位后，`avb_slot_verify.c` 在**验完 vbmeta 自身**（header hash + 签名 + key，可选 rollback）后直接跳到 `load_requested_partitions()`，**整张描述符表不解析**：链不递归、hash/hashtree 不比对、连 `kernel_cmdline` 描述符都不生效。[机制]
- 校验失败能否继续，取决于**引导器是否传 `AVB_SLOT_VERIFY_FLAGS_ALLOW_VERIFICATION_ERROR`**（`avb_slot_verify.c`：`if (!allow_verification_error) goto out;`）。Qualcomm ABL 在**解锁**时就是这么做的。[机制 + 本机证据：orange 且 key 被拒仍启动]
- HLOS 侧（`system/core/fs_mgr/libfs_avb/fs_avb.cpp`，原文）：`IsAvbPermissive()` = `IsDeviceUnlocked()`（除非 `/metadata/avb_enforce` 存在）；permissive 时 `allow_verification_error=true`、**rollback 保护关闭**（`rollback_protection = !allow_verification_error`），并且：
  - `verification_disabled`（bit1）⇒ 状态 `kVerificationDisabled`；
  - `hashtree_disabled`（bit0，**只看顶层 vbmeta**）⇒ 状态 `kHashtreeDisabled`；
  - 两者都会让 `SetUpAvbHashtree()` 直接返回 `kDisabled` ⇒ **init 不建 dm-verity 设备**。
- **[实测]** 设备当前 Android 槽 cmdline（`reports/artifacts/uefi-edl-read-20261101/android-after/props.txt`、`…174233…/post.txt`）：`androidboot.veritymode=eio`（不是 `disabled`）、`verifiedbootstate=orange`、`device_state=unlocked`、`vbmeta.avb_version=1.2`。
  ⇒ **默认状态下 Android 的 dm-verity 是「eio 模式开着」的**：只要用在 system 上，root digest 不匹配就会读 I/O 出错。

**由此得到 A.1 的确定答案**：
1. 只要把顶层 `vbmeta_a` 的 flags 设成 **1 或 3**，ABL 就**不要求 `boot_a` 与任何 key 一致**（bit1 连描述符都不看；bit0 时 boot 的 hash 描述符仍在，但解锁态失败也只是记录）。**[机制 + 实测（现役 b 槽、11-10 实验 F）]**
2. **不改 flags、只把 super 内容换掉**时：ABL 仍会解析描述符，但在 orange 下**仍会交棒**（实测 F 的等价情形）；真正卡住的是**后面的 init**——dm-verity 按旧 root digest 建起来，数据一变就 `eio` 失败（**[推断]**，需上机，判据见 §6）。
3. 因此**两条安全路线**（都可选）：
   - **路线 A（推荐，最小改动）**：顶层 `vbmeta_a` 只置 **bit0（`--flags 1`）**，描述符、props、链全部**照抄原厂**，改用我们的钥匙重签。⇒ dm-verity 关闭、boot/dtbo 仍被校验；**`vbmeta_system_a` 完全不用动**（改了 super 内容也不影响）。
   - **路线 B（自洽链）**：把每个改过的分区重打 hashtree、重建 `vbmeta_system_a` 与顶层 `vbmeta_a`（Flags 0），使整条链严格自洽（锁定/绿色态也能用）。成本高（见 2.3），只有在需要「回锁」或「不想关 verity」时才值得。
   - **路线 C（现役 b 槽形态）**：`--flags 3`。等价于「AVB 全关」，适合 Android 槽也彻底自签/自管的一体化镜像（Linux 槽已在用）。

### 2.3 可直接复制的精确命令

**路线 A：只关 dm-verity（Flags=1），其余照抄原厂**
```bash
cd /home/xuqianhui/y700-elden
python3 tools/avbtool.py make_vbmeta_image \
  --output out/android-min-avb-20261118/vbmeta_a-flags1.img \
  --key bootslot-b/avb.key --algorithm SHA256_RSA4096 \
  --include_descriptors_from_image backup/official-rom-15.10.259/vbmeta.img \
  --flags 1 --rollback_index 0 --rollback_index_location 0 \
  --padding_size 65536
# 自检（必须两项都过）
python3 tools/avbtool.py info_image   --image out/android-min-avb-20261118/vbmeta_a-flags1.img | head -8
python3 tools/avbtool.py verify_image --image out/android-min-avb-20261118/vbmeta_a-flags1.img --key bootslot-b/avb.key
sha256sum out/android-min-avb-20261118/vbmeta_a-flags1.img
```
逐项解释：
- `--include_descriptors_from_image <原厂 vbmeta.img>`：把原厂的 3 条链 + 3 条 hash + 4 条 hashtree + 14 条 prop **逐字节照抄**，避免手抄漂移（这是 A 路线风险最低的写法）。
- `--flags 1`：只置 `HASHTREE_DISABLED`。**不要**同时用 `--set_hashtree_disabled_flag`（那是「在已有 flags 上或位」的写法，和 `--flags` 混用容易互相覆盖；见 §5 的社区条目）。
- `--rollback_index 0 --rollback_index_location 0`：与原件一致（原厂 vbmeta 顶层就是 0/0）。**不许**给比 NVRAM 里存的值更小的数——解锁态 fs_mgr 会跳过 rollback 检查，但锁定态 ABL 会直接 `Image rollback index is less than the stored rollback index` 拒掉。[机制]
- `--padding_size 65536`：`vbmeta_a` 分区是 64 KiB（GPT：137946..137961，4096 B 扇区），不 padding 也能刷，但 padding 后尺寸与原件一致、回退替换不易踩坑。
- 回退件：`backup/official-rom-15.10.259/vbmeta.img`（= `backup/vbmeta_a-orig-20261110.img`，两份 sha 相同 `55929c15…`），直接 `fastboot flash vbmeta_a` 即复原。

**路线 C：Flags=3（AVB 全关）**
```bash
python3 tools/avbtool.py make_vbmeta_image \
  --output out/android-min-avb-20261118/vbmeta_a-flags3.img \
  --key bootslot-b/avb.key --algorithm SHA256_RSA4096 \
  --include_descriptors_from_image backup/official-rom-15.10.259/vbmeta.img \
  --flags 3 --rollback_index 0 --rollback_index_location 0 --padding_size 65536
```
（本仓已有同类历史件 `out/vbmeta-a-flags3/vbmeta_a-flags3-copy-b-20261110.img`：key `fc1e3b33`、Flags 3、只带 boot 链——那是 11-10 的实验件，不要直接当正式件。）

**路线 B 第一步：给改过的逻辑分区重打 hashtree**（salt 必须与原厂一致，否则等于换了一套树；本处 salt 值全部实测自原厂描述符）
```bash
SYS_SALT=fef1e5a94916d343af6f0b41f2bf621f1daeda279040144513668bc1da74e5e0   # system/system_ext/product 共用
DLK_SALT=0c1bb1d3b3451fa25c0adc08b9c182de4ef0ce661ac9848cf227e254d426d40c   # odm/vendor/vendor_dlkm/system_dlkm 共用
PVM_SALT=e55de217e631be725e9aaf98fb7a03589d466fe311aa13bb54d98a28a4945df3   # dtbo/vendor_boot/pvmfw 共用

# 以 system 为例（--partition_size 取**新**的 LP 分区大小；avbtool 会追加 tree+FEC 并补齐）
python3 tools/avbtool.py add_hashtree_footer \
  --image out/android-min-avb-20261118/parts/system-min.img \
  --partition_name system --partition_size 5905580032 \
  --salt $SYS_SALT --hash_algorithm sha256 --block_size 4096 \
  --do_not_append_vbmeta_image \
  --output_vbmeta_image out/android-min-avb-20261118/desc-system.img
```
逐项解释：
- `--salt`：沿用原厂（同一 salt 让 tree 可复现，且 `--include_descriptors_from_image` 时代码路径一致）。
- `--output_vbmeta_image`：hashtree 的描述符**不写进分区**，只吐一个「只含该描述符的 vbmeta 块」，下一步喂给 `make_vbmeta_image`。
- `--do_not_append_vbmeta_image`：逻辑分区里**不要**再塞一份 vbmeta（原厂件也没有）。
- `--partition_size`：必须是**新的** LP 分区大小（旧的是 `system_a` 12 273 176 576 B）；给大了浪费 super，给小了 avbtool 直接报 `Image size + tree + FEC doesn't fit`。
- `pvmfw` 是 **hash**（不是 hashtree）：`--include_descriptors_from_image backup/official-rom-15.10.259/pvmfw.img`。

**路线 B 第二步：重建 `vbmeta_system_a`**
```bash
python3 tools/avbtool.py make_vbmeta_image \
  --output out/android-min-avb-20261118/vbmeta_system_a.img \
  --key bootslot-b/avb.key --algorithm SHA256_RSA4096 \
  --flags 0 --rollback_index 1777939200 --rollback_index_location 0 \
  --include_descriptors_from_image out/android-min-avb-20261118/desc-product.img \
  --include_descriptors_from_image out/android-min-avb-20261118/desc-system.img \
  --include_descriptors_from_image out/android-min-avb-20261118/desc-system_ext.img \
  --include_descriptors_from_image backup/official-rom-15.10.259/pvmfw.img \
  --prop com.android.build.product.os_version:16 \
  --prop com.android.build.product.security_patch:2026-05-05 \
  --prop com.android.build.system.os_version:16 \
  --prop com.android.build.system.security_patch:2026-05-05 \
  --prop com.android.build.system_ext.os_version:16 \
  --prop com.android.build.system_ext.security_patch:2026-05-05 \
  --prop "com.android.build.system.fingerprint:Lenovo/TB322FC/TB322FC:16/BQ2A.250610.001-BP2A.250605.031.A3/ZUXOS_1.5.10.259_260611_PRC:user/release-keys" \
  --prop "com.android.build.product.fingerprint:Lenovo/TB322FC/TB322FC:16/BQ2A.250610.001-BP2A.250605.031.A3/ZUXOS_1.5.10.259_260611_PRC:user/release-keys" \
  --prop "com.android.build.system_ext.fingerprint:Lenovo/TB322FC/TB322FC:16/BQ2A.250610.001-BP2A.250605.031.A3/ZUXOS_1.5.10.259_260611_PRC:user/release-keys" \
  --prop "com.android.build.pvmfw.fingerprint:Lenovo/TB322FC/TB322FC:16/BQ2A.250610.001-BP2A.250605.031.A3/ZUXOS_1.5.10.259_260611_PRC:user/release-keys" \
  --padding_size 65536
```
- **必须显式给 `--prop`**：`--include_descriptors_from_image 原厂 vbmeta_system.img` 会把**旧的** hashtree 描述符也一起带进来，与新描述符同名 ⇒ libavb 会因重复描述符报错，所以只能「新描述符 + 手抄 prop」。
- `rollback_index 1777939200`：与原件相同（时间戳形式）。改小到 0 在解锁态无害，但会破坏「回锁可用」这条退路。[机制]

### 2.4 本轮**已实跑验证**的命令与两个工具坑

| 验证项 | 结果 |
|---|---|
| 路线 A 命令（`--include_descriptors_from_image 原厂 vbmeta.img --flags 1`） | ✅ 跑通：输出 `out/android-min-avb-20261118/vbmeta_a-flags1.img`，key `1e54e86e`、**Flags 1**、描述符条目数与原件**完全一致（24 条）**、`verify_image --key bootslot-b/avb.key` 得出 `Successfully verified SHA256_RSA4096 vbmeta struct` |
| 路线 B 管线（拿 `odm` 做小样本） | ✅ 跑通且**root digest 与原厂逐字节相同**（`3bac79e48e8ae48255155e578bfe8ef1d31e688c4e7f802adfa7e0e1a3e3543a`）⇒ ① `scripts/android-lpdump.py` 的 extent 映射**忠实于厂商签名内容**；② `add_hashtree_footer`+`make_vbmeta_image` 管线语义正确 |
| 路线 C（`--flags 3`） | 与路线 A 同一条命令只换 `--flags 3`；本仓已有同类历史件可比对 |

**工具坑 1：主机没有 `fec` 二进制。** `avbtool add_hashtree_footer` 默认会调外部 `fec` 生成 FEC（原厂每个 hashtree 描述符都是 `FEC num roots: 2`）；本机实测 `FileNotFoundError: 'fec'`，`apt` 里也没有该包。当前只能加 `--do_not_generate_fec`，于是描述符变成 `FEC num roots: 0 / FEC size: 0`。
- 影响：**dm-verity 校验照做**（root digest 不变，实测同一 `odm` 打出的 root digest 与原厂相同），只是**失去块损坏的纠错能力**；且分区尾部少 16 KiB 的 FEC 区，`--partition_size` 要相应小一点或让它 padding。
- 想恢复：编 AOSP `system/extras/verity/fec`（依赖 libfec）或找发行版/预编译件 —— 列入 Q5。

**工具坑 2：`make_vbmeta_image --include_descriptors_from_image <带 hashtree 描述的 vbmeta>` 会去当前目录找 `<partition>.img`。** 实测在 `/tmp` 下必须先 `cp odm-test.img odm.img`，否则报 `FileNotFoundError: '/tmp/odm.img'`（avbtool 会按描述符里的分区名回读镜像做校验）。⇒ 以后跑重建脚本时**cd 到放镜像的目录**，或建同名软链。
- 附带：`avbtool verify_image --image <vbmeta>` 若旁边没有对应 `<partition>.img`，会先打印一行 `Error verifying descriptor.` 再打印 `Successfully verified … vbmeta struct`；**那行不是错误判据**（判据看后面那句）。

### 2.6 重打 super（口径 (a)：只改内容布局，不动 GPT）——`lpmake` 现成可用

`~/bin/lpmake`（并列 lane 今日编好）可直接重打；已跑过「原样重打 14/14 MATCH」，所以以下命令只需把分区大小换成去预装后的新值：

```bash
cd /home/xuqianhui/y700-elden/out/android-min-avb-20261118/parts
# 新分区大小 = avbtool 实占（fs + hashtree + FEC）向上取 MiB 对齐；先用
#   python3 /home/xuqianhui/y700-elden/tools/avbtool.py info_image --image system-new.img
# 看 Image Size/Tree Size/FEC Size，或直接看图镜像字节数×1.03+4 MiB
~/bin/lpmake \
  --metadata-size 65536 --super-name super --metadata-slots 3 \
  --device super:23622320128 \
  --group qti_dynamic_partitions_a:22524 \
  --partition odm_a:readonly:1650688:qti_dynamic_partitions_a          --image odm_a=odm_a.img \
  --partition product_a:readonly:1041178624:qti_dynamic_partitions_a   --image product_a=product_a.img \
  --partition system_a:readonly:<新system大小>:qti_dynamic_partitions_a --image system_a=system-a-min.img \
  --partition system_dlkm_a:readonly:12533760:qti_dynamic_partitions_a  --image system_dlkm_a=system_dlkm_a.img \
  --partition system_ext_a:readonly:598372352:qti_dynamic_partitions_a   --image system_ext_a=system_ext_a.img \
  --partition vendor_a:readonly:1536176128:qti_dynamic_partitions_a     --image vendor_a=vendor_a.img \
  --partition vendor_dlkm_a:readonly:147382272:qti_dynamic_partitions_a --image vendor_dlkm_a=vendor_dlkm_a.img \
  --output /home/xuqianhui/y700-elden/out/android-min-avb-20261118/super-slim.img
# 回解验证（必做两项）
~/bin/lpunpack -S 0 /home/xuqianhui/y700-elden/out/android-min-avb-20261118/super-slim.img /tmp/slim-check   # 7 个分区逐个解出，与输入逐字节 cmp
python3 /home/xuqianhui/y700-elden/scripts/android-lpdump.py   # 解析新件并与上面结果对账（改 --from-xml 为自建的段表）
```
要点：
- `--metadata-slots 3`、`--metadata-size 65536` **必须**与原 geometry 一致（否则 init 的 `ReadMetadata` 会读不到表）。
- 要想保留 `LP_PARTITION_ATTR_UPDATED(0x4)`（原厂 attrs=0x5），lpmake 无法直接指定 ⇒ 重打后用 `scripts/android-lpdump.py` 的解析器把 attrs 字节改成 0x5，再重算 table/header checksum（与 0x1 的差别只影响 OTA 语义）。
- 删掉 7 个 `*-cow` 可再省 **375 MiB**（对应 `cow` 组），代价 = 不支持快照式 OTA。
- `--sparse`：本机**无 `simg2img`**，而 `qdl` 只吃 raw ⇒ 输出 raw 直接 `qdl write 0/90504`。
- 写完必做：`qdl -s ufs "$L" sha256 0/90504+<nsectors>` 与主机 sha 对账（不信工具自报）。

### 2.7 descriptor 覆盖矩阵（改谁就要重建谁）

| 改动的分区 | 谁记得它的摘要 | 重新生成方式 |
|---|---|---|
| `system` / `system_ext` / `product` | `vbmeta_system_a` 的 hashtree | 2.3 路线 B 第一步 + 第二步 |
| `odm` / `vendor` / `vendor_dlkm` / `system_dlkm` | **顶层** `vbmeta_a` 的 hashtree | 同上（描述符塞进顶层 `vbmeta_a`） |
| `dtbo` / `init_boot` / `vendor_boot` | 顶层 `vbmeta_a` 的 hash | 只有换这些件时才需要：`add_hash_footer --output_vbmeta_image` → 顶层重建 |
| `boot` | 顶层 `vbmeta_a` 的**链**（key + loc3） | 换 boot 时：`add_hash_footer --key <同钥或自签> --rollback_index 0`，链描述符可原样保留（解锁态容忍），或 `--chain_partition boot:3:<新 avbpubkey>` |
| `recovery` | 顶层链（loc1） | 同上（本仓 `scripts/flash-recovery.sh` 已记录「描述符不含 recovery 时写 recovery_b 无需重签」） |
| `pvmfw` | `vbmeta_system_a` 的 hash | 不换就不动 |
| `super` 的 LP 元数据本身 | **没人记**（ABL 不解析 super；vbmeta 里记的是逻辑分区内容的摘要，不是 metadata） | 除非改 flags，否则重建 super 不需要动 vbmeta **签名**；但改了分区内容/大小 ⇒ 见上 |

- **`init_boot` / `vendor_boot` / `dtbo` 是否必须一起重签？** 不必须 —— 只有在**换了这三个分区的字节**时才需要（它们在顶层 vbmeta 的 hash 描述符里）。我们要改的是 super 内部的分区，与它们无关。**[机制]**
- **[实测]** `boot_a`/`boot_b` 分区 96 MiB、`dtbo` 32 MiB、`vbmeta`/`vbmeta_system` 各 64 KiB（`gpt_main4.bin`/`gpt_main0.bin` 直读），与原厂件尺寸一一吻合，可作刷写前尺寸门禁。

---

## 3. B. 虚拟 A/B 风险（逐条标等级）

### 3.1 状态落在哪
| 位置 | 内容 | 本包实测 |
|---|---|---|
| **LP metadata**（super 内 12288/208896 起，3 份 ×2 区） | 逻辑分区表 + `*-cow` 设备 + group | **slot0 = `_a` 代 + 7 个 `*-cow`；slot1 = `_b` 代 + 7 个 `*-cow`；slot2 = 出厂代（`_a` 有、`_b` 全 0、attrs=0x1）** [实测]。且 **slot0/slot1 的 extent 逐条相同**（b 代只是改名引用同一批物理块）[实测] |
| **`/metadata` 分区**（64 MiB，f2fs） | update_engine 的 `otapackage/`、snapshot 状态、`avb_enforce` 标记 | **空**（拼回 28 MiB 稀疏镜像后 `strings` 只有 f2fs 内核版本串，无 `otapackage`/snapshot） [实测] |
| **`misc`**（1 MiB，BCB `bootloader_message`） | `bootonce-*`、`boot-recovery`、槽位指令；`qbootctl` 的 slot 计数也走这里 | **包内不写**（`rawprogram_save_persist_unsparse0.xml` 里 `label="misc"` 的 `filename=""`） [实测] |
| **GPT attribute byte6**（LUN4） | `ACTIVE(0x04)` / `SUCCESSFUL(0x40)` / `retry(bits3..5)` / `UNBOOTABLE(0x80)` | `boot_a`=0x77、`boot_b`=**0xf3（UNBOOTABLE）**；`vbmeta_system_a`=0x04、`_b`=0x00 [实测；位定义见 `scripts/slot-attr.py` 头注释] |
| 内核 cmdline | `androidboot.vbmeta.*`、`veritymode`、`slot_suffix` | `veritymode=eio`、`avb_version=1.2`、`vbmeta.size=17344` [实测] |

### 3.2 ABL 怎么选槽 —— 与 super 无关
- **[机制]** ABL 只读 **GPT attribute byte6 + `misc` BCB** 决定 `slot_suffix` 与 retry 计数；**它不解析 super / LP metadata**（本仓 `GPT-MINIMAL-DESIGN` §2.2 已把「super 对 ABL 不可见」列为实测结论）。
- **[机制]** `init`（HLOS）才解析 LP：`first_stage_mount.cpp` → `ReadCurrentMetadata(super_path_)` → `SlotNumberForSlotSuffix(ro.boot.slot_suffix)`（`a/_a`→0，`b/_b`→1；`liblp/utility.cpp`）。
- **[实测]** 所以：**重写 super 不会影响 ABL 选槽**；影响的是 init 能不能建出 `/dev/block/dm-*`。

### 3.3 「`_b` 槽逻辑分区缺失」会不会报错
- **[机制]** `CreateLogicalPartitions()`：`num_extents == 0` 的分区**只是 log 一行 `Skipping zero-length logical partition`**；`LP_PARTITION_ATTR_DISABLED` 同理跳过；只有「分区存在但 dm-linear 建不出来」才 `ERROR ... Could not create logical partition` 并让 first-stage 失败。
- **[实测]** 包内 slot2 就是这种形态（`odm_b`/`product_b`/`system_b`… 全 0 长度）且它随包一起写进设备 —— 说明厂方自己就把它当合法状态。
- **[推断]** 我们把 super 换成「只有 `_a` 那 7 个基础分区（无 cow）」时：a 槽启动无影响；b 槽启动会因 `_b` 相关分区缺失而**起不到 Android**（现在 b 槽本来也是我们的 Linux 槽，不冲突）。若将来想「a/b 都能起 Android」，必须让 metadata 里**同时**有 `_a` 与 `_b` 两套（就是现在 slot0/slot1 的形态）。

### 3.4 重写 super 前要不要清 `misc` / `bootctl`
- **[实测]** `/metadata` 空 ⇒ 没有 pending snapshot，`snapshotctl`/first-stage 的 snapshot 分支不会启动（`SnapshotManager::IsSnapshotManagerNeeded()` 依赖 /metadata 里的状态）。
- **[实测]** 包内 `*-cow` 逻辑分区虽然存在，但**没有配套的 snapshot 状态**，init 只会把它们当普通（空的）逻辑分区建出来，不参与合并。
- **结论**：**不需要**先清 `misc`。真正需要动 `misc` 的场景只有两个：① 想强制一次性进 fastboot/recovery（`bootonce-*`）；② 设备因为 retry 耗尽卡在 fastboot（`PITFALLS #181`：桌面 Linux 不标 SUCCESSFUL ⇒ 7 次后 `UNBOOTABLE`）。
- ⚠️ **[实测]** 反过来的坑更要命：**包内 `gpt_main4.bin` 会把 `boot_b` 设为 UNBOOTABLE、`boot_a` 设为 ACTIVE+SUCCESSFUL**。刷全量包 = 槽属性回出厂 ⇒ 现役 b 槽 Linux 立刻报废；且我们历史事故（2026-11-17 卡 BL）的真因就是 **GPT 不是原厂**，所以「改 GPT」这件事必须按 `RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md` §S1/S3 的复核流程走。

### 3.5 super 内容布局重写的具体风险
| # | 风险 | 等级 | 缓解 |
|---|---|---|---|
| B1 | 自写 LP metadata 位错 ⇒ init 建不出 dm-linear ⇒ 卡开机动画/回 recovery | 高 | 写完必须**双解析器交叉验证**（`scripts/android-lpdump.py` + `~/bin/lpunpack` 解回逐字节比对，并列 lane 已验过原样往返 14/14 MATCH），并核对 extent 两两不重叠、都在 `block_device.size` 内 |
| B2 | `block_device.size` 字段（本包 = 23 622 320 128 **字节**）与实际 super 分区大小不一致 | 中 | 保留原值 = GPT 的 22528 MiB；若真缩分区，必须同步改这个字段与 GPT |
| B3 | 保留 `*-cow` 与否：删掉更省 390 MiB，但若将来做 OTA/快照会缺设备 | 低 | 「最小包」口径：删（并在报告里写明不支持 OTA） |
| B4 | `LP_PARTITION_ATTR_UPDATED(0x4)`：原厂基础分区 attrs = **0x5**（READONLY\|UPDATED）。lpmake 只会给 `readonly` | 低 | 用 lpmake/自写时显式补 0x4；实测 init 只对 `DISABLED` 特判，缺 0x4 只影响 OTA 语义 |
| B5 | 写 super 时用 `fastboot flash super`（bootloader fastboot）与 `fastbootd` 的差别 | 中 | super 是**物理**分区，bootloader fastboot 可写；逻辑分区只能在 fastbootd。**本仓既定通道是 qdl**（`RUNBOOK` S2 实测 15 GiB / 6 min @41 MiB/s） |
| B6 | 新 super 比原分区小 ⇒ 尾部残留旧数据 | 低 | 无害（LP 只按 metadata 分配）；但**别**把「残留」当「已清空」 |

---

## 4. C. 去预装边界（三档 + 判据）

### 4.1 分区与体积现状（全部实测）
| 分区 | LP 大小 | ext4 块数(4 KiB) | free blocks | 清单文件/目录/链接 | 说明 |
|---|---|---|---|---|---|
| `system` | 12 273 176 576 B (11.43 GiB) | 2 949 079 | 8 876 (**0.3%**) | 3333 / 546 / 307 | 几乎全满 |
| `product` | 1 041 178 624 B | 250 163 | 754 (0.3%) | 251 / 89 / 1 | GMS 落点 |
| `system_ext` | 598 372 352 B | 143 761 | 434 (0.3%) | 1188 / 159 / 2 | SystemUI + VNDK apex |
| `vendor` | 1 536 176 128 B | 369 104 | 1 127 (0.3%) | 3757 / 214 / 297 | 厂商 HAL/blob |
| `vendor_dlkm` | 147 382 272 B | 35 392 | 106 | 307 | WiFi/相机模块 .ko |
| `system_dlkm` | 12 533 760 B | 2 991 | 9 | 104 | 上游 GKI 模块 |
| `odm` | 1 650 688 B | 376 | 2 | **13** | 只剩 selinux + 触觉配置 |

均带 `shared_blocks`（去重）特征；`e2fsck -fn` 除 `vendor` 有若干 extent 警告外均干净（`vendor` 警告见 §7 疑点 Q3）。

### 4.2 system 的体积构成（`inv-system.tsv`，逻辑字节，含去重前重复计数）
```
3525.0 MiB  /system/etc        ← 光 /system/etc/AI/models/qwen 5 个 .bin 就 2.8 GiB
3366.6 MiB  /system/priv-app   ← ZUIEpos 374M / ZuiWallpaperSetting 272M / PenService 260M / ZuiCamera 226M …
3271.9 MiB  /system/preinstall ← 联想预装 40 项（Wangyiyun 349M、Capcut 218M、BaiduNetdisk 217M、AiFlashPoint 210M、MotoReadyFor 181M、Weibo 169M、Moffice 156M …）
 393.4 MiB  /system/app        ← ZuiFileManager 160M 等
 379.4 MiB  /system/lib64
 293.1 MiB  /system/apex
 183.4 MiB  /system/framework
```
`system_ext`：`ZuiSystemUI` 212.6 MiB、VNDK apex v30–v34 合计 160 MiB、`QualcommVoiceActivation` 30.8 MiB、`EmergencyInfo`/`StorageManager`/`AvatarPicker`、`libmsp.so` 10 MiB。
`product`：`LenovoXiaoTian` 256.9 MiB、`GmsCore` 184.7 MiB、`TrichromeLibrary64` 172.8、`WebViewGoogle64` 77.8、`xiangbb` 77.5、`talkback` 47.3、ZuiThemeSettings 系列 overlay 合计 ~120 MiB。
`vendor`：`acdbdata` 228 MiB、`lib64/camera` 107、`lib64/rfs` 107、`lib64/hw` 59、`lib/rfsa` 50、`libQnnHtpPrepare.so` 48.8、`libadreno_compiler_cl.so` 31.5、6 个 `bm5a7*.bin` 各 22.5。

### 4.3 三档（判据写在每档里）

**① 安全删（删了不影响开机，实测/机制均可解释）**
- `/system/preinstall/*`（3.27 GiB 逻辑）：联想「首次开机安装后删除」的预装池，系统 App 不 `require` 它们。判据：不在 `/system/etc/permissions/*privapp*` 白名单里；不在 `apex`/`framework`；`ls /system/preinstall` 全是第三方（抖音/优酷/百度网盘/剪映/网易云/微博/搜狗输入法/芒果…）。
- `/system/etc/AI/models/qwen/*`（2.8 GiB）：Lenovo 端侧大模型权重，宿主 App（`/product/app/xiangbb`、`/system/priv-app/ZuiAILens`）缺模型只会降级/报错，不会导致 `system_server` 起不来。**判据 = 它只是 `/system/etc` 下的数据文件，不参与 init/apex/selinux**；但「App 报错」属功能降级，需上机确认（见 §6）。
- 主题类 RRO：`/product/overlay/ZuiThemeSettingsOverlay*.apk`（~120 MiB）、`/system/preinstall/XuiCalendarOverlay*`。判据：RRO 是「可选叠加」，`overlay` 目录缺项由 SystemUI/Settings 容错（AOSP `OverlayManager` 对缺失 target 只 warn）。
- `talkback`、`SwitchAccess`（无 GMS/TTS 场景）、`XtsMusic`/`ZuiGallery` 这类可替换 App —— **需验证**（见 ②）。

**② 需验证（能删但必须上机看）**
- `/system/priv-app/ZUIEpos`(374M)、`ZuiWallpaperSetting`(272M)、`PenService`(260M)、`ZuiCamera`/`ZuiCameraAssistant`/`ZuiCameraQR`(226M 起)：删掉后 **先看 `ZuiSettings`/`ZuiLauncher` 是否硬依赖**（`dumpsys package` 的 required 关系、`AndroidManifest` 的 `<uses-library>`）。
- `/product/priv-app/LenovoXiaoTian`(257M) + `/product/app/xiangbb`(77M) + `/system/etc/AI`：三者是同一套「小天」助手，**要么一起删、要么一起留**。
- `/product/app/TrichromeLibrary64` + `WebViewGoogle64`：**删了 WebView 就没了**（ZUI 自带 App 多数用系统 WebView）⇒ 只换不删。
- VNDK apex `com.android.vndk.v30..v34`：`v34` 是当前 VNDK 版本，删 `v34` 必炸；旧版本（v30/v31）理论上可删，但 **apex 里带 `/vendor` 依赖的 stub**，必须 `apexd --verify` + 起机确认。
- `/system/media`(106M) 铃声/开机动画：删了只是「没铃声」，但要确认 `ZuiSettings` 不因缺资源崩溃。
- **判据（通用）**：① 有 `privapp-permissions-<pkg>.xml` 的 App，**删 App 可以，删 XML 不行**（user 构建里 privileged app 无白名单会直接 `system_server` 起不来；反之白名单里有不存在的包只是 warn）；② 有 `sysconfig/*.xml` 里 `<feature>` / `<library>` 引用的，删 App 前先 grep 该包名；③ 任何 `/system/etc/init/*.rc` 里 `exec_start`/`wait_for_prop` 指向的服务，删了对应二进制会**卡启动**。

**③ 禁止删（删了必黑/必卡）**
- `/system/framework/*.jar`、`/system/lib64`、`/system/bin`（`init`/`linker64`/`toybox`…）、`/system/apex/*.apex`（`com.android.runtime`/`art`/`conscrypt`/`i18n`…）；`odm/etc/selinux/precompiled_sepolicy`（删了 selinux 无策略 ⇒ 无法起 `system_server`）。
- `/system/etc/vintf/manifest*`、`/system/etc/permissions/*.xml`、`/system/etc/init/*.rc`、`/system/etc/fs_config_*`、`/system/etc/ueventd.rc`。
- `/product/app/{DeviceStatisticsService...,LTHD,LatinIME}` 里的 **`LatinIME`**（输入法宿主）与 `SettingsIntelligence`（设置搜索）。
- GMS 骨架：`/product/priv-app/GmsCore`、`ConfigUpdater`、`GooglePartnerSetup`、`GoogleOneTimeInitializer`、`/system_ext/priv-app/GoogleServicesFramework`、`/product/overlay/GmsConfigOverlay*.apk`。删 GMS 会导致（a）`ro.build` 的 GMS 相关 overlay 缺 target、（b）很多 ZUI App 依赖 `com.google.android.gms` 的 `Play Services` 校验。真要「无 GMS」必须走 **lineage/microG 重构**，不是删文件。
- 任何 `/system/priv-app/Zui*` 里的 `ZuiSettings`/`ZuiLauncher`/`ZuiPermissionController`/`ZuiPackageInstaller`/`ZuiSystemUI`（在 `system_ext`）—— 这是当前桌面的功能本体。

### 4.4 已实测的回收量（这是「去预装」的硬数字）
```
== ext4 去预装实测（副本） ==
drop=/system/preinstall /system/etc/AI
free_blocks_before=8 876   (34.67 MiB)
free_blocks_after=1 645 201 (6426.57 MiB)
freed_blocks=1 636 325 => 6391.89 MiB (6.24 GiB)
清单逻辑字节=6481.43 MiB（shared_blocks 去重前；去重只吃掉 1.4%）
e2fsck -fy 后复查：/: 3975/4320 文件，1303878/2949079 块，0 错误
```
⇒ **system 最少可做到约 5.0 GiB**（11.25 − 6.24），加 verity/FEC 约 +2%（≈5.1 GiB）。

**但缩 fs 有个硬坑（实测）**：`resize2fs -M` 受 `shared_blocks` 限制只从 2 949 079 收到 2 687 555 块（10.25 GiB）——**共享块不能搬**。要真缩到 5 GiB 必须：
1. `debugfs -R "rdump / <dir>"` 把文件拷出来（或对**已删除后**的镜像再 `rdump`）；
2. `mkfs.ext4 -b 4096 -O ^has_journal? ...`（原厂特征串见 `dumpe2fs`：ext_attr,dir_index,filetype,extent,sparse_super,large_file,huge_file,uninit_bg,dir_nlink,extra_isize,**shared_blocks**）重建**新**镜像，尺寸按目标；
3. 逐文件 `write` 回去 + `chown/chmod/xattr`（`fs_config` 里的 uid/gid/cap 必须照 `system/etc/fs_config_files` 打）；
4. `e2fsck -fy` 后交给 `avbtool add_hashtree_footer`（注意 §2.4 的 `fec` 缺失 ⇒ 目前带 `--do_not_generate_fec`）。
   ⇒ 这一步**不要**手搓所有权：用 `debugfs -w -f` 生成的指令表 + `fs_config` 对照（本仓可再写一个脚本）。

---

## 5. D. 社区先例与常见翻车

| 先例 / 事实 | 出处 | 对本机意义 |
|---|---|---|
| 「lpmake 重组的 super 与原厂 vbmeta 的 hash 不匹配 ⇒ 用 flags=3 打过补丁的设备**千万别回滚成原厂 vbmeta**」——Surface Duo 1 的 super 损坏恢复实录，含 flags=3 后 `fastboot reboot` 无限 bootloop、`fastboot continue` 才勉强进 OOBE 的失败链 | `https://xdaforums.com/t/guide-updated-surface-duo-1-super-partition-corruption-recovery-woa-84-practical-solution-firehose-loader-request.4786160/`（Brave 摘要） | 与本机同构：**改了 super 内容就必须同时处理 vbmeta 的 flags/描述符**，且「留一份能回滚的原件 + 知道哪一份是配套的」比「回滚到原厂」更安全 |
| AOSP 官方 dynamic partitions 实施文档：`super` 必须按块层最小 I/O 对齐，构建系统默认按 **1 MiB 对齐** | `https://source.android.com/docs/core/ota/dynamic_partitions/implement` | 我们自写 metadata 时每个 extents 起点按 1 MiB 对齐；本包实测 `block_device.alignment=524288`（字节），`first_logical_sector=2048`(=1 MiB)，说明厂方也用 1 MiB 起算 |
| 社区标准「让 super 变小」流程：`lpunpack` 拆 → 改 fs → `lpmake --metadata-size 65535 --super-name super --metadata-slots 1 --device super:<size> --group ... --partition ...` → 刷 `super` + **必须同时 `fastboot flash vbmeta --disable-verity`** | JTech Forums / SamsungImageRepacker / SuperImage 工具帖 | 与我们 §2.3 路线 A/C 结论一致：**只改 super 不改 vbmeta 是翻车主因** |
| `--flags 1`（只关 hashtree）与 `--flags 3`（连描述符都不看）**语义不同**：前者 boot/dtbo 仍校验，后者等于 AVB 全关；`avbtool` 另有 `--set_hashtree_disabled_flag` / `--set_verification_disabled_flag`（在既有 flags 上或位），**与 `--flags` 混用会互相覆盖** | `external/avb/libavb/avb_vbmeta_image.h` + `tools/avbtool.py`（本机 1.3.0，`--set_*_flag` 与 `--flags` 同时存在） | 我们路线 A 用 `--flags 1`，路线 C 用 `--flags 3`；**不要**写成 `--flags 3 --set_hashtree_disabled_flag` |
| rollback index 常见翻车：`Image rollback index is less than the stored rollback index` 是 **ABL 在锁定态**拒签的主因；解锁态 `fs_mgr` 的 `rollback_protection = !allow_verification_error` 直接跳过 | `avb_slot_verify.c`（本机 curl 落的源码）+ `libfs_avb/fs_avb.cpp` | 本机 `vbmeta_system_a` 的 rollback 是 **1 777 939 200**（时间戳），重建时别填 0 再回锁 |
| 键/描述符不匹配的典型报错：`avb_slot_verify.c:913 ERROR: <part>: Public key used to sign data rejected`，**解锁态只是记录**，之后照常 `BootLinux` | 本机 logfs/串口记录（`reports/uefi-p69-flashed-and-vbmeta-20261110.md` §4） | 别把这条 ERROR 当失败判据 |
| 「禁用 verity」的社区做法（`adb disable-verity`、`avbctl disable-verification`）本质就是**改 vbmeta flags 再重签**，需要能签 vbmeta 的钥匙；OEM 钥匙拿不到 ⇒ 只能自签 + 解锁 | postmarketOS wiki / hansenpartnership 博客 | 我们已有 `bootslot-b/avb.key`（RSA-4096）+ `env-pass/keys/testkey_rsa4096.pem`（AOSP 公开 testkey，U1 的顶层曾用它），两条钥匙路线都在 |

⚠️ 社区来源只用「搜索摘要 + AOSP 原文」，未逐篇全文核对；**判据以上游源码与本机实测为准**。

---

## 6. E. 必须上机验证的判据（建议按此顺序，任一条不过就停）

| # | 判据 | 命令（设备侧） | 期望 |
|---|---|---|---|
| V1 | 改完 super 后 **init 能建逻辑分区** | `adb shell 'ls -l /dev/block/dm-*'`；`adb shell 'dmesg \| grep -i -E "lp|dm-linear|logical partition"'` | 7 个 `dm-*`（或按新表数量）；dmesg 无 `Could not create logical partition`、无 `Could not read partition table` |
| V2 | **verity 状态**符合设计 | `adb shell getprop ro.boot.veritymode`；`adb shell getprop ro.boot.vbmeta.digest`；`adb shell 'mount \| grep -E "dm-verity\|/system"'` | 路线 A/C：`veritymode=disabled` 且 `/system` 直接挂（非 dm-verity 设备）；路线 B：`veritymode=eio` 且挂的是 `dm-verity` 设备 |
| V3 | **哈希树没炸**（路线 B） | `adb shell 'dmesg \| grep -i -E "verity\|avb"'`；`adb shell avbctl get-verification`（若有） | 无 `verity: data corruption` / `EIO`；`/system` 可读（`ls /system/framework` 非空） |
| V4 | **fs_mgr 判定** | 早期：`adb shell dmesg \| grep -E "avb_handle\|AVB (HASHTREE|verification) disabled\|Found unknown"` | 路线 A 应出现 `AVB HASHTREE disabled on: /system`（对应 `kHashtreeDisabled`） |
| V5 | **ABL 侧**没拦 | `fastboot getvar current-slot`、`verifiedbootstate`；屏上是否出现 5 s「解锁警告」 | 出现警告是正常的（orange）；**不应**出现「无警告直接掉电/回 fastboot」 |
| V6 | **系统完整性** | `adb shell 'pm list packages -u \| wc -l'`；`adb shell 'settings get global device_provisioned'`；`adb shell 'dumpsys activity \| head -30'` | 与去预装前的包数对照（记录基线），`system_server` 不重启（`adb shell 'pidof system_server'` 一次取值后 5 min 不变） |
| V7 | **去预装的功能面** | `adb shell 'am start -a android.intent.action.MAIN -c android.intent.category.HOME'`；依次开 `ZuiSettings`/`ZuiLauncher`/`ZuiSystemUI` 对应界面；`adb logcat -b crash -d` | 桌面能起、设置能进、无 `FATAL EXCEPTION` |
| V8 | **回退通道** | 事前记：`fastboot getvar all \| grep -E "slot|unbootable"`；事后 `qdl sha256 4/137946+16` 核对 `vbmeta_a` | 回退件 = `backup/official-rom-15.10.259/vbmeta.img`；super 回退 = 重刷 `rawprogram_save_persist_unsparse0.xml`（11-17 实测走通一次，~6 min） |
| V9 | **零写盘预演（强烈建议）** | `fastboot boot <改过的 boot>`？——不行（改的是 super）。替代：先把新 super 写成**稀疏**件，用 `fastboot flash super` 在**一台**机器上单变量验证；或先只改 `vbmeta_a`（flags=1）不碰 super，确认 Android 照常起（**这一步本身就是一个可独立上机的最小实验**） | 只改 vbmeta ⇒ 起机 + `veritymode=disabled`；再改 super ⇒ V1–V4 过 |

**最小可上机的第一步（建议）**：只刷 §2.3 路线 A 的 `vbmeta_a-flags1.img`（64 KiB，可秒回退），确认 (a) Android 照常起，(b) `ro.boot.veritymode=disabled`，(c) `mount | grep system` 不是 dm-verity。**这一步不改 super、不改 GPT、不需要 EDL**，但它是后面所有「改 super」动作的前置闸门。

---

## 7. 风险清单（按严重度）

| # | 风险 | 等级 | 触发条件 | 缓解/判据 |
|---|---|---|---|---|
| R1 | 改 super 内容但**没**动 vbmeta ⇒ init 的 dm-verity 用旧 root digest ⇒ `eio` 读失败、卡开机 | **高** | 路线「只换 super」+ `veritymode=eio` | 先做 §6 的「只改 vbmeta 最小实验」；或直接走路线 A/C |
| R2 | **刷全量包复位 GPT 槽属性**：`boot_b` 变 UNBOOTABLE、`boot_a` 变 ACTIVE+SUCCESSFUL ⇒ 现役 b 槽 Linux 报废；`linux17`/`eldenesp` 条目丢失（2026-11-17 已踩过一次同类） | **高** | 跑 `rawprogram4.xml` + `patch4.xml`（含 `gpt_main4.bin`） | 刷后立刻 `python3 scripts/slot-attr.py --image <LUN4 dump> show`；或刷前绿化 `gpt_main4.bin`（把 `boot_b` byte6 改 0x77） |
| R3 | LP metadata 自写/重组出错 ⇒ 建不出 dm-linear | **高** | 缩 super / 删 cow | 双解析器交叉验证 + extent 不重叠检查 + 先小规模（只删 preinstall、分区大小不变） |
| R4 | 钥匙混用导致**锁定态**起不来（现役 b 槽就是 `vbmeta_b`=`fc1e3b33` / `boot_b`=`1e54e86e`） | 中 | 回锁 / 换单元 | 解锁态无所谓；要回锁必须整链一把钥（`scripts/build-locked-chain.sh` 的 testkey 路线） |
| R5 | rollback index 填小 ⇒ 锁定态拒签 | 中 | 路线 B 重建 vbmeta_system | 照抄原值（`vbmeta_system`=1 777 939 200；顶层 0） |
| R6 | `misc` 不刷 ⇒ 若设备本来有 `bootonce-bootloader`/retry 耗尽状态，刷完仍卡 | 中 | 设备已在 fastboot 循环 | 刷完跑 `fastboot oem ...`/`qbootctl -m a`；必要时清 BCB（`reports/uefi-slotboot-stuck-fastboot-20261101.md` §misc） |
| R7 | 包内**不含 `userdata`**（`rawprogram*` 里无该文件）⇒ 旧 `/data` 与新 system 的预装/权限不一致 | 中 | 全量包刷到曾用过的设备 | `fastboot -w`（`RUNBOOK` S2 ④ 已实测必须） |
| R8 | `resize2fs -M` 收不动（`shared_blocks`）；误以为已缩 | 中 | 想「原地缩 fs」 | 用 §4.4 的 mkfs+重建流程；`dumpe2fs -h` 读 block count 判定 |
| R9 | 空白/裁剪后的 `vbmeta_system` props 缺失（`com.android.build.*.security_patch`）⇒ `ro.build.version.security_patch` 变成空、CTS/设置显示异常 | 低 | 路线 B 重建时忘 `--prop` | 照 §2.3 的 prop 列表逐条给；`avbtool info_image` 复核条数（原件 12 条） |
| R10 | 「缩 super 分区本身」需要前移 `vbmeta_system_a/b`+`metadata`+`rawdump`+`pstoredump`+`userdata` ⇒ 数据全丢、且与 `GPT-MINIMAL-DESIGN` P2 冲突 | **高** | 想要「设备上真省 14 GiB」 | 明确这是**另一次立项**（要用户裁决），本轮不碰 |

---

## 8. 未解决疑点

| # | 疑点 | 现状 | 下一步 |
|---|---|---|---|
| Q1 | 包内 super 的 slot0/slot1 为什么带 `*-cow` 逻辑分区（合并完成后 update_engine 通常会删） | 只知「3 代 metadata 各不同、/metadata 空」；**没有** snapshot 状态 | 若将来要保 OTA 能力，需在设备上 `lpdump`（fastbootd / `adb shell lpdump`）看真机当前表，与本包对照 |
| Q2 | `metadata_slot_count=3`（不是常见的 2） | 实测 geometry 值，含义未查证（可能与 Qualcomm 的「3 代回滚」有关） | 查 ABL/`liblp` 对该字段的容忍范围；自写 metadata 时**照抄 3** |
| Q3 | `vendor_a` 有 `e2fsck` extent 警告（inode 41/47/53：`无效的 extent 节点 (blk 4053/4068/4090)`） | 只记录，未定因（可能第三方转包时拼装错，或 `shared_blocks` + OTA 中间态） | 用 `debugfs -R "stat <41>"` 看是哪个文件；若属真损坏，参考件应从设备侧重新 dump 而不是信这个包 |
| Q4 | `bootslot-b/` 里**没有** `vbmeta_b_flags3.img`，`README` 里的公钥 sha1 是旧钥 `fc1e3b33`，而现役 `avb.key` 是 `1e54e86e` | 文档漂移，本轮只登记（SSOT 只读） | 编排者决定是否补 README + 把在役 `vbmeta_b` 从设备 dump 回仓（`backup/vbmeta_b-20261110.img` 应是它） |
| Q5 | 主机**无 `fec`**（`avbtool` 生成 FEC 的必需外部件）；`lpmake/lpunpack` **已由并列 lane 于今日编好**（`~/bin/lpmake`、`~/bin/lpunpack`，源 `/tmp/aosp-build/`，见 `reports/android-super-format-20261118.md`），仍缺 `lpdump` | 本仓 `tools/avbtool.py` 1.3.0；`add_hashtree_footer` 目前只能 `--do_not_generate_fec` | ① 重打包直接用 `~/bin/lpmake`（并列 lane 已做过“原样重打 14/14 MATCH”）；② 自写 metadata 写入器可作校验器（`android-lpdump.py` 解析器反写约 150 行）；③ `fec` 从 AOSP `system/extras/verity/fec` 编译（依赖 libfec）—— 属主机侧一次性备料 |
| Q6 | 去重特征 `shared_blocks` 是否允许 `mkfs` 重建后直接 `avbtool add_hashtree_footer` | 未实测 | 先拿 `odm`（1.6 MiB）做小样本重建 + `add_hashtree_footer` + `verify_image` 全绿，再上 `system` |
| Q7 | `system_dlkm`/`vendor_dlkm` 里模块与内核版本绑定（`6.6.118-android15`），自行裁剪只删不动（不能删任意 .ko 除非确认未加载） | 只记录 | 若要减 dlkm，按 `modules.load`/`modules.dep` 白名单 minify（与 Linux 侧内核无关） |

---

## 9. 数据指针（可复现）

```
out/android-min-avb-20261118/
  lpdump.txt                  # LP geometry/metadata/分区表/文件系统探测（--verify --probe）
  parts/{odm,product,system,system_dlkm,system_ext,vendor,vendor_dlkm}_a.img   # 15.7 GiB
  inv-*.tsv                   # 每个分区的完整文件清单（type/mode/uid/gid/size/path）
  slim-test.txt               # 去预装回收量实测
  metadata.img                # /metadata 拼回件（28 MiB 稀疏，f2fs，内容近空）
  avb-facts-vbmeta.txt        # vbmeta.img + vbmeta_system.img 的 info_image 全文（含 salt/prop）
scripts/android-lpdump.py scripts/android-rom-segassemble.py
scripts/android-img-inventory.py scripts/android-ext4-slim-test.py
```
对照证据（既有文件，只读引用）：
- AVB 实测：`reports/uefi-dtbo-a-rootcause-20261110.md`（实验 D/E/F/G 表）、`reports/artifacts/uefi-flashed-20261110-174233-ctrl-vbmeta-a-orig-flags0/{verdict,timing}.txt`、`reports/uefi-p69-flashed-and-vbmeta-20261110.md` §4
- 槽位/BCB/GPT：`scripts/slot-attr.py`（byte6 位定义）、`reports/uefi-slotboot-stuck-fastboot-20261101.md`、`RUNBOOK-BRINGUP/GPT-MINIMAL-DESIGN.md` §2.2
- 全量包刷写通道与时序：`RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md` §S2（qdl 三条命令 + `-R` 坑 + 15 GiB/6 min）
- 钥匙与「本机早已 unlocked」：`restore-259/AVB-KSU-2026-09-29.md` §1.4（cmdline 原文）

收尾: S2 事实面已落地（super 全表可解、AVB 链条逐分区实测、去预装回收 6.24 GiB 实测、三档边界与上机判据成文），未碰设备、未改 SSOT。
