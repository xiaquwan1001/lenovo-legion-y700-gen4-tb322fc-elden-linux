# 自主测试闭环：BL ⇄ Linux 双腿验证 + `scripts/autotest-cycle.sh`（2026-11-25）

> 一句话：**无人值守的内核上机循环今天打通并实跑通过** —— `fastboot boot` 零写盘投放（BL→Linux ~21 s）
> + `systemctl reboot --reboot-argument=bootloader` 回 BL（~19 s），封装成一条命令、可连跑 N 轮。
> 起因 = 用户出门前要求「提前持久化部署能从 Linux 到 BL 的版本，这样就能自主测试」。

## 1. 结论（数字优先）

| 项 | 实测值 | 判据 |
|---|---|---|
| BL → Linux（`fastboot boot` 测试件，零写盘） | **21–29 s** 到 SSH（12 s 传完+`Booting` 10 s + 9 s sshd） | `runs/autotest-20261125T070749Z-smoke/round1-fastboot.txt` |
| Linux → BL（软路径） | **18–19 s** 到 `fastboot devices` 见 `HA2EXB0E` | `scripts/to-bootloader.sh` 三次实测 |
| 单轮闭环（投放+就绪 45 s+探针+回 BL） | **≈90 s** | `runs/autotest-20261125T071202Z-smoke3/index.txt` |
| 连跑 | **2/2 轮 rc=0**（同一件重复投放） | 同上 |
| 持久化槽位健康 | 活动槽 `_b`、`Successful=1`、`Bootable=1`；`boot_b` 内容 = vk192（`uname -v` `#32 … Nov 16 10:55:25`） | 设备侧 `qbootctl` dump |
| 硬件看门狗 | **无**（`watchdog: Hard watchdog permanently disabled`、无 `/dev/watchdog`） | 见 §4 限制 |

## 2. 两条腿各自的「成熟组合」（用户口径）

- **Linux → BL**：设备侧 `elden-to-bootloader`（`/usr/local/sbin/`）+ 主机侧 `scripts/to-bootloader.sh`。
  真命令 = `systemctl reboot --reboot-argument=bootloader`（PITFALLS #722：systemd 257 移除了位置参数）。
  **今天踩到的真 bug**：主机侧一直传 `--auto`，设备侧参数解析器不认（只认 `--dry-run/--psci/--bcb/--clear-bcb`）
  ⇒ 脚本打一行 `FAIL 未知参数 --auto` 就退出、设备纹丝不动，主机侧表现为「等 150 s 超时、没反应」。
  修法 = 设备侧补 `--auto`（= 默认 auto 臂），已重新部署到设备并 `--dry-run` 自检通过。→ PITFALLS #723。
- **BL → Linux**：`fastboot -s HA2EXB0E boot <img>`（零写盘；ABL 从 RAM 起核）。
  **镜像预检（本轮新增）**：cmdline 必须 `elden_root=LABEL=linux` —— 2026-11-19 起盘标签从 `linux17` 改成
  `linux`，`out/` 里大量旧件仍写 `linux17`，直接投放会「起核但挂不住根」。`autotest-cycle.sh` 用
  `scripts/boot-img-cmdline.py` 解析后**不匹配就拒跑**（rc=2），不浪费一轮。

## 3. 交付物

| 件 | 说明 |
|---|---|
| `scripts/autotest-cycle.sh`（新） | 全自动循环：起点判定（fastboot/Linux/无）→ 必要时先回 BL → `fastboot boot` → 等 SSH（`--boot-timeout`）→ 等就绪（`systemd is-system-running` ∈ running/degraded 且 ≥`--settle-min`）→ 跑 `--test` 脚本或内置探针 → 回 BL；`--rounds N` 连跑；日志落 `runs/autotest-<UTC>-<label>/`（`index.txt` + 每轮 `roundN-*.txt`）。退出码 0/10/11/12 语义见 `--help`。 |
| `scripts/elden-to-bootloader.sh`（修） | 增 `--auto` 分支；注释记「主机侧一直传 `--auto`，缺此分支 ⇒ 软路径静默不执行」。 |
| 设备 `/etc/systemd/system/qbootctl.service.d/override.conf`（新） | `ExecStart=qbootctl -m` 每次开机必失败（`get_number_slots: Failed to open bootdev dir`，PITFALLS #181 同因）⇒ 换 `qbootctl-mark.sh`（等待+重试+复核），实测 `active`/rc=0/`SLOT _b: is marked successful`。仓内副本 = `packaging/elden-userland/files/etc/systemd/system/qbootctl.service.d/override.conf`。 |
| `runs/autotest-*` | 三次实跑日志（smoke / smoke2 / smoke3 / inspect）。 |

## 4. 限制与风险（无人值守必须知道的四条）

1. **硬挂死 = 需人工**。本机没有可用硬件看门狗（`watchdog: Hard watchdog permanently disabled`，`/dev/watchdog` 不存在），
   `q28-boot-watchdog` 服务在现根里也不存在 ⇒ 若测试核 **hang**（非 panic），设备会一直卡住，只能物理 POR。
   能自愈的只有 panic（cmdline `panic=15` → 15 s 后复位回 `boot_b`）。
   ⇒ 自动循环只跑「失败会 panic 的」实验；改 early-boot/时钟/电源域这类可能静默挂死的不进无人循环。
   （改进项：内核开 `CONFIG_QCOM_WDT` 或让 systemd 喂一个真 watchdog，即可把 hang 也变成自愈——已记 TASKS §4。）
2. **绝不写槽**。测试件只走 `fastboot boot`；`boot_b` 保持 vk192 日常核，任何测试失败都不影响下次正常开机。
3. **回落判定要区分两种情况**：等 SSH 超时后若 `fastboot devices` 有目标 SN = 「投放核没起来、已回落 BL」（可继续）；
   若两者都没有 = 真挂死（脚本报 rc=11 并停，不盲试）。
4. **`systemd is-system-running` 会早到**：early sshd 在 ~29 s 就答，此时 DSI/WLAN 尚未起、`systemd` 已是 `degraded`
   （现根有 3 个常驻 failed unit：`lxc-net`/`lxcfs`/`qbootctl`）。故 `--settle-min`（默认 45 s）是必要下限，否则探针拿到半启动态。

## 5. 复现（三条命令）

```sh
# 设备现在在哪
scripts/autotest-cycle.sh --state
# 单件单轮（内置探针）
scripts/autotest-cycle.sh --image out/<件>.img
# 带测试脚本连跑 3 轮，日志在 runs/autotest-*
scripts/autotest-cycle.sh --image out/<件>.img --test probes/<x>.sh --rounds 3 --label <名字>
```

判据：`index.txt` 每轮 `result=TEST … rc=0`，末行 `结束（rc=0）`；设备最终停在 **fastboot**（除非 `--stay-linux`）。
