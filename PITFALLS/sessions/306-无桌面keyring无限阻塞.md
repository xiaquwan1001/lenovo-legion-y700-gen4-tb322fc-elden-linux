## #670 无桌面会话里 `keyring.get_password()` 会**无限阻塞**（不是报错）⇒ 任何"邮件/凭据自动化"脚本必须给预算 + 环境变量退路

**现象（2026-11-17 早，早间批处理首次调用 `scripts/mail-append-sent.py --check`）**：`python3 scripts/mail-append-sent.py --check <patch>` 跑到 200 s 超时（`rc=124`），**没有任何输出**。逐级排除：

- TCP 通：`/dev/tcp/mail.ustc.edu.cn/993` ok；`imaplib.IMAP4_SSL(...)` 0.0 s 出 welcome 串（`* OK Coremail System IMap Server Ready`）；
- 于是只剩登录前的取凭据一步。单测 **`keyring.get_password("smtp", "xiaqinghuan@mail.ustc.edu.cn")` 25 s 无返回、超时被杀**（`rc=124`）；
- 同一份代码在有桌面的会话里秒回 ⇒ **根因不是网络、不是 IMAP、不是 Coremail，是 keyring backend 在没有可交互会话时阻塞等解锁提示**（GNOME keyring / secret service 通过 D-Bus 弹窗，无会话就永远等）。

**判据（一条命令，10 s 内有答案）**：

```bash
timeout 10 python3 -c 'import keyring;print(bool(keyring.get_password("smtp","xiaqinghuan@mail.ustc.edu.cn")))'; echo rc=$?
# rc=124 ⇒ 无桌面、keyring 阻塞（不是"密码错"，也不是"没存"）
```

**处置（已成 `scripts/mail-append-sent.py` 的默认行为）**：

- 取凭据顺序 = **环境变量 `MAILPW`/`USTC_MAIL_PW`** → `--pw-stdin` → keyring（**5 s 预算，daemon 线程 + join(5)**）→ `git credential fill`（`subprocess.run(..., timeout=10)`）；
- 超时**不当致命错误**，打一行 `[warn] keyring 5 s 未返回…⇒ 跳过` 后继续走退路，全失败才退出并提示 `MAILPW=… `；
- 实测：现在这条路径 **≈15 s 内 fail-fast 退出**（原来是 200 s+ 挂死），早间/定时任务里不会再"静默卡住"。

**推广口径**：cron/systemd-timer/agent 批处理里调任何 `keyring`/`git credential`/`pass`/`secret-tool` 的命令，
**必须**给 `timeout` 或显式预算，并把「凭据取不到」当成可分类的失败（`rc` 非零 + 明确 message），
否则故障形态是**无声挂起**，比报错更难查。相关：`PITFALLS #218`（`git send-email` 认证失败会 `git credential reject` 删掉 keyring 密码）。

关联件：`scripts/mail-append-sent.py`（补 Sent Items 账，含 `--self-test` 离线自测）、`reports/upstream-status-20261113.md` §2b。
