# M1 7.3-rc7 树显示回归 —— 同窗口 vk94 对照（2026-10-14）

> 证据层。结论：**M1 树（7.3-rc7 重基）在结构健康的启动上仍点不亮面板，而同一窗口的日常 vk94 能正常出桌面** ⇒ 这是 M1 树的显示回归，**不是** Q28、不是暖复位粘态、不是面板故障。
> 全程零写盘 `fastboot boot`；串口内核控制台 + SSH dmesg 双通道取证。

## 0. 数字先行（同一会话窗口，~09:00–09:40）

| 臂 | 内核 | 显示结构 | `dsi_isr`(host0) | 面板实测（用户） |
|---|---|---|---|---|
| **vk94**（日常，7.2 血统 `linux/` 树） | 7.2.0-debug-vk64-gd02658e63cf6 | CRTC 106 fb=110 1904x3040、phoc+phosh、grim 可用 | 41 | **✅ 桌面正常** |
| **m1-73j**（M1 树 vendor DSI+DPU） | 7.3.0-rc7-debug-ged6f232d10e3 | L1=L2=0、phoc+phosh、CRTC active、**grim 出图 39 965 B** | 41 | **❌ 仅背光/无内容** |
| **P4a**（P2c+DSC1.2）、**P4d**（+DIAG） | 7.3.0-rc7-debug-g2851bcaff64f | phoc modeset 失败（`no supported format`）；强制 `modetest` modeset（CRTC fb=111）后仍无图 | **0** | ❌ 仅背光/无内容 |

## 1. 直接结论

1. **M1 7.3-rc7 树 = 显示回归**：vk94 / m1-73j 同窗口、同硬件、同启动路径，前者出桌面、后者只有背光 ⇒ 与 Q28 的"间歇坏发"无关，也与"暖复位粘态"无关（vk94 在同样多次温复位之后仍然正常）。
2. **10-13 报告里 73i/73j「未亮屏=Q28 坏发」的归因不成立**：m1-73j 在 **L1=L2=0 的健康发**上依然不亮。
3. **上游显示臂（P2c 系）的额外问题**：合成器连 modeset 都失败（`grim: no supported format`，与 10-13 的 P2b 同型），强制 `modetest` 后 `dsi_isr` 仍为 0。
4. **DSC 1.2 否证**：P4a = P2c + vendor DSC1.2（RC 参数 + `first_line_bpg_offset`），行为与 P2c 无差别 ⇒ 面板 `dsc_version_minor=2` 的参数并非缺口。

## 2. P4d 探针（DIAG）给出的事实

```
DIAG: mgr bridge_enable id=0 powered=1 bonded=1
DIAG: host_enable id=0 mode_flags=0x2e03 power_on=1 ctrl_before=0x171
DIAG: host_enable id=0 done ctrl_after=0x173        <-- bit1 = VID_MODE_EN 已置位
DIAG: host_enable id=1 ctrl_before=0x171 -> ctrl_after=0x173
```
⇒ 上游 DSI manager/host 的 **video 使能路径确实被调用且寄存器置位**；但 `dsi_isr` 恒 0 ⇒ 缺的是让 video 真正跑起来的条件（时钟/PLL/DPU→DSI 数据流），不在"是否调用 enable"。

时钟侧（P4d/健康发）：`dsi0vco=756 839 941 Hz`、`disp_cc_mdss_pclk0/1_clk_src=172 991 986 Hz`（= 已知目标 172.992 MHz）、`dsi1vco=0`；m1-73j 相同。

## 3. 方法学（本目录新增的坑）

- **串口控制台会被设备侧 shell 刷屏**：`~ #` 提示符每秒上百行，printk 到控制台的消息被大量丢弃 ⇒ 只看 console.log 会误判"没有内核日志"。**必须同时用 SSH `dmesg` 交叉核对**（PITFALLS #254）。
- 显示坏态下 `reboot2 bootloader` 挂 DRM cleanup（#253）；`arm-window-hunt.sh` 已加 SysRq-b 两级回退。
- 高频 ssh 重试会触发 sshd 源惩罚把自己锁死（#254）⇒ 单次连接 + 退避。

## 4. 下一步（按优先级）

1. **定位 M1 树显示回归（主）**：在 `linux/`（能点亮）与 `build/m1-upstream/clean-tree-73`（点不亮）之间做显示域审计，重点：
   - 7.2→7.3 rebase 的 **41 个冲突块**里落在显示路径的解析结果（panel / DSI host+PHY / DPU / dispcc / msm_mdss / backlight）；
   - 已知已排除：DTS（两树显示节点无实质差异）、`dispcc-sm8750.c`（0 行差异）、DSC 参数、panel 模式表；
   - 已知候选：`dsi_phy_7nm.c` 的 PLL enable 计数重构（M1 有"已使能即提前返回 + enable_cnt=1"）、`dsi_host.c` 的 `byte_intf_clk` 速率推导（M1 新增 `byte_intf_clk_div_2`）、`disp_cc` 的 `sync_state() pending due to displayport-controller` 行为。
2. **同窗口运行时指纹对照**（1 个窗口 2 发）：m1-73j vs vk94，各取 `dmesg` + `regulator_summary` + `clk_summary`（显示相关项）+ `dsi_isr` 做差。
3. **上游臂暂停**：先把"M1 树能像 vk94 一样点亮"做成基线，再谈上游化显示（否则上游化结论会被 M1 回归污染）。

## 5. 证据

- 串口日志：`logs/arm-{vk94ctrl,m173j,p4a-s2,p4d,p4d2}-*/`、trial 记录 `reports/trials/20261014*`。
- 镜像：`out/boot-elden-p4a-dsc12.img`（DSC1.2）、`out/boot-elden-p4d-diag.img`（DIAG 探针）；树 `build/p1-upstream-dsi` 分支 `p4/p2c-dsc12`。
- 参考：`reports/p1-upstream-dsi-20261013.md`、`reports/m1-73-port-bringup-20261013.md`、`PITFALLS #248/#251/#253/#254`。
