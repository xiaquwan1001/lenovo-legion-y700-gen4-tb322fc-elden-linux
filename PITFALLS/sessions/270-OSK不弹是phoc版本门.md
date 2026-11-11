# 点输入框 OSK 不弹 = phoc 的「版本门」，不是缺 bb1f7465（#615）+ droidloom 通知降级不可行（#616）

> 索引行见 `PITFALLS/README.md` 第 270/271 行。首次取证：2026-11-11（设备实测 + phoc 源码静态），
> 消费者报告 `reports/ime-osk-pop-20261111.md`、`reports/doc-ime-scope-audit-20261111.md`、
> `reports/droidloom-warn-20261111.md`。

## #615 「点输入框 OSK 不弹」在 phoc 上是协议分工（`enable` 对 v≥2 客户端**故意** return）

### 现象与判据（设备实测，2026-11-11 两次独立复现）

- 客户端侧**一切正常**：GTK3/GTK4 窗口拿到焦点后发 `zwp_text_input_v3#N.enable()` + `commit()`
  （`WAYLAND_DEBUG=1` 抓包，我本轮独立抓包复现：`enable=1 commit=1`）。
- 结果：`sm.puri.OSK0` 的 `Visible` **恒 false**、stevia 侧无 `activate`。
- 因此判据**不能**用「客户端不发 text-input」作结论——那只是 `GTK_IM_MODULE=fcitx` 的另一层遮蔽；
  去掉 IM 模块后客户端照样发 `enable`，键盘仍不弹。

### 真机制（phoc 0.58 与 0.59~rc1 逐字节同源，我本轮 diff 过）

`src/input-method-relay.c`（0.58 行号）：

```c
static void
handle_text_input_enable (...)
{
  ...
  /* TODO: only for osk input-methods */
  if (wl_resource_get_version (text_input->input->resource) >=
      ZWP_TEXT_INPUT_V3_SHOW_INPUT_PANEL_SINCE_VERSION)
    return;                      // ← v2 客户端在此被挡掉

  activate_osk (text_input);
}
```

- `src/desktop.c:62` `#define PHOC_TEXT_INPUT_VERSION 2`；`show_input_panel` 在 text-input-v3 的
  `since version 2` 才出现 ⇒ **phoc 自己广告 v2，于是每个客户端都是 v2，于是这个分支永远 return**，
  只剩 `handle_text_input_show_input_panel()` 一条 activate 路径。
- 现实后果：**GTK 从不发 `show_input_panel`** ⇒ 在 phoc 上「聚焦即弹键盘」对 GTK 应用结构性不成立，
  与 `fcitx5`/`stevia`/`wvkbd` 都无关。
- 这也解释了为什么 2026-10-20 那一版能弹：当时的 `elden-ime-focusd` 是**直接调 `sm.puri.OSK0.SetVisible(true)`**，
  绕开了这条协议链（不是 `activate` 生效）。

### 三条处置（按代价）

- **① `focusd` 桥**（A1，零重编）：kimpanel `SetRelativeSpotRect`/`FocusIn` → `SetVisible(true)`；
   源码在 `patches-userland/zh-ime/elden-ime-focusd.c`，但设备侧 `org.kde.impanel` **无 owner**（实测 `busctl --user list | grep -c org.kde.impanel` = 0，
   Debian 栈还没部署）。
- **② phoc 去版本门**（1 行，需重编 15–25 min）：把上面那个 `return` 去掉（或加 `g_getenv("PHOC_OSK_ON_ENABLE")` 门），
   让 `enable` 走 `activate_osk()`。这条与 A2/A3 的 waylandim 方案**正交**：`--disable waylandim` 保持不动也能弹键盘。
- **③ A2/A3**（fcitx5 开 `waylandim` 独占 IM 槽 + `wvkbd` 走 virtual-keyboard）才需要上游 `bb1f7465`（grab NULL 修复），
   **与我们现在的「不弹」不是同一个缺陷** —— 别再把两者混成一条。

### 反向纪律（防再误判）

- 「升到 phoc 0.59 就好了」**不成立**：0.58 → 0.59~rc1 的 `input-method-relay.c` 只差 grab NULL 那一处，
  上面那个版本门两版**完全一致**（`diff -u` 实测仅 `@@ -116,10 +116,11 @@` 一个 hunk）。
- 判「OSK 该不该弹」时，客户端侧只看 `zwp_text_input_v3.enable()`，**不要**看 `show_input_panel`
  （GTK 不发），也不要看 `phosh` 的 D-Bus 偏好（`osk-manager.c` 只表达偏好，不做兜底）。

## #616 droidloom 通知紧循环：不能靠热补丁二进制「降级」，只能重编加 env 门

