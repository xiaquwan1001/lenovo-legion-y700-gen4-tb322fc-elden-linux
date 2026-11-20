# #697 fastboot「无限回落」的三层真因（GUID 占位 / LUN 错配 / retry 抽干）与恢复顺序

- 日期：2026-11-20 22:00–23:10（U2 HA2EXB0E）
- 现象：`fastboot reboot` / `systemctl reboot` 后 **~4 s 又回到 fastboot**；`fastboot boot <好件>` 报
  `Failed to load/authenticate boot image: Device Error`；`slot-successful:b` = **no**。

## 1. 取证口径（怎么拿到定因，不靠猜）

- **ABL 自己的日志在 `logfs`（LUN4，LBA 409595，8 MiB，64 KiB/条环形）**：
  EDL 只读 `read "4/409595+2048"` → 按 64 KiB 切条、可打印字符过滤 → 找
  `KeyPress … / FindBootableSlot / ValidateSlotGuids / Boot lun`。
  判据：**最新一条写在 offset 0**（环回写），不是末尾。
- boot 分区内容与主机件对账：`boot_b` 读回 `740d431b…` = `bootslot-b/boot_b-minbase-labellinux-20261119.img`
  **逐字节一致**（O_DIRECT sha）⇒ 镜像本身没坏，问题在「ABL 让不让它起」。
- LUN4 GPT 与出厂 `gpt_main4.bin` 逐条目比：**type GUID / LBA 全同**（只有 attribute 字节不同）。

## 2. 三层真因（logfs 原文为证，按发生顺序）

| 层 | logfs 原文 | 含义 / 判据 |
|---|---|---|
| ① retry 抽干 | `Active Slot _b is bootable, retry count 6` → … → `Slot _b is unbootable, trying alternate slot` | `boot_b` 的 **SUCCESSFUL 位为 0** 时，ABL 每发减 1；7→0 后标 UNBOOTABLE ⇒ **停在 fastboot**。Linux 侧不 mark-successful 就必然走到这一步 |
| ② GUID 占位 | `ValidateSlotGuids: BootableSlot _b does not have valid guids` + `Boot GUID 77036CD4-…` / `abl_b GUID 77036CD4-…` | 该槽的 `boot_<s>` 与 `abl_<s>` **type GUID 相同**（= 出厂 b 侧占位值 `77036CD4-03D5-42BB-8ED1-37E5A88BAA34`）⇒ 判「无效 GUID」。canonical 侧（a 的出厂值，如 boot=20117f86 / abl=bd6928a1）不会相同 |
| ③ UFS 启动 LUN | `Boot lun: 1 and BootableSlot: _b do not match` | 启动 LUN 跟 active 槽走（**a→LUN1 / b→LUN2**，PITFALLS #484 同族）；只改 GPT 属性不切 LUN ⇒ 这一层拦下 |

**②③ 的机制来源（不再是黑箱）**：Qualcomm 的槽位切换**是把 partition type GUID 在 a/b 两个槽之间搬家**
（`hardware/qcom/bootctrl/boot_control.cpp` 的 `UPDATE_SLOT(pentry, guid, state)`：`memcpy(pentry, guid, TYPE_GUID_SIZE)`
+ 置/清 ACTIVE），同时切 UFS 启动 LUN（开源复刻 `abctl` README 同述）。
⇒ **「canonical GUID 在哪一侧」与「哪一侧是 active」必须一致**，否则 ABL 的 `ValidateSlotGuids` 直接拒。

## 3. 恢复顺序（本次实测，三次冷起均 ~25 s 直进 Linux）

- **① 只走 `fastboot set_active <slot>` 切槽**（它一次做完：搬 GUID + 改属性 + 切 LUN）。
   禁 `slot-attr.py` 单改 ACTIVE 位去「切槽」——那是半完成态，副作用是 ②（本次就是这么踩的）。
- **② 已经半完成态时（canonical GUID 在 a、ACTIVE 在 b 之类）：
   - `fastboot set_active a` 让 GUID 搬家一轮（把 canonical 送到目标槽），再 `fastboot set_active b`；
     每次之后都 dump LUN4 GPT（`scripts/linux-gpt-dump.sh`）逐条看 `boot_*`/`abl_*` 的 type GUID 是否**不同**。
   - 若 GUID 已经就位、只差 ACTIVE 位：用 `scripts/gpt-slot-flip-active.py`（只改 byte6 + 重算两表 CRC）
     + `scripts/linux-gpt-apply.sh --lun 4 --apply`（写前对账 + 写后逐字节/设备端 sha 读回）。
- **③ 最后 `fastboot set_active <同一槽>` 触发 **LUN 切换**（这一步是 ③ 的唯一解）。
- **④ 起来后 **`qbootctl -m` / `qbootctl.service`（已在机 enabled）** 把 SUCCESSFUL 落盘，否则回到 ①。

> 判据：`qbootctl` = `Active/Successful/Bootable 全 1`；`fastboot getvar slot-successful:b` = yes；
> 冷起 3 次都直进 Linux（无 fastboot 回落）。

## 4. 顺带确认的两条

- `fastboot boot <我们签的件>` 失败 **不是** 上述三层：`vbmeta_b` 的 chain 描述符要求 `boot` 公钥 sha1 `fc1e3b33…`，
  而 `bootslot-b/avb.key` 的公钥 sha1 = `1e54e86e…`（2026-10-18 换过钥匙，`vbmeta_b` 没跟着换）
  ⇒ 槽位启动靠 `Flags=3`（verification 关）绕过，`fastboot boot` 这条路走 AVB chain 就必拒。
- 板级镜像与出厂表对账要**逐字段**：本次「LUN4 与出厂同」只对 type GUID/LBA 成立，attribute 被别人改过，
  所以「等于出厂」不能当作「没被改过」的结论。

## 5. 新增/改动的仓内件

- `scripts/gpt-slot-flip-active.py`（只改 boot_* 的 byte6 + 重算两表 CRC，附 CRC 自检）
- `scripts/as-client-deploy.sh`（本轮另一件事：Audio Share Linux 客户端装机，见 INDEX §0）
- 证据目录：`logs/forensics-20261120-2210/{boot_b.img,logfs*.bin,misc.bin,vbmeta_a.img,vbmeta_b.img}`、
  `backup/HA2EXB0E-16+512/edl-20261120-22{08,35}/`（两次六 LUN GPT dump）、
  `backup/HA2EXB0E-16+512/edl-apply-readback-20261120-223802/`（写前回退基线）
