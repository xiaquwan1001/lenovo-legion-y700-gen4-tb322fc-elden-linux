# Q24「相机常驻 + 熄屏」实测 → `cam-mode-off` 退役、改默认相机常驻（2026-11-27）

- 触发（用户 2026-11-27）：「`/dev/video*` 为 0 是 `cam-mode-off.service` 主动卸载的策略态——这个是否过时？可以继续修复。」
- 结论：**过时了，已改默认**。相机栈现在开机常驻（`camera-modules.service`），`cam-mode-off` 降级为手动策略件（不再 enabled）。

---

## §0 一页结论

| 项 | 修前 | 修后 |
|---|---|---|
| 开机后 `/dev/video*` | **0**（`cam-mode-off.service` 每次开机跑 `cam-mode.sh off` 把整栈卸掉） | **17**（`/dev/v4l-subdev*` 32 个；`v4l2-ctl --list-devices` 见 `Qualcomm Camera Subsystem (platform:ad27000.isp)`） |
| 相机栈 | 需手动 `camera-modules-load.sh` 或 `cam-mode.sh on`（后者还会**顺带禁掉熄屏**） | `camera-modules.service`（oneshot，`WantedBy=multi-user.target`，enabled） |
| `cam-mode.sh` | 「相机 ⇄ 熄屏」必须二选一的强制策略 | 保留为**手动策略件**（`off` = 真要长待机/取证时卸栈）；`status` 文案已改 |
| 熄屏安全性 | 靠「不准相机与熄屏同时出现」规避 | 靠 7.3 上游 `rpmhpd: skip retention by default`（树的 `rpmhpd.c` 里 = `.active_only` ⇒ `to_active_sleep()` 把 sleep vote 置 0） |

## §1 为什么说它过时（口径链）

1. **Q24 已于 2026-10-24 关闭**（用户裁决「不值得取证」），原因 = 根因已指名：`TASKS/GAPS.md` §5 Q24 行、`TASKS/G1.md` G1-22 行原文写的是 —— 上游 `pmdomain: qcom: rpmhpd: Skip retention by default`（2026-06-29），**7.3 线已含 ⇒ 日常线免疫**。
2. **G1-22 行自己留了一句关键限定**：「日常仍用 `cam-mode.sh on/off` 互斥（**安全策略，非既成事实**）」——即：从来没人按 Q24 的验收判据（「装相机模块后长时空闲不断电」）在 7.3 线上验过。
3. 本机在跑的就是 7.3.1（`7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`），树里 `drivers/pmdomain/qcom/rpmhpd.c` 有 `.active_only` 机制、`to_active_sleep()` 对 active-only rail 把 sleep vote 置 0 ⇒ 上游修复确实在。

## §2 实测（本轮判据）

| 步骤 | 命令 | 原始结果 |
|---|---|---|
| 加载相机栈（**不动**熄屏设置，故意造成「相机在位 + 可熄屏」这个历史上必挂的组合） | `sudo /usr/local/sbin/camera-modules-load.sh` | `[camera] done: 1 media, 17 video nodes`；`lsmod` 15 个相机相关模块 |
| 节点与格式 | `v4l2-ctl --list-devices` / `-d /dev/video0 --get-fmt-video` | `Qualcomm Camera Subsystem (platform:ad27000.isp)`，`/dev/video0..16`；`1920/1080 UYVY` 可读 |
| 熄屏态 | `cat /sys/class/drm/card*-DSI-1/dpms` | `Off`（DPMS 关） |
| 连续观察 | 主机侧 30 s 采样循环（`out/cam-q24-test/monitor.log`） | **t=0 → t=618 s（10 min 18 s）**：`boot_id` 恒为 `cebacb0f…`、`uptime` 单调增（1671→2289 s）、`video=17` 恒定、**零 UNREACHABLE、零 BOOT_ID CHANGED** |

> 判据口径来自 Q24 行：「装相机模块后长时空闲不断电」。历史失败形态是**熄屏后数分钟内整机硬复位/断电**（`cam-mode.sh` 头注原文：「相机模块在位时熄屏掉电是常态」），10 min 无事件已足以反驳该前提；用户 2026-11-27 明确「不需要更长的测试」⇒ 采信到此为止，监控样本留档。

## §3 落地改动（都已上设备）

1. `packaging/elden-userland/services.tsv`
   - 新增 `camera-modules	ours	oneshot	…	/usr/local/sbin/camera-modules-load.sh	…	multi-user.target	1`
   - `cam-mode-off` 行 `enabled` 1 → **0**，desc 改为「手动策略件…默认相机常驻见 camera-modules」
   - `render.py` → 24 服务 / 21 默认启用（`out/units/systemd/camera-modules.service`）
2. 设备：`install camera-modules.service` + `systemctl enable`（= enabled；oneshot 跑完是 inactive，属正确态）+ `systemctl disable cam-mode-off.service`
3. `/usr/local/sbin/cam-mode.sh`（= `packaging/elden-userland/files/usr/local/sbin/cam-mode.sh`）：头注与 `status` 文案改成新口径；**行为不变**（`off` 仍能一键卸栈）
4. 回退：`systemctl enable --now cam-mode-off.service && systemctl disable camera-modules.service`（或 `cam-mode.sh off`）

## §4 遗留 / 注意

- `cam-mode.sh on` 仍会**禁掉熄屏/挂起**（那是给「相机取证」用的老口径），现在它与默认态不再冲突；若将来有需要，可把 `on` 里的 blank-disable 拆成独立开关。
- "相机常驻" 的功耗面未测（相机栈在位但无流 ⇒ runtime PM 应把时钟关掉）；若要量化，走 D11（设备发热/功耗）线，不要在本条里混。
- 本条不动 C5（`v4l2loopback` 相机共享）与 Waydroid/droidloom：它们要的是 `/dev/video100` 与容器侧链路，与本条的 camss 常驻解耦。

## §5 追加：真重启后的开机态复验（2026-11-27 16:09，父代理）

`sudo systemctl reboot` → 新 `boot_id = c314e0c9-3cfa-4533-a063-22bfb87f258f`，实测：

```
$ ssh elden 'ls /dev/video* | wc -l; systemctl is-enabled camera-modules; systemctl is-enabled cam-mode-off'
17
enabled
disabled

$ systemctl status camera-modules.service
   Active: inactive (dead) since 16:09:33            ← oneshot 跑完的正确态
   Process: 651 ExecStart=/usr/local/sbin/camera-modules-load.sh (code=exited, status=0/SUCCESS)

$ cat /sys/class/drm/card*-DSI-1/dpms
On
$ sudo /usr/local/sbin/cam-mode.sh status
==> 状态 = CAM-ON：相机常驻（2026-11-27 起默认态；熄屏安全，…）
```

- 开机即 **17 个 video 节点**，`camera-modules` oneshot `status=0/SUCCESS`，`cam-mode-off` = disabled ⇒ **默认策略切换生效**。
- 本次启动无 panic 记录：`/var/log/pstore` 空、`/sys/fs/pstore/` 空。
- 说明：`/var/log/camera-modules.log` 未生成 —— 该 unit 的 `log` 列写了路径但 `camera-modules-load.sh` 并不自己重定向（oneshot 默认交 journald）；留档以 `journalctl -u camera-modules` 为准，后续如要文件日志在脚本里加 `exec >>` 即可（不影响功能）。
