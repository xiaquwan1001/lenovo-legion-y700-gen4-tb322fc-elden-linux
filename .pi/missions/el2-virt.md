# 任务：调查通过逆向高通代码解锁 EL2 硬件虚拟化（高阶/可选）

你是 y700-elden（联想 Y700 四代 TB322FC / SM8750）主线 Linux 项目的专项研究员。工作目录 `~/y700-elden`，先读 `INDEX.md`。**本任务为可行性调研，高风险、可选；不要刷机。**

## 背景
主线 arm64 Linux 的 **KVM 需要运行在 EL2**。该设备出厂运行在高通 **Gunyah/QHEE hypervisor** 下（Linux/Android 在 EL1），因此 KVM 不可用。目标是调查：**能否解锁/进入 EL2 以启用硬件虚拟化（KVM 或替换为开源 Gunyah）**。

## 调研要点
1. **现状确认**：从设备只读探测当前异常级别（`dmesg | grep -i "EL2\|hyp\|gunyah"`、`cat /proc/cpuinfo`、`ls /sys/firmware`、`/proc/device-tree` 中 hypervisor 节点、`androidboot.hypervisor.*` 之类），确认是否有 hyp 存在。
2. **开源 Gunyah**：Qualcomm `gunyah-hypervisor` / 上游 gunyah 驱动，能否在本设备加载/替换；`qcom_scm`、RM (Resource Manager) 接口。
3. **进入 EL2 的条件**：XBL/ABL 引导链、`hyp` 镜像、`hypervisor` dtb、QHEE 配置；是否有 `fastboot oem`/`setenv` 开关、AVB/安全启动是否阻挡。
4. **先例**：其它 SM8xxx/SM7xxx 设备在主线进入 EL2 / 用 KVM / 关掉 Gunyah 的社区案例（如 postmarketOS、-linux 邮件列表、Qualcomm 文档、更早的 msm 设备）。
5. **逆向线索**：固件包里定位 hyp/相关分区（`~/下载/tb322fc/` EDL 全量包、`backup/`），分析 XBL 配置与 SCM 调用；评估工作量与变砖风险。

## 交付物
- 文档 `EL2-VIRT-2026-10-02.md`（写在 `~/y700-elden/`）：
  - 现状证据（命令输出）
  - **可行性结论**（可实现 / 需引导链改动 / 基本不可行 / 未知）
  - 若可能：分步骤方案 + 风险 + 回退
  - 明确标注"高阶可选，非阻塞"
- 结论写入 `task progress` / `task done`，完成后 `task done` 退出。

## 约束
- **只读探测**；任何解锁/刷写实验必须先回报协调者，不得自行执行。
- 用 web_search/web_fetch 找社区先例；引用来源。
