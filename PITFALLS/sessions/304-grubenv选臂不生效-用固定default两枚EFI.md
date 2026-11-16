## #668 GRUB 嵌入菜单里「用 grubenv 变量选臂」在 menuentry 之外不生效：`search`+`load_env`+`save_env` 顶层一组静默无效 ⇒ 永远走 default=0

**现象（2026-11-16，Q28 A/B 台架）**：ESP 上装了带 6 臂的新 EFI（v11b，sha `07558bde…`），`grubenv` 里写着 `elden_arm=1`，
但连续两发 a 槽启动都走了**臂 0**；EFI 里明明在 cfg 顶部加了打点 `save_env … elden_dbg_loadenv/elden_dbg_arm/elden_dbg_default`，
**`grubenv` 里一个 `elden_dbg_*` 键都没出现** ⇒ 顶层这组命令根本没跑成（不是「跑了但值没传下去」）。

判据（不用拍屏）：`grep -a '^elden_dbg' /boot/grub/grubenv` 为空 + `journalctl -k | grep -o 'elden_bootmenu=[a-z-]*'`
显示的是**臂 0 的标记**；两发都是 `Linux version …-00005`（现役 vk192），测试臂该有的 `-00008` 一次都没出现。

**坑的两层**：
- **第一层**：顶层 `search --label` 之后 `$root` 未必已指向 ext4（模块/文件系统驱动在 menuentry 内才按需自动加载），
   `load_env -f ($root)/boot/grub/grubenv` 于是失败，`elden_arm` 为空 ⇒ `if` 不成立 ⇒ 退回 `set default=0`；
- **第二层**：`save_env` 同理写不进去 ⇒ **表面上「没报错、没日志、也没生效」**，只能靠「打了点却没键」反证。

**处置（已验证可行的替代）**：不要在 cfg 里做「运行期选臂」，改成**编译期固定 `default` 的两枚 EFI**，
切臂 = 换 ESP 上的 `BOOTAA64.EFI`（8 MB，`scp`+sha 约 5 s）：
`scripts/grub-arm64-arming-build.sh --cfg out/.../arming-ab-arm0.cfg` 与 `…-arm1.cfg`（只差 `set default=N`）。
台架细节见 `reports/q28-ab-rig-20261116.md`。

**附带**：自己写 grubenv 编辑脚本时别用 `data.split(b"#")` 取正文——文件首行就是 `# GRUB Environment Block`，
那样会把整块 key 清空（本次把 10 个键全丢了，已从 `.bak` 恢复）。见 `scripts/grubenv-set.sh`（逐行跳过 `#` 的实现）。
