## 三十七、Q28 arm A：命令路径否证、「面板黑」是不变量、以及我们所有「软件侧点亮代理」的集体失效（2026-10-15 实测）

> 证据：`reports/q28-armA-20261015.md`、`.pi/plans/2026-10-15-armA-采样协议.md`、
> `logs/armA-sampling-20261015/`（s1–s5 逐发）、`reports/q28-badboot-m1-baseline-20261015.md`。

274. **★Q28 的不变量是「面板黑」，不是 `-110`：arm A 去掉 vendor bonded 命令协议后，坏发里 `command DMA timeout` 签名消失，但面板依然黑。**
    - 设计：arm A（`out/boot-elden-armA-nobonded.img`）= baseline（`m1-baseline-f3`）**单文件 3 处**改动，停用 vendor bonded 写路径、改走标准 `need_sync` 双写；唯一变量，对照臂**免构建**（`boot_b` 就是父臂）。5 发**全真 POR**。
    - 结果：**armA 0 GOOD / 3 BAD；baseline 1 GOOD / 1 BAD**。Fisher 双侧 **p = 0.40 ⇒ 无显著差异**（armA 0/3 在 p=0.5 下概率 12.5%，毫不意外）⇒ **作为修复 = 否定**（既不能说更差也不能说更好）。
    - **但**：baseline 坏发 `l1=5`（`status=0x2200200`/`master=-110 peer=-110` 在），**arm A 坏发 `l1=0`（签名不在）、面板仍黑**。
    - ⇒ **「`-110` 命令 DMA 超时」与「面板不亮」是两个可分离的层**；过去七臂 vk116–vk125 与 B5 命令路径分析都盯错了层。**真需求是「面板有内容」。**
    - 附带解释：P2b/P2c（上游命令路径）当年「DRM 全 GOOD、面板无内容」与本型**完全同类**，其「1 发 GOOD」是判据错误而非真点亮。

275. **★★本板上「软件侧点亮代理」集体失效——`grim` 出图、`core_irq` 递增、DPMS/connector/背光/pclk 全部照常，面板仍可全黑。判「点亮」只认用户目视。**
    - 实测（arm A s3，用户确认黑屏）：`DPMS On`、`connector enabled`、`backlight on`、`disp_cc_mdss_pclk0/1_clk_src = 172991986 Hz` 被 `ae94000.dsi`/`ae96000.dsi` 认领、`byte*` 全认领、`crtc intf_mode=2`、**`grim` 出 1904×3040 且解码 151 个不同字节值（真桌面内容）**、**受激 `core_irq` delta = 8/次重绘（与 GOOD 台相同）** —— 全部成立，而面板是黑的。
    - 原因：`grim` 抓的是**合成器自己的 buffer**，不是面板输出；`core_irq`/`msm` IRQ 递增只证明 **DPU 在跑**，不证明**面板收到有效视频**。
    - ⇒ **`scripts/q28-devprobe2.sh` 会误报 `VERDICT=GOOD`**（规则 `l1==0` + connector + session **不充分**）；本会话 **s3、s5 两次**把用户确认黑屏判成 GOOD。**任何 Q28 判定不得只靠该探针。**
    - 唯一与目视一致的软件量（**辅助**，不可单独作数）：**`dsi_isr`（`/proc/interrupts` 的 mdss IRQ 4）——亮 = 41，坏 = 0**（本会话 5/5 一致）。
    - 与 `#251/#255` 同源，本条把它扩展到「agent 自以为找到的客观判据也全部无效」。
    - **纪律**：Q28 采样/判定**必须配合用户在场**；agent 不能自证点亮。

276. **★Q28 有两种坏发亚型，靠「电源键能否控背光」区分，dmesg 看不出来。**
    - **A 型**：电源键**能**控背光（实测 160→511）+ `l1=0`（panel "prepared"）⇒ 背光设备已注册可控，**但仍无画面** ⇒ 失败在更下游（video 真正跑起来的条件）。样本：arm A s3/s5。
    - **B 型**：电源键**不能**控背光 + `l1=5`（`-110`）⇒ panel init 真失败，背光/面板状态未接上。样本：baseline s4。
    - 两型的共同外围特征：**音量键与音频均正常**（即非整机死，是显示子系统局部失败）。
    - ⇒ 后续每发都应记录「背光是否可控」，它是免费的第三个维度。

277. **★`DSI PLL(0) lock failed status=0x00000000` ×4 与 `orphan reparent failed -110` ×4 是早期 probe 伪影，不是 Q28 判别量。**
    - 实测：这两组行在**三发样本（含用户确认 GOOD 的 s2）中完全相同**（各 4 次）⇒ 无判别力。
    - 教训：早期 probe 阶段的并发失败容易与运行时故障混淆；**判别量必须取好/坏发都打或都可比的固定点**（呼应 `#192`、vk118/vk119 探针设计原则）。
