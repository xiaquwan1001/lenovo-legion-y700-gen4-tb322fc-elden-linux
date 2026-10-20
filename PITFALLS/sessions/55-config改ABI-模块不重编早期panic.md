## 五十五、改内核 config 会改 ABI：模块不重编 ⇒ 早期 panic（2026-10-20 实受）

**现象**：给 vk127 只加 `CONFIG_SUSPEND=y`（15 项 suspend 连带开关，看起来完全无害）出 vk128/vk129，
上机后「只亮背光、SSH 不上、十几秒关机」。6–7 次上电里抽到 1 次亮屏，屏幕上是完整 panic：

```
[0.551493] Unable to handle kernel paging request at virtual address 0003201faafe03f1
[0.551663] Internal error: Oops: 0000000096000004 [#1] SMP
[0.551671] Modules linked in: qcaeeee(*) coresight(+) fuse system_heap fsaa4400
[0.551750] pc : software_node_notify+0x54/0x110
[0.551908] x2 : a9be7bfd6a5233f  x1 : d503201faafe03e9
[0.551922] Call trace:
[0.551929]  software_node_notify+0x54/0x110 (P)
[0.551940]  device_add+0xdc/0x800
[0.551950]  device_register+0x24/0x40
[0.551959]  cscfg_init+0xb0/0xd10 [coresight]
[0.551974]  coresight_init+0x6c/0xf8 [coresight]
[0.551996]  do_init_module+0x5c/0x270
[0.552129] Kernel panic - not syncing: Oops: Fatal exception
```

**判读的关键**：`x1`/`x2` 的值是 **ARM64 指令字节**（`d503201f`=nop、`a9be7bfd`=stp、`6a5233f`=and），
不是指针。说明内核把 `dev->fwnode` 读到了错误位置，而那个位置的内核文本被当成 `fwnode_handle` 解引用。

**根因**：`struct dev_pm_info` 里对 `CONFIG_PM_SLEEP` 是真 `#ifdef`（两个分支成员数差一截），
而 `struct dev_pm_info power` 在 `struct device` 里排在 `fwnode` **之前** ⇒ 开关一变，`dev->fwnode` 偏移就动：

| 树 | `CONFIG_PM_SLEEP` | `sizeof(dev_pm_info)` | `dev->fwnode` |
|---|---|---|---|
| `build/vk83-tree`（vk127 配方） | 0 | 280 | **632** |
| `build/m1-73`（vk129 配置） | 1 | 336 | **688** |

差 56 字节。设备上 `/lib/modules/7.3.0-rc7-debug-vk127-…/coresight.ko` 是 **2026-10-17 用 632 那个布局编的**，
新内核按 688 布局 ⇒ 模块读到相邻字段，崩在启动 0.55 s、`udevd` 加载 `coresight` 时。

**为什么没被拦住**：`# CONFIG_MODVERSIONS is not set` ⇒ 内核与模块之间**没有任何符号 CRC 校验**，
失配不会报错，只会变成随机 panic / 静默数据损坏。

**教训（可推广）**

- **「配置差异」≠「行为差异」**：任何 `#ifdef` 进结构体、进函数签名的 config，改它就是改 ABI。
   只加 `CONFIG_SUSPEND` 这类"看起来只是开关"的选项，一样要**整树重编模块**。
- 出镜像的硬门（本项目应该固化）：
   **镜像 UTS 必须在 `/lib/modules/<UTS>` 存在，且早期模块（`coresight` 等）的 md5 与本次构建产物一致**，
   否则拒绝出镜像。这与 #293（RAM 起新内核不部署模块树 ⇒ 无 DRM）是同一个坑的两副面孔。
- 归因纪律：看到「只加了个开关就启动即死」，**先问这个开关改不改结构体布局**，
   而不是去读那个子系统的代码找 bug。vk128/vk129 的原报告（`reports/suspend-enable-vk128-vk129-fail-20261018.md` §2）
   就是因为漏了这一步，把 ABI 失配误判成「suspend 代码本身启动即死」，白等了 2 天。
