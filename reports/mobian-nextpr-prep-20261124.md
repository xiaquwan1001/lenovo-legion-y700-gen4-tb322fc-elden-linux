# Mobian 下一个可交付件备料（不投、不推）— 2026-11-24

> 数字先行：**选型 = 拒三候选 → 走 11-23 审计 B 报告 §④ 的最小增量「mobian-recipes 的 elden 配方补齐」**；
> 门禁 **5/5 绿**（`gate.sh` rc=0）；新发现 **1 条**（!46 已 force-push 为英文版，分叉闭合）；
> 还欠 **1 件**（内核 deb，非本包范围）。

## 1. 选型与判定

三候选（`mobian-upstream-audit-b-20261123.md` §②）自足性判定：

| 候选 | 判定 | 缺口 |
|---|---|---|
| 1（!46 跟进与内容定稿） | **拒（已被上游闭合）** | 现查发现 !46 已于 **2026-11-23T19:10** force-push（sha `ea9fe3d5` ← `2dead7cc`），内容 = 英文版，与 `patches/distro/mobian-20261123/droid-juicer/lenovo,elden.toml` **逐字节一致**（本地 diff rc=0）。分叉不存在了；剩余动作只有「等维护者回复 / 礼貌评论」，评论=发信需用户逐次放行 ⇒ 无剩余主机侧工作 |
| 2（recipes MR-2 全件） | **拒（部分）** | 缺 `devices/qcom/packages/linux-image-*-sm8750.deb`（内核源树版本账 75 行 src_missing WARN），无 deb 提交即 CI 红 |
| 3（一等公民化） | **拒** | 依赖主线 DTS（patchwork 14991580 v7 零回复）+ LTS/staging 收口 |

⇒ 按派工单预案改做**候选 2 的全部主机侧可做部分**（= 最小增量「elden 配方补齐」），
冻结为「内核 deb 一到即可投」的成品包。

## 2. 产物（`patches/distro/mobian-20261124/mobian-recipes-elden-mr2/`）

| 文件 | 内容 |
|---|---|
| `wip.toml.append` | `[[device]] vendor="lenovo" model="elden" chipset="sm8750"`，仅三键（11-22 结论 #3/#4） |
| `upstream-wip.toml@20261124` | 上游 wip.toml 快照（salsa master 2026-11-24 取，仍空模板无人占用） |
| `wip.toml.merged.preview` | 快照+片段合并预览（投递前 diff 用，不直接投） |
| `droid-juicer/lenovo,elden.toml` | !46 当前英文版副本（G4 门证与 11-23 定稿一致） |
| `README.md` | 为什么这件 / 上游判据 / 放行后投法（分支、MR 目标 master、TOML 字段无需改）/ 前置 |
| `gate.sh` | 静态门，**5/5 绿** |

## 3. 门禁（5 绿，复跑）

```bash
cd patches/distro/mobian-20261124/mobian-recipes-elden-mr2 && bash gate.sh   # rc=0
```

G1 片段 tomllib+字段判据（chipset 必写、禁写 version/dtb/append/bootimg）/
G2 合并预览 tomllib（顶层 chipset 仍空、2 个 [[device]]、末位=elden）/
G3 droid-juicer schema（`[juicer]` 单表、8 条 firmware、2 条 folders、结构化条目无 `.mdt`/adsp/cdsp）/
G4 与 11-23 定稿字节一致 / G5 `bash -n` 自身。

## 4. 还欠什么

1. **内核 deb**（`linux-image-<ver>-sm8750`）：D2 内核版本账收口 + 内核分支工件 —— MR-2 投递的硬前置。
2. **设备窗口取证**（不阻塞本包冻结）：sns_reg_config 在 vendor vs odm、ath12k 目录 dmesg 名。
3. **维护者对 !46 的回复**：任何后续迭代以 `ea9fe3d5`（= 本包 G4 锚点）为基线。

## 5. 边界

零发信 / 零 push / 零 git commit / 零设备 / 零编译 / 未 clone 大仓（仅 2 次 REST 单文件 GET）。
未碰 `patches/distro/mobian-20261121/`、TASKS/README.md。
