# elden 板 DTS v8 备料（2026-11-21，**不投递**）

> 本目录只备料：v7 单提交 → v8（把两连接器/mux 形状并进板件）的差异、两种拆法裁决、门禁清单与实测。
> **零发信、零 commit 到仓库、零设备动作。** 上一代发信版 = `../board-dts-single-20261113-sent-20261117/`（v7，patchwork `14991580`，state=new，0 条回复）。
> 两连接器形状的来源 = `../dwc3-v10-20261120/elden-dts/`（v10 binding 下的真 DTB 门）；本目录把它提升为「可发信的补丁形状」。

---

## 0. 数字结论

| 项 | 实测 |
|---|---|
| v7 板 DTS | 129 行，**USB 相关命中 0**（无 `&usb`、无 connector、无 mux） |
| v8 板 DTS | 241 行（`+112/−0` 对 v7） |
| v8 全量改动 | 3 个文件：`qcom.yaml` 1 行 · `sm8750.dtsi` 1 行（label）· `sm8750-lenovo-elden.dts` 112 行 |
| `git am` 顺序应用（4 枚：qcom.yaml → v7 → label → mux） | **4/4 干净**（树 `/tmp/v8-am`，基点 `aebb727447` = 7.4-rc3） |
| `checkpatch --strict` | 新增两枚 **0E/0W/0C**（8 行 / 121 行）；qcom.yaml **0E/0W/0C**；v7 原样复跑 **0E/3W**（3 条都是树内缺件，见 §3.2） |
| `dtbs_check`（**带** v10 binding + qcom.yaml + wl2868c binding） | elden **0 诊断**，mtp/qrd 各 0，`DTC [C]` **3/3**；dtb md5 **`2d2d92662785a7aa07edb6aba78a9341`**（= v10 那轮逐字节同值） |
| `dtbs_check`（**不带** v10 binding，即 7.4-rc3 原树） | elden **8 诊断**，其中 5 条是 `mux-state`/`usb-role-switch`/`mux-controls` **unexpected** ⇒ 合并顺序依赖有实测证据（§2.3） |
| 负样例（真 DTB） | 两 endpoint 同 `mux-state` ⇒ **5 诊断**；删 `mux-controls` 保 `mux-state` ⇒ **8 诊断** |
| `dt_binding_check`（全量，含 v10 binding） | **rc=0**，5420 个 example `DTC [C]`，`error/warning` 行 **0** |

---

## 1. ① v7 单提交 ↔ v10 两连接器形状的差异清单

v7（`../board-dts-single-20261113-sent-20261117/0001-*.patch`）= 板骨架 + WL2868C 稳压器，**完全不写 USB**。
v10 那轮的形状（`../dwc3-v10-20261120/elden-dts/`）= 在板件里加 mux + 两个 connector + DWC3 endpoint 拆分。
两者都基于同一板文件，因此差异 = 纯增量（`before-vs-v8.diff`，2 个 hunk）。

| # | 文件 | 位置 | 新增内容 | v7 有？ | 依赖 |
|---|---|---|---|---|---|
| 1 | `arm/qcom.yaml` | `sm8750` 的 compatible `enum` | `- lenovo,elden` | **没有**（v6 3/5 有，v7 丢了） | 无（只 document 已有 compatible） |
| 2 | `sm8750.dtsi` | `usb@a600000` 的 `ports/port@0` | 节点标签 `usb_dwc3_hs_port:`（**1 行**，零行为） | 没有 | 无 |
| 3 | `sm8750-lenovo-elden.dts` | `wl2868c_vsys` 之后（hunk `@@ -55,6 +55,72 @@`） | `usb_hs_mux`（`gpio-mux`、`mux-gpios = <&tlmm 29 GPIO_ACTIVE_HIGH>`、`pinctrl-0 = <&eusb_mux_state>`）+ 根级 `usb_con_main`/`usb_con_second` 两个 `usb-c-connector`（各 `power-role/data-role = "dual"`，`port@0/endpoint`） | 没有 | v10 binding（`mux-controls`/`mux-state`） |
| 4 | 同上 | 文件尾（hunk `@@ -127,3 +193,49 @@`） | `&tlmm eusb_mux_state`（`pins="gpio29"; function="gpio"; drive-strength=<2>; bias-pull-down;`，**无 output-high/low**）；`&usb { dr_mode="otg"; mux-controls=<&usb_hs_mux>; status="okay"; }`；`&usb_dwc3_hs_port` 里 `/delete-node/ endpoint;` + `endpoint@0`（`reg=<0>`、`usb-role-switch`、`mux-state=<0>`、`remote-endpoint=<&usb_con_main_hs>`）+ `endpoint@1`（`reg=<1>`、`mux-state=<1>`、`remote-endpoint=<&usb_con_second_hs>`） | 没有 | 同上 |

