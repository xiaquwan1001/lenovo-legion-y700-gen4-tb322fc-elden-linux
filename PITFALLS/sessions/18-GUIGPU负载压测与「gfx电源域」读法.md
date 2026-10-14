## 十八、GUI/GPU 负载压测与「gfx 电源域」读法（2026-10-09 实测更正）

144. **`org.gnome.ScreenSaver.SetActive` 极性反直觉且落地有延迟**：`SetActive(true)`=**熄屏**、
    `SetActive(false)`=**唤屏**；调用返回 `()` 只代表 D-Bus 成功，**`dpms` 要到 ~3 s 后才变**。
    ⇒ 任何 `wake; sleep 2; assert dpms==On` 都会误判「唤屏失效」（本轮就这么白跑了一轮）。
    判据要等 ≥4 s，或轮询到超时。另外挂机很久（>1 h，屏幕已熄）后 `SetActive false` 仍能唤亮，
    不需要物理触摸；`mobi.phosh.Power` 在本机不存在（No service），`org.gnome.Mutter.IdleMonitor`
    也没有 `RecordUserActivity`（phoc 裁剪过），别照着 GNOME 文档抄。
145. **`gfx` 电源域 off ≠ 没有 GPU 活动，也 ≠ 桌面在软件合成（单看它会误判）**：idle 时恒
    `off-0`，真实 GUI 压力（foot+btop+chromium 循环）下会 **`on` ↔ `off-0` 跳变**。同时
    `adreno 3d00000.gpu` 只打到 `supply vdd not found, using dummy regulator`，
    `/dev/dri` 只有 `card0`+`renderD128`（显示卡）与 `/dev/kgsl-3d0` 不存在 ⇒ GPU 绑定状态本身
    仍存疑（G1 GPU 项待核）。**要判「合成器真在刷」用 mdss 中断增量**：
    `awk '/^ *185:/ {print $2}' /proc/interrupts` 取两次差（实测 6 s 内 +319 = 在刷）。
146. **别让 root 的 GUI 客户端继承 `/root` 当 cwd**：`foot -e sh -c ...` 以会话用户跑时会报
    `failed to change working directory to /root: Permission denied` + `sh: failed to execute`。
    正确做法：`setpriv … env HOME=$(getent passwd $U|cut -d: -f6) sh -c "cd $HOME && …"`。
147. **从主机对设备狂开 SSH 会自己造出「假复现」**：看守心跳（每 5 s 一条）+ 压测会话 + 交互会话
    并发时，sshd 会短时拒连/卡住，看起来像「整机挂死」（本轮误报一次）。⇒ 判定 FROZEN 必须
    **连续 3 次、间隔 5 s** 都不通，且最好有串口第二通道佐证（串口也静默才算硬楔）。

148. **★`pkill -f`/`pgrep -f` 会杀掉自己：模式里每个分支都要加括号**（本轮连踩两次，每次把自己的
     shell 打死，命令半截没执行）。原因：`bash -c "<整条命令>"` 的 cmdline 里含有模式文本本身。
     ⇒ 规则：模式里**所有**分支都写成 `dev[-]stress` 这种字符组形式（字面量分支如 `cat /dev/ttyACM0`
     也要写成 `ttyACM[0]`），并且 `| grep -vw "$$"` 兜底；**同一行不要再出现任何未加括号的字面量**
     （第二次栽的就是行尾另一处 `... | grep ttyACM0`）。安全顺序：先 `pgrep -af` 只列不杀，看清目标再杀。
149. **会在设备上产生用户可见动作的脚本，必须自己兜底清理**：主机侧 `timeout`/Ctrl-C 杀掉 ssh 时，
     设备侧循环不受影响 ⇒ 平板被留在「反复亮暗 + 桌面刷 tick」的状态。`gui-stress.sh` 已加
     `trap cleanup EXIT INT TERM`（回去 `pkill -f "dev[-]stress"` + `pkill -x foot|btop|chromium`）
     并在开跑前预告 5 s 可取消。**凡是抢屏幕/抢输入的自动化都要这么写。**