- 强烈建议开 `CONFIG_MODVERSIONS=y`：能把这类失配从「随机 panic」变成「加载时明确报 CRC 不匹配」。

**证据**：`reports/suspend-panic-rootcause-20261020.md`、`reports/artifacts/vk129-panic-screen-20261020.txt`

---

## 五十六、systemd `BindsTo=` + `Restart=always` 不会重连：串口日志静默停摆（2026-10-20 实受）

**现象**：P1 实跑，设备 panic 重启后串口日志只有一行头，看起来像「没有 panic」。

**根因**：

```
elden-serial-logger.service: Active: inactive (dead)
  Process: ... (code=killed, signal=HUP)
```

unit 用了 `BindsTo=dev-ttyACM0.device`。设备一重启 USB gadget 重建 `/dev/ttyACM0` ⇒ 节点**消失** ⇒
systemd 按 `BindsTo` **正常停止** service；而 `Restart=always` **只覆盖「非正常退出」**，
不覆盖 `BindsTo` 触发的停止 ⇒ 节点回来后服务永久停着，日志停在旧内容。

这与 #359（`stty || true` + `cat 2>/dev/null` 把权限失败吞成空日志）是**同一个假阴性的第二个来源**：
一个在脚本层、一个在 unit 层。

**修法**（已落地）：

- `scripts/serial-fanout.sh` 改成**自己**轮询等节点 + 重连（`while true` + `wait_port`），
   每次 open/close 都写 `===== serial open/closed =====` 到日志，断连有痕；
- unit 去掉 `BindsTo=`，只留 `After=`，重连责任在脚本，systemd 只管 `Restart=always` 兜底；
- **探针失败必须硬失败**：`suspend-boot-panic-capture.sh` 的 `start_serial` 原来只是
   `⚠️ 探针未通`，现在拒绝继续（除 `ALLOW_NOSERIAL=1`）——空日志绝不能再被当成证据。

**教训**：`Restart=always` 的语义是「进程异常退出就重启」，**不是「服务应当一直处于 active」**。
凡是用 `BindsTo=` / `PartOf=` / `Requires=` 挂了会消失的设备的 unit，都要问一句
「设备走了服务被正常停止，设备回来谁会重启它」。

**证据**：`logs/suspend-capture-20261020-155259.serial.log`、`systemctl status elden-serial-logger`

---

## 补充（2026-10-20 晚）：假设已实证，并补一条部署坑

**实证结果**：内核字节级不变（`Image.gz` sha `f2d073bd…`，与 vk129 镜像内 kernel 逐字相同），
**只重编并部署模块树** ⇒ vk129 完整起机：

```
[  329.559017] cs_system_cfg: CoreSight Configuration manager initialised
```

`cs_system_cfg` 那行是 `cscfg_init()` 的最后一句 —— 原来 panic 的
`device_register → device_add → software_node_notify` 整条链路走通了。`dmesg` oops=0，
`/sys/power/state` = `freeze mem`，`mem_sleep` = `[s2idle] deep`。

⇒ **改 config 必须整树重编模块**这条结论，从此有上机证据，不再只是推理。

**追加的部署坑（同一次踩到）**：设备 `/tmp` 是 **tmpfs 7.3 GB**。
547 MB 的模块 tar 传进 `/tmp` 再解包成 1.5 GB ⇒ 空间不足 ⇒ **静默截断成 1005/1497 个 `.ko`**，
`coresight.ko` 缺失、`modules.dep` 0 字节，设备随后自动重启回落。

部署大目录的四条纪律：

- 落点用**磁盘分区**（本项目 `/` = 189 G），不要 `/tmp`；
- 传完先比 **sha256**，解包前确认字节数；
- 解包后**断言 `.ko` 数量**（本项目 1497）与关键模块存在，不靠「tar 返回 0」；
- ssh 长命令加 `ServerAliveInterval=15` —— 大 tar 解包会断连（首次断在 1197/1497）。

**证据**：`reports/vk129-abi-fix-verified-20261020.md`、`reports/artifacts/vk129-abi-fix-verified-20261020.txt`
