# vk129（CONFIG_SUSPEND=y）启动即死：根因 = 模块 ABI 与内核 ABI 不一致（非 suspend 代码 bug）

- **日期**：2026-10-20
- **pi 会话**：P1（suspend 启动即死取证）实跑
- **结论**：**不是 suspend 代码路径的 bug**，是 `struct device` 布局变化 + `CONFIG_MODVERSIONS` 未开 ⇒
  运行在机（未重编）的 `coresight.ko` 用旧偏移读 `dev->fwnode`，读到 ARM64 指令字节，随即 0 级翻译故障 panic。
- **证据**：`reports/artifacts/vk129-panic-screen-20261020.txt`（用户拍照 OCR，6–7 次上电中抽到 1 次亮屏）
- **设备状态**：已回滚 `boot_b` → vk127，2026-10-20 16:05 复核 `uname -r` = `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty` ✅

---

## 1. 数字结论

| 项 | 结果 |
|---|---|
| vk129 上机（240 s 等 SSH） | ❌ 未起来（与 vk128/vk129 历史两次同型） |
| 串口证据 | ❌ 空（**通道自身故障**，见 §4，不是「没 panic」） |
| panic 栈 | ✅ **拿到**（屏幕 OCR，`reports/artifacts/vk129-panic-screen-20261020.txt`） |
| 崩溃点 | `software_node_notify+0x54/0x110` ← `device_add` ← `cscfg_init` ← `coresight_init` |
| 崩溃时刻 | `[0.551493]`（启动 0.55 s，udevd 加载 `coresight.ko` 时） |
| 非法地址 | `0x0003201faafe03f1`（含 `1faafe03e9` 片段） |
| `x1` / `x2` 的值 | `d503201faafe03e9` / `a9be7bfd6a5233f` = **ARM64 指令字节**（`d503201f`=nop、`a9be7bfd`=stp、`6a5233f`=and） |
| `dev->fwnode` 偏移（开 PM_SLEEP 后编译） | `0x2b0`（= 688，pahole `build/m1-73/vmlinux`） |
| `dev->fwnode` 偏移（PM_SLEEP=n 编译） | `0x278`（= 632，pahole `build/vk83-tree/vmlinux`） |
| **两棵树的偏移差** | **56 字节**（`sizeof(dev_pm_info)` 280 → 336，同样差 56） |
| 设备在机模块 `coresight.ko` | `143032 B`，`/lib/modules/7.3.0-rc7-debug-vk127-…-dirty/`，**2026-10-17 构建** |
| **判定** | **ABI 失配**（`CONFIG_MODVERSIONS` 未开 ⇒ 无 CRC 门，坏模块照样加载） |

## 2. 根因推导（指令级）

`linux/drivers/base/swnode.c:65`：

```c
static inline struct swnode *dev_to_swnode(struct device *dev)
{
	struct fwnode_handle *fwnode = dev_fwnode(dev);   // 读 dev->fwnode @ 偏移 X
	if (!fwnode) return NULL;
	if (!is_software_node(fwnode)) fwnode = fwnode->secondary;
	return to_swnode(fwnode);                          // is_software_node() 再解引用一次
}
```

panic 的 `Code:` 是 `f9400021 b4000101 b140043f 540000c8 (f9400422)`：

| 指令 | 含义 |
|---|---|
| `f9400021` | `ldr x1, [x1]` —— 读 `fwnode->secondary`（x1=坏指针 → 加载到指令字节） |
| `b4000101` | `cbz x1, ...` |
| `b140043f` | `cmn x1, #1` |
| `540000c8` | `b.hi ...` |
| **`f9400422`** | **`ldr x2, [x1, #8]`** ← 访存故障点，x1 = `0x...1faafe03e9` |

所以链条是：**`dev->fwnode` 拿到了错误的值** → 该值指向的内核文本被当成结构体读 → `secondary` 读出 `a9be7bfd6a5233f` / `d503201faafe03e9` 这种指令字节 → 解引用即 0 级翻译故障。

`dev->fwnode` 为什么会错？因为 `software_node_notify()` 是**内核正文（vmlinux）**的一部分，
而 `struct device` 的布局由**内核构建时的 .config** 决定：

```
struct device {                                    /* linux/include/linux/device.h */
	...
	struct dev_pm_info	power;      /* ← 位置随 CONFIG_PM_SLEEP 变化 */
	struct dev_pm_domain	*pm_domain;
	...
	struct device_node	*of_node;
	struct fwnode_handle	*fwnode;    /* ← 偏移随 power 的大小一起移动 */
	void			(*release)(...);
};
```

`struct dev_pm_info` 头文件里对 `CONFIG_PM_SLEEP` 是**真 `#ifdef`**，两个分支成员数差一截：

```c
#ifdef CONFIG_PM_SLEEP
	struct list_head  entry;
	struct completion completion;
	struct wakeup_source *wakeup;
	... 8 个 bool:1 ...
#else
	bool  should_wakeup:1;
#endif
```

实测：vk129 内核（`CONFIG_PM_SLEEP=y`）`sizeof(dev_pm_info)=336`、`dev->fwnode` 在 **688**。
vk127 配置（`CONFIG_SUSPEND=n`）那份内核里这个偏移要小 **~60–70 字节**。

