# Q24 复核：suspend 假设排除 + vk127 上 8/8 存活（2026-10-19）

> **用户观察**：当前设备「电源键熄屏但不触发锁屏/suspend」时，熄屏**不会**导致断电。
> 由此提出假设：**历史上的 Q24 是否是代码不规范（例如误把 suspend 卷进熄屏路径）导致的？**
>
> **结论**：**假设不成立**，但这次复核顺带产出了 Q24 最强的一组正面样本。

## 0. 数字结论

| 项 | 结果 |
|---|---|
| 本机是否支持 suspend | **否**（`/sys/power/state` 空、写入失败、无 `/sys/power/mem_sleep`、`CONFIG_SUSPEND is not set`） |
| 项目历史 config 中开启 SUSPEND 的份数 | **1 / 20**（且那一份 = 2026-10-18 失败的 vk128，从未成为日常基线） |
| 历史 Q24 台架（vk50/vk64/vk89/vk127）的 SUSPEND | **全部 = not set** |
| 本轮「完整相机栈 + 真实 dpms Off」样本 | **8/8 存活**（boot_id 全程未变） |
| 相机模块在场情况 | `camcc_sm8750` + `cambistmclkcc_sm8750` + `qcom_camss` + `s5kjns` + `gc08a8`，**17 个 `/dev/video*`**，全程在位 |
| 每发是否确认真熄屏 | 是，逐发打印 `dpms On→Off→On`，未发生跃迁的记 INVALID（本轮 0 次 INVALID） |

## 1. suspend 假设的排除（证据链）

### 1.1 现场：本机内核根本没有 suspend

```
$ cat /sys/power/state          → 空（0 字节内容，node 存在）
$ echo mem > /sys/power/state   → 写入失败
$ ls /sys/power/mem_sleep       → No such file or directory
$ zcat /proc/config.gz | grep SUSPEND
  # CONFIG_SUSPEND is not set
  CONFIG_ARCH_SUSPEND_POSSIBLE=y
```

⇒ **“熄屏”在当前内核里物理上不可能进入 suspend**。这也正是用户观察到的
「电源键请求挂起 → 内核里没有挂起 → 什么都不发生」的真因（`TASKS` §5 Q24 尾部 2026-10-18 条目、
`PITFALLS` §47/#336 已记录）。

### 1.2 历史：Q24 那些台架也都没有 suspend

项目 `patches/config-*` 共 20 份存档，逐个检查 `CONFIG_SUSPEND`：

| 产物 | `CONFIG_SUSPEND` |
|---|---|
| `config-vk50-modular`（模块化基线） | **not set** |
| `config-vk89-modular`（Q24 臂构建基座） | **not set** |
| `config-vk127-working-20261018`（当前在机） | **not set** |
| `config-daily-c1`、`config-vk76-modular`、`config-vk95-c1routing` 等 | **not set** |
| `config-suspend-s2idle-20261018-173529` | **`=y`**（唯一一份；= vk128，**上机即死、已回滚**） |

⇒ **历史上任何一次 Q24 实验，其内核都不具备 suspend 能力**。
所以「Q24 是 suspend 误入」这条解释**在时间线上就不成立** —— 不是"查不出来"，而是**那个能力当时不存在**。

### 1.3 机制：Q24 的熄屏路径也不经过 suspend

历史 Q24 的「真实熄屏」一直有两种下达方式（`reports/q24-n7-vk127-20261017.md` §3）：

- **B 臂（主用）**：`gdbus org.gnome.ScreenSaver.SetActive(true)` —— 会话层，只驱动 phoc 的 DPMS 关屏；
- **K 臂（已废弃）**：写 `/sys/class/drm/card0-DSI-1/dpms` —— 本机 **sysfs 只读**（root 也写不进，
  `PITFALLS` #294），所以历史上实际只有 B 臂在用。

