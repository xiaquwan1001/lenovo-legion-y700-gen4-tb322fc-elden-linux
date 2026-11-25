# dwc3 v15 投递前 CHECKLIST（2026-11-25，主机侧静态备料）

> 本文件每一条都是**本轮现跑**的结果，命令在条目里给出，可原样复现。未做项显式标 ❌/⏸。
> 基准目录：`patches/upstream/`（`V14=dwc3-v14-20261124`、`V15=dwc3-v15-20261125`）。

## 0. 件与内容

- [x] **件数/编号**：`v15-0000-cover-letter.patch` + `v15-0001`、`v15-0002`、`v15-0003`，共 4 件，编号连续。
- [x] **patch 内容 = v14（硬约束 1）**
  ```
  for n in 1 2 3; do
    awk '/^diff --git/{f=1} f' $V14/v14-000$n-*.patch > /tmp/a; awk '/^diff --git/{f=1} f' $V15/v15-000$n-*.patch > /tmp/b
    cmp /tmp/a /tmp/b; git patch-id --stable < $V14/…; git patch-id --stable < $V15/…
  done
  ```
  | patch | `cmp` diff 段 | diff 段 sha256（前 16） | `git patch-id --stable` |
  |---|---|---|---|
  | 1/3 | **相同** | `b7c8e48bd0883b20` | `aa6ed734239b40469b3f412f7dff910585a6880c`（v14 = v15） |
  | 2/3 | **相同** | `daa8e9365529164f` | `5688adec43eaaf40467ab0093e3be3d39e561a22`（v14 = v15） |
  | 3/3 | **相同** | `83eae25253cffc12` | `60721b9fb7fb2777b8707c7b045f5d3011807434`（v14 = v15） |
- [x] **文件级差异只限两个头部行**（不做整文件 `cmp` 的原因；`diff -u v14 v15` 的输出只有这两行）
  ```
  -Date: Tue, 24 Nov 2026 07:30:17 +0800
  +Date: Wed, 25 Nov 2026 16:00:00 +0800
  -Subject: [PATCH v14 n/3] …
  +Subject: [PATCH v15 n/3] …
  ```
  `From:`、commit message、`Signed-off-by:`、tearline 之后的 changelog/diffstat、diff 段**全部未变**。
  Date 同步到 v15 的投递日，避免 cover（11-25）比 1..3（11-24）新而在线程/归档里倒序。

## 1. blob（落树后每个文件的内容哈希）

- [x] **在干净基线上重跑 apply**：`git -C build/elden-tree worktree add --detach /tmp/dwc3-v15-verify aebb727447`
      → `git apply --check` + `git apply` ×3，**3/3 rc=0，无 offset/fuzz**；验证后 `worktree remove --force`（已删）。
- [x] **后像 blob = patch `index` 行右值**

  | 文件 | patch `index` 右值 | 落树 `git hash-object` | 一致 |
  |---|---|---|---|
  | `Documentation/devicetree/bindings/usb/snps,dwc3-common.yaml` | `dcfa8c3a81c5` | `dcfa8c3a81c5` | ✅ |
  | `drivers/usb/roles/class.c` | `ee186d542a10` | `ee186d542a10` | ✅ |
  | `drivers/usb/dwc3/core.c` | `ce309792864b` | `ce309792864b` | ✅ |
  | `drivers/usb/dwc3/core.h` | `e6cf7b240b23` | `e6cf7b240b23` | ✅ |
  | `drivers/usb/dwc3/debugfs.c` | `82e7a334b135` | `82e7a334b135` | ✅ |
  | `drivers/usb/dwc3/drd.c` | `906cac4f3e6e` | `906cac4f3e6e` | ✅ |

- [x] **前像 blob = 基线 `aebb727447`**：六枚全部与 patch `index` 行左值相同
      （`6c0b8b653824` / `edec139b68b5` / `372737f4750b` / `f3dabb37f806` / `01ebd73198e0` / `f3e37d383627`）。
- [x] **与 v14 cover 的 G1 记账对账**：v14 cover 写的 `snps,dwc3-common.yaml = 7a9cb5a115a6` 是 **v12/v13 的值**
      （与 v14 自己的 `index` 行、与 `GATES-v14.md` 的 `dcfa8c3a81c5` 都不符）⇒ v15 cover 的 G1 写实测 `dcfa8c3a81c5`。
      这是 v14 的 cover 文本缺陷，**未改 patch**。

## 2. cover：新线程 + 内容

- [x] `Subject: [PATCH v15 0/3] usb: dwc3: support two connectors sharing one HS data bus`（fold 在第 78 列，同 v14 形态）。
- [x] **新线程**：`grep -E '^(In-Reply-To|References):' v15-0000-cover-letter.patch` **零命中**；
      `SEND.sh` 第 3 步再查一遍（命令不带 `--in-reply-to`）。
