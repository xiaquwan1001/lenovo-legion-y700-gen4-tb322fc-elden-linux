# 任务：EL2 硬件虚拟化调研（C8）——书面结论已出，仅剩一次零成本上机探测

> 状态与进度的**唯一权威 = `../../TASKS/README.md` §2 行 C8**；本任务书只是派工背景。2026-10-04 现代化。

你是 y700-elden 的虚拟化可行性研究员。工作目录 `~/y700-elden`。**调研线，不刷机、不解锁、不改引导链。**

## 已定结论（2026-10-02，勿重做）
① 设备侧 KVM 不可达（XBL 锁 hyp，`-el2.dtb` overlay 只适用 dev kit）；② 独立 Gunyah 驱动未进主线（本 7.2 树无 `drivers/virt/gunyah`）；③ 唯一在演路线 = KVM-in-EL1 + Gunyah backend（RFC 00/34，WIP）。全文：`archive/topics/EL2-VIRT-2026-10-02.md` + `ARM-VIRT-RESEARCH-2026-10-02.md`。

## 本任务书唯一剩余动作（C8 收口判据）
在任一 mainline 启动的单元上跑一次 Gunyah UUID 探测：`dmesg | grep -i gunyah`（本地 `qcom_scm` 已带探测逻辑），把输出归档 `archive/topics/EL2-VIRT-probe-<YYYY-MM-DD>.md`，并在 `../../TASKS/README.md` C8 由编排者据结果**归档关闭或续立项**。顺路带出即可（其它上机任务的会话里捎一条命令），不值得单独占设备。

## 纪律（2026-10-04 约定）
- 只读探测；最终回复即交付物（命令+原始输出）；**不改 `../../TASKS/README.md`**。
- 若探测引出新的解锁/刷写实验需求 → 停下上报（引导链议题已定稿关闭，见 `../../RUNBOOK-BRINGUP/README.md` §0.5，勿重开）。
