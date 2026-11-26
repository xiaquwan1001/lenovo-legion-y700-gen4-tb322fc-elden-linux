# 传感器 #692 后续① 收口：「补齐 ADSP 的 PD 依赖」不是主线缺口（lane 报告 + 父代理上机复核）

> 工单 = `reports/sensors-692-backport-test-20261126.md` §8.5 第 2 项（「给 ADSP 的 PD 依赖补齐（audio_pd/charger_pd 先 PDR 再 stop）」）。
> 执行：2026-11-27 无人值守轮。lane 调研（`researcher` @ `custom.ustc-pool/ustc-dsf2`，无 shell，行号靠 read 逐段核）+ **父代理独立重跑 + 上机只读采集**。
> 基线树 = `build/daily`（mainline 7.3.1，worktree `4da9a8b69fc8`）。

## 0. 结论（父代理复核后）

1. **「PD 依赖没补齐」不成立，且这不是主线缺口**：主线 PDR（`drivers/soc/qcom/pdr_interface.c`）+ in-kernel pd-mapper
   （`qcom_pd_mapper.c`，**`qcom,sm8750` 在第 665 行映射到 `sm8550_domains`**）都在，`audio_pd`/`charger_pd`/`sensor_pd` 都在表内；
   `sm8750.dtsi` 的 `q6apm`/`q6prm` 都带 `qcom,protection-domain = "avs/audio","msm/adsp/audio_pd"`（`:2366`/`:2384`）。
2. **上机只读实证（本轮新采，`reports/artifacts/sensors-692-logfs-20261127/`）**：本机 `CONFIG_QCOM_PD_MAPPER=y`、
   `CONFIG_QCOM_PDR_HELPERS=y`、`qcom_pd_mapper` aux 驱动已加载，启动 1.2 s 就收到
   `PDR: Indication received from msm/adsp/charger_pd`（`0x1fffffff`=UP）与 `msm/adsp/audio_pd`（同），
   并起了 `gprsvc:service:2:3/2:7` ⇒ **APSS 侧 PD 链路在本机是通的**（详见该目录 README §1）。
3. **主线 PDR 没有「关 PD」这个动作**：`include/linux/soc/qcom/pdr.h` 只有 4 个符号（`pdr_handle_alloc` /
   `pdr_add_lookup` / `pdr_restart_pd` / `pdr_handle_release`），`qcom_pas_stop()`（`qcom_q6v5_pas.c`）全程不碰 PD，
   而 pd-mapper 的注销（`pdm_notify_unprepare`）在 **stop 之后**才发生 ⇒ 工单设想的「先关 PD 再 stop」在主线模型里**没有落点**。
4. **同 SoC 反例（父代理已独立读原文）**：Xiaomi Pad 8 Pro（`piano`，SM8750、同一 `6800000.remoteproc`、mainline 7.2.10）
   `remoteproc0 state=stop` → `start` 可以执行且**整机不复位**，ADSP 崩溃走 rproc SSR 恢复，日志里还有
   `PDM: service 'qsh_process' crash: …`（= in-kernel pd-mapper 真机在跑）。该 issue = `yzddmr6/xiaomipad-8pro-mainline#3`（closed，2026-10-30）。
   ⇒ 「ADSP 一停就静默复位整机」是**本板/本机板级面**的性质，不是 SM8750 主线通性。
5. **动作裁决**：**不做**这个「PD 补齐」补丁（无可落地形态）；T6 的后续①改判为「已否证/不做」，复位面归到
   **PMIC/AOP/TZ（板级）**，下一步只用**零风险只读判据**（§8 的 V1/V2）+ 需要单独授权的一次二值对照（V3，仍禁用 `-s`）。

## 0.1 父代理独立复核（逐条重跑，非采信 lane 自述）

```
$ grep -n sm8750 drivers/soc/qcom/qcom_pd_mapper.c
665:	{ .compatible = "qcom,sm8750", .data = sm8550_domains, },
$ grep -n "^struct\|^int\|^void" include/linux/soc/qcom/pdr.h
21/24/27/28  → pdr_handle_alloc / pdr_add_lookup / pdr_restart_pd / pdr_handle_release   （无 stop/shutdown）
$ awk 'NR>=395&&NR<=450' drivers/remoteproc/qcom_q6v5_pas.c | grep -n pdr|pdm      → 0 命中
$ grep -n "qcom,protection-domain" arch/arm64/boot/dts/qcom/sm8750.dtsi
2366 / 2384   （q6apm / q6prm，均为 "avs/audio","msm/adsp/audio_pd"）
```

设备侧（只读，在机 vk192 核，boot_id `95f5a0fc…`）：

```
CONFIG_QCOM_PD_MAPPER=y / CONFIG_QCOM_PDR_HELPERS=y / CONFIG_QCOM_PDR_MSG=y
PDR: Indication received from msm/adsp/charger_pd, state: 0x1fffffff, trans-id: 1
PDR: Indication received from msm/adsp/audio_pd,    state: 0x1fffffff, trans-id: 1
/sys/bus/auxiliary/drivers/qcom_pd_mapper.qcom-pdm-mapper   （已加载）
remoteproc0=adsp running / remoteproc1=cdsp running
cat /proc/asound/cards → 0 [LenovoY700Gen4 ]: sm8750 - Lenovo-Y700-Gen4   （声卡在 = audio_pd 有活客户端）
dmesg → Adding APR/GPR dev: gprsvc:service:2:3（q6apm）/ 2:7（q6prm）
```

⇒ lane §8 的 **V1/V2 判据本轮已全部跑过并全绿**：PD 链路四件（pd-mapper → PDR UP → GPR 服务 → q6apm 绑定）齐全。
也就是说 `#737` 的「ADSP 停/错 ⇒ 静默复位」**不是**「PD 依赖缺」造成的 —— 剩下的只能是板级复位源（H2/H3）。

⇒ lane 的关键事实**全部复核通过**；lane 标注为「未取」的两项由父代理补齐：基线 commit `4da9a8b69fc8`、
`.config` 三项目实测为 `=y`（见上）。**lane 未写入的报告路径由父代理落仓（本文件）**。

---

## 结论先行

