# droidloom 启动四道门 + 两条判读纪律（#614）

> 索引行见 `PITFALLS/README.md` 第 269 行。首次打通：2026-11-11 上机（L3 `applications` 列出 2 个应用、L4 Settings 窗口上屏，用户目视确认）。

## #614 droidloom 起不来先过这四道门，别怀疑内核

`droidloom-doctor` 全绿只说明**宿主侧前置**成立；cell 真起不来时，2026-11-11 实测踩到的是下面四道，全部是「实验装置 vs 契约」而不是 droidloom 的 bug。

### ① `[FAIL] Dedicated Android UID/GID mapping range`

- 判据：doctor 报 `largest subordinate UID range: 0 IDs`、`contract requires one contiguous range of 100000 IDs`。
- 根因：`/etc/subuid`、`/etc/subgid` 只给桌面用户分了区间，doctor 以 **root** 身份检查 ⇒ root 名下一条都没有。
- 处置：两个文件各补一行 `root:400000:100000`（必须与既有区间不重叠：实测本机已占 `100000-165535` 与 `300000-399999`）。

### ② `unsafe Android storage parent: …/users/<uid>/data`

- 根因：`runtime/droidloom-supervisor/src/host_storage.rs:15-27` 的 `check_parent()` 用 `parent.ancestors()`，**包含 parent 自身**，逐级要求 `uid==0 && mode & 0o022 == 0`。
- 实测本机要改四处：`/`（原 `1000:1000 0775`）、`/var`、`/var/lib`（原 `1000:1000 0755`）、`…/users/<uid>/data`（原属主是桌面用户、`0700`）。
- ⚠️ `PITFALLS #608` 说「别去改这些目录的属主」—— 那是**基于波及面**的保守结论。2026-11-11 用户明确授权（安卓线已不需要保留）后实测：改完 droidloom 通过、系统其余功能无回归。
- 只改属主/模式，**不动其下内容**；`data/` 里的 Android 数据不动。

### ③ `droidloomctl: validate direct host Android storage: No such file or directory`

- 根因：`validate()` 要求 `data_dir/{data,metadata}` **两个直接子目录**存在（`DIRECTORIES = ["data","metadata"]`）；唯一有权创建它们的 `prepare()` 跑在**桌面用户**下，而父目录已按 ② 改成 `root:0755` ⇒ `create_dir` 被拒，且 **`prepare` 仍然返回成功、无输出**（假成功，最坑的一环）。
- 处置：手工 `mkdir`，权限 `0755`、属主 root（与 `prepare()` 内部分支一致）。

### ④ `unshare: failed to execute /usr/bin/droidloom-supervisor: 没有那个文件或目录`

- 根因：runtime **硬编码 `/usr/bin/droidloom-*`**；把发行包摊在 `/opt/dl-test` 时，二进制都在 `/opt/dl-test/usr/bin`。
- 处置：给 `droidloom`、`droidloomd`、`droidloom-supervisor`、`droidloom-wayland`、`droidloom-applications`、`droidloom-audio`、`droidloom-gpu-server`、`droidloom-doctor`、`droidloomctl` 在 `/usr/bin` 建符号链接。

## 两条判读纪律

- **`droidloomctl start` 报 `Droidloom's boot-managed Android cell is not running` 具有误导性**：user unit `droidloom.service` 的 `ExecStartPost` 才是 `droidloomctl start --cell`；无 Wayland 会话/env 时直接跑 `start` 会走「等 droidloomd 回答」的 250 s 超时路径。**看判据请直接看 `start --cell` 的返回**（`started cell u1001`）。
- **`droidloomctl launch` 要裸包名**：`com.android.settings` 可以，`com.android.settings/com.android.settings.Settings` 会报 `invalid Android package name`（`applications` 列出来的第二列是 Activity，不是 launch 的入参格式）。

## 仍未解（2026-11-11）

- 通知通道 ABI 死循环：user journal 反复 `Droidloom notifications: invalid Android frame; disconnected` ↔ `Android connected`；`droidloom-wayland` 宣告 `DROIDLOOM_NOTIFICATIONS_ABI=3`，Android 侧帧解析失败 ⇒ 通知不可用 + 刷日志。
- 内核必须带 `CONFIG_NF_TABLES`（本机 = `vk187b`）；`fastboot boot` 起来是 RAM 态，**重启即失效**。