两条路都只走 **DPMS（显示电源态）**，与 `PM_SUSPEND`（整机 sleep state）是**不同的内核子系统**。
`ScreenSaver.SetActive(true)` 不会调用 `pm_suspend()`；在 `CONFIG_SUSPEND=n` 的内核上更无从谈起。

## 2. 本轮的正样本（有价值的副产品）

当前设备恰好处在 Q24 的**理想台架**上：

- 内核 `7.3.0-rc7-debug-vk127-…`（可编可二分的那条线）；
- **完整相机栈在位**：`camcc_sm8750` + `cambistmclkcc_sm8750`（即 `PITFALLS #212` 的"配对"）
  + `qcom_camss` + 双 sensor，**17 个 `/dev/video*`**；
- **已连续运行 14 小时以上未被复位**（`uptime` 53820 s 起步）。

在该状态下执行 9 发「真实 dpms Off + hold + 唤醒」：

```
round 1..8: ALIVE  dpms On->Off->On   （每发 hold 22 s，逐发确认跃迁）
另有 1 发 hold 60 s:ALIVE（boot_id 不变、uptime 连续 53820→53886 s）
```

**全部存活**，`boot_id = bdf43b01-d8c6-4224-a617-8921f930552b` 全程未变，
相机模块数全程 = 5 / `/dev/video*` = 17（**死后会清空，这是 Q24 的签名之一**）。

⇒ 与 `reports/q24-n2prime-both-arms-survive-20261015.md`（12 发存活）与
`reports/q24-n7-vk127-20261017.md`（12 发存活）一致，**7.3 线累计存活样本增至 41 发**。

## 3. 这对 Q24 口径的影响

**不改变「未解」口径，但把靶点收窄了**：

1. **排除项新增「suspend 误入」**——不是"未验证"，而是**能力不存在 + 时间线不成立**，可以彻底划掉。
2. **`PITFALLS #212`（配对 + 熄屏 = 最小触发）在 7.3 线依然不可复现**（累计 41 发存活），
   与 `reports/q24-n2prime-*` 的判定一致。
3. **「镜像血统」仍是唯一受实测支持的候选**：历史致死只在 **vk64（7.2 血统）** 上复现过
   （`reports/q24-n5-*`，n=2: 1 死 1 活），7.3 线从未致死。下一步仍是 **N5b**（vk64 上扩到 n≥5）
   或 **N6'**（在 vk127 上反向加回 7.2 payload 子集做二分）。

## 4. 待验证 / 未做

- **N5b 未跑**：需要把 vk64 刷进 `boot_b` 或 `fastboot boot`，样本量才够。本轮是"顺手取正样本"，
  不构成对照。
- **Q28 显示态本轮是 GOOD**（`dpms=On`、面板正常、`phoc` 存活），未覆盖 BAD 臂；
  但 `q24-n7` 已证明显示态无判别力，故本轮不做。
- **真正的对照实验**应该是「同一物理机 + 同一栈 + 只在 7.2/7.3 之间切换内核」，
  这正是 N5b/N6' 的设计。

## 5. 方法论

- **"历史上能力不存在"比"历史上测过但没测出来"强得多**：本轮的排除不靠复现，
  靠 **config 存档逐个 grep** —— 20 份里只有 1 份有 SUSPEND，且那份从未成为基线。
  做排除项时优先找这种**能力级证据**，比再跑一遍实验便宜得多。
- **样本要连同"台架现状"一起记**：本轮之所以有价值，是因为它同时满足
  「完整栈在位 + 长时间未复位 + 真实 dpms 跃迁」三个条件，而不是"随便熄个屏"。

## 6. 关联

- `reports/q24-n2prime-both-arms-survive-20261015.md`、`reports/q24-n7-vk127-20261017.md`
- `reports/q24-n5-vk64-death-reproduced-20261015.md`（唯一致死复现）
- `reports/suspend-enable-vk128-vk129-fail-20261018.md`（SUSPEND 开启即死）
- `PITFALLS` #208（判据纪律）、#209（自恢复）、#212（配对触发）、#294（dpms 只读）、§47/#336
