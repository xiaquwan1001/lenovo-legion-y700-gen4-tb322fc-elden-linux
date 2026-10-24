# Gunyah 全量内核构建（可零写盘试验版）— 20261024

状态：**进行中（骨架已落盘，逐步回填）**

## 0. 目标与环境

- worktree：`build/gunyah-port` @ 24223e4（= 在机内核 vk152 的树，含 Gunyah 移植）
- 产出：`Image.gz` + dtbs + modules + 模块包 tar.gz；**只构建不上机**，上机由用户 `fastboot boot`
- 版本名：VERSION=gunyah1；ramdisk 取值与 vk152 一致
- 硬约束：不碰设备（无 adb/fastboot/ssh）、不改 `build/vk151` 的 .config/产物、不写分区

## 1. 配置就绪（§回填：命令+输出）

- [ ] 从 `build/vk151/.config` 复制到 `build/gunyah-port/.config`
- [ ] `CONFIG_VIRT_DRIVERS=y`、`CONFIG_GUNYAH=m`、`CONFIG_GUNYAH_WATCHDOG=m`
- [ ] 确认 `CONFIG_HAVE_ARM_SMCCC_DISCOVERY=y`、`CONFIG_QCOM_SCM=y` 保持原值
- [ ] `syncconfig` 后复查以上项未被丢弃（Kconfig source 在 `if VIRT_DRIVERS` 内）

## 2. 全量构建（§回填）

- [ ] make 命令、日志路径
- [ ] 0 error / 0 warning grep 证据
- [ ] Image.gz / dtbs 产物清单

## 3. 验证（§回填）

- [ ] System.map 出现 `set_direct_map_default_noflush` / `set_direct_map_invalid_noflush` 且带 `__ksymtab_`
- [ ] assert-kernel-sane.sh 同款符号守卫：gcc_sm8750 / msm_dsi_host_bonded_cmd_trigger / qcom_rpmh 在
- [ ] vermagic 与在机一致

## 4. boot.img 打包（§回填）

- [ ] scripts/build-boot.sh 参数、manifest 指针
- [ ] 镜像路径 / sha256 / 大小

## 5. 模块包（§回填）

- [ ] modules_install → tar.gz；含 gunyah 8 个 .ko + gunyah_wdt.ko
- [ ] 每个 .ko 的 sha256 / vermagic 表

## 6. 上机步骤（用户执行，§回填）

fastboot boot 镜像 → ssh 上线 → 解包模块 → depmod → 按序 insmod → 检查 dmesg/平台设备

## 7. 判据与回退（§回填）

- 通过判据：arch_is_gunyah_guest=1、/dev/gunyah、gunyah-wdt 绑定、rsc_mgr probe 状态
- 回退：重启回 boot_b，零写盘

## 8. 失败与未证实（§回填）

（如有既有构建错误、绕过措施、未验证项，列在此处）
