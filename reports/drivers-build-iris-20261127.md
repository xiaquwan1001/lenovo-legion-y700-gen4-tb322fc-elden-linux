# 驱动补完轮：审计结论 + 编译配置 + iris 上机（2026-11-27 下午）

- 性质：主机侧编译 + 设备只读审计 + 3 次 `fastboot boot`（零写盘）实验；设备最终已回到 vk192 正常态。
- 关联：`reports/driver-upstream-audit-20261127.md`（上游化四列结论）、`reports/driver-gap-device-audit-20261127.md`（设备侧缺口枚举）、
  `reports/hwdec-iris-sm8750-feasibility-20261127.md`（iris 备料）。

---

## §0 一页结论

| 项 | 结果 |
|---|---|
| **驱动的真缺口** | **只有 6 类**（都不是「相机/显示/音频」那类大件）：`qcom_trng`、`qce`(crypto)、`ctcu`、coresight `tpdm/tnoc`（22 个 amba 节点无驱动）、`st21nfca`(NFC，DT 里 `i2c@a80000` 仍 disabled)、边缘 `gunyah-wdt`/`qcom_edac`。**相机不是缺口**：6 个相机模块开机全部加载成功（dmesg `done: 1 media, 17 video nodes`），当前 `/dev/video*` 为 0 是 `cam-mode-off.service`（防 Q24 掉电）主动卸载的策略态。GPU 的 `3d37000.gmu` 无 driver 是上游正常形态（`[drm] Loaded GMU firmware v5.1.25`）。 |
| **可模块化** | 现状 31 个模块、1510 个 `.ko` 在树；真正可「按需加载」的增量在下表 §2。相机栈（camss/cci/camcc/flash/regulator）**已经是模块**；`DRM_MSM`/`ATH12K`/`WCD939X` 是 built-in（开机即需，不建议改 `=m`，会动到显示/WiFi 早起）。 |
| **可上游化** | 相机 `qcom,sm8750-camss` 在主线**没有**（`camss.c` 里 `sm8750` 命中 0、binding `media/qcom,sm8750-camss.yaml` 404）⇒ 我方相机栈属「树外补齐」，是最大的一块上游化工作；iris / soundwire / mpss-pas / geni-hub 都是**纯板级 DT 覆盖**形态（binding 已在主线）。详见审计报告。 |
| **编译配置（本轮已落地）** | `CONFIG_DEBUG_INFO_NONE=y`（原 `DEBUG_INFO=y` + `DWARF5`）⇒ **`vmlinux` 686 MB → 81 MB**（8.4×）、`Image.gz` 21.05 MB 基本不变；全量重编 `Image.gz + dtbs + modules` 在 `-j6` 下约 **15 min**（ccache 命中 22%）。 |
| **iris 上机** | 固件已装设备（`/lib/firmware/qcom/vpu/vpu35_p4.mbn`，signed vpu35_4v）；**三次 RAM 启动实验都没拿到「iris probe + 显示正常」的阳性样本**，失败现场已定位到「RAM 启动落到 initramfs shell」，不是 iris 本身（见 §4）。 |

---

## §1 本轮编译配置改动（可复现）

```bash
cd build/daily
./scripts/config --file .config -d DEBUG_INFO -e DEBUG_INFO_NONE -d DEBUG_INFO_DWARF5 -d GDB_SCRIPTS
# 备份：out/.config-daily-<ts>（改动前）
bash scripts/build-kernel.sh dtbs            # 2.7 s
JOBS=6 bash scripts/build-kernel.sh Image.gz dtbs modules   # ~15 min
# 产物：Image.gz 21,054,770 B / vmlinux 81,347,888 B / qcom-iris.ko 238,952 B / DTB 153,085 B
```
> ⚠️ `build-kernel.sh` 的 `JOBS` 默认是 `nproc`（本机 28）。**必须显式 `JOBS=<slot>`**，否则会绕过 `build-slot` 预算（本轮第一次跑就撞到 `-j28` + 101 个 gcc，已中止重来）。

## §2 模块化建议（不阻塞，供决策）

| 候选 | 现状 | 建议 |
|---|---|---|
| 相机栈（`VIDEO_QCOM_CAMSS`/`I2C_QCOM_CCI`/`QCOM_CAMCC`/`LEDS_QCOM_FLASH`/`REGULATOR_WL2868C`） | 已是 `=m`，开机 9.0–9.26 s 全加载 | 保持；`cam-mode-off.service` 需要时再装 |
| `qcom_iris` | `=m`（本轮无变化） | 保持 `=m`：**节点 enable 但模块不加载 = 零风险**，要测再 `modprobe`（本轮实验的教训） |
| `qcom_trng` / `qce` / `ctcu` | 配置里 **not set**（`HW_RANDOM_QCOM`/`CRYPTO_DEV_QCE`/`CORESIGHT_CTCU`） | 若要补，先确认「有消费者」：`smccc_trng` 已兜底随机数、无加密加速需求 ⇒ **低优先**，可作纯模块实验 |
| `DRM_MSM` / `ATH12K` / `WCD939X` | built-in | **不要改 `=m`**：显示/WiFi/音频都要求开机即起，改模块会把时序风险搬进 initramfs |

## §3 校验（本轮判据）

