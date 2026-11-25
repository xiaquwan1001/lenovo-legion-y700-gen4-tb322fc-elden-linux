# #723 主机侧传 `--auto`、设备侧参数解析器不认 ⇒ 软重启「静默不执行」，表现为「设备没反应」

> 2026-11-25 实测（设备在 Linux、日常核 vk192 / UTS `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`，systemd 257.13）。
> 现象：`scripts/to-bootloader.sh` 跑满 150 s 也没进 fastboot；主机侧只看到「等超时」，
> 设备侧 `uptime` 连续增长、`boot_id` 不变 —— 即**根本没有重启**。

## 根因（一行）

`scripts/to-bootloader.sh` 第 3 步发的是 `ssh … "nohup /usr/local/sbin/elden-to-bootloader --auto …"`，
而设备侧脚本的 `case` 只认 `--dry-run / --psci / --bcb / --clear-bcb`（`--auto` 是**默认臂**，没写进参数表）
⇒ 脚本第一行就 `die "未知参数 --auto"`（exit 2）。主机侧把 ssh 的 rc 和输出都丢进 `/dev/null` +
`|| true`（`nohup … &` 那条），所以**两边都看不到失败**。

## 判据（30 秒定位，别再等超时）

```sh
ssh root@192.168.7.1 'cat /tmp/elden-to-bl.log'    # ← 唯一现场：脚本自己写的日志
# 命中 "FAIL 未知参数 --auto" 即本条
ssh root@192.168.7.1 'uptime -p; cat /proc/sys/kernel/random/boot_id'   # 连续不变 = 没重启过
```

## 处置

- **设备侧脚本补 `--auto) MODE=auto ;;`（与默认一致，纯兼容层），已重新 `scp` 部署 + `--dry-run` 自检。**
- **主机侧驱动一律把设备侧日志落到固定路径**（`/tmp/elden-to-bl.log`），失败时 `cat` 回显；
   不要用 `>/dev/null 2>&1 || true` 把「参数错误」和「设备无反应」混成同一现象。**
- 软路径改动后先跑 **设备侧 `--dry-run`**（打印将要发的真命令），再跑主机侧。

## 连带教训

- 「设备没反应」的第一嫌疑 = **命令没发出去**，不是内核/ABL。判据 = `boot_id` 是否变 + 设备侧日志；
  静态判断（`kallsyms` 有没有钩子）永远排在这两条之后（承 #690/#701 的旧错因）。
- 修好后实测：Linux → BL **18–19 s**；BL → Linux（`fastboot boot` 零写盘）**21–29 s** 到 SSH；
  闭环脚本 `scripts/autotest-cycle.sh`，详见 `reports/autonomous-test-cycle-20261125.md`。
