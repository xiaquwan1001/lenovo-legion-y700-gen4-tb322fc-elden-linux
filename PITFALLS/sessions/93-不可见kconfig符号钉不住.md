# #409 没有 prompt 的 Kconfig 符号「钉 `=y`」钉不住；顺带：载荷加载器会把 builtin 报成 loaded

## ① 不可见符号：手工 `=y` 在 syncconfig 之后会被重算回 `m`

`CONFIG_PCI_PWRCTRL_PWRSEQ` 在 `drivers/pci/pwrctrl/Kconfig` 里只有 `tristate`（**无 prompt**）。
`CONFIG_ATH12K=m` 的 `select PCI_PWRCTRL_PWRSEQ` 会在 **kbuild 自己的 syncconfig**（不是 `olddefconfig`）
里把它重算成 `m`。实测序列：

（1）`apply-kernel-fragment.sh`（merge_config + olddefconfig）后手工追加 `=y` → `grep` 看到 `=y`；
（2）`make Image.gz` 触发 syncconfig → `.config` 又变回 `m`（而且**没有任何提示**）。

⇒ 「在 `.config` 末尾追加 `=y` 就能钉住」只对**有 prompt** 的符号成立。不可见符号要么改 Kconfig
（给它加 prompt / 去掉 select），要么承认它跟随 selector 的 tristate。

顺带更正 `PITFALLS #125` 的因果链：`ath12k=m ⇒ PCI_PWRCTRL_PWRSEQ=m ⇒ WiFi 全无` 并不成立。
真正给 WCN7861 供电的是内置的 `CONFIG_POWER_SEQUENCING_QCOM_WCN=y`
（`drivers/power/sequencing/pwrseq-qcom-wcn.c`），而 `pcie-qcom.c` 一次都没引用 pwrseq
（`grep -c pwrseq` = 0）。#125 当年的实测是「模块根本不在设备上」，与 `=y/=m` 无关；
2026-10-26 vk163 上 `pci_pwrctrl_pwrseq` 以模块加载，`wlan0`/rfkill/NM 全部正常。

## ② `modprobe` 对 builtin 也返回 0 ⇒ 加载器会给出假证据

`modprobe ath12k` 在内核把驱动编成 `=y` 时同样 rc=0（命中 `modules.builtin`），`lsmod` 里却永远不出现。
`scripts/payload-modules-load.sh` 原实现据此打印 `[payload] loaded ath12k`，在**非模块化内核**上
给出「7 个载荷模块全部加载成功」的假证据（2026-10-26 在 vk152 上实测复现）。

修法：`modprobe` 之后**用 `lsmod` 复核**，命中才报 `loaded`，否则报 `is builtin … (no-op)`；
并且模块名要做 `-`→`_` 归一（`lsmod` 打印下划线，`snd-q6apm` vs `snd_q6apm`）。

```sh
load() {
  local m=${1//-/_}
  lsmod | grep -q "^$m " && return 0
  modprobe "$1" 2>/dev/null || { echo "[payload] WARN: modprobe $1 failed" >&2; return 1; }
  if lsmod | grep -q "^$m "; then echo "[payload] loaded $1"
  else echo "[payload] $1 is builtin in this kernel (no-op)"; fi
}
```
