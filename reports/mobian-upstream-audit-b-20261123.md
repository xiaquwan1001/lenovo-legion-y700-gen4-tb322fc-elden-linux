# Mobian 侧上游化方向审计（B lane，只读）— 2026-11-23

> 性质：**只读审计 + 本报告**。零设备动作、零发信、零 push/MR 操作、不跑编译。
> 现查手段：GitLab/Salsa REST API + wiki.debian.org（`curl --noproxy '*'`，全部只读 GET）。
> 输入账：`reports/mobian-mr-plan-20261122.md`、`reports/mobian-upstream-firstpr-20261121.md`、
> `reports/distro-upstream-feasibility-20261121.md`、`reports/mobian-firstmr-20261123.md`、
> `patches/distro/mobian-2026112{1,3}/`、`TASKS/README.md` §7（M 系列 + 2026-11-23 派发行）。

---

## ① 我方 !46 现状（一行 + 证据）

**`mobian1/droid-juicer !46`「configs: add Lenovo Legion Y700 Gen4 (TB322FC)」= opened / `detailed_merge_status=mergeable` / 0 条评论（维护者零回复）/ CI 在源 fork（xiaquwan1001/droid-juicer pipeline #1）`success`，目标仓无 pipeline——自 2026-11-21T09:31Z 创建至今（11-23）无任何上游动静。**

证据（可复跑）：

```bash
curl -sS --noproxy '*' "https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46"
#   state=opened, user_notes_count=0, sha=2dead7cca2b0bf443b3a00e4d1a28a140aa7e135,
#   detailed_merge_status="mergeable", reviewers=[], assignees=[]
curl -sS --noproxy '*' "https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46/pipelines"
#   [{"iid":1,"ref":"configs/lenovo-elden","status":"success","created_at":"2026-11-21T09:30:14Z",
#     "web_url":"https://gitlab.com/xiaquwan1001/droid-juicer/-/pipelines/3097183213"}]
curl -sS --noproxy '*' "https://gitlab.com/mobian1/droid-juicer/-/merge_requests/46" | grep -c 'Qinghuan Xia'   # 3（仅作者名，无维护者名）
# notes/discussions 端点 401（匿名不可读）⇒ 用 MR JSON 的 user_notes_count=0 为准
```

**审计发现 1（账面不一致，需回填）**：`reports/mobian-firstmr-20261123.md` 把 MR-1 写成「备料完成、不投递、投递前置第 1 条 = 用户放行」，但 **!46 实际已于 2026-11-21T09:31Z 开出**（早于该报告）。TASKS §7 的 2026-11-23 派发行与 D2 行（「!46 CI 绿等维护者」）才是与事实一致的那条 —— 以会话里有实测证据的那条为准，`mobian-firstmr-20261123.md` §3 的「投递前置清单」应加一行更正注记（本轮只读不改）。

**审计发现 2（内容分叉）**：!46 实际包含的是**中文注释变体**（从 MR sha 2dead7cc raw 取回：`configs/lenovo,elden.toml` 123 行注释，23 个 `name =` 条目，含 `qcom/sm8750/gen80000_zap.mbn` 全路径条目），而 11-23 成品 `patches/distro/mobian-20261123/droid-juicer/lenovo,elden.toml` 是英文注释 19 条。两者**语义核心一致**（同 8 条 firmware 组 + 2 条 folders、ADSP/CDSP 排除、三件自编资产排除、sns_reg_config 标「未上机」），差异只在注释语言与个别条目写法。若维护者要求改动，**应以哪份为准需要先在会话内拍板**（英文版与上游 `configs/` 目录语言习惯一致；见 §2 候选 2）。

---

## ② 下一个 MR：3 个候选（按 价值/前置依赖/工作量 排序）

### 候选 1 —— droid-juicer !46 跟进与内容定稿（价值：中高；前置：无技术前置；工作量：小）

