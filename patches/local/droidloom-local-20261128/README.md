# T43：droidloom-wayland 本机 IME 缓解（2026-11-28）

对应 `reports/t38-keypad-rootcause-20261128.md` 因果链的**客户端两环**：Android 侧
`showSoftInput` 恒 false（#65）⇒ 应用提交后 `start input restarting=true` ⇒ IMMS 收 IME
⇒ **droidloom-wayland 忠实 `disable()` 宿主 text-input**（第 3 环）⇒ 宿主 OSK 收起，且
之后 `Editor.needs_enable()` 不再 `enable()`（第 5 环）⇒ 点输入框再也出不来。

补丁：`0001-t38-text-input-keep-enabled.patch`，只改
`graphics/droidloom-wayland/src/text_input.rs`。

## ① 抑制 disable（第 3 环）

`TextInput::update()` 的 disable 分支加前置条件：当 Android 报 editor 失活/失焦
（`desired = None`）但宿主 `zwp_text_input_v3` 仍在某个 surface 上（`entered.is_some()`）
时，**不发 `disable()`**、不翻转 `self.enabled`，只置 `held = true`。真正的 Leave
（`entered = None`）与 `disconnect()` 路径照旧 disable。对应 T38 §2 时间线中
11:38:26.9x 那次 `-> zwp_text_input_v3@25.disable()`。

## ② 强制重发 enable（第 5 环）

新增 `held: bool`。当处于 `held` 状态（= disable 曾被抑制、Android 的 IME 已被
IMMS 收走）且 Android 重新上报同一 task/session 但 `show_request` 前进（= 用户重新
tap 输入框、新的 showSoftInput 请求）时，绕开 `Editor.needs_enable()` 的
「task/session 未变就不重发」，强制 `resource.enable()`。仅在 `held` 状态激活，正常
流（未抑制过 disable）行为与原版完全一致（原测试
`showing_an_existing_editor_does_not_reenable_it` 原样通过）。

## 构建（本机交叉编，18 s 级）

```sh
cd ~/y700-elden   # build/droidloom-51-src -> ~/elden-cache/build/droidloom-51-src
bash scripts/build-droidloom-userland-crates.sh droidloom-wayland
```

实测：`Finished release in 9.89s`；产物
`build/droidloom-51-src/target/aarch64-unknown-linux-gnu/release/droidloom-wayland`
（7 955 888 B），`objdump -T` max **GLIBC_2.39** ≤ 设备 glibc 2.41。

打补丁到干净源树：

```sh
tar xf droidloom-source-0.1.0-51.tar.gz -C <dir>
cd <dir>/droidloom
patch -p1 --fuzz=0 < 0001-t38-text-input-keep-enabled.patch
```

## 部署目标路径（2026-11-28 只读 ssh 确认）

设备上承接 `droidloom-wayland` 的文件**不在** `/usr/lib/droidloom/runtime/`（该目录下
无 wayland 相关件），而是：

```
/usr/bin/droidloom-wayland   （release 51 原件，7 234 400 B，
                               sha256 01e3d30c2fb02e8d…606fa）
```

部署时先 `sudo mkdir -p /root/droidloom-backup-20261128-t43 &&
sudo cp -a /usr/bin/droidloom-wayland /root/droidloom-backup-20261128-t43/` 再
`sudo install -m755 droidloom-wayland /usr/bin/droidloom-wayland`，然后
`ssh elden-root 'systemctl --user restart droidloom.service'`（或按 AGENT-OPS 流程）。

## 回滚

1. `sudo install -m755 /root/droidloom-backup-20261128-t43/droidloom-wayland /usr/bin/droidloom-wayland`
2. `systemctl --user restart droidloom.service`
3. 源码树：`patch -p1 -R < 0001-t38-text-input-keep-enabled.patch`

## 验收判据

1. **主判据**：小红书手机号（号段）输入框可**连续输入多位**（3-4-4 分组空格属应用
   格式化，非 bug），键盘不随提交自隐；输错后再点输入框键盘能重新弹出（无需重启 cell）。
2. **回归**：`droidloomctl status` 仍 `Android is ready`；RIME 中文输入正常；
   Settings 文本输入正常。
3. 已知取舍（风险）：同一 surface 内应用主动 blur（active=false 且未离开 surface）
   时键盘会**停留**到 Leave/切窗——本补丁有意如此（宁可不收，不可收死）；若实测不可
   接受，回退 ① 仅保留 ② 即可（② 单独也修不了「点不回来」，故建议两者同用）。

## 单元测试

`cargo test -p droidloom-wayland`：101 + 8 全过，含新增
`t38_withholds_disable_while_entered_and_holds_state`（抑制 disable + Leave 照旧收）。
强制 re-enable 分支需 wayland resource，未做单测（fixture 无 resource），由设备验收覆盖。
