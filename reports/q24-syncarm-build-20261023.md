# Q24 单变量臂构建 — rpmhpd sync_state 关闭（7.2 血统 / vk64 台架）

- 日期：2026-10-23
- lane：Q24 / Konrad 单变量臂（主机侧构建，未接触设备）
- 设备验证状态：**NOT_TESTED_ON_DEVICE**
- 基线镜像：`out/boot-elden-vk64.img`（manifest `out/boot-elden-vk64.manifest`）

## 0. 单变量声明

与 vk64 的差异**只有**：
1. `drivers/pmdomain/qcom/rpmhpd.c`：`rpmhpd_driver.driver.sync_state` 赋值被删除（不再调用 `rpmhpd_sync_state()`）；
2. `.config` 的 `CONFIG_LOCALVERSION` / `CONFIG_LOCALVERSION_AUTO` 两项（把 UTS 钉成 vk64 的字符串）。

DTB、ramdisk、cmdline、mkbootimg 全部参数逐项照抄 vk64 manifest。

---

## 1. 建树

| 项 | 值 | 命令来源 |
|---|---|---|
| 工作树 | `/home/xuqianhui/y700-elden/build/vk64-sync-arm` | 见下 |
| HEAD | `d02658e63cf607e71231b077ddd73f42408463c0` | `git -C build/vk64-sync-arm rev-parse HEAD` |
| 构建方式 | `git worktree add --detach`（未复制 20 GB） | 见命令 |
| 工作树大小 | 1.8 GB（`du -sh`） | `du -sh build/vk64-sync-arm` |
| `git status --porcelain` | **空（干净）** | `git -C build/vk64-sync-arm status --porcelain` |
| 子树所在仓库 | `linux` → symlink → `geekidos-linux` | `ls -l linux` |

命令：

```
git -C linux worktree add --detach /home/xuqianhui/y700-elden/build/vk64-sync-arm d02658e63cf607e71231b077ddd73f42408463c0
```

〔已证实〕**找到了 manifest 里的那个提交**，无需退让到 tag vk64 的解析值。
澄清一条容易踩的事实：`refs/tags/vk64` 是 **annotated tag**，`git rev-parse vk64`
打印的是 **tag 对象** `f595a1f5b0`，而 `git rev-parse 'vk64^{commit}'` / `git cat-file -p refs/tags/vk64`
显示其 object 就是 `d02658e63cf607e71231b077ddd73f42408463c0`。所以
「linux 的 tag vk64 指向 f595a1f5b0」是对 annotated tag 的误读，实际构建提交与 vk64 manifest
的 `kernel_git_head` **完全一致**。证据：

```
$ git -C linux cat-file -p refs/tags/vk64 | head -3
object d02658e63cf607e71231b077ddd73f42408463c0
type commit
tag vk64
$ git -C linux rev-list --count d02658e63..vk64^{commit}
0
```

因此本次构建**没有任何提交偏差**（见 §7 风险节的更正说明）。

## 2. 单变量补丁

| 项 | 值 |
|---|---|
| 改动文件 | `drivers/pmdomain/qcom/rpmhpd.c` **唯一一个** |
| 改动内容 | `rpmhpd_driver.driver.sync_state = rpmhpd_sync_state` 一行注释掉（+6/-1，含说明注释） |
| diff 落盘 | `patches/candidate-q24-syncarm/0001-pmdomain-rpmhpd-disable-sync_state.patch` |
| diff sha256 | `56825041996cce9cd1f59357996195b7e9aa52d64bd2e8efa0ff8088f426772f`（`sha256sum`） |
| diff 行数 | 18（`wc -l`） |
| 工作树改动清单 | `M drivers/pmdomain/qcom/rpmhpd.c`（`git status --porcelain`，仅此一行） |

