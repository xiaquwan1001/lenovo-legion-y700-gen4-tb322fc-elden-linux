# #488 · `EUD Init` 是 XBL 的 printk，不是 Linux 侧驱动 probe

日期: 2026-11-02
pi 会话 id: 01a19a46-ece4-740f-9b6b-1b8fd59a7915
主题: UEFI/EDL 调试通道可行性（lane D）——「固件里出现某条日志」与「设备就绪」的区分
结论: `logfs` 里有 `EUD Init` 只证明该代码路径被编进固件；实测 `EUD wait` 0/10、运行 DT 无 `qcom,eud` 节点 ⇒ **0 次 probe**，不能当可用通道
证据指针: `../../reports/uefi-eud-feasibility-20261101.md`、复核命令见下
★SSOT 待并入：无（已并入 PITFALLS/README.md 索引 #488，2026-11-05）

---

## 现象

`logfs` 十段（`0x08`–`0x0f`）逐段 grep 都能命中 `EUD Init`，看起来「EUD 已经起来了」。

## 判据（三条，缺一不可）

```bash
# 1) 固件打印（只说明代码路径存在，不说明设备注册）
strings logfs_seg*.bin | grep -c 'EUD Init'          # → 10/10 命中（工厂模板）
# 2) XBL 侧等待/握手（本题的判别项）
grep -c 'EUD wait' logfs_seg*.bin                    # → 0/10
# 3) 运行期设备节点（Linux 侧唯一硬证据）
ls /sys/firmware/devicetree/base/ | grep -c 'eud'     # → 0
lsusb | grep -E '05c6:9500|05c6:9501'                # → 无
```

## 教训

- 固件字符串 = 「代码被编译进去」，**不是**「外设被枚举」；两者差一整条 probe 链。
- 同类坑：`PITFALLS #485`（`logfs` 十段只有 seg0 是本机的，其余是别的机的模板）、`#486`（EDL loader 不放行 `peek`）。
- 结论口径：本机 EUD 通道**未证实**；要推进只能上机发一发并看 USB 是否枚举出 `05c6:9500/9501`，
  不能再用「日志里有 `EUD Init`」当作可行依据。
