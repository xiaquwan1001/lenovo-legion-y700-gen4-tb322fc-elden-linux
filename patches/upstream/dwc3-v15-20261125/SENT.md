# dwc3 v15 投递记录（2026-11-25T08:12Z，4 封全 `Result: 250`）

## 首发

| 项 | 值 |
|---|---|
| 通道 | USTC smtp（`SEND.sh --send` → `git send-email`），日志 `logs/sent-20261125-161219.txt` |
| cover MID | `<20261125081219.3661014-1-xiaqinghuan@mail.ustc.edu.cn>` |
| patch MID | `-2-` / `-3-` / `-4-`（同前缀） |
| 收件人 | To `Thinh.Nguyen@synopsys.com`；Cc `gregkh@linuxfoundation.org`, **`linux-usb@vger.kernel.org`**（v12–v14 缺的就是它）, `robh@`, `krzk+dt@`, `conor+dt@`, `devicetree@`, `linux-arm-msm@`, `linux-kernel@` |
| 线程 | **新线程**（无 `In-Reply-To`/`References`；cover 正文说明 v14 被发了两次、v15 同时取代两批） |
| 内容 | 1/3、2/3、3/3 与 v14 **diff 段 `cmp` 逐字节相同**（`git patch-id` = `aa6ed734239b` / `5688adec43ea` / `60721b9fb7fb`），只有 cover 是新的 |
| Greg 两条要求 | ① 真机测过 → cover 的 `Testing on hardware` 段（g7a2 vs 日常核同轮对照，`reports/g7-routeA-dtfix-20261123.md` §8）；② 补 `linux-usb` → 已在 Cc |

## lore 复核（独立于投递日志）

- `linux-usb`：**✅ 已归档**，线程 4 封全在
  <https://lore.kernel.org/linux-usb/20261125081219.3661014-1-xiaqinghuan@mail.ustc.edu.cn/>
  （thread overview 列出 0/3 与 1/3–3/3 四封，2026-11-25 08:12 UTC）。
- `linux-devicetree` / patchwork：摄取滞后属常态（见 `TASKS/README.md` §7 头「归档复核口径」）；
  复核判据 = 稍后按同一 MID 查 `/linux-devicetree/` 与 patchwork `q=`，**不以 `state` 字段下结论**。

## 投前独立复核（父代理自己跑，不采信子代理自报）

- 三枚 patch 的 `diff --git` 段与 v14 `cmp` 相同（逐枚）。
- `checkpatch.pl --no-tree --strict --no-signoff - < file.patch`：**0E/0W/0C**（116 / 63 / 624 行）
  ——注意必须**喂 stdin**，直接传文件路径会被当源码解析、报 4 条假 `trailing whitespace`（PITFALLS #725）。
- 在 `aebb727447`（v7.4-rc3）干净 worktree 上 `git apply --check` 3/3 通过。

## 已知遗留（写进 cover，不在本系列解决）

1. 两个 Type-C 口的**物理换口**未做（需人插拔）⇒ mux state 随插拔翻转无样本，只有 GPIO29 电平代理判据。
2. `gpio-mux` probe 用 `GPIOD_OUT_LOW`，不保留固件留下的电平；`GPIOD_ASIS` 属 `drivers/mux/gpio.c` 的独立议题。
3. v14 的 cover 自述「每枚 patch 都带 AI 披露」而实际没有 ⇒ v15 在 cover 里如实记账（`Changes since v14` 第 3 条），
   待下一次动 1/3–3/3 时补回。

## 下一步（收到回信后）

- Greg/Krzysztof/Rob/Conor/Thinh 任一回信 → 按条回应，不遗漏；改动落到 v16。
- 若被要求「先有板 DTS 再谈」，回答口径 = 板件系列独立投递，见 `TASKS/README.md` §7 M3-DTS 行
  （⚠ 该行 2026-11-25 已被重复性核查改写：Pengyu Luo 已投同一板文件，需先对齐身份）。