要点（每条都能在文件里逐行核对）：

- **v7 连 `&usb` 都没 enable**（`status` 保持 dtsi 的 `disabled`）⇒ USB 在 v7 板上完全没有功能，语料里也不会有「两连接器」的暗示。
- 形状**不新增 SoC 侧无条件改动**：dtsi 只加一个标签，`port@0` 的两 endpoint 由板文件 `/delete-node/ endpoint` 后自己长出来（v9 那版在 dtsi 里无条件拆两 endpoint，会让 mtp/qrd 各多 2 条诊断，已废弃 —— 见 `../dwc3-v10-20261120/README.md` §7.2）。
- `usb-role-switch` **不需要**在 `&usb` 里加：`sm8750.dtsi:3205` 已经有（实测 `grep -n usb-role-switch sm8750.dtsi` = 3205），板级重复写属冗余（本轮试过一次，dtb md5 `2d2d9266…` 不变 ⇒ 证明已存在），已从候选补丁里撤掉。
- `dr_mode = "otg"` + `mux-controls` 是 `dwc3_role_mux_init()` 的进入条件之一（另一个是 dwc3 节点上的 `usb-role-switch`，dtsi 已提供；`dwc3_drd_init()` 里是 `device_property_read_bool(dwc->dev, "usb-role-switch")` 才走 `dwc3_setup_role_switch()`）。

---

## 2. ② v8 是否与板件合成同系列：两种拆法对比与推荐

前提事实（决定取舍的三条）：

1. **v7 是「同一系列的续版」**，不是 v1：编号必须续 v8（`../board-dts-single-20261113-sent-20261117/README.md` §1 的推理不变）。
2. **Krzysztof 的 one-logical-action 意见**针对的是「把**同一件事**（加这块新硬件）拆成 4/5+5/5」，不是禁止不同外设分开（`<20261104-elfish-booby-of-awe-27d2b6@quoll>`）。
3. **依赖是单向的**：板件的两连接器形状依赖 dwc3 v10 的 **1/3 binding** 先进树；dwc3 v10 不依赖板件（v10 cover 已写明 board DTS 不在本系列，0004 继续 hold）。不带 v10 binding 的树里，我们的板件会被打 **5 条 `mux-state`/`usb-role-switch`/`mux-controls` unexpected**（`evidence/gate-v8-nov10-dtbscheck.log`，8 诊断里 5 条属此）。

| 方案 | 形状 | 能先落的 | 风险 | 代价 |
|---|---|---|---|---|
| **A 一并**（单提交，3 文件全塞） | v8 = 1 枚（qcom.yaml + dtsi label 折进板件提交） | 无：整枚等 v10 binding | 板件被一个**还没 review 完**的 binding 拖住；维护者大概率回「binding 未进树」；dtbs_check 在他树上必红 | 一次 review 覆盖全部；若 v10 有改动要连带重投板件 |
| **B 分开**（推荐） | **v8 = 2 枚**：`0000 qcom.yaml`（1 行）+ `0001 = v7 原文不动`；USB 部分（dtsi label + 板件 mux/两连接器）等 v10 进树后作 **v9** 单投（1–2 枚） | **v8 立刻可投**：只补 v7 缺的 compatible 文档，零依赖、零诊断新增 | v9 要再发一次邮件（+1 个版本号） | 板上 USB 功能晚一个批次；但 v7 现在本来就 0 回复，先让它能被 review |
| C 只补 binding 不碰 USB | v8 = `0000` 单枚 | 同 B，且更小 | 板件与 USB 分两次 review，但 v9 仍要整段 mux | 最小可投面；缺点是 v8/v9 两轮都在改同一文件 |

**推荐 = B**，理由按权重：

1. **依赖方向**：USB 板件部分在任何未合 v10 的树上都过不了 `dtbs_check`（实测 5 条），投出去只能换来「等 binding」。而 v7 现在**真的缺** `lenovo,elden` 文档（`dtbs_check` 2 条 + `checkpatch` 1 条 W 都是它）⇒ 这是唯一一条「不依赖任何在飞系列、且能立刻减少诊断」的改动。
2. **不违反 one-logical-action**：v8 的两枚是「document 已有 compatible」+「加这块硬件」两件事，本来就该分开（v6 3/5 就是这个形状，只是被 v7 折掉了）。
3. **v10 的 0004 已经 hold**，说明「板件晚于 binding」本来就是既定节奏；B 只是把它显式化，避免整块板文件陪跑。

