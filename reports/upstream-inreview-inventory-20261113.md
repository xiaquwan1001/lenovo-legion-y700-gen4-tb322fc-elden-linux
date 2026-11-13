# 在审系列清单与分诊盲区（B17，2026-11-13）

> 只读 lane。数据 = patchwork REST（`/api/1.2/patches/?submitter=xiaqinghuan@mail.ustc.edu.cn`，3 页
> 共 **251 条**），现查时刻 2026-11-13 18:5x CST。**未发信、未改 SSOT。**

## §0 结论（数字）

- 251 条中 **live（new/changes-requested/needs-ack/awaiting-upstream）= 58 条**；
  `superseded` 130 / `handled-elsewhere` 60 / `not-applicable` 3。
- **`commit_ref` 非空 = 0 条**（live 集合内逐条打印）。这与 11-12 分诊的「0 已合并」一致，但
  **仍只对 patchwork 侧成立**：本轮没跑 `b4`（本机未安装），也没拉 linux-next / drm-misc-next 全树，
  所以「maintainer 树里是否已悄悄应用」**未验证**（见 §2）。
- 表里同一系列会出现 2–3 行：那是**同系列在不同 project 的镜像**（`linux-arm-msm` / `devicetree` /
  `dri-devel` / `linux-usb` / `linux-input`），不是重复投递。

## §1 在审系列清单（按系列聚合）

| 系列(series id) | 最新日期 | 枚数 | 状态 | commit_ref | patchwork id（代表） |
|---|---|---|---|---|---|
| drm/msm/dpu: add the missing GC block to the SM8750 DSPP cat (1184477) | 2026-10-13 | 1 | new | 0 | 14884141 |
| drm/msm/dpu: reject undersized gamma LUT blobs (1184466) | 2026-10-13 | 1 | new | 0 | 14884121 |
| drm/msm/dsi/phy: program PLL_SYSTEM_MUXES on the first PHY e (1189498) | 2026-10-19 | 1 | new | 0 | 14901898 |
| clk: qcom: dispcc-sm8750: reset the MDSS blocks at probe whe (1191356) | 2026-10-22 | 1 | new | 0 | 14907944 |
| clk: qcom: dispcc-sm8750: reset the MDSS blocks at probe whe (1191359) | 2026-10-22 | 1 | awaiting-upstream | 0 | 14907951 |
| clk: qcom: dispcc-sm8750: reset the MDSS blocks at probe whe (1191865) | 2026-10-22 | 1 | new | 0 | 14909706 |
| irqchip/gic-v3-its: Claim LPI tables inherited across kexec  (1192575) | 2026-10-24 | 1 | new | 0 | 14911943 |
| dt-bindings: usb: snps,dwc3: describe two connectors sharing (1193723) | 2026-10-26 | 1 | changes-requested | 0 | 14915408 |
| dt-bindings: usb: snps,dwc3: describe two connectors sharing (1193720) | 2026-10-26 | 3 | new | 0 | 14915401 |
| dt-bindings: media: i2c: add Giantec GT9764 camera lens actu (1194267) | 2026-10-27 | 2 | changes-requested | 0 | 14917101 |
| dt-bindings: media: i2c: add Giantec GT9764 camera lens actu (1194271) | 2026-10-27 | 2 | new | 0 | 14917111 |
| Input: aw86927 - fix the 7 V boost reference for AW86938 (1194635) | 2026-10-27 | 5 | new | 0 | 14918447 |
| remoteproc: qcom_q6v5_pas: release the DTB firmware after lo (1194634) | 2026-10-27 | 1 | new | 0 | 14918444 |
| dt-bindings: display: msm: mdss-common: describe additional  (1196234) | 2026-10-29 | 1 | changes-requested | 0 | 14924257 |
| arm64: dts: qcom: sm8750: describe all MDSS block resets (1196231) | 2026-10-29 | 1 | new | 0 | 14924250 |
| dt-bindings: display: msm: mdss-common: describe additional  (1196472) | 2026-10-29 | 3 | new | 0 | 14925276 |
| regulator: dt-bindings: willsemi,wl2868c: add the WL2868C ca (1197605) | 2026-10-31 | 3 | new | 0 | 14928864 |
| media: camss: csid: unwind the power-on path through a singl (1197609) | 2026-10-31 | 2 | new | 0 | 14928873 |
| dt-bindings: usb: snps,dwc3: tighten the two-connector share (1197789) | 2026-10-31 | 2 | new | 0 | 14929536 |
| drm/msm/dsi: move bonded command failure flag into dsi manag (1198061) | 2026-10-31 | 5 | new | 0 | 14930241 |
| dt-bindings: usb: snps,dwc3: tighten the two-connector share (1198438) | 2026-11-02 | 1 | new | 0 | 14931311 |
| dt-bindings: usb: snps,dwc3: tighten the two-connector share (1198443) | 2026-11-02 | 1 | changes-requested | 0 | 14931316 |
| dt-bindings: display: msm: mdss-common: describe additional  (1198447) | 2026-11-02 | 3 | new | 0 | 14931320 |
| dt-bindings: usb: snps,dwc3: describe two connectors sharing (1204121) | 2026-11-06 | 1 | changes-requested | 0 | 14957399 |
| dt-bindings: usb: snps,dwc3: describe two connectors sharing (1204116) | 2026-11-06 | 3 | new | 0 | 14957383 |
| arm64: dts: qcom: sm8750: mark the ADSP fastrpc node as non- (1207873) | 2026-11-11 | 1 | new | 0 | 14971025 |
| regulator: dt-bindings: willsemi,wl2868c: add the WL2868C ca (1210271) | 2026-11-13 | 1 | needs-ack | 0 | 14978644 |
| regulator: dt-bindings: willsemi,wl2868c: add the WL2868C ca (1210266) | 2026-11-13 | 2 | new | 0 | 14978635 |
| dt-bindings: display: msm: mdss-common: describe additional  (1210310) | 2026-11-13 | 1 | needs-ack | 0 | 14978817 |
| dt-bindings: display: msm: mdss-common: describe additional  (1210288) | 2026-11-13 | 3 | new | 0 | 14978753 |
| dt-bindings: display: msm: mdss-common: describe additional  (1210293) | 2026-11-13 | 3 | new | 0 | 14978765 |