- **现状（2026-11-11 实测，已自愈）**：boot 内 `journalctl -b | grep -c 'invalid Android frame'` = **0**；
  `droidloom-doctor` = **13 PASS / 1 WARN（`Host LSM hardening`，非必需）/ 0 BLOCK**；
  15:38/15:41 两次 cell 会话 `Android connected` 后 0 次失败；adb 实发通知宿主落盘 ⇒ 通道端到端可用。
  紧循环只发生在 12:40–13:53 **那一次会话**（1919 次 / 2 s 周期 ≈ **0.5 次/秒**，「1 次/秒」旧口径要更正）。
- **ABI 错配假设已被否证**：Android 侧 logcat 宣告 `DROIDLOOM_NOTIFICATIONS_ABI=3;`，
  与宿主 `strings /opt/dl-test/usr/bin/droidloom-wayland` 的 `DROIDLOOM_NOTIFICATIONS_ABI=3;` 同值
  （另三通道均 `=1`）。
- **为什么不能热补丁「关掉通知桥」**（本轮 objdump 实证，别再试）：
  `Bridge::start` 符号 = `0xafc14`，**唯一调用点 = `main+…` `0x7a6e0`**，返回 `Result<Bridge, Error>`
  经 **sret**（调用前 `add x8, sp, #0x50`）写到栈上，之后由 `drop_in_place<Result<Bridge, Error>>`
  析构 ⇒ **把它 NOP 掉会留下垃圾 tag，析构时 UB/崩**，不是「干净地不启通知」。
  二进制里也**没有**任何 `DROIDLOOM_*` 运行时开关（`Bridge::start` 不接受 env/配置）。
- **正解**：重编时在 `Bridge::start` 入口加 `DROIDLOOM_NOTIFICATIONS=0` 门（rev30 源码 `main.rs:3065-3068` 无条件 `start()`）。
  验证 = 同 boot 内 `grep -c 'invalid Android frame'` 恒 0 且 `droidloomctl applications` 与 L4 窗口判据不受影响
  （通知桥与 applications/clipboard 通道独立）。

## #617 GRUB→EFI-stub 直启在本板「60–70 s 硬件掉电」，墙在我们这套 UEFI 件、不在机型/GRUB

- **判据链（2026-11-11 三发一致）**：不是 panic —— `/sys/fs/pstore/` 为空（E4 已补 `record-size`）、
  `dmesg` 明确 `Hard watchdog permanently disabled` 且无 `/dev/watchdog`、下次起机 `uptime` 归零（冷上电）。
  `initcall_debug` 那发文字持续 100 s 量级（`earlycon=efifb` 逐行写像素 ≈45 ms/行）⇒ 内核在 EFI 路径下**能走完数百个
  device_initcall**（vmlinux 里 device_initcall 共 1297 条），死点在 **~60–70 s 之后且无 panic 记录**。
  ⇒ 「EB 之后立即死」「≈15 s = `panic=15` 计时」「EFI 只给 469 MiB」三条旧判读**全部作废或收紧**。
- **社区反证（决定性）**：同机型 TB322FC 上 `Project-Aloha/mu_aloha_platforms` PR #820（作者 retro98boy）
  正文原话 *"Booting Armbian through Aloha → GRUB → Linux with a DTB"*（我 2026-11-11 直接抓 PR 页面核对过）；
  同 SoC SM8750 的 OnePlus 13 用 Mu-Silicium → GRUB → `linux` 也起得来，**两处都没有「跑一阵掉电」记录**
  ⇒ **不能对外说「本平台原理上不能 EFI-stub 直起」**，墙在我们的 **QcomModulePkg 血统 + 诊断补丁**那套件。
- **上游无捷径**：GRUB 2.14（= 当前最新发布，`mirrors.edge.kernel.org` 列到 2.14）的 arm64 只有 `loader/efi/linux.c`
  （`LoadImage`+`StartImage`，非 PE 内核直接报错 `plain image kernel not supported`）、`arm64/xen_boot.c`（同样要 EFI-stub 头）、
  `chainloader`（只能串 EFI 应用）；GRUB 自己**从不调** `ExitBootServices`、不碰内存属性、不做 `SetVirtualAddressMap`。
  `master` 与 2.14 的 `linux.c` 逐字相同 ⇒ **换版本无收益**。
- **第一发实验（最省）**：cmdline 加 **`efi=noruntime`** 单变量 ⇒ 一次把「EFI runtime 服务在 EBS 后被内核调用 → 固件侧掉电」
  整类证实/排除。其余候选机制 M1–M6、5 条实验清单与判据见 `reports/grub-project-scan-20261111.md` §3/§4。
- **别再做的事**：在 GRUB 配置里用 `set` 变量拼 cmdline（E2a 因此拿到残缺 cmdline 秒死，曾被我方误读成「白闪与 msm 无关」）；
  把拍屏 OCR 出的驱动名当证据（`gcc_ao_clk_driver_init` 等名字在 vmlinux 里根本不存在）。
