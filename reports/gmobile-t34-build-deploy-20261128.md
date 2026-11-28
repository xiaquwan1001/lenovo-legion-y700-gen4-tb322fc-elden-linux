# T34 — 本机编 `libgmobile` 带 `lenovo,elden` 面板条目并验收（2026-11-28）

- **范围**：T33 的本机侧（上游 MR `!131` 已提）。目标 = 用 Debian 源码重编 `libgmobile 0.3.1`、把条目编进 gresource、装到设备并按 `reports/gmobile-panel-entry-prep-20261128.md` §5 五条判据验收。
- **一句话结论**：**库编好装好、lookup 命中（`border-radius=80`）**；**但 80 px 半径在本机 `scale=3` 下算出 `corner_shift=7 < MIN_PADDING=9` ⇒ 顶栏像素级零变化是「正确结果」，不是没生效** —— 用 `radius=600` 对照证明管线确实生效（图内首墨 x：27 → 417 px）。
- **判据 2（"装后顶栏必然内缩"）按实测改写**：本机不需要内缩即已避让。证据与阈值推导见 §4。

## 0. 数字结论

| 判据（prep 报告 §5） | 结果 |
|---|---|
| 1 `gm_device_info_get_display_panel()` 命中 | ✅ 装前 `panel=NULL`；装后 `name=Lenovo Legion Y700 Gen4 / border-radius=80 / width=119 height=189`（用 `gm_device_tree_get_compatibles()` 取真 compatible 列表 `lenovo,elden` + `qcom,sm8750` 复现 phosh 的取法） |
| 2 视觉（grim 装前/装后左上·右上 160×160 对比） | ⚠️ **改写为「无差异且理由已证」**：装前/装后整屏 **sha256 完全相同**（`b0ef566a…`）；`radius=600` 对照 ⇒ 首墨 x 27→417、整屏 bbox `(27,24,1875,1517)` ⇒ 管线生效，80 px 只是低于阈值 |
| 3 布局不破 | ✅ `systemctl --failed` = 0 个单元；`scripts/deploy-desktop-shell.sh --check` → **MISS=0（达标）**；phosh/phoc 进程在 |
| 4 可回退 | ✅ 三条并存：`.bak-20261128`（原包件，sha `293fea73…`）、`dpkg-divert` 目标 `.dpkg-dist`、`apt-mark hold libgmobile0` |
| 5 包管理器覆盖风险 | ✅ 已用 `dpkg-divert --divert …dpkg-dist --rename` + `apt-mark hold`（PITFALLS #654 同型）；重建/升级要重打 |

## 1. 构建（主机侧，未在平板上编）

```sh
# 1) trixie arm64 sysroot（只因 rootfs/build-sysroot.sh 的包表是 Mesa 用，见 §5 修法）
SUITE=trixie MIRROR=http://deb.debian.org/debian \
PKGS_ENV="libgio-2.0-dev libglib2.0-0t64 libjson-glib-1.0-0 libjson-glib-dev libffi-dev libffi8 \
libpcre2-dev libpcre2-8-0 libsysprof-capture-4-dev libmount-dev libmount1 libselinux1-dev libselinux1 \
libsepol-dev libsepol2 uuid-dev libblkid-dev libblkid1 zlib1g-dev zlib1g libc6 libgcc-s1 libc6-dev linux-libc-dev" \
SYSROOT=$PWD/out/sysroot-trixie-arm64 bash rootfs/build-sysroot.sh      # 193 MB

# 2) 源码（0.3.1 = 设备同版）+ 放条目 + 登记 gresource
curl -LO https://deb.debian.org/debian/pool/main/g/gmobile/gmobile_0.3.1.orig.tar.xz
# cp patches-userland/gmobile-elden-20261128/lenovo,elden.json data/devices/display-panels/
# 并在 data/gmobile.gresources.xml 的 purism,librem5.json 之后加一行 <file …lenovo,elden.json</file>

# 3) 交叉编（新 cross file，见 §5）
meson setup _b --cross-file rootfs/cross-aarch64-gmobile.ini --prefix=/usr \
  -Dgtk_doc=false -Dintrospection=false -Dvapi=false -Dtests=false -Dexamples=false -Dman=false
ninja -C _b && aarch64-linux-gnu-strip --strip-unneeded _b/src/libgmobile.so.0
```

产物：68 824 B，sha256 `5e631b75520021ecc0768ca94087ca85ce08c08ce53e7e9c7f12438335f85211`（`/tmp/libgmobile.so.0.elden`）。

> 编时告警一条如实记录：`json-stripblanks` 预处理因主机无 `json-glib-format` 被跳过（资源未压空白，不影响功能）。

## 2. 部署（设备侧）

```sh
P=/usr/lib/aarch64-linux-gnu/libgmobile.so.0
sudo cp -a $P ${P}.bak-20261128
sudo dpkg-divert --divert ${P}.dpkg-dist --rename $P
sudo install -m644 libgmobile.so.0.elden $P
sudo ldconfig          # 报 "/lib/aarch64-linux-gnu/libgmobile.so.0 不是符号链接"（该件非符号链接，soname 解析不受影响）
sudo apt-mark hold libgmobile0
```

