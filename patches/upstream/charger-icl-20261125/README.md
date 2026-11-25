# charger-icl-20261125 —— `qcom_battmgr` USB 输入限流可写（起草，未投递）

> 状态：**起草**。投递冻结期（`patches/upstream/README.md` §3），本节只做备料。
> 背景与判据：`reports/m12-charger-upstream-20261125.md`（三路径裁决 = B）、
> 定因：`reports/usb-charging-sdp-limit-20261125.md`。
> 源码基线：`build/elden-tree` = `v7.4-rc3`。

## 1. 拟发形式

**先 issue 后 patch**：

1. **RFC patch（单枚，`[RFC PATCH]`）** 发 `linux-pm` + `linux-arm-msm`，抄 `linux-usb`，
   因为改动只在 `drivers/power/supply/qcom_battmgr.c`，体量 40–60 行，够小不需要拆系列。
2. **不发单独 issue**：`qcom_battmgr` 有明确维护者与列表，issue 会分散讨论；RFC 的 cover-letter 正文
   承担 issue 的角色（问题描述 + 复现 + 拟解）。若 RFC 被打回「协议层不该由 OS 改」，再转
   `linux-pm` 的讨论贴（不带 patch），不要另开 bugzilla/GitHub issue。

## 2. 标题

```
[RFC PATCH] power: supply: qcom_battmgr: Allow setting the USB input current limit
```

（若实测发现 ADSP 会覆盖，标题改为 `...: Set and re-apply the USB input current limit`。）

## 3. 受众

| 收件人 | 理由 |
|---|---|
| Sebastian Reichel `<sebastian.reichel@collabora.com>` | power_supply 子系统维护者（`get_maintainer.pl` 口径） |
| Bjorn Andersson `<andersson@kernel.org>` | qcom_battmgr 作者 / PMIC glink 协议知情人 |
| `linux-pm@vger.kernel.org` | 主列表 |
| `linux-arm-msm@vger.kernel.org` | 平台列表 |
| `linux-usb@vger.kernel.org`（抄送） | 因为涉及 USB SDP 500 mA 语义与 UCSI 分工，避免被指「重复造轮子」 |
| Konrad Dybcio / Neil Armstrong（如近期在 `qcom_battmgr.c` 有 commit） | 由 `get_maintainer.pl` + `git log -- drivers/power/supply/qcom_battmgr.c` 现查补齐 |

## 4. 正文提纲（cover letter / commit message，≤15 行）

```
1. 现象：USB2 SDP（非 PD）主机下 ADSP 报 usb_type=Unknown，input_current_limit 钉 100 mA，
   链路已 high-speed + configured（规范允许 500 mA），净放电。
2. 现状：qcom-battmgr-usb 的 power_supply 只暴露 get_property（qcom_battmgr.c:1079-1093），
   用户态无任何写入路径；下游 qti_battery_charger 走私有 owner，不在上游。
3. 关键观察：BATTMGR_USB_PROPERTY_SET (0x33) 与 USB_INPUT_CURR_LIMIT (=5) 早已在该文件定义
   (:78-85) 但零引用；报文结构 (:116-121) 与请求封装 (:364-378) 已存在。
4. 本 RFC：USB psy 增加 set_property/property_is_writeable，ICL 写入走 0x33 + 属性 5，
   只在 sm8350 变体启用，PD/DCP 路径不改。
5. 实测（TB322FC / SM8750P / ADSP 充电固件）：写 500000 后回读与 current_now 变化，
   以及插拔一次后是否被 ADSP 覆盖（把结论写在此处，不写「预计」）。
6. 不做的部分：不改 UCSI_TYPEC_DEFAULT_CURRENT（那是上报语义，另议）；不引入 charger 客户端。
7. 问：ADSP 是否把「USB 属性 set」视为对充电固件策略的越权？若需 spmi/charger PD 侧配合，
   请指出正确的服务路径（现有 tms/servreg + msm/adsp/charger_pd 只做了 PDR lookup）。
```

## 5. 投递前必须补齐的 3 条证据

1. **写-读-流 闭环**：`input_current_limit` 写入 500000 后回读 500000，且 `current_now` 在带载
   （≈800 mA 负载）下从 403 mA 抬到 ≥500 mA；`dmesg` 无 `pmic_glink` 错误/超时
   （否则补 `battmgr->error` 打印说明是 ADSP 拒绝）。
2. **不被覆盖**：写入后触发一次充电器通知（插拔数据线或等 `NOTIF_USB_PROPERTY 0x32`），
   回读限流仍在；若被覆盖，给出重下发位置与代码，并写进 commit message（这决定标题第 2 版）。
3. **变体与回归**：`sc8280xp/x1e80100` 变体（`:1710` 注册点）不受影响；PD 充电器下
   `usb_type=PD` + ADSP 自管限流行为不变；`checkpatch --strict` 0E/0W（按
   `patches/upstream/README.md` §1 的**临时空目录**写法复跑，勿在仓库根跑）。

## 6. 补丁产物与编译/上机验证计划（补充段，20261125 lane 起草）

补丁：`0001-power-supply-qcom_battmgr-allow-writing-input-current-limit.patch`
（sm8350 USB psy 加 `.set_property`/`.property_is_writeable`，仅支持
`POWER_SUPPLY_PROP_INPUT_CURRENT_LIMIT`，借 `BATTMGR_USB_PROPERTY_SET (0x33)`
+ `USB_INPUT_CURR_LIMIT (5)` 走既有 `qcom_battmgr_request_property()`；
值 clamp 到 `[500 mA, max(current_max, 900 mA)]`（µA），ADSP 错误码透传 errno，
成功后刷新缓存 `usb.current_limit`。sc8280xp/x1e80100 变体不动。）

编译（本 lane 不执行）：

```sh
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- drivers/power/supply/qcom_battmgr.o
```

上机验证（由有刷机权限的环节执行；§5 三条证据即验收标准）：

```sh
adb shell cat /sys/class/power_supply/qcom-battmgr-usb/input_current_limit  # 默认 ~100 mA
adb shell sh -c 'echo 500000 > /sys/class/power_supply/qcom-battmgr-usb/input_current_limit'
adb shell cat /sys/class/power_supply/qcom-battmgr-usb/input_current_limit  # 应回读 500000
adb shell sh -c 'echo 10000 > /sys/class/power_supply/qcom-battmgr-usb/input_current_limit'  # clamp 到 500000
adb shell dmesg | grep -iE 'battmgr|pmic_glink'   # ADSP 拒绝应见 errno 传播，无静默
# 之后按 §5.2 触发插拔，确认不被 ADSP 覆盖
```

checkpatch 注意点：

- 本补丁为手写（fake index/base-100），`checkpatch --strict` 可能报
  "does not apply/version" 类噪音；投递前用 `git format-patch` 重生成消除。
- 跑法：`scripts/checkpatch.pl --no-tree --strict <patch>`（在临时空目录按
  `patches/upstream/README.md` §1 写法，勿在仓库根跑）。
- `clamp()` 换行保 80 列；case 缩进用 tab，与树内现风格一致。
- 投递时 commit message 需含 §4 提纲要点并 Cc §3 受众。

最大不确定点：ADSP 是否真正接受 `BATTMGR_USB_PROPERTY_SET` + 属性 5 报文
（帧格式/编号源自树内常量与逆向，未真机确认）。若被拒，write 应返回
ADSP 错误码（常为 -EINVAL）且回读不变——补丁会原样透传，不静默。
