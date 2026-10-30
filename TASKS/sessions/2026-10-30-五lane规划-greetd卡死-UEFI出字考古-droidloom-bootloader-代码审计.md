# 五 lane 规划（含设备实测）：关机 greetd 卡死 / UEFI 出字考古 / droidloom 构建 / bootloader 替代 / 代码审计

- 日期：2026-10-30
- pi 会话 id：01a18ba7-aaca-7573-b847-a59cffc47f1d
- 主题：按用户点名的四个未完成问题并行派发规划 lane；本轮同时把「不需要人手」的部分直接上机执行
- 结论：
  1. **关机 90 s 卡死 = greetd 上游死锁（已证）**：`check_children()` 持 `inner` 写锁去 `await start_greeter()`，
     而 SIGTERM 处理 `terminate()` 要同一把写锁 ⇒ 主进程永不退出 ⇒ 卡满 90 s（systemd 缺省 `TimeoutStopSec`）。
     6/6 有 greetd 的 boot 全部卡满 90.0 s（90.027–90.233 s），同 boot 其它超时单元 0 个；关机总长 90.2 s。
     只在「关机瞬间刚拉起 greeter」的窗口触发（PAM 开会话比 `Stopping greetd` 早 **0.16 ms**）。
     **设备侧止血已装**（drop-in `zz-stop.conf`：`TimeoutStopSec=5` + `ExecStop=greetd.stop` 先杀 session-worker），
     `systemctl show` 已核 `TimeoutStopUSec=5s` / ExecStop 在位；**真验证需一次关机（→ 未做）**。
  2. **UEFI「哪一版能上屏出字」定案 + 交棒判据被推翻（本轮设备实测）**：
     - 能出字的 4 枚 10-05 产物 sha 全部定位；盘上全丢，但 **CI artifact 未过期**（9.7 MB）⇒ 本轮已取回
       `lenovo-y700g4_NOSB.img` = `9607a394…`（`out/uefi-1005-recover/`）。
     - 「文字」不是 ConOut/GOP，而是 `DEBUG()` 经 `FrameBufferSerialPortLib` 直写 framebuffer
       （`PakalaNoSb.dsc:31 USE_SCREEN_FOR_SERIAL_OUTPUT=1`；`Andromeda.dsc.inc:201 SerialPortLib=`；
       `Include/Resources/font5x12.h:35 SCALE_FACTOR 1` ⇒ 1904×3040 上 5 px 字高 = 「看不清」）。
     - **原始 10-05 件今天不交棒**（`OKAY [10.143s]`），与我们同结构重建件（shim 112 B 逐字节同、FV 都 4 MiB、
       header v3、总长 2 441 216 B）表现一致 ⇒ **交棒与镜像无关，是设备/ABL 侧状态**。
     - **同镜像同会话连发 3 遍**：`OKAY`（不交棒）/ `FAILED usb_read`（交棒）/ 无设备 ⇒ **交棒是随机的**（本轮 ~1/3）。
     - 交棒后现象（用户现场）：**不亮屏、随即复位回落 Android**；最小判别件（12 KB = shim + 72 B 裸程序写
       `0xFC800000` 品红）交棒后 **屏幕无可肉眼所见信息**，150 s 内无 fastboot/SSH。
  3. **droidloom 形态反转**：它是 **namespace 容器 cell，不是 VM**（全树 `/dev/kvm|qemu|virtio|tcg` 0 命中），
     故「aarch64 无 KVM ⇒ 不可行」这条旧阻塞**不成立**；x86_64 是硬编码门（`PKGBUILD.in:6`、`main.rs:121`），
     但上游 ARM64 产品层存在且更早（20 项 build-proven 模块），缺的只是宿主二进制 + 打包门。
     精确卡点 = phoc 0.58.0 registry 缺 `wp_linux_drm_syncobj_manager_v1`（实测 `wayland-info | grep -c syncobj` = 0）。
  4. **bootloader 替代**：SM8750 替代类开源 bootloader **0 个**（lk2nd 止于 msm8996、U-Boot 无 board/config、
     coreboot 有 `src/soc/qualcomm/` 但无 SM8750 且产物要过 MBN 签名链）；本机 ABL 本身即 EDK2/DXE（59 个 DXE 模块）。
     裁决仍相容：UEFI 搁置、kexec 仅调试快环；**第 0 号待办 = 真机验证 9008**（`download_mode` 现为 off，
     未验前任何 `abl`/`xbl` 写入判「不可接受」）；`backup/` 内**无** `xbl`/`abl` dump。
  5. **代码审计 lane**（第 5 条，本轮未收口）：范围 = 上游规范 / 职责重复冲突 / 需求对不上 / 缺失四类。