⇒ **只要「内核重编了（偏移变了）而不在镜像里的模块没重编」**，模块按旧偏移访问 `struct device` 就会踩到相邻字段。
`coresight` 恰好是**唯一在启动早期（udevd 阶段）自动加载、且会 `device_register()` 一个软件节点设备**的驱动 ⇒ 第一个炸的就是它。

**实测两棵树的偏移对比**（`pahole` 直接量）：

| 树 | `CONFIG_PM_SLEEP` | `sizeof(dev_pm_info)` | `dev->fwnode` 偏移 |
|---|---|---|---|
| `build/vk83-tree`（= vk127 配方基线） | 0 | 280 | **632** |
| `build/m1-73`（= vk129 配置） | 1 | 336 | **688** |

差 **56 字节**。vk127 时代编的 `coresight.ko` 按 632 读，内核按 688 布局 ⇒ 读到的是 `of_node`/`pm_domain` 附近的内容，再被当成 `fwnode_handle *` 解引用。

## 3. 为什么历史结论「suspend 代码本身启动即死」是错的

`reports/suspend-enable-vk128-vk129-fail-20261018.md` §2 的推理是「diff 只有 15 项、全是 suspend 连带项 ⇒ 必然归因 suspend 代码」。
**前提漏了一项**：那 15 项改变了 `struct dev_pm_info` 的大小 ⇒ 改变全部模块的 ABI。
「配置差异」与「模块 ABI 差异」是两件事，前者看起来无害，后者才是致死原因。

决定性旁证：**加载崩溃的是 `coresight.ko`（`Modules linked in: qcaeeee(*) coresight(+)`），
它 2026-10-17 构建、属于 vk127 那棵 `CONFIG_SUSPEND=n` 的树**；而 vk129 只是换了内核，**模块树没跟着重编**。
真正的 suspend 代码（`kernel/power/suspend.c`）根本没被执行到 —— 崩在 0.55 s、`udevd` 加载模块时，连 `pm_suspend()` 都没进。

## 4. 本轮另一个独立缺陷：串口通道在设备重启时自停（假阴性）

`logs/suspend-capture-20261020-155259.serial.log` 只有一行 `===== relay ... =====`，看起来像「没有 panic」。

实际原因：

```
elden-serial-logger.service: Active: inactive (dead) since 15:52:47
  Process: ... (code=killed, signal=HUP)
```

unit 里 `BindsTo=dev-ttyACM0.device` —— 设备一重启 `/dev/ttyACM0` 消失 ⇒ systemd **正常停止**该 service；
而 `Restart=always` **不覆盖 BindsTo 触发的停止** ⇒ 节点回来也不自启。
这是 PITFALLS #359 的同型缺陷，只在 unit 层又出现一次。

**两处修复**（本轮已改脚本，unit 修复待做）：
1. `serial_probe` 失败必须**硬失败**（`start_serial` 里现在只是 `⚠️` 警告）；
2. unit 的 `BindsTo=` 去掉，改脚本内部重连循环 + `Restart=always`。

## 5. 验证「ABI 失配」的最短实验（下一轮）

单变量、零风险：**只把模块树重编到与 vk129 内核同一棵**，其余一字不改。

```bash
# 1) 用 vk129 的内核配置重编模块（同一个 build/m1-73 树，已经是 .config=CONFIG_SUSPEND=y）
make -C build/m1-73 -j"$(nproc)" modules
make -C build/m1-73 modules_install INSTALL_MOD_PATH=/tmp/mods-vk129

# 2) 上机前核对：新 coresight.ko 的 vermagic 与 vk129 逐字相同
modinfo -F vermagic /tmp/mods-vk129/lib/modules/<UTS>/kernel/drivers/hwtracing/coresight/coresight.ko

# 3) 刷 vk129 内核 + 把 /tmp/mods-vk129 的模块树部署到设备 /lib/modules/<UTS>
#    （PITFALLS #293：RAM/新内核启动前必须先部署对应模块树，否则无 DRM）
```

**判据**
- 若板子**能起来** ⇒ ABI 假设成立，vk128/vk129 的全部失败都作废，suspend 从此可以正常开发；
- 仍崩在 `software_node_notify` ⇒ ABI 假设被推翻；此时开 `CONFIG_MODVERSIONS=y` 重编，让加载器直接报 CRC 不匹配，把问题变成显式错误而不是 panic。

## 6. 顺带值得记的一条

`CONFIG_MODVERSIONS` 未开 ⇒ 内核与模块之间**没有任何 ABI 校验**，失配只会表现为随机 panic/数据损坏。
本项目常年「内核每轮重编、模块树有时不重编」（#293 就是这个坑的一次显形），建议在构建脚本里加一条硬门：
**镜像 UTS 必须在 `/lib/modules/<UTS>` 存在且 `coresight.ko` 等早期模块的 md5 与本次构建产物一致**，否则拒绝出镜像。

## 7. 关联

- `reports/suspend-enable-vk128-vk129-fail-20261018.md`（本报告推翻其 §2 归因）
- `reports/artifacts/vk129-panic-screen-20261020.txt`（原始日志）
- `PITFALLS #293`（模块树未部署 → 无 DRM）、`#359`（串口静默假阴性）
- `scripts/lib-serial-source.sh`、`scripts/suspend-boot-panic-capture.sh`
