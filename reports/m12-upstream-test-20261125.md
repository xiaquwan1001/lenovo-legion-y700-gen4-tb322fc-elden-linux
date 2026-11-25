# 上游充电限流实现的上机验证（2026-11-25 晚）

> 背景：M12（USB 输入限流可写）已判「上游已覆盖」—— Joonhoe Kim 的实现被 Sebastian Reichel 收录为
> `be5e7367bceb`（`sre/linux-power-supply.git`），Venkat Yadlapati 的续作 `[PATCH v2 0/2]` 在评审中。
> 我方自研系列作废，但**这两件都能在真机上验**：既是「本机要不要 backport」的判据，也是能给上游的
> `Tested-by` 素材。本轮 = 把这件做完（上一轮建好镜像但只跑到一半）。
> 通道 = `scripts/autotest-cycle.sh`（`fastboot boot` 零写盘，不写任何槽）；设备 = U1 HA2EXB0E。

## 0. 结论（数字）

| 件 | 写入 900000 | 写入 500000 | `unknown message` | 裁定 |
|---|---|---|---|---|
| 上游 `be5e7367bceb` 单独 | 回读 **900000**，rc=0 | 回读 **500000**，rc=0 | **0** | ✅ 与本机自研 v2 行为等价 |
| 上游 + Venkat v2 两枚 | 回读 **900000**，rc=0 | 回读 **500000**，rc=0 | **0** | ✅ 2/2 的 `usb_type` 门在本机放行 |
| （对照，历史）我方 0001+v2 | 回读 900000/500000 | 同 | 0 | 已作废，仅作等价性对照 |

⇒ **上游实现可直接替代我方自研件**（语义逐条相同 + 本机实测通过）⇒ 本机若需此能力，backport
`patches/upstream/charger-icl-20261125/upstream-be5e7367bceb.patch`（30 行）即可，不必背自研补丁。

## 1. 件与构建

| 项 | 值 |
|---|---|
| 内核树 | `build/g7a-tree`，基线 `aebb727447`（**v7.4-rc3**）+ 在飞 dwc3 系列（工作区改动） |
| `out/m12-upstream-20261125/boot-m12-upstream.img` | 仅叠 `be5e7367bceb`；`scripts/bootimg-replace-kernel.py --verify` = **only-kernel-differs**（kernel 21174710 → 21175828 B） |
| `out/m12-upstream-20261125/boot-venkat-v2.img` | 再叠 Venkat `[v2 1/2 2/2]`；同法 `--verify` 通过 |
| 设备侧 UTS | `7.4.0-rc3-g7a-dwc3v11-reset-20261123-dirty`，BUILD `#8`/`#9`（15:56:44 / 16:01:48 CST） |
| 探针 | `probes/m12-icl-upstream.sh`（判据：writeable / 回读一致 / `unknown message`=0 / 电流方向）、`probes/m12-icl-ab.sh`（500 vs 900 两轮交替 + `current_now` 采样） |
| 日志 | `runs/autotest-20261125T075801Z-m12up/`（上游件）、`runs/autotest-20261125T080219Z-venkatv2/`、`runs/autotest-20261125T080532Z-venkatv2ab/` |

## 2. 实测原文（`round1-test.txt` 摘要）

上游 `be5e7367bceb`：

```
current_limit_before=100000 current_max=900000 usb_type=Unknown [SDP] DCP CDP ACA C PD PD_DRP PD_PPS BrickID
write900000_rc=0 readback=900000        icl=900000 current_now_avg=-272800 uA (n=10)
write500000  readback=500000            icl=500000 current_now_avg=-251700 uA (n=10)
unknown_message_before=0 after=0        RESULT=fail:0
```

上游 + Venkat v2（`--test probes/m12-icl-ab.sh`，两轮交替）：

```
current_max=900000 limit_boot=100000    epp=schedutil load1=0.69
round=1 set=500000 readback=500000 current_now_avg=1137550
round=1 set=900000 readback=900000 current_now_avg=765900
round=2 set=500000 readback=500000 current_now_avg=1142550
round=2 set=900000 readback=900000 current_now_avg=766750
unknown_message=0        RESULT=done
```

**`current_now` 不作为「限流是否落地」的判据**：500 mA 档读到 +1.14 A，物理上不可能由 5 V/0.5 A 端口供出
⇒ 该属性在本板不是干净的电池侧电流（我方 11-25 早期的 A/B 结论用的是**电池电流幅度**，与本轮这个口径不同，
两者不可互换）。本轮只声明「写路径 + 网关 + 固件应答」三件事，不声明功率效果。

## 3. 已发给上游的回信（`out/mail-20261125/re-venkat-battmgr-v2.txt`）

- 收件：To Venkat Yadlapati；Cc Sebastian Reichel / linux-arm-msm / linux-pm / linux-kernel / Joonhoe Kim / phone-devel。
- `In-Reply-To: <20261123-vantage-battmgr-v2-0-03a419078d0a@yahoo.com>`（其 cover），MID
  `<179559445186.3708843.5599816201468147145@mail.ustc.edu.cn>`，SMTP **`已发送 OK`**（2026-11-25T08:14Z）。
- 内容：三组实测值 + 明确 `Tested-by: Qianhui Xu`（1/2、2/2）+ **AI 辅助披露** + 一条数据型观察
  （`current_now` 在本板不可用作功率判据，建议 cover 里换更直接的观测面）。
- 归档复核：**lore 尚未命中**（发送后立即查 `/all/<MID>/` = not found，属已知摄取延迟；复核口径见
  `TASKS/README.md` §7 头「归档复核口径」——不以 patchwork `state` 下结论）。

## 4. 顺带的取证更正（`usb_type` 的 sysfs 语义）

早期报告 `usb-charging-sdp-limit-20261125.md` 把 `usb_type=Unknown [SDP] DCP …` 读成「ADSP 判 Unknown」。
按 v7.4-rc3 源码 `drivers/power/supply/power_supply_sysfs.c` 的
`power_supply_show_enum_with_available()`：**方括号里的那个才是当前值**，其余是 `desc->usb_types` 声明的可用集
⇒ 本机现场值其实是 **`SDP`**（不是 Unknown）。这正好解释为什么 Venkat 2/2 的 `{SDP,CDP,PD}` 门
在本机放行（另有一条独立通道：`qcom_battmgr_usb_sm8350_update()` 在 set 前会**现读一次** USB 属性）。
M12 的结论（SDP 下固件默认 100 mA、需要显式抬限）不受影响，但「ADSP 判 Unknown」这句作废。
教训入 `PITFALLS #726`。

## 5. 未做 / 下一手

- Venkat v2 的 **1/2「早下发」路径**本身没有样本：两轮写入都发生在服务起来之后（`limit_boot=100000`
  = 固件默认值未被 1/2 抬过 ⇒ `usb_icl_pending` 分支未被触发）⇒ 想在真机上验它，需要在连接器/`usb_bc`
  刚起、`service_up` 还是 false 时写入，属上机时序题，暂不做。
- 若要把该 30 行进日常线：走正常 backport 流程（`build/elden-tree` + `scripts/build-kernel.sh`），
  本轮**没有**改日常核，设备仍在 BL（`fastboot devices` = HA2EXB0E）。
