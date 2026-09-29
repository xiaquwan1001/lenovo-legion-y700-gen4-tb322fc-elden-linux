# 减少物理重启的工作规划（BATCH_PLAN）

> ⚠️ **部分过时（2026-09-29，见 `INDEX.md`）**：
> - §2.3「持久 root 未做」→ **已完成**（`/dev/sde79`，`elden_root=LABEL=linux`，见 HANDOFF §16）。
> - §4 批次队列：**B2 已完成**；B3（kexec）**已证伪弃用**；B4 大部分功能已落地。
> - §12「WiFi 卡在缺 PEACH 固件」→ **已打通**（见 HANDOFF §21）。
> - **仍然有效**：§1 成本分层、§2.1 kexec 不可用结论、§2.2 UFS 可见、§3 物理介入模板。

> 目标：把"必须按电源键/物理干预"的次数压到最低。日期：2026-09-28。

## 1. 成本分层

| 类别 | 例子 | 代价 |
|---|---|---|
| A 主机离线 | 编内核、改 DTS/config、打 rootfs、解析固件元数据 | 0 |
| B 系统内 SSH（同一 boot 内） | 挂 UFS 分区、拉固件、测驱动/固件、Vulkan/GL、dm/losetup | 低，可无限次 |
| C 换内核/config/ABL | 新 Image、新 dtbo、新 cmdline | 高（一次 boot） |

## 2. 三个"软化开关"（已实测）

1. **kexec：装载可用，执行不可用** ⚠️（本轮实测）
   - `kexec -s -l`（file_load）→ `FILE_OK`；`kexec -l`（load）→ `LOAD_OK`（含 `--initrd`）。
   - **`kexec -e` 会黑屏挂死**（新内核未起、无 USB gadget），需物理重启。
   - 原因（推断）：arm64/Qualcomm 上跳到新内核后无法复位 GIC/PMIC/次级 CPU，属平台限制。
   - **结论：不能靠 kexec 做内核热切换。** 软重启路径改用 `reboot`（进 ABL→fastboot，无需按电源键；待实测）。
2. **UFS 全分区在 Linux 可见** ✅
   - 5 个 LUN（sda..sde）全部枚举；ext4/f2fs/vfat 直接挂载。
   - Android `super`（sda10）可用 LP 元数据 + `losetup -o` 定位动态分区（见 `probe/result/lp-map.txt`）→ vendor/vendor_dlkm 可读。
3. ~~**持久 root 到 UFS**（未做，最高杠杆）~~ → **已完成（见 HANDOFF §16）**
   - 把 Alpine/完整 Mesa 写成 ext4 到 `sda16`(userdata)/新分区，cmdline `root=`。
   - 做了它，用户态迭代脱离 RAM 96MiB 限制，也脱离重启。

## 3. 每次物理介入的模板

离线备齐该包全部产物；上机后脚本一次跑完，结果落 UFS + SSH 回传；尾部优先 kexec 换内核，否则 `reboot bootloader` 由主机 `fastboot boot` 接下一包。

```
□ 固件/DT/config 采集（B，一次拿全）
□ 多组内核/驱动实验合并进一个 Image（C 内并行）
□ 结果写 UFS + SSH 取回
□ 结束：kexec 换内核 → 否则 reboot bootloader 链式 fastboot boot
```

## 4. 批次队列

| 批次 | 内容 | 状态 |
|---|---|---|
| B0/B1 | 采集固件/DT/config + kexec 探针 | ✅ 完成（一次 boot） |
| B2 | 持久 root 到 UFS（Alpine+完整 Mesa） | ✅ 完成 |
| B3 | kexec `-e` 端到端内核热切换 | ❌ 证伪弃用（arm64 平台限制） |
| B4 | WiFi/音频/触屏/165Hz 合版验证 | 大部分完成（WiFi 已通；音频待自编 tplg） |

## 5. 本轮（B1）实测结论

- kexec 双系统调用 OK；无 `/sys/kernel/reboot-mode`（软回 fastboot 需另设）。
- 全部固件已离线/在线采集完成，见 `backup/fw/` + `probe/result/`。

## 8-12. 历史批次（已完成，详情见 HANDOFF）

持久盘/持久 root（HANDOFF §14/§16）、`/persist` 自动挂载、音频前级（§15）、
图形/桌面（§17.1）、WiFi（§21）——均已在 HANDOFF 对应小节详述，此处不再重复。

> 软回 fastboot（不需按电源键）：`./cycle.sh --soft`。串口救急：`/dev/ttyACM0`（SSH 失效时）。
