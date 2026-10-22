# Q28 显示初始化补丁 A/B — armadaos-freedom 0154 + 0155（2026-10-22 起）

> 来源与逐条裁决：`reference/upstream-armadaos-freedom/README.md` §4/§5.1。
> 本轮做到：**两个镜像构建完成 + 暖起验证 GOOD**；**冷起样本待物理 POR（用户在机旁执行）**。

## 1. 假设

| 补丁 | 机理 | 与 Q28 的关系 |
|---|---|---|
| **0154** `clk: qcom: dispcc-sm8750: reset live display on Lenovo Elden` | probe 时断言再逆序释放 `DISP_CC_MDSS_CORE_BCR`(0x8000) / `CORE_INT2_BCR`(0xa000) / `RSCC_BCR`(0xc000)，握 50 ms ⇒ 让 MDSS/PLL 从**已知零态**重新编程，而不是叠在 bootloader 留下的活状态上 | 对应「冷起首次 bring-up 状态不干净」；也解释「暖复位粘态」（活状态被粘住） |
| **0155** `drm/msm/dsi/phy: power up the digital top before starting the 7nm PLL` | `dsi_pll_{enable,disable}_pll_bias()` 里同 `PLL_SHUTDOWNB` 一起置/清 `DIGTOP_PWRDN_B` ⇒ PLL 才可能锁上 | 直接对应本仓反复记录的 `DSI PLL(0) lock failed, status=0x00000000` |

两条都 `of_machine_is_compatible("lenovo,elden")` 门控 ⇒ 不改变任何其它机型行为；合计 +32 行。
⚠ 它们解释**首次坏发**，与 2026-10-22「软件闩锁 / `link_configured` 误清」那两条（解释**坏发后不可恢复**）不冲突、可叠加。

## 2. 构建（可复现，2026-10-22 实测 rc=0）

基线树 = `build/base-7.2`（HEAD `378459aff`，即 vk64 下游 payload 状态）；配置 = **从 vk64 镜像 `extract-ikconfig` 恢复的真配置**
（避免「配置不身份」这一历史污染源），仅把 `CONFIG_LOCALVERSION_AUTO` 改为 `n` 做 **PINUTS**：

```sh
# 1) 工作树（不动 build/base-7.2 本体，也不动 build/m1-73 的未提交实验）
git -C build/base-7.2 worktree add --detach ../q28-disp HEAD
bash linux/scripts/extract-ikconfig out/vk64-unpack/Image > build/q28-disp/.config   # out/vk64-unpack = vk64.img 解包
sed -i 's/^CONFIG_LOCALVERSION_AUTO=y/# CONFIG_LOCALVERSION_AUTO is not set/' build/q28-disp/.config

# 2) 通用构建（ccache；UTS 钉到 vk64 的串以复用机内模块树）
cd build/q28-disp
export ARCH=arm64 CROSS_COMPILE="ccache aarch64-linux-gnu-" CC="ccache aarch64-linux-gnu-gcc" \
       HOSTCC="ccache gcc" KBUILD_BUILD_USER=elden KBUILD_BUILD_HOST=y700 CCACHE_DIR=$HOME/.cache/ccache-elden
make -j28 LOCALVERSION=-vk64-gd02658e63cf6 Image.gz dtbs     # base 臂（vk137）
cp arch/arm64/boot/Image.gz ../../out/vk137-q28base-kernel.gz
git apply ../../reference/upstream-armadaos-freedom/patches/0154-*.patch \
          ../../reference/upstream-armadaos-freedom/patches/0155-*.patch
make -j28 LOCALVERSION=-vk64-gd02658e63cf6 Image.gz          # exp 臂（vk138，增量 ~40 s）
cp arch/arm64/boot/Image.gz ../../out/vk138-q28disp-kernel.gz

# 3) 打包（vk64 的 ramdisk / DTB / cmdline 逐字节不变 ⇒ 唯一变量 = 内核）
V=vk137-q28base K=out/vk137-q28base-kernel.gz; \
KDIR=build/q28-disp LOCALVERSION=-vk64-gd02658e63cf6 VERSION=$V KERNEL_IMG=$PWD/$K \
DTB_FILE=$PWD/out/vk64-unpack/dtb RAMDISK=$PWD/out/vk64-unpack/ramdisk \
CMDLINE_EXTRA=elden_nocamera=1 bash scripts/build-boot.sh
# vk138 同法，K=out/vk138-q28disp-kernel.gz V=vk138-q28disp
```

## 3. 两镜像身份

