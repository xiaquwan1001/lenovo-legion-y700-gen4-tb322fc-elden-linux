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

## 6. 未做 / 限制

- 未刷任何分区（boot_b 仍是 `vk127`），`fastboot boot` 零写盘；一次 POR 即回日常。
- 未测 0153（video teardown 顺序，其对不上本仓 7.2 树，需先逐段比）。
- `0154` 的 50 ms 停顿在每次 probe 只发生一次，无侧效应证据。
