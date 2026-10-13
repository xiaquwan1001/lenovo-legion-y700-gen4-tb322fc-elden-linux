# M3 板支持系列（2026-10-13）

上游基线：
- **pristine 参照 = tag 提交** `24a19b953e`（`Linux 7.3-rc7`）。「以 `build/m2-worktree` 当 pristine」是错的——它是工作树，当前 = pristine + 本片补丁（tip `6d73764570`）。重建 pristine 参照：`git -C geekidos-linux worktree add --detach <dir> 24a19b953e`。
- 本片工作树 = `build/m2-worktree`，分支 `m3/usb-psy-name`（tip `6d73764570`）；独立复核树 = `build/m3-verify-0001`。
规则 = `reports/upstream-policy-20261013.md`；分片与验收口径 = `reports/m3-series-plan-20261013.md`。

## M3-1 USB 双连接器片 —— 3 枚就绪（未发送）

| 补丁 | 主题 | 内容 |
|---|---|---|
| `0001-dt-bindings-usb-snps-dwc3-document-usb-psy-name.patch` | `dt-bindings: usb: snps,dwc3: document usb-psy-name` | 补上游文档缺口：驱动已读该属性而 `Documentation/` 无任何描述 |
| `0002-dt-bindings-usb-snps-dwc3-describe-the-two-connector.patch` | `dt-bindings: usb: snps,dwc3: describe the two-connector HS data path` | `port-select-gpios` + `ports` 端点 `mux-state`/`usb-role-switch` + `$defs/hs-port` + 条件校验 |
| `0003-usb-dwc3-support-two-connectors-sharing-one-HS-data-.patch` | `usb: dwc3: support two connectors sharing one HS data bus` | `core.h`（`dwc3_role_mux`/`dwc3_role_port`）、`core.c`（`__dwc3_set_mode` 在旧 host/gadget 拆除后切数据通道）、`drd.c`（每连接器一个 role switch + 互斥仲裁 + 状态机）、`debugfs.c`（mux 存在时拒写 `mode`） |

**验收证据（全部本机实跑）**

| 门 | 命令 | 结果 |
|---|---|---|
| checkpatch | `scripts/checkpatch.pl --strict --no-tree patches/upstream/m3-2026-10-13/*.patch` | 3/3 **0E/0W/0C**「ready for submission」 |
| binding 自检 | `dt-doc-validate …/snps,dwc3-common.yaml` | **rc=0** |
| 编译 | `make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- drivers/usb/dwc3/` | **rc=0**，无 error/warning（`core.o`/`drd.o`/`debugfs.o` 重编） |
| 对板 DTB 的效果（三点对照，pristine binding 为 `24a19b953e`） | 板 DTB `dt-validate -s <pristine>/Documentation/devicetree/bindings` | pristine **382 行 / usb 节点 3 / endpoint 2** → +0001 **380 / 2 / 2**（`usb-psy-name` 诊断 2→1）→ +0001+0002 **372 / 0 / 0**（`usb-psy-name` 0）⇒ `UPSTREAM-REVIEW` §3.4 点名的红点由 **0002 消掉**，0001 只去掉 `dt-core.yaml` 的冗余类型诊断 |

**设计取舍（重要，供 review 与后续片复用）**

- **不改 `pre_set_role` 签名**：payload 原版把 `struct dwc3_glue_ops.pre_set_role` 改成返回 `int` 并导出 `dwc3_qcom_glue_ops`；而上游 v7.3-rc7 已把 `dwc3_qcom_set_role_notifier` 重写为 `void` + `current_role` 去抖。直接移植会**回退上游新代码**，故本系列保留上游 `void` 签名——mux 路径不依赖该返回值，只影响单连接器路径的错误上报（可另立小补丁）。
- **`usb-psy-name` 的归属**：它是上游驱动在用、上游 binding 未文档化的属性 ⇒ 补在 `snps,dwc3-common.yaml` 是对的（不是"vendor 私货写进通用文件"）。
- **板 DTS 侧**：`&usb` 的 `port-select-gpios` / `ports` 段随 **M3-2 板基础片** 一起发（板本身尚未上游）。
- payload 的 `dwc3_check_halted()` 未纳入（payload 私有辅助），若 review 需要可另议。

## 独立复核（lane D / `ustc-audit`，2026-10-13）

复核报告：`reports/m3-1-0001-verify-20261013.md`（编排者已对关键项二次复跑，见下）。

| 项 | 结论 |
|---|---|
| 补丁可干净应用到 pristine | ✅ `git am` rc=0（审计树 `build/m3-verify-0001`） |
| `dt-doc-validate` / `checkpatch --strict` / `send-email --dry-run` | ✅ 与本文数字一致 |
| 0001 的效果 | ✅ 复核确认：**仅** −2 行、`usb-psy-name` 诊断 2→1；**单独 0001 不能让该节点合规** |
| 「`qcom,sm8750-dwc3` 未在上游登记 ⇒ 节点根本不合规」 | ❌ **已被编排者复跑推翻**：pristine `qcom,snps-dwc3.yaml` 第 77/228/576 行已列该 compatible；节点残留诊断在 +0002 后归零 |
| 环境说明需限定 | ✅ 采纳：`git send-email` 在 git 2.53 无 `--no-confirm`，用 `--confirm=never`；`get_maintainer.pl` 须在树根运行 |
| 反证（改名后诊断数回到基线） | ✅ 测量方法有效 |

## 待做

| 片 | 内容 |
|---|---|
| M3-2 | 板基础片（UFS/PMIC regulator/TLMM/gpio-keys/ramoops/framebuffer/pmic-glink + `&usb` 段）；切分台账 = `reports/m3-2-board-basics-split-20261013.md`（⛔ 空骨架，待重建），依赖面 = `reports/m3-missing-support-matrix-20261013.md` |
| M3-3..M3-6 | 音频/显示/相机/无线；依赖面与 Q2 偏离 = `reports/m3-missing-support-matrix-20261013.md` |

## 发送纪律

英文 commit + `Signed-off-by: Xu Qianhui <xiaqinghuan@mail.ustc.edu.cn>`；在**树根**跑 `scripts/get_maintainer.pl` 取收件人；`git send-email --dry-run --confirm=never`（git 2.53 无 `--no-confirm`）通过后发送；lore 复核归档（技能 `upstream-mail-ustc`）。
