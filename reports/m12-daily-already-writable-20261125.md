# M12 口径更正：日常线源码**已经**有 ICL 写入口（payload 携带 armadaos 0150）

> 立：2026-11-25 19:2x CST，父代理静态取证（**设备不在线，零上机**）。唯一写入 = 本文件。
> 触发：整理 D 车道（`reports/usb-ports-consolidation-20261125.md` §3）时复核「backport 30 行」这条待办，
> 结果发现前提不成立。

## 0. 一句话结论

`D14` 的「mainline `qcom_battmgr` USB 对象只读 ⇒ 无写入口」**只对 pristine 上游（7.4-rc3）成立**；
**在机日常线的源码树（= `build/daily`，7.3.1 + payload v2）本来就带一份可写 ICL 的实现**，
来源是 `reference/upstream-armadaos-freedom/patches/0150-power-supply-qcom-battmgr-sm8750-usb-current.patch`
（adapted from `h0cheung/tb322fc-linux-kernel @6f97250`，blob `d7fff093…`），随 2026-10-17 的 payload v2 落树。
⇒ 待办从「写 30 行 backport」改成「**上机验一次写**，通了就划掉」。

## 1. 静态证据（逐条可复核）

| # | 事实 | 命令 / 位置 |
|---|---|---|
| 1 | `build/daily` = `7.3.1` + payload v2（HEAD `4da9a8b69fc8`，父提交 `88cd0bc0f4f5 "elden payload v2: downstream vk64 tree state…"`，2026-10-17） | `head -4 build/daily/Makefile`；`GIT_NO_LAZY_FETCH=1 git -C build/daily log --oneline -2` |
| 2 | 该 payload 提交动了 `drivers/power/supply/qcom_battmgr.c` **115 行** | `GIT_NO_LAZY_FETCH=1 git -C build/daily show --stat 88cd0bc0 \| grep battmgr` |
| 3 | payload 内容 = 仓内 `patches/replay-2026-10-17/0001-…patch`；其中 ICL 部分逐字来自 armadaos 0150 | `grep -rl qcom_battmgr_set_usb_current_limit patches/ reference/` |
| 4 | 树内现状：`sm8350_usb_psy_desc` **有** `.set_property` / `.property_is_writeable` | `build/daily/drivers/power/supply/qcom_battmgr.c:1160–1162` |
| 5 | 树内现状：有 `qcom_battmgr_set_usb_current_limit()`（先 `BATTMGR_USB_PROPERTY_GET/USB_ADAP_TYPE` 探测，只对 **SDP/CDP/PD** 放行）+ `BATTMGR_USB_PROPERTY_SET` 应答处理（`:1562`） | 同上 `:1067–1092`、`:1562–1568` |
| 6 | **dwc3 侧也在推**：`dwc3_vbus_draw_work()` 用 `power_supply_set_property(dwc->usb_psy, INPUT_CURRENT_LIMIT, 1000*current_limit)` | `build/daily/drivers/usb/dwc3/core.c:2280–2290` |
| 7 | SM8750 走的正是这个 desc（`battmgr->usb_psy = devm_power_supply_register(dev, &sm8350_usb_psy_desc, …)`，变体只影响电池 desc） | `build/daily/drivers/power/supply/qcom_battmgr.c:1808`（`qcom_battmgr_probe`） |

## 2. 与 D14 的冲突点（D14 没错，但取样对象错了）

`reports/usb-charging-sdp-limit-20261125.md` §1.4 原文引的是 **`build/elden-tree` = `v7.4-rc3`** 的文件：
上游 `sm8350_usb_psy_desc` 只有 `get_property` ⇒ 「无写入口」对**上游**成立，对**在机日常线**不成立。
D14 同轮观察到的「`input_current_limit=100000`」是**固件默认/当下生效值**，不能反证「写不进去」。

## 3. 待上机裁决（一条命令级，设备窗 5 分钟）