| 项 | 内容 |
|---|---|
| 落点仓 | `gitlab.com/mobian1/droid-juicer`（master，最后 commit 2026-10-12 `a160267c` = v0.4.3，仓活着但节奏慢：6 个近期 commit 里 5 个是 configs 小步） |
| 文件形状 | `configs/lenovo,elden.toml` 单文件；CI 只有 cargo fmt/clippy/build/test，**无 TOML schema 校验**（`.gitlab-ci.yml`）⇒ 质量靠人眼 |
| 动作 | a) 先解决 §① 发现 2 的内容分叉（中文变体 vs 英文成品），b) 3 天静默后决定是否礼貌评论/等待，c) 按维护者意见迭代（预案已在 `mobian-mr-plan-20261122.md` §2.5 排好 5 条备选） |
| 验收判据 | 维护者回复（任何形式）或合并；`user_notes_count` 从 0 变正 |
| 阻塞项 | 发信类动作需用户逐次放行（§7 投递口径）；**零技术阻塞**。风险参照：`!2`/`!22`/`!35` 三个 Draft 挂 1–2 年无人理 ⇒ 单设备 config 的上游吞吐本来就慢，!46 3 天静默不异常 |

### 候选 2 —— mobian-recipes MR-2：wip.toml 条目 + droid-juicer 配置副本 + 内核 deb（价值：最高——「能出可启镜像」的唯一路径；前置：最深；工作量：3–6 人日）

| 项 | 内容 |
|---|---|
| 落点仓 | `salsa.debian.org/Mobian-team/mobian-recipes`（master，最后 commit 2026-10-21 `a4fff866`；devices/qcom 子树最后实质 commit 2025-12-04 sm7150；当前 open MR 10 个全部是 CI/luks/提取类杂项，**qcom 设备面 11 个月零合并**） |
| 文件形状（三处同批，缺一即 CI 红，`mobian-mr-plan-20261122.md` §3.3） | ① `devices/qcom/configs/wip.toml` 追加 `[[device]]`（现查 2026-11-23：wip.toml 仍是空模板 + 注释段，未被任何人占用）；② `devices/qcom/droid-juicer/lenovo,elden.toml` 副本（= 候选 1 的定稿）；③ `devices/qcom/packages/*.deb` 至少 `linux-image-<ver>-sm8750` |
| wip.toml 关键约束 | `chipset = "sm8750"` 必须写在 `[[device]]` 里（顶层 `chipset = ""` + jq 空串真值坑，`bootloader.sh:46,54`）；`[bootimg]` 全局默认与本机实测头逐字段相同，**不写覆盖**；`append`/`version`/`dtb` 不写（11-22 报告已把 11-21 的三个 TODO 关成确定结论） |
| 验收判据 | `./build.sh -t qcom-wip -s` 出镜像；CI devices job 绿；MR 描述含 11-22 §2.4 九条自检 + AI 披露 |
| 阻塞项 | **内核分支 `mobian-sm8750-7.4` + Debian packaging**（现查 qcom-linux：51 分支，7.x 家族 14 条，最新 = `mobian-sc7280-7.3` 2026-11-19、`mobian-sdm845-7.3` 2026-11-17、`wip/tiol/7.4-sdm845` 2026-11-06，**仍无任何 sm8750 分支**）⇒ 这正是 §3 的「内核版本账」阻塞面；`debian/` 目录在样例分支根 404（11-21 已标 TODO，投稿前必须现查 `wip/tiol/7.4-sdm845` 树确认打包件落点） |

### 候选 3 —— 一等公民化：build.sh 白名单 + `configs/sm8750.toml` + `sm8750-support` 元包（价值：长期最高；前置：最深；工作量：随主线进度）

| 项 | 内容 |
|---|---|
| 落点仓 | recipes `build.sh:88-94`（加 `sm8750` 一行）+ `devices/qcom/configs/sm8750.toml`（新建）+ `Mobian-team/devices/qcom-support` `debian/control`（元包） |
| 文件形状 | 一行 + 一个新 toml（内容 = 候选 2 的 `[[device]]` 段，不写 chipset 行）+ control 段（`Depends: linux-image-<ver>-sm8750, qcom-support-common`） |
| 验收判据 | `-t sm8750` 可建镜像；wip 的「手动 dpkg -i deb」债同时清掉 |
| 阻塞项 | ① 板 DTS 进 mainline（M3-DTS：patchwork `14991580` v7 仍 state=new、零回复；v8 备料在 `patches/upstream/elden-dts-v8-prep-20261121/` 未投）；② 内核进 Mobian **stable/testing 才强制 LTS**（见 §3 文档现查），sm8750 目前只能走 staging/分支路线 |

**排序理由**：候选 1 是唯一已开出的口子，维护它成本最低且是候选 2 的组成部分；候选 2 是价值拐点（从「配置存在」到「镜像可启」），但其前置（内核分支）正是 ③ 的大头；候选 3 依赖主线 DTS 与 LTS 收口，排在 M 系列（§4）之后。

