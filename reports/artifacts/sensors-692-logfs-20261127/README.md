# 2026-11-27 采集：ADSP PD/PDR 现态 + ABL logfs（sensors #692 后续 ① 的第一手判据）

采集时点：2026-11-27T06:0xZ（设备在线，在机 vk192 核 `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`，
boot_id `95f5a0fc-…`，开机于 2026-11-26 23:11:29 = #692 最后一次复位后的那次启动）。全部只读。

## 1. PD / PDR 现态（推翻 T6 后续① 的前提「PD 依赖没补齐」）

```
zcat /proc/config.gz | grep -iE 'PDR|PD_MAPPER|QCOM_QMI'
CONFIG_QCOM_PD_MAPPER=y
CONFIG_QCOM_PDR_HELPERS=y
CONFIG_QCOM_PDR_MSG=y
CONFIG_QCOM_QMI_HELPERS=y

dmesg | grep -iE 'pd.mapper|protection domain|PDR'
[    1.242493] PDR: Indication received from msm/adsp/charger_pd, state: 0x1fffffff, trans-id: 1
[    1.251685] PDR: Indication received from msm/adsp/audio_pd, state: 0x1fffffff, trans-id: 1

ls /sys/bus/auxiliary/drivers/
qcom_pd_mapper.qcom-pdm-mapper        # PD mapper 驱动已加载

/proc/device-tree/soc@0/remoteproc@6800000/  (= adsp, qcom,sm8750-adsp-pas)
power-domain-names = lcx lmx          # RPMh 负载态（不是 PD）
glink-edge / qcom,qmp / qcom,smem-states 齐备
```

结论：**mainline 这一侧 PD mapper + PDR 全在跑**，ADSP 固件也确实通告了 `audio_pd` 与 `charger_pd`
两个保护域（启动 1.2 s 就收到 state=UP 指示），并按之起了 APR/GPR 客户端
（`Adding APR/GPR dev: gprsvc:service:2:3` / `2:7`）。
⇒ T6「后续① 补齐 ADSP 的 PD 依赖」中的**能力层不缺**；缺的只可能是**顺序**（rproc stop 前没有逐个 PD 的
shutdown 握手），这需要看驱动侧，见 `reports/sensors-adsp-pd-pdr-20261127.md`。

## 2. ABL logfs（`/dev/sde68`，8 MiB，sha256 f3d98a3b…）

`ssh elden-root 'dd if=/dev/sde68 bs=1M count=8'` → `logfs-sde68.img`（本目录）。
`scripts/logfs-decode.py --tsv` 摘要：

| seg | reset_by | reset_type | pon | slot |
|---|---|---|---|---|
| 0 | PSHOLD | Hard Reset | (空) | **_b** |
| 1–9 | PSHOLD | Hard Reset | SYSOK | _a |

- **seg0 = 23:11:29 那次启动**（= #692 最后复位后的回落启动），ABL 记的上一发复位 = `Reset by PSHOLD` /
  `Hard Reset`。按 `PITFALLS #184/#182`，**该字段只说明「AP 侧 PS_HOLD 被拉低」，与正常重启同款，
  不能据此判根因** ⇒ 本次采集**不构成**「谁拉低了 PS_HOLD」的证据。
- seg1–9 是 `_a`（stock Android 期）、VBAT 3.9–4.0 V 的陈旧段，被本段覆盖前遗留。
- **新增事实（判据纠偏）**：该机的 `UEFILOG1.TXT` FAT 目录项 size = **65536（= 1 段 64 KiB）**，
  即当前固件**只留最近一次启动**；`reports/uefi-observability-pivot-20261101.md` §1.1 的「10 段环形可回溯」
  在本机现态下**不成立**（10 段里 9 段是陈旧残留，顺序/时效不可依赖）。要拿「崩的那一发」的 ABL 记录，
  必须在复位后第一发就去读，不能事后回溯。

## 3. V1/V2 只读判据（lane 报告 §8 提出的「PD 链路是否完整」）

```
cat /proc/asound/cards
 0 [LenovoY700Gen4 ]: sm8750 - Lenovo-Y700-Gen4          # 声卡已注册 ⇒ audio_pd 有活客户端
dmesg | grep -E 'Adding APR/GPR dev'
 qcom,apr 6800000.remoteproc:…: Adding APR/GPR dev: gprsvc:service:2:3   # q6apm
 qcom,apr 6800000.remoteproc:…: Adding APR/GPR dev: gprsvc:service:2:7   # q6prm
```
⇒ **PD 链路四件齐全**：pd-mapper 在跑 → ADSP 通告 audio_pd/charger_pd（PDR UP）→ GPR 服务注册 →
`q6apm` 绑上（声卡 `card0` 存在）。即「PD 依赖没补齐」这条前提在本机**实测不成立**。

旁注（本轮顺带看到，未深挖）：`qcom-apm gprsvc:service:2:3: CMD timeout for [1001021] opcode`（开机 6.4 s）
—— 上机音频功能此前已被用户实测判 ✅，故记为「非阻塞现象」，若将来查音频再回溯这条。
