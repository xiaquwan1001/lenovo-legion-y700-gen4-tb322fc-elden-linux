# G1-29（2026-11-08 下午·主机侧）：下一步的情报准备 —— diag 内核 + 路线 B 设计定案

> 线：G1-29（拓展，非主线）。**本轮零上机、零写盘**（设备当前离线）。
> 承接同日 `reports/uefi-grub-esp-handoff-wall-20261108.md`（EFI-stub 撞墙）与 `TASKS/sessions/2026-11-08-UEFI-ESP+GRUB-上机四发-撞EFI-stub墙.md`。

---

## 0. 结论

1. **路线定案：走 B（ESP 侧自备 `boot.img` + Mu `LinuxLoader` 变体）**，不先做 A（改固件内存表）。
   静态核对把 B 的改动面收窄到**一个函数**：`LoadImageAndAuth()`（`Library/avb/VerifiedBoot.c:1658`）
   加「ESP 优先」分支 —— 因为 `BootLinux()` 取件走 `GetImage()` 只是查 `Info->Images[]` 表
   （`BootLinux.c:1445`），内存图/DTB/ramdisk 全在 `BootLinux()` 里且已由 p58 验证。
   设计与 D1–D5 见 `.pi/plans/2026-11-08-g1-29-route-b-espboot.md`。
2. **可见性备用件已构建**（主机侧）：`out/fbdiag-20261108/Image.fbdiag`
   = vk184 同源树 `wt/reb-731` + `CONFIG_SYSFB_SIMPLEFB=y`，UTS `7.3.1-debug-fbdiag-00003-gec74c4795a43`，
   63 443 456 B，`sha256 b85afec4…`；打包前硬门 `assert-kernel-sane.sh` 以
   `LOCALVERSION=-fbdiag` 通过（config 锚点 / System.map 符号 / UTS 对齐）。
   同时备好 GRUB 三件（`Image`/`initrd.img`/`elden.dtb`/`grub.cfg`，来自 `out/boot-elden-vk184.img`）。
3. **但这条可见性通道很可能不亮**：本平台 UEFI **不提供 GraphicsOutput**，屏是 Mu 自己拿
   `Display Reserved` 直接涂（`Platforms/AndromedaPkg/Library/FrameBufferSerialPortLib`，R21 补丁的惰性初始化
   就是找这个区）⇒ `simpledrm` 无 EFI framebuffer 可绑。**B 路线本身不需要它**（内核起来后 `msm` 自己点屏）。
   故 diag 内核只作「万一 B 也死且需要早期串口输出」的备用件，不列为下一步必做。

## 1. 本轮实际做了什么

| 步骤 | 命令/产物 | 结果 |
|---|---|---|
| 取 config 基线 | `cp wt/reb-731/.config /tmp/reb731-config-base-20261108` | `sha256 6f7f592a…`（与 `out/boot-elden-vk185-adsp.manifest` 的 `config_sha256` 一致） |
| 打开 fbcon 前提 | `scripts/config --file .config -e SYSFB_SIMPLEFB` + `make ARCH=arm64 olddefconfig` | 与基线**只差 3 行**（`CONFIG_SYSFB_SIMPLEFB=y`、掉一个不启用的 `DRM_EFIDRM`、多一个 `CC_CAN_LINK`） |
| 构建 | `make -j26 ARCH=arm64 … LOCALVERSION=-fbdiag Image Image.gz` | 37 s（ccache 热）；`Image` 63 443 456 B / `Image.gz` 20 809 541 B |
| 硬门 | `LOCALVERSION=-fbdiag KDIR=wt/reb-731 scripts/assert-kernel-sane.sh …/Image.gz` | **PASS**（ABI 敏感项 27 项一致；`gcc_sm8750`/DSI/`qcom_rpmh` 都在） |
| GRUB 三件 | `scripts/grub-bootfiles.sh --boot-img out/boot-elden-vk184.img --out out/fbdiag-20261108` | `Image`/`initrd.img`(64 622 358)/`elden.dtb`(153 089)/`grub.cfg` |
| 片段入库 | `patches/config-fbdiag-20261108.fragment` | 一行 fragment + 应用说明 |

`wt/reb-731/.config` 现存 `sha256 a17fd712…`（= 基线 + 这一行）；内核工作树 git 状态仍 clean（`.config` 未纳管）。

## 2. 过程中撞到的坑（已回退，无残留）

第一次跑 `make olddefconfig` **漏了 `ARCH=arm64`** ⇒ 按宿主 x86 重写 `.config`，`CONFIG_ARCH_QCOM` 等
arm64 符号**全部消失**（正是 `#162`/`#362` 的同型事故，但触发方式不同：不是脚本，是裸命令漏 ARCH）。
已立刻从 `/tmp/reb731-config-base-20261108` 还原并带 ARCH 重跑；`.config` 只差上表 3 行。
已在 `PITFALLS` #162 正文补一行「裸 `make olddefconfig` 漏 `ARCH=arm64` 也会全抹」+ 必带 ARCH 的写法。

## 3. 复现（全程主机侧）

```bash
cd ~/y700-elden
cp wt/reb-731/.config /tmp/reb731-config-base-20261108
. scripts/env-build.sh
(cd wt/reb-731 && ./scripts/config --file .config -e SYSFB_SIMPLEFB \
  && make ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" olddefconfig \
  && make -j26 ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" LOCALVERSION=-fbdiag Image Image.gz)
LOCALVERSION=-fbdiag KDIR=wt/reb-731 scripts/assert-kernel-sane.sh wt/reb-731/arch/arm64/boot/Image.gz
scripts/grub-bootfiles.sh --boot-img out/boot-elden-vk184.img --out out/fbdiag-20261108
cp wt/reb-731/arch/arm64/boot/Image out/fbdiag-20261108/Image.fbdiag
```

## 4. 设备侧待办（需用户物理动作：开机 + 接 USB）

1. 目标盘件：`out/r21-sbstop-p59/uefi-preamble59-r1.img`（`cd73fbdc…`，p59 世代）+ `fastboot boot`（零写盘）。
2. 本次先用**已装好的 GRUB 菜单**复跑一次「GRUB 直启」确认墙仍稳定（判据仍是屏上到 `App Log Flush` 即死）。
3. 之后按计划 §2 的 D2–D5 落 B 路线件（需先派实现子代理出补丁与 PE 件）。

## 5. 证据指针

- 计划：`.pi/plans/2026-11-08-g1-29-route-b-espboot.md`
- 产物：`out/fbdiag-20261108/{Image,Image.fbdiag,initrd.img,elden.dtb,grub.cfg,cmdline.txt}`、
  `patches/config-fbdiag-20261108.fragment`
- 上游代码位置：`build/uefi-woa-prep/repos/7-mu-lenovo/Platforms/QcomModulePkg/Library/avb/VerifiedBoot.c:1658`、
  `.../Library/BootLib/BootLinux.c:1445`（GetImage）、`:903`（BootLinux）
- 坑：`PITFALLS #162`（补记 ARCH 漏传）、`#549/#555/#556/#557`
