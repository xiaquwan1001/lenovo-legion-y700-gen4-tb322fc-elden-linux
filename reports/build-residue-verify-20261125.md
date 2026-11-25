# `build/` 对象残渣可重建性 —— 只读复核（2026-11-25）

> 性质：**只读取证 lane**。本文件是唯一写入。**未删除/移动任何文件**、未 git 写（无 add/commit/worktree/stash）、未 ssh/设备动作。
> 复核对象：上一轮瘦身 lane 的结论「`build/g7a-tree` + `build/g7-tree` 是同一 commit 的重复 checkout ⇒ 可删 ≈20.7 G」。
> 结论先行：**该结论的前提（"重复 checkout"）是错的**（两棵树是同一 commit 的**两份不同构建配置**）；但**结论本身**（两棵树都可不留）**成立**，因为两棵树各自的产物镜像与源码配方**都已在盘上归档且逐字节对得上**。判据见 §5，证据账见 §E。

---

## §0 数字先行

| 项 | 实测 | 判据 |
|---|---|---|
| `build/` 总量 | **27 G**（其中 `elden-tree` 2.6 G / `g7-tree` 7.5 G / `g7a-tree` 13 G / `g7b-vk185` 1.8 G / `uefi-woa-prep` 1.9 G） | E1 |
| 两棵树 apparent 字节 | g7-tree **7 660 786 890 B = 7.13 GiB**；g7a-tree **13 006 081 127 B = 12.11 GiB**；合计 **19.24 GiB**（`du -sh` 按块算 = 7.5+13 = **20.5 G**，与上轮 "≈20.7 G" 同量级） | E1, E20 |
| HEAD | 两者 **`aebb7274476403040d582c61478df8f4a7bf9cd3`**（= tag `v7.4-rc3`，detached） | E2 |
| 已跟踪改动 | 两者 `git diff` 全量 **sha256 相同 = `29a8bd76a61a7114…f08221e`**，9 文件 **+635/−5** | E3 |
| 未跟踪板 DTS | 两者**不同**：g7-tree `bfb536fb…`（5 384 B，11-21 19:28）／g7a-tree `eeb78f0b…`（70 576 B，11-23 14:20） | E4 |
| `.config` LOCALVERSION | `-g7-dwc3v11-20261121` ／ `-g7a-dwc3v11-reset-20261123` | E5 |
| `vmlinux` sha256 | `2d658f1b…79863c` ／ `c5a65828…ee056a`（**不同**） | E6 |
| 产物镜像是否还在 | **四个产物目录全在**：`out/g7-20261121`、`out/g7-routeA-20261121`、`out/g7-routeA-dtfix-20261123`、`out/g7-reset-20261123`；**两棵树当前产物都能逐一指到具体归档件** | E9–E14 |
| 源码可重建 | remote = `git.kernel.org/…/torvalds/linux.git`，tag `v7.4-rc3` 现在可达且 sha 与本地一致；重打 **7 枚**补丁（另有 1 枚 Route-A/re 版本专用）+ 1 份归档 DTS | E15–E17 |
| 全量编译时长（已有证据） | g7-tree **6:03.77** wall（user 5828 s）；routeA 全量 **7:30.89** wall；**增量重链 30–31 s**；routeA 增量 0:37.58 | E18 |
| 大单体 = 残渣主体 | 每树 `vmlinux.o` **1.65 GiB** + `vmlinux` 0.64 + `vmlinux.unstripped` 0.65 + `.tmp_vmlinux*` 0.26 = **3.20 GiB/树，两树 6.40 GiB**（占 19.24 GiB 的 33%） | E19 |
| **A 类可删合计** | 保守（只删链接产物、留树）**6.40 GiB**；彻底（删两棵 worktree）**19.24 GiB**（du 20.5 G） | §5 |

---

## §1 这两棵树到底是什么

### 1.1 逐项对比

