# U3 判定：`rpmhpd` 的 `presync_floor` 在本机是**死代码** ⇒ 删掉（D13），不立项上游

出处 = `reports/m1-rebase-7.3rc7-execution-20261013.md` §4 **U3**
（"`rpmhpd.c` `presync_floor`（GMU 轨在 sync_state 前钳到最低功能档）属框架级 workaround（policy §6 C4 类）；
需通用复现 + 上游 RFC 论证"）。本轮用**设备只读证据 + 静态对照**给出终局判定。

## §0 结论（数字）

| 项 | 结果 |
|---|---|
| 本机是否生效 | ❌ **从未执行**：`gfx` / `gmxc` 两个 genpd 在机上 **consumer = 0**（`pm_genpd_summary` 均为 `off-0 … 0`），而该分支只在「有消费者投票」时才被 `rpmhpd_aggregate_corner()`/`rpmhpd_power_on()` 走到 |
| 上游立项 | ❌ **不立项**：无复现症状（项目文档零记录）+"夹到最高档"是上游对所有 SoC 的**保守默认**（`sm8650`/`x1e80100` 的 `gfx` 同样没有这个 flag 也没报问题）⇒ 无法论证"通用缺陷" |
| 历史结论一致性 | `reports/q24-causal-audit-20261015.md` §2 与 `reports/q24-retention-rootcause-20261023.md` §3 已各自写明：`presync_floor` **兜的正是 `enable_corner`，不能救 Q24** |
| 采取的动作 | **从树里删除**（`patches/local/rpmhpd-drop-presync-floor-20261027/`，**−8 行**）——删后 `rpmhpd.c` 与 pristine 7.3-rc7 **逐字节相同**（`diff` rc=0），即 D13 消除了这条 vendor 增量 |
| 门禁 | `drivers/pmdomain/qcom/rpmhpd.o` 编译 **rc=0**；`W=1` **0 warning**；无其它文件引用 `presync_floor`（`grep -rn` 全树 0 命中） |

## §1 设备证据（只读，2026-10-27）

```sh
$ ssh root@192.168.7.1 'awk "NR>1 {print \$1, \$2, \$NF}" /sys/kernel/debug/pm_genpd/pm_genpd_summary' \
    | grep -E "^(gfx|gmxc|mx|cx|mmcx|nsp)"
gfx   off-0   0        ← 0 个 consumer
gmxc  off-0   0        ← 0 个 consumer
mx    on      256
cx    on      256
mmcx  on      64
nsp   off-0   0
```

**关键点**：`presync_floor` 只挂在 `gfx`/`gmxc` 上（`rpmhpd.c:123/237`），而这两个域在本机**没有任何设备挂靠**
（板级 DTS 与 `sm8750.dtsi` 里也搜不到 `SM8750_VDD_GFX`/`GMXC` 消费者，GPU 走 GMU/AOP，不经 `rpmpd`）
⇒ `rpmhpd_aggregate_corner()` 的 `else if (pd->presync_floor)` 分支**在本机永远不可达**。

## §2 代码事实（为什么它也不该按"per-rail bool"上游）

```c
if (pd->state_synced) {
	to_active_sleep(pd, corner, ...);                 /* 真实票 */
} else if (pd->presync_floor) {
	to_active_sleep(pd, max(corner, pd->enable_corner), ...);   /* ← vendor 增量 */
} else {
	/* Clamp to highest corner if sync_state hasn't happened */
	this_active_corner = pd->level_count - 1;                   /* ← 上游默认 */
}
```

- 该写法在 **7.2 血统树里就已存在**（`git -C geekidos-linux show ba28ec16f0:drivers/pmdomain/qcom/rpmhpd.c`
  同样 4 处），是**厂商血统**，不是我方为 Q28/Q24 加的实验件；
- 上游语义上"sync_state 前夹到**最高**档"是对**未知消费者**的保守选择；要偏离它，需求方必须给出"夹到最高有害"的
  可复现证据。我们没有，且**本机连消费者都没有**。

## §3 若将来真需要，正确的上游形态（不是 per-rail bool）

1. **消费者侧**：让 GPU/GMU 相关驱动在 probe 早期投自己的 OPP（`required-opps`/`dev_pm_opp_set_opp`），
   使 `sync_state` 之前就不是"未知票"；
2. **provider 侧**：若要表达"该 rail 由外部处理器管理"，应引入通用机制（例如 genpd 的
   `GENPD_FLAG_*` 或 DT 层显式声明），而不是在 rpmhpd 表里硬编码两个 SoC 的 rail 名单；
3. **时机侧**：`sync_state` 与 proxy-PD（GCC/CAMCC 等 consumer）绑定顺序的交互，属 `pmdomain` 核心语义，
   需独立 RFC + 两平台对照（sm8650 vs sm8750）。

以上三条都需要**症状复现**做前提；当前没有 ⇒ 按 policy「未定根因不得写成硬件事实」**不立项**。

## §4 遗留判据

- 若将来板级 DTS 给 `gfx`/`gmxc` 挂消费者（例如 GPU 改走 `rpmpd`），恢复**上游 clamp-to-max** 才是正确默认；
  届时若出现 GPU 掉压/挂死，再按 §3 立项并附本判定作为反例基线。
- U3 关闭后，M1 §4 未决项剩余 = **U1/U2/U5（DSI bonded 一族）+ U7（双控触觉上机）**。
