# 宿主「静默文件损坏」真因 = 内存页缓存位翻转（非磁盘）

- **日期**：2026-10-20 19:50–20:15
- **主题**：纠正 2026-10-19/20 两轮「文件被静默改写」的归因；给出可复现判据与体检门
- **结论（一句话）**：**磁盘上的字节一直是对的；被改写的是内核页缓存里的副本。**
  根因是**内存/CPU 侧位翻转**（本机无 ECC、EDAC 不可用），不是磁盘、不是文件系统、不是 git、不是编译链。
- **方法**：三读法（buffered / 丢页缓存后 buffered / `O_DIRECT` 绕页缓存）在同一时刻对同一文件取 sha，
  再用 `dpkg -V`、git index、官方 `md5sums` 做第三方基线。
- **未上机**：全程只读本机文件，未接触设备。

---

## 1. 决定性证据

### 1.1 单文件三读（`build/m1-73` 里的 4 个「corrupt」文件）

| 文件 | git index sha1 | `O_DIRECT` 读（绕页缓存） | 普通读（经页缓存） |
|---|---|---|---|
| `.../dce/dce_12_0_sh_mask.h` | `45e3801f…` | `45e3801f…` ✅ | `baa1b9b7…` ❌ |
| `.../dpcs/dpcs_4_2_2_sh_mask.h` | `153b0209…` | `153b0209…` ✅ | `735834d4…` ❌ |
| `.../gc/gc_11_0_0_default.h` | `836d6f58…` | `836d6f58…` ✅ | `a4da5a06…` ❌ |
| `.../gc/gc_11_0_0_sh_mask.h` | `f1e224e1…` | `f1e224e1…` ✅ | `1de803e2…` ❌ |

### 1.2 丢弃页缓存立即恢复（不需要 root）

```
before fadvise : 1de803e2efe962f15c1f648cd076cd4ac3a798dd
after  fadvise : f1e224e18a2da4e4b16f7cb5f577a9497ea10276   ← 与 git index 逐字相同
```

`posix_fadvise(fd, 0, 0, POSIX_FADV_DONTNEED)` 只是**丢掉干净页缓存**，磁盘内容一个字节都没动。
丢弃后重读即恢复正确 ⇒ 错的内容只存在于内存。

### 1.3 同一现象命中编译器本体（解释「随机 ICE」）

```
$ f=/usr/libexec/gcc-cross/aarch64-linux-gnu/15/cc1
$ dd if=$f iflag=direct bs=64k status=none | md5sum     # 磁盘
67d7fe9c4b8f4266a24e9d004ae46fd3
$ grep 'libexec/gcc-cross/aarch64-linux-gnu/15/cc1$' /var/lib/dpkg/info/cpp-15-aarch64-linux-gnu.md5sums
67d7fe9c4b8f4266a24e9d004ae46fd3   ← 官方包，逐字一致
$ md5sum < $f                                            # 经页缓存（同一时刻）
c475e4e7ac80958aae735474a769216e   ← 与官方不同
$ dpkg -V gcc-15-aarch64-linux-gnu
??5??????   /usr/libexec/gcc-cross/aarch64-linux-gnu/15/cc1
```

`cc1` 是 GCC 的**实际编译后端**。它的代码页被翻转 ⇒ 执行到该页时行为异常 ⇒
`internal compiler error` / 段错误。**这解释了 2026-10-19 那次「重装 gcc 后好一阵又坏」**：
重装只是让该文件的页缓存被重新填充，与环境无关，所以会"自愈"又会复发。

### 1.4 随机性量化（`build/m1-73` 全树，30 轮）

```
每轮 page_cache_corrupt: 0 0 1 0 0 0 1 0 0 2 3 1 0 0 1 0 3 1 0 0 0 0 0 0 0 0 2 1 1 0
30 轮累计命中 = 17
```

- **每轮命中的文件不同**（`ipuv3-plane.c`、`TreeRCU-gp.svg`、`cache-feroceon-l2.c` …）
- 磁盘真值 30 轮全部正确（`disk_suspect=0`）
- 单发阴性 ≠ 通过 ⇒ 体检门必须**多轮**