| 维度 | `build/g7-tree` | `build/g7a-tree` | 同？ |
|---|---|---|---|
| `rev-parse HEAD` | `aebb7274476403040d582c61478df8f4a7bf9cd3` | 同 | ✅ |
| `describe --tags` | `v7.4-rc3-dirty` | 同 | ✅ |
| `remote -v` | `https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git`，`[blob:none]` | 同 | ✅ |
| gitdir | `build/elden-tree/.git/worktrees/g7-tree` | `…/worktrees/g7a-tree` | 同一对象库 |
| `status --short` | 9 `M` + 1 `??` | 同样 9 `M` + 1 `??`（同名同序） | ✅ |
| `git diff` sha256 | `29a8bd76…f08221e` | 同 | ✅ |
| 未跟踪板 DTS sha | `bfb536fb…`（5 384 B = **上游骨架 + USB mux**） | `eeb78f0b…`（70 576 B = **路线 A 全使能面**） | ❌ |
| `.config` `CONFIG_LOCALVERSION` | `-g7-dwc3v11-20261121` | `-g7a-dwc3v11-reset-20261123` | ❌ |
| `include/config/kernel.release` | `7.4.0-rc3-g7-dwc3v11-20261121-dirty` | `7.4.0-rc3-g7a-dwc3v11-reset-20261123-dirty` | ❌ |
| `vmlinux` | 692 052 840 B，`2d658f1b…`，Uts `elden@y700`，`KBUILD_BUILD_TIMESTAMP` 钉住 | 692 052 824 B，`c5a65828…`，Uts `xuqianhui@xuqianhui`，时间戳未钉 `Mon Nov 23 22:46:49 CST 2026` | ❌ |
| `vmlinux.o` | 1 774 064 272 B | 1 774 074 104 B | ❌ |
| built `Image.gz` | `a635102f…`（21 174 661 B） | `b8c6cb55…`（21 176 565 B） | ❌ |
| built `sm8750-lenovo-elden.dtb` | `88a2d748…`（105 057 B） | `dedc81bf…`（148 479 B） | ❌ |
| 模块 | 未编（0 `.ko`） | **1 508 个 `.ko`（1.73 GiB）**，`Module.symvers` 1.4 MB | ❌ |
| 内嵌 IKCONFIG | = 树 `.config` `373c2fb7…` | = 树 `.config` `622eead1…` | 各自自洽 |

### 1.2 结论

- **是同一个 commit、同一套已跟踪补丁**（7 枚，见 §3），所以 `git diff` 同 sha **只证明"补丁集相同"**，不是"重复 checkout"。
- **不是同一份构建**：`LOCALVERSION`、板 DTS（5.3 KB 骨架 vs 70 KB 全使能）、`vmlinux`/`Image.gz`/`dtb` 全部不同，g7a 还多编了 1 508 个模块。它们分别是 **11-21 dwc3-v11 USB 线（g7）** 与 **11-21 路线 A → 11-23 DT-fix / PSCI-reset 线（g7a）** 的两个工作树。
- ⇒ 上轮 lane 的**推理链有漏洞**（漏掉未跟踪 DTS 与 config 差异），但**结论仍需按"产物已归档"重新判定**，不能用"同 sha"当理由。

---

## §2 产物镜像是否还在，对不对得上

### 2.1 目录

| 目录 | 内容（关键件） |
|---|---|
| `out/g7-20261121/` | `Image.gz` `a635102f…`、`Image-with-rolehook.gz` `0ec80148…`、`boot.img` `00912631…`、`boot-with-rolehook.img` `727bb55f…`、`MANIFEST`/`MANIFEST-rolehook`、`config-g7.config` `373c2fb7…`、`sm8750-lenovo-elden.dtb` `88a2d748…`、`apply.log`、`build.log` |
| `out/g7-routeA-20261121/` | `Image.gz` `138dc1ad…`、`boot-elden-g7a.img` `d0c127ca…`、`boot-elden-g7a.manifest`、`board-dts-g7a.dts`（69 649 B）、`config-g7a.config` `186f7dcd…`、`sm8750-lenovo-elden.dtb` `5b6e9d1c…` |
| `out/g7-routeA-dtfix-20261123/` | `Image.gz` `138dc1ad…`（manifest 明写 "unchanged from g7a, not rebuilt"）、`boot-elden-g7a2.img` `79164085…`、`boot-elden-g7a2.manifest`、`board-dts-g7a2.dts`（70 576 B）、`sm8750-lenovo-elden.dts` 同 sha、`sm8750-lenovo-elden.dtb` `dedc81bf…`、`dtfix.diff` |
| `out/g7-reset-20261123/` | `boot-g7a-reset.img` `647784b7…`（22:18，**含 PSCI vendor-reset 钩子**）、`boot-g7a-ctl.img` `f79dcbcb…`（22:47，**不含钩子**）、`boot-g7a-ctl.manifest`（`kernel_sha256=b8c6cb55…`、`config_sha256=622eead1…`）、`README.md` |

### 2.2 对账（树现状 ↔ 归档件）

