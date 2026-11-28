# phoc MR #829 — `cursor: Add an edge swipe back gesture`

- **MR**：https://gitlab.gnome.org/World/Phosh/phoc/-/merge_requests/829（iid **829**，`opened`，`mergeable`，4 files changed）
- **fork/branch**：`git@gitlab.gnome.org:xuqianhui1001/phoc.git` · `wip/edge-swipe-back`
- **base**：`main` = `5180895`（0.59.0）· **提交**：`4931414cc7d3fd79a9ed67c702ac0c8234f15475`（单提交；已被 CI 要求的 uncrustify 重排 + `Signed-off-by`）
- **创建时间**：2026-11-28T06:03Z（= 14:03 CST）
- **CI**：pipeline **`1154791` = success**（16 success + 1 manual `package-deb-debian-forky:sanitizers:arm64`；先前 `1154790` 在未排版版本上 `failed`，失败项 = `check-format`（uncrustify）+ `check-commit-log`（缺 `Signed-off-by`），已修）
- **最终代码 sha**：`4931414`（含格式重排）；x86_64 与 aarch64 均按该提交重编
- **关联**：#125（正文写 "implements the gesture part of #125"，**没有**用 `Closes` —— 因为 #125 还要动画）

## 编译证据（两架构，均真编）

| 架构 | 命令 | 结果 |
|---|---|---|
| x86_64 | `meson setup build-host -Dembed-wlroots=enabled -Dwlroots:default_library=static` + `ninja src/phoc` | `[3/3] Linking target src/phoc`，0 warning，7,572,896 B |
| **aarch64（目标）** | 同上，在 `/opt/elden/arm64-sid` chroot（wp 1.50 / wlroots 0.20.2 / wayland-server 1.26 / meson 1.13.2） | `[523/523] Linking target src/phoc`，sha256 `47bb43c1…`（commit `4931414` 时重编），max `GLIBC_2.38` ≤ 设备 2.41 |

- 构建脚本：`scripts/build-phoc-mr-arm64.sh`（root/chroot）；日志 `out/phoc-edge-swipe-arm64-20261128/{build.log,meta.txt}`。
- 父代理复验：`PKG_CONFIG_PATH=/tmp/wp-install/share/pkgconfig ninja -C build-host src/phoc` 重跑通过（incremental re-link）。

## 内容边界（这一版不做什么）

- **没有动画**（follow-finger / 松手过渡 / drop shadow 属第二版；可行性见 `reports/gesture-animation-feasibility-20261128.md`）。
- **没有 gsettings 接线**（`edge-width` 只是 GObject 属性，默认 16 逻辑 px）。
- **没有新协议**（逐级 back 意图属于 phosh/协议层）。

## 待办 / 观察点

1. **CI 结果**（pipeline `1154790`）：过了才谈 review；失败就先修（常见 = meson 源列表/编码风格/`-Werror` 新警告）。
2. **设备侧验证**（需一次重启窗）：装 aarch64 产物到 `/usr/bin/phoc`（`dpkg-divert` + 备份，参考 `scripts/phoc-install.sh`），验 ① Firefox 内边缘滑动不滚动网页 ② 中部竖划/捏合不触发 ③ OSK 弹出时不出怪状态 ④ 全屏视频一致。
3. 维护者回复跟进 = T37（每轮 D10 顺带）；有 shape 要求就按 shell 脚本新增的补丁面改。

## 复现（从零）

```sh
git clone --depth 50 https://gitlab.gnome.org/World/Phosh/phoc.git build/phoc-mr-20261128
cd build/phoc-mr-20261128 && git checkout -b wip/edge-swipe-back
git apply /path/to/0001-cursor-Add-an-edge-swipe-back-gesture.patch   # 或 git am
sudo bash /home/xuqianhui/y700-elden/scripts/build-phoc-mr-arm64.sh   # aarch64
```

## 复盘（本轮 CI 的两个必过项）

1. **`check-commit-log`**：缺 `Signed-off-by` ⇒ 直接判红。上游格式 = `component: Summary` + 正文 + `See:`/`Closes:` + `Signed-off-by: Name <email>`，作者/提交者必须是真实身份（子代理起稿用了占位身份 `Elen Dev <dev@elden.local>`，已改回 `Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>`）。
2. **`check-format`**：`.gitlab-ci/check-style.py` 用 uncrustify（本机原先没装，`apt install uncrustify` 0.78 后一致）。该脚本在新 Python 上跑不起来（`argparse.BooleanOptionalAction` 不接受 `type=`，Python 3.14 报 `TypeError`）⇒ 本地把 `type=bool,` 行删掉即可用；`-r` 会走 `git add -p`，**必须 `yes a |` 喂输入**，否则静默不落地（本轮踩过：第一次跑只打印 diff、退出码 0，看起来像"已修"）。
3. `Closes:` 改成 `See:` —— #125 还含动画诉求，本 MR 只实现手势，不应自动关掉该 issue。
