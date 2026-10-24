# UEFI / Gunyah 首轮考查（N1 / N2）

- 日期：2026-10-24
- pi 会话 id：$PI_SESSION_ID
- 主题：下一步考查 UEFI 与 Gunyah —— 主线/上游状态复核 + 本机固件静态取证
- 结论（一句话）：**两项都维持「不重启 / 不立项」**，但各拿到一条新证据：UEFI 侧唯一信息入口（issue #12）在我方 10-21 追问后 3 天 0 回复、厂商 DXE 仍是压缩态（取 UFSDxe 需再投 1–2 h 写递归解压器）；Gunyah 侧主线今日仍无 `drivers/virt/gunyah`，而本机 `hypvm.mbn` 证实 EL2 里 Gunyah + RM-RPC **齐全** ⇒ 「能不能用」变成一个待设备的二值探测。
- 证据指针：`reports/uefi-gunyah-reassess-20261024.md`（§1 UEFI、§2 Gunyah、§4 复现命令）；
  `TASKS/README.md` §4 N1/N2；设备未接入（`fastboot devices`/`adb devices` 均空、SSH 22 拒连）
- ★SSOT 待并入：`TASKS/README.md` §4 N1/N2（已就地写）、§5 Q4/C8（口径未变，无需改）

## 1. 本轮新增的可复核事实

| # | 事实 | 命令/来源 |
|---|---|---|
| 1 | mainline `master` 的 `drivers/virt/` 无 `gunyah/` | `gh api repos/torvalds/linux/contents/drivers/virt --jq '.[].name'` |
| 2 | 本机三树 `drivers/virt/` 各 4 目录、gunyah=0 | `ls build/m1-73/drivers/virt linux/drivers/virt build/m3v2-7.3rc7/drivers/virt` |
| 3 | `hypvm.mbn` 含完整 RM + RM-RPC 字符串（`gunyah-resource-manager`、`qcom,resource-manager-rpc@%016lx`、`rm_rpc_receive_from_rm`、`rm_vm_create`） | `strings -n5 ~/下载/tb322fc/hypvm.mbn \| grep -iE ...`；sha256 `c3dbff5e…` |
| 4 | 内核侧探测点就绪：`qcom_scm_gunyah_wdt_init()` + `CONFIG_HAVE_ARM_SMCCC_DISCOVERY=y` ⇒ 有 `gunyah-wdt` 平台设备即阳性 | `qcom_scm.c:2497/2942`、`build/m1-73/.config:2093` |
| 5 | issue #12 自 2026-10-21 我方追问后无回复；原厂 10-09 只说「需 UFSDxe 专用补丁」 | issue 页面活动（本轮抓取） |
| 6 | `imagefv.elf` = 单个 LZMA 段（GUID 在 `0x1064`、流起 `0x1078`），解出内层 FV 32 198 664 B；但 `UFS.c` 仍 0 命中 | `reports/uefi-gunyah-reassess-20261024.md` §4 |
| 7 | 四个厂商 blob 内 `UFS.c`/`ufs_error_log`/`UFSDxe` 全 0 命中（DXE 模块压缩存放） | `grep -ac` 逐文件 |

## 2. 裁决与解冻条件

- **UEFI**：不投。解冻 = issue #12 给出「补丁打在哪层」/ 出现 SM8750 UEFI 真枚举 UFS 的第三方案例 / kexec 不可用又需要启动菜单。
- **Gunyah**：不立项。阶段 0 阴性 ⇒ 永久关闭；阳性 ⇒ 才谈 port v17（~6.7 kLOC）+ VMM（crosvm 需 rust 且 AVF 那份是 bionic 版，不能用）。
- 两项的共同点：**都不是「写代码」缺，而是「外部信息/设备侧一个二值事实」缺** ⇒ 现在投入是猜。

## 3. 待设备（5 分钟）

设备接入并入主线 Linux 后跑：`ls /sys/bus/platform/devices | grep -i gunyah`、
`dmesg | grep -iE 'gunyah|hypervisor'`、`ls /proc/device-tree | grep -i hypervisor`。
**别用** `dmesg | grep gh_rm` 当反证（树里没该驱动，必空）。
