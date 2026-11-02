# M8 mdss v3 投递报告（2026-11-02）

> 派工单：M8 mdss 做到 v3 并投出（含回 Dmitry 两条意见）。用户已批准本批投递。
> 边界：未改任何 SSOT（README/INDEX/TASKS/DEVICE/RESOURCES/PITFALLS/PROGRESS/.pi/*.md/versions/*）、
> 未 `git add/commit/checkout/clean`（项目仓）、未 sudo、未碰设备、未写任何口令。

---

## §0 结论（先数字）

| 项 | 值 |
|---|---|
| 投出封数 | **6**（系列 4 + 两条 review 短回复 2），全部 `Result: 250` / `已发送 OK` |
| lore 归档点 | **14/14 HTTP 200**（arm-msm 6、dri-devel 6、linux-devicetree 1、其中 1 封为 1/3 独有） |
| 正文一致性 | **6/6 与本地 sha256 逐字节相同**（按 `/<list>/<完整msgid>/raw`） |
| v3 净 diff | 4 文件 **+9 / −6**（v2 为 +22 / −6） |
| 门禁 | checkpatch `--strict --no-tree` **3/3 = 0E/0W/0C**；pristine `git am` **3/3**；binding 三件套 rc=0（**单/双复位两态**）；`W=1` msm 目录 **rc=0 / 0 warning** |
| 上机 | **0 次**（v3 只删复位项 + 删注释，未改 API；本报告 §4 说明为什么不需要，以及哪里仍有风险） |

**Message-ID**

| # | 内容 | Message-ID |
|---|---|---|
| 0/3 | cover | `<20261102055026.438521-1-xiaqinghuan@mail.ustc.edu.cn>` |
| 1/3 | dt-bindings（只这封 Cc devicetree） | `<20261102055026.438521-2-xiaqinghuan@mail.ustc.edu.cn>` |
| 2/3 | drm/msm/mdss | `<20261102055026.438521-3-xiaqinghuan@mail.ustc.edu.cn>` |
| 3/3 | arm64 dts | `<20261102055026.438521-4-xiaqinghuan@mail.ustc.edu.cn>` |
| 回 2/3 长注释 | `Re: [PATCH v2 2/3]` IRT `<odog4t5j3y7j4tatqsiywfj27iufeazkzp3vtfvzce2knct25n@ephs3ngmt2i6>` | `<179359872904.440020.4978864415299817827@mail.ustc.edu.cn>` |
| 回 3/3 RSCC | `Re: [PATCH v2 3/3]` IRT `<dkwloahmxcka2ykjdrf6nh6d6cde6zgd7fe5s763h7s6nv3eqe@pm32d33ghgbb>` | `<179359872977.440050.668410399098679331@mail.ustc.edu.cn>` |

---

## §1 两条 reviewer 意见的落地对照

| 意见 | 来源 | v3 处置 | 证据 |
|---|---|---|---|
| 「删掉 `msm_mdss_reset()` 上方新加的长注释」 | Dmitry 10-31 21:47Z，INBOX 16141，`<odog4t5j…>` | `0002` **整段 11 行注释删除**，机制保留；理由留在 changelog（且缩短到 2 段） | `GATES.md` §1；`0002-*.patch` 净 +2/−3 |
| 「drop the RSCC reset」 | Dmitry 10-31 21:48Z，INBOX 16143，`<dkwloah…>`；Konrad 10-30 同向 | `0001` items 三项→两项 + example 同步；`0003` `resets` 三项→两项；`0002`/`0003` changelog 里的 RSC 表述全删 | `reports/m8-rsc-ownership-20261031.md` §0/§7（RSC 归属裁定 + 复核 5/5 通过） |

两封短回复各自挂回对应评论（**不新起线程**，符合 Mark Brown 11-01 的流程要求），
lore 线程复核：两封都嵌在 v2 线程里 Dmitry 那两条之下（2026-11-02 05:52）。

---

## §2 门禁（本轮实跑，全部原始输出在 `patches/upstream/m8-mdss-v3-20261102/GATES.md`）

1. **checkpatch `--strict --no-tree`**（用目标树自带 `scripts/checkpatch.pl`）：
   0001 `0E/0W/0C 20 lines`、0002 `0E/0W/0C 17 lines`、0003 `0E/0W/0C 9 lines`。
2. **pristine 重放**：`/tmp/amtest-m8v3`（worktree @ `24a19b953e` = v7.3-rc7）`git am` **3/3 干净**，
   之后 `git diff --stat m8/v3-20261102` 为空 ⇒ 终态逐字节一致，无 fuzz。
3. **binding**：`dt-doc-validate` rc=0、`dt-check-style` rc=0；
   `make dt_binding_check DT_SCHEMA_FILES=display/msm/qcom,sm8750-mdss.yaml` 生成 example.dtb 后
   `dt-validate` **双复位 rc=0**；把 example 临时改成单复位再跑 **仍 rc=0**（向后兼容有实测）。
   ⚠ 该 `make` target 内部三步都带 `|| true`（`PITFALLS #470`），其 rc 不作证据。
4. **编译**：`W=1 drivers/gpu/drm/msm/` rc=0；`msm_mdss.o`/`msm.o` 删净后强制重编，warning/error 计数 0。

---

## §3 cover 里做了什么自我更正（重要）

v2 的 cover 写「It has *not* yet been run on hardware」。**这是错的**：
`reports/q28-v2-mdss-reset-20261023.md` §4.5.2b 记录过 mdss 侧（即 dispcc 编程 PLL **之后**）
复位三块 BCR 的实测 —— **5 发真 POR 全 GOOD + 2 发暖复位 GOOD**（`storm_sig=0`、`card0=1`、
`DSI-1 connected` 每发逐字相同），而只复位 core 的 base 臂是 **9 发 5 次 STORM**。

v3 cover 因此改成两段「不是新的证据」：
- 位置（mdss probe / PLL 之后）历史上已上机，5/5 POR + 2/2 暖复位 GOOD（但那次用的是
  shared-reset bulk API + 三枚复位）；
- 保留的两项复位在 Q28 运营线 **8/8 无坏发**（5 POR + 3 暖）里都被 assert+release 过
  （`reports/q28-workaround-closeout-20261024.md` §2）——这是「覆盖」，**不是隔离实验**；
- 明确写「数组 API + 两项复位这个确切形状没上机」「没做新 A/B」「不声称 INT2 是 load-bearing 项」。

同时把「为什么判据只需 CORE+INT2」写清：**复现态本来就只复位了 CORE**（v2 之前
`sm8750.dtsi` 的 mdss 节点只列一项复位）⇒ 失败时 INT2 必然处于未复位态，RSC 不是必要条件。
两封回复里也各写了这一句，避免「删了 RSCC 凭什么还能治好」的重问。

---

## §4 证据强度自审（为什么本轮不上机，以及残余风险）

- **只删复位项 + 删注释，不改 API、不改时机**：`0002` 的代码语义与 v2 逐字相同（v2 已过编译与
  binding 门），`0001/0003` 只减不减机制。所以「v2 → v3 的行为差」只可能来自少复位一个块，
  而该块（RSC）按 §1 的归属裁定本就不属于 MDSS。⇒ 不需要新上机，**且未声称做了新 A/B**。
- **残余风险 1（`claims.tsv` G1）**：`devm_reset_control_array_get(..., RESET_CONTROL_OPTIONAL_EXCLUSIVE)`
  这条路径在 2026-10-23 的同族实验里曾撞 `-EBUSY`（当时改 shared + prime deassert 才过）。
  v3 未复测该 API 组合；若真机 probe 报 `-EBUSY/-EINVAL`，首选修法是换 shared 语义或回到
  bulk-named 形态。**本轮未改（派工单限定只删复位项/注释），在此显式记账。**
- **残余风险 2（G2）**：20 ms 保持时长沿用 upstream 单 CORE 时的值，对两项是否够未测（v1 曾用 50 ms）。
- **未上机（G3）**：v3 形状无真机样本 —— cover 已明写。

---

## §5 lore 三态（逐封，判据 `/<list>/<完整msgid>/raw` = 200）

| 对象 | linux-arm-msm | dri-devel | linux-devicetree | 正文 sha256 |
|---|---|---|---|---|
| 0/3 | ✅ 8219 B | ✅ 7524 B | — | `60f53f96e5d17b02` ✔ |
| 1/3 | ✅ 7408 B | ✅ 6745 B | ✅ 7387 B | `4219820ba6433866` ✔ |
| 2/3 | ✅ 6924 B | ✅ 6225 B | — | `cfc43965b2467749` ✔ |
| 3/3 | ✅ 6857 B | ✅ 6159 B | — | `045150c83a33c581` ✔ |
| 回 2/3 | ✅ 5508 B | ✅ 4744 B | — | `d9a1d81dc81db0b8` ✔ |
| 回 3/3 | ✅ 5476 B | ✅ 4712 B | — | `2acc566933224b1d` ✔ |

注：`/all/<mid>/` 本轮仍是 300 Multiple Choices（多列表收录时无法选一），故一律走列表专属路径。
**附带的通道结论**：M6 B5 当日 `dri-devel` 0/6 的「该列表会丢非订阅者」判断，本轮被证伪
（dri-devel 4/4 + 2/2 全部归档）——以后不要沿用那条悲观结论。

---

## §6 产物

```
patches/upstream/m8-mdss-v3-20261102/
  0000-cover-letter.patch 0001-*.patch 0002-*.patch 0003-*.patch   # format-patch 产物
  README.md GATES.md SENT.md claims.tsv
  sent/{send-email.log, msgids.txt, readback-236..241.txt}
out/mail-20261102-mdss/
  re-dmitry-mdss-v3-comment.txt  re-dmitry-mdss-v3-rscc.txt        # 两封回复草稿
reports/mail-send-20261102-mdss.md                                  # 本文件
TASKS/sessions/2026-11-02-投递-mdss-v3.md                           # 会话记录（6 字段头 + ★SSOT 待并入）
```

复跑：门禁命令见 `GATES.md` §2–§5；归档复核 =
`python3 /tmp/eld-lore-1102.py <list>:<完整msgid>`（`/tmp` 临时脚本，未入库）。

---

## §7 未做

- 未上机（理由与残余风险见 §4）。
- 未改 patchwork（v2 4 枚仍 `new`；标 superseded 需账号，API 403）。
- 未跑 `dtbs_check`、未跑全量 arm64 编译（门禁范围 = msm 目录 + binding + checkpatch + am 回放）。
- 未改任何 SSOT 文档；`TASKS §7 M8` 行需要并入的文字已写在会话文件「★SSOT 待并入」。
