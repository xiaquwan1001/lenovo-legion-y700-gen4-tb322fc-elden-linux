# M3v5 A0 上机只读预检汇总（2026-10-30）

UTS 目标：7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk172
设备：root@192.168.7.1（USB-NCM），全程只读（无任何 device-side 写入）。

## 判据矩阵

| # | 判据 | 期望 | 实测 | 判定 |
|---|------|------|------|------|
| 1 | uname -r / /proc/version | 逐字 = 目标 UTS | 逐字一致（#1 SMP PREEMPT Fri Oct 30 19:00:42 CST 2026 aarch64） | yes |
| 1 | boot_id | b186674c-1754-4241-898a-ab44d05bd324 | b186674c-1754-4241-898a-ab44d05bd324 | yes |
| 1 | lsmod 行数 / .ko 数 | 记录基线 | 108 / 1640 | yes |
| 2 | boot_b sha256 | aedae5f121ecbe5cc6f5de59a14ae5ba3680229d619c49cedee0d6cf8b9b4765 | 相同 | yes |
| 3 | boot_b-pre-vk183-20261030.img | e6b1124c… | e6b1124ca6ec38aa… | yes |
| 3 | boot_b-vk181-daily-signed-20261029.img | b72866ef… | b72866ef6e6c8248… | yes |
| 3 | out/boot-elden-vk183-fastrpc.img | 存在 | 30e6a4c4bcfcd707…，存在 | yes |
| 4 | 4 个 .ko 备份齐全 | /root/m3modbak-20261030 有 4 件 | drivers/usb/dwc3/{dwc3.ko,dwc3-qcom.ko}、typec/ucsi/{typec_ucsi.ko,ucsi_glink.ko} | yes |
| 4 | 备份 vs 现网 | 不同（备份=pre-f2 原件，现网=m3v5-f2 在网） | 4/4 全不同 | yes |
| 5 | GPT 主表 sha（bs=4096 count=35） | 记录 | 6afbaa756a1d30a5f8985fa4a213e4ebfb6baa0237dd8e66591309a978432047 | yes |
| 5 | GPT 备用表 sha | 记录 | c08bbcc4d5c6ef5a0159b55441d2ea35dbd967717bcbfaccc751f0c1808676f3 | yes |
| 5 | 当前槽位 | _b | qbootctl: Current slot: _b（_a/_b 均 Successful+Bootable） | yes |
| 5 | 分区表 | 无异常 | 18 分区，含 linux17/linux18 各 96G，空闲 1GiB | yes |

## Gate4 模块对照表（备份 | 现网 | 相同 | 备份大小）

| 模块 | 备份 sha | 现网 sha | 相同 | 备份大小 |
|------|----------|----------|------|----------|
| dwc3.ko | c694eeac3fdb9d8d… | 528d4dd89ff8b91d… | no | 304400 |
| dwc3-qcom.ko | 3c114021f22e6407… | 7bff9135121c712c… | no | 22896 |
| typec_ucsi.ko | 9992946493eb7532… | b1bcaa382e44b59d… | no | 88824 |
| ucsi_glink.ko | 4bfa8835e57aab70… | 1d242230700970e1… | no | 18944 |

注：备份路径结构为 /root/m3modbak-20261030/drivers/...；现网模块名为 dwc3-qcom.ko（短横线），
非派工单里的 dwc3_qcom.ko，首次比对 No such file 后已用 find 定位修正。

## Gate6 USB/typec 基线（A2 臂对照）

- typec：port0、port0-partner、port1；usb_role：a600000.usb-port0/1-role-switch，waiting_for_supplier 均 0
- port0 与 port1 data_role 均 `host [device]`，power_role 均 `source [sink]`
- udc：a600000.usb，state=configured
- dmesg 计数：PPM init=0；failed to get usb role switch=0
- lsmod：dwc3(188416)←dwc3_qcom(20480)；typec_ucsi(65536)←ucsi_glink(12288)；pmic_glink 挂 altmode/battmgr/ucsi_glink

## 备注

- Gate5 首次备用表 dd 偏移计算错误（blockdev --getsz 为 512B 扇区），得空 sha；已按 SIZE/8-34 修正重跑，记录于 a0-gpt.log 末行。
- 中间证据（GATE*_RC 追加行）保留在本文件历史中。

## 回执

- 结论：7 门全跑完，GATE1–6 RC 全 0，判据矩阵 13/13 yes；**A0 基线可复原性 = PASS**（boot_b=权威 sha、pre-vk183 与 vk181-daily 回退件均在且 sha 前缀匹配、4 个 .ko 备份齐全可与现网对照）。
- 产物：reports/artifacts/m3v5-onboard-20261030/{a0-id,a0-bootb,a0-host-assets,a0-modbak,a0-gpt,a0-usb-state}.log + 本文件。
- 关键数字：boot_b sha=aedae5f1…4765；GPT 主表=6afbaa75…，备用表=c08bbcc4…；slot=_b；.ko 对照 4/4 不同（备份=pre-f2）；PPM init=0、role-switch fail=0；udc=configured。
- 复现命令：`scripts/device-lock.sh -w 300 ssh root@192.168.7.1 "<各门命令>"`，详见各 a0-*.log；设备侧零写入。