| 镜像 | 大小 | 镜像 sha256 | 内核载荷 sha256 | UTS |
|---|---|---|---|---|
| `out/boot-elden-vk137-q28base.img` | 85352448 | `7fb5a8fee99b…` | `1ed94826aecb…` | `7.2.0-debug-vk64-gd02658e63cf6` |
| `out/boot-elden-vk138-q28disp.img` | 85356544 | `a0318ffa12c4…` | `85dc56e071a4…` | 同上（PINUTS） |

- config 与 vk64 真配置逐项相同，**唯一差异 = `CONFIG_LOCALVERSION_AUTO`**（PINUTS 所需）。
- 已登记 `versions/vk-registry.tsv`：`vk137` = base 臂、`vk138` = exp 臂（UTS 同 vk127/vk64 属已登记的 uts_dup 例外族）。
- 校验：`/proc/device-tree/compatible` = `lenovo,elden` / `qcom,sm8750` ⇒ **两条补丁的机型门控确实会命中**（不是空转）。

## 4. 暖起验证（2026-10-22 19:47，`fastboot boot vk138`）

| 项 | 结果 |
|---|---|
| 启动 | ✅ 85 MB 镜像 `Booting OKAY`，USB gadget（product `TB322FC mainline`）+ `usb0` 起来 |
| 根 | ✅ `/dev/sda17 ext4`（磁盘持久根，非 RAM） |
| 会话 | ✅ `phoc` 1 / `phosh` 1 |
| `q28-devprobe.sh` | **GOOD**（`card0` 在、`card0-DSI-1=connected`、风暴签名 0） |
| `DSI PLL(0) lock failed` | **0**（对比：历史 GOOD 冷起样本里曾见 8 次） |
| `device_link_fail` | 8（暖起也有，与 Q28 判据无关，历史同现象） |

⇒ 补丁**没有破坏**正常路径；暖起本来就基本 GOOD，所以**这一条不能证明有效**，只证明「可上机、可判读」。

## 5. 冷起协议（待执行，物理动作只能由用户做）

冷起唯一有效台架 = **真实 POR（断电）+ 按键进 fastboot + `fastboot boot`（零写盘）**；
`reboot bootloader` 是暖复位（会粘 NOCARD，`PITFALLS #166`），且当前在机 `vk127`（replay 线，无 PSCI vendor-reset 钩子）根本进不去 fastboot。
判据必须三态（`scripts/q28-devprobe.sh`：NOCARD / STORM / NOROUTE / GOOD）+ 读全 dmesg + 查 `card0`。

**每一发的操作（约 2 min）**：
1. 长按电源键 ~10 s 关机（真断电）；
2. 按住**音量键** + 短按电源开机 → 进 fastboot（屏上出现 fastboot 界面 / 主机 `fastboot devices` 见 `HA2EXB0E`）；
3. 主机跑：`scripts/q28-disp-ab-sample.sh base` 或 `... exp`（内部 `trial.sh --reset por --deploy fastboot-boot --probe q28`，自动落 `reports/trials/`）。

**样本计划**：交替 `exp,base,exp,base…` 各 5 发（10 次 POR）。判读：
- 若 base 臂复现 ≥2 次坏发（NOCARD 或 STORM）而 exp 臂 5/5 GOOD ⇒ 强信号，扩到各 10 发；
- exp 臂出现坏发 ⇒ 该假设否证，记 `PITFALLS`；
- 两臂混合 ⇒ 与「成簇随机」一致，样本量不足以下结论，需按上一条扩样。
- **每发之间必须 POR**，不得用 `reboot bootloader` 连打。

## 6. 上机结果（2026-10-22 20:00–20:13，10 发真实 POR 冷起，交替 exp/base）

| # | 臂 | 镜像 | uptime@probe | `DSI_PLL_lockfail` | `storm_sig` | 判读 |
|---|---|---|---|---|---|---|
| 1 | exp | vk138 | 12.7 s | 0 | 0 | **GOOD** |
| 2 | base | vk137 | 16.8 s | 4 | 13 | **STORM** |
| 3 | exp | vk138 | 12.6 s | 0 | 0 | **GOOD** |
| 4 | base | vk137 | 19.3 s | 4 | 13 | **STORM** |
| 5 | exp | vk138 | 12.6 s | 0 | 0 | **GOOD** |
| 6 | base | vk137 | 12.6 s | 4 | 0 | **GOOD** |
| 7 | exp | vk138 | 12.6 s | 0 | 0 | **GOOD** |
| 8 | base | vk137 | 12.6 s | 4 | 0 | **GOOD** |
| 9 | exp | vk138 | 12.6 s | 0 | 0 | **GOOD** |
| 10 | base | vk137 | 17.0 s | 4 | 10 | **STORM** |

