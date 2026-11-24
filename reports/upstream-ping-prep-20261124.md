# 两条「只欠一次礼貌 ping」的系列：现查事实 + 待发草稿（2026-11-24）

> 范围：**只读调研 + 草稿**。零发信、零上机、不改既有文件（只新增 `out/mail-20261124/` 两份草稿 + 本文件）。
> 现查数据由主会话用 host `curl` 于 **2026-11-24 22:5x CST** 跑 patchwork API 1.1 + `git.kernel.org` plain 取得
> （本子代理无 shell / `curl` / `web_fetch`，见 §6 ⇒ **原始 JSON 输出在主会话侧、不在本仓**，本文件按其转述登记）。
> 仓内实物（M8 的 cover + 三枚补丁、ADSP 系列目录、两份 README、`out/mail-20261031/` 披露范例）由本文件作者逐行读过。

## §0 三个数字

| 项 | 值 |
|---|---|
| 现查覆盖 | M8：3 个 project 副本 / 9 个 patch id / 3 个 series id + 1 条评论；M10：1 个 patch id + 评论计数 + 1 条内容级 grep |
| 草稿 | `out/mail-20261124/draft-m8-mdss-ping.txt` = **23 行**（技术正文 5 行 ≤ 12）；`draft-m10-fastrpc-ping.txt` = **19 行**（技术正文 4 行 ≤ 10）；两文件**末字节 = 0x0a**（避免 `git send-email` 的 trailing-newline 报错） |
| 是否已进树 | **两系列都未进 torvalds master**（M8 两项 grep = 0；M10 一项 grep = 0） |

## §1 M8（drm/msm/mdss: reset all block resets described in DT，2026-11-13T15:56Z 投出）

**★ 本轮改变口径的一条：M8 不是「无人答复」，而是有 1 条未处置的 review 评论**（sashiko，见 §1.3）。
`reports/upstream-recheck-20261124.md` §8 那句「v5 已 ~10 天仍在两条树之外，属等批量 pull」对**未进树**仍然成立，
但「无待办技术改动」**不成立** ⇒ 那一句以本文件为准（本轮禁改原文，见 §6）。

### 1.1 三个 project 副本 = 三个 series（patchwork API 1.1）

| series | 副本 project | patch id | 枚 | state |
|---|---|---|---|---|
| **1210709** | linux-arm-msm | 14980387 / 14980388 / 14980389 | [1/3] / [2/3] / [3/3] | `handled-elsewhere` / `handled-elsewhere` / `new` |
| **1210711** | dri-devel | 14980395 / 14980396 / 14980397 | [1/3] / [2/3] / [3/3] | 全 `new` |
| **1210712** | linux-devicetree | **14980400** / 14980398 / 14980399 | [1/3] / [2/3] / [3/3] | 全 `new` |

- **`commit_ref` 9 枚全 None**。
- **每个 series 只有 3 枚 ⇒ v5 没有 cover**（任务书里「dri-devel 14980395–14980400」的 `14980400` 实为 **devicetree 副本的 [1/3]**，不是 cover id）。
  与仓内实物对照：`patches/upstream/m8-mdss-v5-20261114/` 里**存在** `0000-cover-letter.patch`，
  而投递记录 `out/mail-20261114/send-mdss-v5.log` = **4×250**（4 封 = cover + 3 枚）。
  ⇒ patchwork 只有 3 枚 ×3 副本，说明 **cover 被 patchwork 归到 series 之外（没建进这三个 series）**。
  两个事实的张力本身值得复核，见 §4 **R8**。

### 1.2 最新代次 = v5（2026-11-13），逐字 Message-ID

| # | Message-ID（author 侧同一套，三副本共享） |
|---|---|
| 1/3 | `<20261113155635.1677541-2-xiaqinghuan@mail.ustc.edu.cn>` |
| 2/3 | `<20261113155635.1677541-3-xiaqinghuan@mail.ustc.edu.cn>` |
| 3/3 | `<20261113155635.1677541-4-xiaqinghuan@mail.ustc.edu.cn>` |

