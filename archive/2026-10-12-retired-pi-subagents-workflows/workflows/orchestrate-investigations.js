// Wave 1: Hard tasks (GLM, high context) — concurrency limit 3
const wave1Results = await runs.all([
  {
    key: "kexec",
    agent: "worker",
    model: "ustc-pool/glm-5.3-flash",
    task: `你是内核启动链专家。调查 elden(TB322FC/SM8750P) 上 kexec 快环的可行性。

## 已有结论（不要重复验证）
- device_shutdown 掉电根因已定位（2026-10-08）：cpufreq_suspend + 设备 .shutdown() 遍历多触发叠加
- 唯一可靠规避 = 整段跳过 device_shutdown（mask=1）→ 能到 Starting new kernel
- 目标内核 kexec 引导仍失败 = 关键路径遗留（跳转后目标 Image 早期失败→回 boot_b、pstore 空）
- 本机不具备早期串口
- 详见 archive/topics/KEXEC-DIAG-TEST-PLAN-2026-10-08.md §8/§9

## 调查方向
1. 目标内核引导失败的可能原因：读 arch/arm64/kernel/machine_kexec.c 和 machine_kexec_file.c 分析跳转流程，列出 SM8750 可能出问题的关键点（SMMU stall、interrupt controller state、PMU、cache coherency）
2. 绕过方案：kexec_file_load 是否传了正确的 DTB/initrd；crash kernel 思路是否适用
3. 社区先例：搜索 ARM64 Qualcomm kexec 经验、LKML 相关修复
4. 最小推进实验（如果只能做一件事）

## 输出
写入 .pi/plans/research-kexec-feasibility-2026-10-09.md。结构：结论→剩余可能性→推荐下一步→参考。
不修改领域层文件。`
  },
  {
    key: "uefi",
    agent: "worker",
    model: "ustc-pool/glm-5.3-flash",
    task: `你是 Qualcomm UEFI/EDK2 专家。调查 elden(TB322FC/SM8750P) UEFI 间接引导的最新可行性。

## 已有结论（不要重复验证）
- 路线 A 上机失败搁置（2026-10-05）：Mu Pakala 能进 BDS 但 UFS init ASSERT
- 已发上游 issue sunflower2333/mu_wide_platforms#12
- 96 MiB 限制已被 vk61 解决，UEFI 不构成主线依赖
- 详见 archive/topics/UEFI-UFS-BRINGUP-2026-10-05.md

## 调查方向
1. Mu Pakala 社区近期动态（GitHub commits/issues）有无 UFS 或 SM8750 进展
2. 替代 EDK2 平台（Qualcomm devkit EDK2 分支、其他 SM8x50 支持）
3. UFSDxe 依赖的专有 PPI/Protocol 清单，分析有无 workaround
4. 若重启 UEFI 方向的最小投入

## 输出
写入 .pi/plans/research-uefi-boot-2026-10-09.md。结构：结论(是/否/观察)→社区变化→推荐路线→风险。
不修改领域层文件。`
  },
  {
    key: "driver-modularization",
    agent: "worker",
    model: "ustc-pool/glm-5.3-flash",
    task: `分析 elden(TB322FC/SM8750P) 主线内核驱动模块化方案。

## 背景
- boot.img 83.3 MB（限制 96 MiB），完整 ramdisk
- 所有驱动 =y（built-in），无 .ko
- slim initramfs 已证伪（无 /lib/firmware → 外设全废）
- kexec 快环需整段跳过 device_shutdown
- Q28 面板开机首次 modeset 间歇失败，模块化延后加载可能有关
- 构建脚本在 scripts/ 目录，内核 config 可能在 arch/arm64/configs/ 或脚本引用处

## 分析任务
1. 找到当前使用的内核 defconfig（grep config in scripts/），列出关键驱动
2. 分类：必须=y / 可=m 需 initramfs 加载 / 可=m rootfs 按需加载
3. 收益评估：体积节省、kexec 意义、Q28 影响
4. 最小改动最大收益路径

## 输出
写入 .pi/plans/research-driver-modularization-2026-10-09.md。结构：分类表→体积预估→关联分析→实施步骤。
不修改领域层文件。`
  }
])

