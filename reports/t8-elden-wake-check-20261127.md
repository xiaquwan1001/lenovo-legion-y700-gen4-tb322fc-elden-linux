# T8：`elden-wake` 纳入 `deploy-desktop-shell.sh --check`（2026-11-27）

> 性质：**只改仓内脚本 1 个**（`scripts/deploy-desktop-shell.sh` 新增 §18），设备侧**只读**验证
> （`ssh elden` 只跑 `systemctl is-*` / `sha256sum` / `test -x`）。未在设备上写任何文件、
> 未启停服务、未 reboot、未 `git add`/`commit`/`push`。
> 来源待办：`reports/panel-wake-service-20261126.md` §4「建议纳入 `deploy-desktop-shell.sh --check`」。

---

## 0. 与派工单基线的一处修正（现查真值）

派工单假设仓内件在 `packaging/elden-userland/{services.tsv,files/,out/units/systemd/}`。**实测不成立**：

```
$ grep -rn elden-wake packaging/ scripts/          # 空
$ find . -name 'elden-wake*' -not -path './.git/*' # 空
```

即：`elden-wake` 的两个 unit **从未进仓**，`services.tsv` 也没有对应行（`render.py` 渲不出来）；
仓内唯一源件是 `scripts/wake-screen.sh`，设备 `/usr/local/bin/elden-wake` 就是它的副本
（`sha256sum` 两边同为 `5e3d5611…b71b42e5`）。2026-11-26 那次是**纯手工 additive 安装**。

⇒ 因此本节不能「比 out/units 的 render 产物」，改走 §15 `WM_CLOSE_SH` 的既有口径：
**把两个 unit 的逐字节内容收进部署脚本本身（仓内即 SSOT）**，判据再拿设备 sha 与脚本渲染值比。
这样仓与设备不会各有一份真源，`bash -n` + 反例都能静态守。

## 1. 加的判据（`scripts/deploy-desktop-shell.sh` §18，四件，缺一即 MISS）

| # | 判据 | 实现 |
|---|---|---|
| ① | `/etc/systemd/system/elden-wake.path`、`.service` 在设备上，且 sha == 脚本 heredoc 渲染值（= `b89b631d…` / `f3169d61…`） | `sha256sum` 设备 vs `sha256sum $EW_TMP/elden-wake.*` |
| ② | `systemctl is-enabled elden-wake.path` = `enabled` | 设备侧 `is-enabled` |
| ③ | `systemctl is-active elden-wake.path` = `active`（path unit 的 active 语义 = 正在监控 `PathExists=`；服务本体 `elden-wake.service` 是 `Type=oneshot`，平时 `static`/`inactive` 是**正确**状态，故不判它 active——判了必假红） | 设备侧 `is-active` |
| ④ | `/usr/local/bin/elden-wake` 在位、`-x`、sha == 仓内 `scripts/wake-screen.sh` | `test -x` + `sha256sum` |

新增行：判据块在脚本第 §18 节（`EW_PATH_UNIT` … 到 `面板唤醒通道就绪`），约 +95 行；
unit 内容 = 2 个 heredoc（`EOSEWPATH` / `EOSEWSVC`），与设备现有文件逐字节相同（下文 §3 sha 对照）。

**install 分支**（同一节 `else` 支）：
- 两 unit sha 不符才 `scp` + `chmod 644` + `daemon-reload`（sha 相同 ⇒ 零拷贝，天然幂等）；
- `elden-wake` sha 不符或不 `-x` 才 `scp scripts/wake-screen.sh` + `chmod 755`；
- 最后 `systemctl enable --now elden-wake.path`（已 enabled 不改、已 active 不重启，不碰
  `/run/elden-wake.trigger`），再复测四件判据给 `ok`/`no`。
- 缺源件（`scripts/wake-screen.sh` 不在）⇒ 报 MISS 并**拒绝装占位件**（同 §15 uinput-back 口径）。

## 2. `--check` 原始输出（2026-11-27，`ssh elden` 只读）

```
$ bash scripts/deploy-desktop-shell.sh --check ; echo rc=$?
== 18) 面板唤醒通道（elden-wake.path/.service：SSH 触发熄屏唤醒）==
  ok    elden-wake.path 与仓内 §18 渲染一致（b89b631d…）
  ok    elden-wake.service 与仓内 §18 渲染一致
  ok    elden-wake.path enabled+active（监控 /run/elden-wake.trigger 中）
  ok    /usr/local/bin/elden-wake 在位可执行且与 scripts/wake-screen.sh 一致

结果: 达标（MISS=0）
rc=0
```

（本次全仓门禁本来就是 MISS=0，§1–§17 全 `ok`，见 `/tmp/ew-check-1.log` 全文；未去修任何别节。）

## 3. 幂等证据（跑两次输出完全相同）