记录：`reports/trials/20261022T1158…–1212…-q28disp-{exp,base}.json`（每条含 dmesg 全文、probe、env、manifest 身份）。

**结论（分层，不许混读）**：
1. **机制端点（补丁是否生效）：10/10 分离。** base 臂**每一发**都 `DSI PLL(0) lock failed` ×4；exp 臂**每一发**都是 **0** ⇒ 0155 的 `DIGTOP_PWRDN_B` 改动确实作用到硬件（不是空转），且让 7nm PLL 在早期 `of_clk_set_defaults` 那次尝试就锁上。
2. **功能端点（是否消 STORM）：方向一致但样本不足。** exp **5/5 GOOD**、base **3/5 STORM**（Fisher 单侧 p≈0.083、双侧 p≈0.167）⇒ **未达统计显著**，不能写「已修 Q28」。
3. **一处与历史口径吻合的细节**：base 的两个 GOOD 样本也有 `lockfail=4` ⇒ **单看 `DSI PLL(0) lock failed` 不是 STORM 的充分条件**（与 `PITFALLS #277` 一致）；但把该失败消掉后，本 5 发里 STORM 没再出现。
4. 暖起（vk138，非 POR）同样 GOOD，`lockfail=0` —— 暖路径本就基本 GOOD，故只作「不破坏」证据。

## 6b. 第二轮：加入 `only0155` 臂拆贡献（2026-10-22 20:16–20:30，共 23 发真实 POR）

为区分两条补丁各自的作用，加构建第三臂 **`vk139-q28only0155` = base + 仅 0155**（revert 0154 的 27 行；树/config/ramdisk/DTB/cmdline/PINUTS 与另两臂逐字节一致）。

### 汇总（全部真实 POR，交替采样）

| 臂 | 镜像 | n | GOOD | STORM | `DSI_PLL_lockfail`（每发） |
|---|---|---|---|---|---|
| base | vk137 | 9 | 4 | **5（56%）** | 4,4,4,4,4,4,4,4,4 |
| **exp（0154+0155）** | vk138 | 10 | **10** | **0** | 0 ×10 |
| only0155 | vk139 | 4 | 1 | **3（75%）** | 0 ×4 |

### 统计

- exp vs base：Fisher 双侧 **p = 0.011**（0/10 vs 5/9）⇒ **达显著**。
- only0155 vs base：p = 1.0（3/4 vs 5/9）⇒ **0155 单独对 STORM 无作用**。
- exp vs only0155：p = 0.011 ⇒ **0154 是消 STORM 的那一条**。

### ★ 机制解离（本轮最有价值的结论）

| 端点 | 由谁决定 | 证据 |
|---|---|---|
| `DSI PLL(0) lock failed`（PLL 未锁） | **0155**（`DIGTOP_PWRDN_B`） | base 9/9 有 ×4；only0155 与 exp 均 0 |
| **STORM（cmd-DMA `0x2200200` 超时 / 面板 init -5）** | **0154**（dispcc probe 复位活显示） | only0155 仍 3/4 STORM 且 **PLL 锁是好的**；exp 0/10 |

⇒ 两条历史判断同时被修正：
1. **PLL 锁失败不是 STORM 的成因**（only0155 4/4 PLL 锁上，仍 3/4 STORM）——与 `PITFALLS #277/#31` 方向一致，但现在有直接对照。
2. **STORM 的对症点是「显示块在 probe 时是活状态」**（bootloader 留下的 dispcc PLL/BCR 状态），probe 断言-释放三个 BCR 后 STORM 在该臂 10/10 未复现。
3. exp 臂同时把 PLL lockfail 打到 0 ⇒ 两条一起上仍有意义（PLL 锁失败虽不致命，但会让 pixel clock 使能计数失衡、留下早期噪声）。

### 样本记录

`reports/trials/20261022T1158…–1230…-q28disp-{base,exp,0155only}.json`（23 发；每发含 dmesg 全文 / probe / env / manifest 身份）。

## 7. 下一步（按性价比）