机制说明〔已证实，源码 `drivers/pmdomain/qcom/rpmhpd.c:973-991`〕：
`rpmhpd_aggregate_corner()` 在 `pd->state_synced == false` 且无 `presync_floor` 时走
`this_active_corner = this_sleep_corner = pd->level_count - 1`（= 最高 corner）。
不注册 `.sync_state` ⇒ `state_synced` 永不为 true ⇒ 所有无 presync_floor 的 rail **恒定钉在最高档**，
正是 Konrad 的单变量设计意图。`sync_state` 仍是 `static` 函数，`CONFIG_WERROR` 未启用
（`patches/config-vk40-bringup:42` 为 `# CONFIG_WERROR is not set`），未使用警告不致命。

## 3. 配置（.config）

命令：

```
cp patches/config-vk40-bringup .config        # sha256 = a383cdb99dfee7a9f7a21c915541af05edf6efa3d2bb7cda552b270a263cbf4d
sed -i 's/^CONFIG_LOCALVERSION="-debug"$/CONFIG_LOCALVERSION="-debug-vk64-gd02658e63cf6"/; \
        s/^CONFIG_LOCALVERSION_AUTO=y$/# CONFIG_LOCALVERSION_AUTO is not set/' .config
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
```

| 项 | 值 | 命令来源 |
|---|---|---|
| 基础 config | `patches/config-vk40-bringup`，sha256 `a383cdb9…cbf4d` | `sha256sum` |
| UTS 钉法 | `CONFIG_LOCALVERSION="-debug-vk64-gd02658e63cf6"` + `# CONFIG_LOCALVERSION_AUTO is not set` | `grep -n CONFIG_LOCALVERSION .config` |
| olddefconfig 后 .config sha256 | `2a61704d1abed79cc9d4c9cf01e820492cc4a3f7ad57cad2ca3d924b68a942cd` | `sha256sum .config` |
| `CONFIG_ARCH_QCOM` | `=y`（第 372 行） | `grep` |
| `CONFIG_DRM_MSM` | `=y`（第 6079 行） | `grep` |
| `CONFIG_WERROR` | 未启用（基础 config 第 42 行） | `grep` |

`olddefconfig` 后相对 `patches/config-vk40-bringup` 的**全部**差异（`diff patches/config-vk40-bringup .config`）：

```
14,16c14,16
< CONFIG_RUSTC_VERSION=109801 / CONFIG_RUSTC_LLVM_VERSION=220108 / CONFIG_RUSTC_LLVM_MAJOR_VERSION=22
> CONFIG_RUSTC_VERSION=0 / CONFIG_RUSTC_LLVM_VERSION=0 / CONFIG_RUSTC_LLVM_MAJOR_VERSION=0
27,32c27
< CONFIG_RUSTC_HAS_SPAN_FILE=y … CONFIG_RUSTC_HAS_SUSPICIOUS_RUNTIME_SYMBOL_DEFINITIONS=y / CONFIG_PAHOLE_VERSION=0
> （5 项 RUSTC_HAS_* 消失）/ CONFIG_PAHOLE_VERSION=131
43,44c38,39
< CONFIG_LOCALVERSION="-debug" / CONFIG_LOCALVERSION_AUTO=y
> CONFIG_LOCALVERSION="-debug-vk64-gd02658e63cf6" / # CONFIG_LOCALVERSION_AUTO is not set
11614a11610,11611
> # CONFIG_DEBUG_INFO_BTF is not set / CONFIG_PAHOLE_HAS_LANG_EXCLUDE=y
```

差异分类〔已证实〕：
- **主动改动（2 项）**：`CONFIG_LOCALVERSION`、`CONFIG_LOCALVERSION_AUTO` —— UTS 钉死所需，唯一有意改动。
- **工具链自导（其余，均非语义）**：
  - `CONFIG_RUSTC_VERSION` / `RUSTC_LLVM_VERSION` / `RUSTC_LLVM_MAJOR_VERSION` 由 `109801/220108/22` 变 `0/0/0`
    —— 本机无 `rustc`（`which rustc` → 未找到）；
  - `CONFIG_RUSTC_HAS_*` 5 项消失、`CONFIG_PAHOLE_VERSION` 由 `0` 变 `131`（`pahole --version` → v1.31）；
  - 新增 `CONFIG_PAHOLE_HAS_LANG_EXCLUDE=y`、`# CONFIG_DEBUG_INFO_BTF is not set`。
  这些**全部是 debug-info / 工具链能力描述符**，不影响 vermagic、不影响任何驱动或 ABI；
  且 `CONFIG_RUST` 未启用（`grep -nE '^CONFIG_RUST=' .config` 无命中），Rust 不参与构建。
