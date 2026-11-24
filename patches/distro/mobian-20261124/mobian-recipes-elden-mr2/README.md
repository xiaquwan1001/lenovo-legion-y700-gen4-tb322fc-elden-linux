# Mobian MR-2 备料包：mobian-recipes elden 配方（不投、不推）

> 2026-11-24，D2②。零发信 / 零 push / 零 commit / 零设备 / 零编译。
> 本包 = 「mobian-recipes 的 elden 配方补齐」最小增量（11-23 审计 B 报告 §② 三候选均不能
> 在「无上游新回复」前提下自足完成，判定见 §3），是候选 2 的全部主机侧可做部分。

## 0. 产物

| 文件 | 是什么 |
|---|---|
| `wip.toml.append` | 追加到上游 `devices/qcom/configs/wip.toml` 末尾的 `[[device]]` 片段 |
| `upstream-wip.toml@20261124` | 上游 wip.toml 原文快照（salsa master，2026-11-24 取，仍是空模板） |
| `wip.toml.merged.preview` | 上游快照 + 片段的合并预览（仅供门禁与投递前 diff，不直接投） |
| `droid-juicer/lenovo,elden.toml` | 与 !46 当前内容（ea9fe3d5，2026-11-23T19:10 更新的英文版）**逐字节一致**的副本 |
| `gate.sh` | 本地静态门（tomllib / 结构判据 / 一致性 / `bash -n`），5 项全绿 |

## 1. 为什么是这件

- **!46 内容分叉已闭合**（本轮现查）：`mobian1/droid-juicer !46` 于 2026-11-23T19:10 被
  force-push 为英文版（sha `ea9fe3d5` ← `2dead7cc`），与 `patches/distro/mobian-20261123/`
  的英文成品逐字节一致（G4 门证）。候选 1 剩下的动作只有「等维护者回复 / 礼貌评论」，
  评论属发信需用户逐次放行 ⇒ 候选 1 无剩余主机侧工作。
- 候选 2（recipes MR-2）是价值最高件，其中**两个 TOML 件**（wip 片段 + droid-juicer 副本）
  完全主机侧可做、可冻结成「内核 deb 一到即可投」的成品包。
- 候选 3 依赖主线 DTS（patchwork 14991580 v7 零回复）+ LTS 收口，不动。

## 2. 上游判据（为何字段长这样）

| 判据 | 出处 |
|---|---|
| `chipset = "sm8750"` 必须写在 `[[device]]` | 上游 wip.toml 顶层 `chipset = ""`，jq 空串真值 ⇒ `DEVICE_SOC=""` ⇒ DTB 路径 `qcom/-lenovo-elden.dtb`（`bootloader.sh:46,54`）；11-22 报告结论 #3 |
| 不写 `version`/`dtb`/`append`/`bootimg` 覆盖 | 不带 dtb 字段走 `cat vmlinuz dtb > kernel` + v0 header（`bootloader.sh:84,88`），= 全部 wip qcom 设备默认；append 由 `bootloader.sh:59,90-92` 自拼；11-22 结论 #4 |
| droid-juicer 副本 = !46 当前英文版 | MR-2 同批件之一（`packages-base.yaml:35-37` 把 `devices/qcom/droid-juicer/` 覆盖进 `/usr/share/droid-juicer/configs`） |
| config 内无 ADSP/CDSP `.mdt` 条目 | droid-juicer 把 `.mdt` squash 成单 `.mbn`（`firmware.rs:305-308`），单文件 `cdsp_dtb.mbn` 本机被 TZ 拒；split 件走 `elden-firmware` 包（11-22 结论 #6） |

## 3. 三候选为何均被拒（自足性判定）

| 候选 | 缺口 |
|---|---|
| 1（!46 跟进定稿） | 内容定稿已由上游 MR 更新闭合；剩余 = 维护者回复（外部）或评论（发信，需放行） |
| 2（recipes MR-2 全件） | 缺 `devices/qcom/packages/linux-image-*-sm8750.deb`（内核源树版本账 src_missing 75 行 WARN），没有 deb 提交即 CI 红 |
| 3（一等公民化） | 依赖主线 DTS 进树 + LTS/staging 路线收口 |

## 4. 放行后怎么投

- 仓：`salsa.debian.org/Mobian-team/mobian-recipes`，目标分支 `master`。
- 分支名建议：`devices/qcom-elden-wip`（或沿用我方 fork 命名习惯）。
- 内容：本包 `wip.toml.append` 追加到 `devices/qcom/configs/wip.toml` 末尾 +
  `droid-juicer/lenovo,elden.toml` 放 `devices/qcom/droid-juicer/`。
- **TOML 字段**：无需改动 —— `[[device]]` 仅 `vendor/model/chipset` 三键；`[bootimg]` 段
  不动（与本机实测头逐字段相同，11-22 §1.2）。
- **前置（硬）**：`devices/qcom/packages/linux-image-<ver>-sm8750.deb`（等 D2 内核版本账
  收口 + 内核分支工件产出）。没有它**不投**（提交即 CI 红）。
- MR 描述：复用 11-22 报告 §2.4 九条自检 + AI 披露；说明 sns_reg_config（vendor vs odm）
  与 ath12k 目录名（dmesg）两个未上机项。

## 5. 静态门（可独立重跑）

```bash
cd patches/distro/mobian-20261124/mobian-recipes-elden-mr2 && bash gate.sh
```

5 项：G1 片段 tomllib+字段判据 / G2 合并预览 tomllib+末位 device=elden /
G3 droid-juicer schema+8 条 firmware+ADSP/CDSP 排除 / G4 与 11-23 定稿字节一致 /
G5 `bash -n` 自身。全绿 rc=0。