1. ~~扩样到各 10 发~~ ✅ 已做：exp 10/10、base 5/9 STORM（p=0.011）。
2. ~~拆 0154/0155 贡献~~ ✅ 已做：**0154 = STORM 对症，0155 = PLL 锁对症**（见 §6b）。
3. 若扩样通过：把 `0154`(或仅 0155) + 现有软件闩锁/`link_configured` 修复**合并成候选日常镜像**，再按 Q28 验收口径（取得稳定 GOOD 冷起）走持久化。
4. 未做：0153（video teardown 顺序，hunk 与本仓 7.2 树对不上，需逐段比）。

## 8. 未做 / 限制

- 未刷任何分区（boot_b 仍是 `vk127`），`fastboot boot` 零写盘；一次 POR 即回日常。
- 未测 0153（video teardown 顺序，其对不上本仓 7.2 树，需先逐段比）。
- `0154` 的 50 ms 停顿在每次 probe 只发生一次，无侧效应证据。

## 9. 日常 7.3 线（m1-73）同日试跑 —— 样本不足 + 一个刷屏谜团的实测结论

设备电量不足，本轮在 7.3 线只拿到很少样本；**不足以支持任何结论**，只记录事实与两个有意义的副产物。

### 9.1 构建

| 镜像 | 内容 | 备注 |
|---|---|---|
| `vk140-q28disp73` | m1-73@24223e44ad80 + 0154 + 0155 | **作废**：UTS 少了 `-vk127` ⇒ 机内模块树对不上（`fsa4480` 不加载 → DP 控制器永久 defer → dispcc `sync_state` 不收敛 → 无 `card0`）。与 `PITFALLS #31` 同一机制，非补丁问题 |
| `vk141-q28disp73` | 同上，`CONFIG_LOCALVERSION="-debug-vk127"` ⇒ UTS 与在机 vk127 逐字相同 | ✅ 可用 |
| `vk142-q28disp73dt` | vk141 + `sm8750.dtsi` adsp fastrpc 补 `qcom,non-secure-domain` | **与 vk141 镜像 sha 完全相同**（实测：vk127 的 DTB 本就已含该属性，`strings` 计数 1 是属性名去重造成的误判）⇒ 该 DT 改动无意义，如实记录 |
| `vk143-q28-73-0155only` | 7.3 线 base + 仅 0155 | 用于排查刷屏来源 |

### 9.2 样本（全部真实 POR）

| 臂 | 样本 | 判读 |
|---|---|---|
| daily（在机 `vk127` 原件） | 4 | **NOROUTE（SSH 150 s 未起）×1、STORM ×3** |
| exp73（vk141：7.3 + 0154 + 0155） | 2 | **GOOD ×2** |
| o155_73（vk143：7.3 + 仅 0155） | 1 | STORM ×1 |

⇒ 方向与 7.2 线一致，但 **n=2 vs 4 什么也不能证明**；7.3 线若要复刻 7.2 的结论，需要 8–10 发/臂，且必须先解释 daily 的 NOROUTE（无 SSH）形态。

### 9.3 ★ 用户报告的「启动/关机大量刷屏」——实测归因：**7.3 线自身的 fastrpc probe 风暴，不是本补丁引入**

同一镜像内按启动随机，统计 `FastRPC Domain not specified in DT` / `rpmsg_dev_probe: failed: -22` 行数：

| 镜像 | 样本 A | 样本 B |
|---|---|---|
| daily（在机 vk127） | **1659 行** | 16 行 |
| exp73（vk141） | **1840 行** | 293 行 |
| o155_73（vk143） | 4 行 | — |

- **日常镜像 vk127 自己也能刷 1659 行** ⇒ 与 0154/0155 无关，属 7.3 线既有问题。
- 根因（源码级）：`drivers/misc/fastrpc.c: fastrpc_rpmsg_probe()` 从 **rpmsg 设备节点**读 `label`，7.3 上该节点的 DT 继承失效 ⇒ 每条 fastrpc 通道 probe 都走 `dev_info("FastRPC Domain not specified in DT")` + `-22`；触发次数取决于该次启动的探测/重试时序，故 4–1840 行随机。
- 后果：`FastRPC` 在 7.3 线**基本不可用**（探测全失败）——这与本仓 G1-34 传感器链（ADSP fastrpc）在 7.3 线上的状态相关，属另一个待办，不是显示补丁的副作用。
- 7.2 线三臂的 dmesg 中该消息 **0 行** ⇒ 这是 7.3 线独有。

### 9.4 暂停点（设备电量不足）

- 设备内存里跑的是最后一发 `vk143`（STORM 态）；`boot_b` 仍是 `vk127`，**一次 POR 即回日常**，建议先充电。
- 未刷任何分区，全程 `fastboot boot` 零写盘。