`-1` 位空缺（MID 序列从 `-2` 起）= cover 有独立 MID `<20261113155635.1677541-1-…>`，与 README 的 4 枚 MID 表一致。
`<…42e0bacd02fa…>` 那条是 v5 当天**回 sashiko（v4 3/3）**的信，不是 cover。

**版本号形状**：仓内实物的 Subject 写 `[PATCH v5 N/3]`，但 patchwork 的 `name` 字段是否带 `v5` **未取证** ⇒
草稿 Subject 按「无版本号」形状写 `Re: [PATCH 1/3] …`；若现查 `name` 带 `v5`，投递前改成带 `v5` 的形状即可（正文不受影响）。

### 1.3 唯一一条评论（**未处置**）

`GET /api/1.1/patches/14980400/comments/` → **n=1**：作者 **`sashiko-bot@kernel.org`**，**2026-11-13T16:12:14Z**，
标题 **`[Low] dt-bindings: display: msm: misdescribed MDSS_CORE_INT2 reset in mdss-common`**。大意：
`DISP_CC_MDSS_CORE_INT2_BCR` @0xa000 配 `MDSS_INT2_GDSC` @0xb000，复位的是**次级 MDSS core 时钟域**
（`disp_cc_mdss_mdp1_clk` / `mdp_lut1_clk` / `vsync1_clk` / `ahb1_clk`），**不是 interrupt controller**；
MDSS 顶层 `HW_INTR_STATUS` 在主 MDSS core MMIO 内。

**我方仓内实物确实带着这个措辞**（逐行核过）：
`0001-dt-bindings-display-msm-mdss-common-describe-additio.patch` 的 hunk 把 `mdss-common.yaml` 写成
`- description: MDSS core INT2 interrupt controller reset`；`0000-cover-letter.patch` 正文同样说
"a block reset for the MDSS core INT2 interrupt controller"。
⇒ v6 要改的是 **1/3 的 `description:` + 1/3/cover 的措辞**（v5 只改了 3/3 的 message，1/3 与 v4 逐字节相同 ⇒ 这一处漏了）。
**方向与我们 Q28 / 0xa000-0xb000 的自有结论同向**（v4 时 Konrad + sashiko 的 Medium 质疑就是同一件事，见 `m8-mdss-v5-20261114/README.md` §「触发」）。

### 1.4 内容级判据（torvalds master，直接读文件，不看 patchwork 状态字段）

| 判据 | grep 判据 | 结果 |
|---|---|---|
| 2/3 驱动（reset 数组 API） | `devm_reset_control_array_get` in `drivers/gpu/drm/msm/msm_mdss.c` | **0** ⇒ 未合 |
| 3/3 DT（第二枚 block reset） | `core_int2_bcr` in `arch/arm64/boot/dts/qcom/sm8750.dtsi` | **0** ⇒ 未合 |
| 1/3 binding | 11-24 早先那轮已判：`mdss-common.yaml` 的 `resets:` 仍是单条 `MDSS_CORE reset`（`reports/upstream-recheck-20261124.md` §8，linux-next 与 torvalds 两侧 `msm_mdss.c` size 相同） | 未合 |

## §2 M10（arm64: dts: qcom: sm8750: mark the ADSP fastrpc node as non-secure domain，v3）