1. **主线有 PDR，也有 in-kernel pd-mapper**，而且**`qcom,sm8750` 已经在 pd-mapper 的机型表里**（映射到 `sm8550_domains`，含 `msm/adsp/audio_pd` / `msm/adsp/charger_pd` / `msm/adsp/sensor_pd` / `msm/adsp/root_pd` / `msm/cdsp/root_pd` / `msm/modem/root_pd`）。⇒ 「缺 PDR / 缺 pd-mapper」**不成立**。
2. **adsp 侧 DTS 依赖也已经是齐的**：`sm8750.dtsi` 的 `q6apm`（`service@3`）与 `q6prm`（`service@7`）**都带** `qcom,protection-domain = "avs/audio", "msm/adsp/audio_pd"`；`charger_pd` 的消费者在 `pmic_glink`（`tms/servreg` → `msm/adsp/charger_pd`）。⇒ 「PD 依赖没声明、没客户端」**也不成立**。
3. **真正的事实是语义层**：主线 PDR 只有 `pdr_add_lookup/*_restart_pd/*_handle_release`（**没有"关 PD"**），`qcom_q6v5_pas.c` 的 `qcom_pas_stop()` **全程不碰 PD**；PD 的 APSS 侧存在性只由 `qcom_common.c` 的 pdm 子设备在 **stop 之后**的 `unprepare` 里注销。⇒ 「stop 前先按 PDR 优雅关闭 audio_pd/charger_pd」**在主线没有对应接口，不是"没实现"，而是主线模型里没有这个动作**。
4. **旁证（强）**：同为 SM8750、同为 `6800000.remoteproc` 的另一台机（Xiaomi Pad 8 Pro，mainline 7.2.10）**ADSP `stop`→`start` 正常、ADSP 崩溃走 rproc SSR 恢复、整机不复位**（实证见 §5.2）。⇒ 本机「ADSP 一停/一错就静默硬复位整机」**不是 SM8750 主线通性**，更像**板级（PMIC/AOP/TZ 安全监控）面**。
5. **推荐动作：不做这个"PD 补齐"补丁**（可实现的形态不存在、收益低）。改为 §8 的「先只读核对 + 一条二值对照实验」，并把复位面重新归到 PMIC/TZ/ABL 方向（§9）。

---

## 1. 基线核实（先说清树）

| 项 | 现值 | 判据 |
|---|---|---|
| 基线 | mainline **7.3.1**（geekidos 血统树） | `build/daily/Makefile:2-4`（`VERSION=7/PATCHLEVEL=3/SUBLEVEL=1`） |
| 日常线指针 | `build/daily` | `patches/current-tree` 末行 |
| commit | **未取**（本 lane 无 git 可用；报告引用请以 worktree `4da9a8b69fc8` 为准，见 `patches/current-tree` 注释与 `reports/sensors-692-backport-test-20261126.md` §1） | — |
| 已编入 PDR/pd-mapper | **是**（对象件真实存在） | `build/daily/drivers/soc/qcom/qcom_pd_mapper.o`、`…/pdr_interface.o` 均可读（ELF），且 `drivers/soc/qcom/Makefile:10-12` 有 `obj-$(CONFIG_QCOM_PD_MAPPER) += qcom_pd_mapper.o` / `obj-$(CONFIG_QCOM_PDR_HELPERS) += pdr_interface.o` / `obj-$(CONFIG_QCOM_PDR_MSG) += qcom_pdr_msg.o` |
| `.config` 具体值 | **未逐字核**（`.config` 12131 行，本 lane 无 grep，只按对象件反推 = 已编入） | 见上行 |

---

## 2. 主线现状：PDR / pd-mapper / qmi 三件都在（逐条给证据）

### 2.1 文件与 Makefile

| 组件 | 文件 | 证据 |
|---|---|---|
| PDR 客户端库（servreg locator/notifier） | `drivers/soc/qcom/pdr_interface.c` | `drivers/soc/qcom/Makefile:11`；文件首 120 行 = `struct pdr_service`/`struct pdr_handle`/`pdr_locator_new_server`/`pdr_locator_ops` |
| PDR 报文编码 | `drivers/soc/qcom/qcom_pdr_msg.c` | `Makefile:12` |
| **in-kernel pd-mapper**（servreg-locator 服务端） | `drivers/soc/qcom/qcom_pd_mapper.c` | `Makefile:10`；首 200 行含 `qcom_pdm_get_domain_list` / `qcom_pdm_pfr` / `qmi_add_server(..., QMI_SERVICE_ID_SERVREG_LOC, 0x101, 0)` |
| QMI over QRTR 基础设施 | `drivers/soc/qcom/qmi_interface.c`（+ `qmi_encdec.o`） | `Makefile:19-20`（`qmi_helpers-y += qmi_encdec.o qmi_interface.o`） |
| API 头 | `include/linux/soc/qcom/pdr.h` | 全文 22 行，**API 只有 4 个**（见 §2.3） |

### 2.2 pd-mapper 的服务内容 + sm8750 已在表内（**本轮最关键的一条**）

- `qcom_pd_mapper.c` 里 PD 条目是**静态表**，例如（`.domain` = servreg 的 PD 路径，`.instance_id` = 74 = ADSP）：
  - `adsp_audio_pd`：`.domain = "msm/adsp/audio_pd"`，`.services = {"avs/audio"}`（`qcom_pd_mapper.c:≈244`）
  - `adsp_charger_pd`：`.domain = "msm/adsp/charger_pd"`，`.services = {NULL}`（`≈252`）
  - `adsp_sensor_pd` / `adsp_root_pd` / `adsp_root_pd_pdr`（`services = {"tms/pdr_enabled"}`）
  - `sm8550_domains[]` = `{adsp_audio_pd, adsp_root_pd, adsp_charger_pd, adsp_sensor_pd, cdsp_root_pd, mpss_root_pd_gps}`
- **机型表里明确有 sm8750**：
  `qcom_pd_mapper.c:665` = `{ .compatible = "qcom,sm8750", .data = sm8550_domains, },`
  （相邻：`:663` sm8550、`:664` sm8650、`:666` x1e80100，同一段实测读出，行号已确认。）