- 注：vk64 manifest 记录的 `config_sha256=ba18b24…` ≠ 基础 config 的 `a383cdb9…`，说明 **vk64 当年的 .config 也是 olddefconfig 之后的状态**（含同类工具链自导项）。因此本 config 与 vk64 实际 .config 的差异〔推测〕**同样只有上述 2 项 LOCALVERSION**，但因 `build/vk83-tree` 已被清理，**无法直接 diff 验证**。

## 4. 构建

```
cd build/vk64-sync-arm
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION= -j28 Image.gz dtbs
```

| 项 | 值 | 命令来源 |
|---|---|---|
| 编译器 | `aarch64-linux-gnu-gcc (Ubuntu 15.2.0-16ubuntu1) 15.2.0`，GNU ld 2.46 | 从 Image 内 UTS 串读出 |
| 并行度 | `-j28` | `nproc` = 28 |
| 结果 | **一次通过**；无 ICE / SIGSEGV / `bad reloc`，**未重跑** | `grep -nE "ICE\|internal compiler error\|bad reloc\|make.*Error" /tmp/q24-build.log` 无命中 |
| 警告总数 | **1 条**：`drivers/pmdomain/qcom/rpmhpd.c:1201:13: warning: 'rpmhpd_sync_state' defined but not used [-Wunused-function]` | `grep -c "warning:"` |
| 该警告性质 | 单变量补丁的**预期**副作用（函数保留、不再注册）；`CONFIG_WERROR` 未启用，不致命 | `patches/config-vk40-bringup:42` |
| `include/config/kernel.release` | `7.2.0-debug-vk64-gd02658e63cf6` | `cat` |

### 4.1 UTS 核对（双向判据）

| 判据 | 值 |
|---|---|
| 树 `make LOCALVERSION= kernelrelease` | `7.2.0-debug-vk64-gd02658e63cf6` |
| Image 内 `strings`/解压出的 UTS | `Linux version 7.2.0-debug-vk64-gd02658e63cf6 (xuqianhui@xuqianhui) (aarch64-linux-gnu-gcc …) #1 SMP PREEMPT …` |
| vermagic（Image 内） | `7.2.0-debug-vk64-gd02658e63cf6 SMP preempt mod_unload aarch64` |
| 两者比对 | **MATCH=yes** |
| manifest `kernel_release_matches_image` | `yes` |

`LOCALVERSION` 必须**显式赋空串**，实测对照〔已证实〕：

```
$ make -s ... LOCALVERSION= kernelrelease   → 7.2.0-debug-vk64-gd02658e63cf6      ← 正确
$ make -s ... kernelrelease                 → 7.2.0-debug-vk64-gd02658e63cf6+     ← 多个 '+'
```

（原因：`scripts/setlocalversion:201` —— `LOCALVERSION` 未设置时走 `scm_version --short` 分支追加 `+`。）

### 4.2 产物 sha256（最终态）

| 产物 | sha256 | 大小 |
|---|---|---|
| `arch/arm64/boot/Image` | `2696543452a78008bb0ad93a822fec2b36055ce16e57b51c8b62dd45e54fd9a4` | 62,540,288 |
| `arch/arm64/boot/Image.gz` | `cf2eaeb9b07b9309ea59611fbf38cf87a847ee0d25584326936a325dfb2c822c` | 20,572,837 |
| `arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb` | `386cc9bd5d243425dd342a9acd703f839bcb133318430b77be5ba675b90d10cb` | 149,051 |
| `.config`（olddefconfig 后） | `2a61704d1abed79cc9d4c9cf01e820492cc4a3f7ad57cad2ca3d924b68a942cd` | — |

