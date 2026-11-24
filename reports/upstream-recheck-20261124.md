# 上游状态现查 + sashiko 对 dwc3 v13 的三条 [Low] 判别（2026-11-24 无人值守轮）

> 一页结论：**系列仍在维护者视野内**（dwc3 v13 = 在档最新代，arm-msm `new` / DT 侧 1/3 `needs-ack`、2/3+3/3
> `handled-elsewhere`，`commit_ref` 全空）；**sashiko 11-23 11:29Z 对 v13 1/3 给了 3 条 [Low]**，全部
> 落在 dt-binding 一处文件；**三条经判别都成立**，其中第 3 条（`oneOf` 在无 `mux-controls` 时必然失败）
> 是逻辑错误 ⇒ 需要 v14，且只需重出 1/3，2/3、3/3 与 v12/v13 逐字节相同。

## §1 现查方法与可复现命令（本轮踩到的 API 事实）

| 事 | 结论 |
|---|---|
| patchwork `?q=` / `?name__icontains=` / `?since=` | **全部被忽略**（返回 2009 年的无关件）⇒ 别用这些参数判「有没有更新」 |
| 可用过滤 | `?submitter=<id>`（本邮箱 submitter id = **226107**）、`?msgid=<MID>`、单件 `/patches/<id>/` |
| 分页 | `per_page=100` 升序，**必须翻到最后一页**才是最新代（page=5 返回 404 即到底） |
| lore | `curl` 直取被 Anubis 挡（403）；**`web_fetch`（Firecrawl）可读**单件页与 `?q=...` 搜索页 |

```sh
# 全量本人的件（4 页，升序）：
for pg in 1 2 3 4; do
  curl -sS -x http://127.0.0.1:7890 "https://patchwork.kernel.org/api/1.2/patches/?submitter=226107&per_page=100&page=$pg"
done
# sashiko 对 v13 的报告（lore 搜索结果页 → 正文）：
#   https://lore.kernel.org/linux-devicetree/?q=sashiko+%22v13+1%2F3%22&x=A
```

## §2 在档各系列的 patchwork 现状（2026-11-24 现查）

| 系列 | 最新代 | 状态（arm-msm / DT 侧） | `commit_ref` | 判读 |
|---|---|---|---|---|
| dwc3 双连接器 | **v13**（11-23 11:08Z，`15012435/6/7` + DT `15012445/8/46`） | `new` / `needs-ack`(1/3)·`handled-elsewhere`(2/3,3/3) | 空 | 在审；v12 全 `superseded` |
| wl2868c | v12（`14991614/5`） | `new` | 空 | **已合入 `regulator.git for-7.5`**（11-21 实证）⇒ patchwork `new` 是盲区，别据此判未合 |
| elden 板 DTS | v7（`14991580`，11-17） | `new` | 空 | v8 备料已在仓（`patches/upstream/elden-dts-v8-prep-20261121/`），**未投**（等放行） |
| M10 fastrpc non-secure-domain | v3（`14971025`，11-11） | `new` | 空 | 13 天无回复；可考虑礼貌 ping（需放行） |
| aw86927 触觉 | v2（11-17，6 枚） | arm-msm `new`；input/DT 侧 `handled-elsewhere`/`not-applicable` | 空 | 在审 |

## §3 sashiko 对 v13 1/3 的三条 [Low]：逐条判别

原文（lore，`sashiko-bot@kernel.org`，2026-11-23 11:29Z；sashiko 报 2/3、3/3 无问题）：

**① `mux-controls` 缺 `maxItems: 1`** —— 本地用 `$ref: /schemas/types.yaml#/definitions/phandle-array`，
数量不受限；`mux-consumer.yaml` 已有全局定义。
→ **成立（低）**。修法：`maxItems: 1`（或直接 `$ref: mux-consumer.yaml` 的定义）。一行改动。

