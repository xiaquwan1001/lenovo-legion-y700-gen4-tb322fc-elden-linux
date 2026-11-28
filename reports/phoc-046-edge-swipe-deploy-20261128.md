# phoc 0.46+edge-swipe 与 droidloom T43 IME 缓解：设备部署记录（2026-11-28）

> 两件都是「主机侧早已编好、只差上机」的欠账（见 `TASKS/NEXT.md` T45 / T43）。
> 本次一趟做完：换 phoc（需重启合成器）+ 换 `droidloom-wayland`（只需重启 droidloom.service）。
> 设备 = TB322FC，`ssh elden`（用户 `xuqianhui1001`，`sudo -n` 可用），内核 `7.3.1-debug-vk189`。

## 1. phoc 0.46 + edge-swipe（T45 产物，零 root 交叉编）

| 项 | 值 |
|---|---|
| 装前在版 | Debian `phoc 0.46.0-1`，`/usr/bin/phoc` 527 408 B，sha256 `e3ffcfcd…a0d6347f`，**无 divert / 无 hold** |
| 装的文件 | `out/phoc-cross-20261128/phoc`（`scripts/build-phoc-cross.sh` 零 root 交叉编，非 chroot 版）<br>672 432 B，sha256 `5a68963c…876fb81e`，max GLIBC 2.38，NEEDED 16 项含 `libwlroots-0.18.so` |
| 设备侧 ldd | `=> not found` **0**，已解析 97 项（装前先验） |
| 钉住 | `dpkg-divert --package elden-phoc-override --divert /usr/bin/phoc.dpkg-dist` + `apt-mark hold phoc`（PITFALLS #654 的两层防护） |
| 发行版原件 | 留在 `/usr/bin/phoc.dpkg-dist`（同 sha），另存 `out/phoc-deploy-20261128/phoc-dist-0.46.0-1.orig.arm64` |
| 生效 | `systemctl restart greetd` @ **15:13:57**，新 phoc pid 96236；日志 `Modesetting with 1904x3040 @ 165.000 Hz` / `Enabling shell mode`，无 assert/segfault |
| 会话 | `greetd` active、`phoc` ×1、`phosh`、`phosh-osk-stub` 均在；锁屏与桌面都能出帧（grim 出图） |

**功能验收**：**用户手动在设备上做左缘右滑 ⇒ 生效**（关闭前台窗口）。证据目录 `out/phoc-deploy-20261128/`
（`post-install-shell.png` 锁屏、`pre-gesture-foot.png` 前台窗口、`post-gesture-left-edge.png` 注入后无变化）。

### ★未解的一点：合成注入的触屏**不触发** phoc 手势

同一份 phoc，`tools/uinput-touch`（`/dev/uinput` 造虚拟多点触屏）的 **tap 能生效**（点应用网格图标能起 app），
但 **从 x=3 起手的 swipe 不触发 edge-swipe**：

- `libinput debug-events` 能看到完整序列（`TOUCH_DOWN 0.16mm` → 20 步 `TOUCH_MOTION` 到 `47.27mm` → `TOUCH_UP`），坐标映射正确（tap 落点与图标位置吻合）；
- 试过 `swipe`（400 ms 建备）与 `hold-swipe`（等待 6 s 让 daemon 认到设备）两种时序，均不触发；dx≈897 px ≫ 阈值 `max(32, 0.25×1904)=476`；
- 结论：**手势类验收只能真手指**；合成触屏目前只适合验「点按/点击」路径（原有 OSK/tap 用例不受影响）。

## 2. droidloom-wayland T43 缓解（#65 客户端两环）

| 项 | 值 |
|---|---|
| 装前在版 | `/usr/bin/droidloom-wayland` release 51 原件，7 234 400 B，sha256 `01e3d30c…f1d606fa` |
| 装的文件 | `build/droidloom-51-src/target/aarch64-unknown-linux-gnu/release/droidloom-wayland`（T43 补丁树）<br>**7 955 888 B**，sha256 `8908c37e…d440ee902`，max GLIBC **2.39** ≤ 设备 2.41；`cargo test -p droidloom-wayland` 101+8 全过 |
| 备份 | `/root/droidloom-backup-20261128-t43/droidloom-wayland`（sha 与原版一致，`sudo sha256sum` 已核） |
| 生效 | `systemctl --user restart droidloom.service`（**不需要重启会话**）；20 s 后 `droidloomctl status` = `cell u1001 is running … Android is ready`，`adb devices` = `10.177.0.2:5555 device` |
| 回滚 | `sudo install -m0755 /root/droidloom-backup-20261128-t43/droidloom-wayland /usr/bin/droidloom-wayland && systemctl --user restart droidloom.service` |

