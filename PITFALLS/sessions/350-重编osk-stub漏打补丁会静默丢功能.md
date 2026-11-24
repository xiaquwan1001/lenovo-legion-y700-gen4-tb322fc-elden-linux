# #717 重编 osk-stub 漏打一枚补丁 ⇒ 功能静默消失（没有报错、键盘照弹、只有 `strings` 能查）

> 2026-11-24 实测：为做「RIME 候选条常显」重编 `phosh-osk-stub`，只乘了 `rime/0003`+`0004`+`0005`，
> **漏了 `haptic/0001`（每键震动）与 `layout/0002`（terminal 方向键）**。装上去之后：
> 进程正常、键盘正常弹、候选正常出 —— 但**每键震动没了**，直到用户说「震动之前已经做了」才发现。
> 用户是对的：`/etc/environment` 里 `ELDEN_OSK_HAPTIC_DEV/_MS/_MAG` 三键一直在，11-23/11-24 的件都带钩子。

## 判据（唯一能查出来的方式）

```sh
strings /usr/bin/phosh-osk-stub | grep -c ELDEN_OSK_HAPTIC      # 装机件必须 = 3；=0 就是丢了
tr '\0' '\n' < /proc/$(pidof phosh-osk-stub)/environ | grep HAPTIC   # 开关在不在（/etc/environment 提供）
python3 读 /dev/input/event2 + 点 3 个键 ⇒ 应见 EV_FF(type 0x15) code=0 value=1
```

`evtest`/`dmesg` 都看不见这些：`g_spawn_command_line_async("/usr/local/bin/ffrumble …")` 是 fire-and-forget，
不写日志、不 fork 留在进程表里（30 ms 级），**只有**「读马达 FF 节点」或「strings 查钩子」两种办法。

## 处置

- 重编配方固定成 `patches-userland/zh-ime-rime-20261123/BUILD.md`（五枚补丁顺序 + 出厂自检 grep + 部署/回退）。
- 门禁 = `scripts/ime-single-stack.sh` **C8**：装机件 `grep -c ELDEN_OSK_HAPTIC` ≥1 + `/etc/environment` 有开关 +
  `/dev/input/event2` 在，三者缺一即 FAIL（`--apply` 不自动重编，只 WARN 指向 BUILD.md）。
- 通则：**replace 自编件时，判据要落在「件里有什么」而不是「进程在跑」**；同理 `layout/0002`（terminal 方向键）
  也属"静默丢"型，重编后应 `grep -c KEY_LEFT src/layouts/terminal.json`。

## 顺带（同轮，候选条）

0.46 的候选条是 `pos-completion-bar.c` 里 GtkBox 平铺 + RIME completer `limit=9` ⇒ **固定间距/固定个数、
不能右划展开**（用户 2026-11-24 记为明日待办）；改法见 `reports/ime-single-stack-20261124.md` §5c。