| 项 | 现查值 |
|---|---|
| patch id / project | **14971025** / linux-arm-msm |
| 最新代次 | **v3**，`2026-11-11T03:57:31Z`，series **1207873**（单枚），未被 supersede（v1 `14959877`、v2 `14966246` 均 `superseded`，见 `reports/upstream-queue-prep-20261121.md` §2.1） |
| state / `commit_ref` / archived | `new` / **None** / false |
| 评论 | `comments/` = **0** ⇒ v3 投出后 13 天零回复。人工评论唯一一次 = **Konrad 回 v1**（两条：① AI 披露段挪到 `---` 以下；② 把 +Ekansh / +Dmitry / +Srini 拉进线程）——**v3 已落实第①条**（同报告 §2.2/§2.4） |
| Message-ID | `<20261111035731.940893-1-xiaqinghuan@mail.ustc.edu.cn>` |
| 内容级 | torvalds `sm8750.dtsi` 里 `qcom,non-secure-domain` 出现次数 = **0** ⇒ **未进树** |

**这条 grep 有一个副作用（比「未进树」更值得注意）**：11-21 那轮记的是「mainline 里 `non-secure-domain` 命中 1 = CDSP 有、ADSP 没有」，
今天 torvalds master 同一文件命中 **0** ⇒ 该文件的 fastrpc 段整体在 next/quilt 侧、Torvalds 树里还没有。
⇒ 后果：**ping 正文刻意不写「CDSP 节点已带此属性」这句类比**（今天的 torvalds master 上无法自证），也不写「树里该处未变」（我们看不到 quilt，无法证明）。见 §4 R6。

## §3 两份草稿（**只写不投**，投递按 `TASKS/README.md` §7 逐系列批准）

| 文件 | 行数 | 挂载点 | 正文形状 |
|---|---|---|---|
| `out/mail-20261124/draft-m8-mdss-ping.txt` | 23（技术正文 5） | `In-Reply-To`/`References` = v5 **1/3** `<…1677541-2-…>` | 承认 sashiko 的 [Low] 成立 ⇒ v6 把 description/changelog 改称 "secondary MDSS core clock domain reset"（零代码、零 DT 改动），问「现在发 v6？」+「要不要先 rebase 到 current master？」 |
| `out/mail-20261124/draft-m10-fastrpc-ping.txt` | 19（技术正文 4） | `In-Reply-To`/`References` = v3 `<20261111035731.940893-1-…>` | 只陈述「v3 自 11-11 无回复 + v1 的两条要求已在 v3 落实」，问「要不要重基到 current master 再发 v4 / 走哪棵树」 |

两稿共同形状（照 `out/mail-20261031/re-krzysztof-wl2868c.txt` 的范例改短）：
`To`/`Cc`/`Subject`/`In-Reply-To`/`References` 头 → 空行 → `*** AI-assistance disclosure ***`（LLM 起草、作者逐行校对、内容/测量/决定归作者）→ 空行 → 一句问候 → 技术正文 → 署名。
**不写任何未经取证的 reviewer 名字或 trailer**；M8 稿只说 "The three Reviewed-by tags still apply" 而不点名（三枚归属只来自仓内记录，见 §4 R2）。

**两稿各自最可能被 reviewer 追问的一句**（诚实边界，别当已答）：

- M8：v5 cover 里我们自己写下的两条测量边界（15/15 出自「含 RSCC 的三枚形状」、`0xa000` 未做单变量 A/B）**草稿没提**，只提了 sashiko 那条。若维护者接着问这句，光改措辞不够 ⇒ §4 R5。
- M10：草稿那句 "both changes Konrad asked for on v1 are already in it"，其中「把三位拉进线程」是靠**我们回复时 Reply-all** 实现的。若这份新线程的 `Cc` 头与实际线程成员不一致，这句在收件人眼里就是空的 ⇒ **投递前逐字核对 `Cc` 头**；`Ekansh Gupta <quic_ekangupt@quicinc.com>` / `Srini Kandagatla <srinivas.kandagatla@linaro.org>` 两个地址写法是**从仓内报告的名字推断的，未经取证**（R6b：核对 lore 线程原头的写法，或直接删掉这两个地址只留 `linux-arm-msm`）。

## §4 需用户裁决（按优先级）

