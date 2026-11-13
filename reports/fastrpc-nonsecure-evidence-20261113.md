# fastrpc「为什么不能只写 non-secure 一行」证据包（B7）

> 只读 lane，2026-11-13 晚。未改树、未发信、未上机。所有行号取自
> `build/m3v2-7.3rc7` 的 `gh/master = 9d66f26fefa`（7.4-rc3）。

## §0 结论

1. **M10 v3（`arm64: dts: qcom: sm8750: mark the ADSP fastrpc node as non-secure domain`）
   本轮不改形状、不重投**。它现在只有一行属性，但同一节点上的 `qcom,vmids` 与缺失的
   `memory-region` 与之语义冲突，Konrad 的「nuanced case」指的就是这组耦合。
2. 通用驱动侧的判定是**二值开关**：`fastrpc.c:2596`
   `secure_dsp = !of_property_read_bool(rdev->of_node, "qcom,non-secure-domain")`。
   所以「加一行」会同时改变 CB 分配、VMID 使用与 secure 世界交互，**不是纯 DT 描述**。
3. 上游同 SoC 已有**正例与反例**并存：
   - CDSP fastrpc = non-secure（`sm8750.dtsi:6407-6412`，带 `qcom,non-secure-domain` + `memory-region`）；
   - ADSP fastrpc = secure（`sm8750.dtsi:2570-2584`，带 `qcom,vmids = <QCOM_SCM_VMID_LPASS QCOM_SCM_VMID_ADSP_HEAP>`，
     **没有** `non-secure-domain`、**没有** `memory-region`）。
   ⇒ 我们的补丁实际是「把 ADSP 从 secure 改成 non-secure」，与 CDSP 的既有形态看齐，但需要把
   `qcom,vmids` 一并处理，否则驱动仍会在 non-secure 路径上尝试 VMID 赋值（语义矛盾）。

## §1 已核实的证据（可直接引用）

| # | 事实 | 证据（可复跑） |
|---|---|---|
| E1 | 驱动把该属性当**布尔开关**，没有中间态 | `git show gh/master:drivers/misc/fastrpc.c \| sed -n '2590,2600p'`；`grep -rn "non-secure-domain" drivers/misc/fastrpc.c`（全树仅此 1 处） |
| E2 | 上游 CDSP 节点是 non-secure 形态 | `git show gh/master:arch/arm64/boot/dts/qcom/sm8750.dtsi \| sed -n '6407,6412p'` |
| E3 | 上游 ADSP 节点是 secure 形态，且带 `qcom,vmids`（LPASS/ADSP_HEAP 两个 VMID） | 同上 `sed -n '2570,2584p'` |
| E4 | ADSP 的 compute-cb 用 SID `0x1003/0x1043`（每 CB 两条 iommu 项）+ `dma-coherent` | 同上 `sed -n '2581,2600p'` |
| E5 | 我们的板级 payload 自 vk64 起就带该属性（日常线 DTB 有、内核 C 代码无） | `.pi/memory/MEMORY.md:240`；`patches/upstream/sm8750-adsp-nonsecure-20261107/`（v3 原件） |
| E6 | 传感器栈（`hexagonrpcd-adsp-sensorspd` → `qrtr svc 400` → `/dev/fastrpc-adsp`）依赖该属性 | `.pi/memory/failures-kernel.md:425`；`reports/` 传感器上线记录 |
| E7 | 上游把「去 secure CB」的另一种写法做成**删节点**（lemans），不是改域属性 | patchwork `14973058`（Abel + Bartosz 双 R-b，2026-11-11） |

## §2 还没拿到的证据（本轮未完成）

| # | 缺什么 | 为什么需要 | 下一步（设备/主机） |
|---|---|---|---|
| M1 | ADSP fastrpc CB 在**不加属性**时实际走哪个 SMMU CB / 是否 secure（寄存器级） | 回答 Konrad 的「为什么原厂固件要求 non-secure」 | 设备侧：`cat /sys/kernel/debug/arm-smmu/*`（CB 绑定）+ `dmesg \| grep -i fastrpc` 前后对照；属上机项 |
| M2 | 原厂 DTBO 里 ADSP fastrpc 的完整属性集（是否带 `qcom,vmids`、`memory-region`） | 证明「原厂也是 non-secure」而非我们自创 | 主机侧：从 `backup/stock-elden/` 的 dtbo 反编译取节点（本轮未做） |
| M3 | `accel/qda` v4（series 1198307）与 `deprecate qcom,nsessions`（series 1198581）落地后对 `fastrpc.c:2596` 的改写 | 决定 M10 是否要改成新属性名/新形状 | 等两个系列进 next 后重核；`qcom,nsessions` 废弃会直接改 ADSP 节点 |
| M4 | Ard 的 32 MB shared DMA pool（7 补丁串，patchwork `14972135`）是否改 4K 页假设 | 影响 `memory-region` 尺寸选择 | 读该串 cover 与本机 `fastrpc` 节点 `memory-region` 现状对照 |

## §3 对 M10 v3 的处置建议

- **形状**：保持「单个 dts 提交」，但 commit message 必须写清三件事：① 驱动侧是布尔开关（引 E1）；
  ② 同 SoC 的 CDSP 已是 non-secure（引 E2），本补丁是把 ADSP 对齐；③ `qcom,vmids` 的去留与原因。
- **时机**：**不在本轮发 v4**。等 `accel/qda` v4 / `nsessions` 废弃任一进 next 再出，否则 rebase 一次白费。
- **可替代/更强证据**：若 M1 能拿到「原厂固件在 non-secure CB 上工作、secure CB 上报 SMMU fault」的
  dmesg 对照，M10 就能从「描述」升级为「修复」，Konrad 的定性会很快收敛；否则按 E7 的做法讨论
  「删 secure CB 节点」这条上游更接受的路线。
