# wl2868c v11（2026-11-13，**已发送**）

- 触发：Mark Brown 对 v10 2/2 的回信（`<27362144>` / lore
  `<20261111111132.1296892-3-xiaqinghuan@mail.ustc.edu.cn>` 的 reply）：
  > Should the driver not also override the LDOx_SEQ registers to make sure we have
  > software control of them, or hide the enable/disable ops if they're non-zero?
- 处置（取第一条）：probe 时把 `0x0a..0x0d`（LDOx_SEQ[3:0]）清零，再读 `0x0e` 播种。
  依据 = datasheet **WL2868C Rev 1.4（2022-04）p.35**「0x0A, 0x0B, 0x0C and 0x0D:
  LDOx_SEQ[3:0]」：`0000`（复位值）= 由 `0x0E` 的 LDOx_EN 控制；`x001..x111` = 由
  sequencer 的 slot 控制，此时写 LDOx_EN 无效。binding 不描述时序 ⇒ 只能清零，
  否则 enable()/disable() 对其静默无效；隐藏 ops 会让软件最需要控制的板子失去控制。
- 板上实测（回信证据，只读）：`0x0a..0x0d = 00 00 00 00`、`0x0e = 0x80`、
  `0x0f = 0x00` ⇒ 本板固件没启用 sequencer，清零是 no-op；原文
  `reports/artifacts/wl2868c-seq-20261113/read.txt`。
- 文件：`v11-0000-cover-letter.patch`（AI 披露 + Mark 原文引用 + datasheet 引用 + 读数）、
  `v11-0001`（binding，与 v10 逐字节相同）、`v11-0002`（driver：+21 行，清 SEQ 槽位）。
- 门禁：`GATES.md`（am 干净 / checkpatch --strict 0E0W0C ×2 / W=1 0 warning /
  dt_binding_check rc=0）。
- 投递：`out/mail-20261113/send-wl2868c-v11.log`（3 × `Result: 250`，新线程、`--thread`）。
- 投后：lore 三封均已归档；1/2、2/2 raw 在 pristine `git am` 后与源树 5 个文件 blob
  **全 SAME**（逐字节一致）。

## Message-ID

| # | Message-ID |
|---|---|
| 0/2 | `<cover.1794557667.git.xiaqinghuan@mail.ustc.edu.cn>` |
| 1/2 | `<9ab5e5937264bb408be43986acb8553464e44a49.1794557667.git.xiaqinghuan@mail.ustc.edu.cn>` |
| 2/2 | `<4ad69e8cfdef799d2f33ce1fdd43e539a2f515f5.1794557667.git.xiaqinghuan@mail.ustc.edu.cn>` |

## 相对 v10

唯一差异 = `wl2868c_probe()` 里新增 8 行（宏 + `regmap_bulk_write()` 清零）与其注释；
binding 未动。v10 的 changelog（sashiko 3 Medium + 2 Low）继续有效，cover 里已声明。