- 匹配方式是**根 compatible**：`qcom_pdm_start()` 用 `of_machine_get_match(qcom_pdm_domains)`；不匹配时打印
  `pr_notice("PDM: no support for the platform, userspace daemon might be required.\n")`。
  ⇒ 本机 `/ { compatible = "lenovo,elden", "qcom,sm8750"; }`（`sm8750-lenovo-elden.dts:29`）**必然命中 `qcom,sm8750`**。
- 服务在 ADSP 起来后由 **rproc 子设备自动挂出**（不需要 DTS 节点）：
  `drivers/remoteproc/qcom_common.c:≈546 pdm_notify_prepare()` → `auxiliary_device_add(name="pd-mapper")`；
  `≈583 pdm_notify_unprepare()` → `auxiliary_device_delete/uninit`；
  `:596 qcom_add_pdm_subdev()` 把二者绑到 `subdev.prepare` / `subdev.unprepare`。
  aux 驱动 id = `"qcom_common.pd-mapper"`（`qcom_pd_mapper.c` 尾部 `qcom_pdm_table[]`），由 `QCOM_PD_MAPPER` 默认随 `QCOM_RPROC_COMMON` 编入（`drivers/soc/qcom/Kconfig:79-89`，`default QCOM_RPROC_COMMON`）。

### 2.3 PDR 的 API 面（**没有"关 PD"**，这是本工单的判据核心）

`include/linux/soc/qcom/pdr.h` 全文只有：

```c
struct pdr_handle *pdr_handle_alloc(void (*status)(int state, char *service_path, void *priv), void *priv);
struct pdr_service *pdr_add_lookup(struct pdr_handle *pdr, const char *service_name, const char *service_path);
int  pdr_restart_pd(struct pdr_handle *pdr, struct pdr_service *pds);   /* ★只"重启"，不"停止" */
void pdr_handle_release(struct pdr_handle *pdr);
```

- 语义方向是 **DSP → APSS 的状态上报**（`SERVREG_SERVICE_STATE_{UP,DOWN,EARLY_DOWN,UNINIT}`，`pdr.h:10-16`），加一个 APSS 侧 `pdr_restart_pd()`（`servreg_restart_pd`）。
- **没有** `pdr_stop_pd()` / `pdr_shutdown_pd()` / "release PD" 这类东西；也没有任何"向 DSP 请求关某个 PD"的 QMI。
- `pdr_interface.c` 里唯一的"下行"动作是 `pdr_register_listener`（`SERVREG_REGISTER_LISTENER_REQ`）与 `pdr_send_indack_msg`（`SERVREG_SET_ACK_REQ`，注释 `/* Ack the indication after clients release the PD resources */`）—— **ack 的是通知，不是 PD 本体**。

> 结论（直接证据 + 源解读）：**"stop 前按 PDR 优雅关闭依赖 PD"这句话在主线找不到落点**。它不是"实现不完"，而是主线把 PD 生命周期完全交给 DSP 固件/虚拟化层，APSS 只做「服务解析 + 状态订阅」。

### 2.4 谁在用 PDR（全树客户，逐条定位）

| 客户 | 证据 | 说明 |
|---|---|---|
| **APR/GPR 总线**（音频唯一桥梁） | `drivers/soc/qcom/apr.c`：`of_apr_add_pd_lookups()`（`≈468`，逐个 child 读 `qcom,protection-domain` 的两个字符串后 `pdr_add_lookup`）；`apr_pd_status()`（`≈570`，`UP` → `of_register_apr_devices(svc_path)` 迟注册 APR 子设备；`DOWN` → `device_for_each_child(..., apr_remove_device)`）；`apr_probe()`（`≈637` `apr->pdr = pdr_handle_alloc(apr_pd_status, apr)`） | **audio_pd 的唯一消费者路径**：q6apm/q6prm 不是直接调 PDR，而是「APR/GPR 总线等待 `avs/audio` UP 后才把 service 注册成 apr/gpr 设备」 |
| **pmic_glink**（battmgr/altmode/ucsi） | `drivers/soc/qcom/pmic_glink.c:347-352` `pdr_add_lookup(pg->pdr, name, path)`；`:401-407` `pmic_glink_adsp_data = { .charger_pdr_service_name = "tms/servreg", .charger_pdr_service_path = "msm/adsp/charger_pd" }` | **charger_pd 的消费者**（本机板 DTS 用 `"qcom,pmic-glink"` 兼容项 ⇒ 命中 `pmic_glink_adsp_data`） |
| remoteproc | `drivers/remoteproc/qcom_q6v5_pas.c:115` 有 `struct qcom_rproc_pdm pdm_subdev;`，但**它是服务端**（把 pd-mapper 挂出去），**不是 PDR 客户端** | 见 §3 |
| Kconfig 依赖链 | `drivers/soc/qcom/Kconfig:270-278`：`config QCOM_APR` `select QCOM_PDR_HELPERS`；`QCOM_PMIC_GLINK` 亦 `select QCOM_PDR_HELPERS`（`Kconfig:104-110` 段） | 只有这两个子系统拉 PDR |

> 源解读：**PDR 在主线只有「服务发现/状态订阅」一个用途**，它的存在是为了让 adsp 上的 **PD 崩了（不是整机 stop）** 时，APSS 侧能把对应服务摘掉再挂回来（"graceful PD restart"），而不是为了在子系统 shutdown 时去关 PD。

---

## 3. 主线 `qcom_q6v5_pas` 的 stop 路径：**完全不碰 PD**

`drivers/remoteproc/qcom_q6v5_pas.c`，`qcom_pas_stop()`（`≈408`–`444`，实测末尾 `return ret; }` 在 444）：

```c
static int qcom_pas_stop(struct rproc *rproc)          /* ≈408 */
{
        ret = qcom_q6v5_request_stop(&pas->q6v5, pas->sysmon);   /* ≈414  sysmon 关机 + 等 stop-ack */
        if (ret == -ETIMEDOUT) dev_err(...);
        ret = qcom_pas_shutdown(pas->pas_id);                    /* SCM PAS shutdown（TZ 侧） */
        if (ret && pas->decrypt_shutdown) ret = qcom_pas_shutdown_poll_decrypt(pas);
        if (pas->dtb_pas_id) { ... qcom_pas_shutdown(pas->dtb_pas_id); ... }
        qcom_pas_unmap_carveout(...);                            /* iommu unmap */
        handover = qcom_q6v5_unprepare(&pas->q6v5);               /* rproc 子设备 unprepare 由 core 之后调 */
        if (handover) qcom_pas_handover(&pas->q6v5);
        if (pas->smem_host_id) ret = qcom_smem_bust_hwspin_lock_by_host(pas->smem_host_id);
        return ret;
}
```

