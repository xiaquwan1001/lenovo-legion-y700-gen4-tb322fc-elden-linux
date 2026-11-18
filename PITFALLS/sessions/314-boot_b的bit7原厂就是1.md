## #678 `boot_b` 的 bit7 **原厂就是 1**（`0xf3`/`0xfb`），`boot_a` 是 0（`0x77`/`0x7f`）⇒ 「byte6 bit7=1 就是 UNBOOTABLE」只在 **a 槽**成立，判据必须**按槽基线**比

**现象（2026-11-18，核 EDL/GPT 板块审计时定量发现）**：审计子代理报「本机 LUN4 备表 `boot_b=0xf3`，
备表里是 UNBOOTABLE，所以只读主表不安全」。按原厂包逐字节对照后**这条不成立**——
`0xf3` 是**原厂 b 槽的出厂值**，不是 ABL 事后打的失败标志。

### 实测基线（三份独立来源，全部来自官方包/设备 dump）

| 条目 | 原厂 `gpt_main4.bin` | 原厂 `gpt_backup4.bin` | 设备 11-01 dump | 设备 11-17 dump | 解读 |
|---|---|---|---|---|---|
| `boot_a` | **0x77** | 0x77 | 0x72（retry6,active=0） | **0x77** | a 槽：bit7=0，succ=1，retry=6 |
| `boot_b` | **0xf3** | 0xf3 | 0x77（当时 b 在跑） | **0xf3** | **b 槽出厂就带 bit7**，retry=6 |
| `uefi_a` | 0x7f | 0x7f | 0x7b | — | a 槽基线 `0x7f` |
| `uefi_b` | **0xfb** | 0xfb | 0xff | — | b 槽基线 `0xfb`（=0x7b\|0x80） |

⇒ **同槽内 a/b 差 0x80 是 OEM 的「非活动槽」编码**（`slot-attr.py` 头注释里那句
「非 boot 分区 a=0x7x、b=0xFx」其实**也适用于 `boot_*` 的 b 槽**，注释只说了前半句）。

**因此**：
- `boot_a=0xf7` 相对原厂 `0x77` **多了 0x80** ⇒ 这一位大概率是 ABL 打的（#672 的结论在 a 槽成立）。
- `boot_b=0xf3` **等于原厂值** ⇒ 不能读成 UNBOOTABLE。**R1 报告的「备表 boot_b=0xf3 是 UNBOOTABLE」已作废。**

### 判据

```sh
# 只和「同槽原厂基线」比，不要全局套 0x80：
#   a 槽基线 0x77 / b 槽基线 0xf3（retry 会自然递减，允许 0x?? 的 bit3..5 变化）
python3 scripts/slot-attr.py show
# 安全判据 = ① retry>0 ② (slot==a ? bit7==0 : 不按 bit7 判) ③ succ 与实验语义一致
```

- **a 槽实验**：`bit7=1` ⇒ UNBOOTABLE（#672 照旧）。
- **b 槽实验**：不能看 bit7；只能看 `retry`（递减到 0 才是危险）与「ABL 是否回 fastboot」这个行为判据。
- 两个工具的**写入方向也要注意**：`mark-successful b` 会把 `boot_b` 写成 `0x7c` 一类（清掉 bit7），
  与原厂 `0xf3` 不同。是否无害**尚未上机验证** ⇒ 第一次用它的实验要把「改前/改后 + 能否启动」记全，
  必要时用原厂 `gpt_backup4.bin` 的 `boot_b` 条目回填。

**推广**：任何「属性字节 → 布尔语义」的映射，都要先拿**出厂值**（官方线刷包里的 GPT）当基线，
再谈「偏离 = 失败标志」。只拿设备自己两次 dump 对比，无法区分「OEM 编码」与「运行时打的标志」。

证据：`backup/official-rom-15.10.259/gpt_main4.bin`、`gpt_backup4.bin`（原厂）、`backup/HA2EXB0E-16+512/edl-20261118/gpt4-primary.bin`（11-17 设备态）、
`backup/lun4-gpt-20261101/lun4-gpt-primary.bin`、`scripts/slot-attr.py` 头注释（位定义）、`reports/script-audit-edl-20261118.md`。
