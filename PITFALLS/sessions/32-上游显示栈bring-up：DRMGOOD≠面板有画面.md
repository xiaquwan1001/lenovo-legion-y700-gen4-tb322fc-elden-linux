## 三十二、上游显示栈 bring-up（P1–P2c 臂）：DRM GOOD ≠ 面板有画面（2026-10-13 深夜）

251. **★判「屏幕点亮」只认面板实测；DRM 判据（card0 / connector connected / CRTC active / phoc+phosh / grim 成功）全部满足，面板仍可能只有背光。**
    - 事实：P2c（上游 DSI host/manager + vendor PHY + vendor DPU）上 `card0-DSI-1` enabled、`crtc-0 enable=1 active=1 mode 1904x3040@120`、`plane` fb 由 phoc 分配、`grim` 截图成功且有非黑内容、`phoc` 在跑——但**用户实测面板只有背光、无内容**。
    - 与 Q28 坏发同型症状（仅背光），但 dmesg **无** `command DMA timeout` / `Failed to initialize panel`。⇒ 「背光无画面」不是单一根因的判据。
    - 规约：显示 bring-up 的结论必须 = **人手确认画面** + DRM/dmesg 辅助；`grim` 只证合成器渲染，不证面板显示。

252. **★上游 7.3-rc7 显示栈点不亮 elden 面板；「上游规范点亮」的 vendor 缺口 = DSI PHY（必需）+ DSI host（video/命令，最大块）+ DSI manager（enable 时序）+ msm_mdss（populate DSI PHY）+ vendor DPU 的 DRM 格式/modifier 面。**
    - 已验证的必要件：① PHY SM8750 C-PHY 位路径（`pll_7nm_register` 选 `DSICLK_SEL(0)`/`pll_bit`）——缺它上游连 `clk_set_rate(pixel_clk)` 都 -22；② `dsi_pll_byte_clk` 取速率；③ `mdss_prepopulate_dsi_phys()`（否则 `dsi1 phy not ready`）。
    - 纯上游 DPU 会让合成器 modeset 失败（`grim: no supported format found`、connector `disabled`）；换 vendor DPU 后合成器可扫描输出。但**即便合成器扫描输出，面板仍无画面** ⇒ 剩余缺口在 DSI host 的视频/命令编程。
    - 详细证据链：`reports/p1-upstream-dsi-20261013.md`；树 `build/p1-upstream-dsi`（分支 `p1/upstream-dsi`，P1 5f0c2c668f → P2c 2851bcaff6）。

253. **★显示处于坏态时 `reboot` / `reboot2` / `eldroid-bootctl reboot system` 都会挂在 DRM cleanup（进程不退、uptime 继续涨）；可靠软件恢复 = `echo b > /proc/sysrq-trigger`（或串口 BREAK 后发 `b`）。**
    - 实测：P2c 上三种常规重启全部无效（`uname -r` 不变）；`ssh root@... 'echo b > /proc/sysrq-trigger'` 立即生效（回日常 `vk94`）。
    - 附：`kmscube`（GL/EGL）在 P2c 上可触发整机硬挂（仅背光 + SSH 无响应，USB gadget 仍枚举），与 `PITFALLS #106` 同型；跑 GL 前必须常驻串口 logger。
    - 根因同类：`PITFALLS #143`（Q28 面板失败 → vblank 风暴占满 workqueue → shutdown/reboot 卡死）。


