# Q24 根因指名：7.2 血统缺上游 `skip retention by default`（2026-10-23）

> 起点：用户裁决「继续采样是浪费时间」，改为**静态对拍 + 设备侧一次 dump**。
> 结论口径：**〔已证实〕** = 代码行/设备实测输出；**〔推测〕** = 有机制推理未闭环。**全文零新采样。**

---

## 0. 数字结论

| 项 | 结果 |
|---|---|
| 两树 `rpmhpd.c` 行为差异 | **仅 1 处**（167 行 diff 里其余全是数组重排/注释） |
| 7.2 上带 retention 档的 rail | **6 个**：`lcx` `lmx` `cx` `mx` `ebi` `gmxc`〔已证实，设备 `cmd-db`〕 |
| 这些 rail 的 `enable_corner` 在 7.2 / 7.3 | **1（level=0x010=retention）/ 2（真工作档 0x038/0x040/0x0c0）**〔已证实〕 |
| `mmcx` 是否受影响 | **否**（`mmcx.lvl` 表里根本没有 0x010）——**我最初的 mmcx 假设被设备数据证伪** |
| ADSP 的 `proxy_pd_names` | **`lcx`, `lmx`** ⇒ 正好落在受影响集合〔已证实，`qcom_q6v5_pas.c`〕 |
| CDSP 的 `proxy_pd_names` | **`cx`, `mxc`, `nsp`** ⇒ `cx` 受影响、`mxc` 已白名单、`nsp` 无 retention 档 |
| 死亡末帧 | `sys_m_smsm.c:322:err fatal notification received from TZ` + `adsp watchdog`〔已证实，2026-10-23 串口〕 |
| 上游修复 | Mike Tipton, 2026-06-29, `pmdomain: qcom: rpmhpd: Skip retention by default`，`Reviewed-by: Konrad Dybcio`——**已在 7.3** |
| 需要我方补丁？ | **不需要**（日常线是 7.3） |

---

## 1. 两树唯一行为差异

`drivers/pmdomain/qcom/rpmhpd.c` / `rpmhpd_update_level_mapping()`：

**7.2（`linux` → `geekidos-linux` v7.2-elden，vk64 源）**

```c
if (rpmhpd->skip_retention_level && buf[i] == RPMH_REGULATOR_LEVEL_RETENTION)
        continue;
```

`skip_retention_level` **只**在两个 rail 上置 true：

```
$ grep -n "skip_retention_level = true" linux/drivers/pmdomain/qcom/rpmhpd.c
197:	.skip_retention_level = true,   /* mxc    */
205:	.skip_retention_level = true,   /* mxc_ao */
```

**7.3（`build/m1-73`）**

```c
if (buf[i] == RPMH_REGULATOR_LEVEL_RETENTION)
        continue;
```

⇒ **7.2 上除 `mxc/mxc_ao` 外，所有 rail 都把 `RPMH_REGULATOR_LEVEL_RETENTION`（= **16 = 0x010**，
`include/dt-bindings/power/qcom,rpmhpd.h:37`）留在档位表里**；7.3 无一例外地删掉。

这段 7.3 代码的注释就是上游提交的说明，逐字对应我们的故障形状：

> *Most HW won't function properly at Retention. The minimum operational level is the first level
> above Retention. … Skip the Retention level to avoid HW failures when the PD is enabled without
> first having an explicit OPP level set.*

---

## 2. 设备侧 `cmd-db` 实测（决定性，一次 dump）

`/sys/kernel/debug/cmd-db` 在 **vk64（7.2 在机内核）** 上的真实档位表（u16 LE）：

```
0x30030: lcx.lvl [00 00 10 00 38 00 40 00 80 00 c0 00 00 01 80 01 ...]
0x30040: lmx.lvl [00 00 10 00 c0 00 00 01 80 01 ...]
0x30000: cx.lvl  [00 00 10 00 40 00 80 00 c0 00 00 01 40 01 80 01 a0 01 c0 01 e0 01 ...]
0x30010: mx.lvl  [00 00 10 00 40 00 ...]
0x30080: mmcx.lvl[00 00 38 00 40 00 80 00 c0 00 00 01 40 01 80 01 ...]   ← 没有 0x10
0x300a0: mxc.lvl [00 00 10 00 40 00 ...]
0x300d0: gmxc.lvl[00 00 10 00 32 00 ...]
```

按各自的 `skip_retention_level` 语义重算 `enable_corner`（`rpmhpd->level[i]` 首个非零档）：

