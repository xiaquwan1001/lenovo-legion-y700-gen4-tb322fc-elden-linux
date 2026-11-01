# #486 · 本机 EDL loader 不放行 `peek` ⇒ 「EDL 直读 DDR」通道不可用（含三条正向事实：`fastboot oem edl` 可用 / udev 生效 / edl-ng 够用）

日期: 2026-11-01
pi 会话 id: 01a19772-4f38-7466-a690-e9551ed1e955
主题: EDL Firehose `peek`（任意物理地址读）在本机是否可用 —— 定案：**不可用**
结论: loader `xbl_s_devprg_ns.melf` 的 Supported Functions **不含 peek**，`rawxml` 手发也被空回包拒绝；
      ⇒ UEFI「载荷是否执行」的 DDR 标记无法靠 EDL 读回，只能「切断回落 + `fastboot boot` Linux 回读」
证据指针: `../reports/uefi-ddr-fallback-plan-20261101.md` §1.4（编排者实测更正）、`../reports/trials/20261101T150336Z-edl-peek-probe-r1.json`
★SSOT 待并入: `TASKS/README.md` §5 的 2026-11-01 UEFI 线；UEFI ①「EDL peek」方案作废

---

## 负向结论（一发定案，未再重试）

- **① loader 回出的 Supported Functions 无 peek**（`firehose_client` 原样输出）：
   `program,read,nop,patch,configure,setbootablestoragedrive,erase,power,firmwarewrite,getstorageinfo,benchmark,emmc,ufs,fixgpt,getsha256digest`
   ⇒ host 侧 `firehose_client.py:522-527` 的 `check_cmd("peek")` 直接拒绝：`Peek command isn't supported by edl loader`。
- **② 绕过 `check_cmd` 用 `edl.py rawxml` 手发 `<peek>` 同样失败**（两发不同属性命名，`address64="0x81D00000"` 已知非零 smem 探活）：
   均 `failed.` + 空回包 `[]` ⇒ loader 侧不实现 / 被 secboot 门控，**不是 host 侧拦截**。
- **③ 静态推断（loader 明文有 `Peek is disabled on secure boot devices%c`）只能写「可能」；**判据必须上机一发**。
   本机结论定案后 `scripts/edl-peek.sh` 仅留作记录，勿再试（重复试错违反「一次正反判断」）。

## 正向事实（同一次上机顺带坐实，可复用）

- **`fastboot oem edl` 可用**：`OKAY [0.001s]`，约 4 s 后 `lsusb` = `05c6:9008` ⇒ 免按键进 9008 首次拿到**实测**证据
  （此前只有 2026-10-03 档案 `archive/topics/复盘.md:63`）。
- **udev 规则生效**：`/dev/bus/usb/001/044` = `crw-rw-rw- root plugdev` ⇒ 无需 sudo；非 root 跑
  `udevadm control --reload-rules` 会报 `Failed to connect to udev via varlink: Permission denied`（≠ 规则没写）。
- **edl-ng 1.6.0（QCEDL.NET）在本机可用**：`edl-ng printgpt -u 4 -l <melf> --memory Ufs` 正常列出 LUN4 全表
  ⇒ 存储/GPT/读写擦以 edl-ng 为准（无 python 依赖、单条命令）；**只有 peek 族必须 python edl，而本机 loader 又不放行**。
- **`edl-ng reset` 从 9008 回 Linux 正常**：约 9 s ssh 上来，`boot_id fb08d9d7…`，槽位未变（零写盘实验的安全出口）。
