# UEFI GitHub 扫描 — 2026-11-03（lane：GitHub 扫描，时间盒 15min）

基线：issue#12 共 7 评论；我方最后 2026-10-29T04:16Z；上游 sunflower2333 最后 2026-10-29T04:19Z（已归档）。

## 1. sunflower2333/mu_wide_platforms issue#12

（待填）

## 2. 我方仓库 xiaquwan1001/lenovo-legion-y700-gen4-tb322fc-elden-linux

（待填）

## 3. 通知（gh api notifications）

（待填）

## 4. 上游生态（Mu-Silicium / WOA-project / worproject）

（待填）

### 记录

| 对象 | 时间 | 事实 | 对 UEFI 线(G1-29 路线A)含义 |
|---|---|---|---|
| mu_wide_platforms#12 | 2026-10-29T04:19:30Z | `gh api ...issues/12 --jq {state,updated_at,comments}` → `{comments:7, state:open, updated_at:2026-10-29T04:19:30Z}`；comments 过滤 `created_at > 2026-10-29T04:30Z` → 空 | **无新回复**，最后仍是已归档的 sunflower2333 04:19Z。无行动项。 |
| mu_wide_platforms commits | 2026-10-25 起 | `/commits?since=2026-10-25T00:00:00Z` → 空数组 | 无 UFSDxe/SMMU/SM8750/Pakala 相关新提交。 |
| mu_wide_platforms releases | — | `/releases` → 空 | 无新 release。 |
| xiaquwan1001/elden-linux | 2026-11-03 | repo: stars=2, forks=0, open_issues=0, has_discussions=false, pushed_at=2026-11-03T03:56:36Z | 无外部关注动向。 |
| 我方 issues | — | `gh issue list --state all` → 空 | 无外部人提 issue。 |
| 我方 PRs | — | `gh pr list --state all` → 空 | 无 PR。 |
| 我方 discussions | — | API 410（discussions 未启用） | 不适用。 |
| notifications | 2026-11-03 | `gh api notifications` 未读全部为无关仓库（Melodia/coolapk/netease 等）；无 UEFI/mu_wide 相关 | 无上游动静信号。 |
| mu_wide_platforms watch | — | subscription API 404；`gh api notifications` 无 mu_wide 条目；注：token 缺 notifications scope，此节为尽力核查 | 未 watch 该仓库（404），需人工决定是否 watch 以获得推送。 |

注：`gh api notifications` 可用但完整 scope 提示 `gh auth refresh -s notifications` 未执行；上面通知列表来自当前可用输出，未见 mu_wide 相关条目。


### 4 记录（上游生态，2026-10-01 起）

| 对象 | 时间 | 事实 | 含义 |
|---|---|---|---|
| Project-Silicium/Mu-Silicium releases | v4.0 2026-10-01、v4.1 2026-11-01 | `gh api .../releases` 过滤 since=10-01；v4.1 仅 2 assets，**无 SM8750/Pakala/8750 命中** | 上游发版节奏活跃但未覆盖 Pakala/SM8750 平台。 |
| Project-Silicium/Mu-Silicium commits | 10-01→11-01 共 36 | 无 UFSDxe/SMMU/SM8750/Pakala 命中（grep 过滤为空）； notable：#2166 "Fix Synchronous Exception error when booting linux"(10-28)、#2172 Bump Mu_Basecore(10-29)、v4.1(11-01) | 「UEFI 启动 Linux 同步异常修复」(#2166) 可能与 G1-29 路线 A 卡点相关，建议后续 diff 复核；其余为 Exynos/小米平台工作，无直接收益。 |
| sunflower2333 个人仓库 | 10-01 起 pushed | 仅 dsh-android/dxvk/freedreno_turnip-CI/gunyah-guest-drivers-windows/kShimC/linux/mesa/mu_wide_platforms 有 push；无 UEFI/UFS 专项新仓 | sunflower2333 无 UFSDxe/SMMU 方向新动作。 |
| WOA-Project mu-* | — | mu-CN/mu-Frontpage releases 均 404（无 release 或不存在） | 无信号。 |
| worproject | — | `users/worproject/repos` pushed_at≥10-01 → 空 | worproject 整体无 10 月动向。 |

### 结论

- **issue#12：10-29 之后无新回复**（comments=7，updated_at=04:19:30Z = 已归档基线；>04:30Z 过滤为空）。
- mu_wide_platforms 10-25 后零 commits、零 releases。
- 我方仓库 0 issue / 0 PR / discussions 未启用 / 2★ 0 fork，无外部动静。
- 通知无 UEFI/mu_wide 相关未读。
- 上游唯一值得跟进：Mu-Silicium #2166（Linux 启动同步异常修复）。

