# reboot2 退役 + Coresight 两处上游缺陷（已投）+ vk196 持久化部署 — 2026-11-27

> lane：父会话（用户三项指令：①`reboot2` 过时开关检查并禁用 ②CTCU 缺 `MODULE_DEVICE_TABLE` 报上游 ③持久化部署新内核）
> 结论先行：**三件全部完成**；两处上游缺陷各成一个 v1 系列，**3/3 × 250 已投**；设备已从 `boot_b` 持久跑 vk196，
> 且**不靠 `modules-load.d` 兜底**就能自动加载 CTCU/TPDA。

## §0 一页账

| 项 | 结果 | 判据 |
|---|---|---|
| `reboot2` | ✅ 已退役：真件留档 + PATH 上换 810 B 拒绝壳（`rc=1`） | `reboot2; echo rc=$?` → `rc=1`；真件 sha256 `0c68ee5f…`；`scripts/retire-reboot2.sh` 幂等 |
| 上游缺陷 A（CTCU/TPDA 缺 `MODULE_DEVICE_TABLE`） | ✅ **v1 已投**（`[PATCH 0/2]`，3 × 250） | MID `<20261127113137.931578-1-…>`；checkpatch 0E/0W/0C；真机 alias + 自动加载 |
| 上游缺陷 B（SM8750 TNOC 缺 periphid，连带 binding 缺口） | ✅ **v1 已投**（`[PATCH 0/2]`，3 × 250） | MID `<20261127113158.932414-1-…>`；dtbs_check/dt_binding_check/checkpatch 全绿 |
| 持久化部署 | ✅ `boot_b` = vk196（payload 与已验 vk195 逐字节同） | `uname -r` = `…-g4da9a8b69fc8-dirty`；`qbootctl`：`_b Active=1 Successful=1 Bootable=1`；回滚件在 `bootslot-b/` |
| 回归 | ✅ 显示 / WiFi / 音频 / 相机 / 输入 / ADSP+CDSP / TRNG 全绿 | 见 §4 |

## §1 `reboot2`：为什么「写进文档」不够

- 上一轮踩坑现场（`PITFALLS #368/#542` 已写停用，仍踩）：`ssh elden-root 'sudo -n reboot2'` ⇒ USB 全不枚举 +
  用户看到 phosh 起来后整机卡死，需长按电源。
- 根因：`/usr/local/sbin/reboot2` 一直是**可用的 ELF**（709 368 B，sha256 `0c68ee5f…`），文档门槛挡不住手滑。
- 处置（`scripts/retire-reboot2.sh`，幂等、带 device-lock）：
  真件 → `/var/lib/elden/retired/reboot2-20261127`（+ `.sha256`）与 `/usr/local/sbin/reboot2.retired-20261127`；
  PATH 上留 **拒绝壳**（打印 `systemctl reboot --reboot-argument=bootloader`，`rc=1`）。
- 坑：`rootfs/build-overlay.sh` / `build-rootfs.sh` / `configure-ubuntu.sh` 都会用 `rootfs/reboot2.c` 重装真件
  ⇒ **rootfs/镜像重建后必须重跑本脚本**（已写入脚本头与 `PITFALLS #749`）。

## §2 上游缺陷 A：CTCU / TPDA 缺 `MODULE_DEVICE_TABLE`

用户在审计里指出：`ctcu_match` 只有 `qcom,sa8775p-ctcu`（SM8750 的 `qcom,sm8750-ctcu` 作为第二 compatible
回退命中），且驱动 `=m` 但**没有**导出该表。实测（vk194/vk195，同一台机）：

```
$ lsmod | grep -c coresight_ctcu          # 0（开机从不加载）
$ modinfo -F alias coresight-ctcu         # 空
$ sudo modprobe coresight-ctcu && readlink -f /sys/bus/platform/devices/10001000.ctcu/driver
.../drivers/coresight-ctcu                # 手动加载后立即绑定
$ modinfo -F alias coresight-tpda         # 空（5 个 tpda 节点同理）
```

补丁后（vk196 构建 + 部署）：

```
$ modinfo -F alias coresight-ctcu         # of:N*T*Cqcom,sa8775p-ctcu （+ C* 变体）
$ modinfo -F alias coresight-tpda         # amba:d???F0F??
$ modprobe -S <UTS> -R 'of:N*T*Cqcom,sa8775p-ctcu'   # coresight_ctcu
$ modprobe -S <UTS> -R 'amba:d???F0F??'              # coresight_tpda
```

**上游件**：`patches/upstream/coresight-moduletable-20261127/`（v1-0000..0002 + GATES.md + SEND.sh）。
`build/daily` 工作区已 apply；上游 7.4-rc3（`build/elden-tree`）同样缺这两行。
dup-check：patchwork `linux-arm-kernel`(62)/`linux-arm-msm`(92) 搜 `ctcu`/`tpda` 未见同类 `MODULE_DEVICE_TABLE` 投递。

> 「driver 不是 builtin」这点确认：`CONFIG_CORESIGHT_{CTCU,TPDA}=m`（配置批刻意全 `=m`，不把开机时序风险
> 搬进 early boot）⇒ 缺 alias 就是**静默不加载**，而不是「编进内核所以没事」。修法选**补宏**而不是改 `=y`：
> 前者是上游缺陷的正解，后者只是掩盖。

## §3 上游缺陷 B：SM8750 TNOC 缺 `arm,primecell-periphid`（连带 binding）