| 树当前产物 | 归档位置 | 对得上？ |
|---|---|---|
| g7-tree `Image.gz` `a635102f…` | `out/g7-20261121/Image.gz` 同名同 sha | ✅ **逐字节** |
| g7-tree `dtb` `88a2d748…` | `out/g7-20261121/MANIFEST:dtb_sha256` + 目录内 `sm8750-lenovo-elden.dtb` | ✅ |
| g7-tree `.config` `373c2fb7…` | `out/g7-20261121/config-g7.config` | ✅ **逐字节** |
| g7a-tree `Image.gz` `b8c6cb55…` | `out/g7-reset-20261123/boot-g7a-ctl.img` 的 `kernel_packed_sha256`；`boot-g7a-reset.img` 内同 UTS 内核 | ✅ |
| g7a-tree `dtb` `dedc81bf…` | `out/g7-routeA-dtfix-20261123/sm8750-lenovo-elden.dtb` + `g7a2.manifest:dtb_sha256` | ✅ |
| g7a-tree 板 DTS `eeb78f0b…` | `out/g7-routeA-dtfix-20261123/{board-dts-g7a2.dts,sm8750-lenovo-elden.dts}` | ✅ **逐字节** |
| g7a-tree `.config` `622eead1…` | **只有 manifest 里的 sha，没有明文 config 文件**（盘上唯一明文副本 = `build/g7a-tree/.config`） | ⚠️ **B 类**（§5.2） |
| 11-21 routeA `Image.gz` `138dc1ad…` / `dtb 5b6e9d1c` / `board-dts-g7a.dts` | `out/g7-routeA-20261121/` | ✅（注意：**该 DT 在两棵树里都已不存在** ⇒ 树从来不是它的来源） |

### 2.3 由此得到的判定

1. **两棵树当前状态都被归档件精确覆盖**（内核 Image.gz + config + dtb + 未跟踪 DTS 四件齐），因此 §2 判据"对不上 ⇒ C 不可删"**未触发**。
2. 反向还有一条更硬的事实：11-21 routeA 那枚 `Image.gz`（`138dc1ad…`）所对的板 DTS（`5b6e9d1c`/69 649 B）**已不在任何树里**，只存在于 `out/g7-routeA-20261121/` ⇒ **树天然不是唯一来源**，"删树=丢镜像"的担心不成立。
3. **唯一"树是唯一明文载体"的物项 = `g7a-tree/.config`（sha `622eead1…`）**（`kernel/config_data` 是它的同名副本）。它可从 `boot-g7a-ctl.img` 反解 IKCONFIG 恢复（`scripts/extract-ikconfig`，实测该 Image.gz 内嵌 config = 该 sha，E12），但**多一步、要解包 boot.img**，故列为 B（一条 `cp` 即可清零）。

---

## §3 源码可重建性

### 3.1 remote 与 commit

- `origin = https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git`，`partialclonefilter=blob:none`、`promisor=true`（E8）。
- 基点 commit `aebb7274476403040d582c61478df8f4a7bf9cd3` = annotated tag **`v7.4-rc3`**（tag 对象 `19d1b4de6d37bccecc3ad9144d279f1baa405eb1`，本地与 `git ls-remote` 远端**一致**；`git.kernel.org` 现可达，`info/refs` HTTP 200）（E15）。
- **离线可重建的判据**：`build/elden-tree` 仍检出同一 commit，且 `GIT_NO_LAZY_FETCH=1` 下 `cat-file -e` 对 `drivers/usb/dwc3/core.c`、`arch/arm64/boot/dts/qcom/sm8750.dtsi` 均命中（blob 在本地 720 M `.git` 里），因此删两棵 worktree 后仍可 `git -C build/elden-tree worktree add --detach <new> aebb727447` 离线重建（E16）。

### 3.2 需要重打的补丁（7 枚，顺序即 `out/g7-20261121/apply.log`）

| # | 补丁 | 作用 |
|---|---|---|
| 1 | `patches/upstream/board-dts-single-20261113/0001-arm64-dts-qcom-sm8750-lenovo-elden-add-Lenovo-Legi.patch` | 新建板 DTS（v7 骨架）+ `Makefile` |
| 2 | `patches/upstream/elden-dts-v8-prep-20261121/0000-dt-bindings-arm-qcom-document-the-Lenovo-Legion-Y700.patch` | `qcom.yaml` 加 `lenovo,elden` |
| 3 | 同目录 `0001-arm64-dts-qcom-sm8750-label-the-DWC3-High-Speed-port.patch` | `sm8750.dtsi` 加 `usb_dwc3_hs_port:` 标签 |
| 4 | 同目录 `0002-arm64-dts-qcom-sm8750-lenovo-elden-describe-the-USB-.patch` | 板 DTS 加 mux + 两 connector |
| 5–7 | `patches/upstream/dwc3-v11-20261121/v11-000{1,2,3}-*.patch` | 被 G1–G6 门禁过的 dwc3 v11 三枚 |

