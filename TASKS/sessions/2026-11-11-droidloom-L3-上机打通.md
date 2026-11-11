# 2026-11-11（第二段）— droidloom **L3 上机打通**（Android ready + 应用列表）

- **日期**：2026-11-11 中午
- **pi 会话 id**：本段会话（关键词「我们先做 droidloom，这个对用户观测要求更低」）
- **主题**：把 droidloom 从「L3 结构性阻塞」推到「cell 起来 + Android ready + `applications` 列出应用」
- **结论**：
  1. **L3 判据达成**（原文判据 = 「`droidloomctl start` 后 `droidloomctl applications` 列出 Android 应用」）：
     `droidloomctl start --cell` → `started cell u1001`；`droidloomctl wait` → **`Droidloom is running; Android is ready`**；
     `droidloomctl status` → `cell u1001 is running from /etc/droidloom/cell.json; Android is ready`；
     `droidloomctl applications` → **`listed 2 Android applications`**（Files `com.android.documentsui`、Settings `com.android.settings`）。
     另 `droidloomctl launch com.android.settings` 已把 Settings 进程拉进 cell（uid 1000，host PID 3626/14630）。
  2. **前提：内核必须换成 vk187b**（`CONFIG_NF_TABLES`）。在机 boot_b 的 vk185 上 `droidloom-doctor` 报
     `[FAIL] Private veth and nftables networking`（`CONFIG_NF_TABLES is disabled`）⇒ doctor 不 ready，cell 起不来。
     本轮按既有零写盘法：`/usr/local/sbin/reboot2 bootloader`（**Debian 根上原本没有这个件，从 `out/reboot2/reboot2`
     拷进去才可用**；`/sbin/reboot bootloader` 是 busybox 包装，不进 fastboot）→ `fastboot boot out/boot-elden-vk187b.img`
     → UTS `7.3.1-debug-vk184-00002-g4da9a8b69fc8`，`/lib/modules` 有对应目录，ssh 12 s 就绪。
  3. **一共四个门禁，逐个关掉（都是"契约 vs 实验装置"问题，不是 droidloom 的 bug）**：
     | # | 报错 | 根因 | 处置 |
     |---|---|---|---|
     | ① | `[FAIL] Dedicated Android UID/GID mapping range` | `/etc/subuid` 只分配给了桌面用户 1001 | 追加 `root:400000:100000`（与 100000-165535 / 300000-399999 不重叠）到 `/etc/subuid` + `/etc/subgid` |
     | ② | `unsafe Android storage parent: …/1001/data` | `host_storage.rs:15-27 check_parent()` 用 `ancestors()`（**含自身**）要求 `uid==0 && mode&022==0` | 已在前一段完成（`/`、`/var`、`/var/lib`、`…/1001/data` 全 root:root 非组写） |
     | ③ | `droidloomctl: validate direct host Android storage: No such file or directory` | `validate()` 要求 `data_dir/{data,metadata}` 两个直接子目录存在（`prepare()` 才有权建，且以 0755/root 建） | 手建 `…/1001/data/{data,metadata}`，0755 root（`prepare` 以桌面用户跑，因父目录 root 0755 无法创建，静默无输出） |
     | ④ | `unshare: failed to execute /usr/bin/droidloom-supervisor: 没有那个文件或目录` | `/opt/dl-test` 实验装置里二进制都在 `/opt/dl-test/usr/bin`，而 runtime 硬编码 `/usr/bin/droidloom-*` | 给 `droidloom{,d,-supervisor,-wayland,-applications,-audio,-gpu-server,-doctor,ctl}` 在 `/usr/bin` 建符号链接指向 `/opt/dl-test/usr/bin` |
  4. **`droidloomctl start` 与 `start --cell` 的差别是实打实的坑**：user unit `droidloom.service` 的 `ExecStartPost` 等于
     `droidloomctl start --cell`；在没有 Wayland 会话/env 时直接跑 `droidloomctl start` 会走「等 droidloomd 回答」的超时路径
     并最终报 `Droidloom's boot-managed Android cell is not running`（**误导性**：其实只差 cell 这一步没发）。判据看 `start --cell` 的返回。
  5. **仍然开着的一个真缺陷**：通知通道死循环 —— user journal 反复
     `Droidloom notifications: invalid Android frame; disconnected` / `Android connected`。
     `droidloom-wayland` 宣告 `DROIDLOOM_NOTIFICATIONS_ABI=3`，Android 侧帧解析失败 ⇒ 通知不可用 + 刷日志。
     未定位（下一步：对 ABI 3 的帧格式与 Android 侧发送端版本对齐）。
- **证据指针**：
  - 设备上装的是 `/opt/dl-test`（usr/bin 八个件 mtime 11-05 19:47），`/etc/droidloom/{cell.json,package-state.json,runtime.env}`，
    `systemd` 单位 `/etc/systemd/system/droidloomd.service` + `~/.config/systemd/user/droidloom.service`（`Type=notify`，`ExecStartPost=droidloomctl start --cell`）
  - 镜像在 `/opt/dl-test/usr/lib/droidloom/images/images/{system.img 959 MB, vendor.raw.img 1073741824 B, product.img, system_ext.img}`（2.4 G）
  - 复现命令见本文 §结论 1/2/3 的命令行（全部经 `runuser -u xuqianhui1001 -- env XDG_RUNTIME_DIR=/run/user/1001 …` 走桌面用户）
- **★SSOT 待并入**：
  - `TASKS/README.md` §0/§5：droidloom **L1 ✓ / L2 ✓ / L3 ✓（2026-11-11 上机）** / L4 待目视确认；G2 数字据此更新。
  - `PITFALLS/README.md` 增一条：「droidloom 的四个启动门禁（subuid 给 root / 祖先属主 / data_dir 下必须有 data+metadata /
    runtime 硬编码 `/usr/bin/droidloom-*`）——查 droidloom 起不来先按这四条过一遍，别怀疑内核。」
- **设备态**：**RAM 启动 vk187b**（`fastboot boot`，未写盘）——**重启即回 vk185，nftables 又没了**；
  cell `u1001` 运行中，Android ready，phoc/phosh 会话 `c1`（uid 1001）在 `wayland-0` 上。