- 装前设备件 = Debian `libgmobile0 0.3.1-1`（67 600 B，2025-05-29，sha `293fea73…`）。
- phosh 侧确认真的加载新件：`/proc/<phosh-pid>/maps` 的 gmobile 四段与 `/usr/lib/aarch64-linux-gnu/libgmobile.so.0` **inode 相同（26401）**。

## 3. 验收数据

| 实验 | 命令要点 | 结果 |
|---|---|---|
| lookup（装前） | `./t`（系统 `libgmobile`） | `panel=NULL` rc=3 |
| lookup（装后） | `./t`（系统路径，不带 `LD_LIBRARY_PATH`） | `name=Lenovo Legion Y700 Gen4 / border-radius=80` rc=0 |
| phosh 取法复现 | `./t2` 用 `gm_device_tree_get_compatibles()` | `compat: lenovo,elden` / `compat: qcom,sm8750`，panel 命中 |
| 视觉 A/B（80 px） | 原包件 vs 新件，各 `systemctl restart greetd` + `grim` | 整屏 sha256 相同 `b0ef566a…` |
| 视觉对照（600 px） | 同上，只改 `border-radius`=600 | 首墨 x **27 → 417**，整屏 diff bbox `(27,24,1875,1517)` |
| 布局 | `systemctl --failed` / `deploy-desktop-shell.sh --check` | 0 单元 / **MISS=0** |

截图与裁图：`reports/artifacts/gmobile-elden-20261128/`（`1-before-restart`、`2-after-restart`、`3-radius600`、`4-radius80-retest`、`5-baseline-origlib`、`6-radius80-confirmed` + 160×160 四角裁图）。

## 4. 为什么 80 px 不动（阈值推导，可复核）

phosh 0.46 `src/layout-manager.c:get_corner_shift()`（`git show v0.46.0:src/layout-manager.c`）：

```
r = c = gm_display_panel_get_border_radius(panel) / scale;      # 逻辑 px
b = c - (TOP_BAR_HEIGHT - 0.8*ICON_PIXEL_SIZE)/2 = c - 9.6;      # 32, 16
a = floor(sqrt(c*c - b*b));
shift = MAX(PHOSH_TOP_BAR_MIN_PADDING /*9*/, ceil(r - a));
```

设备 `wlr-randr`：**`Scale: 3.000000`**（DSI-1，1904×3040）。

- `radius=80` ⇒ `c=26.67`、`b=17.07`、`a=20.50` ⇒ `ceil(c-a)=7` **< 9** ⇒ `shift=9` = 默认内边距 ⇒ 与无条目时**逐像素相同**（实测 sha 相同，吻合）。
- 反解阈值：`c - sqrt(19.2c - 92.16) > 9` ⇒ `c ≳ 31.6` 逻辑 px ⇒ **原始半径 ≳ 95 px** 才可能改变顶栏。
- `radius=600` ⇒ `c=200` ⇒ `shift=139` 逻辑 = 417 物理 ≈ 实测 27→417。✅

⇒ 结论：**80 px 圆角（=26.7 逻辑 px）落在 phosh 默认 9 逻辑 px 内边距覆盖范围内，本机无需额外内缩**。条目本身正确（原厂 persist dump 的 `RoundedCorner radius=80`），上游 `!131` 无需因此改值。
若日后要"看得见"圆角避让，那不是改半径，而是**改 phosh 侧**（如让 MIN_PADDING 依半径推导），属上游议题，不在本机打补丁范围。

## 5. 顺手修掉的两个工具坑（都已落地）

1. **`rootfs/build-sysroot.sh` 默认 `SYSROOT` 指向不存在的 `/home/xuqianhui1001/y700-elden/…`**（旧用户名）⇒ 按默认跑必失败。已改为按仓根推导，并新增 `SUITE` / `MIRROR` / `PKGS_ENV` 覆盖口。
2. **`rootfs/cross-aarch64.ini` 写死 `/TB322FC/out/sysroot-arm64`**（该路径本机不存在；prep 报告 §4 照抄该文件必然失败）。已新增 `rootfs/cross-aarch64-gmobile.ini` 指向 `out/sysroot-trixie-arm64`；Mesa 那份保持原样（其路径是历史约定，改动风险另议）。

## 6. 复现命令（一条流）

```sh
meson setup _b --cross-file rootfs/cross-aarch64-gmobile.ini --prefix=/usr -Dgtk_doc=false \
  -Dintrospection=false -Dvapi=false -Dtests=false -Dexamples=false -Dman=false && ninja -C _b
scp _b/src/libgmobile.so.0 elden:/tmp/gmtest/  # 之后按 §2 装、按 §3 判
```

## 7. 残留

- 本机保留新件（inert：80 px 无视觉变化；一旦 phosh 侧阈值策略变化即会生效）。升级/重建后需重打（divert+hold 已记）。
- 上游 `!131` 的 review 跟进 = T37（D10 lane 每轮报）。