**验收判据**（`patches/local/droidloom-local-20261128/README.md` §验收）：小红书号段框可连续输入多位、
键盘不随提交自隐、再点输入框能重新弹出；RIME 中文与 Settings 文本输入无回归。

### 2026-11-28 实测（用户出门，自动化跑；截图见 `out/phoc-deploy-20261128/ime-test/`）

| 步 | 动作 | 结果 |
|---|---|---|
| 1 | `am start` 小红书 → `adb input tap` 点「Log In」→ 宿主 `ydotool click 608,801` 点号段框 | 宿主 **数字键盘弹出**（`t43-b.png`），Android 侧 `mInputShown=true / mImeWindowVis=1` |
| 2 | `ydotool type "1234567890"` 连输 10 位 | 框内 = **`151 2345 6789`**（3-4-4 分组是应用格式化）；**键盘全程不隐**（`t43-c.png`，`mInputShown=true`） |
| 3 | 点非输入区尝试收起键盘 | 未收起（本步未复现「收起后唤不出」；自动化无法给真实触摸，收起/重弹路径**仍待真手指**） |
| 4 | 回归 | `droidloomctl status` = `Android is ready`、`adb devices` 在线、`systemctl --user is-active droidloom.service` = active |

**★自动化陷阱（本轮最大收获，`PITFALLS #761`）**：`adb shell input tap` 点在 **cell 里面**，宿主 phoc 收不到，droidloom 窗口拿不到
`wl_keyboard.enter` ⇒ `focused_task=None` ⇒ `text_input.rs` **永不发 `enable`** ⇒ 宿主 OSK 不起。
于是「用 adb 点击验键盘」**必然假阴性**（本轮第一次测就是这么误判的）。正确姿势 = 宿主侧 `ydotool` 点输入框拿焦点。
附带探针证据（临时插桩，已回滚）：`focused=None entered=Some(...)` 时无 OSK；`focused=Some(..) entered=Some(..) android_task=Some(65)` 时 OSK 立刻出现。
**已尝试**放宽 `text_input.rs` 的 `focused_task` 判据（`is_none_or`），**未上机证明、已回滚**（现设备上的件 = 纯 T43，sha `8908c37e…`，与原构建逐字节一致）。

## 3. 本次踩到的连带故障：换 phoc 会静默打死 droidloom（**已修一例，缺口待补**）

- 现象：phoc 换好后**小红书打不开**。设备侧 `droidloom.service` = `inactive dead`、`droidloom-applications` 每 2 s 报
  `connect catalog subscription: No such file or directory`。
- 根因：`/usr/lib/systemd/user/droidloom.service` 是 `PartOf=graphical-session.target` + `WantedBy=graphical-session.target`；
  `restart greetd` 撕掉会话 ⇒ 15:13:56 它被停；而新会话起来后 **`graphical-session.target` 仍是 `inactive`（static）**，
  没有任何东西重新 start 它 ⇒ droidloom 不会自己回来（`Restart=on-failure` 也救不了，因为它是被显式 stop 的）。
- 现修：`systemctl --user start droidloom.service`（25 s 内 cell ready），随后
  `adb shell am start -W -n com.xingin.xhs/.index.v2.IndexActivityV2` ⇒ `Status: ok / LaunchState: COLD / TotalTime: 742 ms`（截图 `after-droidloom-restart-xhs.png`）。
- **缺口**：以后每次换 phoc/phosh 或重启 greetd 都要手工补这一步 ⇒ 已登记 T46（自启修复），见 `PITFALLS #759`。

## 4. 产物与证据清单

```
out/phoc-cross-20261128/{phoc,meta.txt}                       # 装进设备的件（T45 零 root 交叉编）
out/phoc-deploy-20261128/
  phoc-dist-0.46.0-1.orig.arm64                               # 发行版原件（527408 B，sha e3ffcfcd…）
  post-install-shell.png / pre-gesture-foot.png / post-gesture-left-edge.png / unlock1.png
  g2.png / g3.png / tap-probe.png / after-droidloom-restart-xhs.png
build/droidloom-51-src/…/release/droidloom-wayland            # 装进设备的 droidloom（T43 补丁，7955888 B）
```

脚本侧同轮改动：`scripts/phoc-install.sh` 的补丁标记检查改成「命中任一标记即算我们的件」
（`linux_drm_syncobj` = 0.59 那批；`phoc-gesture-edge-swipe` = 本条线），此前它对 0.46 件会误报「装的是上游件」。
