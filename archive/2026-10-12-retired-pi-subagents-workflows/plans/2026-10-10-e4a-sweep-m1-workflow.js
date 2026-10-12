// 上机验证线：E4a MXC 熄屏扫测（设备已 fastboot）+ M1 资产树（主机侧）并行
const results = await runs.all([
  runs.run('e4a-sweep', {
    agent: 'worker',
    task: `E4a 上机验证：cambist MXC DTB（vk80）熄屏扫测。仓库 /home/xuqianhui1001/y700-elden，设备已在 fastboot（U2）。
必读：
- .pi/plans/2026-10-10-E4a-FIX1-DT.md（本补丁记录）
- scripts/sleep-sweep.sh（熄屏扫测脚本）
- PROJECT skills: qbootctl-slot-management 技能（~/.pi/agent/projects-memory/y700-eden 注意路径）——slot-attr 预检
- PITFALLS #150–#152（上机纪律：reboot 挂、用 reboot2、温启循环 mark-successful 预检）

步骤：
1. 执行 fastboot boot out/boot-elden-vk80-e4amxc.img（单条命令，PITFALLS #3）。等待设备起来（ssh/adb 可达），验证 uname/DTB 生效（decompile /sys/firmware 或 dmesg 确认 cambist 挂 MXC）。
2. slot 预检：slot-attr.py mark-successful b（RAM 直启不置 succ，防 retry 扣尽）。
3. 相机加载态：scripts/camera-modules-load.sh（CAM_FORCE=1）加载全栈，确认 20 模块。
4. keep-awake 关掉后跑 scripts/sleep-sweep.sh 真实熄屏 ≥3 轮。
5. 判定：3/3 存活 = MXC 单票根治候选成立（但样本低，记录）；掉电 = 记录轮数/现象（pstore 是否无痕）。
6. 每步留回退；设备操作日志全量保存 logs/。
注意：掉电本身安全（复位即恢复），但 reboot2/SysRq-b 兜底；扫测后若设备存活，退回日常态（cam-mode.sh off 或直接保持，报告实际状态）。命令 + 原始日志方式汇报，编排者会独立复跑。返回：每步命令+输出摘要+判定结论。`
  }),
  runs.run('m1-tree', {
    agent: 'worker',
    task: `M1：干净上游资产树构建（全主机侧，不碰设备）。仓库 /home/xuqianhui1001/y700-elden。
必读：
- TASKS.md §7 M1 定义 + archive/topics/UPSTREAM-REVIEW-2026-10-04.md（分级 A/B/C/D 与 payload 清单：125 改 + 11 新文件 ≈12.4k 行，相对主线 v7.2）
- DEVICE.md 相关内核树说明

步骤：
1. 建 M1 工作树目录（建议 build/m1-upstream/ 或按 review 档案 §4 指定的位置）：upstream tip（GEEKiDoS 上游或 gitlab 镜像 y700-elden-kernel main=fe54fcfff 起点需查 RESOURCES/UPSTREAM-REVIEW 档案确认 upstream tip 口径）+ payload 重放（剔除 D 类补丁与 vk 历史提交，只重放 A/B/C 级 125 改+11 新文件）。
2. git log 确认无 vk 历史/D 类混入。
3. 编译验证：交叉编译 aarch64 defconfig 通过（scripts/build-kernel.sh 或等价），dtbs_check 状态报告。
4. 产出 = 能编出 vk 等价功能镜像的干净树 + 编译产物路径 + 与 vk80 镜像的功能等价对照清单（哪些 payload 已含）。
长任务：构建设时间盒（timeout -k 包裹，≤2h 单次），失败先记录再重试。返回：树位置、commit 清单摘要、编译结果、与 vk80 等价性对照。`
  })
]);
emit({
  sweep: results[0] ? { output: results[0].output, error: results[0].error } : null,
  m1: results[1] ? { output: results[1].output, error: results[1].error } : null
});