〔已证实〕**DTB sha256 与 vk64 manifest 的 `dtb_sha256` 逐字相同** ⇒ DT 侧零差异，唯一改动确实只在 kernel 的 rpmhpd。

### 4.3 单变量证据（对象级）〔已证实〕

在同一棵树上把补丁 stash 掉、只重编 `rpmhpd.o`，再与打补丁版本对比：

| 文件 | sha256 | .text | .data |
|---|---|---|---|
| 基线 `rpmhpd.o`（无补丁） | `70d0362656cc0fa5898da48a8b8463bdbd4077178479c6868760bd94151e6ed5` | 10150 | 44880 |
| 打补丁 `rpmhpd.o` | `79303174fac114455abc5d2eb816e0a15204ea5e0f67f127242487b8ab56feda` | 9870（−280） | 44872（−8） |

符号级差异（`aarch64-linux-gnu-nm -S` 双向集合差）：

- **只在基线有**：`rpmhpd_sync_state`、`__initcall__kmod_rpmhpd__461_1245_rpmhpd_init1`
- **只在补丁版有**：`__initcall__kmod_rpmhpd__461_1250_rpmhpd_init1`
- **同名符号的 size/type 差异：无**

即：编译器把未被引用的 `rpmhpd_sync_state` 整个丢弃（`-280 B .text`），`rpmhpd_driver` 里
那一个函数指针（`-8 B .data`）归零。`diff <(objdump) <(objdump)` 的正文差异全部落在
「函数地址重排」上，无其它语义变化。

链入内核后的交叉验证：`grep -i rpmhpd System.map`

```
ffff800080c8fe88 t rpmhpd_probe
ffff800080c901c8 t rpmhpd_aggregate_corner
ffff800080c90350 t rpmhpd_set_performance_state
ffff800080c90448 t rpmhpd_power_on
ffff800080c904d0 t rpmhpd_power_off
ffff8000839193f0 d rpmhpd_driver
```

`rpmhpd_sync_state` **在 System.map 里 0 次命中**（`grep -c` = 0）⇒ 内核中确实不存在
sync_state 回调，无法被任何指针引用。

## 5. 打包

参数逐项照抄 vk64 manifest 的 `mkbootimg_args`，**只替换 kernel/dtb 路径与 `-o`**：

```
python3 scripts/mkbootimg.py --header_version 2 --os_version 15.0.0 --os_patch_level 2025-08 \
  --kernel build/vk64-sync-arm/arch/arm64/boot/Image.gz \
  --ramdisk out/rootfs-vk127.cpio.gz \
  --dtb build/vk64-sync-arm/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb \
  --cmdline "console=ttyGS0,115200 console=tty0 loglevel=8 ignore_loglevel printk.devkmsg=on panic=15 clk_ignore_unused pd_ignore_unused arm-smmu.disable_bypass=0 elden_root=LABEL=linux17 androidboot.slot_suffix=_b elden_nocamera=1" \
  --base 0x00000000 --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 \
  --second_offset 0x00f00000 --tags_offset 0x00000100 --dtb_offset 0x01f00000 \
  --pagesize 4096 -o out/boot-elden-vk64-syncarm.img
```

| 项 | 值 |
|---|---|
| 输出 | `/home/xuqianhui/y700-elden/out/boot-elden-vk64-syncarm.img` |
| 大小 | 85,352,448（与 vk64 相同：各段按 4096 页对齐后总长不变） |
| image sha256 | `93bbc4e265ae06a0e302f86d741137cace8d9f233ab60d719069804042435815` |
| manifest | `out/boot-elden-vk64-syncarm.manifest`（`scripts/build-manifest.sh vk64-syncarm` 生成，sha `2fe6590a103d6b3e…`，未手写） |
| kernel_payload_sha256（解压后内核身份） | `2696543452a78008bb0ad93a822fec2b36055ce16e57b51c8b62dd45e54fd9a4` |