```sh
# 设备侧（ssh root@192.168.7.1）；只读+一次写，写后可立刻还原
B=/sys/class/power_supply/qcom-battmgr-usb
ls -l $B/input_current_limit                  # 期望 -rw-r--r--（有 set_property + is_writeable）
grep -o '\[.*\]' $B/usb_type                   # 期望 [SDP]（adapter gate 才会放行）
cat $B/input_current_limit                    # 基线
echo 900000 > $B/input_current_limit; echo "rc=$?"; sleep 1; cat $B/input_current_limit
# 判定：
#   rc=0 且读回 900000（或 500000/被 clamp）⇒ 写入口在 ⇒ M12「backport」待办划掉
#   rc=-EINVAL/-EPERM/写后不变 ⇒ 记录 errno + dmesg | grep battmgr，才需要 backport/改 gate
echo 100000 > $B/input_current_limit          # 还原（或直接拔插）
```

判读要点：
- **rc 与读回**是主判据；`dmesg | grep -i 'battmgr.*unknown message'` 必须是 0（该树已有 `0x33` 应答 case）。
- 若写进去了但**充电电流没变** ⇒ 属于「ADSP 是否真按新值限流」的问题，与 M12 上机 A/B（500 vs 900 档幅度差）方法一致。
- 反向对照 = 同一台机器用 `7.4-rc3` 测试核（无 setter）时写会失败 ⇒ 可区分「源码有无」而不是「ADSP 收不收」。

## 4. 对台账的影响（父代理已同步 TASKS）

- **D14 行**：结论保留（现象、ADSP 侧链缺失、UCSI 上报值），但「无写入口」标注为**仅对 upstream**。
- **M12 行**：`backport be5e7367bceb 30 行` 从「必做」降级为「**先上机验，失败才做**」；若只是 gate 差异（例如
  `adapter_type` 停在 UNKNOWN 导致 `-EINVAL`），则要改的是**本地 gate**，不是 backport 上游件。
- **§7 上游化**：M12 仍维持 ⛔（上游已被 `be5e7367bceb` 覆盖），不投。

---

## 5. 上机裁决结果（2026-11-25 19:55 CST，**已执行**）

设备在 BL，用户放行上机。`fastboot boot out/boot-elden-vk192.img` 第一发**卡在 initramfs（只有背光）**——根因不是 Q28，
而是该镜像 cmdline 里 `elden_root=LABEL=linux17`，而 2026-11-18 磁盘重建后 **`/dev/sda17` 的 LABEL 已改为 `linux`**
（`blkid` 实证）。改用 `out/boot-elden-vk192.img` 的 `--set` 重打包件（**已按 PITFALLS #728 记账后删除**，可再生）（`scripts/boot-img-cmdline.py --set` 只改 cmdline，
kernel/ramdisk/dtb 三段 sha 与原件逐字节相同）后未再走 fastboot，而是 `reboot -f` 回 `boot_b`（其 cmdline 已是 `LABEL=linux`），
在**在机日常核** `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`（vk192）上直接采判据：

| 判据 | 实测 | 结论 |
|---|---|---|
| `ls -l qcom-battmgr-usb/input_current_limit` | `-rw-r--r-- root root` | 有写属性（0444 才会是只读） |
| `usb_type` 当前值 | `[SDP]`（`grep -o '\[.*\]'`） | 与 `PITFALLS #726` 一致 |
| 写 900000 / 500000 → 读回 | **rc=0，读回 900000 / 500000** | **写入口存在**（M12「backport 30 行」待办 **永久划掉**） |
| `dmesg | grep -c 'unknown message'` | **0** | `0x33` 应答 case 已在树内（payload 版实现） |
| **限流是否真落到充电电流**（30 s × 10 样本） | 500 mA 档 `current_now` = **−101…−117 mA**（净放电）<br>900 mA 档 = **+45…+287 mA**（转充电） | **成立**：同一 SDP 端口下只改 ICL 就能从净放电翻到充电 |

原始日志：`reports/artifacts/devicewin-20261125/{m12-icl-write.txt,m12-icl-ab.txt,psy-uevent.txt}`。

**因此 D14 的操作面结论更新为**：数据线（PC 的 SDP）默认 100 mA 仍会导致净放电，但**本机可以自己写 ICL 到 900 mA 解决**，
不需要 PD 主机、不需要 hub、不需要内核 backport —— 需要的只是一个「开机后把 ICL 抬到 500–900 mA」的用户态动作（下一轮做成 service/dispatcher 即可）。
