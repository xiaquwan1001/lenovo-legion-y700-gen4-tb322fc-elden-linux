# 2026-10-22 · Q28 现场取证：软件闩锁「只置位不清零」+ `link_configured` 误清

- **日期**：2026-10-22
- **pi 会话 id**：`$PI_SESSION_ID`（本轮）
- **主题**：Q28「面板 init 间歇失败」——在**活体坏发**上做运行期取证，定位到两处**新的代码级缺陷**
- **结论（一句话）**：Q28 的**不可恢复性**由我们下游 payload 自己造成：①`dsi_bonded_cmd_failed` 是**单向闩锁**（全树只有 `WRITE_ONCE(…, true)`，**零清零点**）；②`msm_dsi_host_set_display_mode()` 无条件 `WRITE_ONCE(link_configured, false)`，而它**排在 `power_on` 之后**调用 ⇒ 每次唤醒必被判 `-ESTALE`。两者叠加使「一次坏发」升级为「此后每次重试都不可能成功」。**硬件侧首次被真正测到**（此前所有「救不回」实验都被闩锁短路掩盖）。
- **证据指针**：`logs/q28-latch-20261022/`、`probes/q28latch/`、`probes/q28peek/`
- **★SSOT 待并入**：`reports/q28-DOSSIER.md` 新增 §s；`TASKS/README.md` §5 Q28 当前口径追加一条；`PITFALLS` 新增条目

## 1. 为什么这轮能取证（方法学前提）

- 起手时设备**恰在 Q28 坏发态**（`uptime` 8 min、`bonded command DMA failed: master=-110 peer=-110`、`dsi_isr=0`、`card0-DSI-1=connected` + phoc/phosh 在 ⇒ 典型「假 GOOD」）。
- 坏发现场**重启即失**（恢复只能整机复位，`PITFALLS #224`）⇒ 必须做**不重启的运行期探测**。
- 手段：内核模块（`=y` 无法换模块版，所以用**探针模块**读/写符号），vermagic 逐字匹配
  `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty`；偏移取自 `pahole -C msm_dsi_host build/m1-73/vmlinux`。
- 熄屏/唤醒走会话总线（`dpms` sysfs **只读**，`PITFALLS #294`）：
  `DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/dbus-<X>`（**从当前 `pidof phoc` 的 `/proc/<pid>/environ` 取**，`#295`）+ `org.gnome.ScreenSaver.SetActive`。

## 2. 发现 A：`dsi_bonded_cmd_failed` 是单向闩锁（零清零点）

`drivers/gpu/drm/msm/dsi/dsi_manager.c`：

| 行 | 内容 |
|---|---|
| 41 | `static bool dsi_bonded_cmd_failed;` |
| 54 | `return dsi_mgr_uses_bonded_cmd() && READ_ONCE(dsi_bonded_cmd_failed);` |
| 377、649 | `WRITE_ONCE(dsi_bonded_cmd_failed, true);` |

**全树（`build/base-7.2` / `geekidos-linux` / `build/m1-73` 三个血统）grep 结果一致：只有置位，无任何清零。**
置位后 `msm_dsi_manager_cmd_failed()` 在 **7 处**（`dsi_manager.c:292/314/367/396/429/615/681`、`dsi_host.c:1699`）无条件短路：

- `bridge_pre_enable` / `bridge_enable` / `bridge_post_disable` / `bridge_disable` / `dsi_err_worker` 直接 `return`（**不 power_off、不 disable_irq** ⇒ 这解释了本轮实测到的 `Unbalanced enable for IRQ 188/189` WARNING：唤醒时 `dsi_mgr_bridge_power_on()` 无条件 `enable_irq`，而下一次 `post_disable` 因闩锁提前返回 ⇒ 引用计数失衡）；
- `msm_dsi_manager_cmd_xfer()` 对**任何**写命令返回 `-EIO`。

后果：坏发后**每一次**面板重 init（DPMS 唤醒 / 任何 commit）都在第一条 DCS 就 `-5`，**永远不触碰硬件**。

## 3. 发现 B：`link_configured` 被 `set_display_mode()` 误清（顺序缺陷）

