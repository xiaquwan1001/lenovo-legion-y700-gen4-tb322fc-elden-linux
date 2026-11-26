# elden 板 DTS v11 备料（**只有 cover/changelog 文本，无 DTS 改动**，未投递）

> 来源裁决：`reports/dts-v10-sashiko-20261126.md` §5（选 (A)：不改 DTS，把拆分计划写进下一版 cover/changelog）。
> 上一代（已投、只读）：`../elden-dts-v10-20261126/`。

## 为什么这个目录里没有 patch

v10 的两条 sashiko `[Medium]`（binding 缺失 / 缺 core boot 节点）**都不产生 DTS 改动**：
① binding 已在 `linux-next next-20261125`（⇒ 7.5 合并窗口进 mainline），基线 `v7.4-rc3` 早于它；
② core 节点是 v6 起就声明的范围外内容，且补它要引入 3 个在飞依赖（双口 USB = dwc3 v16；
`ramoops` = M11；`usb-psy-name`/`qcom,preserve-boot-mappings` 在上游无 binding/是死属性）。

## 文件

| 文件 | 用途 |
|---|---|
| `cover-scope-section.txt` | **可直接粘进 v11 cover 的 `Scope of this series, and what follows` 一节** + 2/2 changelog 两行 + `Waiting on bindings` 的加固一行；末尾「Editor notes」不要粘进信里 |

## 生成 v11 时的动作（等真有下一版的理由再做）

1. 复制 `../elden-dts-v10-20261126/` 的 `v10-0000/0001/0002`、`GATES.md`、`SEND.sh` 到本目录并按代次改名；
2. 把 `cover-scope-section.txt` 的第一段插到 cover 的 `Waiting on bindings` 之上；
3. 在 2/2 的 `Changes in v11:` 下加那段两行 changelog（**diff 段保持与 v10 逐字节相同**）；
4. 门禁只需复跑：`git apply --check`、checkpatch（1/2、2/2）、`dtbs_check`（elden/mtp/qrd）+ 编单 DTB（应仍为
   `50f7cede1d01a45f9c1eb647b4577cc4`，因为内容未变）；`SEND.sh` 的三段断言需把文本改为新 cover 串；
5. 投递仍需 `TASKS/UPSTREAM.md` §7 逐系列放行 + 用户放行，**本目录不含任何发信动作**。

## 纪律

- 本目录**只读地**引用了 v10 目录；未改动 v10、`TASKS/`、`PATCHES/` 任何既有文件。
- 未发信（连 `--dry-run` 都没跑）；未 `git commit`。
