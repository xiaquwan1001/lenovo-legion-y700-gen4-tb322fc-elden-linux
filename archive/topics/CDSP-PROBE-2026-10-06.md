# G1-11 CDSP 取证 — 未起来（`-22` @ SCM dtb pas）（2026-10-06 深夜）

> 过程证据（archive，只增不改）；结论口径以 `TASKS.md` G1-11 为准。
> 背景：文档曾记 vkD2-cdsponly「零写盘正常启动、设备侧已启动、待 remoteproc1 取证」。
> 本次上机独立复核 **推翻了该口径**。

---

## 0. 结论（数字）

- **CDSP `state=offline`**，未起来。`cdsp.mbn`（主固件）**装载成功**，但紧随其后
  `qcom/sm8750/cdsp_dtb.mbn` 报 **`-22` (EINVAL)**，`remoteproc1: Failed to load program segments: -22`。
- 对照：同一 boot 的 **ADSP `state=running`**（用 split `adsp_dtb.mdt`+`.b00/b01/b02`，正常）。
- 错误点在 `drivers/soc/qcom/mdt_loader.c:278` 的 `qcom_scm_pas_init_image(dtb_pas_id, metadata)`
  —— **SCM 拒绝 DTB 的 metadata**，不是文件没找到、不是主固件问题。

## 1. 复现

```
ssh root@192.168.7.1 'setsid /usr/local/sbin/reboot2 bootloader'
fastboot boot out/boot-elden-vkD2-cdsponly.img      # kernel 7.2.0-debug-g2b5badef00fb (vk53-hw)
ssh root@192.168.7.1 'cat /sys/class/remoteproc/remoteproc1/state'   # -> offline
```

dmesg：

```
[1.196] remoteproc remoteproc1: powering up cdsp
[1.198] remoteproc remoteproc1: Booting fw image qcom/sm8750/cdsp.mbn, size 3920296
[1.200] qcom_q6v5_pas 32300000.remoteproc: error -22 initializing firmware qcom/sm8750/cdsp_dtb.mbn
```
（注：即便 `remoteproc1` 事后 `unbind` 再 `bind`，也因 reserved-mem 未回收而 `assign memory 0 failed -22`
⇒ 必须冷启动才能重试。）

## 2. 已做的对照实验（都排除）

| 假设 | 实验 | 结果 |
|---|---|---|
| 固件文件缺失/名字错 | 设备 `/lib/firmware/qcom/sm8750/` 有 `cdsp_dtb.mbn.zst`（内核自动解压） | cdsp.mbn 能装载 ⇒ 路径/解压 OK |
| 应为 vendor **split** 格式 | 部署 vendor `cdsp_dtb.mdt`+`.b00/b01/b02`（adsp 同款 split 才成功），命名成 `cdsp_dtb.mbn` 覆盖，冷启动 | **仍 `-22`** ⇒ 与文件格式/命名无关 |
| DTB 该不该单独 load | 驱动逻辑：`dtb_pas_id` 仅当 DT 有第二个 firmware-name 时启用 | 见下方假设 |

## 3. 剩余假设（未验证）

- **`dtb_pas_id` 不匹配**：sm8750 cdsp 走 `compatible = "qcom,sm8650-cdsp-pas"` ⇒ 复用
  `sm8650_cdsp_resource`，其 `dtb_pas_id = 0x25`。SM8750 的 TZ 可能对 cdsp DTB 用**不同 PAS id**
  （mainline 无 sm8750 专属 cdsp 资源；对照 sm8750 adsp 复用 `sm8550-adsp-pas`）。`qcom_scm_pas_init_image`
  正是「无效 PAS/metadata」才回 `-EINVAL`。
- 或：SM8750 的 CDSP DTB **不应单独 PAS 加载**（应随主固件），即 DT 去掉第二个 firmware-name、
  让 `dtb_pas_id=0` 跳过该路径。
- 二者都需**改 DT 重建**（当前未做；`remoteproc1` 的 `region_assign`/`pas_ctx` 无 DT 覆盖点）。

## 4. 处置

- G1-11 由「✅ 设备侧已启动」更正为 **🟡 未起来（CDSP `-22`，PAS id 待定）**；非主线阻塞项。
- 设备固件现场已**恢复原状**（`cdsp_dtb.mbn.zst` 复位，vendor split 文件移除）。
- 后续最小实验：DT 去掉 cdsp 的 dtb firmware-name → 冷启看 `cdsp.mbn` 能否单独 running；
  若可，则 CDSP 可用、无需 DTB；若不可，再试枚举 `dtb_pas_id`。

---

## 5. 后续更正（2026-10-07，追加；本文 §3「PAS id 待定」假设已被否证）

本文不是终局。2026-10-07 复排并修好 CDSP，结论改写：
- **「dtb_pas_id 不匹配」假设否证**：反汇编 stock `qcom_q6v5_pas.ko` 的 `sun_cdsp_resource`
  → pas_id=18 / dtb_pas_id=0x25，与主线 `sm8650_cdsp_resource` 完全一致。
- **真根因 = 固件变体 + 载具**：DTS 用非 stock 单文件 `cdsp_dtb.mbn`（被 TZ 拒 `-22`），
  且固件由 initramfs 加载（磁盘副本不生效）。改用 stock **split** `cdsp.mdt`/`cdsp_dtb.mdt`
  并注入 initramfs 后 `remoteproc1 state=running`。
- 详见 **`CDSP-FIX-2026-10-07.md`**、`PITFALLS` #127、`TASKS.md` G1-11。