**② `port@0` 换成 `graph.yaml#/$defs/port-base` 后，未给 `endpoint` 显式 schema** ——
`port-base` 用 `^endpoint(@[0-9a-f]+)?$` 匹配 `endpoint-base`，而 `endpoint-base` **故意不写**
`unevaluatedProperties: false`；于是单连接器的 `port@0/endpoint` 可携带任意未文档化属性（含
`usb-role-switch`/`mux-state`）而不报错，且 `endpoint@2/@3` 不被拒。
→ **成立（低）**，但修法要权衡：给 `endpoint` 也加 `unevaluatedProperties: false` 会让「单连接器
+ 厂商私有属性」的既有树报错（上游有先例依赖宽松）。**倾向修法**：`patternProperties` 收紧为
`'^endpoint(@[01])?$'`（拒绝 endpoint@2+），并对 `endpoint`（无 reg 的 plain 形态）保留宽松；
或者只在 `required: [mux-controls]` 分支里加 `endpoint: false`/端点集合约束。**要一次 dtbs_check 全量验证再定**。

**③ `oneOf`（两连接器 mux-state 互斥）在**没有** `mux-controls` 时必然失败** —— JSON Schema 里
`properties` 对缺失属性恒为真 ⇒ 两个分支同时匹配 ⇒ `oneOf` 崩。另外顶层 `if/then/else` 已经把
「有 mux ⇒ 两端点必须带 `usb-role-switch`+`mux-state`；无 mux ⇒ 二者禁用」说全了，故
`dependentRequired` 与 else 分支的 `mux-controls: false` 是冗余。
→ **成立（逻辑错误）**。修法：把 `if: required: [endpoint@0, endpoint@1] / then: oneOf…` 搬进
**`then:`（有 mux-controls）分支内部**，或给 `oneOf` 每个分支加 `required: [mux-state]`；同时删
`dependentRequired` 与 `mux-controls: false`。**这条必须修**（否则未来任何「两连接器但没写 mux」的树
都会被错误拒绝，属行为回归）。

## §4 处置与下一步（主机侧，未投递）

1. **v14 只需重出 1/3**：2/3、3/3 与 v12/v13 逐字节相同（已两次复核 blob）。
2. 修 ①③（确定性 bug）+ ②（按 §3 权衡，先跑全量 `dt_binding_check` + 四份 `dtbs_check` 看是否引入回归）。
3. 门链沿用 G1/G2（快），G3–G6 重跑（`make -j26` 起步；G4/G5 约 10–20 min）。
4. **投递仍按 `TASKS/README.md` §7「按系列逐次批准」**：v14 出件后等用户放行再发。

## §5 本轮未做

- 未改任何 patch（只判别与记计划）；未发信；未跑重门（编译类留到 v14 备料轮）。
- M8 mdss v5 / aw86927 的 sashiko 报告仍未逐条判别（老欠账，见 `reports/comm-triage-20261123-b.md` §表）。

## §6 交叉依赖实测：**板件（v9 形状）在 dwc3 v14 binding 下仍然全绿**

v14 把 `port@0` 收紧了（mux 分支内拒绝 plain `endpoint` 与 `endpoint@2+`），而板件正是这条新约束的
**首个真实消费者** ⇒ 必须确认「v14 进树后板件不会变红」，否则两条系列会互相拖死。

**做法**（零设备、零发信；worktree @ `aebb727447` = 7.4-rc3，逐枚 `git apply`）：

```sh
git apply patches/upstream/dwc3-v14-20261124/v14-0001-*.patch                     # 新 binding
git apply patches/upstream/wl2868c-v12-20261117/v12-0001-regulator-dt-bindings-*.patch
git apply patches/upstream/elden-dts-v8-prep-20261121/0000-dt-bindings-arm-qcom-*.patch
git apply patches/upstream/board-dts-single-20261113-sent-20261117/0001-*.patch    # v7 板件
git apply patches/upstream/elden-dts-v8-prep-20261121/0001-*.patch                 # dtsi label
git apply patches/upstream/elden-dts-v8-prep-20261121/0002-*.patch                 # 板件 mux/两连接器
make -j26 ARCH=arm64 O=/tmp/kb-v9b defconfig && make -j26 ARCH=arm64 … O=/tmp/kb-v9b dt_binding_check
make -j26 ARCH=arm64 … O=/tmp/kb-v9b CHECK_DTBS=1 qcom/sm8750-lenovo-elden.dtb \
     qcom/sm8750-mtp.dtb qcom/sm8750-qrd.dtb
```