要点（逐条事实）：
1. **没有** 任何 `pdr_*` 调用、没有 `qcom_pdm_*` 调用、没有 `proxy_pds` 关闭（`qcom_pas_pds_disable()` 只在 `start()` 的失败回滚与 `handover` 路径里出现，`≈424` 的 `qcom_pas_handover()`）。
2. `proxy_pds` 是 **Linux genpd**（`cx/lcx/lmx` 等 RPMh 电源域），**与 PD（servreg 的 audio_pd/charger_pd）不是一回事** —— 命名撞车，容易误判。
3. `qcom_pas_stop()` 返回后，remoteproc core 才 `rproc_unprepare_subdevices()` ⇒ **`pd-mapper` aux 设备（`pdm_notify_unprepare`）是在 DSP 已经下线之后才注销的**。即：**主线当前顺序恰好是"先 stop，后撤 PD 映射服务"**，与工单设想的"先关 PD，再 stop"**方向相反**。
4. `qcom_q6v5_request_stop()`（`drivers/remoteproc/qcom_q6v5.c`）只做 sysmon `shutdown` 通知 + `smp2p` "stop" 位 + 等 `stop-ack` 中断 —— **没有任何 PD 语义**。

> **推断（明标为推断）**：`#737` 的 C2 实测「`echo stop` 自身不返回 = 卡在停止握手」，与上面第 4 条吻合：卡点在 `qcom_q6v5_request_stop()` 的 `stop-ack` 等待（或紧随的 `qcom_pas_shutdown()` SCM 调用），**这之前不存在任何"该关而未关的 PD 步骤"可以补**。

---

## 4. 主线 `sm8750.dtsi` 的 adsp 节点现在声明了什么（与"缺什么"的对照）

`arch/arm64/boot/dts/qcom/sm8750.dtsi`：

| 位置 | 内容 | 行号（实测） |
|---|---|---|
| adsp remoteproc | `remoteproc_adsp: remoteproc@6800000 { compatible = "qcom,sm8750-adsp-pas", "qcom,sm8550-adsp-pas"; reg = <0x0 0x06800000 0x0 0x10000>; }` | `:2204-2206` |
| 中断/握手 | `interrupt-names = "wdog","fatal","ready","handover","stop-ack","shutdown-ack"`；`qcom,smem-states = <&smp2p_adsp_out 0>; qcom,smem-state-names = "stop";` | `:2208-2221`、`:2274-2275` |
| 电源域（genpd，**非** PD） | `power-domains = <&rpmhpd RPMHPD_LCX>, <&rpmhpd RPMHPD_LMX>; power-domain-names = "lcx","lmx";` | `:2230-2233` |
| 固件 | `memory-region = <&adspslpi_mem>, <&q6_adsp_dtb_mem>;` + `qcom,qmp = <&aoss_qmp>;` | `:2235-2237` |
| glink-edge | `label = "lpass"`, `qcom,remote-pid = <2>` | `:2280-2290` |
| fastrpc | `compatible="qcom,fastrpc"; label="adsp"; memory-region=<&adsp_rpc_remote_heap_mem>; qcom,vmids=<VMID_LPASS,VMID_ADSP_HEAP>`（**无** `qcom,non-secure-domain`，故只出 `/dev/fastrpc-adsp-secure`；工单 §8.1 的实测差异即此项） | `:2292-2296` |
| **GPR 客户端（audio_pd 已有！）** | `gpr { compatible="qcom,gpr"; qcom,domain=<GPR_DOMAIN_ID_ADSP>; }` 下：`q6apm: service@3 { compatible="qcom,q6apm"; reg=<3>; qcom,protection-domain = "avs/audio", "msm/adsp/audio_pd"; }` | `:2314-2367`（`q6apm` 在 `:2362`，`qcom,protection-domain` 在 `:2366-2367`） |
| **q6prm（audio_pd 已有！）** | `q6prm: service@7 { compatible="qcom,q6prm"; reg=<7>; qcom,protection-domain = "avs/audio", "msm/adsp/audio_pd"; q6prmcc: clock-controller { compatible="qcom,q6prm-lpass-clocks"; } }` | `:2381-2392` |

**对照结论（事实）**：

- `qcom,pd` / `qcom,pdr` / `audio-pd` / `charger-pd` / `qcom,protection-domain` 在 adsp 下的**消费者侧**：**audio_pd 已在（q6apm+q6prm）**；charger_pd 不在 DTS，而在 `pmic_glink` 驱动内部常量（§2.4）。
- **没有**任何名为 `qcom,pd` / `pd-mapper` / `qcom,servreg` 的 DTS 节点 —— **也不需要**：in-kernel pd-mapper 用根 compatible + 静态表，auxdev 由 remoteproc 自建（§2.2）。
- `qcom,qmp` 在（`&aoss_qmp`）、`qcom,smp2p` 状态在（`smp2p_adsp_out/in`）—— 与 PD 无关。
- ⇒ **能在 DTS 层补的"PD 依赖"，已经全补完了；DTS 层没有可加的项。**

> 与下游（vendor）对比的**核心差异**：下游把 PD 映射放在**固件的 JSON**（`/vendor/etc/…servreg…`）里、由 **userspace `pd-mapper` 守护进程**加载；主线把它搬进内核静态表（`qcom_pd_mapper.c`，Linaro 2023，`of_machine_get_match` 匹配机型）。**两边都只是"给 DSP 的 servreg locator 提供 服务名↔PD 名 的映射"，都不是"关 PD 的能力"**。下游 `audio_pdr.c / audio_ssr.c / audio_notifier.c`（`MSM_QDSP6_PDR/SSR/NOTIFIER` 三个 Kconfig，见 §7 的检索命中）也**只做通知与客户端重建**，不做 PD 关停。

---

## 5. 关键旁证：同 SoC 的另一台机，ADSP stop 不复位整机