- 只读验证：`git apply --check -R`（反向）在 **两棵树**上对第 2/3/4/5/6/7 枚**全部 OK**（E17a）；第 1 枚是"新建文件"，反向天然失败（无重叠风险：`apply.log` 7/7 rc=0）。
- g7a 侧额外两件（不是补丁，是**文件覆盖 + 补丁**）：
  - 板 DTS 换成路线 A 全使能版：`out/g7-routeA-dtfix-20261123/board-dts-g7a2.dts`（= `eeb78f0b…`，逐字节同树内文件）；
  - PSCI vendor-reset 钩子：`patches/local/psci-vendor-reset-20261123/0001-psci-minimal-SYSTEM_RESET2-vendor-reset-hook.patch`，**正向 `apply --check` 在 g7a-tree 现状态 rc=0**（E17b）。

### 3.3 构建时长（引用既有证据）

| 场景 | 实测 | 出处 |
|---|---|---|
| g7-tree 首次全量（`Image.gz dtbs`，`-j26`，ccache 22.6% 命中） | **6:03.77** wall / user 5828.16 s / sys 973.85 s | `out/g7-20261121/build.log`（`/usr/bin/time -v`） |
| g7-tree 被打断后**增量**续编 | **1:10.50** | `out/g7-20261121/build-2.log` |
| 单次**重链**（`Image.gz`） | **30–31 s** | `reports/dwc3-g7-prep-20261121.md` §0（"此后单次重链 30–31 s"） |
| routeA（g7a）全量 | **7:30.89** wall / user 6797.74 s（中途一次 gcc ICE） | `out/g7-routeA-20261121/build.log` |
| routeA 增量 | **0:37.58** | `out/g7-routeA-20261121/build-2.log` |
| routeA `modules`（1 508 `.ko`） | **未找到**（`build-modules*.log` 未套 `/usr/bin/time`） | — |
| `g7-reset` 的 `make -j8 Image.gz modules` | **未找到**（该目录只有 README/2 枚 img，无编译日志） | — |

⇒ 结论：**重建内核 Image 的成本 = 6–8 分钟**（有 ccache 时更快）；模块需另加（时长无证据）。若只为"以后还能改一改再编"，**保留树的价值只是省 6–8 分钟 + 省模块重编**，不构成"不可重建"。

---

## §4 大单体文件是否就是残渣主体

### 4.1 字节分解（apparent，非 `du` 块）

**g7-tree（7.13 GiB）**

| 类别 | 大小 | 占比 | 件数 |
|---|---|---|---|
| `*.o`（除 vmlinux.o） | 1.70 GiB | 23.9% | 4 994 |
| **`vmlinux.o`** | **1.65 GiB** | 23.2% | 1 |
| 源码 `.c/.h/.S` | 1.40 GiB | 19.6% | 66 575 |
| **`vmlinux.unstripped`** | **0.65 GiB** | 9.1% | 1 |
| **`vmlinux`** | **0.64 GiB** | 9.0% | 1 |
| 其它 | 0.43 GiB | 6.1% | 42 136 |
| `*.cmd` | 0.27 GiB | 3.8% | 8 593 |
| **`.tmp_vmlinux*`** | **0.26 GiB** | 3.7% | 17 |
| `*.dtb` | 0.13 GiB | 1.8% | 2 435 |
| `*.a` | ~0 | 0.0% | 1 009 |

**g7a-tree（12.11 GiB）**

| 类别 | 大小 | 占比 | 件数 |
|---|---|---|---|
| `*.o`（除 vmlinux.o） | 4.64 GiB | 38.3% | 11 036 |
| **`*.ko`** | **1.73 GiB** | 14.2% | 1 508 |
| **`vmlinux.o`** | **1.65 GiB** | 13.6% | 1 |
| 源码 | 1.40 GiB | 11.5% | 68 083 |
| **`vmlinux.unstripped`** | **0.65 GiB** | 5.3% | 1 |
| **`vmlinux`** | **0.64 GiB** | 5.3% | 1 |
| `*.cmd` | 0.58 GiB | 4.8% | 18 807 |
| 其它 | 0.43 GiB | 3.6% | 44 801 |
| **`.tmp_vmlinux*`** | **0.26 GiB** | 2.2% | 17 |
| `*.dtb` | 0.13 GiB | 1.1% | 2 435 |

### 4.2 判定

