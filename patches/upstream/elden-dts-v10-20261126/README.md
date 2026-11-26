# elden 板 DTS v10 备料（**未投递**、未 commit）

> 用途：回应 sashiko 对 **v9 2/2** 的第 3 条 `[Medium]`（`missing vin*-supply
> properties on pmic@2f for active LDOs`）——**唯一改动**= `pmic@2f` 补四条输入轨。
> 定因链与判据原文：`reports/elden-v10-vin-supply-20261126.md`。
> 上一代：`../elden-dts-v9-20261126/`（已投，`SENT.md`）。

## 文件

| 文件 | 说明 |
|---|---|
| `v10-0000-cover-letter.patch` | cover（AI 披露 + 逐条答 sashiko 三条 + Changes since v9；**保留** Krzysztof 要的 `Waiting on bindings` 段） |
| `v10-0001-…qcom-document-the-Lenovo-Legion-Y700.patch` | 1/2 = v9 1/2 逐字节相同（只改代次），diff 段未变 |
| `v10-0002-…sm8750-lenovo-elden-add-…Gen4.patch` | 2/2 = v9 2/2 + 四条 `vin*-supply` + 一处注释 |
| `cover.txt` | cover 正文（纯文本，`SEND.sh` 不依赖，供人读/复用） |
| `GATES.md` | 门禁账（逐门 rc + 原始输出指针） |
| `SEND.sh` | 投递脚本；**默认只做本地检查**，`--dry-run` 才连 send-email 的 dry-run，`--send` 才真发 |
| `SHA256SUMS` | 三枚 patch 的 sha256 |
| `logs/` | 每道门的原始输出 |

## 改动（2/2，唯一实质改动）

`arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts`：

```diff
 	pmic@2f {
 		…
 		pinctrl-0 = <&camera_pmic_default>;
+		vin12-supply = <&wl2868c_vsys>;
+		vin34-supply = <&wl2868c_vsys>;
+		vin5-supply = <&wl2868c_vsys>;
+		vin7-supply = <&wl2868c_vsys>;
 		vsys-supply = <&wl2868c_vsys>;
```

外加 `wl2868c_vsys` 上那段注释扩写成「VSYS + 四个 LDO 输入都吃这条常开轨」。

**为什么不另起新节点**：这五条输入在板上同属一条常开系统轨，DT 里已用一个
`regulator-fixed` 兜住（SPMI PMIC 未描述）；同一 phandle 指向多个输入是 upstream
既有形状（`regulator/isl9305.txt` 的 `VINDCD1/2`、`VINLDO1/2` 四个都指
`&system_power`）。**VIN6 不加**：LDO6 本板未引出，ldo6 节点也不存在（与 v9 同）。

## 需要编排者/作者决定的一件事

**1/2 的 `Acked-by: Krzysztof Kozlowski` 没加进补丁体**：本轮任务口径是「与 v9 同套，
只改需要的那个文件」，所以 1/2 只改了代次。若要在 v10 里带上该 trailer（v9 投出前
12 h 给过，b4 也能自取），需在 `v10-0001` 的 `Signed-off-by` 后插一行并重算
`SHA256SUMS`；本目录**未做**这一步，交由作者在投递前定。

## 门禁结论（细节与原始输出见 `GATES.md`）

| 门 | 结果 |
|---|---|
| `git apply --check -v` | 2/2 **rc=0**，无 offset/fuzz |
| `git am --keep-cr` | 2/2 **干净**；提交日期 `2026-11-26 21:00:00 +0800` |
| `checkpatch.pl --strict --no-signoff` | 1/2 **0E/0W/0C**；2/2 **0E/1W/0C**（新文件 MAINTAINERS 提示，v7/v8/v9 同款，不修） |
| `dt_binding_check`（定向 `arm/qcom.yaml`，1/2 改了 binding） | **rc=0**，静默 |
| `dt-doc-validate …/arm/qcom.yaml` | **rc=0** |
| `dtbs_check CHECK_DTBS=1`（elden/mtp/qrd） | 3/3 `DTC [C]`；**无 binding 时诊断 1/0/0**（= v9 同款、唯一一条兼容性缺 schema）；**apply wl2868c binding 后 0/0/0** |
| DTB md5 | elden `50f7cede…`（v9 `4707d3de…`，按预期变）；mtp 仍 `ecc15876…` 不变；**apply 与 am 两条路线逐字节相同** |
| DTB 反编译 diff（v9 vs v10） | **只多四条 `vin*-supply`**（注释不进 DTB），`logs/dtb-decompile-diff-v9-vs-v10.txt` |
| 上机 | **未做**（板件无 SPMI/RPMh/console 描述，起不到 shell；本轮只做机械门） |

## 纪律

- **未发信**：本目录任何脚本都未执行发信路径；`SEND.sh` 默认 `local` 模式。
- **未 `git commit` 仓库**：补丁由一次性 worktree `/tmp/v10wt` 内两个临时提交
  `git format-patch` 生成后落到本目录，仓库工作区未增删。
- 基线 = `build/elden-tree` 的 `aebb72744764`（Linux 7.4-rc3，与 v8/v9 同一基线）。