| 判据 | 结果 |
|---|---|
| 六枚 `git apply` | 全部 rc=0（`0002` 报 1 条「new blank line at EOF」空白告警，与 v8 prep 原记录一致） |
| `dt_binding_check`（全量） | **rc=0**，`DTC [C]` **5421** 个（比无 wl2868c binding 的 5420 多 1，因为它带自己的 example），0 条 error/warning 行 |
| `dtbs_check` 三份 dtb | **3/3 `DTC [C]`，`^arch/.*dtb:` 诊断 0**（elden 0 条 ⇒ v14 的新约束对板件无影响） |
| elden DTB md5 | **`2d2d92662785a7aa07edb6aba78a9341`** = v10 那轮记录值（binding 只影响校验，不改 DTB 生成结果） |

**结论**：v14 与板件（v9 形状）**互不阻塞**；日志入 `patches/upstream/elden-dts-v8-prep-20261121/evidence/`
（`gate-v14-binding-20261124.log`、`gate-v14-dtbscheck-3dtb-20261124.log`）。若 v14 进树，v9 可直接按 v8 prep 的
「方案 B」投（v8 = qcom.yaml + v7 原文；v9 = dtsi label + 板件，1–2 枚）。

**本轮边界**：未重跑 v8 prep 的负样例（同 `mux-state`/去 `mux-controls`）——那两条测的是 DT 自身形状，
与 binding 版本无关，11-21 结论继续有效。

## §7 两条「sashiko 未判别」老欠账的现查结果（2026-11-24，网络恢复后补）

| 系列 | 现查结论 | 处置 |
|---|---|---|
| **M8 mdss v5**（`patches/upstream/m8-mdss-v5-20261114/`） | **lore 上不存在 sashiko 对 v5 的报告**：`/linux-arm-msm/?q=sashiko+"reset all block resets"` 只命中我们自己的回信（11-17 04:17Z）；`/all/?q=sashiko+...since:2026-11-14` 也没有 mdss 相关条目 ⇒ 这条「欠账」是**记账错误**，不是漏判别 | 关掉该欠账（`reports/comm-triage-20261123-b.md` §表 的注脚以本节为准） |
| **aw86927 v2**（`patches/upstream/haptics-v2-20261117/`） | **有报告未判别**：sashiko 对 **v2 6/6** 于 2026-11-17 05:46Z 给 **1×[High] + 1×[Low]**（`/all/?q=sashiko+aw86927`）。**[High] 成立**：devres 动作只拉 reset、不排空 `play_work`，inhibited 设备 unbind 时 `input_close_device()` 被跳过而 flush 会重排队 ⇒ worker 可能写已释放的 regmap（use-after-free 形状）。[Low] 也成立：message 说 suspend/shutdown 都 stop+reset，代码只各做一半 | **已出 v3 备料** `patches/upstream/aw86927-v3-prep-20261124/`（只改 6/6：devres 动作先 `disable_work_sync` 再拉 reset，shutdown 复用同一 helper；message 对齐）。G1 6/6 干净、G2 checkpatch 0E/0W/0C ×6、G3 `W=1` 编译 rc=0/0 warning（7.4-rc3 基线）。**未投递，等放行** |

**副作用情报（下一轮用）**：同一次搜索看到两处**同文件外部改动**，将来会影响我们的 rebase：
1. `[PATCH v2] dt-bindings: usb: snps,dwc3-common: Document usb-psy-name`（Venkat Yadlapati，11-22，sashiko 已回）
   —— 与我们 dwc3 v14 改的**同一个 binding 文件**。
2. `[PATCH v3 07/11] drm/msm: mdss: Add support for MDSS on Nord`（Nabige Aala，11-16）
   —— 与我们 M8 2/3 改的**同一个 `msm_mdss.c`**。
投 v14 / M8 后续代次前先看这两条是否进树。
