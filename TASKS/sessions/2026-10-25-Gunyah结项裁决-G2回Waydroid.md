# 会话：Gunyah 结项裁决 —— G2 回 Waydroid，6.12 分层转 G1 上游素材

- 日期：2026-10-25
- 裁决人：用户（选 C）。执行：agent。
- 结论（一句话）：**本 firmware 下「纯 Linux 宿主 + 主线 `drivers/virt/gunyah` + RM」建子 VM 不可行**，
  `VM_INIT` 恒 `0xA MEM_INVALID` 且对 DTB/内存模型/驱动代次全不敏感；能用的 Android 路径依赖主线不存在的
  `MEM_DONATE(0x51000010)` + `gunyah_loader` hypercall 族 ⇒ **G2 回 Waydroid**，Gunyah 只保留上游化素材。
- 权威文件：`reports/gunyah-decision-20261025.md`（裁决 + 复启条件 + 保留资产清单）
- 过程证据：`reports/gunyah-612-samebuild-20261025.md`、`reports/gunyah-612-driver-port-20261025.md`、
  更早 `gunyah-{stage0-positive,rm-probe,dv-capid,capid-forensics,mainline-rm-up,vmm-first-attempt,pvm-attempt}-*.md`

## 落地动作（本次已完成）

1. `TASKS/README.md`：概览表「拓展」行改为 Gunyah 结项（已完成 1 项）；§4 N2 追加**终局裁决 + 结项口径 + 复启条件 + 保留资产**；
   §5 Q4（C8）加终结指针。
2. `PROGRESS.md` §6 第 1 项追加终局段（G2 回 Waydroid）。
3. 312 行以下的设备侧状态不变，本次**零写盘**（未写任何分区）。

## 后续（G2 线开放项，按序）

1. C3 身份/DRM 取证（Play Integrity / Widevine 等级；需装 APK，用户提供）。
2. U7 相机 App 实开预览（`Number of camera devices: 1` 已成立，剩 App 侧）。
3. C2 Play 登录复核（凭据/代理由用户掌握）。

## 复启条件（任一）

- 新一代 firmware 的 `gh_rm_drv.ko` 出现 `0x32/0x33/0x34` 或不再依赖 `MEM_DONATE`（只读判据已写在裁决报告 §6）；
- 上游/社区出现 `gunyah_loader` ABI 开源实现；
- 确有本机跑 Windows/Linux 子 VM、而 Waydroid/Box64 覆盖不了的硬需求。
