# M4-2…M4-4 camss 驱动系列（**可发状态**，2026-10-28 定稿）

面向上游 `linux-media` 的 **camss SM8750 驱动主体**，9 提交。承接 M4-1（sensor binding 三枚已投，
`patches/upstream/m4-camss-2026-10-13/sent-20261027/`）。
规则 = `reports/upstream-policy-20261013.md`；拆解方案 = `reports/m4-camss-project-20261013.md` §2.1。

**状态：v1 已投**（2026-10-28 03:41Z，`[PATCH 0/9]` 10 封全 `Result: 250`，cover MID `<20261028034105.326535-1..10@mail.ustc.edu.cn>`，实发转录 `out/mail-20261028/m4-camss-20261028-send.txt`；v2 见 `../m4-camss-series-20261028-v2/`）。上一版草稿（7 提交、含 `NOT FOR UPSTREAM` 提交、未拆 R3/R4）
保留在 `../m4-camss-series-20261027/` 作历史，**不要再发那一版**。

## 1. 基线与复现

| 项 | 值 |
|---|---|
| 基线 | pristine `24a19b953`（Linux 7.3-rc7） |
| 源分支 | `build/m4-base` @ **`m4/send-20261028`**（tip `02df6d46c`，9 提交，14 文件，**+1931 −61**） |
| 重放验证 | 在 pristine 上新开分支 `git am 000[1-9]-*.patch` ⇒ **9/9 干净**，终态与源分支 `git diff` **逐字节空** |
| 备份 | 旧草稿分支 `draft/m4-split`（tip = 旧 7 提交拆分前状态）、`backup/m4-draft-20261027` |

```sh
# 逐提交可编译（arm64 defconfig，CONFIG_VIDEO_QCOM_CAMSS=m）
cd build/m4-base
for c in $(git rev-list --reverse 24a19b953..m4/send-20261028); do
  git checkout -q $c && make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
    drivers/media/platform/qcom/camss/ || echo "FAIL $c"; done
```

## 2. 提交清单（发送顺序 = 文件序号）

| # | 主题 | 内容 / 为何单独 |
|---|---|---|
| 1 | `dt-bindings: media: add the Qualcomm SM8750 camera subsystem` | `qcom,sm8750-camss.yaml`；**放最前**（上游惯例：binding 先行，它独立于驱动可单独评） |
| 2 | `csiphy: add CSIPHY 2.4.0 lane settings for SM8750` | 103 条 lane 表 + `CAMSS_8750`；**R1 已定案**：4 条 SKEW_CAL 用厂商值 `0x00`（不是 `0x54`），正文写明厂商 2ph 表出处 + 本机 A/B「无可测差异」 |
| 3 | `csid: unwind the power-on path through a single error label` | 顺带修真 bug（pm_runtime 失败漏放 parent 引用）；**可独立进上游** |
| 4 | `csid: add the 980 generation` | 新文件 `camss-csid-980.c`（full/lite）+ `rup_update`/`aup_update` 显式字段（替掉下游匿名 union）；**不含帧起始** |
| 5 | `csid: report frame starts from CSID` | **R3 已拆**：架构性改动独占一枚 —— SOF 源从 VFE 移到 CSID、`camss_frame_start()`、`V4L2_EVENT_FRAME_SYNC`、序号只在 SOF 递增、SOF 前完成的 buffer 标 `VB2_BUF_STATE_ERROR`、EOF/SOF 时间戳比较处理「SOF 后到」 |
| 6 | `video: check that a buffer is DMA contiguous and add a prepare hook` | **R4a**：写主控只能吃连续 buffer（帧增量寄存器描述单段线性地址）+ `prepare_buffer()` per-SoC 钩子 |
| 7 | `video: stop the subdevices already started when a start fails` | **R4b**：失败回退（抽出 `video_stop_subdevices()`，顺带「停某个 subdev 失败也继续停其余」） |
| 8 | `vfe: add the gen4 block and SM8750 camera subsystem` | `camss-vfe-gen4.c` + 资源表（6 CSIPHY/4 CSID/3 VFE/2 lite）+ icc + compatible |
| 9 | `arm64: dts: qcom: sm8750: add the camera subsystem` | **R6 已闭**：`isp@ad27000` 节点进 SoC dtsi（`status = "disabled"`）⇒ **`dtbs_check` 现在能跑且绿** |

## 3. 门禁（2026-10-28 全部重跑）

| 门 | 结果 |
|---|---|
| `checkpatch.pl --strict` ×9 | **0 errors / 0 checks**；3 条 WARNING 全是同一假阳性（1/4/8 的 `added file(s), does MAINTAINERS need updating?`，见 R5） |
| 逐提交 `make drivers/media/platform/qcom/camss/` | **9/9 rc=0，0 warning**（arm64 defconfig；每次都到 `LD [M] qcom-camss.o` ⇒ 连链接都过） |
| `dt-doc-validate qcom,sm8750-camss.yaml` | **rc=0** |
| `make CHECK_DTBS=y DT_SCHEMA_FILES=… qcom/sm8750-{mtp,qrd}.dtb` | **0 warning**（两板） |
| `dtbs_check` 负向测试 | 往节点塞 `bogus-test-property` ⇒ schema 精确报 `'bogus-test-property' does not match any of the regexes`（证明校验真的覆盖了本节点，不是空转） |
| 重放 | pristine + `git am` 9 枚 ⇒ 干净，终态逐字节一致 |
| `send-email --dry-run` | 10 × `Result: OK`；To/Cc 已定；纯 ASCII；线程 `References` 自洽 |
| 未跑 | 未上机（**本系列 = 已在机树的功能等价重切**，机上验证在 `devcam-ab`/G1-5 记录里；本轮零设备写） |

