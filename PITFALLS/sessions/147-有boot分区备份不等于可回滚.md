# #483 · 「有 boot 分区备份」≠「可回滚」：写 boot 分区前必须先抓当前态基线（`logfs` + GPT 双表）

- 日期：2026-11-01（事故现场 `reports/uefi-slotboot-stuck-fastboot-20261101.md`）

## 事故形态

把 UEFI 载荷签进 `boot_b`（96 MiB，AVB testkey）→ `reboot`（走 ABL 正常 boot 路径）后：

- 14 s 直接进 fastboot，**从未出现 Android gadget**；
- 把 `boot_b` 刷回**原件**、`--set-active` 双向切、`misc` 清零 / `erase misc`、
  刷回**原厂 `boot_a`**、用户物理断电重启 —— **全部仍停在 fastboot**；
- `fastboot continue` 对两个槽都报 `Failed to load image from partition: Device Error`。

EDL 只读取证把「镜像内容」和「槽位属性」两条都排除了：
`boot_a` 读回 = 原厂备份逐字节相同，`boot_b` 读回 = 之前正常跑 vk183 的分区值；
LUN4 GPT 的 `boot_*` 属性字节改成 `active+successful+retry7` 并双表重算 CRC、写回、逐字节读回一致，
ABL 也真的接受了（`getvar` = `successful:yes` / `retry:7`，且 reboot 后不再递减）——**还是不启动**。

## 教训（按重要性）

- **boot 分区备份只覆盖「内容」，不覆盖「分区之外的持久状态」**：GPT 属性、`misc`、`devinfo`、
   `lenovoraw`、rpmb 里的 rollback / 版本计数、ABL 的 prevent-flash-verify 类修改检测，全都不在备份里。
   「刷回去就行」是错误的心理模型。
- **动手写 boot 分区之前，先抓当前态的判据基线**：`logfs`（8 MiB，10 段环形）、LUN4 GPT 主备 34 块、
   `misc`、`getvar all`。本次 GPT 抓了，但 `logfs` 只抓在写盘**之前**，正好缺了「坏掉那一次」那一段，
   导致事后无法判断 ABL 到底停在哪一步。
- **`fastboot continue` 的 `Failed to load image from partition: Device Error` 是独立信号**：
   它来自 ABL 的**加载层**，比 `Booting OKAY`（拒）和 `usb_read failed`（接手）都更有指向性
   ⇒ 判据表里应单列一档（`PITFALLS #481` 的三态是「上层终态」，这一条是「下层失败」）。
- **`Image size : 4096 Bytes` 不是通用判据**：在 TB322FC 上它出现在**能正常启动**的段里；
   别的机型（TB321FU）才是「ABL 解析失败」的标志。判据必须按机型实测，不能跨机型照搬。
- **`--set-active` 会把 retry 重置为 7**，所以「`getvar` 显示 retry 7」不能证明「没有尝试过启动」；
   要判「试过没试过」得看 `logfs` 里有没有 `Booting from slot` + `Loading Image`。

## 处置模板（下次）

```
# 写 boot 分区前 30 秒，先做基线（全部只读）
python3 edl.py --loader=<melf> r logfs  before/logfs.bin
python3 edl.py --loader=<melf> rs 0 34 --lun=4 before/lun4-gpt-primary.bin
python3 edl.py --loader=<melf> rs $((TOT-34)) 34 --lun=4 before/lun4-gpt-backup.bin
python3 edl.py --loader=<melf> r misc  before/misc.bin
fastboot getvar all > before/getvar.txt
```
