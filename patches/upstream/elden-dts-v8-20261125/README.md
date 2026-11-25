# elden 板 DTS —— v8 发信就绪包（2026-11-25，**未投递**，等 §7 逐系列放行）

> 件：`v8-0000-cover-letter.patch` + `v8-0001`（binding 一行）+ `v8-0002`（板件，= v7 原文）。
> 本目录**只做备料**：没有发信、没有 commit 到内核树、没碰设备。
> 上一代 = `../board-dts-single-20261113-sent-20261117/`（v7，2026-11-17 已投，patchwork `14991580`，维护者 0 回复）。

## 1. 为什么有 v8（v7 的硬缺口）

v7 只投了 Makefile + 板件，**没有**把 `lenovo,elden` 写进 `Documentation/devicetree/bindings/arm/qcom.yaml`
⇒ 板子树能编但 `dtbs_check` 直接判根节点不合法（实测原文见
`logs/dtbs-check-no-binding-entry-20261125.log`）：

```
sm8750-lenovo-elden.dtb: / (lenovo,elden): compatible: 'oneOf' conditional failed ...
sm8750-lenovo-elden.dtb: /: failed to match any schema with compatible: ['lenovo,elden', 'qcom,sm8750']
```

v8 = v7 板件原封不动 + 补上那一行（`qcom.yaml`）。**没有其它内容改动**（2/2 的 diff 段与 v7 逐字节相同）。

## 2. 与 Pengyu Luo v2 的关系（投前硬要求，已写进 cover）

- 同一文件由 **Pengyu Luo** 先投：`[PATCH v2 0/2] Introduce Lenovo Legion Y700 Gen4`（2026-07-26，1170 行，based on `sm8750-qrd`）；
  状态 = `changes-requested`（Abel Vesa 2026-07-27、Konrad Dybcio 2026-09-02 都 review 过），**无 v3、未合入**。
- **2026-10-25 双方已确认移交**（Pengyu 原话「squash them and send the whole thing your way」）⇒ 本系列
  **supersedes** 其 v2，不是抢投。证据与回撤经过 = `reports/dup-check-20261125.md` 附节。
- `1/2` 的那一行 = 他 v2 里加的同一行 ⇒ cover 里如实署名，并请他指定 trailer 形式
  （`Co-developed-by` 需连带他的 `Signed-off-by`，我方**不代签**）。

## 3. 门禁（2026-11-25 现跑，基线 = 干净 worktree `aebb727447` = v7.4-rc3）

| 门 | 命令要点 | 结果 | 日志 |
|---|---|---|---|
| apply | `git apply --check` ×2（无 offset/fuzz） | rc=0 / rc=0 | — |
| blob 对照 | 落树 `git hash-object` = patch `index` 右值 | `qcom.yaml a32cfb30a1` / `Makefile e0b65a36c5` / 板件 `73f4452f46` **全等** | — |
| checkpatch | `--no-tree --strict --no-signoff - < patch`（**必须 stdin**，`PITFALLS #725`） | 1/2 **0E/0W/0C**；2/2 **0E/1W/0C**（新文件 MAINTAINERS 提示） | `logs/checkpatch-v8-000*.txt` |
| dtbs_check | `CHECK_DTBS=1 … qcom/sm8750-{lenovo-elden,mtp,qrd}.dtb` | 3/3 编译通过；板件 **1 条**诊断（= WL2868C binding 未进树，见 §4），mtp/qrd **0 条** | `logs/dtbs-check-3dtb-20261125.log` |
| dt_binding_check | `DT_SCHEMA_FILES=…/arm/qcom.yaml` | **rc=0**，无错误（LINT/STYLE 均过） | `logs/dt-binding-check-qcomyaml-20261125.log` |
| 负样例 | 去掉 1/2 后重跑 dtbs_check | 根节点被判不合法（原文见 §1）⇒ 1/2 是**必需件**，不是凑数 | `logs/dtbs-check-no-binding-entry-20261125.log` |

## 4. 已知依赖 / 未做（cover 里已如实写）

1. **WL2868C binding/driver 不在 v7.4-rc3**（已进 `regulator.git for-7.5`：`84e67d2ee13f` + `602f57223457`）⇒
   板件唯一那条诊断来自它，7.5 合并窗口后自然消失。**不隐藏**。
2. **SPMI PMIC / RPMh regulators / console 仍未描述** ⇒ 本系列「自身不能起飞」；这是 v6 线程就提出的
   「骨架板」判定，未变，也不在本系列解决。
3. **上机面**：板件描述来自作者本机（vendor 血统 7.3 内核跑着的同一台），**v7.4-rc3 树没有在该机上启过**
   ⇒ cover 不作启动声明（只声明 dtbs/dt_binding/checkpatch/apply 四类机械门）。
4. USB 两口部分**不在本系列**（依赖 dwc3 `[PATCH v15 0/3]`，在审），备料留在
   `../elden-dts-v9-prep-20261124/`。

## 5. 发信

`bash SEND.sh`（默认 dry-run）→ 放行时 `bash SEND.sh --send`。
收件人 = `get_maintainer.pl` 现查（Bjorn/Konrad/Abel/Rob/Krzysztof/Conor + `linux-arm-msm` / `devicetree` / `linux-kernel`），
另 **Cc Pengyu Luo**（关系声明需要他在线程里）。

## 6. 文件清单

| 文件 | 内容 |
|---|---|
| `v8-0000-cover-letter.patch` | cover（supersedes 声明 + 依赖 + 门禁 + 上机声明 + AI 披露） |
| `v8-0001-dt-bindings-arm-qcom-document-the-Lenovo-Legion-Y700.patch` | `qcom.yaml` +1 行（原件 = v6 3/5，Date/Subject 换 v8） |
| `v8-0002-arm64-dts-qcom-sm8750-lenovo-elden-add-Lenovo-Legion-Y700-Gen4.patch` | 板件（= v7 原文，129 行 + Makefile 1 行） |
| `SEND.sh` | dry-run/真发脚本（与 dwc3 目录同形） |
| `logs/` | 5 份门日志（checkpatch ×2、dtbs ×2、dt_binding ×1） |
| `SHA256SUMS` | 本目录全部件 sha256 |
