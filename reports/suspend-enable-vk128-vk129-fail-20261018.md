# 开启 CONFIG_SUSPEND 的两次尝试都失败（vk128 / vk129）——2026-10-18 晚

> **结论：`CONFIG_SUSPEND=y` 在本机 7.3-rc7 重放树上会让内核在早期启动阶段死掉；
> 现象 = fastboot 交接后只亮背光、SSH 连不上、约十几秒后关机。未定位，暂缓。**

## 0. 数字结论

| 项 | 值 |
|---|---|
| vk128（`olddefconfig` 方式加 suspend） | ❌ 失败：只亮背光 → 约 15 s 后关机 |
| vk129（**只**加 suspend、其余回钉 vk127 config） | ❌ **同样失败**（用户实机 fastboot flash 验证） |
| vk127（`CONFIG_SUSPEND=n`，当前在机） | ✅ 正常 |
| 两次失败的共同点 | 都只有 `CONFIG_SUSPEND` 组差异（vk129 已把 vk128 多引入的 `KEXEC`/`ARCH_SUPPORTS_KEXEC` 全部移除） |
| 判定 | **不是配置污染**（vk129 的 diff 已收到 15 项、全是 suspend 连带项），而是 **suspend 代码本身在这棵树上启动即死** |
| 设备状态 | 已回滚到 `boot_b-vk127`（可用，`Sat Oct 17 17:06:17` 那个内核） |

## 1. 现象（用户实机）

```
fastboot flash boot_b bootslot-b/boot_b-vk12{8,9}.img   → OKAY
fastboot reboot                                          → OKAY
→ 背光亮，SSH 连不上（192.168.7.1:22 timeout）
→ 约十几秒后关机
```

- 背光 = bootloader 点亮的，SSH 从没起来 ⇒ **内核在启动早期就死了**，不是"起来了但网络没起"。
- "十几秒后关机" 与 cmdline 的 **`panic=15`** 吻合 ⇒ **极可能是 panic 后自动重启**。

## 2. 为什么不是"配置改坏了"

`build/m1-73/.config` 有两份可对照的快照：

| 文件 | sha256 | 用途 |
|---|---|---|
| `patches/config-vk127-working-20261018`（= 原 `backup/m1-73-config-vk127-20261018.config`） | `9d38ae13…` | **与 `out/boot-elden-vk127.manifest` 的 `config_sha256` 逐字一致** ⇒ 确是能启动的那份 |
| `patches/fragment-suspend-s2idle.config` | — | 只含 `SUSPEND`/`PM_SLEEP`/`SUSPEND_FREEZER`/`PM_AUTOSLEEP=n`/`HIBERNATION=n` |

vk129 = 上表第一份 + 第二份，**且 vk128 多出来的 `ARCH_SUPPORTS_KEXEC`/`KEXEC` 已强行移除**。
最终 diff 只有 15 项，全部属于 suspend 连带项：

```
CONFIG_SUSPEND=y / CONFIG_SUSPEND_FREEZER=y
CONFIG_PM_SLEEP=y / CONFIG_PM_SLEEP_SMP=y / CONFIG_PM_SLEEP_DEBUG=y
CONFIG_PM_GENERIC_DOMAINS_SLEEP=y
# CONFIG_PM_AUTOSLEEP is not set
# CONFIG_PM_TEST_SUSPEND is not set
# CONFIG_PM_USERSPACE_AUTOSLEEP is not set
# CONFIG_PM_WAKELOCKS is not set
CONFIG_VT_CONSOLE_SLEEP=y
CONFIG_FW_CACHE=y  # CONFIG_FSL_RCPM is not set      （依赖自动带入，与本机无关）
```

⇒ vk129 失败**必然**归因于 suspend 代码路径本身，而不是"改错了别的开关"。

## 3. 下一步该怎么查（未执行）

1. **先取 panic 栈**（最关键，一次就能定性）：
   - vk129 的 cmdline 已经带 **`printk.always_kmsg_dump`**（本次新增），ramoops 在 DT 里（`ramoops@c2000000`、16 KiB）且 `CONFIG_PSTORE_RAM=y`。
   - 但**失败后设备会自动重启**，ramoops 是否残留未经实测 ⇒ 下次验证要：失败后**先别断电**，等它重启回 vk127，再 `mount -t pstore pstore /sys/fs/pstore && ls`。
   - 若 pstore 空：改用 **`panic=0`**（不自动重启）或直接走 `/dev/ttyGS0` 串口抓完整 dmesg。
2. **怀疑点（静态，未验）**：`CONFIG_PM_GENERIC_DOMAINS_SLEEP=y` + 本机大量 `rpmhpd` 域
   （已知 `sync_state` 门控在开机窗口一次性求值，见 Q24/N1b）⇒ suspend 框架在启动末期
   让 genpd 参与"未使用域关断"（`genpd_power_off_unused`），可能把某个启动关键域关掉。
   二分法：只开 `CONFIG_SUSPEND=y` 但 `PM_GENERIC_DOMAINS_SLEEP=n`（需先确认是否可独立关闭）。
3. **对照 7.2 血统**：`build/base-7.2` 有 `CONFIG_SUSPEND`，而 vk64（7.2 内核）历史上能启动。
   若 7.2 树 + suspend=y 能起，则问题是 7.3 重放线独有的（可二分提交集）。
   ⚠ 但 `base-7.2` 的 `.config` 已不在树内，需重建同配置才可比。

## 4. 附带的两个真实收益（与失败无关，已确认）

- **`fastboot boot`（RAM 内核）在本机不可靠**：`fastboot boot out/boot-elden-vk128.img` 报 OKAY，
  但设备回落到磁盘的 boot_b，`/proc/version` 时间戳仍是旧内核 ⇒ **必须 `fastboot flash` 才真正生效**，
  且 `verifiedbootstate=orange` 下需要 AVB 签名（`scripts/sign-boot-b.sh`，公钥 sha1 `1e54e86e`）。
  另：本机 ABL **没有 `fastboot fetch`**（#290），所以刷前无法读回备份 ⇒ 靠 `bootslot-b/*.img` 存档回退。
- **UTS 必须与在机模块目录逐字一致**：`LOCALVERSION=-vk127` 才能得到
  `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty`，否则已部署的 1597 个 `.ko` 全部失效
  （含相机模块 ⇒ 相机直接不可用）。

## 5. 现场

- 设备：`boot_b` = `bootslot-b/boot_b-vk127.img`，运行中，SSH 可用。
- 仓库：`out/boot-elden-vk12{8,9}.img` 与 `bootslot-b/boot_b-vk12{8,9}.img` 均在盘（`/out/*` 与 `bootslot-b/` 视 gitignore 而定），
  两份 config 快照入库（`patches/config-vk127-working-20261018`、`patches/fragment-suspend-s2idle.config`）。
