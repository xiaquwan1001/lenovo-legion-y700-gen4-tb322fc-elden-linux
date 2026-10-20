# vk129（CONFIG_SUSPEND=y）上机成功：ABI 根因假设**已实证**

- **日期**：2026-10-20
- **实验**：纯单变量 —— 内核字节级不变，只把模块树按 vk129 配置重编
- **结论**：**ABI 失配假设成立**。`reports/suspend-enable-vk128-vk129-fail-20261018.md` 的「suspend 代码本身启动即死」归因**正式推翻**，vk128/vk129 的失败全部作废
- **设备状态**：跑着 vk129 内核（`CONFIG_PM_SLEEP=y`），**s2idle + deep 均可用**
- **原始取证**：`reports/artifacts/vk129-abi-fix-verified-20261020.txt`

---

## 1. 数字结论

| 项 | 修复前（vk129 内核 + vk127 模块树） | 修复后（vk129 内核 + vk129 模块树） |
|---|---|---|
| 启动 | ❌ 只亮背光，`[0.55 s]` panic | ✅ **完整走到用户态**（`ath12k`/WiFi 关联/BT/elogind session 全通） |
| 崩溃点 | `software_node_notify+0x54` ← `cscfg_init` | ✅ `[329.559] cs_system_cfg: CoreSight Configuration manager initialised` |
| `dmesg` oops 计数 | 1（`Internal error: Oops … [#1]`） | ✅ **0** |
| `coresight` 模块 | 加载即 panic | ✅ `modprobe rc=0`，`coresight 98304 0` |
| `/sys/power/state` | — | ✅ `freeze mem` |
| `/sys/power/mem_sleep` | — | ✅ **`[s2idle] deep`** |
| 模块数 | 1005（部署截断）/ 143032 B coresight | ✅ **1497**（全树 vermagic 一致），coresight 3 456 536 B |
| 内核字节 | `Image.gz` sha `f2d073bd…` | ✅ **同一份，未重编** |

**单变量性**：`vmlinux` / `Image.gz` 在实验全程未被重建（mtime 仍是 2026-10-18 18:20），
`sha256(Image.gz) == sha256(vk129 镜像内 kernel)`。唯一变化 = 模块树 ABI。

## 2. 决定性日志

```
[  329.559017] [ T3978]  cs_system_cfg: CoreSight Configuration manager initialised
```

这行来自 `coresight-syscfg.c:1310`，是 `cscfg_init()` 的**最后一句**。也就是说
`cscfg_create_device() → device_register() → device_add() → software_node_notify()`
整条链路（= 原来 panic 的那条）完整走通了。修复前它崩在 `software_node_notify+0x54`。

## 3. 判据对照（§5 预先写下的判据）

| 预写判据 | 实测 | 结论 |
|---|---|---|
| 「能起来 ⇒ ABI 假设成立」 | ✅ 起来了 | **成立** |
| 「仍崩在 `software_node_notify` ⇒ 假设被推翻」 | 未发生 | — |

---

## 3.5 追加：真实 s2idle 挂起/唤醒实测（2026-10-20 17:00）

上面证明了「能起机、suspend 能力在」。本节是**真的进了一次 suspend 并成功唤醒**：

```
[424.875757] PM: suspend entry (s2idle)
[424.881754] Filesystems sync: 0.005 seconds
[424.892431] Freezing user space processes completed (elapsed 0.001 seconds)
[424.892440] OOM killer disabled.
[424.893486] printk: Suspending console(s) (use no_console_suspend to debug)
[426.296374] PM: suspend exit
```

| 判据 | 值 | 说明 |
|---|---|---|
| `suspend_stats/success` | **1** | 成功进入过一次 |
| `suspend_stats/fail` | **0** | 零失败 |
| `last_failed_errno` | **0** | — |
| `boot_id` | `aa883b60…`（挂起前后相同） | **没有重启**，是真挂起不是崩溃重启 |
| `PM: suspend exit` | 出现 | 正常 resume |
| `dmesg` oops | **0** | — |
| 唤醒后 `wlan0` | UP / LOWER_UP | 网络栈完好 |
| 唤醒后输入设备 | 7 个 `/dev/input/event*` | 触屏/按键在 |
| 唤醒后相机模块 | 2 个（camcc + cambist） | 未丢 |

