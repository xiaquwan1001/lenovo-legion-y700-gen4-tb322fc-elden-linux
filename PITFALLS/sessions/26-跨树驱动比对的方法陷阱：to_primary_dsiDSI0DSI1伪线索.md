## 二十六、跨树驱动比对的方法陷阱：`to_primary_dsi` DSI0/DSI1 伪线索（2026-10-12 静态核查）

196. **★「上游用 `dsi[1]`、本树改成 `dsi[0]`」= 伪线索，不是 Q28 杠杆；不要为此上机、更不要改成 `dsi[1]`。**
    - 背景：`reports/q28-handoff-20261012.md` §2-1 曾把它列为 **Q28 最高优先待核查项**（依据 `reference/upstream-pengyuluo/README.md` 的行级差异）。
    - 核验（全静态，未上机）：
      1. **vanilla `linux-7.2`**（`build/m1-upstream/linux-7.2.tar.xz`，非本树 worktree）的 `drivers/gpu/drm/msm/dsi/dsi_manager.c` **完全没有 `bonded_cmd_xfer`**（grep=0），且 `#define DSI_ENCODER_MASTER DSI_1`（注释「take the encoder of DSI_1 as master encoder」）。
      2. **本树**（GEEKiDoS `v7.2-elden` 下游 + 我们改动）有整套 `dsi_mgr_bonded_cmd_xfer()`，其注释明写 **「This supports hardware where DSI0, not DSI1, is the broadcast master and completion source」**；`dsi_mgr_uses_bonded_cmd() = is_sm8750 && IS_BONDED_DSI()` → 本机为真。
      3. 本树 `dsi_manager.c:80` 按 DT `qcom,master-dsi` 解析 `master_dsi_link_id`；**本树与 Pengyu 上游 DT 都**把该属性挂在 `mdss_dsi0` ⇒ 硬件 master = DSI0。
      4. `dsi_mgr_bonded_cmd_xfer(msg)` **完全忽略消息来自哪个 host**（master/slave 全由 `master_dsi_link_id` 解析，见 `dsi_manager.c:590-655`）。
      5. 面板驱动（本树与上游）**无 RX 读命令、无 `MIPI_DSI_MSG_REQ_ACK`**（均 grep=0）⇒ `dsi_mgr_use_bonded_write()` 对每条 DCS 命令都成立 ⇒ **全部命令走 host-agnostic 的 bonded 路径**。
    - 结论：两边各自**自洽**——上游 `dsi[1]` ↔ 上游 mainline 的 `DSI_ENCODER_MASTER=DSI_1`；本树 `dsi[0]` ↔ 本树下游的「DSI0 是 broadcast master」。在本硬件上 **`to_primary_dsi()` 返回 `dsi[0]` 或 `dsi[1]` 是 no-op**：既不是 Q28 的因（Q28 已定案=构建身份伪影，#195），也不是 bug。**改成 `dsi[1]` 反而与本树 `dsi_manager.c`（DSI0 master）自相矛盾，有引入新回归的风险。**
    - 方法学：跨树比对驱动前，**先确认差异所在的机制层在两边是否都存在**。此处「上游写法 vs 本树写法」属**两套不同 MSM 实现**（mainline 无 bonded cmd xfer），不是同一机制的两种参数；把行级差异直接当候选根因是误判。
    - 同步更正：`reference/upstream-pengyuluo/README.md`、`reports/q28-handoff-20261012.md` §2-1。

197. **★Q24「第二 CC probe 时 RPMh 批量投 0」= **cambist probe 的常规行为**，不是死因（2026-10-12 实测更正）。**
    - 旧口径（`reports/q24-repro-20261011.md` §4）把「第二个 CC 加载时 RPMh 一次性把 `ebi/gfx/lcx/lmx/mss/nsp/nsp2/gmxc/mxc`→0、`mmcx`→6、`mx`→5」称作**死前共同签名**，隐指其为死亡机制。
    - 2026-10-12 阶段 A 实测（`logs/q24-stageA-20261012/`）：`modprobe camcc` → `modprobe cambistmclkcc-sm8750`，**无熄屏、设备存活**，RPMh trace 里**同一串投 0 照样出现**。归因=i) 那批轨的**稳态本来就是 0**（`mxc=off-0`、`ebi/gfx/gmxc/lmx/lcx=off-0`）；ii) cambist 注册为 genpd 子域时 genpd 重报全部轨聚合值。⇒ **时间相关巧合，非因果**。
    - 更正：判断 Q24 现场时**不得**把该死前 trace 当作「已进入危险态」的判据；真正缺的仍是「熄屏瞬间 DPU/面板路径对 `mxc/mmcx` 的增量投票」。
    - 另记（同轮）：本轮终态是**整机挂死（hang）**，不是历史口径的「硬复位/真关机」——USB gadget 仍枚举（`devnum` 不变、`active_duration` 连续增长 ⇒ 未重启）、NCM `rx/tx` 冻结、串口无回显。⇒ Q24 终态取证必须并列多判据（`boot_id` + `devnum`/`active_duration` + USB 枚举 + 串口回显 + `ip neigh`）。详见 `reports/q24-stageA-20261012.md`。

198. **★「熄屏类」实验必须先用硬门证明「屏真的关了」，否则 no-op 会被当成存活（2026-10-12 实测教训）。**
    - 现象：`gdbus … org.gnome.ScreenSaver.SetActive true` 返回 `()`（成功），但 `GetActive` 恒 `false`、`DPMS` 恒 `On`、`bl_power` 恒 0、RPMh trace **零事件** ⇒ **屏根本没关**。若不做门，就会把「无事发生」读成「不致死」。
    - 根因（本轮）：**合成器已卡死**——`phoc` 在 `D (disk sleep)`，`wchan=rpm_resume`（栈 `adreno_get_param→__pm_runtime_resume`），同批 `a6xx_gmu_set_oob` / `msm_gpu_fault_crashstate_capture` 也在 D 态（GPU 故障捕获）；`kill -9` 无效。dmesg 佐证 `ctl 1 reset failure: -22` / `frame done timeout` / `wait for commit done returned -110`。D 态的 phoc 持有 DRM master ⇒ `modetest … DPMS:3` 恒 `Permission denied`。
    - 触发条件：本轮是经 **`reboot2 bootloader`（暖复位）**进的 fastboot = `PITFALLS #166` 的粘坏态。**⇒ Q24/Q28 任何 A/B 的起点必须是物理 POR**；`reboot2 bootloader` 只用于回日常。
    - **硬门（下次必过）**：执行熄屏后**读三个值**——`GetActive`、`/sys/class/drm/card0-DSI-1/dpms`、RPMh trace 里必须出现 `0x30080`(mmcx)/`0x30000`(cx) 的降档票；任一不动 = 本次**无效**，不得计入存活/死亡。
    - 另：D 态进程清单（`/proc/*/status` 的 `State: D` + `/proc/*/wchan`）应作为「台架是否健康」的前置检查。
    - 证据：`reports/q24-ctl-20261012.md` §7–§9、`logs/q24-s123-20261012/device-evidence.txt`。

---