---

## ③ 「内核版本账」（源树 geekidos 缺失）阻塞面划分

**被阻塞（复用同一份未收口的版本账）：**

| 件 | 为什么被阻塞 |
|---|---|
| 候选 2 的 `packages/linux-image-*-sm8750.deb` | 构建 deb 需要一个可复现的源树。`build/elden-tree` = v7.4-rc3 纯上游（payload 在 patches 栈里），而**配方源树**（GEEKiDOS/linux 浅克隆 + daily 补丁栈）缺失，`versions/kernel-src-archive.tsv` 记 **75 行 `src_missing` WARN**（TASKS D2 行 2026-11-23 口径）——「在机镜像逐字节可复现」的版本账没收口前，任何 deb 产出都无法声明与在机功能面等价。恢复动作 = 11-23 派发 D2 行的路线 B（重建 daily 源树，估 4–6 h，`make -j26`），**不在本轮范围** |
| 候选 2 整体（CI 提交即红） | `bootloader.sh` 要求 `linux-version list` 有内核 + dtb 存在；没有 deb 就没有内核，MR 必红 |
| 候选 3 | 同候选 2 + 追加「进 stable 需 LTS 6.18」这条已被 `mobian-upstream-firstpr-20261121.md` §1 判死（6.18 缺 USB v7.0 / mdss v7.1 / GPU+camss-PHY v7.4 三段使能 = SoC bringup 级倒灌，非 MR 量级） |

**不被阻塞（与内核版本账正交，已全部落盘或在飞）：**

| 件 | 状态 |
|---|---|
| droid-juicer `configs/lenovo,elden.toml` | 已提交（!46），内容与内核版本零耦合（纯固件抽取清单） |
| `elden-firmware` 包自编/拼装件（board-2.bin 拼装、haptic、tplg） | `patches/distro/mobian-20261123/` 成品 + 11-21 §2 的 C2/C3 结论，任何内核版本通用；欠的只有设备窗口取证（vendor vs odm 的 sns_reg_config、ath12k 目录 dmesg 名） |
| UCM2 / tplg（音频用户态） | 纯固件/用户态，无版本耦合（11-21 §1.1 audio 行「无版本冲突」）；归口 = §4 的三份共用前置件 |
| recipes `wip.toml` 片段本体 | `patches/distro/mobian-20261123/mobian-recipes/wip-device-snippet.toml` tomllib rc=0，随时可随候选 2 同批 |

---

## ④ 与主线 M 系列（TASKS §7）的复用关系

**结论：三份共用前置件先收口，Mobian 侧全是消费者——同一份 DTS / UCM2+tplg / firmware 清单对三家（Mobian、将来任何发行版、我方自建根）只做一次。** `distro-upstream-feasibility-20261121.md` 已定此口径，本轮现查证实它在 Mobian 侧的具体落点：

| 共用件 | M 系列归属（TASKS §7 现状） | Mobian 侧消费点 | 复用形状 |
|---|---|---|---|
| **板 DTS**（`sm8750-lenovo-elden.dts`） | **M3-DTS**：v7（`14991580`）state=new 零回复；v8 备料（qcom.yaml + v7 两枚）在档不投；dwc3 v11 三 blob GATES 全绿待投 | 候选 2/3 的 dtb 落 `linux-image` 包（`/usr/lib/linux-image-<ver>/qcom/sm8750-lenovo-elden.dtb`，`bootloader.sh:66`）；DTS 未进树前 Mobian 内核分支经 `debian/patches` 携带（gbp pq 流程，Porting 页原文） | 同一份 v8；v8 里 USB 部分等 dwc3 v10 binding 进树后 0 诊断（`mainline-upstream-audit-20261122.md` §3） |
| **dwc3 v11** | §7 头 11-21：SENT-ready 未投（G7 上机 #1 部分通过：起得来、Type-C devlink 环未闭合） | Mobian 内核分支 payload = 同一批 patch | 逐字复用 `patches/upstream/dwc3-v11-20261121/` |
| **UCM2 / tplg / firmware 清单** | `rootfs/debian/elden-firmware/`（deb 已产出，`elden-firmware_1.0~20261028_all.deb`）；tplg 源 `scripts/audio-tplg/` | droid-juicer 配置排除清单的三件自编资产（haptic/board-2/tplg）+ ADSP/CDSP split 件全走该包；tplg 与内核版本零耦合 | 同一份包，droid-juicer 只管 vendor 可抽取件（!46 描述已写明该分工） |
| **wl2868c** | 🟢 已合 `regulator.git for-7.5`（`84e67d2ee13f`+`602f57223457`） | Mobian 内核分支无需携带（等 7.5 合并窗口后重基即含） | 零成本 |
| **M8（mdss reset）/ M10（ADSP fastrpc non-secure）** | M8 = 3 枚（11-13）handled-elsewhere/new；M10 = v3（`14971025`）new，只欠礼貌 ping | 同为 Mobian 内核分支 payload；ADSP 件影响 hexagonrpcd/sensor PD，与 droid-juicer 的传感器树条目是**同一条功能链的两半** | 逐字复用 |

