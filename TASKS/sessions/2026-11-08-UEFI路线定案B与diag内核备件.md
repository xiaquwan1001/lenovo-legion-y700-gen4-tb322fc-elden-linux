# 2026-11-08（下午）— G1-29 路线定案 B + diag 内核备件（零上机，设备离线）

- **日期**：2026-11-08 下午
- **pi 会话 id**：`.pi/sessions/*.jsonl`（关键词「route-b-espboot / fbdiag / SYSFB_SIMPLEFB / LoadImageAndAuth」）
- **主题**：UEFI 交棒墙之后的路线裁决与主机侧备料；同时派出四个一级子代理（邮件/文档/资产/droidloom/UEFI 仓库搜查）
- **结论**：
  1. **路线定案走 B**（ESP 上放 `boot.img`，由 Mu `LinuxLoader` 变体从 ESP 读起），不做 A（改固件内存表）。
     静态核对把改动面收窄到**一个函数**：`LoadImageAndAuth()`（`VerifiedBoot.c:1658`）加「ESP 优先」分支；
     `BootLinux()` 的取件是查 `Info->Images[]` 表（`BootLinux.c:1445`），内存图/DTB/ramdisk 全复用 p58 已验证路径。
  2. **diag 内核已备**（`out/fbdiag-20261108/Image.fbdiag`，vk184 同源 + `CONFIG_SYSFB_SIMPLEFB=y`，
     UTS `7.3.1-debug-fbdiag-00003-gec74c4795a43`，`sha256 b85afec4…`，硬门 PASS）。
     但**判它很可能不亮**：本平台 UEFI 无 GOP，屏是 Mu 用 `Display Reserved` 直涂 ⇒ `simpledrm` 绑不上。
     它只作「B 也死且要早期输出」的备用件，不列为必做。
  3. **设备当前离线**（`adb`/`fastboot`/ssh 三路都不见 U2）⇒ 本轮上机项全部顺延，需要用户开机 + 接 USB。
  4. 过程中撞到自己埋的坑：裸 `make olddefconfig` 漏 `ARCH=arm64` 把 `.config` 按 x86 重写（`#162` 同型）；
     已从备份还原、带 ARCH 重跑、并在 `#162` 正文补记。
- **证据指针**：
  - `archive/plans-20261110/2026-11-08-g1-29-route-b-espboot.md`（D1–D5 + 回退 + 判据）
  - `reports/uefi-route-b-prep-20261108.md`（本轮主机侧事实与复现命令）
  - `patches/config-fbdiag-20261108.fragment`、`out/fbdiag-20261108/`
  - `scripts/check-doctor.sh` → **FAIL=0 WARN=5**
- **★SSOT 待并入**：`TASKS/README.md` §1 G1-29 行剩余项（B 路线定点）+ §5 Q25 一行指针；
  `PITFALLS` #162 正文（已补，不新增编号）
- **设备态**：U2 不在机（离线）；`boot_b` 与 ESP+GRUB 保持 11-08 上午状态，无本轮写入
