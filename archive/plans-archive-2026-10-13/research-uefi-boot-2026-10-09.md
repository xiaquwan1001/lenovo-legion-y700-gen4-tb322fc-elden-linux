# UEFI 间接引导可行性复查（G1-29 路线 A）— 2026-10-09

> 调研任务：复查 elden(TB322FC/SM8750P) UEFI 间接引导最新可行性。
> 基线：`archive/topics/UEFI-UFS-BRINGUP-2026-10-05.md`（路线 A 上机失败搁置；平台可达 BDS，UFS init 唯一硬阻塞）。
> 方法：GitHub API 实查（mu_wide_platforms / Mu-Silicium 生态 commits+issues）、本地 fork 源码/二进制取证。
> 本文件只增不改，不修改领域层文件。

## 结论（四方向逐条）

| # | 方向 | 结论 |
|---|---|---|
| 1 | Mu Pakala 社区动态 | **无实质进展**（观察） |
| 2 | 替代 EDK2 平台 | **Mu-Silicium 主仓有 PakalaPkg Silicon、无设备包**；无 SM8750 UFS 可行先例（否） |
| 3 | UFSDxe 专有依赖 | **依赖链完全卡在 Qualcomm 专有 DXE + 平台配置映射**，无开源 workaround（否） |
| 4 | 重启 UEFI 最小投入 | **有明确路径但属中-高投入，不建议现在重启**（否/观察） |

## 1. 社区变化（2026-10-05 → 10-09）

- **mu_wide_platforms（sunflower2333）**：最新 commit 仍是 `3e1d0520`（2026-10-01，remove sm8650.json），
  即 PakalaPkg 相关自 2026-07-19 后零推进。我们的 issue **#12 自 10-05 起 open、0 评论、无 assignee**——
  该 repo 无活跃社区（issue 多为 dependabot bump），短期等回复期望低。
- **Project-Silicium/Mu-Silicium**（515★，主流活跃项目）：v4.0 发布于 2026-10-01，日提交活跃。
  - `Silicon/Qualcomm/` 含 **PakalaPkg**（近期有维护：2026-08-29 "Add ACPI PCDs"、08-16 "Update SEC"），
    **但 `Platforms/` 下 Pakala 无任何 Device 包**（Qualcomm 仅有 qrd8550Pkg，Lenovo 仅 9707f/j706f）。
  - `Status.md` 无 Pakala/SM8750 条目 → 官方不支持。
  - 有价值的社区行为样本：issue #2145（pipa SM8250 自建 UEFI OOM + INACCESSIBLE_BOOT_DEVICE，**closed**）——
    维护者 Robotix22 亲自给出逐项修正后的 `MemoryMapLib` 内存映射后问题解决。
    **启示**：Mu 系 vendor 二进制的 UFS/启动失败，多数最终归因于内存映射/平台配置与 stock 不符，
    维护者愿意直接给配置 diff；但前提是已知可用设备作对照——SM8750 无对照设备。
- 无任何 GitHub issue/commit 提及 SM8750 UFS 在 EDK2 下可用（全局搜索 831 条结果过滤后无一相关）。

## 2. 替代 EDK2 平台

- **edk2-porting/edk2-msm**（2589★）：最近 push 2026-03，最新 SoC = **sm8550**（无 sm8650/8750），
  与 Mu Pakala 无重叠，从 sm8550 到 sm8750 距离不小于现状。
- **Project-Silicium Mu-Silicium**：见上；PakalaPkg Silicon 层维护中，可作 **Mu 补丁版二进制（ClockDxe 等）的参考实现**，
  其 Binaries submodule 版本较 mu_wide_platforms 新，值得 diff。
- **radxa-pkg/edk2-qualcomm**（push 2026-09）：设备厂商维护的 EDK2（x86/ARM devkit 风格），无 SM8x50 手机 SoC 支持。
- **Qualcomm 官方 devkit EDK2**：官方只随 devkit（QCS6490/8550 RB 系）提供闭源 UEFI 发行包，无开源分支；
  SM8750 无 devkit UEFI 可借鉴。
- **结论**：无任何替代平台已有 SM8750 UEFI 支持可移植；Mu 生态独苗，且 Silicon 层配置问题同源。

## 3. UFSDxe 专有依赖清单与 workaround 分析

从 Pakala 设备包 vendor `UFSDxe.efi` 二进制取证，其运行期依赖（全部为 Qualcomm 专有 Protocol/GUID，均由
同 FV 内其他 vendor DXE 提供）：

