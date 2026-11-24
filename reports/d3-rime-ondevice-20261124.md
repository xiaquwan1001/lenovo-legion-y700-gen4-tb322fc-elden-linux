# D3 收口：RIME 候选后端在机可用 —— 根因 = `Completers.Rime.user-data` 是空串（2026-11-24 设备窗轮）

> 设备：TB322FC U2（HA2EXB0E 候选，`ssh root@192.168.7.1`）· 内核 `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`（日常核）
> · 根 `/` = `/dev/sda17` · Debian trixie · phosh/phoc/osk-stub **0.46.0**
> 本轮类型：设备侧实测（可读可写，非只读）。所有命令都带 `timeout -k`。

## 0. 一页结论

| 项 | 结论 | 判据（可复跑） |
|---|---|---|
| **B 案 rime 件是否已部署** | **早就部署完了**（不是待办）——`/usr/bin/phosh-osk-stub` md5 = `2c040ca7…` = `out/osk-stub-rime-20261123/phosh-osk-stub`；`dpkg-divert` 在；gschema + `rime.completer` 均我方件；`Completers default = 'rime'` | 见 §2 表 |
| **真缺陷（唯一）** | `sm.puri.phosh.osk.Completers.Rime user-data = ''` ⇒ 我们的 completer 把空串直接塞给 `RimeTraits.user_data_dir` ⇒ librime 每发都 `deployment_tasks.cc:90 Error creating user data dir:`（日志里冒号后**为空**正是空路径的指纹）⇒ 用户词典/部署从未建成 ⇒ 候选空 | `journalctl _COMM=phosh-osk-stub \| grep 'Error creating user data dir'` |
| **修法（零重编）** | `install -d ~/.local/share/rime` + `gsettings set … user-data /home/xuqianhui1001/.local/share/rime` + 让 osk-stub 重启 | §3 |
| **修复后证据** | `~/.local/share/rime/` 被 osk-stub 自己填出 **24 个文件**（`build/luna_pinyin*.{prism,table,reverse}.bin` 等，属主 `xuqianhui1001`，mtime = 重启当刻）；journal 里该错误消失；**osk-stub 持有 `luna_pinyin.userdb/LOCK`**（拿独立进程去开同一 userdb 会 `Resource temporarily unavailable` = 它真的在用 RIME） | §4 |
| **候选真的出得来** | 用仓内 A 案守护件（静态构建的 aarch64 `librime-piped --oneshot`）以**同一对 shared/user 目录**跑：`nihao` ⇒ **你好 / 妳好 / 逆号 / 拟好 / 你**（rc=0） | §4 |
| **仍缺（需人手）** | 屏上真打字（输入框内 `nihao` → 候选条 → 空格/数字选词）、每键震动、方向键三条观感判据；设备当前停在**锁屏**（无 `/dev/uinput`，agent 无法注入手势） | §5 |

## 1. 为什么这是「收口」而不是「又一轮调研」

2026-11-23 的 H lane 把件编译+部署到设备，`reports/ime-rime-backend-20261123.md` 十条判据里前几条只差「上机看候选」。
本轮查明：**那个「看不到候选」不是 RIME 质量问题，而是一个空串配置把 librime 的部署整体挡掉了**——它每天开机都在报错，
只是没人把 `deployment_tasks.cc:90` 与「OSK 不出候选」连起来。

## 2. 部署现状（现查，逐件 sha/md5）

| 件 | 设备值 | 仓内件 | 结论 |
|---|---|---|---|
| `/usr/bin/phosh-osk-stub` | md5 `2c040ca717084f04a3abc85bafb113fd` | `out/osk-stub-rime-20261123/phosh-osk-stub` 同 md5 | 我方件在位 |
| `dpkg-divert --list` | `本地转移 /usr/bin/phosh-osk-stub 到 /usr/bin/phosh-osk-stub.dpkg-dist` | — | divert 在（PITFALLS #654 的正确形态） |
| `/usr/share/glib-2.0/schemas/sm.puri.phosh.osk.gschema.xml` | md5 `f69635531728c4201a9562f29e2bc95a` | 同 md5 | 我方件在位，**且含 `Completers.Rime` 子 schema**（`user-data` 默认 `''` 就是坑源） |
| `/usr/share/phosh-osk-stub/completers/rime.completer` | md5 `ff01e83f008691c4b8c5cfaa10f38a69` | 同 md5 | 我方件在位（dpkg 里没有该文件 ⇒ 不被 apt 冲刷） |
| `gsettings … Completers default` | `'rime'`（uid 1001 + 会话总线） | — | 已选中；**注意**：以 root 无会话总线查会得到 `''`，别据此误判 |
| `gsettings … Completers.Rime` | `schema 'luna_pinyin'` / `shared-data '/usr/share/rime-data'` / **`user-data ''`** | — | 三键都在（`list-recursively` 只列 `default` 是因为**子 schema 不会出现在父 schema 的列表里**，不是没装） |

