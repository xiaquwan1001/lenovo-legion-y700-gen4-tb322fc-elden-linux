# camss CSIPHY 2.4.0 v2 —— SENT 前一步（2026-11-18 复核，**仍不发送**）

> 本轮只做 A3：① 查 SM8750 CAMSS v6 `1/7` 与 Kaanapali v25 是否已进 tree
> （决定本系列 `0001` 是删还是留）；② cover 定稿；③ 复跑便宜门。
> **未发信、未改上游树、未碰设备。**

## 1. 树查结论（2026-11-18，两个独立来源）

| 判定对象 | 判据 | 结果 |
|---|---|---|
| `Documentation/devicetree/bindings/phy/qcom,x1e80100-csi2-phy.yaml` @ torvalds master | cgit `plain/` 现取（2026-11-18 10:2x CST，213 行） | `grep -n 'sm8750\|kaanapali'` = **0 命中**；compatible 仍只有 `x1e80100` + `glymur` |
| `drivers/phy/qualcomm/phy-qcom-mipi-csi2.c` @ torvalds master | 同上 | `grep -n 'kaanapali\|sm8750'` = **0 命中**（连 Kaanapali 都还没进） |
| SM8750 CAMSS v6 `[1/7]`（patchwork `14700821`） | `GET /api/1.2/patches/14700821/` | `state=new`，`archived=False`，**`commit_ref=None`** ⇒ 未合 |
| Kaanapali v25 系列（linuxtv patchwork `series/33877`） | `GET /api/1.2/series/33877/` + 首枚 `patches/170944/` | 15 枚，2026-11-13，首枚 `state=under-review`、`commit_ref=None` ⇒ **前缀仍不在 tree** |

**决定**：`0001`（binding，加 `items: [sm8750, kaanapali]`）**保留**——它依赖的
`qcom,kaanapali-csi2-phy` 本身都还没进 master，v6 `1/7` 也没合；此时删 `0001`
会让驱动枚引用一个 tree 里不存在的 compatible 回退对。

**但**：`0002` 的 `.compatible = "qcom,sm8750-csi2-phy"` 在 vanilla master 上
无 binding 描述、`0001` 也只能落在 v25 前缀之后 ⇒ 投递时必须写明
「apply on top of Kaanapali v25」，**cover 已含该段**（`0000-cover-letter.patch`
第 2 段）。若维护者先合 Kaanapali，本系列可原样跟发；若 v6 先合，则删 `0001`
并把 `0002` 的 `Fitz:`/口径对齐 v6（届时重做一次树查）。

## 2. 本轮复跑的门（前缀夹具 `/tmp/csiphy2/git`，prefix 提交 `86e8cec`）

| 门 | 命令 | 结果 |
|---|---|---|
| `git apply --check` | `git checkout 86e8cec && git apply --check -v 0001 0002` | **rc=0**（4 个文件逐个 OK） |
| diffstat | `git apply --numstat` | `3+137+1+1 = 142 insertions / 4 files`（与 cover 短统计一致） |
| `checkpatch --strict` | `perl <7.4-rc3>/scripts/checkpatch.pl --strict --no-signoff --no-tree /abs/path/000N-*.patch` | 0001 = **0E/0W/0C（9 行）**；0002 = **0E/0W/0C（163 行）** |

**踩到的坑（下轮别再误判）**：checkpatch 传**相对路径**时会把整枚 patch 当普通文件处理
（`lines checked` 变成文件总行数），于是 `-- ` 签名行的尾随空格被报成
`ERROR: trailing whitespace`；同一脚本同一文件传**绝对路径**即 0E/0W/0C。
判据 = `total: … 9 lines checked`（对）vs `34 lines checked`（错）。

## 3. 投递参数（备好，等放行）

- 收件人沿用 RFC 线程：`bod@kernel.org`（Bryan O'Donoghue，binding 的 maintainer）、
  `vkoul@kernel.org`、`linux-phy@lists.infradead.org`、`linux-arm-msm@vger.kernel.org`、
  `devicetree@vger.kernel.org`、`linux-kernel@vger.kernel.org`
  （**发信前按 MAINTAINERS 现查一次**，本轮未查）。
- `--in-reply-to '<179472053649.14538.1565870277822789081@mail.ustc.edu.cn>'`
  （我方 RFC v1，2026-11-15 05:29 UTC）——Bryan 的答复
  `<57ea8341-4685-4b50-9072-cceab6fc1623@kernel.org>` 在该线程内。
- 发送顺序：**建议等 Kaanapali v25 进树再发**（否则要请维护者先应用前缀）；
  若用户要求现在发，cover 已明写依赖 + 无实测，按此发即可。
- 发信后补 `SENT.md`（MID + lore 复核），改 `TASKS` §7 `media: camss` 行。

## 4. 仍缺（如实）

- **⑦ 上机出流回归 = ❌**（`GATES.md` 第 ⑦ 项）：设备不在线，未测 30 fps / 未出帧。
  cover 已声明 "No hardware testing"。
- ③ `W=1` 编译与 ④ `dt_binding_check` 本轮未复跑（前缀夹具未变、轮次优先级让位给
  haptics v3 / dwc3 v10 复核），沿用 2026-11-17 的 **rc=0 / rc=0** 记录。
