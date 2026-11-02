# M8 mdss v3 投递记录（2026-11-02 13:50 +0800 / 05:50 UTC，用户已批准本批投递）

## 1. 系列（`git send-email`，4 封 `Result: 250`）

- Subject 根：`[PATCH v3 0/3] drm/msm/mdss: reset all block resets described in DT`
- 新线程（**未挂 v2**，遵守 Mark Brown 11-01 的流程要求）：`send-email.log` 里 cover 无 In-Reply-To，
  1/3–3/3 的 IRT 全部 = cover。
- **To**：`linux-arm-msm@vger.kernel.org`、`dri-devel@lists.freedesktop.org`
- **Cc**：Konrad Dybcio `<konrad.dybcio@oss.qualcomm.com>`、Dmitry Baryshkov
  `<dmitry.baryshkov@oss.qualcomm.com>`、Abhinav Kumar `<abhinav.kumar@linux.dev>`、
  Jessica Zhang `<jesszhan0024@gmail.com>`、Taniya Das `<taniya.das@oss.qualcomm.com>`、
  Bjorn Andersson `<andersson@kernel.org>`、Rob Herring `<robh@kernel.org>`、
  Conor Dooley `<conor+dt@kernel.org>`、Krzysztof Kozlowski `<krzk+dt@kernel.org>`
  （**未用任何 `quic_*@quicinc.com`**）
- **额外 Cc（只 1/3）**：`devicetree@vger.kernel.org` —— 写在 `0001-*.patch` 的
  `Cc:` 头行里，`git send-email` 只对该封生效（dry-run 日志有
  `(mbox) Adding cc: devicetree@vger.kernel.org from line 'Cc: ...'`）。

| # | Subject | Message-ID | lore |
|---|---|---|---|
| 0/3 | cover | `<20261102055026.438521-1-xiaqinghuan@mail.ustc.edu.cn>` | arm-msm ✅ / dri-devel ✅ |
| 1/3 | dt-bindings | `<20261102055026.438521-2-xiaqinghuan@mail.ustc.edu.cn>` | arm-msm ✅ / dri-devel ✅ / linux-devicetree ✅ |
| 2/3 | drm/msm/mdss | `<20261102055026.438521-3-xiaqinghuan@mail.ustc.edu.cn>` | arm-msm ✅ / dri-devel ✅ |
| 3/3 | arm64 dts | `<20261102055026.438521-4-xiaqinghuan@mail.ustc.edu.cn>` | arm-msm ✅ / dri-devel ✅ |

**Cc 落点回读验证**（Sent Items `HEADER.FIELDS (Cc)`，seq 236–239）：`devicetree@vger.kernel.org`
**只出现在 seq 237 = 1/3**，cover/2/3/3/3 的 Cc 里没有；四封 Cc 里**均无任何 `quic_*@quicinc.com`**。
与 lore 侧一致（`linux-devicetree` 只归档了 1/3）。

## 2. 两封短回复（`send-mail-ustc.py`，各 1 封，均 `已发送 OK`）

| 回哪条 | Subject | Message-ID | In-Reply-To | lore |
|---|---|---|---|---|
| Dmitry 对 v2 2/3（要求删长注释） | `Re: [PATCH v2 2/3] ...` | `<179359872904.440020.4978864415299817827@mail.ustc.edu.cn>` | `<odog4t5j3y7j4tatqsiywfj27iufeazkzp3vtfvzce2knct25n@ephs3ngmt2i6>` | arm-msm ✅ / dri-devel ✅ |
| Dmitry 对 v2 3/3（要求 drop RSCC） | `Re: [PATCH v2 3/3] ...` | `<179359872977.440050.668410399098679331@mail.ustc.edu.cn>` | `<dkwloahmxcka2ykjdrf6nh6d6cde6zgd7fe5s763h7s6nv3eqe@pm32d33ghgbb>` | arm-msm ✅ / dri-devel ✅ |

线程复核（`/<list>/<v2 cover>/t/`）：两封都嵌在 Dmitry 10-31 21:47 / 21:48 那两条评论之下
（2026-11-02 05:52），未另起线程。草稿正文 = `out/mail-20261102-mdss/re-dmitry-mdss-v3-*.txt`。

## 3. lore 三态表（2026-11-02 06:0x UTC 逐封核）

判据 = `/<list>/<完整 Message-ID>/raw` 取回 HTTP 200（**不用 `/all/`**，该路径本轮仍然 300）。

| 对象 | linux-arm-msm | dri-devel | linux-devicetree | 正文 sha256 vs 本地 |
|---|---|---|---|---|
| 0/3 | ✅ 8219 B | ✅ 7524 B | — | **一致** `60f53f96e5d17b02` |
| 1/3 | ✅ 7408 B | ✅ 6745 B | ✅ 7387 B | **一致** `4219820ba6433866` |
| 2/3 | ✅ 6924 B | ✅ 6225 B | — | **一致** `cfc43965b2467749` |
| 3/3 | ✅ 6857 B | ✅ 6159 B | — | **一致** `045150c83a33c581` |
| 回 2/3 | ✅ 5508 B | ✅ 4744 B | — | **一致** `d9a1d81dc81db0b8` |
| 回 3/3 | ✅ 5476 B | ✅ 4712 B | — | **一致** `2acc566933224b1d` |

**合计 6 封 / 14 个 (列表, 信件) 归档点全部 200，0 缺。**

> 与 M6 的对照：M6 的 B5 系列当日 `dri-devel` 0/6（疑非订阅者 moderation）。本轮 dri-devel
> **4/4 + 2/2 全部归档**，说明该通道当前正常；不再沿用「dri-devel 会丢」的判断。

## 4. 回读与落盘

- Sent Items 回读（`readback-236..241.txt`，只读 `BODY.PEEK`）：Subject / Message-ID / IRT / 正文逐项核对。
  回读文件 sha256 见 `msgids.txt`。
- 实发件与 msgid 清单：`msgids.txt`；发信日志 `send-email.log`。
- 正文逐字节比对脚本（临时，`/tmp/m8v3-verify.py`）：lore `/raw` 正文 vs 本地文件正文，
  规范化（去尾随空白/空行）后 sha256 相等 = 上表「一致」。

## 5. 未做

- 未改 patchwork 状态（v2 的 4 枚仍为 `new`；标 superseded 需账号，API 403 —— 历史结论）。
- 未上机；v3 形状无真机样本（cover 已明写）。
- 未订阅新列表、未动任何 SSOT 文档。
