## #658 「设备能枚举」不等于「fastboot 命令通道可用」：多项目共用一台 USB 调试主机时，隔壁项目的孤儿 `fastboot` 进程会抢走通道，表现为**我们的命令发出后设备黑屏崩溃**

结论: 2026-11-14 连续三次 UEFI 复测崩溃（`fastboot boot` 前、`fastboot reboot-bootloader`、以及**只发 3 次 `getvar product`**）都不是固件/载荷/命令写法问题，而是主机上有 **13 个孤儿 `fastboot oem dump-emmc ptable` 进程**（来自隔壁项目 `kirin-tool-linux`，`PPID=systemd --user`，父进程已死，已存活 10 h，在 `fastboot` 自身重试 sleep 里周期性重开同一 USB 设备）在争抢同一台设备的 fastboot 通道。设备侧表现 = 黑屏 + 崩溃 + 自行回落正常槽位。

判据:
- **`fastboot devices` 能列出 SN 只证明「USB 枚举正常」，不证明「命令通道可用」**。真正的门 = 发一条**无副作用**命令（`getvar product`）能否在 5 s 内返回；`< waiting for <SN>>` 挂住即通道不可用。
- 崩溃后**先**数孤儿：`pgrep -af "fastboot"`（注意模式写字符组 `[f]astboot` 避免自匹配）。同主机上任何 `fastboot <cmd>` 进程只要 `PPID=1`/`systemd --user` 且 cwd 属于**别的仓库**，就是嫌疑。
- 现场特征：孤儿进程 `wchan=hrtimer_nanosleep`、**无常驻 USB fd**（`ls -l /proc/<pid>/fd` 只有 0/1/2）⇒ 它们在「睡一会儿再重开设备」的循环里，而不是持有端点。

处置:
- **隔离**：`pkill -f "[f]astboot oem dump-emmc"`；再查 CI runner 是否会重启它们（本例 `gitlab-runner` 常驻，`xqh/kirin-tool-linux-refresh` 的 job 会重放）。
- **恢复**：先只发一次 `getvar product` 验证，再发任何写盘/启动命令。
- **预防**：任何要独占 USB 调试设备的脚本，执行前先做「孤儿 fastboot 进程 + 单发 getvar」双门；不同项目的设备实验不要并行在同一主机上跑。

反例（别踩）: 本轮一度怀疑「`fastboot reboot-bootloader` 写法不对」——`fastboot --help` 明确有 `reboot [bootloader]`，写法合法；也一度怀疑 UEFI 载荷把设备搞崩，但第三次崩溃时**我们只发了 `getvar`**，与载荷无关。**归因顺序：先证明通道独占，再怀疑固件。**

证据指针: `reports/artifacts/uefi-retest-20261114-212908/`（`30-orphan-test.txt` 孤儿快照、`31-stability.txt` 三次 `getvar` 全挂、`README-取证摘要.md` 时间轴）