- 现象：`/sys/bus/amba/devices/109ab000.tn/uevent` 里 `AMBA_ID=00000000` ⇒ `coresight-tnoc` 的
  `trace_noc_ids`（`0x000f0c00/0x001f0c00, mask 0x00ffff00`）永不匹配；dmesg 只有
  `deferred probe pending: (reason unknown)`。
- 只改 DTS **过不了门**：`qcom,coresight-tnoc.yaml` 根 `additionalProperties: false` 且没引用 PrimeCell schema
  ⇒ `dtbs_check` 报 `'arm,primecell-periphid' does not match any of the regexes`。所以系列 = binding + dts 两枚：
  1/2 加 `allOf: - $ref: /schemas/arm/primecell.yaml#`，根改 `unevaluatedProperties: false`；
  2/2 `tn@109ab000` 加 `arm,primecell-periphid = <0x000f0c00>;`。
- 门禁：`dtbs_check`（`sm8750-mtp.dtb` + `sm8750-qrd.dtb`）**无诊断**、`dt_binding_check` rc=0、
  `checkpatch --strict` 0E/0W/0C（命令与输出 = 该目录 `GATES.md`）。
- 上机：`readlink /sys/bus/amba/devices/109ab000.tn/driver` → `coresight-trace-noc`；AMBA 未绑定 **0/28**。
- 上游件：`patches/upstream/sm8750-tnoc-periphid-20261127/`。`kaanapali.dtsi:5134` 同型缺口留作后续。
- 本机树里保留了带中文证据注释的版本（`build/daily` 工作区）；发件版本去掉了本地注释，只留属性（GATES 有记）。

## §4 vk196 持久化部署（首次写盘）

- 载荷：`Image.gz` = `9728a751…`、DTB = `ce27003e…`、boot img sha = `d702a93f…`，与已上机验收的 vk195 **逐字节相同**
  （本轮只改了 2 个 coresight 源文件，属 `=m` 模块，不进 boot.img）。`out/boot-elden-vk196.img` 由
  `VERSION=vk196 KDIR=build/daily RAMDISK=out/ramdisk-vk181-working.cpio.gz bash scripts/build-boot.sh` 重打，sha 不变。
- 模块：`DEPLOY_ANY_UTS=1 bash scripts/deploy-modules.sh --from build/daily` → `verify: local=1505 device=1505 sample_sha_ok=1`。
- QEMU 全链：`bash scripts/qemu-full-chain-smoke.sh build/daily/arch/arm64/boot/Image` → **4/4 PASS**（12 s）。
- 写盘：`bash scripts/flash-b.sh out/boot-elden-vk196.img --reboot`
  - 写前备份设备 `boot_b` → `bootslot-b/boot_b-device-20261127-vk192.img`（sha `68d3dc46…`，与 `bootslot-b/boot_img` 一致）
  - 重签（`bootslot-b/avb.key`）→ dd → 读回 sha `0ccbf906…`（签名后 96 MiB）一致 → sysrq-b 重启
- 重启后判据（同一发）：

```
uname -r                    → 7.3.1-debug-vk189-suspend-g4da9a8b69fc8-dirty
lsmod | grep -E 'coresight_(ctcu|tpda|tpdm|tnoc)' → 4 个都在（**modules-load.d 已移走**）
/sys/bus/platform/devices/10001000.ctcu → coresight-ctcu
/sys/bus/amba/devices/109ab000.tn       → coresight-trace-noc
AMBA 未绑定                             → 0
rng_current=smccc_trng；10c3000.rng/driver → qcom_rng
card*-DSI-* connected = 1；wlan0 UP；Lenovo 声卡 2；/dev/video* 17；/dev/input/event* 9
remoteproc0/1 = running
qbootctl → _b Active=1 Successful=1 Bootable=1
```

- 兜底文件 `/etc/modules-load.d/elden-coresight.conf` 已移到 `/root/elden-coresight.conf.retired-20261127`
  （只有本缺陷会造成它存在；上游合入前若回滚内核需把它移回）。

## §5 投递记录

| 系列 | 封数 | 结果 | cover Message-ID |
|---|---|---|---|
| coresight MODULE_DEVICE_TABLE v1 | 3（cover+2） | 3 × `Result: 250` | `<20261127113137.931578-1-xiaqinghuan@mail.ustc.edu.cn>` |
| sm8750 TNOC periphid v1 | 3（cover+2） | 3 × `Result: 250` | `<20261127113158.932414-1-xiaqinghuan@mail.ustc.edu.cn>` |

- 发送日志：两目录 `logs/sent-20261127-*.txt`；`SENT.md` 已记。
- lore 复核：`https://lore.kernel.org/all/<MID>/` 目前 **403**（Anubis 反爬，已知口径：`/raw 200` 也不能当证据）；
  patchwork 摄取滞后，本轮查询未命中 ⇒ 下次会话按 MID 用 patchwork API + lore `/T/` 复核并回填。

## §6 回滚 / 现态

- 内核回滚：`bootslot-b/boot_b-device-20261127-vk192.img`（vk192，sha `68d3dc46…`）用 `flash-b.sh` 写回即可。
- `reboot2` 回滚：`mv /var/lib/elden/retired/reboot2-20261127 /usr/local/sbin/reboot2`。
- 设备现态：`boot_b` = vk196、槽属性 `_b` succ=1、桌面在跑；未触碰 Android `_a` 槽与其余分区。