- **是**。`vmlinux.o`（1.65 G）+ `vmlinux`（0.64 G）+ `vmlinux.unstripped`（0.65 G）+ `.tmp_vmlinux*`（0.26 G）= **3.20 GiB/树，两树 6.40 GiB**，是两树里最大的单体簇（单文件第一名恒为 `vmlinux.o`）。
- **可单独删而保住树**：这 4 类都是**纯链接产物**（`vmlinux`/`vmlinux.unstripped`/`.tmp_vmlinux*` 由 `vmlinux.o` + built-in.a 链出；`vmlinux.o` 由全量 `ld -r` 过一遍 `*.o` 得到，**不重编译**）。判据：`make vmlinux`/`Image.gz` 目标会重建它们，且实测**单次重链 30–31 s**（E18）；剩余的 1.70/4.64 GiB `*.o` 无法用同一理由删（删了要重编 4 994/11 036 个目标）。
- g7a 的 1.73 GiB `*.ko` 属**另一类**：删了必须重跑 `make modules`（时长无证据），不是"30 秒级复原"。

---

## §5 裁决（逐项 A / B / C）

> 判据行号指 §E 证据账的条目 ID。**命令只供父代理执行，本 lane 未执行任何删除。**

### 5.1 A 类 —— 可删（本 lane 判定为安全）

#### A-1（保守档：只删链接残渣，**保留两棵树**）—— **6.40 GiB**（E19, E18, E9, E12）

判据：四类文件都是链接产物；两树当前 Image/config/dtb 均已归档（E9–E12）；重建 = 重链 30–31 s（E18）。

```sh
rm -rf build/g7-tree/vmlinux build/g7-tree/vmlinux.unstripped build/g7-tree/vmlinux.o build/g7-tree/.tmp_vmlinux*
rm -rf build/g7a-tree/vmlinux build/g7a-tree/vmlinux.unstripped build/g7a-tree/vmlinux.o build/g7a-tree/.tmp_vmlinux*
```

#### A-2（彻底档：删两棵 worktree 本体）—— **19.24 GiB apparent（du 20.5 G）**（E1, E2, E3, E9–E12, E15–E17）

判据（全部满足才可执行）：
1. HEAD/补丁集可重建：remote 可达 + 7 枚补丁在 `patches/` 且反向 check OK（E15, E16, E17a）；
2. 两树当前产物逐字节对应归档件（E9–E12）；
3. 未跟踪 DTS 已归档（g7a：`out/g7-routeA-dtfix-20261123/board-dts-g7a2.dts`；g7-tree：`patches/upstream/dwc3-v10-20261120/elden-dts/sm8750-lenovo-elden.dts`，同 sha `bfb536f…`）；
4. 共享对象库 **`build/elden-tree` 保留不动**（C 类），故离线可 `worktree add` 复原（E16）；
5. 先执行 §5.2 的 B 两条（config 与可选 symvers 落地）。

```sh
# 0) 先做 B（§5.2）
git -C build/elden-tree worktree remove --force build/g7-tree
git -C build/elden-tree worktree remove --force build/g7a-tree
git -C build/elden-tree worktree prune
# 等价的纯 rm 形式（不推荐：会留 .git/worktrees 管理员目录，需 prune 收尾）
# rm -rf build/g7-tree build/g7a-tree && git -C build/elden-tree worktree prune
```

> 注：`worktree remove` 是 git 写操作，属父代理权限；本 lane 未执行。`build/elden-tree/.git/worktrees/{g7-tree,g7a-tree}` 是元数据（几 KB），执行后由 `prune` 清理。
> 附：`git -C build/elden-tree worktree list` 另有 9 个 `/tmp/dwc3-*` 等登记项（E7），与本裁决无关，但 `prune` 会一并清掉已不存在的条目——属预期。

### 5.2 B 类 —— 需（一次性）归档后即可删

| # | 物项 | 为什么 | 动作（父代理执行） |
|---|---|---|---|
| B-1 | `build/g7a-tree/.config`（sha `622eead1…`，UTS `g7a-dwc3v11-reset-20261123`） | 盘上**唯一明文**副本；`out/` 里只有 manifest 记的 sha（E12） | `cp build/g7a-tree/.config out/g7-reset-20261123/config-g7a-reset.config` |
| B-2（可选） | `build/g7a-tree/Module.symvers`（1.4 MB） | UTS 级 out-of-tree 模块兼容用；不影响内核重建 | `cp build/g7a-tree/Module.symvers out/g7-reset-20261123/Module.symvers` |
| B-3（无需动作，仅记录） | 1 508 个 `.ko`（1.73 GiB） | 未归档；重编时长无证据（E18 缺项）。但 `g7-reset/README.md` 已写"USB 面全内建 ⇒ RAM 起新核不需 /lib/modules"，且设备现役内核 UTS 不同（结构性不可用）⇒ 无现存使用面 | 删前确认无在办事项依赖该 UTS 的模块 |

