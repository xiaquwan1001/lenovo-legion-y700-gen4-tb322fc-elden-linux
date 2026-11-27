# SM8750 TNOC AMBA periphid —— v1（2026-11-27）

> 来源：`reports/capbatch-vk194-20261127.md` §6/§7、`reports/upstream-coresight-fixes-20261127.md`
> 状态：**v1 备料完成，门禁全绿**（`GATES.md`）。投递走 `SEND.sh`（默认 dry-run）。
> 口径：`TASKS/README.md` §7（用户 2026-11-26 全面放行）。

## 1. 缺陷

`sm8750.dtsi` 的 `tn@109ab000` 是 AMBA 设备，但没写 `arm,primecell-periphid` ⇒ AMBA 核读回
**`AMBA_ID=0x00000000`**（寄存器在 `aoss_qmp`/`apb_pclk` 上电前读回 0），而 `coresight-tnoc`
的 amba id 表是 `0x000f0c00 / 0x001f0c00, mask 0x00ffff00` ⇒ 永不匹配，节点恒
`deferred probe pending: (reason unknown)`。`kaanapali.dtsi:5134` 有同样的缺口（本系列只动 SM8750，
留作后续同型修复）。

DT 单独改不过门：`qcom,coresight-tnoc.yaml` 根 `additionalProperties: false` 且**没有**引用
PrimeCell schema ⇒ `dtbs_check` 拒 `arm,primecell-periphid`。故本系列先补 binding。

## 2. 补丁（v1）

| 文件 | 内容 |
|---|---|
| `v1-0000-cover-letter.patch` | [PATCH 0/2] arm64: dts: qcom: sm8750: describe the TNOC AMBA periphid |
| `v1-0001-dt-bindings-…-allow-the-AMBA-periphid.patch` | binding 加 `allOf: - $ref: /schemas/arm/primecell.yaml#`，根 `additionalProperties: false` → `unevaluatedProperties: false`（与其它 CoreSight AMBA binding 同形） |
| `v1-0002-arm64-dts-…-describe-the-TNOC-AMBA-periphid.patch` | `tn@109ab000` 加 `arm,primecell-periphid = <0x000f0c00>;` |

基线 = `build/daily` HEAD `4da9a8b69fc85`（7.3.1）；上游 7.4-rc3 同缺。

## 3. 判据（上机 + 机检）

- 上机（vk195/vk196）：`readlink /sys/bus/amba/devices/109ab000.tn/driver` → `coresight-trace-noc`；
  AMBA 未绑定 28 → **0**。
- `dtbs_check`（`sm8750-mtp.dtb` + `sm8750-qrd.dtb`）无诊断；`dt_binding_check`（本 yaml）rc=0；
  `checkpatch.pl --strict` 0E/0W/0C。命令与原始输出见 `GATES.md`。

## 4. 收件人

`TO` = Bjorn Andersson；`Cc` = Konrad Dybcio / Rob Herring / Krzysztof Kozlowski / Conor Dooley /
`linux-arm-msm` / `devicetree` / `linux-kernel`（`SEND.sh` 内固化）。
