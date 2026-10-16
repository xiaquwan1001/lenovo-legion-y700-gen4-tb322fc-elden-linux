---
name: "y700-adsp-ssc-sensors-bringup"
description: "在 y700-elden(TB322FC/SM8750P) 主线 Linux 上启用 ADSP 上的 Snapdragon Sensor Core(SSC)：加速度计/重力旋转/接近光/环境光/罗盘。触发词：传感器 no IIO node、hexagonrpcd、sensor_pd、QRTR svc 400、/dev/fastrpc-adsp 缺失、monitor-sensor 无 accel、自动旋转不工作。"
version: 4
created: "2026-10-09"
updated: "2026-10-09"
---
## When to Use
当需要让 Y700 四代在主线 Linux 上出传感器数据/自动旋转，或排查「无 /sys/bus/iio 节点」「qrtr 无 svc 400」「/dev/fastrpc-adsp 不存在」「ssccli 无输出」时。前提认知：SM8750P 无独立 SLPI，Sensor Core 在 ADSP 上、经 FastRPC 起 PD。

## Procedure
1. 确认 elden(TB322FC) 的 ACCEL_MOUNT_MATRIX 实测值：单位矩阵会让屏幕方向反 180°。正确值=绕 Z 轴 180°=X、Y 各取反、Z 不变：-1, 0, 0; 0, -1, 0; 0, 0, 1（2026-10-09 用户实机确认）。写进 81-libssc-elden.rules 后必须 udevadm control --reload + udevadm trigger --action=change /sys/class/misc/fastrpc-adsp 刷新设备 db，再 udevadm info -q property 确认读回新值（只 reload 不 trigger 可能仍显示旧值=异步竞态），最后 rc-service iio-sensor-proxy restart 让 proxy 重连读新 db。
2. 改前 cp -a 带时间戳备份规则文件；规则在持久 rootfs /etc/udev/rules.d 下重启自动保留。udev 只读 *.rules，备份名 *.rules.bak-* 不会被加载（安全）。经 ssh 用 sed 改含分号+引号的矩阵值易被远端 shell 吞引号而静默不匹配——改用本地 heredoc 喂 ssh 'cat > 文件' 整行重写最稳。
3. 自动旋转 tile 置灰/方向锁死（≠重力感应）：先确认是启动时序而非 SSC claim 竞态。iio-sensor-proxy 3.9 只扫一次即放弃，若在 svc400 出现前起，net.hadess.SensorProxy 整轮无加速度计→phosh rotation-manager 停 MODE_OFF→tile 置灰、方向锁死。现场免改判据：先确保 rc-service iio-sensor-proxy restart（svc400 已在则秒过），再重启一次 phosh 会话让其在 proxy 之后启动→拿起横过来应能转（实测 2026-10-09 生效）。
4. 持久修复（防下次冷启复现）：给 /etc/init.d/iio-sensor-proxy 加 start_pre() 等 QRTR svc400 就绪再起（封顶 60s、超时照起不退化）+ depend() 加 after hexagonrpcd-adsp-sensorspd。仓库真源 rootfs/persistent-overlay/iio-sensor-proxy.initd（restore.sh 在装包后 install 覆盖）。本 build iio-sensor-proxy 走 SSC/QRTR 后端：/sys/bus/iio 恒空但 HasAccelerometer=true，就绪判据用 qrtr-lookup|grep -qw 400，不要等 /sys/bus/iio 节点（永远没有）。
5. 重启 phosh 会话做取证/验证会重跑一次完整 KMS modeset，Q28 bonded-DSI 有「背光亮无画面」复发风险（恢复需物理冷启）；非必要不为查日志重启 compositor，优先端到端物理实测（用户转设备）判定。
## Pitfalls
- SM8750P 无独立 SLPI：不要去找 slpi.mdt 或 *-slpi-pas；传感器在 ADSP。
- 本树 qcom,non-secure-domain 只加在 cdsp 的 fastrpc 节点，ADSP 节点缺失是核心卡点（内核 fastrpc.c: secure_dsp=!of_property_read_bool(node,"qcom,non-secure-domain")）。
- hexagonrpcd 服务脚本硬编码 -f /dev/fastrpc-adsp（非 secure）；没有该节点就静默起不来。
- registry 由 PD 经 HexagonFS 反向写；config 目录必须整目录拷（不能只拷 json.lst 列的条目），registry 目录要 fastrpc 用户可写。
- iio-sensor-proxy 只查一次：必须在 sensorspd 起来、svc 400 出现后再启动；libssc 30s 拿不到 registry 就放弃。持久修复见 Procedure 第 4 步（init.d start_pre 等 svc400）。
- Alpine 默认 80-iio-sensor-proxy.rules 无 fastrpc 条目，必须自加 81-libssc-elden.rules。
- 内核二进制必须与磁盘 /lib/modules/<release> 的模块 vermagic 一致，否则 fastrpc.ko 装不上。
- 不要走 gnome-settings-daemon 路线修自动旋转：gsd46/50 上游已删 orientation 组件（Alpine 无主 gsd 二进制也无 gsd-orientation），往 phosh.session RequiredComponents/autostart 塞不存在的 helper 会 fail-whale（PITFALLS #51）。自动旋转是 phosh 原生：连系统总线 net.hadess.SensorProxy、绑 gsettings org.gnome.settings-daemon.peripherals.touchscreen:orientation-lock、经 phoc 设 transform。
- phosh UI 无独立“自动旋转”开关，只有单个“方向锁定”tile；tile 在 .ui 里 visible=1 恒显示，只 sensitive 绑 rotateinfo.present（=SENSOR 模式+有内置屏），present=false 时置灰——别误判为“开关消失”。
- 读 phosh 0.55 的 rotation-manager debug 日志不可靠（子代理读的 0.58 源码，措辞/时机不同）；判 mode 用端到端物理实测，不要 G_MESSAGES_DEBUG=phosh-rotation-manager 空跑。
## Verification
1. ls /dev/fastrpc-adsp 存在（非 -secure）。
2. qrtr-lookup | grep ' 400 ' 显示 Snapdragon Sensor Core service。
3. ssccli --sensor accelerometer 出持续变化的 X/Y/Z（平放 Z≈+9.5 m/s²）。
4. monitor-sensor 报出 accelerometer/light/proximity/compass 并有实时事件。