### 5.1 镜像结构逐字段对比

```
python3 scripts/mkbootimg.py --unpack out/boot-elden-vk64.img        --unpack-dir /tmp/un-a
python3 scripts/mkbootimg.py --unpack out/boot-elden-vk64-syncarm.img --unpack-dir /tmp/un-b2
```

| 头字段 | vk64 | syncarm | 判定 |
|---|---|---|---|
| magic | `ANDROID!` | `ANDROID!` | SAME |
| kernel_size | 20571386 | 20572837 | DIFF（预期） |
| kernel_addr | 32768 | 32768 | SAME |
| ramdisk_size | 64622358 | 64622358 | SAME |
| ramdisk_addr | 16777216 | 16777216 | SAME |
| second_size | 0 | 0 | SAME |
| second_addr | 15728640 | 15728640 | SAME |
| tags_addr | 256 | 256 | SAME |
| page_size | 4096 | 4096 | SAME |
| dtb_size 字段 | 2 | 2 | SAME |
| dtb_addr | 503316787 | 503316787 | SAME |
| header_version | 2 | 2 | SAME |
| 文件总长 | 85352448 | 85352448 | SAME |

段级 sha256（`sha256sum /tmp/un-a/* /tmp/un-b2/*`）：

| 段 | vk64 | syncarm | 判定 |
|---|---|---|---|
| kernel（Image.gz） | `2894b62d36f54609a2f36306c524b40d93aa64b2234ee7695f7420ccbe98c611` | `cf2eaeb9b07b9309ea59611fbf38cf87a847ee0d25584326936a325dfb2c822c` | DIFF（**唯一允许的差异**） |
| ramdisk | `4d4834e681fcf3caafffb6f1ac640c9f424ac46bc25ec456a5a552e515fc50ec` | `4d4834e681fcf3caafffb6f1ac640c9f424ac46bc25ec456a5a552e515fc50ec` | **SAME** |
| dtb | `386cc9bd5d243425dd342a9acd703f839bcb133318430b77be5ba675b90d10cb` | `386cc9bd5d243425dd342a9acd703f839bcb133318430b77be5ba675b90d10cb` | **SAME** |
| cmdline（解包打印） | — | — | 逐字相同 |

〔已证实〕**打包层单变量成立**：镜像内 ramdisk 与 dtb 字节级相同，仅 kernel payload 变化。

附注（非本 lane 引入）：vk64 镜像头里 `dtb_size` 只记了 2 字节，实际 dtb 段 149051 字节；
本镜像**同样复现**该 quirk（`scripts/mkbootimg.py` 的既有行为），属「与 vk64 一致」。

## 6. 门禁

| 检查 | 命令 | 结果 |
|---|---|---|
| ABI/config 门（默认 ref = `patches/config-vk127-working-*`） | `bash scripts/check-abi-config.sh build/vk64-sync-arm/.config` | ✅ ABI 敏感项与参考一致（27 项） |
| 同一门禁，ref = `patches/config-vk40-bringup` | `bash scripts/check-abi-config.sh --ref patches/config-vk40-bringup build/vk64-sync-arm/.config` | ✅ 一致（27 项） |
| 内核闸门 | `KDIR=build/vk64-sync-arm bash scripts/assert-kernel-sane.sh` | ✅ 通过：config 锚点（`ARCH_QCOM` / `DRM_MSM` / `DRM_MSM_DSI` = y）、System.map 符号（`gcc_sm8750` / `msm_dsi_host_bonded_cmd_trigger` / `qcom_rpmh`）、非陈旧 |
| 闸门内 UTS 对齐 | 同上 | ⚠️ 脚本内 `kbuild` 固定 `make -C $ROOT/linux`，对被 gate 的树取不到 release → **打印跳过**；已用 §4.1 的双向手工判据替代（MATCH=yes） |

## 7. 风险与偏差

### 7.1 偏差清单（相对 vk64 manifest）

