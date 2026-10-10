# y700-elden — 项目说明

> **项目描述只在本文件。** 做事规范见 **`.pi/AGENT-OPS.md`**（agent 行为/授权唯一入口）；
> 踩坑经验见 **`PITFALLS.md`**（开发经验唯一入口）；文档地图与状态见 **`INDEX.md`**（唯一入口）。

**机型唯一**：联想拯救者 Y700 四代 = **TB322FC** = 代号 **elden** = SoC **SM8750(P)**。
研究面 = **让这块板子在主线 Linux 上功能完整**（固件/驱动为主；刷写只是手段）。

## 目标（按优先级）

- **G1 完整 Linux + 上游化**：主线 Linux **功能特性完整**，**正确驱动全部原厂固件**（ADSP/CDSP/WCN7861/GPU/触屏/触觉/功放/tplg/相机…）。
  代码达到上游规范后**按模块向上游提交**（checkpatch/DTC/`dtbs_check` 绿；分级与顺序见 `TASKS.md` §7 M1–M5）。
- **G2 安卓容器**：**不依赖 Android 宿主**运行安卓应用（主路线 Waydroid，备胎 redroid）。
  核心验收 = **可用性 + 风控/完整性等级**：GMS 登录、**Play Integrity / SafetyNet**、Widevine 能做到哪一级
  （**取证判定，不预设"不可能"也不承诺**；见 `RESOURCES.md` §1.3、`TASKS.md` §5 Q1/§6）。
- **G3 x86 模拟运行**：以 **Steam 游戏**为验收载体，跑通 x86 用户态/游戏（Box64 + Wine/Proton 线）。
- **拓展（非主线，不阻塞 G1–G3）**：**UEFI 间接引导**、**Gunyah 高通虚拟化做 VM**。现状/裁决见 `TASKS.md` §4/§5、`archive/topics/`。

## 核心原则

- **设备等价**：同型号多台单元**物理地位完全等价**，唯一差异 = 容量；身份 = **(SN, hwboardid, 容量)**（`DEVICE.md`）。
  任务按单元**当前状态**分派，产出必须**设备无关**（运行时读实际 GPT/DT）。设备称 **U1 / U2**。
- **存储**：Linux 容量按项目体量一次给足（`DEVICE.md` §3），扩容首选回收 Android 专属分区；不写死配置。
- **文档 SSOT**：唯一入口 `INDEX.md`；分层与清单见 `INDEX.md` §2。

---

> API 限流 / 模型选择见全局 `~/.pi/agent/AGENTS.md`「API 网关与限流」（本文件不重复）。
