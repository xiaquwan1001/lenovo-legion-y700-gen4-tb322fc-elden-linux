# M3-6 无线片 — 补丁草案（2026-10-13）

基底：pristine `24a19b953e`（Linux 7.3-rc7）。工作树：`build/m3-6-worktree`（分支 `m3-6/draft`）。
规则：`reports/upstream-policy-20261013.md` §1/§3。分析：`reports/m3-6-wireless-slice-20261013.md`。

## 补丁

| # | subject | 文件 | 说明 |
|---|---|---|---|
| 0001 | `regulator: qcom,qca6390-pmu: document the WCN7861 PMU` | qca6390-pmu.yaml | 加 `qcom,wcn7861-pmu` enum + 供应集合；剔除 vendor 属性 |
| 0002 | `power: sequencing: pwrseq-qcom-wcn: add WCN7861 PMU support` | pwrseq-qcom-wcn.c | 复用 wcn7850 轨道 + BT 时序（reset/wlan-off/power-off 延迟） |

## 验收

- `checkpatch.pl --strict --no-tree`：0001 `0E/0W/0C`；0002 `0E/0W/0C`。
- 编译：`cp build/m1-upstream/clean-tree/.config .config; make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig` rc=0；`make … drivers/power/sequencing/` rc=0（`CC pwrseq-qcom-wcn.o`）。
- `dt-doc-validate Documentation/devicetree/bindings/regulator/qcom,qca6390-pmu.yaml` rc=0。
- `git apply --check`（对 pristine 24a19b953e）：两枚均 APPLY_OK。

## 不含（私有/违例，见报告 §1/§2）

`vreg_cfgs` 逐轨电压投票、AOSS QMP PDC（`qcom,qmp`/`qcom,pdc-init-table`/`qcom,vreg-pdc-map`/`qcom,pmu-vreg-map`）、OL-CPR 导出 API、ath12k TME-L/OL-CPR、hci_qca PERI。

## 未上机

功能结论未证实；补丁未发送，仅备料。
