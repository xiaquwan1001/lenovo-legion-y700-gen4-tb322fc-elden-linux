# GATES —— kaanapali TNOC periphid 草稿（2026-11-27）**已执行，全绿，但草稿不投递**

发件树 = `git worktree /tmp/kn-wt`（`build/elden-tree` @ `aebb72744764` = Linux 7.4-rc3，干净），
一枚提交 `4e5193b9f63f`；构建槽位 `202752-3498977-y700-elden_kaanapali-tnoc -j4`（已 drop）。
原始输出 = `logs/`。判定「不投递」的依据是 `logs/patchwork-dupcheck.log`，不是门禁失败。

| # | 门 | 命令 | 结果 | 日志 |
|---|---|---|---|---|
| 1 | checkpatch --strict（DT 封） | `perl /tmp/kn-wt/scripts/checkpatch.pl --strict --no-signoff v1-0001-*.patch` | `0 errors, 0 warnings, 0 checks, 7 lines checked`，rc=0 | `logs/checkpatch-v1-0001.log` |
| 2 | checkpatch --strict（封面） | 同上 `v1-0000-cover-letter.patch` | `0 errors, 0 warnings, 0 checks`，rc=0 | `logs/checkpatch-v1-0000-cover.log` |
| 3 | dtbs_check **负对照**（不打 binding 补丁） | `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CHECK_DTBS=1 -j4 qcom/kaanapali-mtp.dtb qcom/kaanapali-qrd.dtb` | **2 条诊断**，两条 DTB 各一：`tn@111b8000 (qcom,coresight-tnoc): 'arm,primecell-periphid' does not match any of the regexes: '^pinctrl-[0-9]+$'`；make rc=0（CHECK_DTBS 诊断不改变退出码） | `logs/dtbs_check-1-without-binding-patch.log` |
| 4 | dtbs_check **正对照**（工作区 apply sm8750 v1-0001 binding） | 同上 | rc=0，**无任何诊断** | `logs/dtbs_check-2-with-binding-patch.log` |
| 5 | dt_binding_check | `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- dt_binding_check DT_SCHEMA_FILES=Documentation/devicetree/bindings/arm/qcom,coresight-tnoc.yaml` | rc=0（CHKDT/LINT/STYLE/DTEX/DTC 全过） | `logs/dt_binding_check.log` |
| 6 | `git am` 可装性 | 干净 worktree `/tmp/kn-am` @ `aebb72744764`，`git am v1-0001-*.patch` | rc=0，作者与 subject 保真（封面无 diff，`git am` 报「补丁为空」属正常） | `logs/git-am.log` |
| 7 | dup-check | patchwork API `project=92`，`q=tnoc` / `q=primecell`，+ series 1206568 / 1214623 | **命中同型投递**：14995781（kaanapali periphid）/ 14995782（sm8750）/ 14995780（binding），且 v7 `[3/5][4/5]` state=`in-next` | `logs/patchwork-dupcheck.log` |

## 判定

1–6 全绿说明**草稿本身技术上可投**；#7 说明**不该投**：kaanapali 这一行与 14995781 同实质
（同一节点、同一 `0x000f0c00`），投出去是重复件，且与 `in-next` 的 `[v7,3/5]`（改平台总线绑定）冲突。

## 复现

```bash
cd /home/xuqianhui/y700-elden/build/elden-tree
git worktree add /tmp/kn-wt aebb72744764
cd /tmp/kn-wt && make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig
git am /home/xuqianhui/y700-elden/patches/upstream/kaanapali-tnoc-periphid-20261127/v1-0001-*.patch
# 负对照：此时直接跑
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CHECK_DTBS=1 -j4 qcom/kaanapali-mtp.dtb qcom/kaanapali-qrd.dtb
# 正对照：先打 binding（= 14995780 的同文）
git apply /home/xuqianhui/y700-elden/patches/upstream/sm8750-tnoc-periphid-20261127/v1-0001-*.patch
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CHECK_DTBS=1 -j4 qcom/kaanapali-mtp.dtb qcom/kaanapali-qrd.dtb
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- dt_binding_check \
  DT_SCHEMA_FILES=Documentation/devicetree/bindings/arm/qcom,coresight-tnoc.yaml
```
