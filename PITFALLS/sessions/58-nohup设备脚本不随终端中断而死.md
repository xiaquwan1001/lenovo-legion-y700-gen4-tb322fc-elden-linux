## 五十八、`nohup` 起的设备脚本不会随监控中断而死 —— 它会继续折腾设备（2026-10-20 实受）

**现象**：用户在旁观察到我「中断了一条命令」之后，设备仍在**反复重启 → 断电 → 偶尔经过 fastboot → 再重启**，
期间还抽中一次屏幕好发。而我的终端里那条命令早就结束了。

**根因**：

```bash
nohup bash scripts/n5b-vk64-death-rate.sh 5 > /tmp/n5b2.log 2>&1 &
sleep 150; tail -25 /tmp/n5b2.log     # ← 我中断的是这一条
```

`nohup ... &` 让脚本**脱离父 shell**成独立会话；我中断的 `sleep 150; tail` 只是监视器。
于是脚本继续跑完 5 轮：每轮 `reboot2 bootloader` → `fastboot boot` → 失败 → 回落 → 再踢进 fastboot……

实测残留：**PID 485392，`n5b-vk64-death-rate.sh 5`，存活 302 秒**。
`ps` 里 `ppid=485390`（父 shell），但父 shell 已被我中断 —— nohup + `&` 的组合让子孙进程独立存活。

**为什么危险**（比在主机上跑更甚）：

- 这类脚本**直接操作设备**：`reboot2 bootloader`、`fastboot flash/boot`。
  无人看管时它会持续打断设备，用户看到的是「设备自己发疯」。
- 设备被反复硬启会让 boot_b 的 `slot-retry-count` 掉（`PITFALLS #150–#152`），
  耗尽后设备**真的 unbootable**，需要 EDL 救砖。
- 掩盖真实信号：用户观察到的「设备自己在重启」被误当成设备故障，而不是我留下的进程。

**规矩（设备类脚本必须遵守）**

- **不要用 `nohup ... &` 跑会操作设备的脚本**。要么前台跑（能 Ctrl-C 真停），
   要么用 `timeout -k 10 N bash script` 把整段生命周期框死。
- 万不得已要后台：**必须记录 PID**，并在监控中断时显式 `kill` 该 PID。
   `pkill -f <脚本名>` 有自杀风险（`pkill-self-match`），用 PID 最稳。
- 脚本自身要有**单轮时长上限 + 总时长上限**（本项目 `timeout -k` 纪律）：
   一次 `fastboot boot` 卡住不该让整个 5 轮流程失控。
- 脚本每轮开头**检查设备真实状态**（在 Linux？在 fastboot？uptime 多少？），
   不满足就明确报 FAIL 并退出，而不是盲目重试。
- 收工前必须 `ps` 确认无残留，再看设备是否健康。

**本次的处置**：`kill -TERM 485392` → 确认无残留 → `fastboot reboot` 把设备踢回系统 → 复核 `uname/uptime/phoc`。

**顺带记一个同源坑**：`sleep N; tail ...` 这种「监视长任务的命令」自身被中断，
**不代表**被监视的任务被中断。判断「任务还在不在」只认 `ps`，不认终端回显。

**证据**：`/tmp/n5b2.log`（5 轮记录，Round 1 ALIVE / 2 无效 / 3 FAIL / 4 跑错内核 / 5 FAIL）；
设备最终回落到 vk127，`boot_id` 已换新。
