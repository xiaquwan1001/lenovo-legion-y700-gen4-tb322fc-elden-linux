# 宿主机构建环境「静默文件损坏」取证（2026-10-19/20）

> **一句话**：内核树里多个 tracked 文件被**单字符改写**，大小/mtime 不变、`git status` 显示干净；
> 结果是交叉编译随机 ICE/段错误、`ld` 报 `bad reloc symbol index`。
> 这不是源码/编译器版本问题，**git 也查不出来**——只有逐文件 sha1 对 index 才能发现。
> 处置：修复损坏文件 + 把完整性校验固化进构建脚本 + 重建 vk64 镜像（已成功）。

---

## 0. 数字结论

| 项 | 值 |
|---|---|
| 受损 tree | `build/vk83-tree`（4 个）、`build/m1-73`（3 个，但**是良好本地修改**）、项目 repo（1 个，同上） |
| 真正损坏文件数 | **vk83-tree 4 个**（另有 2 个在本轮早期已修：`nfstrace.h`、`serial_bcm63xx.h`） |
| 损坏形态 | **单字符替换/插入**，文件大小与 mtime **均不变** |
| 扫描成本 | 9.5 万文件 ≈ **2 s**（32 线程 sha1） |
| 全数校验结果 | 7 棵树 **corrupt=0**（修完） |
| vk64 镜像 | **已重建成功**：`out/boot-elden-vk64.img`（85 352 448 B，sha256 `983936396fd7bbac…`），内嵌 UTS 逐字 = `7.2.0-debug-vk64-gd02658e63cf6` |
| DTB | sha256 `386cc9bd5d243425…` **与历史 vk64 manifest 逐字相同**（强证据：树与配置确为原配方） |

---

## 1. 症状序列（按发生顺序）

1. 运行 `scripts/rebuild-vk64-image.sh` → 内核构建在**不同文件**上轮流崩：
   - `internal compiler error: in scev_initialize, at tree-scalar-evolution.cc:3017`（`gpio-blzp1600.c`、`blk-mq.c`、`fcntl.c`、`kobject.c` …）
   - `internal compiler error: 段错误`（`nfs4xdr.c`、`tegra186.c`）
   - `error: unterminated argument list invoking macro 'TRACE_EVENT'`（`nfstrace.h`）
2. 用最小样例定位：`aarch64-linux-gnu-gcc -O2 -c hello.c` **也崩** ⇒ 先怀疑交叉工具链。
3. 用户重装 `gcc-15-aarch64-linux-gnu` 后 hello 恢复（`-O1/-O2/-O3` 全 OK），但**内核树里仍崩**。
4. 于是逐文件 sha1 比对 index ⇒ 揪出被改写的源文件（见 §2）。
5. 修复源文件后，链接阶开始报新错：`bad reloc symbol index (0x827 >= 0x60) ... '.debug_info'`、
   `member lib/raid/raid6/int2.o in archive is not an object` —— **每次换一个对象**。
6. 全树扫描 `.o`（只对 AArch64 对象做 `ld -r`）→ 只剩 1 个坏对象（`libps2.o`），删掉重编后**全量链接通过**。

---

## 2. 被改写的文件与具体差异