---

## 2. 为什么前两轮的归因是错的

| 旧结论（2026-10-19/20 报告） | 现在的事实 |
|---|---|
| 「文件内容被单字符改写，mtime/size 不变」 | 改写**不在文件里**，在页缓存；mtime 不变正是因为它没被写 |
| 「处置 = 修复损坏文件」 | 重写同样经过内存，可能写回错字节，还会**覆盖掉本来正确的磁盘副本** |
| 「重装 `gcc-15-aarch64-linux-gnu` 后 hello 恢复」 | 重装刷新了 `cc1` 的页缓存 ⇒ 看起来"修好了"；与包无关 |
| 「删掉坏 `.o` 串行重编即可收敛」 | 收敛是概率性的：下一轮换一批文件翻转 |
| 「git 不校验工作树 ⇒ 只能逐文件 sha1」 | 仍成立，但 sha1 **必须绕过页缓存**才反映真值 |

**危险副作用（本轮实际踩到）**：`build/m3v2-7.3rc7` 的 git pack 与 4 个 worktree 的 `index`
被误判为"损坏"，我用 `git cat-file` 重写了 11 个源文件。事后用 `O_DIRECT` 复核：
11 个文件的**磁盘内容全部等于 HEAD**（`corrupt=0`），即重写这次恰好没写坏，
但这纯属运气 —— 正确动作应该是**丢页缓存重读**，而不是重写。

> 附带修好的真实问题：`build/m3v2-7.3rc7` 的 pack 确有**物理损坏**
> （`pack-d19c589d….pack` 的 checksum mismatch + 8 个对象解压失败），
> 已用「从 `geekidos-linux` 补 loose 对象 → 全部 118 357 个对象逐个验 sha1 → 重建对象库」
> 修好；`git fsck` 非 reflog 错误 = 0。这一条与内存位翻转**是两个独立问题**，
> 但当时被同一批症状混在一起。

---

## 3. 现在能确认「没写坏」的范围

| 对象 | 判据 | 结果 |
|---|---|---|
| 6 棵内核树（`base-7.2`/`m1-73`/`m3v2`/`vk83`/`geekidos`/`linux`） | `verify-tree-integrity.py` 三读法 | `corrupt=0`（仅偶发 `cache=N`） |
| 项目文档仓库 | 同上 | `corrupt=0 dirty-ok=13` |
| 交叉工具链（`cc1`/`binutils`） | `O_DIRECT` md5 vs `dpkg` md5sums | 磁盘逐字一致 ✅ |
| 4 个 boot 镜像（vk64/vk127/boot_b-vk127/boot_b-vk129） | 三读法 + manifest sha | 一致 ✅（vk64 `983936396fd7bbac`、vk127 `7515f6a453dfd689`、boot_b-vk127 `dc2132636fba8699`、boot_b-vk129 `736bfe87cba197c9`） |
| 修过的 git 对象库（118 357 对象） | 逐对象重算 sha1 | 0 坏 ✅ |
| `/tmp/elden-obj`（修复中转） | 逐对象重算 sha1 | 0 坏 ✅ |

**不能确认的**：任何**曾经经过内存生成**的中间产物（`.o`、`.a`、ramdisk、打包镜像）
在生成时刻是否带翻转位 —— 只能用 manifest 的 sha 事后比对（上表 4 个镜像已比对通过）。

---

## 4. 硬件侧的判断

| 项 | 值 | 含义 |
|---|---|---|
| CPU | i7-14700KF | 无 ECC 支持（消费级） |
| 主板 | ASUS PRIME Z790-P **D4** | 支持 ECC 内存但**按非 ECC 模式运行** |
| 微码 | `0x133` | 已含 0x12B Raptor Lake 缓解，**不是** Vmin Shift 那一类 |
| EDAC | `/sys/devices/system/edac/mc/` 只有 `power`，无 `mc0` | 硬件**无法**报告 CE/UE |
| `dmesg` MCE | 0 条 | 没说没发生，只是没人记录 |
| 内存 | 61 GiB（DDR4） | 容量大 ⇒ 命中面积大 |

