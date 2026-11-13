# reports/artifacts — 试验证据二进制（2026-11-13 起「大件不入库」）

## 规则（唯一正文）

- **入库**：`SHA256SUMS`、`*.md`、`*.txt`、小件截图与配置（单件 ≤1 MiB）。
- **不入库**：单件 >1 MiB 的 `*.fd`（UEFI 固件）、`*.img`、`*.bin`（payload）、`*.gz`、`*.log`（构建日志）。
  `.gitignore` 末尾有对应块。实测 277 件 / 823.9 MiB，占主仓被跟踪体积 88%。
- **文件没删**：仍在本机磁盘原位（本目录下），只是不再被 git 跟踪 ⇒ 本机引用路径照常可用。
- **可核验性**：每目录 `SHA256SUMS` 仍在库；历史版本仍可取回：
  `git show <commit>:reports/artifacts/<dir>/<file> > /tmp/<file>`（2026-11-13 之前的提交都含这些 blob）。
- **重新入库的条件**：只有当某件成为「结论的唯一载体」（无 SHA256SUMS、无 out/ manifest、无法重出）时，
  用 `git add -f <path>` 单独入库，并在对应报告里写明理由。

## 为什么

主仓被跟踪 6525 路径 / 932 MiB，其中 `reports/artifacts/` 占 798 MiB（86%），而 UEFI 试验目录里
每个都带一份 4 MiB 的 `SM8750_EFI.fd` + `bootpayload.bin` + 5 MiB `build.log`，30 个 trial 高度重复。
不入库后：`reports/artifacts` 由 798 MiB → 48.7 MiB，主仓 checkout 体积与 clone 时间同步下降。
审计依据 = `reports/git-tree-audit-20261113.md` §2。
