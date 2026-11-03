# UEFI 线 P1：DDR 标记「正控」实验（Linux 内核最早入口写标记）——2026-11-03

> 性质：主机侧构建（已完） + **一发零写盘 `fastboot boot`**（已执行，结果待读回）。
> 背景：`reports/uefi-next-step-decision-20261103.md`（三线核查后的裁决）。
> 目的：先证「经 boot.img 装载的代码在极早期能否写这四块 DRAM 窗口，且复位后 Linux 侧读得回来」。
> 这一步是 11-02 四臂全 0 的**前置控制**（`TASKS/sessions/2026-11-02-UEFI四臂判别与收尾.md` §4 未做项 1）。

---

## §1 构建（主机侧，已完）

| 项 | 值 |
|---|---|
| 内核源 | `build/vk183-fastrpc`（HEAD `509f271d52`，干净工作区） |
| 补丁 | `patches/uefi/20261103-posctrl/0001-arm64-head-ddr-stage1-marks.patch`：在 `arch/arm64/kernel/head.S` 的 `primary_entry` **第一条** 插 4×512 次 `str`（整页 0xFF）→ 四窗口各一页 |
| 窗口 | `0xE3F00000`（**判据窗**，boot_b cmdline 已 `memmap=1M$` 保留）、`0x84A00000`/`0x9C300000`/`0x89300000`（11-02 已证「回落启动不清」的 carveout，旁证窗） |
| 反汇编核对 | `vmlinux` 的 `primary_entry` 起始 6 条 = `mov x9,#0x84a00000 … mov w14,#0x200` + `str x13,[x9],#8`…（见 §4 附录命令） |
| 打包 | **不新打包**：`scripts/bootimg-replace-kernel.py`（本轮新增）把新 `Image.gz` 换进**在机 `boot_b` 原件**，其余逐字节保留 |
| 在机原件 | `reports/artifacts/uefi-posctrl-20261103/boot_b-live.img`，sha256 `fb55997c…c35169`（与 `DEVICE/README.md` §1.1 记录一致） |
| 产物 | `out/boot-elden-posctrl-20261103.img`，84 525 056 B，sha256 `9dfdb3319b61…eb60993` |
| 结构对账 | `scripts/bootimg-replace-kernel.py --verify` → **`only-kernel-differs`**（kernel 19 766 148→19 765 071 B；ramdisk 64 595 425 B / dtb 153 101 B / cmdline **逐字相同**） |
| 标记真实性 | 解压镜像内核段后 `Image` 内命中 `d2b09409`（= `movz x9,#0x84a00000`），确认标记进了产物而不是只进了源码 |

## §2 上机（一发，零写盘）

- 命令：`scripts/uefi-boot-trial.sh --image out/boot-elden-posctrl-20261103.img --label uefi-posctrl-linuxentry --watch 55`
- 门禁：`boot_b succ=1 retry=6 unbootable=0` → GATE=OK；`current-slot: b`；`slot-unbootable:b: no`
- `fastboot boot`：`Sending OKAY [1.873 s]` → `Booting OKAY [10.106 s]` → 12.0 s 返回
- 采样 55 s：`usb_present=9/55`（前 9 个采样有 USB，之后消失）⇒ 脚本判 `HANDOFF`（= ABL 接受并开始启动）
- **用户目视（14:2x）**：过联想 logo 后**只剩背光亮**，无画面、无 USB、无网络 ⇒ 内核**确实开始执行**（背光=面板已上电），但本次重建的内核没走到用户态
- **重要对照**：这一发**没有出现**「1–2 s 整机掉电」，设备持续带电 ≥2 min。⇒ 11-01 记的「跳转后 1–2 s 掉电」**是 UEFI 载荷路径特有**，不是「任何非 Android 载荷」的共性

## §3 标记读回（待执行：需一次物理断电重启）

设备当前停在背光亮的状态（无 ssh/USB 通道），必须**长按电源键 ~10 s 强制断电**，再按电源键开机回 `boot_b`（日常 Linux）。
开机后跑：

```
scripts/blackbox.py read --pa 0xE3F00000     # 判据窗
scripts/blackbox.py read --pa 0x84A00000     # 旁证窗
scripts/blackbox.py read --pa 0x9C300000
scripts/blackbox.py read --pa 0x89300000
```

判据（单调编码，阈值 = popcount≥6 的字节占比 ≥50%）：

| 读回 | 结论 | 对 UEFI 线的含义 |
|---|---|---|
| stage 0 REACHED（四窗任一或判据窗） | **正控通过** | 「boot.img 装载的代码在极早期能写这些窗口 + 复位后可读」成立 ⇒ 11-02 的 stage1=0 **确实是载荷没执行**，不是通道假阴性 |
| 四窗全 0 | 正控失败 | 窗口不可写 / 回落清掉 / 读回窗被内核覆盖 ⇒ 之前所有「stage=0」结论**不可信**，须先修通道 |

## §4 证据与复现

- 构建/核对：`vmlinux` 反汇编 `aarch64-linux-gnu-objdump -d vmlinux | sed -n '/<primary_entry>:/,+20p'`
- 镜像对账：`python3 scripts/mkbootimg.py --selftest <img>`；`python3 scripts/bootimg-replace-kernel.py --verify out/boot-elden-posctrl-20261103.img reports/artifacts/uefi-posctrl-20261103/boot_b-live.img`
- 现场：`reports/artifacts/uefi-boot-20261103-142023/{run.log,usb-watch.txt,fastboot-pre.txt,gate.txt}`
- 0xFF 页判读阈值与单调编码依据：`reports/uefi-ddr-blackbox-20261101.md` §2（G2：0xFF 页复位后 81%–86% 字节 popcount≥7；0x00 页 100% 仍 0）