**Porting 文档约束现查（wiki.debian.org/Mobian/Porting，last modified 2026-09-27，未变）**：「Mobian ships LTS kernel versions (e.g. 6.1/6.6/6.12/6.18) to stable and testing branches, while some not-LTS kernel versions can be made available in the staging section」——与 11-21 报告读法一致：**staging 收 7.x 分支没问题，stable/testing 才强制 LTS**；另注意该页建议「look at Nura 的 deviceinfo」——**Nura 侧 AI 政策禁止我们读/生成其贡献内容，这句对我们不适用，投稿时不得引用 pmaports 内容**。

---

## 本轮改动

只新增本报告：`reports/mobian-upstream-audit-b-20261123.md`。零代码/补丁改动，零设备动作，零外发。

## 复跑命令汇总

```bash
curl -sS --noproxy '*' "https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46"
curl -sS --noproxy '*' "https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests/46/pipelines"
curl -sS --noproxy '*' "https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/merge_requests?state=opened"
curl -sS --noproxy '*' "https://salsa.debian.org/api/v4/projects/Mobian-team%2Fmobian-recipes/repository/commits?ref_name=master&per_page=10"
curl -sS --noproxy '*' "https://salsa.debian.org/api/v4/projects/71384/repository/files/devices%2Fqcom%2Fconfigs%2Fwip.toml/raw?ref=master"
curl -sS --noproxy '*' "https://salsa.debian.org/api/v4/projects/Mobian-team%2Fdevices%2Fkernels%2Fqcom-linux/repository/branches?per_page=100"
curl -sS --noproxy '*' -L "https://wiki.debian.org/Mobian/Porting"
# !46 内容取证（MR sha，master 上无此文件）：
curl -sS --noproxy '*' "https://gitlab.com/api/v4/projects/mobian1%2Fdroid-juicer/repository/files/configs%2Flenovo%2Celden.toml/raw?ref=2dead7cca2b0bf443b3a00e4d1a28a140aa7e135"
```

## 残余风险

- notes/discussions API 匿名 401 ⇒ 「0 评论」以 `user_notes_count=0` + 页面 HTML grep 为判据（两者一致），非逐字遍历讨论层。
- `debian/` 打包目录在 qcom-linux 样例分支的落点仍未实证（11-21 TODO 沿袭）；候选 2 开工第一天必须先解。
- !46 中文注释变体 vs 11-23 英文成品的「哪份为准」未拍板（维护者要求改动时会立刻撞上）。
- recipes qcom 设备面 11 个月零合并 + droid-juicer 三个 Draft 长期挂起 ⇒ 上游吞吐慢是常态，预期管理按「周级静默正常」。

---

## 后记（2026-11-23 晚，用户裁决执行）

- **用户裁决**：「mobian 侧内容先英文后中文；编译任务往后」。
- **已执行**：!46 分支 `configs/lenovo-elden` 已 force-update `2dead7c`（中文注释 23 条目）→
  `ea9fe3d`（**英文注释 22 条目** = `patches/distro/mobian-20261123/droid-juicer/lenovo,elden.toml`，
  tomllib 解析过；push 走 SSH，规则 14）。API 复核：MR state=opened、head sha=ea9fe3d5、
  merge_status=unchecked（等 fork pipeline 重跑）。中文版备份 = `/tmp/mobian/zh-backup.toml`，
  仓内存档 `patches/distro/mobian-20261121/droid-juicer/`（如仍有）。
- 「后中文」= 中文注释版本留作后续（如维护者接受 MR 后再补注/或仅留仓内档），不主动推第二版。
- 推送命令：`git push -f origin configs/lenovo-elden`（clone = git@gitlab.com:xiaquwan1001/droid-juicer.git）。
