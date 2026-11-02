# 父会话复核：M6 B5 v2（4 枚，base `6628e7d4c6`）—— **暂不发**

- 复核对象：`reports/m6-b5-v2-20261102.md`、`patches/upstream/m6-b5-v2-20261102/`（4 枚 + cover，未发送）。
- 复核方式：父会话独立重跑（base 真实性、门禁、覆盖性），不采信 worker 自报。

## §0 结论：**门禁 PASS，但续发条件不满足 ⇒ 暂不投**

| 检查 | 结果 | 证据 |
|---|---|---|
| base 真实性 | ✅ `6628e7d4c6` 是**真 Linus commit**（`author/committer Linus Torvalds`，parent = `46fec1c302`，`Linux 7.4-rc1`） | `git -C build/b5-v2 cat-file -p 6628e7d4c6 \| head -8` |
| 补丁几何 | ✅ 4 枚在 base 之上线性（`76ec90f0fd`→`be4425b7c9`→`f38983e7b4`→`57494c1d20`） | `git -C build/b5-v2 log --oneline --graph -5` |
| 净 diff | ✅ 仅 `drivers/gpu/drm/msm/`，6 文件 +653 −6 | `git -C build/b5-v2 diff --stat 6628e7d4c6..HEAD` |
| base 里是否已存在该路径 | ✅ **不存在**：base `dsi_host.c` 中 `BROADCAST` 命中 **0**；`registers/display/dsi.xml` 只有 `BROADCAST_EN` 位域，无 `BROADCAST_MASTER` / 其余命令 DMA 位域 | `git -C build/b5-v2 grep -c BROADCAST 6628e7d4c6 -- …/dsi_host.c` |
| 报告的措辞问题 | ⚠ 报告 §1 写「v7.4-rc1 **删掉**了 10 处寄存器定义」——实际是**本来就没有**（不是被删）。改「补回/重新加回」会在评审里被问「谁删的」 | 同上；base 的 `dsi.xml` 仅 1 处 BROADCAST 命中 |
| **在树内有没有使用者** | ❌ **没有**：v2 四枚只加「per-SoC 配置 + host ops + manager 路由 + peer 拒绝」，**不含任何 DTS**；`cfg->bonded` 只有 DT 声明 bonded 主从后才非空，而 elden 的 bonded DSI 描述在**另一个（P4）系列**里 | `grep -h '^+++ ' 000*.patch \| sort -u`（无 `arch/arm64/boot/dts/**`） |

## §1 为什么必须补这一条才能发

内核评审对「新增一条驱动路径但树内无人使用」的默认回应是「who uses it / 请与使用者一起发」。
Dmitry 已经在 0/5 上质疑过立项理由（「bonded DSI is seemingly working today」）；如果 v2 仍然没有使用者，
这一条质疑会以更强的形式回来。

**二选一（需用户裁决，不是技术选择）**：

- **A（推荐）**：把 P4 的 bonded DSI DTS（`sm8750-lenovo-elden` 的 `qcom,master-dsi` 关系）合成 1 枚
  `arm64: dts: …` 追加进 v2（变 5 枚），cover 用「本板实测：首个 DCS `ff 20` 三连 -22 → 排序 slave-first 后消失」当动机。
  风险：DTS 依赖商人**尚未接受**的绑定形状；需要确认 P4 DTS 只用到 v2 已定义的属性。
- **B**：v2 只发 4 枚驱动，cover **显式声明**「使用者 DTS 单独随 B5-P4 提交」并给出该系列的 msgid。
  风险：可能被要求「合在一起」。

## §2 发送前还要改的三处文本

1. 报告/commit message 里「re-add removed definitions」→ 改成「add the register definitions required by this path
   (they are not present in the current register map)」。
2. `0002` 的 `udelay` CHECK：在 commit message 里留一句「busy-wait is bounded and runs once per command」，别让评审猜。
3. cover 的动机段保留「STATUS0=0x20003 / `ff 20` 三连 -22」这两个可复现观测，但**不要**写「bonded DSI 现在是坏的」——
   Dmitry 的反例（多数板子正常）成立；正确口径是「本板在该路径缺 broadcast 主从语义时会挂起」。

## §3 复跑命令

```bash
cd /home/xuqianhui/y700-elden
git -C build/b5-v2 cat-file -p 6628e7d4c6 | head -6
git -C build/b5-v2 grep -c BROADCAST 6628e7d4c6 -- drivers/gpu/drm/msm/dsi/dsi_host.c
git -C build/b5-v2 diff --stat 6628e7d4c6..HEAD
grep -h '^+++ ' patches/upstream/m6-b5-v2-20261102/000*.patch | sort -u
```
