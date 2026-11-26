# `#692` 又推进两层：`-R` 文件树布局对上了，但**给 DSP 的 sensor config/registry 全是 0 字节占位**（+ 一条会毁掉二进制的采集坑）

> 2026-11-27 无人值守轮续（T13）。本轮 3 发上机（trial3/4/5），共 2 次整机复位；全部零写盘、自动回 `boot_b`。
> 产物：`reports/artifacts/sensors-692-attach-crash-20261127/serial-trial{4,5}.txt`。

## 0. 三条新结论

1. **`hexagonrpcd` 0.5.0 与 droid-juicer 准备的 `-R` 树布局不一致**（这是 trial4 的 `No such file or directory` 真因）。
   0.5.0 的 `rpcd_builder.c` 常量是**扁平**的：`<R>/sensors/config/`、`<R>/sensors/registry/`、`<R>/sensors/sns_reg.conf`、`<R>/acdb/`、`<R>/dsp/<dsp>/`、`<R>/socinfo/`；
   而 Debian wrapper 默认 `-R /var/lib/droid-juicer/sensors/` 里的树是 **Android 布局**：`vendor/etc/sensors/…` + `mnt/vendor/persist/sensors/…`。
   ⇒ 按 0.5.0 布局重建 `<R>` 后（trial5），文件服务**正常应答**了：`openat($ADSP_LIBRARY_PATH, /vendor/etc/sensors/sns_reg_config, r) -> 2`、`stat(.../config/json.lst)` 都不再报错。
2. **但 DSP 仍然断言**（`sns_registry_sensor.c:309`）——真因浮出来：**droid-juicer 抽出来的 sensor 配置/registry 几乎全是 0 字节占位**：
   `vendor/etc/sensors/sns_reg_config` = **0 B**、`sns_odp_config` = 0 B、`config/json.lst` = **0 B**、`config/` 139 个文件里**只有 1 个非空**；
   `registry/`（343 项）同样**只有 1 个非空**（总 48 KB）。⇒ DSP 拿到空 registry 必炸，跟我们改不改 `fwrite` 无关。
   另 `oemconfig.so` 在整机任何地方都**不存在**（`find / -xdev` 0 命中），DSP 也会要它。
3. **一条会毁掉下发的坑（新 `PITFALLS #740`）**：`scp` 到设备的文件若在**硬复位前没落盘**，复位后**尺寸不变、内容全 0**
   （ext4 延迟分配）。本轮 `trial3` 就是这样：`/usr/local/bin/hexagonrpcd-v` 变成 68912 字节全 0 ⇒ `file` 报 `data`、
   执行报「可执行文件格式错误」、进程静默退出、**看起来像"程序跑不起来"**。判据：下发后 `sync` + `sha256sum` 对账。

## 1. 五发总表（本轮）

| 发 | `-R` | 结果 |
|---|---|---|
| 3 | droid-juicer 树 | **没跑起来**：二进制被上一条坑清零（`alive=0`、无输出、无复位）——当时误判为「无崩溃」 |
| 4 | droid-juicer 树 | 0.5.0 报 3 个 `Could not open`（`sns_reg_config`/`config/json.lst`/`oemconfig.so`）⇒ DSP 断言 ⇒ **整机复位** |
| 5 | 0.5.0 扁平树（本轮新建） | 文件服务**全绿**（`openat`/`stat` 都不报错），但 DSP 仍断言（拿到的是 0 字节 registry）⇒ **整机复位** |

## 2. 下一步（T13 修正后的攻击面，按序）

1. **取真配置**：`super` 分区的 Android `vendor` 里应有 `etc/sensors/**` 与 `persist/sensors/registry/**` 真本体。
   官方 ROM 备份在 `backup/official-rom-15.10.259/`：`super_1..8.img` 不是顺序切片，而是 `rawprogram*.xml` 里**带 start_sector 的 8 段**
   （例：`super_1` @90504×4096、`super_4` @345480×4096…）⇒ 先按 XML 把它们稀疏拼回 22 GB 的 `super.img`，
   再 `~/bin/lpunpack --partition vendor` 抽 `vendor.img`，最后 `erofsfuse`/`debugfs` 取 `etc/sensors/**`。
   （已核：`lpunpack` 在 `~/bin/lpunpack`，ELF x86-64 正常；`lpdump` 不在盘。）
2. 把真配置按 0.5.0 扁平布局放进 `/var/lib/hrpcd-root`（`sensors/config`、`sensors/sns_reg.conf`、**可写** `sensors/registry`、`dsp/adsp/`）。
3. 再上机一次；判据仍是三态（`qrtr 400` + `HasAccelerometer`）。
4. 若 DSP 还要 `oemconfig.so`：从同一 `vendor` 里取（属 sensor DSP 库），或确认它在 ADSP 固件体内。

## 3. 采集脚本（本轮已固化，可复制）

```sh
# 下发后必须 sync + 校验（坑 #740）
scp hexagond-rpcd-v elden-root:/usr/local/bin/ && ssh elden-root 'sync; sha256sum /usr/local/bin/hexagonrpcd-v'
# 试验（输出必须直接进串口；别用 nohup，见上一轮）
ssh elden-root 'setsid /usr/local/bin/hexagonrpcd-v -f /dev/fastrpc-adsp -d adsp -s -R /var/lib/hrpcd-root/ \
   </dev/null >/dev/ttyGS0 2>&1 &'
# 主机侧看现场
awk '/TRIAL/{f=1} f' /var/log/elden-serial/ttyACM0.log | head -20
```

## 4. 设备现态

`boot_id 887f62f8…`（trial5 复位后起）、`--failed`=0、两 rproc `running`、`hexagonrpcd` 服务仍 **masked**；
`/usr/local/bin/hexagonrpcd-{patched,v}` 已重新下发并 sha 校验；`/var/lib/hrpcd-root`（0.5.0 布局的试验树）留着待下一轮替换真配置。
