# #748 Coresight 补 CONFIG 不够：三个「静默不生效」的半截条件

> 2026-11-27，能力集合配置批（vk194 → vk195）现场踩到。开 `=m` 之后设备仍然一堆节点没驱动，
> 但每条都**不报错**（只有 `deferred probe pending: (reason unknown)`）。

## 三件事（缺一都白干）

- **①** **TPDA 是独立驱动**：`coresight-tpda.ko` 由 `CONFIG_CORESIGHT_TPDA` 控制，**不在 TPDM 里**。
   只开 `CONFIG_CORESIGHT_TPDM` 时，21 个 tpdm/tpda 里 TPDM 全绑、**TPDA 5 个全不绑**。
- **②** **驱动缺 `MODULE_DEVICE_TABLE` ⇒ 编成模块后没有 modalias ⇒ 永不自动加载**。
   2026-11-27 实测：`coresight-tpda`（缺 `amba` 表）与 `coresight-ctcu`（缺 `of` 表）都是这样；
   `modinfo -F alias <mod>` 返回**空**就是判据。手动 `modprobe` 立即绑定，所以「手动能好」不代表部署就绪。
- **③** **amba 设备靠硬件 PID 匹配，DT 不写 `arm,primecell-periphid` 就可能读回 0**。
   `109ab000.tn`：`uevent` 显示 `AMBA_ID=00000000`、`MODALIAS=amba:d00000000` ⇒ 驱动的
   `amba_id` 表（`0x000f0c00`/`0x001f0c00`, mask `0x00ffff00`）永不匹配。补一行 periphid 后
   立刻 `coresight-trace-noc` 绑定 + 模块自动加载。
   （同族 `tpda` 节点反而能读回真 PID `000f0f01/02/04` ⇒ **不是「读不到」的普遍问题，是 TNOC 这块在
     `apb_pclk` 上电前读回 0**。）

## 判据（照抄就能用）

```bash
# a) 设备态：谁没绑
for d in /sys/bus/amba/devices/*; do [ -e "$d/driver" ] || basename "$d"; done
# b) 模块有没有 modalias（空 = 不会自动加载）
sudo modinfo -F alias coresight-tpda; sudo modinfo -F alias coresight-ctcu
# c) amba id
grep AMBA_ID /sys/bus/amba/devices/*/uevent
# d) 手动加载对照：手动 modprobe 后能绑 ⇒ 问题在 autoload，不在驱动本身
```

## 修法（本轮落地）

- 本地兜底：`/etc/modules-load.d/elden-coresight.conf`（`coresight-ctcu` + `coresight-tpda`）。
- 上游：两行 `MODULE_DEVICE_TABLE` + 一行 periphid，草稿 `patches/upstream/coresight-moduletable-20261127/`。
- 结果：**amba 未绑定 28 → 0**（TPDM 22 / TPDA 5 / TNOC 1 / CTCU 1）。

## 相关

- 报告：`reports/capbatch-vk194-20261127.md` §6/§7；`DEVICE/CAPABILITIES.md` 表格行 13/15/16。
- 同族教训：`PITFALLS #452`（门禁静默跳过）、`#681`（模块零自动加载 ⇒ 聚合永不 bind）。