| # | 项 | vk64 | 本镜像 | 性质 |
|---|---|---|---|---|
| 1 | kernel 源码 | `d02658e63` clean | `d02658e63` + rpmhpd 补丁 | **主动单变量** |
| 2 | `CONFIG_LOCALVERSION` | `-debug`（+ AUTO=y） | `-debug-vk64-gd02658e63cf6`（AUTO off） | **主动**，为复用机内模块树 |
| 3 | `RUSTC_*` / `PAHOLE_*` / `DEBUG_INFO_BTF` | （未知，树已删） | 本机工具链自导值 | 工具链自导，无行为影响 |
| 4 | DT 提交 | `d02658e63` | `d02658e63` | **无偏差** |
| 5 | DTB 字节 | `386cc9bd…` | `386cc9bd…` | **无偏差** |
| 6 | ramdisk 字节 | `4d4834e6…` | `4d4834e6…` | **无偏差** |
| 7 | cmdline / mkbootimg 参数 | — | 逐字相同 | **无偏差** |

**提交偏差：无。** 任务书里「linux 的 tag vk64 指向 `f595a1f5b0`」是**对 annotated tag 的误读**：
`refs/tags/vk64` 是 annotated tag，其 *tag 对象* 是 `f595a1f5b0`，`object` 行才是
`d02658e63cf607e71231b077ddd73f42408463c0`（= manifest 的 `kernel_git_head`）。证据：

```
$ git -C linux cat-file -p refs/tags/vk64 | head -2
object d02658e63cf607e71231b077ddd73f42408463c0
type commit
$ git -C linux rev-list --count d02658e63..'vk64^{commit}'
0
```

### 7.2 风险

1. **模块树复用未上机验证**〔推测成立、待设备确认〕：复用 `/lib/modules/7.2.0-debug-vk64-gd02658e63cf6/` 的 1497 个 `.ko`。
   vermagic 逐字相同（§4.1），ABI 敏感 27 项与参考一致（§6），但仍需设备侧确认无 `-EINVAL`/unknown symbol。
2. **`CONFIG_DEBUG_INFO_BTF` 由 y 变 not set**（若 vk64 当时为 y）：只影响调试信息/BTF 段，不影响
   运行映像与 vermagic；`DTB`/`ramdisk` 已证明零差异。
3. **构建非字节可复现（已量化）**：同一棵树、同一补丁、同一命令重链接四次，`Image.gz` 依次为
   `4d70d304…` → `1671a8f6…` → `cf2eaeb9…`（`init/version-timestamp.o` 每次重建、`.rodata` 里的
   编译时间戳随之变化）。但 `rpmhpd.o` 每次编译**字节完全相同**（`79303174…`，三次一致）
   ⇒ 代码差异本身是确定的，不确定性只在时间戳。
   **最终交付态 = 本文 §5 与 `out/boot-elden-vk64-syncarm.manifest` 的 sha**：
   image `93bbc4e2…`，kernel payload `2696543452…`，Image.gz `cf2eaeb9…`。
   判据请用 `kernel_payload_sha256`（解压后内核身份），不要用中间产物。
4. **语义风险（本 lane 不判定）**：所有 rail 钉在最高档可能导致功耗/发热显著上升，或与
   `presync_floor`（GMU 管理 rail 走另一分支）的交互不同；这是实验本身要测的东西。
5. **vmlinux 调试符号**：本 lane 只要求 `Image.gz + dtbs`，未构建 `modules`；
   `vmlinux`（669 MB，unstripped）留在 `build/vk64-sync-arm/`，未清理。

### 7.3 工作树状态（供编排者审）

```
$ git -C build/vk64-sync-arm status --porcelain
 M drivers/pmdomain/qcom/rpmhpd.c
$ git -C build/vk64-sync-arm rev-parse HEAD
d02658e63cf607e71231b077ddd73f42408463c0
```

未 commit、未触碰设备、未发邮件。项目仓 HEAD `0307c0c5670530a09dcf88cf0f503a891f339a6c`。
