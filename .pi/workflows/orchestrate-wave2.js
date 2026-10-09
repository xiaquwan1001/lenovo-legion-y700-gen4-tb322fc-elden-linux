// Wave 2 retry: correct model name ustc-ai-1/qwen3.8-flash-next
const wave2Results = await runs.all([
  {
    key: "doc-audit",
    agent: "worker",
    model: "ustc-ai-1/qwen3.8-flash-next",
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
    model: "ustc-ai-1/qwen3.8-flash-next",
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
    model: "ustc-ai-1/qwen3.8-flash-next",
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

emit(wave2Results.map((r, i) => ({ key: ["doc-audit","gpu-camera","auto-rotation-toggle"][i], status: r.status || "done" })))
