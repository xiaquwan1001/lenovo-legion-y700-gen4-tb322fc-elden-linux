# M3 板支持系列（2026-10-13）

上游基线：`torvalds/v7.3-rc7`（`24a19b953e`）；工作树 = `build/m2-worktree`，分支 `m3/usb-psy-name`（tip `6d73764570`）。
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
| 对板 DTB 的效果 | 板 DTB 对**纯上游 binding + 本系列**校验 | 诊断 **382 → 372** 行；`usb@a600000` 与 `endpoint` 相关诊断 **3 + 2 → 0**（即 `UPSTREAM-REVIEW` §3.4 点名的红点被本片消掉） |

**设计取舍（重要，供 review 与后续片复用）**

- **不改 `pre_set_role` 签名**：payload 原版把 `struct dwc3_glue_ops.pre_set_role` 改成返回 `int` 并导出 `dwc3_qcom_glue_ops`；而上游 v7.3-rc7 已把 `dwc3_qcom_set_role_notifier` 重写为 `void` + `current_role` 去抖。直接移植会**回退上游新代码**，故本系列保留上游 `void` 签名——mux 路径不依赖该返回值，只影响单连接器路径的错误上报（可另立小补丁）。
- **`usb-psy-name` 的归属**：它是上游驱动在用、上游 binding 未文档化的属性 ⇒ 补在 `snps,dwc3-common.yaml` 是对的（不是"vendor 私货写进通用文件"）。
- **板 DTS 侧**：`&usb` 的 `port-select-gpios` / `ports` 段随 **M3-2 板基础片** 一起发（板本身尚未上游）。
- payload 的 `dwc3_check_halted()` 未纳入（payload 私有辅助），若 review 需要可另议。

## 待做

| 片 | 内容 |
|---|---|
| M3-2 | 板基础片（UFS/PMIC regulator/TLMM/gpio-keys/ramoops/framebuffer/pmic-glink + `&usb` 段）；依赖 lane-B 的切分台账 |
| M3-3..M3-6 | 音频/显示/相机/无线，依赖 lane-C 的缺口矩阵 |

## 发送纪律

英文 commit + `Signed-off-by: Xu Qianhui <xiaqinghuan@mail.ustc.edu.cn>`；`get_maintainer.pl` 收件人 + `git send-email --dry-run` 通过后发送；lore 复核归档（技能 `upstream-mail-ustc`）。
