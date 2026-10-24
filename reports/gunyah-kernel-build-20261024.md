# Gunyah 全量内核构建（可零写盘试验版）— 20261024

状态：**完成（构建/打包/验证全部通过，未上机）**

## 0. 目标与环境

- worktree：`build/gunyah-port` @ 24223e4（= 在机内核 vk152 的树，含 Gunyah 移植）
- 工具链：aarch64-linux-gnu-gcc 15.2.0 + ccache；`-j28`；源 `scripts/env-build.sh`
- 产出：`Image.gz` + dtbs + modules + 模块包 tar.gz；**只构建不上机**，上机由用户 `fastboot boot`
- 版本名：`gunyah1`；ramdisk 与 vk152 一致（`out/rootfs-vk127.cpio.gz`，sha256 4d4834e6…）

## 1. 配置就绪

`build/gunyah-port/.config` 已存在且与 vk151 逐项 diff **仅多出 gunyah 相关行**（未复制覆盖，避免丢已调好的 gunyah 项）：

```
diff <(grep -vE "^#|^\s*$" .config) <(grep -vE "^#|^\s*$" ../vk151/.config)
  < CONFIG_GUNYAH_WATCHDOG=m
  < CONFIG_VIRT_DRIVERS=y / CONFIG_GUNYAH=m / CONFIG_GUNYAH_PLATFORM_HOOKS=m
  < CONFIG_GUNYAH_QCOM_PLATFORM=m / CONFIG_GUNYAH_IRQFD=m / CONFIG_GUNYAH_IOEVENTFD=m / CONFIG_VMGENID=y
```

- `make ARCH=arm64 CROSS_COMPILE=… syncconfig` → `# No change to .config` 后复查：

```
.config:CONFIG_VIRT_DRIVERS=y
.config:CONFIG_GUNYAH=m
.config:CONFIG_GUNYAH_WATCHDOG=m
.config:CONFIG_HAVE_ARM_SMCCC_DISCOVERY=y
.config:CONFIG_QCOM_SCM=y
.config:CONFIG_ARCH_QCOM=y
```

（教训 #382 类：`VIRT_DRIVERS` 先行 =y，`GUNYAH=m` 未被 syncconfig 丢弃。）

## 2. 全量构建

```
make ARCH=arm64 CROSS_COMPILE="ccache aarch64-linux-gnu-" CC="ccache aarch64-linux-gnu-gcc" \
     HOSTCC="ccache gcc" LOCALVERSION= -j28 Image.gz dtbs modules
```

- 日志：`/tmp/gunyah-build-log/build.log`（time box：`timeout -k 60 5400`，实际约 10 min）
- 产物：`arch/arm64/boot/Image.gz` 20,805,400 B；`dts/qcom/sm8750-lenovo-elden.dtb` 153,089 B
- **0 error**：`grep -cE " error:|Error [0-9]" build.log` → 0
- **0 warning**：`grep -cE "warning:" build.log` → 0

## 3. 验证

System.map 关键导出（硬缺口修复证据，`arch/arm64/mm/pageattr.c` 两行 EXPORT 编进了内核）：

```
ffff800080064068 T set_direct_map_invalid_noflush
ffff8000800640e8 T set_direct_map_default_noflush
ffff800082ce6ef0 r __ksymtab_set_direct_map_default_noflush
ffff800082ce6efc r __ksymtab_set_direct_map_invalid_noflush
```

平台符号守卫（assert-kernel-sane.sh 同款）：`gcc_sm8750 OK / msm_dsi_host_bonded_cmd_trigger OK / rpmh OK / qcom_rpmh OK`。
打包前闸门：`[assert] ✅ ABI 敏感项一致（27 项）` + `✅ 内核闸门通过…（build/gunyah-port/…/Image.gz）`。
模块 vermagic 9 个 .ko 全部 = `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty SMP preempt mod_unload aarch64`，与在机 `uname -r` 逐字一致。
`nm gunyah_rsc_mgr.ko` 中 `U set_direct_map_default_noflush` 为运行时解析（内核侧已导出，insmod 可解析）。

## 4. boot.img 打包

```
export KDIR=$PWD/build/gunyah-port
VERSION=gunyah1 RAMDISK=$PWD/out/rootfs-vk127.cpio.gz bash scripts/build-boot.sh
```

