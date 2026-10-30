# M3-1 v5 投递前独立构建 + 边界回归（pristine 基线）— 2026-10-30（重派轮）

基线：build/m3v5-pristine = pristine 24a19b953e(Linux 7.3-rc7) + v4 三枚 + v5 两枚（HEAD 34865c8915）。
本轮纪律：每条门禁 rc/warn/err 计数完成即追加，日志 tee 到 reports/artifacts/m3v5-prefetch-20261030/。

## §0 门禁矩阵

| 门禁 | 内容 | rc | warn | err | 结论 | 日志 |
|---|---|---|---|---|---|---|
| G1 | W=1 增量编译 dwc3/+roles/（本人重跑 O=/tmp/m3v5-g1-obj，自 66-.o 残留复制） | 0 | 0 | 0 | **PASS** | artifacts/m3v5-prefetch-20261030/mine-g1.log |
| G2 | 全部 dwc3 glue（本人重跑 O=/tmp/m3v5-g2-obj 增量 + /tmp/m3v5-g2-cov 18/18 glue=m 全量） | 0 | 0 | 0 | **PASS** | mine-g2.log, mine-g2-cov.log |
| G3 | 四符号使用点审计（10/7/5/13 点） | 0 | 0 | 0 | **PASS**（0 漏改） | g3.log, g3-addendum.log |
| G4 | checkpatch 0E/0W/0C ×2 + dt-doc-validate rc=0 + DTS 形状 D1 全 PASS | 0 | 0 | 0 | **PASS** | mine-g4-checkpatch.log, mine-g4-dtdoc.log, mine-g4-shape.log |
| G5 | /tmp 新 worktree pristine+v4×3+v5×2 重放，diff 6 文件 vs build/m3v5-pristine | 0 | 0 | 0 | **PASS**（6/6 SAME） | artifacts/m3v5-prefetch-20261030/g5.log |

## §1 门禁明细
（逐条完成后追加）

## §1.5 G5 重放一致性（本人执行，2026-10-30T21:53:14+08:00）
- 新 worktree /tmp/m3v5-g5-replay @ pristine 24a19b953e；git am v4×3 (rc=0) + v5×2 (rc=0)，replay head=e89920966d
- diff -r（逐文件 diff -q）6 目标文件 vs build/m3v5-pristine：**6/6 SAME，0 diff**；sha256 双副本全匹配（12/12 行）
- build/m3v5-pristine 未被污染：head 仍=34865c8915，status 脏行数=0
- 异常登记：checkout 时从 alternates（build/m3v2-7.3rc7 pack-d980bb4f…）读 delta base 401c2787 报 inflate 错，但 checkout 100% 完成、该 blob 现可 cat-file、该 pack verify-pack 0 error ⇒ 判「待确认（疑似瞬时读/资源抖动，最终状态已验证无损）」。日志 g5.log / g5-verify.log / g5-pack-anomaly.log


## §2 G1/G2 构建（本人独立重跑；L2-A 通道死亡未产出，见 §5）
- 工具链教训：必须带 CROSS_COMPILE=aarch64-linux-gnu-（缺省首轮 rc=2，gcc 报 -mlittle-endian 不识别；非源码缺陷，已记录防再犯）。
- G1：make -j26 W=1 O=/tmp/m3v5-g1-obj ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- drivers/usb/dwc3/ drivers/usb/roles/ → rc=0，warning:=0，error:=0，实编 33 个 CC/AR/LD 行（含 roles/class.o、dwc3/core.o 等）。残留 66 .o 原地复制到 /tmp/m3v5-g1-obj 复用（不触碰原始 /tmp/m3v5-prefetch-obj*，防与 L2 撞锁）。
- G2a（glue 构型增量）：O=/tmp/m3v5-g2-obj（自 70-.o 残留复制）drivers/usb/dwc3/ → rc=0，0W/0E，35 个编译行。
- G2b（覆盖增强）：/tmp/m3v5-g2-cov，COMPILE_TEST=y 后 18/18 个 USB_DWC3_* glue 全部 =m（olddefconfig rc=0），make W=1 drivers/usb/dwc3/ → rc=0，编译期 0 warning/0 error；产出 19 个 glue .o（imx/imx8mp/qcom/qcom-legacy/pci/exynos/st/rtk/am62/apple/google/haps/keystone/meson-g12a/octeon/omap/xilinx/generic-plat/of-simple）。唯一 'warning:' 行为 Kconfig 'override: reassigning to symbol ACPI'（播种配置提示，非编译器告警）。注：派工单所列 dwc3-hisi 在 v7.3-rc7 树中不存在（Makefile/Kconfig 无 hisi 条目）⇒ N/A，非漏编。