| # | 待裁 | 依据 / 选项 |
|---|---|---|
| **R1** | **M8：先处置 sashiko 那条 [Low]（直接出 v6）还是先 ping**（推荐**先处置**） | 有明确可写的 v6 = 改 1/3 的 `description:` + 1/3/cover 措辞，**零代码 / 零 DT 改动**、三个 R-b 全可保留。上游惯例里「带修正的 v6」比「问一句要不要 v6」更快被 pick ⇒ 建议下一轮备料出 v6，**本 M8 ping 大概率不该投**，留作「想先问一句」时的备选 |
| R2 | M8 草稿要不要**点名三个 Reviewed-by**（Abel Vesa / Dmitry Baryshkov / Konrad Dybcio） | 现查只给「评论 n=1」，未给 trailer 明细；三枚归属只来自 `m8-mdss-v5-20261114/README.md`。不点名 = 绝对安全但少一分「可直接 pick」的信号 |
| R3 | M8 若发 v6：**1/3 要补回 Rob Herring 的 `Acked-by`**（v3 有、v4/v5 掉了） | `m8-mdss-v5-20261114/README.md` §「已知遗留」第 1 条；贴逐字 Ack 需要一次 trailer 明细现查 |
| R4 | **M8 的收件人 / 挂载副本**：现草稿 To = DT 维护者（Krzysztof / Rob / Conor），Cc arm-msm + dri-devel（因为那条评论在 devicetree 副本 14980400） | 备选 = 挂 **arm-msm 副本**（14980387）并把 To 换成 `andersson` / `konradybcio`——「0xa000 到底属哪个域」是 Qualcomm 硬件事实，他们才是否决者。三副本并存 ⇒ 挂哪份 = 谁的队列先看见 |
| R5 | M8 是否顺带处理 3/3 的**测量边界**（`0xa000` 单变量 A/B、两枚形状上机验证都没做） | v5 cover 已自曝；维护者下一步很可能就问这句 ⇒ 需要一次上机 A/B（禁在本轮）。若不愿补测，按 README「下一步」方案 (b)：删 3/3、只留 1/3+2/3 |
| R6 | M10：正文要不要加一句「该文件目前在 mainline 里还没有这段节点」 | 本轮 grep=0 的副作用（§2）。当前草稿**不提**（最保守）。另：是否顺带问「是否改与 Ekansh 的 `qcom,fastrpc` 重构 / `Remove secure FastRPC context bank` 一起走」（同向，见 `upstream-queue-prep-20261121.md` §2.4） |
| **R6b** | M10 草稿 `Cc` 里 **Ekansh / Srini 的地址写法未经取证**（§3） | 三个动作里挑一个：① 用 lore 原头核对写法（lore 需 Firecrawl，不能裸 curl）；② 删掉这两个地址、只留 `andersson`/`konradybcio` + 两个 list；③ 保留但在正文去掉「both changes」这句 |
| R7 | 放行后的 Mbox 化与记账：`git send-email --in-reply-to … --thread`，日志进 `out/mail-<日期>/send*.log` + `reports/mail-send-*.md` | 本文件不假定已批准 |
| **R8** | M8 **cover 到底投没投**（数据自相矛盾） | 一边：`send-mdss-v5.log` = 4×250 且 README 有 cover MID；另一边：三个 series 各只有 3 枚、MID 序列 `-1` 位空着 ⇒ 像是 cover 未投或被 patchwork 归到 series 外。影响：若 cover 其实没投，v5 的「三个 R-b 全保留 + 边界声明」这段维护者**根本没看到**，那 ping 的性质就从「催」变成「补交代」 |
| **R9** | M8 v6 是否顺手避开**同文件外部在途件** | `[PATCH v3 07/11] drm/msm: mdss: Add support for MDSS on Nord`（Nabige Aala，11-16）也改 `msm_mdss.c`（`upstream-recheck-20261124.md` §7/§8 已登记）。我们 1/3 只动 binding、2/3 动 `msm_mdss.c` 的相邻 hunk ⇒ 出 v6 前先看它是否进树，需要再查一次 |