### 5.1 事实

GitHub issue（Xiaomi Pad 8 Pro `piano`，**kernel 7.2.10-piano26**，同一 SoC = SM8750，同一 ADSP 基址 `6800000.remoteproc`）：
`https://github.com/yzddmr6/xiaomipad-8pro-mainline/issues/3`（2026-10-16，已 closed）

- 报告里的原始日志（**引用，非我方实测**）：
  ```
  PDM: service 'qsh_process' crash: 'EF:qsh_process:0x4:UTIMER_CLIENT_4:0x1000002f:sns_watchdo'
  qcom_q6v5_pas 6800000.remoteproc: fatal error received: …
  remoteproc remoteproc0: crash detected in adsp: type fatal error
  remoteproc remoteproc0: handling crash #1 in adsp → recovering adsp
  ```
  ⇒ ① **in-kernel pd-mapper 在真机上确实在工作**（`PDM: service … crash: …` 就是 `qcom_pd_mapper.c` 的 `qcom_pdm_pfr()` 打印）；② ADSP 崩溃走的是 **rproc 恢复**，**整机不复位**。
- 该机的"Ruled out"表里还有一条直接命中本工单：
  > `DSP runtime state` | `remoteproc0` `state = stop` then `start`（firmware reloaded）：still 8 crashes/60 s
  ⇒ **ADSP 的 `stop`→`start` 在同一 SoC 的另一台机上是被成功执行过的操作**（否则不会只剩"还是 8 次/分"这个观测）。

### 5.2 这条旁证的分量（源解读）

- 它**不能**证明"本机复位与 PD 无关"（两机固件/PMIC 配置/板级不同）。
- 它能**否掉**两种强主张：
  - 「SM8750 + 主线 + 有 audio_pd 客户端」⇒ ADSP stop 必然复位整机 —— **否**（piano 反例）。
  - 「PD 依赖没补齐」⇒ 必然复位 —— **否**（piano 的 DTS 也只有同样的 `avs/audio` 客户端）。
- 因此**复位面的可解释变量从"主线 PD 模型"转移到"本机板级/PMIC/TZ/AOP 配置"**。

---

## 6. 假说分级（严格区分事实 / 源解读 / 推断 / 未验证假说）

| 编号 | 内容 | 级别 | 依据 / 反证 |
|---|---|---|---|
| F1 | 主线有 PDR（`pdr_interface.c`）+ in-kernel pd-mapper（`qcom_pd_mapper.c`），`qcom,sm8750` 在机型表内 | **事实** | §2.1/2.2 文件:行 |
| F2 | 主线 PDR 无"关 PD"API；`pdr.h` 只有 4 个符号 | **事实** | §2.3 |
| F3 | `qcom_pas_stop()` 内无任何 PD/PDR 动作；pd-mapper 注销发生在 stop **之后** | **事实（源解读为"顺序相反"）** | §3 |
| F4 | 本机 DTS 已声明 audio_pd 消费者（q6apm/q6prm），charger_pd 消费者在 pmic_glink 常量里 | **事实** | §4、§2.4 |
| F5 | 同 SoC 另一台机（piano，mainline）ADSP stop/start 与 ADSP SSR 均不复位整机 | **事实（他方报告，非我方实验）** | §5.1 |
| F6 | 本机 ADSP stop/`-s` ⇒ 1–2 s 静默整机复位，CDSP 不复位 | **事实（我方实测）** | `#737` 正文 + 工单 §8.2 |
| I1 | 「PD 依赖未补齐 ⇒ 复位」不成立（既无缺项，也无对应动作可补） | **推断（依据 F1–F6）** | §7 |
| I2 | 复位点在本机最可能是 `qcom_q6v5_request_stop()` 的 stop-ack 等待、或紧随的 `qcom_pas_shutdown()` SCM（TZ）调用，被**板外某监控**强制复位 | **推断** | `#737` 的"`echo` 未返回"+ 串口零行 |
| H1 | **未验证假说**：PMIC / 安全监控在"ADSP 的 PD 失去客户"或"PD 状态不一致"时触发整机复位（工单原设想的机制） | **未验证（且 §5.2 使其先验概率下降）** | 无任何直接证据；piano 反例 |
| H2 | **未验证假说**：Lenovo 板的 AOP/PMIC PBS 或 TZ 里配了"ADSP 停机 ⇒ 强制 POR"（例如 `PON` 触发器 / `SMP` 安全监控），Android 侧靠 `adsp-loader` 的特定关机顺序规避，主线没做 | **未验证** | 可解释 F6+F5 的差异；缺 PMIC/TZ 侧取证 |
| H3 | **未验证假说**：ADSP 固件在 stop 握手时对"仍持有 LPASS 宏/时钟投票"的客户端（q6prm clk、va/wsa macro）走 SSR 自毁，而本机 TZ 把 SSR 升级成 POR | **未验证** | piano 的日志确实出现 `clk_unregister … LPASS_HW_DCODEC / LPASS_HW_MACRO`（崩溃路径），但那边只 SSR |

---

## 7. 补丁草案（诚实版：主线形态下"没有能落地的版本"）

### 7.1 三种可能的形态与结论

| 形态 | 具体内容 | 结论 |
|---|---|---|
| **A. 纯 DTS**（工单原本的设想） | 在 `remoteproc_adsp` 下加 `qcom,pd` / `qcom,protection-domain` / `audio-pd` / `charger-pd` 等 | **无可加**：audio_pd 已由 q6apm/q6prm 声明（`sm8750.dtsi:2366-2367`、`:2385-2386`）；charger_pd 由驱动常量给出（`pmic_glink.c:401-407`）；pd-mapper 不认 DTS 节点（§2.2）。**任何新增属性都只会被 `unevaluatedProperties: false` 的 yaml 拒掉** |
| **B. 驱动：在 `qcom_pas_stop()` 里"先关 PD"** | 例如仿 2023 年 RFC 在 `adsp_stop()` 开头调 `qcom_pdm_del_domain()` | **上游已否过这个形态**：`[RFC PATCH 5/5] remoteproc: qcom: pas: add configuration for in-kernel pdm`（Dmitry Baryshkov, 2023-12-25, `linux-remoteproc@vger.kernel.org/msg00092`）当时确实把 `qcom_pdm_del_domain()` 放在 `qcom_q6v5_request_stop()` **之前**，但**最终合入的形态**是 `qcom_common.c` 的 `pdm` 子设备（`prepare`/`unprepare`），即**注销发生在 stop 之后**。而且 `qcom_pdm_del_domain()` 只是**从 APSS 的服务表里删条目**，**对 DSP 固件没有任何作用**，也不存在"通知 DSP 关 PD"的 QMI。⇒ 这条路**即使写出来也不解决任何事**，且必然被 upstream 拒（改的是服务表而不是 PD 状态） |
| **C. 新增上游能力：servreg "PD 关停/排空" 请求** | 需要 DSP 固件支持新的 QMI（现有 `SERVREG_*` 只有 `GET_DOMAIN_LIST / REGISTER_LISTENER / SET_ACK / RESTART_PD / LOC_PFR`，见 `pdr_internal.h`） | **不可行（本机）**：无固件接口文档、无 DSP 侧配合、无任何厂商先例；工作量 ≥ 数周且收益不可证 |

