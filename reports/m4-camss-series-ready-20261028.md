# M4-2…M4-4 定稿：可发状态（2026-10-28）

> 触发：`继续任务` → 「把 M4-2…M4-4 定稿成可发状态（补齐 R3 拆 RFC、正文/收件人/gate 全绿、留 dry-run 产物）」。
> 性质：**纯主机侧**（`build/m4-base` worktree 内重建历史 + 编译/dtbs/schema 门 + `send-email --dry-run`），**零设备操作**。
> 交付：`patches/upstream/m4-camss-series-20261028/`（9 提交 + cover letter + README）。

## §0 结论（数字）

| 项 | 结果 |
|---|---|
| 系列 | **9 提交 / 14 文件 / +1931 −61**，基线 pristine `24a19b953`（7.3-rc7），源分支 `m4/send-20261028` @ `02df6d46c` |
| `checkpatch --strict` | **9/9：0 errors、0 checks**；3 条 WARNING 全是 MAINTAINERS 整目录 glob 假阳性（R5，不用改） |
| 逐提交编译 | **9/9 rc=0、0 warning**，且每次都到 `LD [M] qcom-camss.o` ⇒ 连模块链接都过 |
| binding | `dt-doc-validate` **rc=0** |
| **`dtbs_check`（新增，R6 关闭）** | `qcom/sm8750-{mtp,qrd}.dtb` **0 warning**；**负向测试**：塞 `bogus-test-property` ⇒ schema 精确报错（证明真在校验本节点） |
| 重放 | pristine + `git am 000[1-9]-*.patch` ⇒ **9/9 干净**，终态与源分支 **逐字节一致**（`git diff` 空） |
| dry-run | `git send-email --dry-run` ⇒ **10 × `Result: OK`**，10 封同线程（`…306629-1..10`），纯 ASCII |

## §1 相对上一版草稿（`m4-camss-series-20261027/`）的实质变更

| 项 | 旧草稿 | 现在 |
|---|---|---|
| 提交数 | 7（含 `0007-NOT-FOR-UPSTREAM-csid-vfe-pairing`） | **9**，且**剔除 NOT-FOR-UPSTREAM 提交**（它只属本地树，M4-5 隔离层） |
| **R1** SKEW_CAL | 4 条 `0x5c = 0x54`（我方偏离） | **改成厂商值 `0x00`**，正文写明厂商 `csiphy_2ph_v2_4_0_reg` 出处（地址/掩码/类型 103/103、data 99/103）+ 本机 A/B（90 帧 ×2、0 错误、30.26 fps、帧时 STDDEV 53.81 vs 53.78）「无可测差异」+ 「本机是 2ph 变体，3ph 表地址体系不同不能复用」 |
| **R3** 架构改动 | 夹在 `csid: add the 980 generation and report frame starts from CSID` 里 | **拆成两提交**：`csid: add the 980 generation`（4）+ `csid: report frame starts from CSID`（5）；cover letter 给三段论证（gen4 VFE 为何不再报中断 / 序号为何只由 SOF 递增 / 错误帧为何 ERROR 而非丢弃） |
| **R4** 混装 | 一枚提交混「DMA 连续性校验」+「起流失败回退」 | **拆成**（6）DMA 连续性 + `prepare_buffer()` 钩子、（7）失败回退（顺带修「stop 某 subdev 失败仍继续停其余」） |
| **R6** DT 缺件 | 无节点 ⇒ `dtbs_check` 跑不了 | **新增（9）`arm64: dts: qcom: sm8750: add the camera subsystem`**（`isp@ad27000`，`status = "disabled"`）⇒ `dtbs_check` 可跑且绿 |
| binding 位置 | 第 5 枚 | **第 1 枚**（上游惯例：binding 先行、可独立评） |

方法备注：拆提交用的是「按目标树快照逐提交提交」而不是 `git rebase -i` —— 旧草稿里 3 与 3a/3b 是**派生关系**
（3a = 3 去 SOF），cherry-pick/rebase 会在「修改一个目标树里不存在的文件」上打冲突（实测）。
快照法保证每步 **diff 只含该提交要表达的内容**，且终态可与草稿 `git diff` 逐字节比对。

## §2 定稿时抓到的两个小问题（都已修）

1. 旧 `0004` 提交尾部有**一行缩进的重复 `Signed-off-by`**（`    Signed-off-by: …`）—— `checkpatch` 会当格式问题；重切时丢了。
2. 3a 拆分处残留**连续两个空行**（`CHECK: Please don't use multiple blank lines`）—— 已修，现 9/9 `0 checks`。

## §3 收件人（`get_maintainer.pl` 现取）

- **To**：`Bryan O'Donoghue <bryan.odonoghue@linaro.org>`（camss 共同维护者）、`Mauro Carvalho Chehab <mchehab@kernel.org>`（media）
- **Cc**：Rob Herring、Krzysztof Kozlowski、Conor Dooley（DT）、Bjorn Andersson、Konrad Dybcio（arm-msm）、
  Hangxiang Ma、`linux-media`、`linux-arm-msm`、`devicetree`、`linux-kernel`

## §4 仍然存在、但**不阻塞发送**的项

- **R5 MAINTAINERS 假阳性**：回帖贴 `F: drivers/media/platform/qcom/camss/` 与
  `F: Documentation/devicetree/bindings/media/qcom,*camss*` 两条即可。
- **R7 / M4-5**：`CAMSS_INIT_BUF_COUNT` 重复 RUP 规避、SOF/EOF 时间戳兼容分支、`mc-entity.c` 核心改动、
  CSID↔VFE 按 `i==k` 的 SoC 特判 —— 均按约定**不进本系列**。
- **上机**：本系列 = 已在机树（`build/vk151`）功能等价重切，机上出流证据属 G1-5/devcam 记录；本轮零设备写。

## §5 环境坑（一句话）

`make dt_binding_check` 在本机**跑不了**（`scripts/dtc/dt-check-style` 缺 `ruamel.yaml`，且 `scripts/dtc/dt-doc-validate`
未生成、`python3 -c "import dtschema"` 也没有）⇒ 用**用户装的** `~/.local/bin/dt-doc-validate`（自带环境，rc=0）
+ `make CHECK_DTBS=y DT_SCHEMA_FILES=…`（后者能跑，且已用负向测试证明有牙）。

## §6 产物指针

- 系列：`patches/upstream/m4-camss-series-20261028/`（`0000-cover-letter.patch` + `0001..0009` + `README.md`）
- 旧草稿（已标 superseded）：`patches/upstream/m4-camss-series-20261027/`
- dry-run 转录：`out/mail-20261028/m4-camss-20261028-dryrun.txt`（`out/` 不入库）
- 源分支：`build/m4-base` 的 `m4/send-20261028`（`draft/m4-split` = 拆分前留档）
- 前置取证：`reports/m4-csiphy-vendor-provenance-20261027.md`（R1/R2）、`reports/lanes-20261027-verified.md`（devcam A/B）
