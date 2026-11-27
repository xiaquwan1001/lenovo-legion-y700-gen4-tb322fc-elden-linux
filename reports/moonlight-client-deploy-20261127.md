# Moonlight V+ 客户端部署报告（Y700 四代 / elden / TB322FC）— 2026-11-27

## 结论

**部署完成 + 待一次 GUI 配对。**

## 资产

- 文件：`Moonlight-VPlus-6.5.7-aarch64.AppImage`
- 大小：`95,963,656 B`（与工单预期一致）
- sha256：`aec90c578f24e97b9db1943330a50ab3193f17e02e472146b1df77a80dc1f163`（主机与设备两侧一致）
- URL：`https://github.com/qiin2333/moonlight-qt/releases/download/v6.5.7/Moonlight-VPlus-6.5.7-aarch64.AppImage`
  （注：V+ 的 AppImage 发布在 qiin2333/moonlight-qt 的 Releases，tag `v6.5.7`；`qiin2333/moonlight-vplus` 仓库只有 Android 版本）
- 下载方式：`curl -L`（经本机 127.0.0.1:7890 代理），未使用 rayburst/aria2
- 主机留档：~~`~/y700-elden/artifacts/…AppImage`~~ **已删（2026-11-27 收尾：96 MB 二进制不入库、不占盘；设备侧 `/opt/moonlight-vplus/` 即有正本，重下用上面 URL + sha256 校验）**

## 部署

- AppImage：`/opt/moonlight-vplus/Moonlight-VPlus-6.5.7-aarch64.AppImage`（0755）
- 包装脚本：`/usr/local/bin/moonlight-vplus`（0755），内容：
  ```bash
  #!/bin/bash
  exec env XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0 QT_QPA_PLATFORM=wayland \
    /opt/moonlight-vplus/Moonlight-VPlus-6.5.7-aarch64.AppImage "$@"
  ```
  说明：ssh `elden` 登录即 uid 1001，无需 setpriv 降权（实测 `setpriv --init-groups` 报「不允许的操作」，已去掉）。以 uid 1001 + `WAYLAND_DISPLAY=wayland-0` 起 GUI。

### 回退方法

```bash
ssh elden 'sudo rm -rf /opt/moonlight-vplus /usr/local/bin/moonlight-vplus'
```

## 兼容性证据（设备实测输出）

| 项目 | 结果 |
|---|---|
| glibc | `ldd (Debian GLIBC 2.41-12+deb13u4) 2.41` ≥ 2.39 ✔ |
| libfuse3 | `/usr/lib/aarch64-linux-gnu/libfuse3.so.4` 存在 ✔（`fusectl` 已挂载） |
| fusermount3 | `/usr/bin/fusermount3` 存在 ✔ |
| `/` 剩余空间 | 159G 可用（/dev/sda17，190G 已用 13%）✔ |
| 系统 | Debian 13 (trixie) |

AppImage 运行时自检：`--appimage-version` → `AppImage runtime version: https://github.com/AppImage/type2-runtime/commit/fedfad5`，**FUSE 可用，无需 `--appimage-extract-and-run`**。

## GUI 启动验证（命令 + 原始输出）

```
$ ssh elden 'timeout 20 moonlight-vplus >/tmp/mvlp.log 2>&1; echo exit=$?; tail -8 /tmp/mvlp.log'
exit=124        # timeout 正常 SIGTERM
00:00:07 - Qt Info: clientname: "elden"
00:00:10 - Qt Info: clientname: "elden"
00:00:16 - Qt Warning: Update check timed out   # 仅自动更新检查超时，不影响功能
00:00:19 - SDL Info (0): Received signal: 15
```
Qt + SDL 正常启动，Wayland 下界面已可渲染。无残留进程。

## 配对下一步（GUI 配对，PIN 在界面点）

1. 主机启动 Sunshine（已在运行，pid 见 `ps`）。
2. 设备上 `moonlight-vplus` → 界面添加主机 `192.168.7.1`（或主机 IP）→ 界面会显示 PIN。
3. 主机侧提交 PIN（HTTP 接口为 **HTTPS**，明文 HTTP 返回 empty reply；已验证 basic auth 200，用户名是 `xuqianhui` 而非默认 `sunshine`，口令在 `~/.config/sunshine/webpass.txt`，不在此回显）：

```bash
curl -sk --noproxy '*' \
  -u "xuqianhui:$(tr -d '\r\n' < ~/.config/sunshine/webpass.txt)" \
  -H 'Content-Type: application/json' \
  -d '{"pin":"<界面PIN>","name":"elden"}' \
  https://127.0.0.1:47990/api/pin
```

  （返回 200 即配对成功；也可直接在浏览器 `https://127.0.0.1:47990` 的 Pin 页面输入。）

4. 配对后即可在 V+ 界面选择应用起流。

## 遗留风险

- 配对未执行（需在设备 GUI 手动输入/提交 PIN），本轮止步于「待 GUI 配对」。
- `Update check timed out` 为设备侧出网受限所致，可忽略；必要时在 V+ 设置里关闭自动更新。

---

## 追加（2026-11-27，父代理上机实测）：硬件解码不可用，非客户端缺陷

用户上机试用 V+ 报了「检测不到硬件解码」。逐条取证（`ssh elden`，只读）：