254. **★SSH 连接洪泛会把自己锁在外面（sshd 源惩罚）；而 U2 一直有 `/dev/ttyACM0` 内核控制台可用——判显示坏态不必依赖 SSH。**
    - 现象：轮询式 `ssh` 重试（本次 ~60 次）后，设备 sshd 立刻回 `banner line 0: Not allowed at this time` 后断开（OpenSSH 9.8+ 的 **PerSourcePenalties** 源惩罚），随后连 banner 都不再给（`Connection timed out during banner exchange`）；**TCP 能连上（内核 backlog）但用户态不回**——容易误判成"系统挂死"。惩罚按源 IP 记账，安静等待也不可靠（新连接可能续期），**最稳的恢复 = 重启设备**。
    - 纪律：设备探测**单次连接 + ≥15 s 退避**，用 `-o ConnectionAttempts=1 -o ConnectTimeout=8`，禁止 for 循环里高频 ssh；判定"是否挂死"不能只看 TCP 是否 accept。
    - **串口控制台（本次新发现）**：U2 的 USB gadget 同时暴露 **CDC-ACM 内核控制台** `/dev/ttyACM0`（`console=ttyGS0,115200`；`/dev/serial/by-id/usb-Lenovo_TB322FC_mainline_*HA2CB1KY-if02`），`cat` 即得内核 log（含 boot 之后的 WARN 风暴）；**没有 getty/无 shell、无回显**，只能读（BREAK+\`b\` 的串口 SysRq 本次未生效，仍需物理 POR）。⇒ **SSH 死了也能判 L1/L2**（本次即靠它看出 `vblank wait timed out on crtc 0` 风暴）。
    - ⚠️ **gadget 的 iSerialNumber 是硬编码常量 `HA2CB1KY`**（`rootfs/.../usr/local/sbin/usb-gadget` 第 37 行），**不是设备身份**——本次差点把 U2(HA2EXB0E) 误认成另一台。认设备只认 `fastboot getvar serialno`。


255. **★M1 7.3-rc7 重基树存在显示回归：健康的 m1-73j 启动点不亮面板，而同窗口的日常 vk94 正常出桌面 ⇒ 73i/73j 的"未亮屏"不是 Q28 坏发。**
    - 2026-10-14 同窗口（~09:00–09:40）对照：vk94 CRTC active + 用户实测桌面正常；m1-73j **L1=L2=0、phoc/phosh 在、CRTC active、grim 出图 39965 B**，但用户实测**只有背光无内容**。
    - ⇒ 用 `card0`/connector/CRTC/会话/grim 判"显示正常"在 M1 树上**无效**（呼应 #251）；M1 树任何"显示已通过"的结论必须面板实测。
    - 上游臂（P2b/P2c/P4a/P4d）的额外症状：phoc `no supported format`（modeset 失败）+ 强制 modetest 后 `dsi_isr=0`；DIAG 探针证明 `dsi_mgr_bridge_enable`/`msm_dsi_host_enable` 都被调用且 `DSI_CTRL 0x171→0x173`（VID_MODE_EN 置位）⇒ 缺口不在"enable 是否被调用"。
    - **DSC 1.2 否证**：P4a（P2c + vendor DSC1.2 RC 参数 + `first_line_bpg_offset`）与 P2c 行为无差别。
    - 证据：`reports/m1-73-display-regression-20261014.md`。

256. **★跨版本重基必须清点"上游 revert 过的设备必需修复"：elden 是 bonded 双 DSI，而 7.3-rc 把 `93c97bc8d85d ("drm/msm: dsi: fix PLL init in bonded mode")` revert 了（`44784327815b`，理由=它破坏了**非 bonded** 用例）⇒ M1 7.3-rc7 树点不亮面板。**
    - 代码形态（本地实测 diff）：`dsi_pll_enable_pll_bias()` 变成"首次调用即早退"（`if (pll->pll_enable_cnt++) { …; return; }`），且 `dsi_7nm_phy_enable()` 预置 `pll->pll_enable_cnt = 1` ⇒ `PLL_SHUTDOWNB`/`PLL_SYSTEM_MUXES=0xc0` 不再写入；7.2 血统树是**无条件自增**（带修复）。
    - 现象（易误判）：`clk_summary` 里 `dsi0vco` 有速率、CRTC active、phoc/phosh 在、grim 出图——**但面板只有背光**；判"点亮"只认面板实测（`#251/#255`）。
    - 教训：重基不止要比 payload 差分，还要 `git log --grep=Revert` + lore 查"上游在窗口内回滚过哪些与设备相关的修复"，否则会把设备必需修复悄悄丢掉。
    - 证据：`reports/m1-display-rootcause-analysis-20261014.md`、`reports/m1-73-display-regression-20261014.md`（含 Pengyu Luo 上游指路：缺 "dsi clk source select for the 10-bit CPHY plane"）。
    - **★已实测确认（2026-10-14 11:35）**：E1 臂（= `73j` 的 config/ramdisk/DTB/cmdline 逐字节复用，唯一变量 = 还原无条件重编程 + `Q28-E1` 探针）⇒ **面板有内容、触屏可操作**；探针实证面板 bring-up 时 `PLL_SYSTEM_MUXES` 由 `0x0` 变 `0xc0`（上游形态因 `pll_enable_cnt=1` 预置必然早退 ⇒ 该写入永不发生）⇒ **H1 = 根因**。证据 `reports/m1-73-e1-pllfix-20261014.md`。
    - **★最终形态（E1b，2026-10-14 12:40 实测确认）**：**保留上游 refcount**（`if (pll->pll_enable_cnt++)` 原样），只把 `writel(0xc0, …PLL_SYSTEM_MUXES)` 补进 `dsi_7nm_phy_enable()` 的预置块 ⇒ 干净 POR 发 **L1=0/L2=0、`dsi_isr`=41、面板有内容 + 触屏可操作**；净差异 vs 上游 = **1 行**。E1 的 refcount 变更形态**废弃**（上游即以「破坏非 bonded」为由 revert，别再送回）。
    - **两条台架纪律（同日实测）**：① **从坏显示态暖链（`reboot2 bootloader`）会污染台架**——已知 GOOD 的 E1 在同链下同样 `dsi_isr=0` + L2 风暴，任何显示判据只有在 POR 路径下才作数；② **M1-7.3 树同样有 Q28 偶发坏发**（E1b 第 1 发 = `command DMA timeout … master=-110 peer=0`），复判必须按 L1/L2/`dsi_isr` 三元签名排除坏发后再看面板。
    - **补丁形态注意**：E1 的还原改掉了上游的 refcount 语义（上游 revert 的理由正是该语义破坏非 bonded 用例）⇒ 上报上游前应先做 **E1b**：保留 refcount，只在 `dsi_7nm_phy_enable()` 预置点补写 `0xc0`（待测）。

---

