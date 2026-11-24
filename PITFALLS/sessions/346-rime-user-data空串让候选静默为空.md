# #713 空 `user-data` 让 librime 每发部署失败（`.userdb` 不持久化 + 产物落进 cwd），**不是**「候选为空」

> 2026-11-24 设备窗轮。**初版把因果写强了，同日已按隔离实验更正**（见 §3）。
> 定因全文 = `reports/rime-completer-userdir-20261124.md`（主机侧 librime 1.13.1 三段实验）；
> 设备侧修复与证据 = `reports/d3-rime-ondevice-20261124.md`。

## 判据

- 症状（可自动查）：`journalctl _COMM=phosh-osk-stub | grep 'Error creating user data dir'` 每发开机一条，
  **冒号后面是空的** = 空路径指纹。
- 定因（file:line）：`pos-completer-rime.c:356,361` 把 `g_settings_get_string(… "user-data")` **原样**赋给
  `RimeTraits.user_data_dir`；librime 对「非 NULL 空串」不兜底（`RIME_PROVIDED` 只判非 NULL）⇒
  `InstallationUpdate::Run()` 里 `fs::create_directories("")` 必失败 ⇒ `deployment_tasks.cc:86-91` 打该 ERROR。
- gschema 默认值就是 `''`（描述还写着「Empty disables the user dictionary」）⇒ **默认配置 = 默认坏**。

## 危害（照实测写，别再加戏）

| 成立 | 不成立 |
|---|---|
| 用户词典 / 用户定制 / `installation_id` **从不持久化**（每次开机重部署、学词全丢） | ~~候选为空~~ |
| 部署产物写进**进程 cwd**（osk-stub 由 phosh 拉起，cwd 不在用户目录 ⇒ 污染 + 换会话即丢） | ~~schema 从未建成~~ |

## 处置（零重编，幂等可回退）

```sh
install -d -o <会话用户> -g <会话用户> ~/.local/share/rime
gsettings set sm.puri.phosh.osk.Completers.Rime user-data /home/<user>/.local/share/rime   # 必须会话总线
kill <osk-stub pid>      # phosh 按需重拉
```
已固化进 `deploy-desktop-shell.sh` **§14**（三件同验：目录+属主 / gsettings 指向 / `<user-data>/build/*.prism.bin` 在；
反例实测 ⇒ MISS=1）。

## 三条连带事实（都踩过）

- **子 schema 不会出现在父 schema 的 `gsettings list-recursively`**：GLib 只把「键名以 `/` 结尾」的可重定位子 schema 当 children，
  而 `Completers.Rime` 是独立 schema id + 自带 `path=` ⇒ 查 `Completers` 只看到 `default` 属正常，**不是缺键**。
- **以 root 且无会话总线查 gsettings 会得到假 `''`**；必须 `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/<uid>/bus` + 会话用户身份。
- **`/home/<user>/.local` 是 `root:root`**（2026-11-19 重建根遗留，只有 `.local/share` 被修过）⇒ 往 `~/.local/` 直接写的部署会 EACCES。

## 欠账（正解在源码，需重编 osk-stub 一轮）

空值应退化为 `g_build_filename (g_get_user_data_dir (), "rime", NULL)` + `g_mkdir_with_parents()`，gschema 描述同步改写。
