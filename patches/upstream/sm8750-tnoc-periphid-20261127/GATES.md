# GATES —— SM8750 TNOC periphid v1（2026-11-27）

发件树 = `/tmp/cs-wt`（worktree @ `4da9a8b69fc85`），两枚提交：binding + dts；
封面手写（`v1-0000-cover-letter.patch`）。

| 门 | 命令 | 结果 |
|---|---|---|
| checkpatch --strict | `perl scripts/checkpatch.pl --strict --no-signoff v1-0001-*.patch` | `0 errors, 0 warnings, 0 checks`，17 行 |
| checkpatch --strict | 同上 `v1-0002-*.patch` | `0 errors, 0 warnings, 0 checks`，7 行 |
| dtbs_check | `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CHECK_DTBS=1 -j12 qcom/sm8750-mtp.dtb qcom/sm8750-qrd.dtb` | rc=0，**无诊断**（未打 binding 补丁时：`'arm,primecell-periphid' does not match any of the regexes` 两处） |
| dt_binding_check | `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- dt_binding_check DT_SCHEMA_FILES=Documentation/devicetree/bindings/arm/qcom,coresight-tnoc.yaml` | rc=0（LINT/STYLE/DTEX/DTC 全过） |
| 上机绑定 | vk195/vk196：`readlink -f /sys/bus/amba/devices/109ab000.tn/driver` | `coresight-trace-noc`；AMBA 未绑定 0/28 |
| 上游 7.4-rc3 复检 | `grep -c primecell-periphid build/elden-tree/arch/arm64/boot/dts/qcom/sm8750.dtsi` | 0（仍缺） |
| dup-check | patchwork `q=ctcu`/`q=tpda`（project 62/92）+ `q=tnoc` | 无同类 periphid 投递 |

复现（binding 必须先于 DTS，否则 dtbs_check 必红 —— 这是本轮实测的第一手教训）：

```bash
cd /tmp/cs-wt
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CHECK_DTBS=1 -j12 qcom/sm8750-mtp.dtb qcom/sm8750-qrd.dtb
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- dt_binding_check \
  DT_SCHEMA_FILES=Documentation/devicetree/bindings/arm/qcom,coresight-tnoc.yaml
```