- 镜像：`/home/xuqianhui/y700-elden/out/boot-elden-gunyah1.img`
- sha256：`4d97e7e7a5d1a3766992bd3669f7f0c3a0f78e5890352519b96e0b9b8ff84646`，85,590,016 B
- manifest：`out/boot-elden-gunyah1.manifest`（kernel_uts=`…-dirty`，与 vk152 同 UTS、不同 payload；打包 argv/ramdisk/cmdline 全记录）
- cmdline 与 vk152 完全一致（无多变量）；DTB 来自 gunyah-port 树

## 5. 模块包

- 路径：`/home/xuqianhui/y700-elden/out/gunyah-modules-gunyah1.tar.gz`
- sha256：`753de11d8ce648c1ac9ded1b3ddcf78da10fb1187b718ba367b7faa489b9952a`，1,370,044 B
- 来源：`make INSTALL_MOD_PATH=/tmp/gunyah-modinst modules_install`（depmod 已跑）后抽出 gunyah 相关 9 个 .ko + modules.order/builtin/symvers
- vermagic 全表（9 个 .ko 逐字相同，见上）；sha256 表：

| .ko | sha256(前16) | 大小 |
|---|---|---|
| arch/arm64/gunyah/gunyah_hypercall.ko | 6a6846de4fa0921e | 192,816 |
| drivers/virt/gunyah/gunyah.ko | c722dd95d6650391 | 326,032 |
| drivers/virt/gunyah/gunyah_rsc_mgr.ko | a90f4961f6242991 | 1,167,768 |
| drivers/virt/gunyah/gunyah_vcpu.ko | f5455836747e2e26 | 422,024 |
| drivers/virt/gunyah/gunyah_irqfd.ko | 968d447677703e07 | 328,104 |
| drivers/virt/gunyah/gunyah_ioeventfd.ko | f131640e015e6106 | 315,152 |
| drivers/virt/gunyah/gunyah_platform_hooks.ko | f1f6f91c8e1fcd7c | 330,824 |
| drivers/virt/gunyah/gunyah_qcom.ko | 7282acbe3806b2bd | 345,056 |
| drivers/watchdog/gunyah_wdt.ko | 949f1545a7f15cae | 347,000 |

## 6. 上机步骤（用户执行；全程零写盘，只 fastboot boot）

```
fastboot boot out/boot-elden-gunyah1.img
# ssh 上线后：
scp out/gunyah-modules-gunyah1.tar.gz <设备>:/tmp/
ssh <设备>
KVER=$(uname -r)   # 必须是 7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty
tar -xzf /tmp/gunyah-modules-gunyah1.tar.gz -C /tmp/gm
mkdir -p /lib/modules/$KVER/updates && cp -a /tmp/gm/kernel /lib/modules/$KVER/updates/ && cp /tmp/gm/modules.* /lib/modules/$KVER/
depmod -a $KVER
# 按依赖顺序 insmod：
cd /lib/modules/$KVER/updates/kernel
insmod arch/arm64/gunyah/gunyah_hypercall.ko
insmod drivers/virt/gunyah/gunyah.ko
insmod drivers/virt/gunyah/gunyah_rsc_mgr.ko
insmod drivers/virt/gunyah/gunyah_vcpu.ko gunyah_irqfd.ko gunyah_ioeventfd.ko \
       gunyah_platform_hooks.ko gunyah_qcom.ko drivers/watchdog/gunyah_wdt.ko
```

## 7. 判据与回退

**通过判据**（按序）：
1. `dmesg | grep -i gunyah` → hypercall 探测成功、`arch_is_gunyah_guest=1`（或等效 guest 判定日志）
2. gunyah.ko probe → `/dev/gunyah` 出现
3. gunyah-wdt 绑定 `gunyah-wdt` 平台设备（此前 stage0 已在机实证 insmod/绑定/rmmod 干净）
4. `gunyah_rsc_mgr` probe：**允许因缺 capid（DT 无 Gunyah 节点/cap-id）而 defer 或 fail**——这不是本次试验失败，是预期分支；失败信息回填 `gunyah-rm-probe-20261024.md` 结论

**回退**：fastboot boot 不写任何分区；`reboot` 即回 boot_b（vk152），零副作用。

## 8. 失败与未证实

- manifest 里 `kernel_release=…-dirty+`（manifest 侧 `make kernelrelease` 未带 LOCALVERSION 的 `+` 后缀）；**权威判据是镜像内 UTS** = `…-dirty`（无 `+`），已核实一致，不影响 vermagic。
- 全量构建未撞任何既有错误（0 error / 0 warning），无需规避措施。
- 未证实项：rsc_mgr 在真机上的 probe 结果（需上机）；`/dev/gunyah` 出现与否依赖 hypervisor 侧固件配合，本构建只解决内核侧 insmod 链路。
