# #713 OSK 候选「静默没有」= `Completers.Rime.user-data` 空串把 librime 部署整体挡掉

> 2026-11-24 设备窗轮实测（`reports/d3-rime-ondevice-20261124.md` 全文）。

## 判据（症状 → 一句话定因）

- 症状：phosh-osk-stub 0.46 的 B 案 rime completer 已部署、`Completers default='rime'`、librime1t64 + `librime-data` 都在，
  **打字却一条候选都没有**（而键盘本身完全正常 ⇒ 不像「装了坏二进制」）。
- 定因：`journalctl _COMM=phosh-osk-stub | grep 'Error creating user data dir'` 每发开机都有
  `E… deployment_tasks.cc:90] Error creating user data dir:` —— **冒号后面是空的**，这是「路径串为空」的指纹。
  追到源码 `pos-completer-rime.c`：`g_settings_get_string (settings, "user-data")` 的值被**原样**赋给
  `RimeTraits.user_data_dir`，而 gschema 里 `user-data` 的默认值就是 `''`（描述写「Empty disables the user dictionary」）。
  ⇒ librime 拿空路径去 `mkdir`/建 leveldb，部署任务失败，schema 从未建成 ⇒ 候选恒空。**没有任何一条错误会出现在 UI 上**。

## 处置

```sh
install -d -o <会话用户> -g <会话用户> ~/.local/share/rime
gsettings set sm.puri.phosh.osk.Completers.Rime user-data /home/<user>/.local/share/rime   # dconf 持久化
kill <osk-stub pid>            # phosh 按需重拉
```

修复后三重证据：`~/.local/share/rime/build/` 被 osk-stub 自己填出 24 个 `luna_pinyin*` 档 ⇒ 该错误消失 ⇒
osk-stub 持有 `luna_pinyin.userdb/LOCK`（独立进程去开同一 userdb 报 `Resource temporarily unavailable` = 它真在用 RIME）；
用同一对目录跑 `librime-piped --oneshot nihao` = `你好/妳好/逆号/拟好/你`（rc=0）。

## 两条连带事实（同一坑族）

- **子 schema 不会出现在父 schema 的 `gsettings list-recursively X` 结果里**：查 `Completers` 只看到 `default`，
  会误判「Rime 三键没装」；要查 `sm.puri.phosh.osk.Completers.Rime` 本身。另：**以 root 且无会话总线查 gsettings 得到 `''`**，
  不是真实值，必须 `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/<uid>/bus` + 会话用户身份查。
- **`/home/<user>/.local` 是 `root:root`**（2026-11-19 重建根遗留；只有 `.local/share` 被修过）⇒ 任何要往 `~/.local/`
  直接写的部署都会 EACCES。往 `~/.local/share/...` 写没事，但别把「能写」当通则。

## 欠账（正解在源码，需重编 osk-stub）

空值应退化为 `g_build_filename (g_get_user_data_dir (), "rime", NULL)` + `g_mkdir_with_parents()`；
gschema 的 `user-data` 描述同步改成「空 ⇒ 用 XDG 默认目录」。这样默认配置不再是「默认坏」。
