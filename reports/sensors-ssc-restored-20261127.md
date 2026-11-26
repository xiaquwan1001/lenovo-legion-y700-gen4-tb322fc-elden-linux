# ★ 传感器回来了：主线 Linux 上 SSC 三属性全 true + `ssccli` 出真值（2026-11-27 收口）

> 无人值守轮收口。前序：`reports/sensors-692-backport-test-20261126.md`（假说 A 否证）、
> `reports/sensors-adsp-pd-pdr-20261127.md`（PD 面排除）、`reports/pmic-pon-reset-reason-20261127.md`（复位源）、
> `reports/hexagonrpc-upstream-registry-write-20261127.md`（上游 #29）、`reports/sensors-692-file-root-20261127.md`（布局与 0 字节配置）。

## 0. 结论（实测，均为本机现态）

```
HasAccelerometer  = true
HasAmbientLight   = true
HasProximity      = true
ssccli --sensor accelerometer → X=-1.17 Y=-0.66 Z=9.55 m/s² …（连续出值，Z≈g）
```
`iio-sensor-proxy` **active**（`systemctl start` 后常驻）；`AccelerometerTilt/Orientation` = `undefined` 是**已知非判据**
（需客户端 claim + 姿态变化，`PITFALLS` 老账），不要拿它当"没出数"。

## 1. 一条完整的因果链（本次把每一环都实测到位）

```
① droid-juicer 给的 sensor 配置是 0 字节占位（139 config 仅 1 非空 / sms_reg_config 0 B）
② hexagonrpcd 0.5.0 的 -R 树是扁平布局，与 droid-juicer 的 Android 布局不符         → 三个 Could not open
③ 真 vendor 配置按扁平布局就位后，DSP 不再断言（trial6：0 条 PDM crash、ADSP 一直 running）
④ 宿主侧：udev 缺 ssc-accel（PITFALLS #451）+ iio-sensor-proxy 被 masked            → 三属性全 false
⑤ 补上 81-libssc-elden.rules + unmask/start proxy ⇒ 三属性全 true、ssccli 出真值
```

**多轮里所有"整机静默复位"的唯一来源** = ①+② 造成的 DSP 断言（`sns_registry_sensor.c:309`）在**本板上**被放大成
PAS 关停/重启段的整机复位（`PITFALLS #737` 已修订：内核其实看到了 fatal error 并进了 SSR recovery）。
配置一真，复位现象**整条消失**（trial6/7/8/9 共 4 发，0 复位）。

## 2. 收口后的可复现步骤（本机现态逐条可重跑）

```sh
# 1) 取真配置（一次性；大件已删，重建见 reports/sensors-692-real-configs-20261127.md §1）
#    产物在本机：out/vendor-extract-20261127/etc-sensors/sensors/{config,sns_reg_config,…}
# 2) 设备上准备 0.5.0 扁平 -R 树
R=/var/lib/hrpcd-root
install -d $R/sensors $R/dsp
cp -a <config dir>  $R/sensors/config
cp    sns_reg_config $R/sensors/sns_reg.conf
cp -a <registry 骨架> $R/sensors/registry      # 目录里要有 registry/DIR（0 B 即可）+ sns_reg_version + parsed_file_list.csv
ln -sfn /usr/lib/firmware/qcom/sm8750 $R/dsp/adsp
# 3) 补 udev 规则（仓库里有成品：packaging/elden-userland/files/etc/udev/rules.d/81-libssc-elden.rules）
install -m644 81-libssc-elden.rules /etc/udev/rules.d/ && udevadm control --reload && udevadm trigger --subsystem-match=misc --action=change
udevadm info /dev/fastrpc-adsp | grep -c ssc-accel      # 必须 ≥1
# 4) attach 一次（**同一 boot 只能一次**；已注册过会报 Could not register ADSP default listener）
setsid /usr/local/bin/hexagonrpcd-patched -f /dev/fastrpc-adsp -d adsp -s -R /var/lib/hrpcd-root/ </dev/null >/tmp/attach.log 2>&1 &
# 5) 起代理并验收
systemctl unmask iio-sensor-proxy; systemctl start iio-sensor-proxy
busctl get-property net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy HasAccelerometer   # b true
ssccli --sensor accelerometer | head -3
```

## 3. 残余（下一轮/后续，均不阻塞"传感器可用"）

1. **`Unsupported method: 36 (1f050100)` = `fopen_with_env_fd`**：DSP 最后会调它，我们没实现 ⇒ 返回 `AEE_EUNSUPPORTED`，
   `run_fastrpc_listener` 因此退出（`alive=0`）。**当前不影响出数**（attach 已完成、代理走 QRTR 直连 SSC），
   但 **DSP 侧重启后需要重新 attach**，届时需要这个方法 + 常驻（上游 unit 是 `Type=simple` + `Restart=always`）。
   最小修法：把 `fopen_with_env_fd`(36)/`fopen_fd`(34)/`fclose_fd`(35) 也做成"假成功"（签名见 AOSP `apps_std.idl`）。
2. **registry 仍是 343 条 0 字节骨架**：DSP 自己重建过但没有可写后端落盘。真写后端（copy-on-write 到 `/var/lib/hexagonrpc/`）
   才能持久化 registry/标定数据；不做的话每次 PD 重启都要重新解析（当前可用，只是慢/丢标定）。
3. `oemconfig.so` 与 7 个 json 在 ROM 里本就没有（可选项，DSP 未因此失败）。
4. 上游：#29 的"registry 写支持"仍 open；我们现在的配置/布局经验可直接回帖（**需用户放行**）。

## 4. 与台账的关系

- `TASKS/G1.md` **G1-34** 本来就是 ✅（2026-10-30 起），本次是**在当前树/当前根上复现并修好**，
  所以 §0 的 36/37 不变；变化记在 `TASKS/NEXT.md` **T6/T13** 与 `INDEX.md` §0。
- `PITFALLS` 新增 **#741**（0 字节占位配置 + 扁平 -R 布局 + 同一 boot 只能 attach 一次 + `Unsupported method` 会结束服务）。