⚠️ **口径**：本次只验证「suspend 机制可用」，**功耗/掉电率未测**（那是 T9）。
也**不得**与 Q24（相机×熄屏挂死）混谈 —— 两者是独立故障线。

取证原文：`reports/artifacts/vk129-suspend-verified-20261020.txt`

## 4. 本轮踩到并修掉的三个坑（都可能重复咬人）

### 4.1 `make olddefconfig` 不带 `ARCH` 把配置写成 x86

`.config` 从 `52ae455f…`（arm64）被改成 `0fb67a2f…`（x86）：
`CONFIG_CC_VERSION_TEXT` 变宿主机 gcc、`CONFIG_DRM_SCHED` `=y→=m`、`CONFIG_KERNEL_GZIP` 被重置。
已从 `patches/config-suspend-s2idle-20261018-173529` 恢复，并**用镜像内嵌 ikconfig 逐字校验**通过。
→ `PITFALLS #357`

### 4.2 宿主机静默文件损坏再次复现（第二次）

`internal compiler error: 段错误` @ `include/linux/netdevice.h:2441`，随后
`verify-tree-integrity.py` 查出 **14 个** tracked 文件损坏（AMD dcn/gc/hdp、nouveau mxms、ov02e10、mwifiex）。
用 `git cat-file -p HEAD:<path>` 全部恢复，复验 `corrupt=0`。
→ 10-19 之后**第二次**，宿主机内存不可靠，`memtest86+` 至今未跑。

### 4.3 设备 `/tmp` 是 tmpfs（7.3 GB）导致部署静默截断

547 MB tar 解到 `/tmp` 再解包 1.5 GB ⇒ 空间不足 ⇒ **静默截断成 1005/1497 个 `.ko`**，
`coresight.ko` 直接缺失、`modules.dep` 0 字节。设备随后自动重启回落。

**教训**：往设备部署大目录时
- 落点必须在**磁盘分区**（`/` = 189 G），不要在 `/tmp`；
- 传完先比 **sha256** 再解包；
- 解包后**断言 `.ko` 数量**（本机 1497）与关键模块存在；
- ssh 长命令加 `ServerAliveInterval=15`，否则大 tar 解包会被断连打断（首次就断在 1197/1497）。

## 5. 下一步（suspend 线正式解锁）

1. **P3 掉电率实测**（原 T9）：`scripts/suspend-drain-rate.sh`，拔线，量 `%/h` + `boot_id` 不变 + 唤醒后栈完整。
   ⚠️ 明确口径：**不得计入 Q24**。
2. **s2idle vs deep 选择**：`mem_sleep` 当前默认 `s2idle`，需实测两者在 SM8750 上的实际功耗与唤醒可靠性。
3. 之后才谈 Q24 —— 相机栈 + 真实熄屏的挂死与 suspend 是两条独立线，别混。

## 6. 产物

- `reports/artifacts/vk129-abi-fix-verified-20261020.txt`（上机取证原文）
- `reports/artifacts/vk129-panic-screen-20261020.txt`（修复前 panic 屏幕 OCR）
- 模块树：本机 `/tmp/mods-abl`（1497 `.ko`）、设备 `/lib/modules/7.3.0-rc7-debug-vk127-…-dirty`
- 回滚资产：设备 `/lib/modules/vk127-backup-20261020`、`/lib/modules/…-dirty.vk127old`、`….partial`；
  主机 `bootslot-b/boot_b-vk127.img`

## 7. 关联

- `reports/suspend-panic-rootcause-20261020.md`（根因推导，本报告是其验证）
- `reports/suspend-enable-vk128-vk129-fail-20261018.md`（**其 §2 归因已被推翻**）
- `PITFALLS` #355（config 改 ABI）、#356（BindsTo 串口停摆）、#357（olddefconfig 写 x86）
- `TASKS/README.md` T8（本实验，✅ 已实证）
