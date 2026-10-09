# CAMERA-NOTFOUND-2026-10-10 — 根因："camera not found" 三层定位

设备 y700-elden (TB322FC)，内核 7.2.0-debug-vk64-gd02658e63cf6（boot_b）。全部设备命令走 `scripts/device-lock.sh`（本会话独占持有，结束后已释放）。

## 结论（一句话）
"camera not found" 是**设计内行为（配置层根因）**：`elden_nocamera=1` 的日安全态让相机内核模块完全不加载 → 无 /dev/video* / /dev/media* → libcamera 枚举为空 → 任何 app 报 "camera not found"。**模块 installed ≠ loaded**。栈加载后（CAM_FORCE=1 camera-modules-load.sh / cam-mode.sh on）两颗摄像头全部枚举成功并出真实帧。

## 证据链（原始日志在 logs/cam-notfound-2026-10-10-*）
1. **未加载态**（02-unloaded-enumeration.log）：lsmod 相机相关 = none；`ls /dev/video* /dev/media*` 两者不存在；`cam --list` / `cam -l` → "Available cameras:"（空）；`gst-inspect-1.0 libcamerasrc` 工厂正常存在（仅枚举不到相机）。
2. **加载态**（03-load.log）：`CAM_FORCE=1 cam-mode.sh on` → 20 模块 / 1 media / 17 video 节点；blanking 关闭（idle=0）。
3. **枚举恢复**（04-loaded-enumeration.log）：`cam --list` →
   - 1: Internal back camera (/base/soc@0/cci@ac7b000/i2c-bus@0/camera@56)  ← s5kjns
   - 2: Internal front camera (/base/soc@0/cci@ac7c000/i2c-bus@0/camera@31) ← gc08a8
   （注：软件 IPA 模块 'simple' 对两 sensor 的 camera sensor helper 构建失败，回退 uncalibrated.yaml——仅影响 3A 质量，不阻断枚举/出流。）
4. **真实出流**（05-capture2.log）：`cam -c 1 --stream=width=1920,height=1080,role=viewfinder --capture=3` → 3 帧 @ ~30fps，SoftwareIsp 输入 4080x3072 GRBG-10-CSI2P，输出 1920x1080 ABGR8888。**前 csiphy -32 阻塞已彻底不复现**。
5. **清理**（06–12）：`cam-mode.sh off` → rmmod 全部 sensor + camss + cci 成功（gc08a8/s5kjns 首次报 "in use" 属 rmmod 异步竞态，重试即清）；blanking 恢复（idle=300, AC=900, BATT=900, LOCK=true）；/dev/video* /dev/media* 为空；sensor/camss 全部卸载（/proc/modules 验证 sensors-unloaded）。

## 残留（无害）
`system_heap`（/proc/modules 标 [permanent]，不可 rmmod）与 v4l2 核心基建模块（videodev/mc/videobuf2_v4l2/videobuf2_common，use count 显示 0 但互相报 in-use——debug 内核 usecount 显示滞后/环引用）留在内存。无任何 media/video/sensor 节点，功能上相机全关，重启即净。cam-mode.sh status 计数 "= 1" 即 system_heap 残项。

## Q24 折衷与裁决遵守
- 未把相机烧入日安全态；唯一合规开关 = `sh /usr/local/sbin/cam-mode.sh on|off`（per user ruling）。
- `cam-mode.sh on` 先关 blanking 再加载；全程未熄屏；off 恢复 blanking。
- 已部署缺口：`camera-stream-up.sh` / `keep-awake.sh` 仅在宿主 scripts/，设备 /usr/local/sbin 只有 camera-modules-load.sh + cam-mode.sh。用户工作流若依赖"一条命令起流"，需部署 camera-stream-up.sh（建议连同 keep-awake.sh）。
- 桌面 app：GNOME Snapshot 存在（org.gnome.Snapshot.desktop），flatpak 未装；快照 app 走 libcamera，栈未加载时同样报 not found。

## 编排者独立复核（2026-10-10，父会话持锁重跑，不采信子代理自报）
- **根因独立确认 = 配置层**：开机基线（我亲测）cmdline 带 `elden_nocamera=1` → lsmod 相机栈 = 0、`/dev/video*` `/dev/media*` 均不存在 → libcamera 枚举空 → app 报 "camera not found"。`.ko` 全部在盘（installed），只是没加载（not loaded）。与子代理结论一致，证据充分。
- **⚠️ 本会话期间设备发生一次硬复位（Q24 复现）**：camdiag 加载相机栈出流后约 23:34 设备重启（`/proc/uptime` 归零）。`/sys/fs/pstore` 与 `/var/log/pstore` **均空** = 无 oops 的硬复位 = **与既有 Q24「无痕重启」特征完全一致**（TASKS G1-33 已记同类）。⇒ 现役 vk64 上把相机栈加载后，Q24 硬复位风险**仍在**（cambistmclkcc 未根治、上游报告待发回复）。
- **当前设备安全态复核通过**：0 相机模块 / video=media=subdev=0 / dpms=On / pstore 空 / cmdline `elden_nocamera=1`。已释放设备锁。
- **裁决（§8.5 两决定，见 CAMERA-WRAPUP）**：① vk78-modular **不刷**为日常 boot_b（其 /init 不再挂 `elden_nocamera` ⇒ 相机常驻 = 违反 Q24）；② payload-modules-load.sh **不**同步到持久根（双加载器 = #157 静默失败温床）。均与本轮 Q24 复现相互印证。
