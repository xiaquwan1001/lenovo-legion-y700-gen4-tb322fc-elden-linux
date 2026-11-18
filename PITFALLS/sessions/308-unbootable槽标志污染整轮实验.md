## #672 实验前必须先读 A/B 槽属性：`boot_x` 条目 byte6 的 bit7(0x80)=UNBOOTABLE 会让 ABL **直接拒绝执行镜像**，把一整轮失败样本全部污染

**现象（2026-11-18，安卓「最小化线刷包」试装）**：三发试装全部「没进 Lenovo logo → 黑屏 → 回 fastboot」：
① 我方 8.28 GiB `super_min` + 原厂 metadata；② 我方 system fs + 原厂 `vbmeta_system` + Flags=1 `vbmeta_a`；
③ **全量回滚原厂 `super_1..8` + `vbmeta` + `vbmeta_system`（sha 逐字节核验一致）后仍然不启动**。
第③发是整个 lane 的关键反证：连官方件都不起 ⇒ 不是我们的镜像有问题。

**定因**：LUN4 GPT 里 `boot_a` 条目 attribute byte6 = **`0xf7`** = bit7(0x80) **UNBOOTABLE** + bit6(0x40) BOOT_SUCCESSFUL +
retry=`(0xf7>>3)&7`=**6**。按 `scripts/slot-attr.py` 头注释与技能 `qbootctl-slot-management` 的口径，**ABL 在 UNBOOTABLE 槽上直接进 fastboot，
连尝试都不尝试** ⇒ 三发都只是「ABL 拒绝执行」，**不是镜像判据**。

**为什么会有 0xf7**：这个位是 ABL 在「active 槽连续启动失败、retry 计数归零」时自己置的（历史：11-10 起反复 `fastboot boot`/`boot_a` UEFI 实验）。
之后所有「a 槽能不能起」的实验都是**在污染状态下做的**，谁做的都会得到同一个假结论。

### 判据（每次上机实验前 30 秒，不可跳过）

```sh
# 设备在 Linux（b 槽）时：
python3 scripts/slot-attr.py show            # 读 /dev/sde（LUN4）里 boot_a/boot_b 的 byte6
# 设备在 fastboot / 离线时：用 LUN4 GPT dump（主表 LBA0..5 + 备表末 6 LBA）
python3 scripts/slot-attr.py --image backup/.../lun4-gpt-main.bin show
```

- `0x7x` = 正常（successful）；**出现 `0x8`/`0xf` 高位 = UNBOOTABLE**，此时**任何「刷了能不能起」的实验都无效**。
- 判据纪律：**设备回到 fastboot 而没有 Lenovo logo / 没有背光变化 / 时间 < 3 s ⇒ 先查槽属性，再怀疑镜像**。
  「回滚原厂件也不起」这个现象本身就是槽属性的指纹，不要把它记成「原厂包也坏了」。

### 处置

- 清 UNBOOTABLE：`scripts/slot-attr.py set a --successful --retry 7 --no-unbootable`，
  **主表与备表必须一起改**（`--image` 路径要同时给主/备两份 dump，或直接用 `linux-gpt-apply.sh --lun 4 --gpt … --backup … --apply`）。
- 每次实验收尾：写完整链后 `mark-successful <slot>` + `--retry 7`，并在报告里贴一次 `show` 的原始行。
- 跑实验的脚本必须**开头 show 一次、失败路径也留日志**（见同轮脚本审查 R2）。

**注意槽基线**：bit7 只在 **a 槽**等于 UNBOOTABLE；`boot_b` 出厂就是 `0xf3`（bit7=1），b 槽不能按 bit7 判（#678）。

**推广**：这是「失败标志未清理 ⇒ 后续实验全部无效」的第二个实例（第一个是 `#181` b 槽不置 succ 每次扣 retry）。
凡是有持久失败状态的地方（AVB rollback index、misc BCB、watchdog 计数、Q28 看门狗 2 次预算），**实验前都要先读一次现值**。

证据：`TASKS/sessions/2026-11-18-安卓最小线刷包-主机侧造件与EDL试装失败.md`；`INDEX.md` §0 设备状态行；
`backup/HA2EXB0E-16+512/edl-20261118/` 的 LUN4 表 dump；技能 `qbootctl-slot-management`。
