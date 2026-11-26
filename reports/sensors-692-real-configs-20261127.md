# `#692` 突破：换上**真 vendor sensor 配置**后，`-s` 不再复位整机（ADSP 存活）

> 2026-11-27 无人值守轮续。本轮把「取真配置」做成了：官方 ROM 的 `super` 8 段落按 `rawprogram*.xml` 稀疏拼回 → `lpunpack` →
> `debugfs` 抽 `/etc/sensors`。**trial6/trial7 两次 `-s` 都没有复位**（boot_id 不变、`remoteproc0=running`）。

## 0. 结论（四条）

1. **复位链被切断**：`droid-juicer` 抽出的配置是 0 字节占位（上一轮实测）时，DSP 必断言 ⇒ 整机复位；
   换成真配置后（trial6）DSP **不再断言**，ADSP 一直 `running`。⇒ `#692` 的"整机复位"是**空配置 ⇒ DSP 断言 ⇒ SSR ⇒ 板级复位**这条链的最后一环，**配置一真就消失**。
2. **`-R` 树必须按 0.5.0 的扁平布局**（`<R>/sensors/{config,registry,sns_reg.conf}`、`<R>/dsp/<dsp>`），本轮已建 `/var/lib/hrpcd-root`：
   `config/`（139 个真 json，808 KB）、`sns_reg.conf`（271 B，真内容 `version=1 / file=input=json.lst / file=output=…`）、`registry/`（蹭 droid-juicer 的 343 条 0 字节骨架）。
3. **trial6 的失败点已具体化**（都不致命、无复位）：
   - `Could not open oemconfig.so` —— 该文件在 `vendor` 全盘（含 `/lib/rfsa/adsp`）**不存在**，判断为可选；
   - `Opening …/registry/registry/DIR for writing (writes are discarded)` 后紧接 `Could not open … DIR: No such file or directory`
     ⇒ 我们的「假写」只放开了 `fopen`，**hexagonfs 后端仍拒绝非只读打开**（真写后端还没做）；
   - 7 个 `Could not open /vendor/etc/sensors/config/<name>.json`（`qsh_ble`、`sns_amd_sw_disabled`、`sns_presence_detect`、
     `sns_tilt_sw_disabled`、`qsh_camera_imx688_4`…）—— 这些在 ROM 的 `vendor`/`odm`/`product`/`system_ext` 里**都没有**，
     `qsh_camera` 只有 `_6` 版本 ⇒ 判断为 ROM 自身也不提供的可选配置。
4. **trial7 的新现象**：`Could not register ADSP default listener` 后立即退出（alive=0）—— 上一发的 listener 还没被 ADSP 释放
   （同一 boot 内二次 attach），**不是** DSP 故障：`qrtr-lookup | grep -c 400` 仍 = 1、ADSP `running`。⇒ 试验协议要加一条：**同一 boot 内只跑一次 attach**，或先等/重启。

## 1. 本轮做成的取数流水（可复制，纯主机侧）

官方 ROM 的 `super` 不是顺序切片，而是 `rawprogram_save_persist_unsparse0.xml` 里 **8 段带 start_sector**（4 KiB 扇区）的 used-extent：

```sh
# 1) 稀疏拼回（super 起始 = sector 90504，与设备 /sys/class/block/sda10/start=724032×512 一致）
truncate -s 23622320128 out/vendor-extract-20261127/super.img
for each (fn,start,n) in xml:  # 相对偏移 = (start-90504)*4096
  dd if=backup/official-rom-15.10.259/$fn of=super.img bs=1M oflag=seek_bytes seek=$rel conv=notrunc status=none
# 2) 抽分区（vendor_a 1.5 GB；odm/system/system_ext/product 也一并抽了）
~/bin/lpunpack -p vendor_a out/vendor-extract-20261127/super.img out/vendor-extract-20261127/
# 3) 取文件（vendor 是 ext4）
mkdir -p etc-sensors && debugfs -R "rdump /etc/sensors etc-sensors" vendor_a.img
```
产物：`out/vendor-extract-20261127/{super.img,vendor_a.img,odm_a.img,system_a.img,system_ext_a.img,product_a.img,etc-sensors/}`（**本地，未入库**）。

## 2. 判据现状（三态）

| 判据 | 结果 |
|---|---|
| DSP 断言 / 整机复位 | **消失**（trial6：`PDM … crash` 0 条、boot_id 不变） |
| `hexagonrpcd` 常驻服务 DSP | ❌ 进程在 ~10 s 后自行退出（`alive=0`），原因未查（可能是 listener 生命周期；需要 `-s` 后保持的机制） |
| 传感器出数（`HasAccelerometer` 等） | 未测：**宿主侧还缺 udev 规则** `/etc/udev/rules.d/81-libssc-elden.rules`（现在只有 3 条规则，`ssc-accel` 无人打），且 `iio-sensor-proxy` 被 masked（`PITFALLS #451/#453` 的老账） |

## 3. 下一步（T13 重写）

1. **真写后端**（唯一功能缺口）：`hexagonfs_mapped` 只读；把 `/persist/sensors/registry` 迁到可写目录（copy-on-write 到 `/var/lib/hexagonrpc/`），
   实现 `fwrite/ftrunc/fremove/frename/mkdir/rmdir/fsync`。上游 #29 的 ~700 行方案是参考；PR #21 只 stub。
   产出后 DSP 才能把 registry 落盘（现在那份 343 条是 0 字节骨架）。
2. **`hexagonrpcd` 的生命周期**：查清 `-s` 之后为何退出（`data/hexagonrpcd-adsp-sensorspd.service.in` 是 `Type=simple` 常驻；直接跑就退出，说明 attach 一次即结束）。
   ⇒ 若设计如此，宿主侧应配成 **oneshot + DSP 侧自行运行**，与 Android 的 `sensors@` HAL 语义一致。
3. **宿主侧接线**：`81-libssc-elden.rules`（`ssc-accel ssc-proximity ssc-light ssc-compass` + `ACCEL_MOUNT_MATRIX`）+ `iio-sensor-proxy` 挂 `graphical.target`（`#451/#453` 全套）。
4. 之后才谈「传感器可用」与 `TASKS/G1-34` 的收口。

## 4. 设备现态

`boot_id 887f62f8…`（本轮 trial6/7 **没有再复位**）、`--failed`=0、两 rproc `running`、`hexagonrpcd` 服务仍 masked；
`/var/lib/hrpcd-root/` = 0.5.0 扁平试验树（真 config + 真 sns_reg.conf + 0 字节 registry 骨架）。