| 检查 | 实测 |
|---|---|
| `/dev/video*` | **零个**（`ls /dev/video*` → `没有那个文件或目录`） |
| DT `soc@0/video-codec@aa00000` | 存在，`compatible = "qcom,sm8750-iris"`，**`status = "disabled"`** |
| 内核配置 / 模块 | `CONFIG_VIDEO_QCOM_IRIS=m`，`qcom-iris.ko` 在 `/lib/modules/7.3.1-debug-vk189-suspend-*/kernel/drivers/media/platform/qcom/iris/` |
| 驱动为何不 probe | 节点被显式关；上游 `sm8750.dtsi` 原注释：「IRIS firmware is signed by vendors, only enable in boards where the proper signed firmware is available.」 |
| `modprobe qcom-iris` | 无 probe 日志（节点 disabled） |
| Vulkan 面（替代路径） | `libvulkan_freedreno.so` 的 strings 里有 `VK_KHR_video_decode_h264/h265`，但 turnip 侧解码未验证；ffmpeg `-hwaccels` 有 `vulkan` 无实际可用解码器 ⇒ 不作为可行路径 |

**结论**：V+ 报的「无硬件解码」是**事实**（本机确实没有解码节点），当前只能软件解码。

**本机规避（今天可用）**：V+ 设置里把解码器改成软件（AVCodec），分辨率 720p–1080p、码率 ≤20 Mb/s。

**治本**：三项链条（已在 `reports/hwdec-iris-sm8750-feasibility-20261127.md` 取证）——
① 从 Android `vendor_a` 取 iris/vpu 厂商签名固件装 `/lib/firmware/qcom/…`；② 板级 dtsi 覆盖 `status = "okay"`（`video_mem` 保留区、`iommu 0x1940/0x1947`、`videocc` GDSC 都已在上游 `sm8750.dtsi` 里）；③ 主线 iris 驱动对 `qcom,sm8750-iris` 的兼容项与固件命名/HFI 版本要对上，对不上就是上游能力缺口（按项目原则登记 + 试上游）。

**GUI 自动化经验（本轮实测，可复用）**：`grim` 需 DPMS On（`wtype -k Escape` 唤醒）；`uinput-touch tap` 因设备枚举延迟常无效，**必须用 `uinput-touch hold-swipe X Y X Y <attach_ms=2500> 1`** 才可靠；Qt（V+）窗口对注入触点不响应（疑似需 wl_touch 正确焦点），键盘 `wtype -k Return` 可被接受。

---

## 追加 2（2026-11-27 14:1x，父代理完成配对 + 起流）：**端到端通了**

### 做什么（全部设备侧 GUI 自动化，未改 Sunshine 配置）

1. 唤醒屏（`wtype -k Escape`，DPMS Off→On）→ 上滑解锁（`uinput-touch swipe 950 2700 950 900`）。
2. 起 V+（`setsid nohup moonlight-vplus`），已在 `[hosts]` 里有 `xuqianhui-pc / 192.168.7.9:47989`（`srvcert` 为空 = 未配对）。
3. `hold-swipe 385 676` 点主机 → V+ 弹「请在你的主机上输入 **1692**」。
4. 主机侧提交 PIN —— **注意新版 Sunshine（2026.1106）API 变了**：
   - 旧写法 `POST /api/pin {"pin","name"}` → `400 {"error":"pairing_id must contain exactly 32 hexadecimal characters"}`；
   - 正确顺序：`GET /api/pin` 返回 `{"pairings":[{"address":"192.168.7.1","id":"d0a9403e…","name":"roth"}]}` ⇒
     `POST /api/pin {"pin":"1692","name":"elden","pairing_id":"<上面那个 id>"}` → `{"status":true}`。
5. 设备侧确认 `1\srvcert=@ByteArray(-----BEGIN CERTIFICATE-----…)` 已写入 = 配对成功。
6. 进主机 → app 列表（Desktop / Limbus Company / Agent 终端）→ 起 Desktop ⇒ **设备上出现主机桌面，标题 `xuqianhui-pc - Moonlight`**。

### 起流实测（软解）

```
SDL Warn (0): Vulkan device 'Adreno (TM) 830' does not support VK_KHR_video_decode_h264
SDL Warn (0): Vulkan device 'llvmpipe' does not support VK_KHR_video_decode_h264
SDL Error(0): No suitable Vulkan devices found!
FFmpeg: [h264_v4l2m2m] can't configure decoder          ← 无 /dev/video* ⇒ V4L2 解码器建不起来
SDL Info (0): FFmpeg-based video decoder chosen          ← 落软解
SDL Info (0): Audio stream has 2 channels
SDL Info (0): Recreating renderer for window event: 6 (1902 3039)
SDL Info (0): Frame pacing disabled: target 165 Hz with 60 FPS stream
```
“`Adreno 830 不支持 VK_KHR_video_decode_h264`” 这条是 turnip 的实测答复 ⇒ Vulkan 视频解码这条路也堵死（与 Q36 的结论互相印证）。

### GUI 自动化可用性（本轮踩到的真事，下次直接复用）

| 动作 | 可用性 |
|---|---|
| `grim` 抓屏 | ✅（但 DPMS Off 时失败，必须先唤醒；唤醒后 1904×3042） |
| `uinput-touch tap X Y` | ❌ 常无效（设备枚举延迟） |
| `uinput-touch hold-swipe X Y X Y 2500 1` | ✅ 等价于点按（先等 2.5 s 让 phoc 认到注入设备） |
| `uinput-touch swipe` 解锁 | ✅ |
| `wtype -k Return/Tab/Left` | ✅ 可驱动 V+ 的对话框与列表（**V+ 的瓦片按键能点，触摸不响应**） |
| `pkill -x phosh-osk-stub` | ✅ 关掉占焦点的 OSK（phosh 会按需重拉） |
| 起流 | 需焦点在瓦片 + OSK 不抢焦点；`space`/`Return` 都试过，最终是 `hold-swipe` 点到瓦片才起流 |

⚠️ 一处观察（未立项）：V+ 的主机列表页会**自己弹出 OSK**（没有文本框），疑似 phoc/osk 的 `Enable()` 状态残留 —— 与 D13/OSK 线相邻，记在这里备查。
