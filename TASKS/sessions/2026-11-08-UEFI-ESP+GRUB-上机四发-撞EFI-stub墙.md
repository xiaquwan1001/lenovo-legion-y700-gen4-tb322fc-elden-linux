# 2026-11-08（上午）— G1-29 后半上机 4 发：ESP+GRUB 打通到「菜单可操作、内核 PE 被装载」，EFI-stub 交接撞平台墙

- **日期**：2026-11-08 上午（接同日「主机侧备料」轮）
- **pi 会话 id**：见 `.pi/sessions/*.jsonl`（关键词「grub-arm64-standalone / esp blk=120 / DBI dump table」）
- **主题**：用户批准写盘 ⇒ 建 ESP、装 GRUB、p59 世代（R54-espfirst）上机 4 发
- **结论**：
  1. **写盘安全完成**：GPT 尾部**纯追加** 512 MiB ESP（`/dev/sda18` 名 `eldenesp`，`sgdisk -v` = No problems found；
     写入后读回 sha 与主机件逐字节一致；GPT 备份 `backup/HA2EXB0E-16+512/gpt_before-esp-20261108-0934_*.bin`）；
     `boot_b` sha 全程未变（`4e38bc2c…`）。工具 = `scripts/gpt-surgery-tb322fc.py append-free`。
  2. **链路上半段全部成立**（屏照）：`[K] esp blk=120` → `fs=8` → `ld=Not Found i=0`（modem_b）
     → **`ld=Success i=1`（我们的 ESP）** → **GRUB 2.14 菜单** → 选中条目后 `[I] base=…C5D80000 size=03F40000`（63.4 MB = 内核 PE）。
  3. **下半段是平台墙**：紧接着 `DBI dump table info not found` + `App Log Flush : 0 ms`（= Mu `CoreExitBootServices()` 尾巴）
     ⇒ 内核 EFI stub 调过 EB 后无任何输出、整机复位；四条取证通道同时空（无 fbcon 因 `# CONFIG_SYSFB_SIMPLEFB is not set`、
     gadget 未起、ramoops 0.08 s 未到、`ConOut` no-op）。同芯片项目 sunuefi 对同一交接有同样记录；
     平台侧差异 = `PlatformMemoryMapLib` 只有 `DXE Heap` ≈469 MiB 是 Conv，raw DT 有 ~15 GiB。
  4. **R54 四轮演进**（每轮判据写在补丁头）：入口扫描（fs=0 静默回退）→ 入口 `EfiBootManagerConnectAll`
     （本板同步异常、屏上地址循环刷）→ AfterConsole 扫描（MsCorePkg 的 AfterConsole 不 ConnectAll，仍 fs=0）
     → **按 BlockIo 定向 `ConnectController(...,TRUE)`（成）**。
  5. **面板按键契约（用户实测）**：GRUB 下 **音量上/下 = 移动高亮，电源键 = 确认**；`set timeout=8` 超时自动选第一项。
- **下一步（三选一，未执行）**：A 改固件内存表把 DDR 标 Conv（解锁通用 EFI-stub/GRUB，风险高）；
  B 自写 raw-jump loader 从 ESP 读 kernel/initrd/dtb（复用 p58 已验证交接口，最稳，菜单 UI 需自接按键）；C 回退（内核仍走 `boot_b`）。
- **证据指针**：
  - `reports/uefi-grub-esp-handoff-wall-20261108.md`（正文 + §3 路线 + §2b 按键）
  - 固件：`patches/uefi/20261108R54-espfirst/`、`patches/uefi/p59-recipe.txt` + `p59-kept.sha256`、
    镜像 `out/r21-sbstop-p59/uefi-preamble59-r1.img`（`cd73fbdc…`）、`scripts/uefi-r21-p7-ladder.sh --gen p59 --verify` PASS
  - 设备侧：`/dev/sda18`（ESP）内容 `EFI/BOOT/BOOTAA64.EFI` = `7993adfc…`；
    `/boot/{Image,initrd.img,elden.dtb,grub/grub.cfg}`；生成器 `scripts/grub-bootfiles.sh`
  - 坑 `PITFALLS #556/#557/#558`
- **★SSOT 待并入**：`TASKS/README.md` §5（已加）+ §1 G1-29 行（已改）；`PITFALLS` 索引（已加）
- **设备态**：U2 正常引导（`boot_b`），ESP+GRUB 在位但未被使用（R54 走 fallback）