## 4. 评审风险（2026-10-28 状态）

- **R1 数值出处** ✅ **已定案**：2ph v2.4.0 lane 表与厂商 `csiphy_2ph_v2_4_0_reg` 地址/掩码/类型 103/103 相同、
  data 99/103；4 条差异 = SKEW_CAL 数据字节，**改用厂商值 `0x00`**（本机 A/B 90 帧 ×2 无可测差异，正文已写明）。
  正文另点明「本机是 **2ph** 变体，3ph 表地址体系不同不能复用」（`reports/m4-csiphy-vendor-provenance-20261027.md`）。
- **R2 `0x138`** ✅ 已解决（厂商每代参数结构 `csiphy_v2_4_0[+4] = 0x1138`）。
- **R3 架构性改动** ✅ **已拆成独立提交**（#5），cover letter 里给了三段论证（为什么 gen4 VFE 不再报中断、
  序号为何只由 SOF 递增、错误帧为何用 ERROR 而非丢弃）。
- **R4 提交混装** ✅ **已拆**（#6 / #7）。
- **R5 MAINTAINERS 假阳性**（不用改）：`QUALCOMM CAMERA SUBSYSTEM DRIVER` 段已含
  `F: drivers/media/platform/qcom/camss/` 与 `F: Documentation/devicetree/bindings/media/qcom,*camss*`；回帖贴这两条即可。
- **R6 DT 缺件** ✅ **已闭**：SoC dtsi 节点随系列（#9），`dtbs_check` 绿。
- **R7 已知遗留（仍不进本系列）**：`CAMSS_INIT_BUF_COUNT` 重复 RUP 的规避、SOF/EOF 时间戳排序的兼容分支、
  `mc-entity.c` 核心改动 ⇒ 归 M4-5；CSID↔VFE 按 `i==k` 配对的 SoC 特判**也仍隔离在本地**
  （旧草稿的 `0007-NOT-FOR-UPSTREAM-*`，**已从可发系列剔除**）。
- **可能的第一问**：「为什么不复用 `csiphy-3ph-1-0.c` 的 3ph 表」→ 已在 #2 正文回答；
  「为什么 SOF 由 CSID 报」→ 已在 #5 正文 + cover letter 回答。

## 5. 发送（需用户批准）

```sh
cd build/m4-base
D=/home/xuqianhui/y700-elden/patches/upstream/m4-camss-series-20261028
git send-email --no-chain-reply-to \
  --to="'Bryan O'Donoghue' <bryan.odonoghue@linaro.org>" \
  --to="Mauro Carvalho Chehab <mchehab@kernel.org>" \
  --cc="Rob Herring <robh@kernel.org>" \
  --cc="Krzysztof Kozlowski <krzk+dt@kernel.org>" \
  --cc="Conor Dooley <conor+dt@kernel.org>" \
  --cc="Bjorn Andersson <andersson@kernel.org>" \
  --cc="Konrad Dybcio <konradybcio@kernel.org>" \
  --cc="Hangxiang Ma <hangxiang.ma@oss.qualcomm.com>" \
  --cc="linux-media@vger.kernel.org" --cc="linux-arm-msm@vger.kernel.org" \
  --cc="devicetree@vger.kernel.org" --cc="linux-kernel@vger.kernel.org" \
  $D/0000-cover-letter.patch $D/000[1-9]-*.patch
```

投递后必做（技能 `upstream-mail-ustc` §5）：lore 按 Message-ID 取 raw 复核 + INBOX 回环 + 正文 sha 比对。
dry-run 转录件：`out/mail-20261028/m4-camss-20261028-dryrun.txt`（`out/` 不入库）。

## 6. 投递记录（2026-10-28 11:40:56 +0800 已发）

| 项 | 值 |
|---|---|
| 发送 | `git send-email --confirm=never`，10 封 `Result: 250`（git 2.53 不认 `--no-confirm`，须 `--confirm=never`） |
| Message-ID | `<20261028034105.326535-1..10-xiaqinghuan@mail.ustc.edu.cn>`（同一线程，`References` 自洽） |
| Sent Items 回读 | 10/10 在（`[170,172..178]` + 2 封主题不含 "camss" 的按主题单查） |
| INBOX 回环 | 10/10（每封各 1 次列表回环） |
| **lore 归档** | `/all/` **10/10**；另抽验 `/linux-media/`（#5）、`/linux-arm-msm/`（#7）、`/linux-devicetree/`（#1）均 200 + Subject 正确 |
| **逐字节复核** | 把 `/all/` 的 9 封补丁（去掉 cover）拼 mbox → 在 pristine `git am` ⇒ **9/9 干净**，与源分支 `git diff` **空** |
| 复核工具 | `scripts/lore-fetch-raw.py <list|all> <msgid>... -o DIR`（带 Anubis PoW；**Message-ID 不能带尖括号**，否则 pass-challenge 404） |
| 转录件 | `out/mail-20261028/m4-camss-20261028-send.txt`（`out/` 不入库） |

下一步 = 盯 review（`python3 ~/.local/bin/read-mail-ustc.py --days 3 --replies-only`）。