**⇒ 工单第 2 项按"补丁"交付是不可能的；按"判据"交付是可行的（§8）。**

### 7.2 如果只是想让"PD 客户端在 stop 前被摘掉"（唯一勉强有意义的最小改动）

- 现有机制：`QCOM_SSR_BEFORE_SHUTDOWN` 通知（`qcom_common.c` `ssr_notify_stop()`，`≈477`）在 `rproc_stop` 里由 subdev `stop` 触发；APR/GPR 摘设备走的是 **PDR DOWN 指示**（DSP 主动发）或 `apr_remove()`。
- 可做的最小改动（**不建议**，仅登记）：在 `qcom_pas_stop()` 开头显式 `srcu_notifier_call_chain(QCOM_SSR_BEFORE_SHUTDOWN)` 提前 —— **但这已经在 stop 里发生了**，提前 1 个函数调用对 DSP 侧握手无任何影响。
- 判据：改完后 `#737` 的 C2 复现若**依旧复位**，则该改动 O 价值（预期如此）。

---

## 8. 上机可验证的判据（**不使用 `-s`**，遵守 `PITFALLS #737`）

> 全部为**只读**或**零写盘**；任何"要 stop ADSP"的实验都必须单独授权 + 物理在场 + 接受"整机复位后自回 `boot_b`"。

### V1（只读，0 风险，先做）——把"PD 链路是否完整"钉成事实

```sh
ssh elden-root 'uname -r'
ssh elden-root 'ls /sys/bus/auxiliary/devices/ | grep -i pd'        # 期望: qcom_common.pd-mapper
ssh elden-root 'dmesg | grep -iE "PDM:|pdr" '                       # 期望: 无 "PDM: no support for the platform"
ssh elden-root 'qrtr-lookup'                                        # 期望: servreg-locator / pd-mapper 端口在列
ssh elden-root 'ls -l /sys/bus/gpr/devices/ 2>/dev/null; ls /sys/bus/apr/devices 2>/dev/null'
ssh elden-root 'cat /sys/class/remoteproc/remoteproc0/state'
```
- **判为"主线 PD 面完整"的充分条件**：(a) `qcom_common.pd-mapper` auxdev 在；(b) dmesg 无 `PDM: no support for the platform`；(c) dmesg 有 `PDR: Indication received from msm/adsp/audio_pd…` 或 gpr 子设备（`gprsvc:*`）已注册；(d) `qrtr-lookup` 有 servreg 相关端口。
- 若 (a)–(d) 全绿 ⇒ **§7.1 形态 A/B 的动机彻底消失**（PD 链路本来就是通的），后续只做 V3。
- ⚠ 注意：本 lane **无法**在离线状态下断言这四项为真（`reports/artifacts/sensors-692-s-test-20261127/trial-dev-nodes.txt` 只抓了 `qrtr-lookup | grep 400`，**没有全量 qrtr 列表、没有 auxdev、没有 PDM 行**）⇒ 这正是 V1 要补的第一手证据。

### V2（只读）——确认客户端确实挂上（而不是"只注册了 lookup"）

```sh
ssh elden-root 'cat /sys/kernel/debug/devices_deferred 2>/dev/null'   # 看 gpr service@3/@7 是否 deferred
ssh elden-root 'dmesg | grep -iE "Adding APR/GPR dev|apr|gprsvc"'
ssh elden-root 'ls /sys/class/power_supply/; dmesg | grep -i battmgr'
```
- 判据：`q6apm`/`q6prm` 的 gpr 设备**已注册**（= audio_pd 报过 UP）、battmgr 属性**非 `-EAGAIN`**（= charger_pd 报过 UP）。这两条同时成立 ⇒ 「两个 PD 都有活客户端且状态正常」，H1 的"PD 失去客户"前提在本机不成立。

### V3（二值对照，**需授权 + 零写盘 fastboot boot**）——唯一能真正判 PD 相关性的实验

> 目的：把"PD 客户端是否存在"变成单变量。**不 stop ADSP 两次，只 stop 一次**。

1. 造一个 **DTB 变体**（仅本轮实验用，不进仓）：把 `sm8750.dtsi` 里 q6apm/q6prm 的 `qcom,protection-domain` **两处删掉**（⇒ apr 不再为 `avs/audio` 注册 lookup ⇒ gpr 设备在无 PD 的情况下立即注册 ⇒ **APSS 侧完全没有 audio_pd 客户端**）。
2. `fastboot boot` 该内核（零写盘）；开机后先跑 V1/V2，**确认 audio_pd 客户端确实不存在**（`dmesg` 无 `PDM`/PDR 指示；gpr 设备直接注册）。
3. **然后**才执行一次 `echo stop > /sys/class/remoteproc/remoteproc0/state`（唯一的高风险动作，整机复位后自回 `boot_b`）。
- **判读**：
  - 仍 1–2 s 静默复位 ⇒ **PD 客户端与复位无因果**（I1 升级为实验否证 H1）⇒ 该方向彻底关闭，转 H2/H3。
  - 不复位（能停到 `offline`）⇒ **H1 首次获得支持**，此时才值得讨论"如何让 PD 在 stop 前被摘"（但那也不是主线 API 能做的事，见 §7.1 C）。
