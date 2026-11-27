# coresight MODULE_DEVICE_TABLE 缺失 + SM8750 TNOC periphid —— 上游候补（2026-11-27）

> 来源：`reports/capbatch-vk194-20261127.md` §7（实机证据）。目标 = 让这两个驱动**编成模块后能被 udev 自动加载**，
> 以及让 TNOC 的 amba id 能被匹配（否则 `AMBA_ID=0` 恒 unbound）。
> **投递未发生**（按 `TASKS/README.md` §7 逐系列批准）。

## 1. 两个补丁

| 文件 | 内容 | 上游现状 |
|---|---|---|
| `0001-coresight-add-missing-MODULE_DEVICE_TABLE.patch` | `coresight-tpda.c` 加 `MODULE_DEVICE_TABLE(amba, tpda_ids);`；`coresight-ctcu-core.c` 加 `MODULE_DEVICE_TABLE(of, ctcu_match);` | 两者都**没有**该宏（`git grep MODULE_DEVICE_TABLE drivers/hwtracing/coresight/` 只有 tnoc/tpdm 有） |
| `0002-arm64-dts-sm8750-tnoc-periphid.patch` | `sm8750.dtsi` 的 `tn@109ab000` 加 `arm,primecell-periphid = <0x000f0c00>;` | 上游 `sm8750.dtsi:5366` 与 `kaanapali.dtsi:5134` 都缺；缺了就 `AMBA_ID=00000000` |

## 2. 实测证据（为什么这不是「猜」）

设备 vk194（= 只开了 4 个 CONFIG，未加这两枚补丁）：

```
# 1) 模块有、能绑定、但永不自动加载
$ lsmod | grep -c coresight_ctcu        → 0        # 开机后没加载
$ sudo modprobe coresight-ctcu && readlink -f /sys/bus/platform/devices/10001000.ctcu/driver
  → .../drivers/coresight-ctcu                     # 手动加载后立即绑定
$ sudo modinfo -F alias coresight-ctcu  → 空       # 没有 of: alias
$ sudo modinfo -F alias coresight-tpda  → 空       # 没有 amba: alias

# 2) TNOC：硬件 PID 读回 0 ⇒ amba 表永不匹配
$ cat /sys/bus/amba/devices/109ab000.tn/uevent
  AMBA_ID=00000000   MODALIAS=amba:d00000000
$ sudo modprobe coresight-tnoc && ls -l /sys/bus/amba/devices/109ab000.tn/driver
  → 无（仍未绑定；`deferred probe pending: (reason unknown)`）
# 加 periphid 后（vk195）：
$ readlink /sys/bus/amba/devices/109ab000.tn/driver | xargs basename
  → coresight-trace-noc                            # 自动加载 + 绑定
```

vk195 汇总：**amba 未绑定 28 → 0**（TPDM 22 + TPDA 5 + TNOC 1 + CTCU 1）。

## 3. 本地现状（在生效中）

- 两个补丁已 apply 在 `build/daily` 工作区（下次构建即产出「有 alias」的模块）。
- vk195 那发用的是「未打补丁的模块 + `/etc/modules-load.d/elden-coresight.conf`」的兜底；上游合入后该文件可删。
- TNOC 的 DT 行已在 vk195 的 DTB 里。

## 4. 投递前还要做

1. `git format-patch` 化（补 `Signed-off-by`、commit message：为什么只有模块化才暴露 —— 这些驱动长期被当 built-in 用）。
2. `checkpatch.pl --strict` + `dtbs_check`（0002 会触发 binding 检查，`arm,primecell-periphid` 是通用属性，倾向上游能过）。
3. 收件人建议：Coresight 维护者（Suzuki K Poulose / Mike Leach / Leo Yan）+ 设备树侧（Bjorn Andersson / Konrad Dybcio）。
4. 与 `TASKS/UPSTREAM.md` §7 的 M 系列排同一批（需用户放行）。