`dsi_host.c:2377 dsi_cmd_link_clk_set_rate()`（SM8750 专有分支）要求 6 个条件全真，否则 `-ESTALE`：

```c
if (!READ_ONCE(msm_host->power_on) ||
    !READ_ONCE(msm_host->link_configured) ||     /* ← 罪魁 */
    byte_clk_rate != link_byte_rate || pixel_clk_rate != link_pixel_rate ||
    byte_intf_clk_rate != link_intf_rate ||
    !clk_is_match(clk_get_parent(byte_src_clk), dsi_pll_byte_clk) || …)
        return -ESTALE;
```

而 `link_configured` 的写入点只有：

| 位置 | 动作 |
|---|---|
| `dsi_host.c:3069` | `power_on()` 末尾置 **true** |
| `dsi_host.c:3092`、`3129` | `power_off()` / `set_display_mode()` 置 **false** |
| `dsi_host.c:383` | `runtime_suspend` 置 false |

`dsi_manager.c:494 dsi_mgr_bridge_mode_set()` 调 `msm_dsi_host_set_display_mode()`，**在 DRM atomic 流程里排在 `pre_enable`（内含 power_on）之后** ⇒ 唤醒链路必然得到 `power_on=1, link_configured=0`。

**运行时实测（`q28peek.ko`，坏发活体，清闩锁后唤醒一次）**：

```
dsi[0] host=ffff000805369c80
  power_on=1 link_configured=0          ← 唯一不满足项
  byte  clk=108107959 link=108107959 OK
  pixel clk=172972735 link=172972735 OK
  intf  clk=108107959 link=108107959 OK
  byte_src parent / pixel_src parent    （与 dsi_pll_* 匹配，clk_is_match 不通即无法从这里区分）
dsi[1] 同型
```

三个 rate 全部相等、parent 也一致 ⇒ `-ESTALE` **只可能来自 `link_configured=0`**。

## 4. 硬件侧首次实测：引擎忙位不释放，但 CTRL 已关

清闩锁后 `SetActive false`（真实唤醒）→ 报出新签名（**此前从未出现过**）：

```
msm_dsi ae94000.dsi: stale link configuration        ×3（三次重试）
panel-novatek-nt36536: sending dcs data ff 20 failed: -116   (ETIMEDOUT)
```

直接读控制器 MMIO（`dsidump`，`/dev/mem` + `/proc/device-tree` 取基址 `0xae94000`/`0xae96000`）：

| 寄存器 | 值 | 解读 |
|---|---|---|
| `STATUS0 (0x04)` | `0x00000175` | `cmd_engine_busy=1`、`mdp_busy=1`、`dsi_busy=1`、`cmd_dma_busy=0` |
| `CTRL (0x00)` | `0x20090000` | bit0 `ENABLE=0` ⇒ 控制器**已关** |
| `TRIG_DMA (0x8c)` | `0` | 触发位已被清 |
| `TIMEOUT_STATUS (0xbc)` | `0xffff` | 全置（粘滞） |
| `INTR_CTRL (0x10c)` | `0x13ff3be0` | — |
| `CLK_STATUS (0x11c)` | `0x23f` | 无 `PLL_UNLOCKED(0x10000)`、无 `DYN_*` ⇒ **PLL 锁定、无动态时钟残留请求** |

两侧控制器逐位相同。`dsi_isr` 在整场（1769 s）**始终为 0**。

⇒ **修正 DOSSIER 既有口径**：「DYN pclk 域闩住不释放」在本发**不成立**（`CLK_STATUS` 的 DYN 位全 0、PLL 未失锁）；
实测形态是 **`STATUS0` 的 engine-busy 位自锁而控制器已 disable**（`CMD_MODE_ENGINE_BUSY|CMD_MODE_MDP_BUSY|DSI_BUSY`），
即**命令引擎内部状态机停在未完成事务**，与时钟域无关。

## 5. 与既有结论的关系（哪些被削弱/加强）

