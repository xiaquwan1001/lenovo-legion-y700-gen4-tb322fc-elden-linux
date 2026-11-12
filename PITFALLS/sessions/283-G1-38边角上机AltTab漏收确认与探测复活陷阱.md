# 2026-11-12 G1-38 边角上机（T-H1/T-H3/T-A6/T-H5）+ 五失效点实测定案

- **日期**：2026-11-12 晚
- **pi 会话 id**：$PI_SESSION_ID
- **主题**：G1-38 OSK 剩余边角实验（GTK3 双窗 / Alt+Tab / 同窗换焦点 / fcitx5 重启与停止）
- **结论**：
  1. **T-H1 Alt+Tab 跨窗 = 漏收确认**：A 窗 Entry 弹键盘（`show requested by SetRelativeSpotRect`）后 Alt+Tab 到 B 窗（无输入控件），fcitx5 **不发零矩形、State 保持 1**（旧 IC 残留），OSK 挂着（vis=true 持续 ≥20 s）。与静态预测（§2.4 ②）一致。对照：**关掉 A 窗**（IC 销毁）时 State→0，focusd `hide requested by fcitx State=0` 正确收起。
  2. **T-H3 同窗 Tab 到 Button = 2 s 即时收不触发，但 idle 兜底有效**：fcitx5 对同窗焦点轮换**不发零矩形**（`zero_rect_since_us` 无从置位）⇒ 立即收路径沉默；把 `ELDEN_IME_IDLE_SEC` 临时降到 45 s 后实测 **45 s 兜底收起成功**（`hide requested by idle timeout`，t+51=false）。300 s 默认值下用户感知 =「换焦点后键盘挂 5 分钟」，属已知局限非新 bug。
  3. **T-A6 fcitx5 重启零矩形误弹回归 = 通过**：`systemctl --user restart fcitx5` 后 14 s 内 vis=false，focusd 日志无零矩形 show——四改中的零矩形过滤有效。
  4. **T-H5 fcitx5 停止 = 通过（附探测陷阱）**：真停时 focusd 经 `State=0`（或 -1 宽限）1 s 内收起。**方法论坑：org.fcitx.Fcitx5 是 dbus-activatable，用 busctl 探 State 本身会把 fcitx5 拉活**（stop 后立刻探 ⇒ `i 1`/active，看起来「没收」）——判据必须以 focusd 日志 + 不探 State 的 vis 轮询为准。
  5. **执行环境坑（新）**：root ssh 下 `setpriv --reuid` 起的 GTK 进程 IC 建不出来（State 恒 0）；必须 `su - xuqianhui1001`（带 HOME/XDG_RUNTIME_DIR）才能建 IC。探针 `probes/ime/ime-gtk3-two.py`（双窗）+ `probes/ime/g138-edge.sh`（判据脚本，POSIX sh）已入库。
  6. 设备上二进制 = `out/ime-host` 产物逐字一致（sha `c76dbee7…`），非陈旧件——局限是**算法口径**（State==0 收、零矩形 2 s、idle 300 s）而非部署漂移。
- **证据指针**：`/tmp/elden-ime-focusd.log` 各时刻行（本文件只录判据序列）；探针 `probes/ime/{ime-gtk3-two.py,g138-edge.sh}`；截图 `reports/artifacts/ime-osk-edge-20261112/`（shot-two.png = B 窗 OSK 误挂）。
- **★SSOT 待并入**：TASKS G1-38 行的「仍未验」三项中两项已验（Alt+Tab=漏收确认、GTK3 一例通过）；剩 Qt 一例（`fcitx5-frontend-qt6` 未装）与候选窗遮挡（T-C2）。
- **后续建议**：漏收治本 = focusd 订阅 `CreatedIC`/`DestroyedIC`（kimpanel2 未广播）或收 `UpdateSpotLocation` 停发；代价小，下轮处理。
