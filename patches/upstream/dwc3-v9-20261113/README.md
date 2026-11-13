# dwc3 v9 备料（2026-11-13，DRAFT，未发送）

> 状态：**未投**。发信属 A4，需用户逐系列批准。上一版 = `patches/upstream/m3-dwc3-v7-20261106/`（实发 v8）。
> 本目录 = v8 → v9 的三件改造全部落地（binding 草案沿用 11-11 的 `dwc3-v9-draft-20261111/`）+ 门禁全绿 + 兼容性结论。

## 1. Rob 意见 → v9 落地对照

来源：Rob Herring 2026-11-10T16:36Z 对 `[PATCH v8 0/3]`（原文 `out/mail-20261111/robh-20261110T1636Z-raw.txt`）。

| Rob 意见 | v9 落地 | 证据 |
|---|---|---|
| 「port@0 should have 2 endpoints and port@2 dropped」 | binding（1/1 重写，沿用 11-11 草案）：`hs-port` = 一个 port 两个 endpoint（`endpoint@0/endpoint@1` 各带 `reg`，`oneOf` 强制 mux-state 互斥），`port@2` 全线删除 | `v9-0001-…patch`（142 行 checked） |
| 「Use the gpio mux binding」 | binding：删私有 `port-select-gpios`，改 `mux-controls`（phandle → `gpio-mux`，`#mux-control-cells = <0>`）；driver：`devm_mux_control_get(dev, NULL)` + `mux_control_select(mux, endpoint->mux_state)`（endpoint 的 `mux-state` 即 mux state） | `v9-0003`（`drd.c` init + `core.c` port_switch 块） |
| （结构）DTS 随新形状 | sm8750.dtsi `port@0` 拆成 `endpoint@0/endpoint@1`（`usb_dwc3_hs` 标签保持在 endpoint@0，mtp/qrd 板不受影响）；elden 板新增 `gpio-mux`（GPIO 29）+ `mux-controls` + 两个 endpoint 的 `usb-role-switch`/`mux-state` | `v9-0004` |

## 2. mux 持锁 × role-switch 回调上下文兼容性评估（B6 要求的结论）

**结论：可投。约束不变量与 v8 相同，mux API 没有引入新的原子上下文要求。**

- `mux_control_select()` / `mux_control_deselect()` 内部持 mutex、可睡眠（`drivers/mux/core.c`）。
- v9 中二者的**唯一调用点是 `__dwc3_set_mode()`**，它跑在 `system_freezable_wq` 工作线程（进程上下文、可睡眠）。
- role-switch 的 `set()` 回调（`dwc3_mux_role_set()`）**不直接碰 mux**：它只在 `dwc->lock` 下登记 role/desired_port，然后 `queue_work()`。该回调自身本来就要求可睡眠上下文（持 `mux->lock`、调可睡眠的 `dwc3_pre_set_role()`→ pm_runtime）——这是 v7/v8 就有的不变量，Rob/v8 评审未提异议。
- 若某连接器驱动在原子上下文调 `set()`，v8（mutex + queue_work）同样会炸，**不是 v9 新增面**。
- 设计注记：mux 在两次切换之间保持 selected（dwc3 是唯一 consumer、恒驱动两口之一）；首.mode 请求 select state 0（mux 控制器不可读回，v8 靠 `gpiod_get_value` 读启动电平的能力消失，见 0003 commit message 第 2 段——这是行为差异，已在正文如实披露）。

## 3. 门禁账（2026-11-13 实跑，树 `build/m3v2-7.3rc7`，base `f66469d9905`）

| 门 | 命令 | 结果 |
|---|---|---|
| G1 编译 | `. scripts/env-build.sh && kbuild drivers/usb/dwc3/`（ARCH=arm64，`CONFIG_MULTIPLEXER=y`） | **rc=0**，无 warning/error |
| G2 DTB | `kbuild qcom/sm8750-lenovo-elden.dtb` | **rc=0**，无诊断 |
| G3 dt_binding_check | `kbuild dt_binding_check DT_SCHEMA_FILES=Documentation/devicetree/bindings/usb/snps,dwc3-common.yaml`（v9 yaml 就位） | **rc=0**，SCHEMA/CHKDT/LINT/STYLE 无诊断 |
| G4 dtbs_check | `kbuild CHECK_DTBS=y DT_SCHEMA_FILES=usb/snps,dwc3-common.yaml qcom/sm8750-lenovo-elden.dtb` | **rc=0**，无诊断 |
| G5 checkpatch | `scripts/checkpatch.pl --no-signoff --no-tree` × 4 枚 | **0 errors / 0 warnings**（0001=142 行、0002=63、0003=567、0004=52 checked） |
| G6 整串 apply | pristine 树（`git archive HEAD`）逐枚 `git apply --check` | **4/4 OK** |

- 树操作纪律：门禁用临时覆盖法（7 个文件先备份到 `/tmp/b6-backup/`，跑完全部还原；`git status` 复核与开工前一致）。G3/G4 的 v9 yaml 同法。
- binding 正/负样例门（dt-validate × 4）已于 11-11 跑过：`patches/upstream/dwc3-v9-draft-20261111/README.md` §3（正样例 PASS、三负样例分别被 `oneOf`/`endpoint@1 必需`/`#address-cells 必需` 拒）。v9 yaml 自那之后零改动。

## 4. 文件清单

- `v9-0000-cover-letter.patch`（DRAFT，含门禁摘要）
- `v9-0001-dt-bindings-usb-snps-dwc3-two-connectors-one-hs-bus.patch`（= 11-11 草案，未改）
- `v9-0002-usb-roles-look-up-role-switches-attached-to-a-graph-endpoint.patch`（= v8 2/3，Rob 未提意见，原样保留）
- `v9-0003-usb-dwc3-select-the-shared-HS-data-bus-with-a-mux.patch`（GPIO → mux_control，4 文件 +567 行 diff）
- `v9-0004-arm64-dts-qcom-sm8750-describe-the-two-connector-sh.patch`（dtsi 双 endpoint + elden 板 mux）

## 5. 未证 / 遗留

1. **未上机**（按派工单，上机归下一轮）：mux 切换的运行期行为（含 GPIO 29 复用冲突、SDP/PD 两口枚举）未验。
2. v8 cover 的「12 次拔插 0 WARNING」证据仍属**旧 GPIO 代码**；v9 的 mux 路径无运行期证据，cover 已如实。
3. 0004 的「两口分别连什么 remote-endpoint」在 elden 板上还缺 typec connector 节点（板级 DTS 尚未描述连接器），本补丁只把 mux 形状立起来；连接器节点属 A5 板级 DTS 串的范围。
4. 投递收件人沿用 v8 清单（Greg/Thinh/Rob/krzk/conor + linux-usb/devicetree/linux-arm-msm/lkml）；发信时 base 需按 X10 再确认（7.4-rc2 线 vs 7.4-rc3 重放线）。
