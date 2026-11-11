# IME OSK 不弹 — 上机最小判别链（2026-11-11）

设备：U（在机 7.3.1-debug-vk184-00002，ssh root@192.168.7.1，GUI 用户 1001）。
执行 lane：G1-37 / C11「点输入框 OSK 不弹」。判别脚本 = `reports/ime-phosh-fcitx5-invest-20261110.md` §6.2/§9。
所有设备命令经 `scripts/device-lock.sh`，单服务 stop/start 均已回退，未装包、未重启会话。

## 1. 环境现状（原始输出摘录）

```
phoc 0.58.0 / phosh 0.59~alpha1-1 / phosh-osk-stevia 0.59~rc1-1 / squeekboard 1.43.1-2.1 / fcitx5 5.1.23-1
进程：phoc(1014) phosh(1109) fcitx5(1099: `/usr/bin/fcitx5 -r --disable waylandim`)
      phosh-osk-stevia(1641, `--allow-replacement`, unit = mobi.phosh.OSK.service)
fcitx5 日志：`waylandmodule.cpp:702] Using Wayland native input method protocol: 0`（waylandim 确认关闭）
```

## 2. E0 / E2 / E4 逐步结果

### E0 — OSK 本体（通过）
```
gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 \
  --method sm.puri.OSK0.SetVisible true   →  ()
Get Visible → (<true>,)          # 键盘 D-Bus 面 + 渲染通路完好
```

### E2 — IM v2 槽位（通过，计数 0）
```
journalctl --user -b | grep -c 'Input method unavailable'  →  0
```
stevia 自 11-05 起独占槽位（E3b 里手动重启后 `get_input_method → zwp_input_method_v2#43` 绑定成功，无 unavailable）。

### E4 — 客户端 text-input 链（客户端 OK，OSK 不弹）
停 fcitx5 + `env -u GTK_IM_MODULE -u QT_IM_MODULE` 起 GTK4/GTK3 测试窗（python3-gi Gtk.Entry + grab_focus），
WAYLAND_DEBUG 抓包（/tmp/e4-gtk4.log, /tmp/e4-gtk3.log, /tmp/e4d-*.log, /tmp/e3b-app-*.log）：

```
-> zwp_text_input_manager_v3.get_text_input(new id zwp_text_input_v3#62, wl_seat#3)
zwp_text_input_v3#62.enter(wl_surface#7)          # phoc 发给客户端
-> zwp_text_input_v3#62.enable()                  # 客户端 enable 请求 ✅
-> zwp_text_input_v3#62.set_surrounding_text / set_content_type / set_cursor_rectangle
-> zwp_text_input_v3#62.commit()
```
GTK3 对照臂同样 `enter → enable()`。清空污染（先 SetVisible false）后 3/3 连跑：
**enable 发出，`Visible` 恒 `(<false>,)`，键盘不自动弹**（try1/2/3: enable=1 enter=1 keymap=1 Visible=false）。

### E3 — stevia 侧 activate（无）
手动 `G_MESSAGES_DEBUG=all phosh-osk-stevia --allow-replacement`（/tmp/e3b-stevia.log，1305 行），
同窗口内客户端 3 次发 enable，stevia **零条 `handle_activate`/activate 事件**，仅有 `pos_osk_dbus_handle_set_visible: 0`（E0 的 hide）。
⇒ phoc 收到 enable 后**没有向 input-method-v2 客户端发 activate**。

## 3. 走了哪支 + 判定

**走了「E2=0 且 E4 有 enable 但键盘不弹 → E3 → 判 phoc（合成器）侧」分支。**
E4 的期望分支（键盘自动弹 ⇒ 部署 focusd）**不成立**，故本轮**未部署** `elden-ime-focusd`。

