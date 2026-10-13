---
name: upstream-mail-ustc
description: "给上游内核列表发补丁/报告（USTC 邮箱通道）并在 lore 复核投递。触发词：发上游邮件、git send-email 配置、补丁有没有进归档、lore 查不到、QQ/Outlook 发不出去、Message-ID 被改写、vger 订阅。"
---

# 上游邮件：USTC 通道发送 + lore 复核

给 linux-arm-msm / linux-clk / LKML / devicetree / regressions 发补丁或回归报告，并**独立验证真的进了归档**。
通道三选一的实测结论与全部坑见项目 `PITFALLS.md` §二十七。

## 何时用

- 要把 patch / 回归报告发到内核邮件列表。
- 怀疑"发出去了但列表没收到"（lore 查不到、没有回信）。

## 通道事实（2026-10-12 实测，别重试另外两条）

| 通道 | 结论 |
|---|---|
| outlook.com | ❌ basic auth 被账号级禁用（IMAP 直接回 `Basic authentication is disabled.`），应用密码无用 |
| smtp.qq.com:465 | ⚠️ 能发，但**腾讯把 Message-ID 换成 `<tencent_…@qq.com>`** ⇒ 补丁串线程断；仅限单封 |
| **smtp.ustc.edu.cn:465** | ✅ **Message-ID 逐字保真**、线程自洽、正文可逐字节校验 |

## 步骤

### 1) 报告类（纯文本，无补丁）

邮件写成文件：首部 `To:`/`Cc:`/`Subject:`，**空行后正文**（必须纯 ASCII）。

```bash
python3 ~/.local/bin/send-mail-ustc.py <file>          # dry-run：核对头/行数/非 ASCII
python3 ~/.local/bin/send-mail-ustc.py <file> --send   # 真发
```

### 2) 补丁 / 补丁串

```bash
git format-patch -N --cover-letter -o out/
git send-email --annotate --to=<list> --cc=<maintainers> out/*.patch
```

配置在 `~/.gitconfig`（`sendemail.smtpServer=smtp.ustc.edu.cn`、465/ssl、`smtpUser=xiaqinghuan@mail.ustc.edu.cn`、
`confirm=always`、`suppresscc=self`）；凭据在 GNOME keyring，**主机键是 `smtp.ustc.edu.cn:465`（带端口）**。

### 3) 订阅（未订阅会被审核/丢弃）— 已实测的可脚本化流程（2026-10-13）

```bash
# a) 发任意内容的信到 +subscribe（subspace 页面的 sub 链接就是这个地址）
printf 'To: linux-clk+subscribe@vger.kernel.org\nSubject: subscribe\n\nsubscribe\n' > /tmp/sub.txt
python3 ~/.local/bin/send-mail-ustc.py /tmp/sub.txt --send
# b) 等 Confirm subscription（**别用 26 s 当预期**：2026-10-13 linux-clk 实测 ~5 min，可能灰名单）
python3 ~/.local/bin/read-mail-ustc.py --days 1 --grep 'linux-clk'
# c) 确认信 Reply-To 形如 <list>+confsub-<token>-<user>=<domain>@vger.kernel.org：回任何内容即可
python3 ~/.local/bin/read-mail-ustc.py ... # 取 Reply-To（或直接照抄确认信正文里的地址）
printf 'To: linux-clk+confsub-<token>-xiaqinghuan=mail.ustc.edu.cn@vger.kernel.org\nSubject: confirm\n\nconfirm\n' > /tmp/conf.txt
python3 ~/.local/bin/send-mail-ustc.py /tmp/conf.txt --send
# d) 收到 'Welcome to <list>@vger.kernel.org' 才算成功（核对：INBOX + "Junk E-mail"）
```

地址格式以 https://subspace.kernel.org/vger.kernel.org.html 的 sub 链接为准（HTML 里 `+subscribe` 被转义成 `&#37;&#52;&#48;` = `@`）。
**非 vger 列表另走各家门**：dri-devel = lists.freedesktop.org 表单、ath12k = lists.infradead.org 表单（邮件 +subscribe 无效）。

发信到 `<list>+subscribe@vger.kernel.org`（**majordomo 已退役**），确认信回一发即生效。
列表/归档的权威目录：`https://subspace.kernel.org/vger.kernel.org.html`。

### 4) 读回信（IMAP）

```bash
# IMAP 主机 = mail.ustc.edu.cn:993（imap.ustc.edu.cn 无 DNS，别按名字猜）
# 凭据复用 keyring 的 smtp.ustc.edu.cn:465 条目；工具已在 ~/.local/bin/
read-mail-ustc.py --days 3                       # 三处（INBOX / "Junk E-mail" / "Sent Items"）
read-mail-ustc.py --days 7 --grep cambistmclkcc,nt36536   # 按主题/发件人过滤
read-mail-ustc.py --days 14 --replies-only       # 只看对我们的 Message-ID 的回复（In-Reply-To/References）
```

### 5) 复核投递（必做）

```bash
# 按发件人查（自动过 Anubis PoW）
python3 ~/.local/bin/lore-query.py "https://lore.kernel.org/linux-arm-msm/?q=f:<你的地址>"

# 按 Message-ID 直取 raw —— 不依赖搜索索引，最可靠；再比正文 sha256
```

## 坑（都踩过）

1. **inbox 路径不能按列表名猜**：`devicetree` → **`/linux-devicetree/`**、`linux-kernel` → `/lkml/`。查错路径得 404，会误判"未投递"。
2. **lore 有 Anubis PoW**；`pass-challenge` 必须带 `id=` 参数，否则 HTTP 500 + 新挑战。
3. **认证失败后凭据会被自动清空**（`git credential reject`）——先重存再排查。
4. **列表信会被 USTC 标 `[SPAM]`**；`Junk E-mail` 在 IMAP 里必须加引号才能 select。回信要三处都看。
5. **本地文件行数 ≠ 收到行数**是正常的：`git send-email` 会把 format-patch 的伪头提升为邮件头。
6. 有的地址会"邮箱满"退信（`554 5.2.2`）——地址没错，过几天单独重投，别当配置问题。
7. **`git format-patch` 对 >80 列 Subject 折行、并按同样规则截断文件名** —— 这是 git 的正常行为，**不是补丁损坏**：`git format-patch -1 <commit>` 重生成会一模一样（2026-10-13 实测 m2/m3/m3-4 全部如此）。判"Subject 被截断/补丁坏了"前先复现一次。
8. **未订阅的 vger 列表也能投递并归档**（2026-10-13 实测）：M3-1 三枚补丁 To `linux-usb`、Cc `devicetree`/`linux-arm-msm`/`linux-kernel`（后三者中 devicetree/lkml 未订阅），结果 **linux-usb 与 linux-devicetree 各自 4/4 归档**。⇒ 「未订阅即被审核/丢弃」只对部分列表成立；但**投递后仍必须按 Message-ID 到每个目标 inbox 单独复核**（`lore-query.py "https://lore.kernel.org/<list>/?q=f:<地址>"`，注意 devicetree 的 inbox 是 `/linux-devicetree/`）。
9. **读回信**：IMAP = `mail.ustc.edu.cn:993`。`--replies-only` 靠 `In-Reply-To`/`References` 匹配我们自己的 Message-ID，是查「有没有人回」的最快路径（比翻列表洪水可靠）。判归档一律按 Message-ID 取 raw 比正文 sha256，**别只看「已发送」**。