// Wave 2: Moderate tasks (deepseek-flash-2) — concurrency limit 3
const wave2Results = await runs.all([
  {
    key: "doc-audit",
    agent: "worker",
    model: "ustc-pool/qwen3.8-flash-next",
    task: `审核 elden 项目文档进度口径一致性。

## 任务
1. 跑 bash scripts/check-doctor.sh，完整保留输出
2. 对照 INDEX.md §3 "未解列表" vs TASKS.md 实际状态，找出：
   - 完成度百分比（G1≈90%·G2≈45%·G3 PoC）是否与实际任务行匹配
   - "Linux 侧未解（5）"各项在 TASKS.md 中是否仍为未解
   - "已定不做/搁置/取消"列表与任务行是否一致
3. 检查 TASKS.md §4 "下一步"各项是否仍开放
4. 找出口径冲突或过时引用

## 输出
写入 .pi/plans/research-doc-audit-2026-10-09.md。结构：结论→不一致项列表→check-doctor 输出→建议修正。
不修改领域层文件。`
  },
  {
    key: "gpu-camera",
    agent: "worker",
    model: "ustc-pool/qwen3.8-flash-next",
    task: `调查 elden GPU 驱动与相机模块后续方向。

## 已有状态
- GPU: freedreno A830 工作正常（Mesa 26.1.8）
- 相机: 出流+libcamera+Snapshot App 实测通过
- 相机剩余：后摄过曝（IPA 调优，缺 s5kjns 校准 yaml）
- cambistmclkcc × Q24 未根治（规避 = elden_nocamera=1）
- CDSP 已启用

## 调查方向
1. freedreno/turnip 对 Adreno 830 (SM8750) 的上游进展
2. libcamera s5kjns IPA 校准 yaml 获取路径（vendor IQ 文件转换？自标定？）
3. linux-arm-msm 邮件列表关于 cambistmclkcc-sm8750 的回复/fix 进展
4. GPU 基准 (G1-8) 前置条件检查：读 scripts/bench-run.sh

## 输出
写入 .pi/plans/research-gpu-camera-status-2026-10-09.md。结构：各子项状态→推荐行动→参考链接。
不修改领域层文件。`
  },
  {
    key: "auto-rotation-toggle",
    agent: "worker",
    model: "ustc-pool/qwen3.8-flash-next",
    task: `分析如何将 elden 的重力/自动旋转做成用户级开关。

## 当前实现
- SSC/QRTR svc400（ADSP/hexagonrpcd）+ iio-sensor-proxy
- 自动旋转已可用，开机竞态已修
- 桌面 = Phosh 0.55，init = OpenRC
- 判据接口 = net.hadess.SensorProxy
- 不创建 /sys/bus/iio 节点

## 分析方向
1. Phosh 原生是否有旋转锁（gsettings orientation-lock？quick-settings tile？）
2. iio-sensor-proxy D-Bus 控制粒度（Enabled 属性？AccelScale suspend？）
3. 最小实现方案按代价排序：
   A: Phosh 内置开关
   B: gsettings + 脚本 kill/signal iio-sensor-proxy
   C: 自定义 D-Bus 拦截
   D: 快速设置磁贴
4. 对 Waydroid 传感器注入（C4）的影响

## 输出
写入 .pi/plans/research-auto-rotation-toggle-2026-10-09.md。结构：推荐方案→实施步骤→验收判据。
不修改领域层文件。`
  }
])

emit({
  wave1: wave1Results.map((r, i) => ({ key: ["kexec","uefi","driver-modularization"][i], status: r.status, output: (r.output||"").slice(0, 500) })),
  wave2: wave2Results.map((r, i) => ({ key: ["doc-audit","gpu-camera","auto-rotation-toggle"][i], status: r.status, output: (r.output||"").slice(0, 500) }))
})