最终判定层：**合成器（phoc 0.58）的 text-input-v3 → input-method-v2 activate 转发断裂**。
客户端层（GTK3/4）、shell 层（stevia 绑槽成功）、OSK 本体（E0）、槽位（E2=0）全部排除。
与调研报告 §5 假说一致：phoc 修复提交 `bb1f7465` 不在 0.58 中，D2 路线必须 phoc ≥ 0.59。
注意：默认会话里 GTK 三变量全设 `fcitx`（见 §4-U3），GTK 客户端压根不发 text_input —— 这条 phoc 断裂被掩盖；
即便换了客户端，phoc 0.58 也接不住。上游 issue 素材（未投递）：
- 复现：phoc 0.58.0-1 + 任一 text-input-v3 客户端发 enable/commit + input-method-v2 客户端（phosh-osk-stevia 0.59~rc1）已绑定槽位；
- 现象：客户端收到 `enter`，发送 `enable()`+`commit()`，IM 客户端收不到 `activate`；
- 对照：phosh 0.59~alpha1 / stevia 0.59~rc1；怀疑缺 `bb1f7465` 等价修复。
- 原始抓包：设备 /tmp/e4-gtk4.log、/tmp/e4-gtk3.log、/tmp/e4d-{1,2,3}.log、/tmp/e3b-stevia.log。

## 4. U3 / U12 / U6 补证

| # | 结论 | 证据 |
|---|---|---|
| U3 | **确认**：GUI 会话进程环境真有 `GTK_IM_MODULE=fcitx` | `tr '\0' '\n' </proc/1109(phosh)/environ`：`GTK_IM_MODULE=fcitx` / `QT_IM_MODULE=fcitx` / `XMODIFIERS=@im=fcitx`；fcitx5-indicator.py(1100) 同 |
| U12 | `org.kde.impanel` **无 owner**（计数 0）——focusd 未部署（Debian rootfs 未装），kimpanel 无人监听 | `busctl --user list \| grep -cF org.kde.impanel` → 0；仅有 org.fcitx.Fcitx5 / IBus 别名（fcitx5 pid 50106）与 sm.puri.OSK0（stevia pid 52943） |
| U6 | `wayland-protocols` **包不存在**，`/usr/share/wayland-protocols/` 目录也没有（0 项）——协议 XML 烘进了二进制 | `dpkg -l wayland-protocols` → 没有找到；`ls /usr/share/wayland-protocols` → 无此目录 |

## 5. 未完成项

- **E7/E8 需装包**（fcitx5-frontend-gtk4 / wvkbd / phoc ≥0.59），本轮禁装，未跑。
- `elden-ime-focusd` 未部署：设备缺 `libwayland-dev`/gio dev 头文件不确定，且按分支纪律不在本轮落。
  **下轮建议**：E0 已证 OSK0 通路完好，focusd（kimpanel→OSK0）仍是最省修复；但 phoc 侧断裂独立存在，
  Wayland 原生 app（不走 fcitx IM 模块）在 phoc ≥0.59 前无解。
- 未做真实触屏点击复现（物理动作归用户）；本判据链全部用 xdg_activation + grab_focus 取得键盘焦点（keymap=1 已核实）。

## 6. ★SSOT 待并入（由总管收口）

1. **根因分层（新证据，修正 §6 假说）**：「点输入框 OSK 不弹」在 phoc 0.58 上有**两条独立断裂**：
   ① GTK 三变量=fcitx ⇒ 客户端不发 text-input（已知）；② **phoc 0.58 收到 text-input enable 也不向 input-method-v2 发 activate**（本轮 E4/E3b 实测，3/3 可复现）。
   ② 使 D1/D2 之外的一切「协议侧」修复在 phoc ≥0.59 前无效；focusd（OSK0 通路）是唯一绕开两条断裂的修法。
2. phosh-osk-stevia 的 unit 名是 **`mobi.phosh.OSK.service`**（不是 phosh-osk-stevia.service）；重启 stevia 需 `--allow-replacement` 保持抢槽。
3. 本轮环境：fcitx5 unit 描述已带「waylandim disabled」，`protocol: 0` 可作日常判据；U12 口径更新为「focusd 未部署于 Debian rootfs」。
4. E0 会把 OSK0 Visible 置 true 且**不自动回退**，做后续 E4 类实验前必须先 `SetVisible false` 清污染（本轮踩过一次）。

## 复现命令（主机，cwd=仓库根）

```sh
cd /home/xuqianhui/y700-elden
# E0/E2/E4/E3 全链：脚本在设备 /tmp/{e4b,e4d,e3b}.sh；判据链见本文 §2
scripts/device-lock.sh -w 600 bash -c "ssh root@192.168.7.1 'su - xuqianhui1001 -c \"sh /tmp/e4d.sh\"'"
scripts/device-lock.sh -w 600 bash -c "ssh root@192.168.7.1 'su - xuqianhui1001 -c \"sh /tmp/e3b.sh\"'"
```