## §3 G3 使用点审计（build/m3v5-pristine = v4+v5 已应用态）
| 符号 | 使用点数 | 明细 | 结论 |
|---|---|---|---|
| pre_set_role | 10（其中 7 行含 dwc3_pre_set_role 重叠已注明） | imx8mp.c:177 / qcom.c:606 / imx.c:181 赋值；core.h:1003/1007 定义、1706-1707 glue_ops 派发（新 inline） | 已适配 |
| dwc3_pre_set_role | 7（净 6+1 定义） | core.h:1704 inline 定义；drd.c:385/411/443/472/584 调用 | 已适配 |
| usb_role_switch_at_endpoint | 5 | roles/class.c:167 static 定义（无 EXPORT，ABI 干净）、:214/:239 两处查找路径调用；snps,dwc3-common.yaml:27 文档引用 | 已适配 |
| glue_ops | 13 | core.h:1070/1272 定义+1706-1713 派发；core.c:2513 复位；imx8mp.c:269/qcom.c:701/imx.c:263 赋值 | 已适配（既有上游机制） |
- 漏改探测：usb_role_switch_get/find_by_fwnode 调用方（chipidea/usb-conn-gpio/qcom_eud/rtk/apple…）均走未改动的公共 API ⇒ 不适用；**漏改=0**。

## §4 G4 静态门
- checkpatch --strict --no-tree：v5-0001 **0E/0W/0C**（142 行）、v5-0002 **0E/0W/0C**（222 行），rc=0×2。
- dt-doc-validate snps,dwc3-common.yaml：rc=0。
- 形状一致性（common.yaml 无 examples 块，以 v5 schema 为权威）：D1(geekidos DTS) port@0+port@2、各 1 endpoint、mux-state 在 endpoint（0/1 互补）、无 port@1 ⇒ 5/5 规则 PASS；D2(Y700-elden-linux) 无 usb-role-switch/mux-state（单口旧形状）⇒ 不适用。脚本首轮 2 个 FAIL 为括号解析伪影，人工节点核对推翻并留痕（mine-g4-shape.log correction 段）。

## §5 编排异常（如实记录）
- L2-A/L2-B 经 agents.run(custom.ustc/deepseek-flash) 派发（后台任务 a2a45d75），~15 min 零产物、agents.list()=0、无子进程 ⇒ **派发通道静默失败**（连续第二轮编排失效：上轮 SIGSEGV、本轮无 spawn 痕迹）。G1–G4 全部由 Lead 本人重跑取数（符合 AGENT-OPS「收口必须本人重跑主门禁」）。
- G5 checkout 时 alternates（build/m3v2-7.3rc7 pack）一次 inflate 报错，终态验证无损 ⇒ 待确认（见 §1.5）。

## §6 结论
- **G1–G5 全部 PASS；两枚 v5 补丁达到投递前静态/构建/一致性门标准；无需 patches/upstream/m3v5-20261030b/。**
- 未投递/未发信/未刷机/未碰设备/未改 SSOT；build/m3v5-pristine 保持 34865c8915 干净（0 脏行）。