- `scripts/build-kernel.sh` 符号守卫：`gcc_sm8750 / DSI bonded / rpmh present` ⇒ OK。
- 设备侧模块部署：`scripts/deploy-modules.sh --from build/daily`（`DEPLOY_ANY_UTS=1`）⇒ `installed (atomic swap)`、`verify: local=1500 device=1500 sample_sha_ok=1`。
- 串口仲裁（本轮新增）：`scripts/serial-console.sh {tail|send|attach}` + udev 规则 `99-elden-serial-mm-ignore.rules`（`1d6b:0104` / `ttyACM*` ⇒ `ID_MM_DEVICE_IGNORE`）。

## §4 iris 上机实验（三次，全部 `fastboot boot` 零写盘）

| # | 镜像 | 内核 | DTB | 现场 |
|---|---|---|---|---|
| 1 | `vk193-iris` | **本轮新编**（build/daily, `g4da9a8b69fc8-dirty`, DEBUG_INFO_NONE） | 同树（iris okay） | **串口零输出**（连 kernel banner 都没有）⇒ 内核在 console 起来前就死了 |
| 2 | `vk194-iris-dtbonly` | vk192 原件 | build/daily 的 DTB（iris okay，但另含 3 处与 vk192 不同：ramoops 0x400000/0x200000、缺 `qcom,non-secure-domain`、2 个相机 iommu streamid） | 起来了但**落 initramfs shell**（`~ #`），根分区没挂上 |
| 3 | （未上机）`vk195` | vk192 原件 | **vk192 的 DTB 反编译后只改 iris status**（差异 2 行 ⇒ 单变量） | 已备好，因连续两次失败+需要人工断电，本轮没再发 |

**已确认与 iris 无关的两条**：
1. 实验 2 里我先加了 `/etc/modprobe.d/elden-blacklist-iris.conf`（`blacklist qcom-iris`）⇒ iris 驱动根本没加载，**仍然黑屏落 shell** ⇒ 失败不在 iris probe。
2. 事后从 initramfs shell 里 `e2fsck -y /dev/sda17` = **clean**，`fstab` 的根是 `rw,noatime`，`/etc/elden-init-mode` = systemd ⇒ 不是文件系统腐坏。

**失败形态（实验 2）**：串口日志顺序 = `[init] probe finished` → `/bin/sh: syntax error: unexpected ")"` → `~ #`；缺少正常启动必有的 `[init] DBG mount start: dev=/dev/sda17 …` ⇒ **根 label 解析没走成功路径**，落到了 fallback 分支（fallback 分支里有个脚本语法错误，直接把 shell 顶出来）。

**产物留档**：`out/hwdec-iris-20261127/dtb-iris-enabled-vk192base.dtb`（单变量 DTB，153 125 B）。没有留下任何镜像文件（实验镜像已删，避免 vk 版本账留垃圾号）；重建方法：
```bash
python3 - <<'PY'
from pathlib import Path
from importlib.machinery import SourceFileLoader
mk=SourceFileLoader("mkbootimg","scripts/mkbootimg.py").load_module()
d,sec,f=mk.read_image("out/boot-elden-vk192.img")
dt=Path("out/hwdec-iris-20261127/dtb-iris-enabled-vk192base.dtb").read_bytes()
Path("out/boot-elden-vk195-iris.img").write_bytes(mk.compose(
  page=f["page"],kernel_data=sec["kernel"],ramdisk_data=sec["ramdisk"],second_data=sec["second"],
  recovery_data=sec["recovery"],dtb_data=dt,kernel_addr=f["kernel_addr"],ramdisk_addr=f["ramdisk_addr"],
  second_addr=f["second_addr"],tags_addr=f["tags_addr"],dtb_addr=f["dtb_addr"],cmdline=f["cmdline"],
  extra_cmdline=f["extra_cmdline"],name=f["name"],header_version=f["header_version"],
  os_version=f["os_version"],recovery_dtbo_offset=f["recovery_dtbo_offset"]))
PY
```

## §5 下一步（按代价排序）

1. **先修 initramfs 的 root 解析/fallback 语法错**（这是反复黑屏的真凶，且在 RAM 启动路径上）：
   判据 = `bash -n initramfs/init` + 在 QEMU 链上跑到 `[init] DBG mount start`（`scripts/qemu-full-chain-smoke.sh`，单轮 ~35 s，不用上机）。
2. 用 vk195（单变量 DTB）做**一次** `fastboot boot`，串口侧用 `scripts/serial-console.sh tail -f` 盯着；若再落 shell，现场可直接读。
3. iris 阳性后再谈「补 6 类真缺口」与「相机栈上游化」（后者是 §7 M 系列量级的工作）。

## §6 收尾备注（WARN 归类，2026-11-27）

`check-doctor` 现存 **FAIL=0 / WARN=4**，逐条归类：

| WARN | 归类 |
|---|---|
| 源树不可核（67 行身份暂不可核） | **已登记豁免（C 类存量）**：`geekidos-linux/` 不在盘，逐行见 `versions/kernel-src-archive.tsv` |
| 账本已登记的例外（`uts_dup*`） | **已登记豁免**：`versions/vk-ledger-known-issues.tsv` |
| 内核身份表降级一致（C=2） | 同第一条（同一根的派生显示） |
| `build/daily/vmlinux 取不到 of_node 偏移（pahole 无该成员？）` | **本轮修的副作用（预期）**：`CONFIG_DEBUG_INFO_NONE` 后 vmlinux 无 DWARF ⇒ pahole 读不到结构体偏移。判据 = 要这份偏移就临时编 debug 版，或改用 BTF（`DEBUG_INFO_BTF=y` 只留类型信息，体积远小于 DWARF）。**不是缺陷**，已在报告登记 |