### 5.3 C 类 —— 必留

| # | 物项 | 判据 |
|---|---|---|
| C-1 | **`build/elden-tree/`（含 `.git` 720 M）** | 是两棵 worktree 的**共享对象库**；删它 ⇒ 未归档的历史/未 fetch 的 blob 一起消失，`worktree add` 复原路径断裂（E8, E16） |
| C-2 | `out/g7-20261121/`、`out/g7-routeA-20261121/`、`out/g7-routeA-dtfix-20261123/`、`out/g7-reset-20261123/` | 是本裁决成立的前提（E9–E12）；`out/g7-reset-20261123/boot-g7a-reset.img` 还是**PSCI vendor-reset 钩子二进制的唯一载体**（E14） |
| C-3 | `patches/upstream/{board-dts-single-20261113,elden-dts-v8-prep-20261121,dwc3-v11-20261121}/`、`patches/local/psci-vendor-reset-20261123/`、`patches/upstream/dwc3-v10-20261120/elden-dts/` | 是"源码可重建"的唯一配方（E17） |
| C-4 | `build/g7b-vk185`、`build/uefi-woa-prep` | **不在本 lane 范围**，未取证，不得连带删除 |

---

## §6 残余风险与未取证项

| # | 内容 | 影响 |
|---|---|---|
| R1 | `out/g7-reset-20261123/boot-g7a-ctl.manifest` 的 `image = out/boot-elden-vk28.img`、`kernel_release=…reset-20261123`，但**该文件不存在**；盘上同名件 `boot-g7a-ctl.img` 的 sha（`f79dcbcb…`）与 manifest 的 `image_sha256` 一致，**而其内嵌内核不含 `vendor reset_type` 钩子**；含钩子的是同目录 `boot-g7a-reset.img`（`647784b7…`，E14） | 命名/描述错位。**结论不变（二进制在盘），但不要按 README 的字面把 ctl.img 当"带钩子件"**；两枚都得留（C-2） |
| R2 | `g7a-tree/.config` 无明文归档（仅 sha） | B-1 一条 `cp` 清零 |
| R3 | 模块与 `g7-reset` 那次 `make -j8 Image.gz modules` **无时长证据** | 删 g7a-tree 后若需模块，代价未知（≥ 7:30.89 全量 + 模块） |
| R4 | remote 是 `blob:none` 部分克隆 | 全新 `git clone` 需网络（现可达，E15）；离线恢复依赖 `build/elden-tree`（C-1） |
| R5 | 11-21 g7a-tree 曾发生 **4 个源文件同尺寸位翻转**（`reports/…`/`~/hw-stability` 证据），说明"留着树当备份"本就不可靠 | 支持 A，不支持"树=保险" |
| R6 | `vmlinux` 与归档 `Image.gz` 的一致性只做到 **Image.gz sha + 内嵌 IKCONFIG sha + UTS 串 + 时间戳**四级对应，**未做二进制反汇编级复核**；g7-tree `KBUILD_BUILD_TIMESTAMP` 已钉、`Image.gz` 复现已被 `reports/dwc3-g7-prep-20261121.md` §0 实测过（删 `init/version-timestamp.o` 重编 sha 不变） | 残余风险低 |
| R7 | `du -sh` 与 apparent 字节差 ~1.3 GiB/树（4 K 块对齐，97 k 小文件） | A 类 GB 数按两者分别给出 |

---

## §E 证据账（判据行号索引）