- 风险与兜底：复位后设备自回 `boot_b`（`#732` 同族做法）；**必须**先 `ssh elden-root 'reboot'` 回在机核，且实验前确认 `qbootctl -a` = `_b`。

### V4（只读，判 H2/H3 的"板外复位者"）
```sh
ssh elden-root 'dmesg | grep -iE "pon|pbs|pmic|spmi|watchdog|reset reason"'
ssh elden-root 'cat /proc/cmdline'          # 看有没有 androidboot.*reason / bootreason
```
- 只在**正常启动**（非复位后）能读；复位后读 PMIC PON reason 需要 PMIC PON 驱动接口（**本 lane 未确认主线 7.3.1 是否提供 sysfs/nvmem 读 PON reason** ⇒ 记为缺口）。
- 判据：若能在复位后读到 `pon_reason = KPARMED`/`HARD_RESET` 类值，H2/H3 从"假说"升级为"有方向"；读不到则维持假说。

---

## 9. 推荐动作与收益评估

| 优先级 | 动作 | 收益 | 成本/风险 |
|---|---|---|---|
| **P0** | 跑 **V1+V2**（只读 5 条命令），把"PD 链路完整"钉成第一手事实并写入 `reports/` | **高**：一条命令面即可关闭"PD 补齐"这条线，避免后续再花轮次 | 0 |
| **P1** | 把本报告结论并入 `TASKS/README.md` T6 的三条后续：第 2 项由「补 PD 依赖」改写为「PD 面已证完整；改为 V3 单变量对照（需授权）」 | 高（防后人重走） | 低（改文档，本轮不做） |
| **P2** | 若用户放行 V3：做 DTB 变体 + 一次 stop 对照 | 高（唯一二值判据） | 中（一次整机复位） |
| **P3** | H2/H3 方向（PMIC/AOP/TZ 复位源）：查 Lenovo 原厂 DT/PMIC 配置、`xbl`/`abl` 里的 `PON` 与安全监控配置、以及 7.3.1 是否有 PON reason 读取路径 | 中（可能真正解释 `#737`） | 中（需要原厂件反查，非纯主线） |
| — | 「stop 前按 PDR 关 audio_pd/charger_pd」 | **≈0** | 不可实现（§7.1） |

**判断：这个方向不值得做**（形态 A 无可加、形态 B 被上游否过且语义空转、形态 C 不可行）；但它**值得写下来**，因为它是把 `#737` 从"神秘复位"推进到"板级复位源"的必要的一步排除。

---

## 矛盾与未解

- **矛盾 1（未解）**：`#737` 称"复位在 Linux 之外（PMIC/引导层看门狗或安全监控）"，而 APSS 硬看门狗在启动横幅里是 `Hard watchdog permanently disabled`。两者兼容的唯一已知解释是"复位者是 **ADSP WDOG 的板级路由**或 **TZ/AOP**"，**未取证**。
- **矛盾 2（未解）**：本机 ADSP stop 卡在握手且整机复位；piano 同 SoC stop/start 正常。差异面（PMIC 型号 `pmih0108`+`pm8550` 组合 / Lenovo ABL 版本 / TZ 版本 / ADSP 固件版本）**全部未核对**。
- **未解**：本机 `audio_pd` 到底有没有"活着的"客户端（V1/V2 才能定）——若 q6apm 从未 probe（例如音频卡未起），那"PD 有客户"这一前提在本机就**根本没被验证过**，H1 连前提都缺。

## Missing evidence（明确没拿到的）

1. `build/daily/.config` 里 `CONFIG_QCOM_PD_MAPPER/QCOM_PDR_HELPERS/QCOM_APR/QCOM_PMIC_GLINK` 的**字面值**（只按 `.o` 存在反推"已编入"）。
2. 本机 `dmesg`/`qrtr-lookup` 全量（V1）。现有证据文件只 grep 了 `400`。
3. 本机 adsp 固件版本、TZ 版本、PMIC/PBS 配置（H2 的必需品）。
4. `git -C build/daily log -1` 的 commit（无 shell）。
5. `drivers/remoteproc/qcom_q6v5.c` 中 `qcom_q6v5_request_stop()` 的逐行（本轮只按函数语义引用，未逐行读）。

## Sources

- **Kept**
  - `build/daily/drivers/soc/qcom/qcom_pd_mapper.c`（本地 7.3.1 树）—— pd-mapper 服务本体 + **`qcom,sm8750` 在机型表**（`:665`）
  - `build/daily/drivers/soc/qcom/pdr_interface.c` + `include/linux/soc/qcom/pdr.h` —— PDR API 面（无"关 PD"）
  - `build/daily/drivers/soc/qcom/apr.c` —— audio_pd 唯一消费者路径（`of_apr_add_pd_lookups` / `apr_pd_status`）
  - `build/daily/drivers/soc/qcom/pmic_glink.c:347-352,401-407` —— charger_pd 消费者（`tms/servreg`→`msm/adsp/charger_pd`）
  - `build/daily/drivers/remoteproc/qcom_common.c:≈546/≈583/596` —— pdm 子设备在 **unprepare（stop 之后）** 注销
  - `build/daily/drivers/remoteproc/qcom_q6v5_pas.c:≈408-444` —— `qcom_pas_stop()` 不碰 PD
  - `build/daily/arch/arm64/boot/dts/qcom/sm8750.dtsi:2204,2362-2367,2381-2392` —— adsp 节点与 q6apm/q6prm 的 `qcom,protection-domain`
  - `build/daily/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts:29,~640(pmic_glink)` —— 根 compatible 与 `qcom,pmic-glink` 兼容项
  - `https://github.com/yzddmr6/xiaomipad-8pro-mainline/issues/3` —— 同 SoC 反例（PDM 在跑、ADSP SSR 不复位、stop→start 成功）
  - `https://www.mail-archive.com/linux-remoteproc@vger.kernel.org/msg00092.html` —— 2023 RFC 曾把 `qcom_pdm_del_domain()` 放在 stop 前，最终合入形态改为 prepare/unprepare
  - `PITFALLS/sessions/576-ADSP-stop硬复位整机-ADSP侧故障一律静默复位.md`（`#737`）—— 我方实测事实基线
