# hexagonrpcd 可写 overlay：整理成上游 PR #31 并在 hexagonfs 层次上机复验

> 2026-11-27（第二轮，承接 `hexagonrpcd-writable-overlay-20261127.md`）。结论：**旧实现重构为上游能接受的分层，真机复验通过，PR 已投递并转 ready**。
> 产物：`patches/userland/hexagonrpc-pr31-20261127/`（`git format-patch` 原文 6 提交）；PR https://github.com/linux-msm/hexagonrpc/pull/31

## 0. 数字结论

| 项 | 值 |
|---|---|
| PR | #31（draft → **ready for review**），6 提交，17 文件 **+1277/−81** |
| 每提交构建+测试 | **6/6 绿**；全仓 `ninja test` **4/4**（新增 `overlay` 用例）；编译告警 **0** |
| GitHub 门 | **DCO pass**；`Build+test` = `action_required`（首次贡献需维护者批准跑 workflow） |
| 上机 | TB322FC 真重启：`active` / `NRestarts=0` / `--failed` 空 / 三属性 true / `ssccli` Z≈±9.54 |
| overlay 真写入 | `cam_registry_dump.txt` 18628 B、`fstempfile` 6851 B、`sns_reg_version` 9 B、`registry/DIR` 3 B |
| 部署二进制 | sha256 `0a8ef526…a8afd92d7`（回滚件 `.bak-20261127` = `4a7946b2…c192f7f`） |

## 1. 为什么必须换层次

旧实现把 overlay 分派放在 `apps_std`（fd ≥ 1000），绕过了 `hexagonfs_*`；维护者在 #21 里画的方案是文件系统级
（读先查可写目录、写模式 copy-up，落点 `/var/hexagonrpcd`），且 lumag 明确「只读树里的文件被删/改就报错」。review 会卡层次不一致。

现在：

- `hexagonfs_openat_write()`：copy-up + 打开 overlay 文件（`O_RDWR|O_CREAT[|O_APPEND]`）。
- `hexagonfs_openat()` **overlay-first**：文件在 overlay 里就服务 overlay，目录/虚拟项仍走 `-R`。
- `struct hexagonfs_fd` 增 `vpath`（DSP 可见路径），由 `hexagonfs` 统一维护；各 backend 分配 fd 改 `calloc` 以免 `vpath` 未初始化。
- `hexagonfs_remove()/rename()`：overlay 里没有、`-R` 里有时返回 **-EPERM**（不误删只读树）。
- `apps_std` 只做转发，方法表只声明观察到的方法（5/23/24/33/34/35/36）。

## 2. 上机一个反直觉点（写验收的触发条件）

**正常 boot 不会触发写**：`rpcd_builder` 已把 `-R/sensors/registry/sns_reg_version` 挂出来，DSP 读到就认为 registry 已持久化、不重写。
首轮把 overlay 目录清空重启后 40 分钟里 `find /var/lib/hexagonrpc -type f` 为空、而传感器仍全绿 —— 不是写失败，是**没进入写路径**。
把 `sns_reg_version` 从 `-R` 树临时移走（等价 first attach）后重启，4 个文件立刻出现，验完已还原。

## 3. 部署坑（会在发行版里复现）

`-O` 目录必须**预先存在且对运行用户可写**：`/var/lib` 下 unprivileged `mkdir` 失败 ⇒ `Could not initialize write overlay …: Permission denied`
⇒ 写侧静默关闭（服务照常 active、传感器照常工作，只有写不落盘）。已在 man page 写明；发行版侧建议 `tmpfiles.d`。

## 4. 判据（照抄）

```sh
ssh elden 'systemctl is-active elden-sensorspd; systemctl show -p NRestarts elden-sensorspd'
ssh elden 'sudo find /var/lib/hexagonrpc -type f -printf "%s %p\n"'
ssh elden 'busctl get-property net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy HasAccelerometer'
ssh elden "ssccli --sensor accelerometer | tail -2"
```

## 5. 仍开放

1. `'w'` 是否 `O_TRUNC`（现与上机版本一致=不截断，未做 A/B）。
2. ftell/flen/fileExists/ftrunc/mkdir/rmdir 未声明（签名属猜测，写错只影响单方法）。
3. 维护者可能要求 rebase 到 #21 分支；`git am` 本目录 6 个 patch 即可。