| ID | 判据（命令 / 输出） |
|---|---|
| E1 | `du -sh build/*` → `13G build/g7a-tree`、`7.5G build/g7-tree`、`2.6G build/elden-tree`、`1.9G build/uefi-woa-prep`、`1.8G build/g7b-vk185`；`du -sh build/` = **27G**；`du -sxb` = g7-tree 7 660 786 890 B、g7a-tree 13 006 081 127 B |
| E2 | `git -C {g7,g7a}-tree rev-parse HEAD` → 两者 `aebb7274476403040d582c61478df8f4a7bf9cd3`；`rev-parse --abbrev-ref HEAD` = `HEAD`（detached）；`describe --tags` = `v7.4-rc3`；`describe --dirty` = `v7.4-rc3-dirty` |
| E3 | `git -C {g7,g7a}-tree diff \| sha256sum` → 两者 `29a8bd76a61a71143cf1eb453d40e997b58615e6164b8c42fabf51a65f08221e`；`diff --stat` = `9 files changed, 635 insertions(+), 5 deletions(-)`；`status --short` 各 10 行（9 `M` + 1 `??`），行内容与顺序相同 |
| E4 | `sha256sum …/sm8750-lenovo-elden.dts` → g7-tree `bfb536fb…8481fbf`（5 384 B，11-21 19:28）、g7a-tree `eeb78f0b…4f245ca6`（70 576 B，11-23 14:20）；`diff` 显示差异为路线 A 全使能面（sound/wcd939x/pmic-glink/wcn7861-pmu/mdss/dsi/panel/touch/ufs/…） |
| E5 | `grep ^CONFIG_LOCALVERSION` → `"-g7-dwc3v11-20261121"` / `"-g7a-dwc3v11-reset-20261123"`；`include/config/kernel.release` = `7.4.0-rc3-g7-dwc3v11-20261121-dirty` / `7.4.0-rc3-g7a-dwc3v11-reset-20261123-dirty`；`include/generated/utsrelease.h` 同值 |
| E6 | `sha256sum vmlinux` → g7-tree `2d658f1b2e63a0c2d7f2b754792da2c368d451eca625b5313b2b06d65079863c`（692 052 840 B）、g7a-tree `c5a65828cd85b810035265e511b7dc9fd4d2c05a2091b1910048b92fafee056a`（692 052 824 B）；`strings vmlinux` 的 UTS 行分别 `elden@y700`（`2026-11-21 00:00:00 UTC`）/`xuqianhui@xuqianhui`（`Mon Nov 23 22:46:49 CST 2026`） |
| E7 | `cat {tree}/.git` → `gitdir: /home/…/build/elden-tree/.git/worktrees/{g7-tree,g7a-tree}`；`git -C build/elden-tree worktree list` = 12 项（3 个 build/ + 9 个 `/tmp/dwc3-*` 等） |
| E8 | `git -C build/elden-tree config --get remote.origin.partialclonefilter` = `blob:none`；`…promisor` = `true`；`remote.origin.url` = `https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git`；`du -sh build/elden-tree/.git` = 720 M |
| E9 | `cat out/g7-20261121/{MANIFEST,BUILD-ENV,SHA256SUMS}`：`kernel_release=7.4.0-rc3-g7-dwc3v11-20261121-dirty`、`kernel_sha256=a635102f…`、`dtb_sha256=88a2d748…`、`config_sha256=373c2fb7…`、`image_sha256=00912631…`、`kernel_git_head=aebb727447…` |
| E10 | `sha256sum out/g7-20261121/Image.gz` = `a635102f1d925a051c80b60de7e3b4e7452161fa527908609a1013e1b0da6ff3`（= g7-tree `Image.gz` sha）；`sha256sum build/g7-tree/.config out/g7-20261121/config-g7.config` → 同为 `373c2fb7…`；`sha256sum build/g7-tree/…/sm8750-lenovo-elden.dtb` = `88a2d748…`（= manifest `dtb_sha256`） |
| E11 | `cat out/g7-routeA-20261121/boot-elden-g7a.manifest` + `SHA256SUMS`：`kernel_release=7.4.0-rc3-g7a-dwc3v11-20261121-dirty`、`kernel_sha256=138dc1ad…`、`dtb_sha256=5b6e9d1c…`、`config_sha256=186f7dcd…`、`image_sha256=d0c127ca…`；`sha256sum out/g7-routeA-20261121/Image.gz` = `138dc1ad…` |
| E12 | `cat out/g7-routeA-dtfix-20261123/boot-elden-g7a2.manifest`：`kernel_origin=build/g7a-tree/…/Image.gz (unchanged from g7a, not rebuilt)`、`dtb_sha256=dedc81bf…`、`dtb_source_sha256=eeb78f0b…`；`sha256sum build/g7a-tree/.config` = `622eead19febd945e1d324adf01a45905dfc7432bacbdc546e515c8ba0e2906b` = `out/g7-reset-20261123/boot-g7a-ctl.manifest:config_sha256`，且 `grep -rl 622eead…` 在 `out/` 只命中该 manifest（**无明文 config 文件**）；`build/g7a-tree/kernel/config_data` 同 sha；`bash scripts/extract-ikconfig build/g7a-tree/arch/arm64/boot/Image.gz \| sha256sum` = `622eead1…` |
| E13 | `sha256sum build/g7a-tree/…/sm8750-lenovo-elden.dtb` = `dedc81bfdd3830bb…c41c6`（= E12 manifest `dtb_sha256`）；`sha256sum build/g7a-tree/…/sm8750-lenovo-elden.dts out/g7-routeA-dtfix-20261123/{sm8750-lenovo-elden.dts,board-dts-g7a2.dts}` → 三者同为 `eeb78f0b…`；`sha256sum build/g7-tree/…/sm8750-lenovo-elden.dts patches/upstream/dwc3-v10-20261120/elden-dts/sm8750-lenovo-elden.dts` → 同为 `bfb536fb…` |
| E14 | 内存内解压 boot 镜像（无落盘）：`boot-g7a-reset.img` 的 kernel 段**含** `vendor reset_type`（PSCI 钩子格式串）、UTS `7.4.0-rc3-g7a-dwc3v11-reset-20261123-dirty`，sha256 `647784b7c7fc7a5b…ba45403`；`boot-g7a-ctl.img` 与 `out/boot-elden.img` 的 kernel 段**不含**该串（`=False`），`boot-g7a-ctl.img` sha256 `f79dcbcb…8fa9a8a8` |
| E15 | `git -C build/elden-tree rev-parse v7.4-rc3` = `19d1b4de6d37bccecc3ad9144d279f1baa405eb1`；`timeout 40 git ls-remote https://git.kernel.org/…/linux.git refs/tags/v7.4-rc3` → `19d1b4de6d37… refs/tags/v7.4-rc3`（**一致**）；`curl -o /dev/null -w '%{http_code}' …/info/refs?service=git-upload-pack` = `200`（6.1 s） |
| E16 | `GIT_NO_LAZY_FETCH=1 git -C build/elden-tree cat-file -e aebb727447:drivers/usb/dwc3/core.c` → rc=0；同 `…:arch/arm64/boot/dts/qcom/sm8750.dtsi` → rc=0（blob 本地在库） |
| E17 | (a) 只读反向校验：`git -C {g7,g7a}-tree apply --check -R -p1` 对 `v11-000{1,2,3}`、`elden-dts-v8-prep-20261121/000{0,1}`、以及 g7-tree 的 `0002` **全部 OK**；(b) `git -C build/g7a-tree apply --check -p1 patches/local/psci-vendor-reset-20261123/0001-….patch` → rc=0（`FORWARD_OK`）；(c) `cat out/g7-20261121/apply.log` = 7 枚 `APPLIED rc=0`（顺序同 §3.2） |
| E18 | `grep -aE 'Elapsed\|User time' out/g7-20261121/build{,2}.log` → `6:03.77`（user 5828.16）/`1:10.50`（user 725.43）；`out/g7-routeA-20261121/build.log` → `7:30.89`（user 6797.74）、`build-2.log` → `0:37.58`；"单次重链 30–31 s" 引自 `reports/dwc3-g7-prep-20261121.md` §0；`build-modules*.log` 无 `time` 记录 ⇒ 模块时长**未找到**；`out/g7-reset-20261123/` 无编译日志 ⇒ 该次时长**未找到** |
| E19 | 逐类字节统计（`os.walk` 求和，非 `du`）：g7-tree `vmlinux.o` 1.65 GiB / `vmlinux` 0.64 / `vmlinux.unstripped` 0.65 / `.tmp_vmlinux*` 0.26 / 其它 `*.o` 1.70 / 源码 1.40 / 总 7.13 GiB；g7a-tree `*.ko` 1.73 / 其它 `*.o` 4.64 / `vmlinux.o` 1.65 / `vmlinux` 0.64 / `vmlinux.unstripped` 0.65 / `.tmp_vmlinux*` 0.26 / 总 12.11 GiB；`find -size +20M` 头名：两树均 `vmlinux.o` 1 692 M，其次 `vmlinux.unstripped` 661 M、`vmlinux` 660 M |
| E20 | `du -sxb` 合计 20 666 868 017 B = 19.24 GiB；`du -sh` 合计 20.5 G（4 K 块对齐后偏大约 1.3 GiB/树） |
| E21 | 边界自证：`git diff --cached --stat` 空（本 lane 无暂存）；本文件此前不存在（`ls` = No such file）；`df -h .` = 723 G 已用 / 168 G 可用 |

---

## §7 一句话回执

**两棵树不是"重复 checkout"（同 commit、同 7 枚补丁，但板 DTS 5.3 K vs 70 K、`LOCALVERSION`/`vmlinux`/`dtb` 全不同，g7a 多 1 508 模块）；但它们当前产物已被 `out/g7-20261121`（g7）与 `out/g7-routeA-dtfix-20261123`+`out/g7-reset-20261123`（g7a）逐字节覆盖，源码 = `v7.4-rc3@aebb727447` + 7 枚补丁 + 1 份归档 DTS，全量重编 6–8 分钟 ⇒ 建议：先补 `g7a-tree/.config`（B），再删两棵 worktree = A 19.24 GiB（du 20.5 G）；保守档只删链接产物 = 6.40 GiB；`build/elden-tree` 与四个 `out/g7-*` 目录为 C，必留。**