补充：11-13 当天新投的两批在表内——`wl2868c v11`（series 1210266/1210271，含 1 张 `needs-ack` 的 dt 副本）
与 `mdss v4`（series 1210288/1210293/1210310）。
“commit_ref=0”解释：patchwork 的 `accepted` 状态在我们 251 条里 **0 条**，与 11-12 结论一致。

## §2 盲区状态

| 盲区 | 本轮状态 | 证据 / 卡点 | 下一步 |
|---|---|---|---|
| U1 maintainer 树是否已应用 | **部分**：最便宜的否定证据已取——`gh/master`（7.4-rc3）里 `willsemi,wl2868c`、`awinic,aw86937`、`qcom,sm8750-camss` 的 `git grep -l` 均为 **0** | 三个 grep 是对 `gh/master` 全树 `Documentation drivers` 跑的 | 完整判定需 `b4`（本机无）或拉 `next-2026*` / `drm-misc-next`；下一轮主机侧可跑，属「未完成」 |
| U6 `/covers/` 全量过 comments | **未完成** | 本轮只按 patch 端点取，未遍历 54+ cover | 下一轮用 `/api/1.2/covers/` + `/comments/` 按窗口过 |
| U7 在审清单固化 | **完成（本文件）** | §1 表 | 建议总管把此表指针并入 `TASKS/README.md` §7（本轮不动 SSOT） |

## §3 口径限定（建议写进 TASKS）

> 「0 已合并」= 仅 patchwork `state/commit_ref` 侧；maintainer 树（`next`、`drm-misc-next`、
> `clk-next`、`arm-msm-next`）**未核**。凡引用此数字必须带这句限定。
