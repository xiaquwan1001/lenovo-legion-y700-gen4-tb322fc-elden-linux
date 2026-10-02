# 暂停存档 — 2026-10-02 12:2x（切安卓前）

> 用户要求：暂停所有 worker、保存进度，临时切到 Android。
> 本文件是恢复入口；详细原始日志已拷到 `logs/agent-logs-2026-10-02/`（约 80MB）。

## 0. 暂停动作已完成

- **所有 spawned worker 已停止**：`spawn list` = 空，无 `pi --mode` 进程。
  - task-8 音频 AudioPilot4、task-10 Win-x86 CanaryWin4 均已**自行完成并退出**。
  - task-9 相机 CameraPilot3 在"准备重启验证冷启加载"时被**主动 stop**（工作已实质完成，见下）。
- **监控已停**：`swarm-monitor.sh` 已 kill。
- **harness 保留在端口 9878**（未杀，切回可直接用）。
- **设备侧：已冷启验证相机模块自动加载成功**。设备当前在线（`v4l2-ctl --list-devices`=Qualcomm Camera Subsystem + `/dev/video0-16`/`/dev/media0`；media graph s5kjns/gc08a8 ENABLED）。现处于 mainline Linux（boot_b）；可直接切 Android。
- 另：task-8 音频/相机/温控所有设备改动均在 **sda17 的 Linux rootfs** 与 boot_b，不动 Android（a 槽 userdata 146G）；切 Android 不影响。

## 1. 任务总账（12/13 完成）

| task | 状态 | 结论摘要 |
|---|---|---|
| task-1~6,12 | ✅ | 探针/Win 可行性/EL2/相机拆解/GAPPS/音频 tplg/冒烟 |
| **task-8 音频** | ✅ 完成 | **APM 图打通**。根因链：① `GRAPH_OPEN status=1` 已由 container capability 用新 GC 修复；② `BE graph(id=18, Secondary MI2S) APM_CMD_GRAPH_START` 5s 超时(-110)，因本树在 **trigger** 启 BE graph，而原厂在 **prepare 末尾**启、且 **BE 必须先于 FE**。修复=为 `q6i2s_ops` 加 prepare-time `q6apm_graph_start`（`patches/0011`），刷 **vk39**（`out/boot-elden-vk39.img`）验证 `APM_CMD_GRAPH_START status=0`、连播无错。**待用户上机 `amixer -c0 cset numid=8 on; speaker-test` 确认可听声**（设备无 capture）。 |
| **task-9 相机** | ✅ 完成（已冷启验证） | 不刷 boot、只部署 `.ko`。隐藏最深一环：`CONFIG_V4L2_FLASH_LED_CLASS` 未开 → `flash-leds` 只注册 LED class、不注册 v4l2 flash subdev → sensor async notifier 永远 waiting → media graph 无 link。开启并重建 20 个 `.ko` 后：`/dev/media0 + video0-16 + v4l-subdev0-31` 全出；s5kjns(11-0056, SGRBG10 4080x3072)→csiphy3 [ENABLED]；gc08a8(12-0031)→csiphy4 [ENABLED]。持久化=`/etc/modules-load.d/camera.conf`。**冷启后实测仍自动加载**（重启验证成功）。 |
| **task-10 Win-x86** | ✅ 完成 | **Box64 0.4.5(DynaRec)+Wine 9.0(wine64:amd64)** 在设备 glibc chroot(`/root/glibc-rootfs`, Ubuntu24.04 arm64/glibc2.39) 跑通 x86_64：`cmd /c echo hello`→hello；`strings64.exe`；GUI `notepad.exe` 在 Phosh 出窗（截图 `WIN-X86-POC-notepad.png`）。旧 box64 0.2.6 的 fork 风暴根因=版本过旧。交付：`WIN-X86-POC-2026-10-02.md`、`scripts/win-x86-rootfs.sh`、`scripts/win-x86-run.sh`。 |
| **task-11 网络** | ✅ 完成 | 根因=内核缺 `CONFIG_IP_ADVANCED_ROUTER` → 容器无默认路由。**不刷 boot 方案打通** Waydroid 容器内 Google 通路。 |
| **task-13 温控** | ✅ 完成 | 分级 trip 已在线（70/82/90/105，递增 state；`patches/0010-thermal-graded-trips.patch`）；压测#1 峰值 CPU **82°C**（事故 103°C）、稳态 80.8°C；`scripts/thermal-watch.sh` 上机通过。 |
| **task-7 基准** | ⬜ 未派 | CPU/GPU 多 API 基准；可复用 task-13 的压测/采样框架。 |

## 2. 关键产物 / 版本

- 内核 boot 镜像：**`out/boot-elden-vk39.img`**（音频修复，b 槽当前）。回退基线 `vk35`。
- 音频 patch：`patches/0011`（q6i2s prepare-time graph_start）。
- 温控 patch：`patches/0010-thermal-graded-trips.patch`。
- Win-x86：`WIN-X86-POC-2026-10-02.md` + 脚本。
- 相机：20 个 `.ko`（本树构建，vermagic 匹配设备）+ `/etc/modules-load.d/camera.conf`（设备侧）。
- 原始 worker 日志：`logs/agent-logs-2026-10-02/`。

## 3. 恢复方法（切回 Linux 后）

```bash
cd ~/y700-elden
# 1) 确认 harness 在跑（9878）
./scripts/swarm.sh --status
./scripts/swarm.sh task list          # 应显示 12/13
# 2) 恢复已切好的官方 provider：.pi/settings.json = deepseek/deepseek-flash
# 3) 重派未竟任务（示例）
./scripts/swarm.sh spawn --role ThermalEngineer "..." --task-id task-9  --agent-file .pi/agents/camera.md
./scripts/swarm.sh spawn --role ???            "..." --task-id task-7  --agent-file ...
```
- 注意：`scripts/swarm.sh` 已钉回会话桶 `01a0f868-...`；worker 已打 detached 补丁，可扛 harness 重启。
- 重派 task-9 时先让 worker **只重启验证冷启**（模块持久化已写入），再补 `CAMERA-2026-10-02.md` 文档。
