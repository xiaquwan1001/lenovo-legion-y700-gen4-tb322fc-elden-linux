// 2026-10-10 Q28 编排：3 lane 并行。
// 优先级（用户定）：调试开发便利 > 驱动检查/修 bug > 其他。
//   A 编译 Q28 delay 实验镜像（驱动 bug 修复，host-only）
//   B 设备日志取证（好发现场 dump + "谁开 DYN pclk"，SSH read-only）
//   C 上游联网调查（异步，不阻塞，返回 key 给父代稍后取）
// 设备此刻 = U2 已起 vk64（好发），SSH 192.168.7.1，slot b 已 mark-successful。
// 纪律：worker 只读设备 / 只 host 编译；reboot 循环由父代做；单写者——只有 lane A 碰 linux/。

const ROOT = '/home/xuqianhui1001/y700-elden';

// ---- Lane C：上游调查（async，不 await，先起跑）----
runs.run('research-upstream', {
  agent: 'researcher',
  context: 'fresh',
  async: true,
  output: `${ROOT}/reports/q28-upstream-research-20261010.md`,
  acceptance: 'attested',
  task: `目标：为 Q28（TB322FC/SM8750P 主线 Linux，面板首条 DCS 写 ff 20 走 bonded 命令 DMA 超时 -110，~71% 开机坏发）调研上游是否已有已知问题/修复。

已知硬事实（现场寄存器差分，7 坏/4 好零误报）：
- 失败点在 drivers/gpu/drm/msm/dsi/dsi_host.c：msm_dsi_host_bonded_cmd_trigger() 写 REG_DSI_TRIG_DMA=1 后命令 DMA 永不完成（STATUS0 卡 CMD_MODE_ENGINE_BUSY|CMD_MODE_DMA_BUSY，cmd_dma_busy/cmd_engine_busy=1）。
- 好/坏发唯一寄存器差异 = CLK_STATUS：好 0x2343，坏 0x3743 = 多 DSI_DYN_PCLK_ACTIVE(0x400)+DSI_DYN_CMD_PCLK_ACTIVE(0x1000) 两位（drivers/gpu/drm/msm/registers/display/dsi.xml，DSI6G）。
- 假说：首次 modeset 时命令 DMA 触发撞上 DYN 像素时钟域切换/门控。
- 平台 DSI 版本 6G minor >= V2_8_0（有 VBIF_CTRL priority 分支）；bonded 双 DSI（ae94000/ae96000）1904x3040@165Hz DSC wide。
- 内核树 = v7.2-elden（GEEKiDoS fork，基于上游 6.x/7.x），面板 novatek nt36536。

要查清（带 URL 与 commit/message-id 出处）：
1. 上游 drm-msm / LKML 是否有 "command DMA timeout" / "bonded command DMA" / DSI "DYN_PCLK" / "dyn refresh clock" / "cmd pclk" 相关 bug 报告或修复补丁（lore.kernel.org、patchwork.freedesktop.org、git log）。给出 commit hash 或 message-id。
2. 上游 dsi_host.c 在 cmd trigger 前对 clk_status / dyn pclk 是否有等待/门控逻辑（对比本树 msm_dsi_host_bonded_cmd_* 函数族是否缺了什么）。
3. 下游（codeaurora / Qualcomm msm-4.x/5.x/6.x / vendor 内核）的 dsi 驱动在 cmd DMA 触发前是否有 delay 或等 DYN 时钟稳定的处理（vendor 用 qcom,dsi-ctrl 等私有驱动；找它的 cmd trigger 路径）。
4. bonded DSI（双 DSI 拼宽）cmd mode 已知问题（如 dual-DSI panel bringup、slave 触发时序）。
5. 有没有人报告过"冷启概率性失败、重启后概率恢复"的同类 DSI 现象。

不要重复论证已知结论；只补外部证据。产出 = reports/q28-upstream-research-20261010.md：§1 命中清单（带出处）§2 对本树修复方向的启示 §3 未命中（明确说"未找到上游同类"也是结论）。`,
});