| rail | 7.2 `enable_corner` | 7.2 该档电压档 | 7.3 `enable_corner` | 7.3 该档电压档 | 差异 |
|---|---|---|---|---|---|
| `cx` | 1 | **0x010 = retention** | 2 | 0x040 | **←** |
| `mx` | 1 | **0x010 = retention** | 2 | 0x040 | **←** |
| `ebi` | 1 | **0x010 = retention** | 2 | 0x040 | **←** |
| `lcx` | 1 | **0x010 = retention** | 2 | 0x038 | **←** |
| `lmx` | 1 | **0x010 = retention** | 2 | 0x0c0 | **←** |
| `gmxc` | 1 | **0x010 = retention** | 2 | 0x032 | **←** |
| `mmcx` | 1 | 0x038 | 1 | 0x038 | 同 |
| `mxc` | 2 | 0x040 | 2 | 0x040 | 同（7.2 已白名单） |
| `gfx` | 1 | 0x032 | 1 | 0x032 | 同（表里无 0x10） |
| `nsp`/`nsp2`/`mss`/`ddr`/`xo` | 1 | 非 retention | 1 | 非 retention | 同 |

**⇒ 7.2 上有 6 个 rail 的「最低可 enable 档」= retention；7.3 上全部是真工作档。**

---

## 3. 这条差异如何对上死亡签名

三处代码事实串起来：

1. **`rpmhpd_power_on()`** 用的是 `corner = max(pd->corner, pd->enable_corner)`
   ⇒ **只要没有消费者投 OPP，把 rail 开起来就等于投票到 `enable_corner`** —— 在 7.2 上就是 retention。
2. **`rpmhpd_aggregate_corner()`** 在 `state_synced == false` 时走 `presync_floor` 分支：
   `to_active_sleep(pd, max(corner, pd->enable_corner), ...)` ⇒ 仍然兜到 `enable_corner`
   （**注意：`presync_floor` 不能救这个 bug，它兜的正是同一个 `enable_corner`**）。
3. **受影响的 rail 恰好是 DSP 的父域**：
   `sm8550_adsp_resource.proxy_pd_names = {"lcx","lmx"}`、`sm8550_cdsp_resource.proxy_pd_names = {"cx","mxc","nsp"}`。

⇒ 熄屏时 camera/display 侧对 `cx/mmcx/mx` 的投票全部撤掉，DSP 的 proxy PD 变成最后一票；
若此刻 `pd->corner` 为 0，父域被 enable 到 **retention** ⇒ DSP 子域拿不到工作电压 ⇒
ADSP 侧判死，写 `crash_reason` smem（`crash_reason_smem = 423`），Linux 侧 `q6v5_wdog_interrupt()`
把它原样打出：

```
qcom_q6v5_pas 6800000.remoteproc: watchdog received: sys_m_smsm.c:322:err fatal notification received from TZ
remoteproc remoteproc0: crash detected in adsp: type watchdog
```

这正是 2026-10-23 N5b 抓到的末帧（`logs/n5b-vk64-20261023-133658.log.round2.serial`），
之前只能描述为「TZ 主动通知」，现在有了上游链路。

〔已证实〕代码三处语义 + cmd-db 档位 + proxy_pd 名单 + 末帧字符串逐字一致。
〔推测〕`pd->corner` 在熄屏瞬间确实为 0（需 `vk149` 臂或 trace 坐实，但上游提交说明已把这条当成已验证事实）。

---

## 4. 与 `sync_state` 臂的关系：两条独立证据收敛

Konrad 2026-10-20 的建议（注释 `rpmhpd_driver.sync_state`）实测 **4/4 存活**（同协议基线 6/8 死）。
当时的解释只能到「rail 降档时序有问题」。现在机制清楚了：

- `sync_state` 不注册 ⇒ `pd->state_synced` **永不为 true** ⇒ `rpmhpd_aggregate_corner()` 走
  `this_active_corner = this_sleep_corner = pd->level_count - 1`（**最高档**）⇒ **永远不在 retention**。

| 干预 | 手段 | 结果 |
|---|---|---|
| Konrad 臂（vk148） | 把 rail **钉在最高档** | 4/4 活 |
| 上游修复（7.3 / vk149） | 把 retention **从档位表删掉** | 7.3 线 41/41 活 |

**两条完全不同的手法，指向同一个物理约束：ADSP/CDSP 的父 rail 不许停在 retention。**
这是该机制最有力的独立旁证——不是调参调出来的巧合。

---

## 5. `vk149` 臂（唯一保留的取证动作）