```
$ bash scripts/deploy-desktop-shell.sh --check > /tmp/ew-check-1.log 2>&1 ; echo rc=$?   # rc=0
$ bash scripts/deploy-desktop-shell.sh --check > /tmp/ew-check-2.log 2>&1 ; echo rc=$?   # rc=0
$ diff /tmp/ew-check-1.log /tmp/ew-check-2.log && echo IDENTICAL
IDENTICAL
```

两次均为 **74 行输出、逐字节相同、rc=0**（不是只比 §18 那 4 行，是整份日志）。

sha 三方对照（设备 = 脚本 heredoc = 仓内源件）：

| 件 | 设备 sha256 | 脚本 heredoc 渲染 sha256 | 结论 |
|---|---|---|---|
| `elden-wake.path` (186 B) | `b89b631d02c61e9cd8b0c1a54490f14b957efcceb6ebbc545fb69b22dbe4b1f2` | 同 | 一致 |
| `elden-wake.service` (363 B) | `f3169d61b9c9448b728eb4b0c6da41e884dade54630d69a65a44c66c9a415d92` | 同 | 一致 |
| `/usr/local/bin/elden-wake` | `5e3d561149f60b5beae432039d17402752bbc98033ff45705d9a5036b71b42e5` | = `scripts/wake-screen.sh` | 一致 |

⇒ install 分支在这些条件下是**空操作**（三个 sha 全相同 ⇒ 一次 scp 都不发，只 `enable --now` + 复测），
重复跑 MISS 不会增长。

设备侧状态原始值（只读）：

```
is-enabled elden-wake.path  = enabled
is-enabled elden-wake.service = static
is-active  elden-wake.path  = active
is-active  elden-wake.service = inactive   ← oneshot 正常态，判据故意不要求 active
/run/elden-wake.trigger     = 不存在（服务自消费正常）
```

## 4. 判据反例（人工核对过的边界，未写自动化 selftest）

- path unit 若不 `enabled` ⇒ §18 第 3 项走 `no`（"要 enabled + active"）；
- 若手工改过设备 unit（哪怕只多一个空行）⇒ sha 不等 ⇒ 第 1/2 项 `no`；
- 若 `/usr/local/bin/elden-wake` 是旧版脚本 ⇒ sha 与 `wake-screen.sh` 不等 ⇒ 第 4 项 `no`；
- 判据③**不**看 `elden-wake.service` 的 `is-active`：oneshot 跑完即 `inactive`，拿它当门 =
  永远假红（这条写进脚本注释，防后人「顺手加上」）。

## 5. 复现命令

```bash
cd /home/xuqianhui/y700-elden
bash -n scripts/deploy-desktop-shell.sh            # 语法门（§22 A 也跑这个）
bash scripts/deploy-desktop-shell.sh --check       # 只读；rc=0，§18 四行全 ok
bash scripts/deploy-desktop-shell.sh --check > /tmp/a.log 2>&1
bash scripts/deploy-desktop-shell.sh --check > /tmp/b.log 2>&1
diff /tmp/a.log /tmp/b.log                          # 空 = 幂等
ssh elden 'systemctl is-enabled elden-wake.path; systemctl is-active elden-wake.path; sha256sum /usr/local/bin/elden-wake'
```

## 6. 回退方式（纯 additive，两行）

```bash
# 回退本改动（唯一改的文件）
cd /home/xuqianhui/y700-elden
git checkout -- scripts/deploy-desktop-shell.sh     # 或 git revert <本次提交>
# 设备侧无需任何回退动作：本节只读判定，未在设备上改过任何文件/服务
# （如需彻底删掉这条通道本身——与本改动无关——见 reports/panel-wake-service-20261126.md §0 回滚行）
```

## 7. 残留风险 / 待办（交给父会话）

1. **install 分支未上机实跑**（本 lane 禁设备写）：逻辑上是 sha 不符才 scp，当前三 sha 全一致 ⇒
   空操作；但「从零重建根后第一次真装」这条路径只能等下一次重建窗口验证（建议紧跟 rebuild 后跑一次不带 `--check`）。
2. **unit 内容进了部署脚本的 heredoc**（不是 `packaging/elden-userland`）。若以后要让
   `render.py`/`services.tsv` 统一管 path unit，应把两 unit 迁去 `out/units/systemd/` 并让 §18
   改读渲染产物——届时本节两处 heredoc 必须一并删掉，否则出现双真源。
3. `scripts/wake-screen.sh` 现被 §18 当作设备件 SSOT（此前无人引用它做门禁）；
   改它 = 会立刻让设备 §18 报 `no`（这是设计意图，但等于新增一条「改了要重装」的耦合）。
4. 本报告未登记进 `reports/README.md`（机器生成，`scripts/reports-index.py`，属总管/收口步）。