- [x] **首段写清「同内容 + 只因 Greg 两条要求重发 + 引原话与日期」**：正文第 1 段即
      「This is the v14 series again, unchanged… Greg Kroah-Hartman asked for exactly two things when he replied
      to v14 on 2026-11-24:」+ 缩进引文 `Please test on real hardware before resending, AND also cc: the proper
      mailing lists (you forgot the usb list).`（MID `<2026112405-sniff-untying-8990@gregkh>`）。
- [x] **`Testing on hardware` 段：数据只取 `reports/g7-routeA-dtfix-20261123.md` §8**，逐条带数字与出处判据：
      两个 role switch `waiting_for_supplier=0`；`/sys/class/mux` 基线空 / 候选 `muxchip0`；
      `/sys/class/udc` 有 `a600000.usb` 且 HS gadget 在 connector 0 枚举；
      `Failed to create device link` **7 ≤ 基线 8**（并写明少的那条是 `msm_dsi ↔ panel@0`，7 条 = pmic_glink 族）；
      `Fixed dependency cycle(s)` 137 vs 141（允许的 `FWLINK_FLAG_CYCLE`）；Type-C port0/port1 形态；
      以及「非 USB」的显示栈 WARN 58 / call trace 55（该件无显示 bring-up）。
- [x] **显式写未覆盖项**：`Not tested, stated so that nobody has to guess` 段 =
      两连接器**物理换口未做**（需人插拔）⇒ 无 mux state 跟随插拔的样本；`/sys/class/mux` 与
      `/sys/kernel/debug/mux` 都不暴露 state ⇒ 只有 **GPIO29 电平代理判据**（connector 0 活跃 + gadget 在跑时 `out low`），翻转未观测。
- [x] **AI 披露与 changelog 全在 `---` 之下**：`grep -n '^---$'` = 行 99；
      `AI-assistance disclosure`@100、`Changes since v14`@106、`since v13`@135、`since v11`@155、`since v10`@190、
      `Changes in earlier versions`@225 —— 全部 > 99。`SEND.sh` 第 4 步逐条断言。
- [x] **changelog 覆盖历代**（Greg 2026-11-23 的要求）：v15 新增 `Changes since v14`（3 条）+ 保留 v13/v11/v10/v4-v9 全部。
- [x] **v14 遗留缺陷不复制**：v15 cover **不再声称**「each patch carries its disclosure below `---`」，
      改为 series 级披露 + `Changes since v14` 第 3 条写明「v14 重出时掉了 per-patch 披露段」的现状。
- [x] **纯 ASCII**：`LC_ALL=C grep -P '[^\x00-\x7f]' v15-000*.patch` 零命中。

## 3. 收件人

- [x] **含 `linux-usb@vger.kernel.org`**（Greg 2026-11-24 第二条；v12/v13/v14 三代都缺，v11 之后该列表零我方 v 系列）
      —— `SEND.sh` 里 `CC="gregkh@…,linux-usb@vger.kernel.org,robh…,krzk+dt…,conor+dt…,devicetree…,linux-arm-msm…,linux-kernel…"`
- [x] **dry-run 收件人实证**：4 封每封 9 个 `RCPT TO`，每封都含 `RCPT TO:<linux-usb@vger.kernel.org>`
      （日志 `logs/dry-run-20261125-160404.txt`；`SEND.sh` 第 7 步会断言，缺了直接 exit 1）。

## 4. 机械门（本轮现跑）

- [x] `git mailinfo` 逐封解析 4/4 OK（`SEND.sh` 第 5 步）。
- [x] `git send-email --dry-run`：**4 封全 `Result: OK`**，`smtpserver=smtp.ustc.edu.cn` / `smtpuser=xiaqinghuan@mail.ustc.edu.cn`
      （日志 `logs/dry-run-20261125-160404.txt`）。**注意：dry-run 不发报文数据**，`Message-ID` 也是本次 dry-run 现生成的，
      与真发件不同（技能 `upstream-mail-ustc` 坑 10 同源）。
- [x] `git worktree list` 无本目录残留（验证用 worktree 已删）。

## 5. 未做（显式）

- ⏸ **真发**：本轮禁止；放行后 `bash SEND.sh --send`。
- ⏸ **SENT.md**：真发后按 cover MID 记 4 封 Result + lore 两处（`/linux-usb/`、`/linux-devicetree/`）命中清单。
- ⏸ **checkpatch / dt_binding_check / dtbs_check / W=1 编译**：**未重跑**，理由 = patch 内容与 v14 逐字节相同
      （`cmp` + `patch-id` 已证），v14 的门禁结论原样适用（`GATES-v14.md`）。v15 cover 的 G2–G6 写的是「v14 现跑值，未重跑」。
- ❌ **两连接器物理换口 / mux 翻转样本**：需人插拔线缆，主机侧无法补；cover 已把它写成未覆盖项。