用户侧信息：**今天已通过三轮 `stress-ng`，本次上电至今无内核卡死/应用崩溃**。

> 这不与结论矛盾：`stress-ng` 默认不校验数据完整性（除非带 `--verify`），
> 静默位翻转对它是不可见的；且翻转是**概率事件**（30 轮里 17 轮命中 0–3 个文件，
> 也可能整轮为 0）。所以「今天稳定」≠「内存已修好」。

---

## 5. 交付物（均为新增，可直接用）

| 文件 | 作用 |
|---|---|
| `scripts/detect-memory-corruption.py`（新） | **三读法**判页缓存翻位：buffered / 丢缓存 / `O_DIRECT`；支持 `--tree` 全树扫描（96 k 文件 ≈ 9 s）；退出码 0=一致 / 1=MEMORY / 2=磁盘真坏 |
| `scripts/verify-tree-integrity.py`（改） | mismatch 后自动丢页缓存重读 + `O_DIRECT` 复核；输出分 `CORRUPT`（磁盘真坏）与 `CACHE`（页缓存翻位）；**`CACHE` 不再判失败** |
| `scripts/kbuild-sanity.sh`（新） | 构建前后门：树完整性 + 多轮页缓存污染率 + 工具链 `dpkg -V` + `-O2` 编译探针；任一轮命中即 FAIL 并打印处置顺序 |
| `scripts/rebuild-vk64-image.sh`（改） | 前后两处门改为调用 `kbuild-sanity.sh`（`SANITY_ROUNDS` 可调），并更新注释说明「CACHE ≠ CORRUPT」 |

### 用法

```bash
# 构建前（建议每次；--rounds 默认 2，翻位频繁时可加到 5）
scripts/kbuild-sanity.sh build/m1-73 --before --allow-dirty

# 只想知道某个文件是不是真坏
scripts/detect-memory-corruption.py <path>...

# 全树扫一遍
scripts/detect-memory-corruption.py --tree build/m1-73
```

---

## 6. 处置建议（按代价排序）

1. **BIOS：关 XMP/EXPO，内存回到 JEDEC 默认频率**，放宽主/次时序（`PRIME Z790-P D4` 现为 BIOS `1836` / 2026-04-16）。
   这是**最可能有效**的一步 —— 位翻转的概率与频率/电压/时序余量强相关。
2. **单条内存排查**：只插一条跑体检门，逐个换；能定位到具体条。
3. **`memtest86+` 至少 4 轮 pass**（夜间跑）。注意：memtest 覆盖的是 DRAM 阵列，抓不到 CPU cache 内翻转，
   所以 memtest 全绿也不能完全排除，但红了一定是。
4. **降 CPU 侧余量**：关 PBO/超频、锁 `PL1/PL2`、必要时 `IA/SA` 电压偏移 +offset、
   或临时把倍频降到基频 —— Raptor Lake 的 `-KF` 型号在高频/高 SoC 电压下更容易出现不稳定。
5. **长期**：换 ECC 平台（W680/服务器板 + ECC UDIMM），才能把「静默翻转」变成「可报告的 CE/UE」。
6. **软件侧兜底（已落地）**：本文件的 3 个脚本已把「读到的字节是否可信」变成可判定项；
   构建流程已强制过门。**发现 MEMORY 时不要重写文件**，只需丢缓存（工具已做）。

---

## 7. 对项目其它结论的影响

- `PITFALLS` #282–#285 的主题（「构建机静默文件损坏」）**结论需要改口径**：
  现象成立，但**归因从「文件/磁盘」改为「内存页缓存」**，处置从「重写文件」改为「丢缓存 + 修硬件」。
- 2026-10-19/20 那批「随机 ICE、`bad reloc symbol index`、`member … not an object`」
  全部与内存翻位自洽，**不需要**再怀疑交叉工具链版本或内核源码。
- 本日之前所有**构建产物**的可信度：已用 manifest sha 复核的 4 个镜像通过；
  其余未复核的镜像如需使用，应先 `detect-memory-corruption.py` 扫一遍再比 manifest。
- 与设备侧无关：设备（U2）的 Q24/Q28/T9/T10 结论**不受影响**。
