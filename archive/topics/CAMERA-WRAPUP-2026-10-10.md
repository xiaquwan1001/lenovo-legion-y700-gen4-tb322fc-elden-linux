# CAMERA-WRAPUP-2026-10-10 — camera MODULE 驱动线收尾（host-side only）

> 收尾整理（本会话，主机侧；**全程未触设备**——另一 agent 持锁 192.168.7.1）。
> 状态权威 = `TASKS.md` §1 G1-5 / G1-33 / §5 Q24 / §8.5；本文件只做过程、工具集整理与两个 §8.5 决策的**建议答案**（不改 TASKS.md / INDEX.md，由编排者裁决回填）。

## 1. 当前状态（编排者已核事实，此处复述）

- 相机 `.ko` 全部已装在设备 `/lib/modules/7.2.0-debug-vk64.../` 下。
- 设备上部署的**只有** `/usr/local/sbin/camera-modules-load.sh` + `/usr/local/sbin/cam-mode.sh`；
  `camera-stream-up.sh`、`keep-awake.sh`、`cam-load-verify.sh` **未部署**（存在于主机 `scripts/`，需要时 scp）。
- 日常安全态 = cmdline `elden_nocamera=1`（栈不加载，熄屏安全）；相机**只用** `cam-mode.sh on/off`
  （camera-in-place ⇄ screen-off **互斥二选一**，用户裁决 Q24/G1-33 + PITFALLS #160）；相机**不固化进日常态**。
- **2026-10-09 23:14 已证**：`CAM_FORCE=1 camera-modules-load.sh` 18 s 加载全栈 20 模块，双摄出真实帧
  （前 distinct=255/stddev=36.8，后 243/34.7；10-bit packed 帧长 = W×H×1.25）。

## 2. 已证明什么（证据链 + PITFALLS 引用）

| 事实 | 引用 |
|---|---|
| 驱动出帧 + libcamera soft ISP + Snapshot 预览/拍照/录像可用 | G1-5（TASKS §1）；PITFALLS #130 |
| dma-buf：只 `system_heap`，**绝不 `cma_heap`**（DmaHeap 探测序 CMA 优先 → ENOMEM） | PITFALLS #130 |
| 前后摄 180° 修正（DT 取补角，内核 `8b69eb153`） | G1-5 ④ |
| Q24 根因 = 单模块 `cambistmclkcc-sm8750` × DT 电源域；H1/H2/D1/D2 均未根治 | G1-22/G1-33、TASKS §5 Q24、PITFALLS #132（头部摘要） |
| 操作口径 = 互斥二选一（cam-mode.sh on/off），不固化进日常态 | PITFALLS #160、G1-33 |
| 守卫不静默 / lsmod 连字符⇄下划线 / `kernel/` 前缀误判 | PITFALLS #157 |
| media-ctl entity I2C 总线号随 probe 漂 → 运行时按驱动名+地址解析 | PITFALLS #158 |
| rc=0 ≠ 真画面；帧长公式 W×H×1.25；distinct/stddev 廉价判据 | PITFALLS #159 |
| timeout 不能跑 shell 函数（第三次同型静默失败） | PITFALLS #161 |
| 上游报告已发（cambist Q24，linux-arm-msm，2026-10-08） | `archive/topics/UPSTREAM-REPORT-cambist-q24-2026-10-08.md` |

## 3. 工具集整理（本会话所做）

8 个相机脚本的角色划分（全部保留，零删除）：

| 脚本 | 角色 | 部署？ |
|---|---|---|
| `camera-modules-load.sh` | **核心**：幂等加载相机栈（depmod + 依赖序 modprobe；`elden_nocamera` 守卫 + `CAM_FORCE` 旁路） | ✅ /usr/local/sbin（build-modular-overlay.sh 也安装它） |
| `cam-mode.sh` | **核心**：互斥操作口径（status/on/off + blank disable/restore；先禁熄屏再加载） | ✅ /usr/local/sbin |
| `deploy-camera-modules.sh` | 主机侧：向**运行中**设备部署模块 tar 包（scp + depmod + load），零刷机回退路径 | 主机 |
| `package-camera-modules.sh` | 主机侧：从 modules_install staging 打 `out/camera-modules-<KV>.tar.gz`（kmod 兼容 index） | 主机 |
| `probe-camera-sensors.sh` | 主机/设备两用：**只读**探测（DT/I2C/V4L2/模块/config/IIO/SLPI） | 主机 |
| `camera-stream-up.sh` | 设备采集助手：媒体图 pad 格式统一 + 链路使能 + 试抓帧（非破坏性） | ❌ 未部署（scp 上去用） |
| `cam-load-verify.sh` | 设备验证助手：加载 + dmesg 前后差分 + #130 合规断言 | ❌ 未部署（scp 上去用） |
| `keep-awake.sh` | 设备助手：单独禁熄屏/挂起/锁屏（与 `cam-mode.sh blank disable` **重叠**） | ❌ 未部署 |

