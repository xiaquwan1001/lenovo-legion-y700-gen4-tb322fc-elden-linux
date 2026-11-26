# #741 · SSC 传感器 attach：`-R` 必须是 **0.5.0 扁平布局** + 配置必须是**真 vendor 文件**；同一 boot **只能 attach 一次**

- 日期：2026-11-27（`#692` 收口轮，设备 TB322FC / 主线 vk192）
- 三个必踩点（逐条实测）：
  1. **`-R` 布局**：`hexagonrpcd` 0.5.0 的 `rpcd_builder.c` 常量是扁平的
     `<R>/sensors/{config/,registry/,sns_reg.conf}`、`<R>/dsp/<dsp>/`、`<R>/acdb/`、`<R>/socinfo/`；
     Debian wrapper 默认的 `-R /var/lib/droid-juicer/sensors/` 是 **Android 布局**（`vendor/etc/sensors/…`、`mnt/vendor/persist/…`）⇒
     表现为 `Could not open /vendor/etc/sensors/sns_reg_config` 等 3 条 ENOENT。
  2. **配置必须是真文件**：droid-juicer 抽出的那份 `config/`（139 个）只有 1 个非空、`sns_reg_config`/`json.lst` 都是 **0 B** ⇒
     DSP 在 attach 时断言 `PDM: service 'qsh_process' crash: … sns_registry_sensor.c:309` ⇒ 本板放大成**整机静默硬复位**（`#737`）。
     真配置从官方 ROM 取：`super_1..8.img` 按 `rawprogram*.xml` 的 `start_sector` 稀疏拼回 → `lpunpack -p vendor_a` →
     `debugfs -R "rdump /etc/sensors OUT"`（流水见 `reports/sensors-692-real-configs-20261127.md` §1）。
  3. **同一 boot 只能 attach 一次**：`hexagonrpcd -s` 正常退出后，DSP 侧的 default listener 槽位仍被占；
     再跑报 `Could not register ADSP default listener`（不是 DSP 坏，`qrtr-lookup | grep -c 400` 仍 =1）⇒ 要么重启设备，要么常驻别退。
- 另一个"会让服务自己退出"的点：DSP 会调 `fopen_with_env_fd`（method **36**，`sc=1f050100`），
  0.5.0 未实现 ⇒ 打印 `Unsupported method: 36` 并结束 `run_fastrpc_listener`（`alive=0`）。**不影响已 attach 的出数**，
  但 PD 重启后需要重新 attach ⇒ 要常驻就得把 34/35/36 也做假成功。
- 宿主侧两件老账仍然要做：`/etc/udev/rules.d/81-libssc-elden.rules`（`ssc-accel` 等，见 `#451`）+ `iio-sensor-proxy` 不要 masked。
- 验收判据（**别用 Orientation/Tilt**，常态 `undefined`）：`busctl get-property … HasAccelerometer|HasAmbientLight|HasProximity` 三 true，
  外加 `ssccli --sensor accelerometer` 连续出值（Z≈9.5 m/s²）。
- 全账：`reports/sensors-ssc-restored-20261127.md`（含 5 步可复现命令）。