| 文件 | 差异 |
|---|---|
| `fs/nfs/nfstrace.h` | `__field(int, error)` → `__field(int( error)` ← 直接导致宏参数不闭合 |
| `include/linux/serial_bcm63xx.h` | `UART_FIFO_PARERR_MASK` → `IUART_FIFO_PARERR_MASK` |
| `drivers/gpu/drm/amd/include/asic_reg/mmhub/mmhub_9_4_1_offset.h` | 宏值前插入一个反引号 `` ` `` |
| `drivers/gpu/drm/amd/include/asic_reg/nbio/nbio_7_11_0_sh_mask.h` | 单字符改写（同类） |
| `drivers/net/ethernet/broadcom/bnx2x/bnx2x_reg.h` | `MSTAT_REG_TX_STAT_GTXPOK_LO` → `M[TAT_REG_TX_STAT_GTXPOK_LO` |
| `kernel/trace/trace_probe.c` | 单字符改写（同类） |

特征：**全部是「一个字符级」的改动，且都破坏语法/标识符**——与硬盘坏道、编译期写坏不同，
更像内存位翻转在文件缓存写回时落盘（本机 `EDAC ie31200: No ECC support` ⇒ 硬件无法发现）。

---

## 3. 已排除的原因

| 假设 | 排除依据 |
|---|---|
| `/tmp`（tmpfs）写坏 | 受影响文件全在 `build/`（ext4 on NVMe），与 `/tmp` 无关 |
| 编译期把输出写坏 | 损坏的是**源文件**（`.c/.h`），且在编译开始前就存在 |
| git 操作/checkout 造成 | 多处时间戳仍是 2026-10-17 16:42（初始 clone 时间），期间无 checkout |
| 磁盘 I/O 错误 | 3 × 600 MB `urandom` 写入→`sync`→回读 sha 全部一致；`dmesg` 无 ext4/nvme 错误 |
| ECC 报错 | 本机 `EDAC ie31200: No ECC support` —— **无从报告**，不是「没发生」 |
| 交叉编译器本身 | 重装后 hello 正常；且**坏源文件修好后**内核一次性编译通过 |
| `ccache` 投毒 | 清空 `~/.cache/ccache-elden` 后仍复现；后续构建用 `CCACHE_DISABLE=1` |

未定性：**触发条件未知**（跨多棵树、跨两天、无 git 操作时发生）。怀疑内存/缓存层位翻转，
但本机无 ECC 无法取证；`journalctl --list-boots` 显示 2026-10-19 19:21–21:51 间**重启 6 次**，
宿主自身稳定性也有问题（见 §6）。

---

## 4. 固化进工具链的三道门

| 门 | 位置 | 行为 |
|---|---|---|
| **编译前全树完整性** | `scripts/rebuild-vk64-image.sh` → `scripts/verify-tree-integrity.py <tree> --allow-dirty -q` | 有损坏 → 打印文件名并**拒绝编译** |
| **编译后全树复验** | 同上，编译完成后 | 编译期间新增损坏 → **丢弃产物** |
| **坏对象迭代隔离** | 同上，构建重试环 | 从 `ld` 报错里提取被点名的 `.o` → 删除 → 下一轮串行重编，最多 4 轮 |

`verify-tree-integrity.py` 的关键设计：
- 判据是 `sha1("blob <len>\0" + 内容)` vs **git index 的 blob sha**（不是 HEAD，也不是 mtime）；
- `--allow-dirty` 读 `git status` 豁免**有意的本地修改**（否则 `build/m1-73` 的 AGC 修会被误报）；
- 只报 `CORRUPT`，`dirty-ok` 单独计数 —— 让「改动」和「损坏」在输出上不可混淆。

---

## 5. 产出与复现

```bash
# 全树体检（~2 s / 9.5 万文件）
scripts/verify-tree-integrity.py build/vk83-tree --allow-dirty

# 修复（唯一正确姿势：从 object 库取回，不要 checkout —— 见下）
git -C build/vk83-tree cat-file -p HEAD:<path> > build/vk83-tree/<path>

# 重建 vk64（含三道门）
scripts/rebuild-vk64-image.sh --check-only   # 零编译预检
scripts/rebuild-vk64-image.sh                # 编内核 + 打包 + manifest
```

⚠️ **`git checkout -- <file>` 在本仓库不可靠**：实测对一个已损坏文件执行 `git checkout -f --` 后
内容**仍未恢复**（而 `git cat-file -p HEAD:<path> > <path>` 立即恢复）。原因未查（怀疑同一层缓存问题）。
⇒ 治损坏一律用 `cat-file` 重定向，改完再跑一次校验确认。

产物（已入库）：
- `out/boot-elden-vk64.img` + `out/boot-elden-vk64.manifest`
- `patches/m1-73-worktree-20261020/0001-worktree-agc-fix-and-adsp-non-secure-domain.patch`
  （把 `build/m1-73` 三处未提交修改固化，防被当垃圾清掉）

---

## 6. 宿主稳定性旁证（待用户裁决）

`journalctl --list-boots`（2026-10-19）：

```
-4 19:21:05 → 19:27:21
-3 19:27:46 → 19:58:23
-2 19:58:45 → 21:46:26
-1 21:47:03 → 21:47:14   ← 11 秒
 0 21:51:17 →
```

2.5 小时内 6 次启动，其中一次只有 11 秒 —— 与「内存/CPU 不稳」的观察一致。
建议（需用户执行/在场）：跑一轮 `memtest86+`；或启用 `CONFIG_EDAC` 可用的平台通道（本机不支持）；
在定位前，**重要构建产物一律带三道门 + 事后 sha 复核**。

---

## 7. 关联

- `PITFALLS` #282–#285（第 54 节）
- `scripts/rebuild-vk64-image.sh`、`scripts/verify-tree-integrity.py`
- `reports/migration-rebuild-audit-20261017.md`（换机后 `out/*.img` 丢失，本轮补建）
- `reports/q24-n5-vk64-death-reproduced-20261015.md`（N5b 需要本镜像）
