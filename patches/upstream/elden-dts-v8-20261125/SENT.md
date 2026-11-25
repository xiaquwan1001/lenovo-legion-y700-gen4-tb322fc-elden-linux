# v8 投递记录（2026-11-25T09:13Z，3 封全 `Result: 250`）

| 项 | 值 |
|---|---|
| 通道 | USTC smtp（`bash SEND.sh --send`，日志 `logs/sent-20261125-171309.txt`） |
| cover MID | `<20261125091309.124354-1-xiaqinghuan@mail.ustc.edu.cn>` |
| patch MID | `-2-` / `-3-`（同前缀） |
| 收件人 | To `andersson@kernel.org`,`konradybcio@kernel.org`；Cc `abelvesa@kernel.org`, **`mitltlatltl@gmail.com`（Pengyu，关系声明需要他在线程里）**, `robh@`, `krzk+dt@`, `conor+dt@`, `devicetree@`, `linux-arm-msm@`, `linux-kernel@` |
| 新线程 | 无 `In-Reply-To`/`References`（v7 是单提交碎片，无 cover） |
| 内容 | 1/2 = `qcom.yaml` 加 `lenovo,elden`（v7 漏的那行）；2/2 = v7 板件原文，`cmp` diff 段逐字节相同 |
| 脚本修复 | `SEND.sh` 原用 `${CMD[@]/--dry-run/}` 展开出空串（`fatal: empty string is not a valid pathspec`）⇒ 改成 dry-run/真发两条显式命令 |

## lore 复核

- 投后 2 min 内查 `/linux-devicetree/`、`/linux-arm-msm/`、`/linux-kernel/` 均 `not found`（已知摄取延迟，
  见 `TASKS/README.md` §7 头「归档复核口径」）；**复核判据 = 稍后按同一 MID 再查，不以 patchwork `state` 下结论**。