- 证据指针：
  - `reports/shutdown-greetd-hang-plan-20261030.md`（57 KB，6/6 复现 + 源码级死锁 + 三级修复）
  - `reports/uefi-text-console-archaeology-plan-20261030.md`（45 KB，四枚产出定案 + 文字机制 + 最短复现）
  - `reports/droidloom-build-device-plan-20261030.md`（47 KB，容器 cell 定性 + ARM64 缺件 + M1 执行单）
  - `reports/bootloader-alternatives-survey-20261030.md`（54 KB，分层矩阵 + 三处前提更正 + 回退判据）
  - `reports/code-style-and-duty-overlap-audit-20261030.md`（审计 lane 产物，收口中）
  - `reports/artifacts/uefi-e1v0b-20261030/`（10-30 15:04 E1-v0b 未归档事故的补证：`OKAY [10.110s]` = 未交棒）
  - 本轮新产物：`out/uefi-1005-recover/PakalaPkg/ci_artifacts/lenovo-y700g4/lenovo-y700g4_NOSB.img`
    （`9607a394…`）、`/tmp/uefi-text-20261031/{T1-v3,T2-v0}.img`、`/tmp/fbtest/{FB-v3,FB2-v3}.img`（临时件，未入库）
- ★SSOT 待并入：
  - `TASKS/README.md` §5 **Q25（UEFI）**：补「原始 10-05 件今天同样不交棒 ⇒ 交棒是随机的，与镜像无关」+
    「交棒后不亮屏即复位」；`reports/uefi-consolidated-20261030.md` §3 的 B 系列判据需按本条改写。
  - `PITFALLS` 待新增三条（本文件先记，索引待并入）：
    ① **`Booting OKAY [10.1s]` ≠ 启动成功**：ABL 试 10 s 未交棒也回 OKAY；唯一「真交棒」判据是
      `FAILED (usb_read failed: No such device)` 或 fastboot 立刻掉线。
    ② **`fastboot boot` 在设备处于 Linux（非 fastboot）时不会报错**：会 `< waiting for any device >` 直到超时被杀，
      据此判「已交棒」是假阳性（本轮踩到一次）。
    ③ **greetd 关机 90 s 死锁**：`KillMode`/`SendSIGKILL` 已是缺省且会话在 `user.slice/session-c*.scope`（不在 greetd
      cgroup）⇒ 常规手段无效；解法 = `ExecStop` 先杀 `--session-worker` + `TimeoutStopSec=5`。
  - `DEVICE/README.md` §1.1：本轮在机镜像未变（vk172），未写盘（全程 `fastboot boot` 零写盘），仅 `boot_b`
    槽位属性补写 `mark-successful`（0x77 → 0x7f，retry 7→7）。
- 未做 / 下一步：
  1. 关机 3 连测（需用户在场）验证 90 s → ≤2 s。
  2. `FB2-v3.img`（写屏后 PSCI SYSTEM_RESET2 回 fastboot）**已构建未上机** ⇒ 这是不依赖肉眼的执行判据，
     待设备窗口再试。
  3. UEFI 复活条件：先修「交棒随机」再谈 Mu；否则改判据走串口/`ttyACM` 或放弃屏上出字。
  4. droidloom M1-b（设备装 6 个 `-dev` 包 + rustup）与 phoc syncobj 两件，均未开工。
  5. 审计 lane 收口后按其 P0 清单另派实施 lane。

## 审计 lane（L5）收口 + 编排者独立复核（2026-10-30 18:2x）

- 产物：`reports/code-style-and-duty-overlap-audit-20261030.md`（80 KB）——
  **54 条发现：P0 10 / P1 21 / P2 23**（A 上游规范 4/9/9、B 职责重复 2/5/8、C 需求对不上 3/3/3、D 缺失 1/4/3）。
  A1 机械门：108 个 patch → 81 个 0/0/0，合计 1 E / 35 W / 10 C（其中 24 W = 已知假阳性）。