// ---- Lane A + B：起跑后并发 await（先各 start，再各 await，确保并发）----
const buildP = runs.run('q28-delay-build', {
  agent: 'worker',
  context: 'fresh',
  output: `${ROOT}/reports/q28-delay-build-20261010.md`,
  acceptance: 'checked',
  task: `在 ${ROOT} 主机侧编译一个 Q28 单变量实验内核镜像 + 两个 boot.img（基线 vs 实验），**只编译，不碰设备、不 fastboot、不 commit**。

背景：Q28 = 面板首条 DCS 写走 bonded 命令 DMA 超时（坏发 CLK_STATUS 多 DYN_PCLK_ACTIVE+DYN_CMD_PCLK_ACTIVE，好发没有）。单变量实验 = 在命令 DMA 触发前插一个可配 settle 延时（默认 0 = 现状），用 cmdline 切换 delay 值做同口径 A/B。

必须做的：
1. 先读 scripts/build-boot.sh、scripts/build-kernel.sh、scripts/env-build.sh 与 scripts/q28-boot-cycle.sh 顶部注释，搞清：(a) LOCALVERSION/vk 号怎么传；(b) CMDLINE_EXTRA 怎么注入 cmdline；(c) build-boot.sh 输出镜像命名规则。
2. 写补丁：编辑 linux/drivers/gpu/drm/msm/dsi/dsi_host.c，加（**唯一功能改动 = 可选延时，默认 0，不改任何既有逻辑**）：
   - 文件靠上（其它 static 附近）加：
     static unsigned int dsi_cmd_delay_us;
     用 early_param("dsi_cmd_delay_us", ...) + kstrtouint 解析（这样开机即可生效；不要用 module_param，DRM_MSM 是 =y built-in）。
   - 在 msm_dsi_host_bonded_cmd_trigger() 写 REG_DSI_TRIG_DMA=1 **之前**：若 dsi_cmd_delay_us 非 0，则先 dsi_read(REG_DSI_CLK_STATUS) 取触发前值，usleep_range(dsi_cmd_delay_us, dsi_cmd_delay_us+50)，再 dev_err 打印一行 "Q28 delay=%uu pre CLK_STATUS=%#x post=%#x"（post 再读一次），最后才写 TRIG_DMA=1。
   - 确认 REG_DSI_CLK_STATUS 宏确实存在（grep 本树 dsi 寄存器头），若名字不同用实际存在的宏；usleep_range 需 <linux/delay.h>（文件已 include，确认）。
   - 这是纯设备侧实验变体，注释里写清不是上游对齐、默认 off。
3. 把该改动另存为 patches/q28-cmd-dma-delay.patch（git diff 生成，可复现）。
4. 交叉编译内核 Image（LOCALVERSION=-vk84，走 scripts/env-build.sh + build-kernel.sh 既有方式；这是 =y 改动要重编整 Image）。
5. 出两个 boot.img（复用刚编好的 Image，不重编）：
   - 基线：out/boot-elden-vk84-q28delay-base.img（CMDLINE_EXTRA 不含 dsi_cmd_delay_us，等价现状）
   - 实验：out/boot-elden-vk84-q28delay-exp.img（CMDLINE_EXTRA="dsi_cmd_delay_us=1000"）
6. 自检并把原始命令+输出写进 reports/q28-delay-build-20261010.md：交叉编译通过、两镜像存在+sha256+size、两镜像 cmdline 唯一差 = dsi_cmd_delay_us=1000（用 dump/bootimg 工具或 grep 镜像里 cmdline 段证明）、dtb/Image 一致。

不要做：fastboot / 设备连接 / git commit / 改领域层文档。报告只报命令+原始输出，结论由父代判。`,
});

const forensicsP = runs.run('device-forensics', {
  agent: 'worker',
  context: 'fresh',
  output: `${ROOT}/reports/q28-device-forensics-20261010.md`,
  acceptance: 'attested',
  task: `通过 SSH（root@192.168.7.1，已起 vk64，本发是**好发**有桌面）从设备只读取一份完整取证。**严禁任何写操作 / reboot / fastboot / rm / 加载卸载模块 / 改文件**——纯 read-only dump。设备锁脚本 scripts/device-lock.sh 若存在则用它串行化。

采集（每项原始输出落盘到 logs/q28-forensics-<时间戳>/，并 cat 关键项）：
1. uname -a；cat /proc/cmdline；cat /proc/uptime；findmnt /；cat /proc/cmdline 确认 elden_nocamera。
2. 完整 dmesg（dmesg -t 或 cat /proc/sysrq-trigger 触发前先只读）存 dmesg.txt；grep 出 panel-novatek / command DMA / bonded / vblank 计数。
3. **重点（Q28 计划步骤③"谁开 DYN pclk"）**：cat /sys/kernel/debug/clk/clk_summary，把 dsi/mdss/pclk/dyn/gdsc 相关行连同 prepare/enable 计数与 consumer 列完整抓下来（这是好发现场，坏发态 clk_summary 已在 logs/q28-BAD-vk75dump-*/state.txt）。存 clk_summary.txt + 单独抽出 dsi/mdss 子树。
4. DRM 状态：/sys/class/drm/*/status、/sys/kernel/debug/dri/0/ 下 summary、连接面板 mode。
5. DSI 控制器寄存器快照（若 debugfs 有）：/sys/kernel/debug/dri/0/ 或 regmap 里 dsi 相关；没有就跳过并说明。
6. pstore：/sys/fs/pstore/ 列目录与内容（#106 卡死装弹是否在位）。
7. 串口设备：ls /dev/ttyGS*、确认 initramfs gadget 在位；cat /proc/tty/drivers 不必。
8. lsmod 全量 + vermagic（uname -r）；模块是否 vk64 vermagic 一致（供 mod-loop 用）。
9. 温控/电压：cat /sys/class/thermal/thermal_zone*/temp（关联 Q28 强时间相关假说：机身温度）。
10. 电源/充电：cat /sys/class/power_supply/*/capacity、online、voltage_now（充电态 Q28 假说候选）。

产出 reports/q28-device-forensics-20261010.md：§1 好发现场关键证据（尤其 clk_summary 里 DYN pclk 的消费者是谁——回答步骤③）；§2 与 logs/q28-BAD-vk75dump-*/state.txt 坏发的 clk_summary 对比表；§3 取证边界（取不到的项写明）。所有数字带原始行。

注意：这是好发现场（CLK_STATUS 应该=0x2343 基线）。若 dmesg 里出现 command DMA timeout 说明实际是坏发，照实写明。`,
});

const build = await buildP;
const forensics = await forensicsP;

return {
  build: { key: 'q28-delay-build', outputPath: build.outputPath, status: build.status },
  forensics: { key: 'device-forensics', outputPath: forensics.outputPath, status: forensics.status },
  research: { key: 'research-upstream', async: true, note: '上游调查仍在后台，稍后 bg_wait / status 取' },
};