选 A 的唯一合理场景：v10 binding 在下一轮就被接收，且希望「板件只发一次」。此时 A 的 cover 必须显式写「本系列 1/3 依赖 dwc3 v10（binding）先进树」，否则会被当噪声。

**产物**：`0000-dt-bindings-arm-qcom-document-the-Lenovo-Legion-Y700.patch`（= v6 3/5 原文件，本轮实测对 7.4-rc3 **`git apply --check` rc=0**，可直接复用）+ `0001/0002`（v9 用的两枚：dtsi label + 板件 mux，形状已按 B 设计，v9 时再决定合不合）。

---

## 3. ③ 门禁清单与实测

### 3.1 清单（本轮跑了的 + 跑不动的）

| 门 | 命令形状 | 本轮 | 结果 |
|---|---|---|---|
| G1 顺序 apply | `git am` 4 枚（qcom.yaml → v7 → label → mux），基点 `aebb727447` | 跑了 | **4/4** |
| G2 `checkpatch --strict` | `perl scripts/checkpatch.pl --strict --no-signoff <patch>`（**树模式**，不带 `--no-tree`） | 跑了 | 新增两枚 **0E/0W/0C**；qcom.yaml **0E/0W/0C**；v7 **0E/3W** |
| G3 `dtbs` 编译 | `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- qcom/sm8750-lenovo-elden.dtb` | 跑了（`O=/tmp/kb-v8-check`，`-j4`+`nice -n 15`+`flock`） | rc=0，`DTC` 1 次，无 dtc 警告 |
| G4 `dtbs_check`（带依赖） | `CHECK_DTBS=1 qcom/{sm8750-lenovo-elden,sm8750-mtp,sm8750-qrd}.dtb`，**不带** `DT_SCHEMA_FILES` | 跑了 | **3/3 `DTC [C]`，elden 0 诊断**（mtp/qrd 0） |
| G5 `dtbs_check` 对照（不带 v10 binding） | 同 G4，树 = 7.4-rc3 原样 | 跑了 | elden **8 诊断**（5 条 mux/usb 相关）⇒ 依赖实证 |
| G6 负样例（真 DTB） | 两 endpoint 同 `mux-state`；删 `mux-controls` 保 `mux-state` | 跑了 | **5** / **8** 诊断，首行分别 `ports:port@0: 'oneOf' conditional failed`、`endpoint@0: False schema does not allow 0` |
| G7 `dt_binding_check` | `rm -f processed-schema.json && make ... -j4 dt_binding_check`（全量 5959 schema） | 跑了 | **rc=0**，5420 example `DTC [C]`，0 error/warning 行 |
| G8 上机 | — | **没跑**（离线；执行单见 `reports/upstream-queue-prep-20261121.md` §3） | — |
| G9 `DT_SCHEMA_FILES` 形状 | — | **故意不跑** | 公共片段无 `select:` ⇒ 恒空转假绿（`PITFALLS #696`、`../dwc3-v10-20261120/README.md` §4） |

跑不动/不需要的项与原因：

- **G7 上机**：设备离线（本轮硬约束「不碰设备」）；执行单已写好在报告 §3。
- **`dt_binding_check` 对 DTS 补丁本身**：DTS 不改 binding，这个门只在「树里有改过的 yaml」时才有意义；本轮跑它是为了证明 **v10 binding 在树里仍是 0 诊断**（G7 门实际是 dwc3 v10 的门，不是本补丁的门）。
- **`make dtbs`（全量）**：只编目标三份 DTB，不整包 —— 全量 dtbs 与结论无关且要在高负载机上跑 20+ min。

### 3.2 v7 的 3 条 W（复跑确认，不是本轮引入）

```
WARNING: added, moved or deleted file(s), does MAINTAINERS need updating?
WARNING: DT compatible string "lenovo,elden" appears un-documented -- check ./Documentation/devicetree/bindings/
WARNING: DT compatible string "willsemi,wl2868c" appears un-documented -- check ./Documentation/devicetree/bindings/
total: 0 errors, 3 warnings, 0 checks, 136 lines checked
```

- 第 2 条 = **本目录 `0000` 要修的**（v6 3/5 从来没过，v7 折掉了它）。
- 第 3 条 = `willsemi,wl2868c` binding 已于 2026-11-21 进 `regulator.git for-7.5`（INDEX §0），树里带上后自然消失（本轮把该 binding 打进门树后，`dtbs_check` 最后 1 条诊断正是它，加 binding 后 **0**）。
- 第 1 条 = 新文件提示，qcom 板级 dts 已被 MAINTAINERS 覆盖，纯提示。