| 项 | 值 |
|---|---|
| 树 | `build/vk64-ret-arm`（`git worktree` @ `d02658e63cf6`，与 vk64 同一提交） |
| 唯一改动 | `patches/candidate-q24-retention/0001-pmdomain-rpmhpd-skip-retention-by-default.patch`（sha256 `b518d745…`，**+9/−5**，与上游 commit 同形） |
| `.config` | `patches/config-vk40-bringup` + 仅 `CONFIG_LOCALVERSION`/`LOCALVERSION_AUTO` 两项；olddefconfig 后 sha256 `2a61704d…` = **与 vk148 逐字相同** |
| UTS | 钉 `7.2.0-debug-vk64-gd02658e63cf6`（复用机内 1497 `.ko`，`PITFALLS #367`） |
| 与 vk64 的差异 | **只有那 9 行**（DTB/ramdisk/cmdline/mkbootimg 全部逐项照抄） |
| 产物 | **`out/boot-elden-vk149.img`**（85 352 448 B，`sha256 8aedd98a7d81…`） |
| kernel payload | `sha256 8f95a729be69…`（≠ vk64 的 `1483a9c6…` ≠ vk148 的 `26965434…`） |
| DTB 核对 | `386cc9bd5d24…` = **与 vk64 逐字节相同**〔已证实〕 |
| config 核对 | `2a61704d1abe…` = **与 vk148 逐字相同**〔已证实〕（⇒ 与 vk148 唯一差 = 补丁内容：一个改 sync_state、一个改 retention） |
| 镜像内 UTS | `7.2.0-debug-vk64-gd02658e63cf6`（**无 `+`**，vermagic 与设备 1497 `.ko` 匹配）〔已证实〕 |
| 构建结果 | 一次通过，**0 warning / 0 error**（vk148 那条 `rpmhpd_sync_state defined but not used` 在本臂不存在，因为该函数仍在用） |

**判据（只需 2–3 发，不是采样）**：
1. **变量生效**：`grep -c skip_retention_level /proc/kallsyms` 无关，改判 `dmesg` 里 `rpmhpd` 的
   `enable_corner` 行为 —— 更硬的判据是**同一条 `cmd-db` dump 在 7.3 语义下 `lcx/lmx/cx` 的
   `enable_corner` = 2**；或直接读 `pm_genpd_summary` 里 `lcx/lmx` 的 performance 值（7.2 上出现过 0/320，
   7.3 语义下不应再出现 retention 档对应值）。
2. **行为**：完整 19 相机模块 + 真实 `dpms On→Off` + 唤醒，`boot_id` 不变。
3. **对照**：同批基线 vk64 必须仍能死（否则台架本身变了）。

> **即使 `vk149` 仍死，也不改变「停止采样」的裁决**：那说明还有第二个条件，但**7.2 血统本来就不是我们的
> 目标线**——7.3 线 41 发 0 死亡是产品口径。

---

## 6. 对日常线的影响

**零。** 日常内核是 7.3（`vk145`/`vk147`），`rpmhpd.c` 已是上游版。
`scripts/cam-mode.sh on/off` 的相机×熄屏互斥**从「安全策略」降级为「可选偏好」**——
它当初的依据是「相机在位 ⇒ 熄屏必掉电」，而该绝对口径 2026-10-19 已作废，现在又有了根因解释。

---

## 7. 方法论（可复用）

- **「版本差」比「概率」便宜一个数量级**：两树 `git diff` 一次就能枚举全部行为差异；
  在 167 行 diff 里用「哪些是数组重排/注释、哪些改语义」筛出**唯一 1 处**。
  这比再跑 5 发 `fastboot boot` 快，且**结论是确定的**。
- **设备上已有的 debugfs 就是证据源**：`/sys/kernel/debug/cmd-db` 一次 dump 就把「retention 档到底在不在」
  这个纯静态问题变成实测——**并且证伪了我的第一版假设（mmcx）**。假设被自己的数据推翻是好事。
- **死亡末帧要能追到上游 commit**：`sys_m_smsm.c:322` 是固件里的字符串，本身不可查；
  但把「受影响的 rail 集合」与「DSP proxy PD 名单」求交，就把它落到 Linux 侧可解释的一行代码上。
- **两个独立干预收敛 = 机制可信**：`sync_state` 臂与上游 retention 修复手法完全不同却指向同一约束，
  这比任何单臂的 p 值都强。

---

## 8. 关联

- `reports/q24-n5b-20261023.md`（n=6：4 死，末帧来源）
- `reports/q24-syncarm-test-20261023.md` / `q24-syncarm-build-20261023.md`（Konrad 臂）
- `patches/candidate-q24-retention/0001-pmdomain-rpmhpd-skip-retention-by-default.patch`
- `reports/mail-triage-20261021.md` §3.1（camcc GDSC 卡在 off，同族上游补丁）
- `TASKS/README.md` §5 Q24 / §4 T10 / §7 M7；`PITFALLS` §47