| 既有口径 | 本轮 |
|---|---|
| 「坏发 ~50%、随机、按时间成簇、与镜像无关」 | **不变**（本发仍在 vk127 上出现） |
| 「故障态不在 DSI 控制器内部」 | **削弱**：`STATUS0` 的 engine/DSI busy 位就在控制器内且自锁 |
| 「判别量 = DYN pclk 域闩住不释放」 | **本发不成立**（`CLK_STATUS=0x23f`） |
| 「恢复只能整机复位」 | **不变，但机理改写**：不是硬件不可救，而是**软件闩锁 + `link_configured` 误清**让所有重试在到达硬件前就失败 |
| 「驱动内自恢复（power off/on 后重试）」 | **仍可行，但必须先修 A+B**；且修完后仍需确认 `STATUS0` 自锁能否被 `dsi_sw_reset` 清掉（本轮未测：`set_display_mode` 挡住了） |

## 6. 下一轮的三个最小单变量实验（都可零写盘、冷起坏发上直接做）

1. **探针 B'**：模块内直接置 `link_configured=1`（并保持闩锁已清）→ 再唤醒一次。判据：是否越过 `-ESTALE`、DCS `ff 20` 是否变成真超时/真成功。
2. **探针 A'**：若 B' 后仍失败，读 `STATUS0` 是否仍为 `0x175`；若仍自锁，再做一次 `dsi_sw_reset_v2_9` 等价写序列（`CTRL` 清使能 → `CLK_CTRL|force_on` → `RESET=1` → `RESET=0`）后重读 `STATUS0`。判据：`STATUS0 & 0x19` 是否清零。
3. **正式补丁**（待 1/2 结论）：
   - A 修法 = 在 `dsi_mgr_bridge_power_on()` 成功路径里 `WRITE_ONCE(dsi_bonded_cmd_failed, false)`（或把闩锁改成「每 link 一次」而非全局一次），并让 `post_disable` 不因闩锁跳过 IRQ/power 清理（修 `Unbalanced enable`）。
   - B 修法 = `set_display_mode()` 不要清 `link_configured`（该标志语义应是「link 已按当前 rate 编程」），或在 `power_on()` 末尾之后再单独置位。

## 7. 产物

| 路径 | 内容 |
|---|---|
| `probes/q28latch/q28latch.c` | 运行期清 `dsi_bonded_cmd_failed` 的探针模块（`addr=`/`value=` 参数） |
| `probes/q28latch/dsidump.c`、`dsistat.c` | `/dev/mem` 映射 DSI 控制器，dump 关键寄存器 / `STATUS0` 解码 |
| `probes/q28peek/q28peek.c` | 读 `msm_dsi_host` 的 `power_on`/`link_configured`/rate/parent（偏移来自 pahole） |
| `logs/q28-latch-20261022/dmesg-full.txt`、`state-after.txt` | 坏发全程 dmesg + 收尾状态/寄存器/中断计数 |

**复现（需在坏发态）**：

```sh
A=$(ssh root@192.168.7.1 'grep -w dsi_bonded_cmd_failed /proc/kallsyms|cut -d" " -f1')
scp probes/q28latch/q28latch.ko root@192.168.7.1:/tmp/
ssh root@192.168.7.1 "insmod /tmp/q28latch.ko addr=0x$A value=0"   # before=1 after=0
# 然后走会话总线 SetActive false 唤醒，观察 -ESTALE / -116
G=$(ssh root@192.168.7.1 'grep -w msm_dsim_glb /proc/kallsyms|cut -d" " -f1')
ssh root@192.168.7.1 "insmod /tmp/q28peek.ko glb=0x$G"             # power_on=1 link_configured=0
```

## 8. 纪律提醒

- **探针模块会 taint 内核**（`O`）且**改变行为**（清闩锁后进入此前不可达的路径）⇒ 只能用于取证，不得进任何上游包 / 不得进日常镜像。
- 本轮设备**未写盘**、未重启；`boot_b` 仍 = `vk127`；实验后闩锁已被清（写入的是 RAM 里的静态变量），**设备仍处坏发态，恢复仍靠整机复位**。
- 现场留档后若要回到可用态：由用户**物理 POR**（不要 `reboot2`/`reboot -f`，见 `PITFALLS #166/#215`）。