本会话实施的纯文档级编辑（无行为变化，`sh -n` 全绿）：
- `keep-awake.sh`：头部注明与 `cam-mode.sh blank disable` 的重叠关系、保留理由（2026-10-09 在机用过 + 不动相机时单独禁熄屏）、未部署提醒。
- `camera-stream-up.sh`：头部用法从 `/tmp/...` 更正为部署后路径，注明未部署 + 2026-10-09 23:14 验证证据。
- `cam-load-verify.sh`：头部注明未部署、与 `cam-mode.sh on` 的分工（后者是日常操作，本脚本是取证工具）。

**不做删除**：`keep-awake.sh` 被 `cam-load-verify.sh` 头部注释引用且 2026-10-09 实测路径在档；
`deploy-camera-modules.sh` 是零刷机回退路径仍有效；`probe-camera-sensors.sh` 只读探测仍有价值。
编排者如想进一步收敛，唯一安全候选是未来某天删 `keep-awake.sh`（确认无人引用后）——本次未做。

## 4. 剩余非阻塞项

1. **后摄过曝 / 高光压制偏慢**：IPA 调优（libcamera `simple` IPA 无 s5kjns 校准 yaml）。
2. **Snapshot 缺聚焦/曝光调节 UI**：app 功能基础，非驱动问题。
3. **`cambistmclkcc` Q24 根治**：上游报告已发（2026-10-08），等上游回复；期间保持互斥口径。

## 5. 两个 TASKS §8.5 开放决策 —— **建议答案（供编排者裁决，不改 TASKS.md）**

### ① 是否把 vk78-modular 刷成 boot_b 日常用？

**建议：暂不刷，等一个前置条件补测后再刷。**
理由：
- 相机链在 `elden_nocamera` **不设**（即相机模块随 /init 自动加载）的配置下**未测**过——
  而 vk78-modular 的 `/init` 门控已不再挂 `elden_nocamera`（TASKS §8.5「已修」），刷上去就等于
  **相机模块常驻日常态**。这直接违反 Q24/G1-33 用户裁决（相机不固化进日常态：相机在位时熄屏掉电是常态，#160）。
- 换言之：在 cambistmclkcc 上游根治（或证明相机在位熄屏安全）之前，**任何把相机栈带进日常启动的镜像都不该当 boot_b**。
- 补测命令（下次持锁时，编排者执行；**本次未触设备**）：
  `fastboot boot out/boot-elden-vk78-modular.img` 后 `lsmod | grep -cE 'camss|cci|camcc|bist'`（预期 =0 或 =20 取决于 /init 门控），
  再 `scripts/cam-load-verify.sh` + `scripts/sleep-sweep.sh` 做相机加载态熄屏扫测；即便如此，结论也只影响「测过没」，**裁决仍是 Q24 口径**。
- 若 vk78-modular 的 /init 门控确实不再挂 `elden_nocamera`，刷 boot_b 前应先确认设备上
  `/proc/cmdline` 的 `elden_nocamera=1` 语义（payload 层门控 vs cmdline 层）——两者缺一，相机就会进日常态。

### ② 是否把 payload-modules-load.sh 同步到持久根 /usr/local/sbin？

**建议：不同步到持久根；把需求改写为「随镜像层走」。**
理由：
- 持久根 `/usr/local/sbin` 现已有 `camera-modules-load.sh`（功能等价，vk64 在用），再放一份
  `payload-modules-load.sh` 会造成**同名职责双份**，违反「一个概念一个拼写」——两份加载器哪份生效
  取决于调用方，正是 #157「静默失败」这型事故的温床。
- `payload-modules-load.sh` 的存在意义在 **ramdisk/payload 层**（mod-loop 热换、镜像自包含），
  与持久根无关；它已经在镜像层工作正常（mod-loop 7 s 热换环已验收，TASKS §8.5）。
- 若确实需要持久根侧有 payload 语义，建议做**一个入口**：在 `camera-modules-load.sh` 头部加一行
  指针注释（「payload 层对应 payload-modules-load.sh，热换场景用那个」），而不是复制脚本。
  这一步本次**未做**（属于 DEVICE 行为之外的纯文档，但脚本已部署在机，改主机 repo 会与在机副本漂移，
  留给下一次持锁部署时一并 scp 同步）。

**给编排者的精确待办（下次持锁）**：
1. 补测命令（① 的前置）：见上 `fastboot boot` + lsmod + cam-load-verify/sleep-sweep。
2. 如裁决同意 ② 的「不加第二份」：下次部署时把更新后的 `scripts/keep-awake.sh`、
   `scripts/camera-stream-up.sh`、`scripts/cam-load-verify.sh`（本次加了头部说明）scp 到设备
   `/usr/local/sbin/` 或按需忽略（三者在机均无）。
