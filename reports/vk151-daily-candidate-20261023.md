# vk151：Q28 日常候选（复位在 mdss 侧 + 全软件修）（2026-10-23）

> 定位：把 `reports/q28-v2-mdss-reset-20261023.md` 验证过的**复位归属迁移**，
> 合到 `vk145` 的**完整功能栈**（A/B 两处闩锁修 + 0155）上，产出**可替换 `boot_b` 的日常镜像**。
> 状态：**主机侧完成，未上机**。

---

## 0. 数字结论

| 项 | 结果 |
|---|---|
| 基础树 | `24223e44ad80`（`replay/m1-73-vk127` tip，与 vk127/vk145 同源） |
| 改动文件 | **6**（无 `drivers/clk/` 改动） |
| 净行数 | **+125 / −18** |
| `dispcc-sm8750.c`（0154） | **完全移除**（`git diff -- drivers/clk` = 0 行） |
| 编译 | **0 error / 0 warning** |
| UTS | `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty`（**逐字匹配机内模块树**） |
| DTB | `resets = <0xd7 0x00 0xd7 0x01 0xd7 0x02>` + 三项 `reset-names` ✅ |
| 上机 | ❌ **未做** |

---

## 1. 与 vk150-q28v2 的区别（关键）

`vk150-q28v2` 只验证了"复位搬到 mdss 侧不损失效果"，但它**基于裸 `24223e44`**，
不含 2026-10-22 取证得到的三项功能修。**vk151 = v2 的复位改动 + vk145 的全部软件修**：

| 修复 | 内容 | vk150-q28v2 | **vk151** |
|---|---|---|---|
| **复位归属** | 3 个 BCR 复位从 dispcc probe 搬到 `msm_mdss_reset()` | ✅ | ✅ |
| **A：闩锁** | `dsi_bonded_cmd_failed` 单向闩锁加清零点（`bridge_power_on` 成功路径 + `power_off`/`post_disable` 不再跳过清理） | ❌ | ✅ |
| **B：link_configured** | `msm_dsi_host_set_display_mode()` 只在 `!power_on` 时清 | ❌ | ✅ |
| **0155** | DSI PHY `DIGTOP_PWRDN_B` 随 PLL bias 置/清 | ❌ | ✅ |

⇒ vk151 的 `DSI_PLL_lockfail` 预期为 **0**（vk150-q28v2 是 4，因为不带 0155）。

---

## 2. 六处改动清单

| 文件 | 改动 | 来源 |
|---|---|---|
| `Documentation/devicetree/bindings/display/msm/mdss-common.yaml` | `resets` 扩 3 项 + `reset-names`，`minItems: 1` | v2 |
| `arch/arm64/boot/dts/qcom/sm8750.dtsi` | mdss 节点加 `CORE`/`CORE_INT2`/`RSCC` 三个 BCR | v2 |
| `drivers/gpu/drm/msm/msm_mdss.c` | bulk **shared** reset + deassert prime | v2 |
| `drivers/gpu/drm/msm/dsi/dsi_manager.c` | 闩锁清零点（A） | vk145 |
| `drivers/gpu/drm/msm/dsi/dsi_host.c` | `link_configured` 条件清（B） | vk145 |
| `drivers/gpu/drm/msm/dsi/phy/dsi_phy_7nm.c` | 0155 `DIGTOP_PWRDN_B` | vk145 |

**`drivers/clk/qcom/dispcc-sm8750.c` 零改动** —— 0154 的 35 行已彻底不在本树里，
这是本镜像相对 vk145 唯一"删除"的东西，也是回应 Taniya 评审的实质动作。

---

## 3. 关键设计点（`msm_mdss.c`）

```c
/* 有 reset-names ⇒ shared bulk（不能 exclusive：dispcc 已作为 provider 持有） */
ret = devm_reset_control_bulk_get_shared(dev, num_resets, resets);
...
/* shared 是 deassert 引用计数，首用必须先 deassert 一次建计数 */
ret = reset_control_bulk_deassert(num_resets, resets);
ret = reset_control_bulk_assert(num_resets, resets);
msleep(20);
ret = reset_control_bulk_deassert(num_resets, resets);
```

- **无 `reset-names` 的板子走原单 reset 路径**，行为逐字不变（向后兼容）。
- 复位发生在 `devm_clk_bulk_get_all()`（`:403`）与 `clk_bulk_prepare_enable()`（`:255`）**之前**
  ⇒ 天然早于 PLL，与 Taniya 的时序意见不冲突（已在 vk150 的 5/5 上机中验证）。

---

## 4. 产物

| 项 | 值 |
|---|---|
| 镜像 | `out/boot-elden-vk151.img`（85 585 920 B） |
| image sha256 | `628b97554e35a06f52bdcc669eb891a57842280c9a7770b0deb6f34bbb5d9204` |
| kernel payload sha256 | `64510749697fba81a4e614f5e1e667717f75ec707b8aae1d205a3e203370ade4` |
| DTB sha256 | `7190ecf050c59108195495a9ff7d555657b3f4c090fa885b8f9e29330113d492` |
| 补丁集 | `patches/vk151-20261023/0001-daily-q28-reset-at-mdss-plus-software-latch-fixes.patch`（241 行） |

镜像内实测确认（`strings` 判据）：

- `failed to acquire mdss resets` ✅ / `failed to prime mdss resets` ✅（v2 代码在）
- `stale link configuration` ✅ / `Unbalanced enable` ✅（A/B 两修在）

---

## 5. 上机判据（未执行）

对齐 `reports/q28-disp-init-ab-20261022.md` §10 的 vk145 验收口径：

1. **≥8 发真实 POR 冷起**，交替与 `daily` 对照（禁暖复位样本，`PITFALLS #166`）；
2. GOOD = `card0` 在 + `card0-DSI-1=connected/enabled` + `storm_sig=0` + **面板实测有画面**（`PITFALLS #251`）；
3. **`DSI_PLL_lockfail` 预期 0**（0155 在场）；若非 0 需查 0155 是否生效；
4. **`dmesg | grep -c "failed to acquire mdss resets"` 必须 0**（vk150 第一版的 `-EBUSY` 不能复现）；
5. 顺带验证 A/B 两修：坏发后**能自行恢复**（闩锁不再单向）、唤醒路径不再报 `-ESTALE`。

---

## 6. 关联

- `reports/q28-v2-mdss-reset-20261023.md`（v2 的 5/5 真 POR 验证）
- `reports/q28-disp-init-ab-20261022.md` §6c（2×2 解离）、§10（vk145 验收）
- `reports/q28-DOSSIER.md`（SSOT）
- `PITFALLS #366`（单向闩锁）、`#367`（vermagic/UTS）、`#368`（reboot2 早期下发）