### 3.3 复现命令（逐条可直接跑）

```sh
# 建门树（7.4-rc3 + v10 binding + qcom.yaml + wl2868c binding）
cd /home/xuqianhui/y700-elden/build/elden-tree && git worktree add --detach /tmp/v8-am aebb727447
cd /tmp/v8-am
git am /home/xuqianhui/y700-elden/patches/upstream/elden-dts-v8-prep-20261121/0000-*.patch
git am /home/xuqianhui/y700-elden/patches/upstream/board-dts-single-20261113-sent-20261117/0001-*.patch
git am /home/xuqianhui/y700-elden/patches/upstream/elden-dts-v8-prep-20261121/000{1,2}-*.patch   # 4/4

# checkpatch（树模式）
cd /tmp/v8-am && for p in /home/xuqianhui/y700-elden/patches/upstream/elden-dts-v8-prep-20261121/000{0,1,2}-*.patch; do
  perl scripts/checkpatch.pl --strict --no-signoff "$p" | grep -E '^(ERROR|WARNING|total)'
done

# dtbs_check（关键：不带 DT_SCHEMA_FILES；门树需先装 v10 binding 1/3 + wl2868c binding）
patch -p1 < /home/xuqianhui/y700-elden/patches/upstream/dwc3-v10-20261120/v10-0001-*.patch
patch -p1 < /home/xuqianhui/y700-elden/patches/upstream/wl2868c-v12-20261117/v12-0001-*.patch
rm -f Documentation/devicetree/bindings/processed-schema.json
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j4 dt_binding_schemas
rm -f arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CHECK_DTBS=1 -j4 \
     qcom/sm8750-lenovo-elden.dtb qcom/sm8750-mtp.dtb qcom/sm8750-qrd.dtb
# 判绿：DTC [C] ×3，^arch/.../elden.dtb: 行数 = 0（cmd_dtb_check 末尾有 || true，rc 不可信）
```

负样例复跑：把 `mux-state = <1>` 改成 `<0>`（两 endpoint 同值）或删掉 `&usb` 里的 `mux-controls` 行后重编同一目标，期望 5 / 8 条诊断。

---

## 4. 未尽项（下一轮入口）

1. **上机（G8）**：mux 实际切换/两口枚举/角色切换都没验；GPIO 29 的语义/极性/`mux-state 0/1 ↔ 长边短边` 仍无硬件证据（`../dwc3-v10-20261120/README.md` §7.1）。执行单 = `reports/upstream-queue-prep-20261121.md` §3。
2. **形状仍不是最终拓扑**：真机两口在 `pmic-glink` + `ucsi` 下，`port@1` 才是 SS + 每口一颗 `fsa4480`；本轮两个**根级** `usb-c-connector` 只表达「HS 各一个座」。DP/altmode 无法在本 DTS 上测（`usb_dp_qmpphy` 仍 `disabled`）。
3. **`0001` 的 dtsi 标签**是否愿意单独成一枚（而非折进板件），要按维护者上一轮的偏好再判一次；本轮两枚都可 apply，两种折法成本一样。
4. **v8 的 cover**：若走 B，cover 只需一句「v7 + document the compatible」；若走 A，必须写依赖（否则会被当噪声）。
5. 本目录**没有**发信、没有 `git send-email`、没有 commit 到仓库（只在 `/tmp/elden-v8-1121` 里做了临时提交以便 `format-patch`）。

---

## 5. 文件清单

| 文件 | 内容 |
|---|---|
| `0000-dt-bindings-arm-qcom-document-the-Lenovo-Legion-Y700.patch` | 复用 v6 3/5 原件（v8 方案 B 的第 1 枚） |
| `0001-arm64-dts-qcom-sm8750-label-the-DWC3-High-Speed-port.patch` | dtsi 1 行标签（v9 用） |
| `0002-arm64-dts-qcom-sm8750-lenovo-elden-describe-the-USB-.patch` | 板件 mux + 两 connector + endpoint 拆分（v9 用） |
| `sm8750-lenovo-elden.dts` | 应用全部改动后的板文件全文（241 行，供逐行核对） |
| `before-vs-v8.diff` | v7 板文件 → v8 板文件的 unified diff（125 行，2 hunk） |
| `evidence/` | 8 份门日志 + `checkpatch.txt`（`gate-v8-final-3dtb` / `gate-v8-nov10-*` / `gate-neg-*` / `gate-binding-v8` / `gate-with-{qcomyaml,all-prereq}`） |
| `SHA256SUMS` | 本目录全部文件的 sha256 |