## §5 复核命令（任何人可复跑；本文件所有数字都出自这两类只读命令）

```sh
PX=https://patchwork.kernel.org/api/1.1
for id in 14980387 14980388 14980389 14980395 14980396 14980397 14980398 14980399 14980400 14971025; do
  timeout -k 10 30 curl -sS "$PX/patches/$id/" \
    | jq -r '[.id,.project,.name,.state,.commit_ref,.series]|@tsv'
done
for id in 14980400 14980387 14971025; do
  timeout -k 10 30 curl -sS "$PX/patches/$id/comments/" \
    | jq -c '[.[]|{submitter:.submitter.name,date:.date}]'
done
# v5 三枚的 trailer 明细（R2/R3 要用这个，别只靠 README）
timeout -k 10 30 curl -sS "$PX/patches/14980395/" | jq -r .content | sed -n '1,40p'
K=https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain
timeout -k 10 30 curl -sS "$K/drivers/gpu/drm/msm/msm_mdss.c" | grep -c devm_reset_control_array_get   # 期望 0
timeout -k 10 30 curl -sS "$K/arch/arm64/boot/dts/qcom/sm8750.dtsi" | grep -c core_int2_bcr            # 期望 0
timeout -k 10 30 curl -sS "$K/arch/arm64/boot/dts/qcom/sm8750.dtsi" | grep -c non-secure-domain        # 期望 0
# 草稿形状：技术正文 ≤ 12 / 10 行；末字节须为 0a（否则 git send-email 报 trailing-newline）
for f in out/mail-20261124/draft-m8-mdss-ping.txt out/mail-20261124/draft-m10-fastrpc-ping.txt; do
  wc -l "$f"; tail -c1 "$f" | od -An -tx1; done
```

## §6 本轮工具边界与由此产生的验证限制（如实记）

- 本子代理（role=researcher）**工具面只有 `web_search` / `read` / `write`：无 shell、无 `curl`、无 `web_fetch`**。
  ⇒ 任务书步骤 2「patchwork REST（`curl` 套 `timeout -k 10 30`）」与步骤 3「`web_fetch` 抓 `plain/` 再 grep」**我无法亲自执行**。
  已试且失败的绕法：`web_search provider="browser"` 会把 URL 当**搜索词**丢进 DuckDuckGo（一次返回无关结果、一次 0 结果 / 32 s），并不 fetch URL；
  各 provider 对 patchwork API 端点与补丁 ID 一律 0 命中（Firecrawl 路 curl 60 s 超时）。已上报阻塞，主会话给出真值。
- **验证限制（明确一条）**：§1 / §2 的 patchwork 与 grep 数字 = **主会话 curl 真值的转述**，原始 JSON 不在本仓 ⇒ 本仓内无法二次复算；
  §5 的存在就是为了让任何人 60 秒内自己复算并推翻本节。相对地，**仓内实物（cover + 三枚 M8 补丁正文、ADSP 系列目录与两份 README）是本文件作者逐行读过的直接证据**。
- 未访问 lore（按任务书：lore 直连被 Anubis 挡）；未发信、未 `git push`、未跑编译、未碰设备。
- 副作用清单：**只新增 3 个文件**（`out/mail-20261124/` 两份草稿 + 本文件），未改任何既有文件。
  ⇒ 由此留下待下一轮显式改写的**已知矛盾**（本轮禁改）：
  ① `reports/upstream-recheck-20261124.md` §8 的「v5 … 无待办技术改动 / 可以问一句」——M8 现有 1 条未处置 [Low]；
  ② `reports/upstream-queue-prep-20261121.md` §2.3 的「mainline 命中 1 = CDSP 有」——今日 torvalds master 同一文件命中 0（§2 副作用）。
