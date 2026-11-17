# camss CSIPHY 2.4.0 delta：按 Bryan 要求重基到 on-list kaanapali v25（主机侧，2026-11-17 下午）

> 只读上游 + 本地备料，**零发信、零写盘、零设备操作**。产物 = `patches/upstream/camss-csiphy-24-v2-20261117/`
> （2 枚补丁 + `README.md` + `GATES.md` + `logs/` + cover 草稿）。

## 结论（数字）

1. **v1 的三处前提全部变了**：v25 `[02/15]` 引入 `common_status_offset`（3nm=0x138 / x1e=0xb0）、
   `[03/15]` 已加 `mipi_csi2_dphy_3nm_kaanapali`（**但 `init_seq` 复用 `lane_regs_x1e80100[]`，即 4nm v2.1.2 表**）、
   `[01/15]` 把 binding 的 compatible 改成 `enum{kaanapali,x1e80100}`。
   ⇒ v1 那枚「独立 `const: sm8750`」既会撞 binding 段、也没带新字段，**不可直接投**。
2. **v2 已在「7.4-rc3 + v25 01–03」前缀上重建并过 6 道门**：`git apply --check` rc=0、`checkpatch --strict` **0E/0W/0C**（9 / 163 行）、
   `W=1` 编译 **rc=0 0 warning**、`dt_binding_check` rc=0、表对账 **13/13 差异且与 vendor 103/103 全等**、`git am` **2/2 干净**。
3. **新找到一条能改变评审判断的旁证**：Qualcomm 自己的 SM8750 CAMSS 系列（[v6 4/7]，patchwork `1131656`，
   2026-07-21）把 `sm8750_resources.csiphy_res` 直接指向 `csiphy_res_kaanapali`，其 subject 写 **v2.3.0**；
   而 v2.3.0 与 v2.4.0/2.4.1 的 18 张 2ph 表**逐字节同值**（`reports/camss-csiphy-v6-vs-240-20261113.md` §2.2）
   ⇒ **上游现用的 v2.1.2 值，与 Qualcomm 自己在两处（SM8750 v6、我们 dump 的 2.4.0）的口径都不一致**。
   这条只写进 cover 的提问段（「若 Kaanapali 也是 2.3.0/2.4.0，本系列可压成 1 枚只改 `init_seq`」），
   **不替 Kaanapali 下结论**（无该机型可测）。
4. **仍未做上机出流回归**（本 lane 静态门禁），`GATES.md` 第 ⑦ 项显式记 ❌ ⇒ 投标前必须补，或在 cover 声明「无实测」（需用户裁决）。

## 与上游的对齐关系（谁在飞、谁已合）

| 线上工作 | 状态（2026-11-17 现查） | 与本系列关系 |
|---|---|---|
| kaanapali v25（`series/33877`，Hangxiang） | **15 枚在评审**（2026-11-13） | **本系列的前缀**；`[03/15]` 的表选择是本系列要补的缺口 |
| SM8750 CAMSS v6（`series/1131656`，Hangxiang） | 7 枚，2026-07-21，**未合**（`v6 1/7` 的 binding 形状 = 本系列 `0001`） | 若它先进树，本系列 `0001` 可删 |
| 我方 RFC（2026-11-15，`<179472053649.14538…>`） | Bryan 11-15 回信要求「先基于 on-list」 | 本系列即回应该要求 |

⚠️ binding 段两者改**同一处**：本系列 `0001` 与 v6 `1/7` 的 `items: [sm8750, kaanapali]` **逐字相同**
⇒ 投递前必须再看一次 v6 是否已进 tree（进则删本系列 `0001`，只发驱动一枚）。

## 复现（全部命令与原始输出）

见 `patches/upstream/camss-csiphy-24-v2-20261117/GATES.md`（含基线限制说明：7.4-rc3 整树导不出，
被改的 4 个文件用的是 `aebb727447` 的 blob 原文）。

## 未做 / 边界

- 未发任何邮件；`cover-draft.txt` 只备料（含 AI 辅助披露段，按 `AGENTS.md` 上游发信三件套）。
- 未上机（设备当前在 fastboot、电量 3.425 V，见 `DEVICE/README.md` §1.1 现态）。
- 门禁 ③ 不是「整棵 7.4-rc3 编译」，只覆盖本系列改动的 4 个文件（原因同上）。

收尾: v1 delta 已按 Bryan 要求重基到 kaanapali v25 前缀并重建为 2 枚（6 道门全绿 + 新增 Qualcomm 自身 v2.3.0 旁证），产物与 cover 草稿在档，等用户放行 + 一次上机出流回归。