| 依赖 | 提供者（vendor DXE） | 本机日志证据 |
|---|---|---|
| HWIO Protocol（MMIO 访问） | PlatformPeiLib/ConfigLib 装载的 HWIO DXE | "Failed to locate HWIO Protocol" |
| SCM Protocol（TrustZone 调用） | SCM DXE | "Failed to locate SCM protocol for Mailbox 14" |
| DTBExtnProtocol（DT 扩展配置） | PlatformPeiLib | "Locate DTBExtnProtocol failed" |
| NPA Protocol（时钟/资源请求） | NPA client framework | "Fail to init client handle to QBSS clock node" |
| Qseecom / TzeLoader | TZ 加载器 | (字符串证据) |
| RPMB Protocol | RPMB DXE | "Failed to find RPMB Protocol" |
| ResetNotification / Clock gate (`ufs_clock_gate`) | ClockDxe（须用 Mu 补丁版） | 原版 ClockDxe 使平台更早崩 |
| UFS IOMMU Protocol | Platform IOMMU DXE | "UFS IOMMU LocateProtocol failed" |

**关键分析**：
- UFSDxe 本身无源码（vendor 预编译），错误语义（`ufs_error_log: 11/3b/55`）未知；
  其启动链 = HWIO/SCM/NPA/DTBExtn 全部可用 → 才能拿到 UFS HC MMIO 和时钟 → 才能跑 init。
- 日志三条早期错误（SCM Mailbox 14、QBSS clock node、CPU_Vectors region）说明
  **信息缺口在平台配置映射（InfoBlk/ConfigLib/DTB 扩展），不在 UFSDxe**——与 10-05 结论一致。
- 无 workaround 可行：无源码不可能重写 UFSDxe；这些专有 protocol 也无开源实现
  （HWIO/SCM/NPA 都是 QCOM UEFI 内部接口，上游 edk2 无对应物）。
- 唯一可行路径 = **把 stock 的平台配置喂给 Mu 壳**（见 §4）。

## 4. 若重启 UEFI 方向的最小投入

按 10-05 复盘 §9.4 + 本轮证据，最小投入路径（估 3–5 个工作单元）：

1. **提取 stock 配置（前置，零上机）**：本机已有 `uefi-firmware-backup/`（含多台设备原厂 UEFI 备份）。
   用 UEFITool/UEFIReader 从 stock FV 提取：
   - InfoBlk / ConfigLib 数据块（`PlatformPeiLib` 消费的 tag 表，重点找 `tag==0x402` 表项的真实结构）；
   - stock 内存映射（对照 Mu `PlatformMemoryMapLib.c`——10-05 已证与 oneplus-dodge 逐字节相同，可疑）；
   - stock uefiplat.cfg（若非 DT-only stub）。
2. **配置回填**：把 stock 数据转写进 Mu 的 `PlatformConfigurationMapLib` / InfoBlk 侧，
   补齐 SCM Mailbox 14 / QBSS / CPU_Vectors 缺项。
3. **对照 Mu-Silicium 新 Binaries**：diff mu_wide_platforms 与 Mu-Silicium 的 PakalaPkg Binaries submodule
   与 Silicon 层（SEC/ACPI PCD 改动），看是否有新补丁版 UFSDxe/ClockDxe 配对。
4. **重验矩阵**：保持 10-05 最佳基线（未打补丁 UFSDxe + 补丁版 ClockDxe + 多线程 0），
   仅替换配置，`fastboot boot` 看三条早期错误是否消失。

**不建议现在重启的理由**：
- 不构成主线依赖（96 MiB 限制已由 vk62 解决；路线 C 已交付）；
- 投入产出比低于 G1 剩余功能项（相机/传感器等）；
- 即便 UFS 通了，Mu 多线程调度器、GRUB 链仍有一段路。

## 风险

- `uefi-firmware-backup` 的 stock UEFI 是 Android ABL 信任态下运行；`fastboot boot` 环境下
  ABL 是否为 UEFI 留好 UFS/SMMU 状态仍未知（10-05 未解点），配置回填也可能仍失败。
- vendor 二进制错误码无文档，取证只能靠黑盒矩阵。
- 本项目人员精力优先级冲突：UEFI 属拓展，主线 G1 功能项更急。
- issue #12 无社区关注，上游回复不可依赖；若需人力只能自研。

## 推荐

维持**搁置**，不改路线。若日后重启，按 §4 顺序执行（先零上机的 stock 配置提取）。
可顺手行动（低成本）：在 issue #12 追加 Mu-Silicium PakalaPkg 存在但无设备包的观察，
@Robotix22（Mu-Silicium 维护者有帮人调内存映射的先例）。