- **Rejected / deprioritized**
  - `ratatoskr.run` 的 Glymur ADSP 系列（v6/v8/v11）—— 只证明别的 SoC 也在用同样的 `qcom,protection-domain` 写法，与本机判据冗余
  - `codebrowser.dev` / `elixir.bootlin.com` —— elixir 被 Anubis PoW 挡住（`#444` 同族），codebrowser 未取到 sm8750 页；本地树已够用
  - msm8998 时代的 `audio_pdr.c/audio_ssr.c/audio_notifier.c` 下游实现 —— 只作"下游也只通知、不关 PD"的旁证，未逐行核

## Next steps

1. **V1（5 条只读命令）** —— 决定这条线是否就地关闭。
2. 若 V1 全绿 且用户放行 → **V3 单变量对照**（DTB 去 `qcom,protection-domain` + 一次 stop）。
3. 并行开 **P3**：从原厂 DT/ABL/`logfs` 里找 `PON`/安全监控/`adsp` 相关配置，判 H2；顺带确认 7.3.1 是否已有 PMIC PON reason 读取路径（没有就登记为缺口）。

---

```acceptance-report
{
  "criteriaSatisfied": [
    {
      "id": "criterion-1",
      "status": "satisfied",
      "evidence": "报告已落盘到指定 artifact 路径；结论先行（5 条）+ 证据表（全部给文件:行，本地 build/daily 7.3.1 树逐段 read 确认）+ 补丁草案（3 形态，含为何不可行）+ 假说分级表（F/I/H 三类严格区分）+ 无 -s 的上机判据 V1–V4 + 矛盾/Missing evidence/Sources Kept-Rejected/Next steps 段落齐备"
    }
  ],
  "changedFiles": [
    ".pi/sessions/subagent-artifacts/outputs/fd877c9f-5a68-4875-a938-e710b4ba79fd/.pi/sessions/subagent-artifacts/outputs/451c0567-734f-48b3-9cf8-59e204140422/task-2.md"
  ],
  "testsAddedOrUpdated": [],
  "commandsRun": [
    {
      "command": "(none — 本 lane 无 shell 工具)",
      "result": "not-run",
      "summary": "无法 git log/grep/rg；全部证据用 read 工具逐段取本地 build/daily 树文件，行号已落盘标注"
    }
  ],
  "validationOutput": [
    "build/daily/Makefile:2-4 = VERSION 7 / PATCHLEVEL 3 / SUBLEVEL 1（基线 7.3.1 已核）",
    "drivers/soc/qcom/Makefile:10-12 存在 qcom_pd_mapper.o / pdr_interface.o / qcom_pdr_msg.o",
    "qcom_pd_mapper.c:663-666 实测读出 qcom,sm8550 / sm8650 / sm8750 / x1e80100 四行，sm8750 在 :665",
    "sm8750.dtsi:2362 q6apm service@3，:2366-2367 qcom,protection-domain = avs/audio, msm/adsp/audio_pd；:2381 q6prm service@7",
    "pmic_glink.c:401-407 pmic_glink_adsp_data = {charger_pdr_service_name=\"tms/servreg\", charger_pdr_service_path=\"msm/adsp/charger_pd\"}",
    "qcom_q6v5_pas.c:qcom_pas_stop() 体（≈408-444）内无 pdr_*/qcom_pdm_* 调用"
  ],
  "residualRisks": [
    "本 lane 无 shell ⇒ 未做 git log -1、未 grep 全树、未核 .config 字面值（用对象件存在反推已编入）",
    "行号中带 ≈ 的 5 处为同函数块内推定（qcom_common.c:≈546/≈583、apr.c:≈468/≈570/≈637、qcom_pas_stop ≈408），偏差 ±15 行内",
    "同 SoC 反例（piano）是他方 GitHub issue 报告，非我方实测；其 stop/start 成功是从该文 'Ruled out' 表反推，不是原始日志逐行",
    "未验证假说 H1/H2/H3 均未取证；PMIC/TZ 侧完全没碰",
    "报告要求的目标路径 reports/sensors-adsp-pd-pdr-20261127.md 未由本 lane 写入（Output 路径覆盖）；父代理需另行落仓"
  ],
  "noStagedFiles": true,
  "diffSummary": "仅新增 1 个 artifact 输出文件（报告正文），未触碰仓库任何受管文件、未 git commit",
  "reviewFindings": [
    "no blockers",
    "工单第 2 项的前提（PD 依赖未补齐）经本地树证据否证：audio_pd 由 q6apm/q6prm 声明、charger_pd 由 pmic_glink 常量声明、pd-mapper 已含 sm8750；且主线无任何'关 PD'接口 ⇒ 该补丁形态不存在（形态 A 无可加、形态 B 上游 2023 RFC 已否、形态 C 不可行）",
    "新增最有力旁证：同 SoC 另一台机（Xiaomi Pad 8 Pro，6800000.remoteproc，mainline 7.2.10）ADSP stop→start 与 ADSP SSR 都不复位整机 ⇒ 本机复位更像板级 PMIC/AOP/TZ 面"
  ],
  "manualNotes": "三行回报：(1) 主线既有 PDR（pdr_interface.c，pdr.h 4 个 API，无'关 PD'）也有 in-kernel pd-mapper（qcom_pd_mapper.c，且 qcom,sm8750 在机型表 :665 → sm8550_domains 含 audio_pd/charger_pd/sensor_pd/root_pd）；(2) adsp DTS 不缺东西——sm8750.dtsi:2362-2367 与 :2381-2392 的 q6apm/q6prm 已带 qcom,protection-domain=\"avs/audio\",\"msm/adsp/audio_pd\"，charger_pd 消费者在 pmic_glink.c:401-407，pd-mapper 不需要 DTS 节点（auxdev 由 remoteproc 的 pdm 子设备自建）；(3) 推荐动作=不做该补丁（不可实现、qcom_pas_stop 全程不碰 PD、pd-mapper 反而在 stop 之后才注销），先跑 V1 五条只读命令把 PD 链路钉成事实，若放行再做 V3 单变量对照（DTB 删 qcom,protection-domain + 一次 stop）；值得做的只是'排除'，方向本身收益≈0。"
}
```
