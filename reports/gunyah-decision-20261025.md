# 裁决：Gunyah 子 VM 在本 firmware 上不在主线自建（2026-10-25，用户定 C 方案）

> 裁决人：用户（2026-10-25）。执行：agent。成本：零写盘（全程 `fastboot boot`，未写任何分区）。
> 证据链：`reports/gunyah-{stage0-positive,rm-probe,dt-capid,capid-forensics,mainline-rm-up,vmm-first-attempt,pvm-attempt,612-driver-port,612-samebuild}-*.md`。

## 1. 裁决（一句话）

**本机 firmware 下「纯 Linux 宿主 + 主线 `drivers/virt/gunyah` + RM」这条建 VM 的路走不通**：
`VM_INIT` 恒定 `0xA MEM_INVALID`，而能用的 Android 路径依赖主线不存在的厂商 `MEM_DONATE` + `gunyah_loader`
hypercall 族 ⇒ **G2 回 Waydroid**；Gunyah 只保留 6.12 驱动分层作为 G1 上游化素材，不再为「跑起 VM」继续投入。

## 2. 走到这一步的完整否证链（都做完了，不是没试）

| 轴 | 试验 | 结果 |
|---|---|---|
| hyp 通道是否存在 | `HYP_IDENTIFY` / `GUNYAH_WDT_STATUS` / SMCCC SIP `0x02000609` | ✅ 全通（api v1、DOORBELL/MSGQUEUE/VCPU/MEMEXTENT 全支持） |
| 驱动栈 | AOSP 6.6 → AOSP `android16-6.12`（17 文件 + 5 头文件，`config_image` + `auth_vm_mgr`） | ✅ 编 9 `.ko` 0 error、vermagic 逐字、同构建加载 **0 corruption** |
| RM 通道 | `/dev/gunyah` + `GUNYAH_CREATE_VM` | ✅ 真实 RPC 往返、`/hypervisor` 节点每开机自动落地（capid 会变，靠 SIP 复刻解决） |
| DTB 配置 | 7 个 DTB 变体（`rm-rpc` vdevice / 无 config 子节点 / `size-max` / 独立 DTB / `DTBOFF=0`） | ❌ 错误码一字不变 |
| 固件（pVM） | 真 `pvmfw` 1 MiB + `SET_FW_CONFIG` + `SET_FIRMWARE_MEM` + auth→PVM | ❌ 仍 `0xA`；SHARE+auth 更早被 `DENIED` |
| 内存模型 | SHARE+按需分页 vs **整块 8 MiB 急切 LEND**（crosvm protected 形状） | ❌ 两者 RM 序列逐字相同、错误码相同 |
| 驱动代次 | 6.6 AOSP 移植 / 6.12 上游分层 / 同 harness 在 stock Android（厂商内核+驱动） | ❌ 三者 `0xA` 一致 ⇒ 不是移植、不是 DTB、不是 VMM 参数 |
| 厂商路差异 | `gh_rm_drv.ko` / `gunyah_loader.ko` 反汇编 | 厂商用 **`MEM_DONATE 0x51000010`**（主线未定义）+ `hvc #0x6045/#0x604e…#0x6065`；vendor RM 无 `0x32/0x33/0x34` |

## 3. 为什么不走 A（逆向 loader 协议补主线）

- 纯厂商内部 ABI：无文档、随固件/baseband 版本变，且 `gunyah_loader` 的 hypercall 表在主线无对应。
- **不可上游化**：与 G1「按模块向上游提交」的目标反向；即便跑通也是第二套 out-of-tree 驱动。
- 收益面窄：只服务「本机跑 Windows/Linux 子 VM」，而 Waydroid 已覆盖 G2 的主用例（安卓应用）。

## 4. 保留什么（都已落仓库，可直接复查/复用）

| 资产 | 位置 |
|---|---|
| 6.12 驱动分层（`config_image` + `auth_vm_mgr` + `gunyah_qtvm`） | `reference/gunyah-refs/g612{,‑hdrs}/`、`build/gunyah-port`（含 7 处 `ELDEN PORT` 漂移注释） |
| hyp capid 运行时发现（SIP `0x02000609` → boot info → DTBO overlay） | `build/gunyah-port/elden-hypprobe`、`elden-gunyah-dtbo`、`scripts/gunyah-rm-bringup.sh` |
| 可复现镜像与模块 | `out/boot-elden-gh612b.img`（+ manifest）、`/lib/modules/<UTS>/…/gunyah/` 在机、6.6 原件 `/root/ghmodules-6.6-backup.tar.gz` |
| 最小 VMM harness | `tools/gunyah-modules/vmmtest/`、`elden-rmtest` |
| 两条新坑 | `PITFALLS #395`（7.3 `DTC_FLAGS` 按 `target-stem`）、`#396`（`gunyah.ko` `[permanent]` 不可 `rmmod`） |

## 5. 对 G1 的处理

`drivers/virt/gunyah` 6.12 分层仍是主线可接受形状，**仅作为补丁素材封存**，不排期、不占用设备时间：

1. 先 `vm_mgr` / `vm_mgr_mem`（结构最干净，且与设备无关）；
2. 再 `gunyah_qtvm`（`auth_vm_mgr` 插件样板）；
3. `gunyah_qcom` / `platform_hooks` 属 vendor hook，上游不接受，只留本地。

**不承诺上机验证**：这条上游化线与本机能否建 VM 无关（本裁决已把「跑 VM」与「上游化」解耦）。

## 6. 复启条件（任一成立才重新评估）

1. 出现**新一代 firmware**（系统更新/baseband 升级）且 `gh_rm_drv.ko` 反汇编里出现 `0x32/0x33/0x34`
   或不再依赖 `MEM_DONATE`（判据 = 重新跑 §2 的 3 条二值实验，全部只读）；
2. 上游或社区出现 **`gunyah_loader` ABI 的开源实现/文档**（届时不必逆向）；
3. 有人真的需要在**本机**跑 Windows/Linux 子 VM 且 Waydroid/Box64 都覆盖不了。

## 7. G2 回 Waydroid 后的下一步（开放项，按序）

1. **C3 身份/DRM 取证**（Play Integrity / Widevine 能做到哪一级；需装 APK，用户提供）；
2. **U7 相机 App 实开预览**（`Number of camera devices: 1` 已成立，剩 App 侧验证）；
3. C2 Play 登录复核（凭据/代理由用户侧掌握）。
