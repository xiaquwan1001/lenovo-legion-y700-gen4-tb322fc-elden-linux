# elden 板 DTS v10 —— 已投（2026-11-26T05:20:57Z = CST 13:20:57）

| 项 | 值 |
|---|---|
| 线程形态 | **新线程**（cover 无 `In-Reply-To`/`References`） |
| 收件人 | To `andersson@kernel.org`（Bjorn）；Cc `linux-arm-msm`/`linux-devicetree`/`conor+dt`/`krzk+dt`/`robh`/`abelvesa`/`lkml` 等（沿用 v9 `get_maintainer.pl --no-rolestats` 结果，SEND.sh 未重查） |
| Message-ID | cover `<20261126052057.1544590-1-xiaqinghuan@mail.ustc.edu.cn>` · 1/2 `<…-2-…>` · 2/2 `<…-3-…>` |
| 结果 | **3 封全 `Result: 250`**（`send-email rc=0`，日志 `logs/sent-20261126-132057.txt`） |
| 本代改动 | 只动 **2/2**：`pmic@2f` 加 `vin12/vin34/vin5/vin7-supply`（同指 `&wl2868c_vsys` placeholder）+ 注释改写为显式 stand-in；**1/2 只补 `Acked-by: Krzysztof Kozlowski`（v8 1/2 上给的，v9 漏带）与代次**，diff 段与 v9 逐字节相同 |
| 门禁（投前，父代理复跑） | `git apply` 2/2 干净、136 行完整（曾抓到 hunk 计数 135≠136 会吃掉末尾 `};`，已修）；checkpatch 1/2 `0E/0W/0C`、2/2 `0E/1W/0C`（MAINTAINERS 提示）；只重编 elden DTB = `50f7cede1d01a45f9c1eb647b4577cc4`（与修订前逐字节相同 ⇒ 纯注释改动）；`SEND.sh --dry-run` OK |
| lore 复核 | **✅ 已归档两处**（父代理 web_fetch 复核 3/3 封）：`/linux-arm-msm/` 与 `/linux-devicetree/`（cover 05:21:01Z、1/2 05:21:02Z、2/2 05:21:05Z；1/2 含 `Acked-by`、2/2 含四条 `vin*-supply` 与 stand-in 措辞） |

## 回应关系（本版答谁）

- **sashiko 对 v9 2/2 的 3×`[Medium]`**：① `wl2868c` binding 不在目标树 → cover `Waiting on bindings` 专节点名 `84e67d2ee13f`/`602f57223457` 与合并顺序；② 缺板级 boot/power 节点 → cover「Not included, and not claimed to work」；③ **`vin*-supply`（新增）→ 本版修**（`Changes in v10` 逐条）。
- **Krzysztof 对 v8 1/2 的 `Acked-by`**：本版带进补丁体（v9 漏了）。
- **Krzysztof 对 v8 2/2 的意见**（changelog/cover 要明写 waiting on bindings）：v9 已落实，本版沿用。

## 下一步

1. ~~lore 归档命中后回填~~ **已完成（2026-11-26T05:2xZ，两处 inbox 3/3 命中）**。
2. patchwork 摄取可能滞后数十小时 ⇒ **lore 为准**。
3. 盯 sashiko 对新 `vin*-supply` 的回评：若被指「指向 placeholder 不可接受」，改法 = 等 SPMI PMIC 描述进树后改指（cover 已写明这一点）。

## ⚠ 投出后发现的措辞不一致（如实记账，待 reviewer 触发时按此回答）

- **cover.txt 仍保留了那条推断**：「the four LDO inputs and the VSYS pin of this chip are fed from the tablet's always-on system rail … That is not a shortcut」。
  父代理只改了**提交信息与 DTS 注释**（改为显式 stand-in），**未同步 cover**，而 cover 已随信发出。
  ⇒ 若被问「你怎么知道同一条轨」：如实回答「**没有原理图/datasheet，这是建模假设**；DTS 注释与提交信息里已写明 stand-in，
  等 SPMI PMIC 描述进树后一次性改指」；不要声称测过。
- cover 的 `Checks` 段写「checkpatch 1/2 and 2/2 both 0 errors 0 warnings 0 checks」，实际 **2/2 = 0E/1W/0C**
  （新文件 MAINTAINERS 提示，v7–v9 同款）。以 `GATES.md` §12.3 的逐条值为准。