- **编排者独立复核（不采信自报，三条 P0 全部复现）**：
  1. **A1-11 门禁命令本身有缺陷（已复现）**：同一枚 `aw86927-20260527-v2/0001-*` 在**仓库根**跑
     `checkpatch --strict` → `3 errors / 35 lines checked`（把 patch 当源码扫、patch 级检查全跳过）；
     复制到 `/tmp` 跑 → `0 errors / 1 warning / 8 lines`（真实值）。⇒ **历史上任何「仓库根 0E/0W/0C」都不足为凭**，
     `patches/upstream/README.md` §1 的命令必须改成「先 cp 到空目录再跑」。
  2. **C-01/C-02/D-01 传感器口径崩塌（设备实测复现）**：`hexagonrpcd` = **failed**（`Could not open FastRPC node
     (/dev/fastrpc-adsp)`），`/dev/` 只有 `fastrpc-adsp-secure`/`fastrpc-cdsp`/`fastrpc-cdsp-secure`，
     `busctl … HasAccelerometer/HasAmbientLight/HasProximity` = **false/false/false**。
     根因：`fastrpc.c:2599` 以 `qcom,non-secure-domain` 决定是否建非安全域实例，而该属性只存在于
     `build/vk151` 的**未提交工作区改动**（`sm8750.dtsi` diff 可见）⇒ **在机 vk172 的 DTB 早于这行**。
     ⇒ `TASKS/README.md` G1-34 的 ✅「三真」**与在机状态不符**，需改回未完成。
  3. **B7-01 ABI 门禁默认检退役树（已复现）**：`scripts/check-abi-config.sh:56` `CONF=${1:-$ROOT/build/m1-73/.config}`
     ⇒ 裸跑恒绿，检的不是 `patches/current-tree` 指向的 `build/vk151`。
- 用户已核实的「三条无问题」：b5 bonded 表已独立成 `sm8750_dsi_cfg`；Q34 固件门禁真存在且会 FAIL；G1-34 的 udev 门禁三件齐全。
- 待用户裁决（SSOT 改动，本轮未动）：① G1-34 是否改回未完成 + `DEVICE/README.md` §1.1 svc 400 口径；
  ② 三处门禁（checkpatch 命令 / `check-abi-config.sh` 默认目标 / `deploy-camera-modules.sh` 加 ABI 门）是否立即修。

## 用户批准后的落地（2026-10-30 18:4x，「都改」）

1. **SSOT 更正（G1-34 由 ✅ → 🔴）**：`TASKS/README.md` G1-34 行首改为「🔴 在机不通（2026-10-30 复核推翻）」，
   写明 `hexagonrpcd` failed / 无 `/dev/fastrpc-adsp` / 三属性 false / 根因 `fastrpc.c:2599` +
   `qcom,non-secure-domain` 只在未提交工作区；10-27 的判定降级为「仅在镜像带该 DT 属性时成立」。
   `DEVICE/README.md` §1.1 传感器段同步改写，并显式作废旧口径「svc 400 可见 ⇒ 正常」。
2. **三处门禁修复**：
   - `patches/upstream/README.md` §1：checkpatch 命令改为「用 `patches/current-tree` 解析现役树的
     `scripts/checkpatch.pl`（仓库根根本没有这个文件，旧写法本身是坏的）+ 先 cp 到空临时目录再跑」，
     并写明坑的实测数字（仓库根 3E/35 行 vs `/tmp` 0E/1W/8 行）。
   - `scripts/check-abi-config.sh`：默认目标从写死的 `build/m1-73`（已退役树）改为
     `patches/current-tree` 指向的现役树；解析失败则报错退出（不再静默取旧树）。
   - `scripts/deploy-camera-modules.sh`：在 vermagic guard 之后新增 **ABI gate**（调 `check-abi-config.sh`
     比对模块构建树 vs SSOT 参考 config），不一致即 `REFUSING`。
3. **用修好的门复跑全量 upstream patch（76 枚）**：**1 ERROR / 22 WARNING / 10 CHECK**。
   唯一 ERROR = `Fixes:` 指向的 commit subject 不符（审计 A1-01）——**未改**：涉及已投递系列的正文，
   需单独裁决（改 patch 正文会与已发送内容不一致）。