## 3. 修复序列（本轮实际执行；幂等、可回退）

```sh
# 1) 建用户目录（属主必须是会话用户）
install -d -o xuqianhui1001 -g xuqianhui1001 /home/xuqianhui1001/.local/share/rime

# 2) 指向它（dconf 持久化，冷启动存活）
su -l xuqianhui1001 -c 'XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus \
  gsettings set sm.puri.phosh.osk.Completers.Rime user-data /home/xuqianhui1001/.local/share/rime'

# 3) 让 osk-stub 重建（phosh 会在需要键盘时重新拉起；原件 1445 被杀后新 pid=49077）
kill <osk-stub pid>
```

**回退**：`gsettings set … Rime user-data ''` + `rm -rf ~/.local/share/rime`（回到「无候选」的旧态，不影响键盘本身）。

**⚠ 顺带发现的坑（`/home/xuqianhui1001/.local` 是 `root:root`）**：11-19 重建根后 `.local` 属主为 root，只有 `.local/share` 被修过；
若将来某次部署要往 `~/.local/` 直接写（不是 `share/`），用户身份会 EACCES。本轮只记录，未改（改属主属重建根动作）。

## 4. 修复后的三重证据

```
$ ls /home/xuqianhui1001/.local/share/rime/build | wc -l
24                     # luna_pinyin*.prism.bin / *.table.bin / *.reverse.bin / default.yaml …  mtime 15:57 = osk-stub 重启当刻
$ journalctl _COMM=phosh-osk-stub --since "-5min" | grep -c 'Error creating user data dir'
0
$ su -l xuqianhui1001 -c "/tmp/librime-piped --oneshot nihao --shared /usr/share/rime-data \
    --user /home/xuqianhui1001/.local/share/rime --schema luna_pinyin"
E… level_db.cc:259] Error opening db 'luna_pinyin': IO error: lock /home/xuqianhui1001/.local/share/rime/luna_pinyin.userdb/LOCK: Resource temporarily unavailable
你好
妳好
逆号
拟好
你
rc=0
```

那个 `LOCK` 报错是**正面证据**：osk-stub 正持有同一 userdb（说明它已按新配置初始化 librime）。

## 5. 还需人手的两条（设备停在锁屏；agent 无 `/dev/uinput`）

1. 上滑解锁 → 打开任意输入框（Firefox 地址栏最省事）→ 打 `nihao` → 应出现 `1 你好 2 妳好 …`；空格或数字选词。
2. 交回英文（`Esc`/切布局）确认英文照常；再确认每键震动（`haptic/0001`）与 terminal 布局方向键。

## 6. 欠的技术债（下一轮编译轮做，需重编 osk-stub）

- **正解在源码**：`pos-completer-rime.c:355-361` 把 `user-data` 原样传给 librime；空串时应退化为
  `g_build_filename(g_get_user_data_dir(), "rime", NULL)` + `g_mkdir_with_parents()`，并把 gschema 的 `<description>` 由
  「Empty disables the user dictionary」改为「Empty ⇒ 用 XDG 默认目录」，不要让默认配置默认坏掉。
  改后 gschema 默认值不必改（用户已有 dconf 值不会被覆盖）。
- 该条同时是**可上游**的小改动（空值健壮性），但需先重编 + 重跑本轮三条判据。

## 7. 来源

- 件/补丁：`patches-userland/zh-ime-rime-20261123/rime/0003-osk-stub-rime-completer-wiring.patch`（`Completers.Rime` 子 schema 定义、`g_settings_new` 与 `traits.user_data_dir` 赋值分别在补丁 :19 与 :349/:355-361）
- 产物：`out/osk-stub-rime-20261123/{phosh-osk-stub,rime.completer,sm.puri.phosh.osk.gschema.xml,DEPLOY.md,SHA256SUMS}`
- 前账：`reports/ime-rime-backend-20261123.md`（§5 H2 十条判据）、`reports/ime-osk-zero-to-usable-20261121.md`
- 本轮实测日志：`logs/rime-device-20261124/`（ssh 原始输出）
