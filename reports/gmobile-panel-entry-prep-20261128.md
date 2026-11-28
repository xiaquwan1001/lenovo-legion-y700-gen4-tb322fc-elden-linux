# T33 素材 — 自建 gmobile `lenovo,elden` 显示面板条目（圆角/刘海避让）

- **日期**：2026-11-28（主机侧素材，未改设备、未编任何件）
- **背景**：本机 `border_radius=0`（phosh 顶栏不内缩、无刘海遮罩），因为 gmobile 的 display-panels 表里没有本机条目。
- **本轮目标**：把「能不能自建、要什么值、怎么装、怎么验收」写成可执行素材，**不 patch 二进制**。

## 0. 一句话结论

**能自建，但只能重编 `libgmobile`（或上游 MR），运行时放 JSON 无效**；识别键已确定 = DT compatible **`lenovo,elden`**（文件名必须叫 `lenovo,elden.json`）。
面板几何真值 = **1904×3040、8.8" 16:10、无挖孔**；唯一缺的真值是**圆角半径**（原厂 Android 确认启用了硬件圆角，但半径不在可读文本里）⇒ 下一步 = 量半径 → 编进条目 → 用「顶栏是否内缩」验收。

## 1. 加载机制（已逐行核对源码/装机件，可复现）

| 事实 | 证据 |
|---|---|
| 查找键 = **设备树 compatible，按顺序逐个试** | 上游 `src/gm-device-info.c`：`for (i…) filename = "<compatible>.json"; resource = /mobi/phosh/gmobile/devices/display-panels/<filename>` |
| 本机 compatible 顺序 | `/sys/firmware/devicetree/base/compatible` = `lenovo,elden\0qcom,sm8750\0` ⇒ 第一条就是 **`lenovo,elden`** |
| 条目编译进 **gresource**，不是磁盘文件 | `data/gmobile.gresources.xml` 逐条 `<file preprocess="json-stripblanks">devices/display-panels/….json</file>`，由 `data/meson.build` 的 `gnome.compile_resources()` 打进 `libgmobile.so` |
| 装机件里确实没有 JSON 文件 | `dpkg -L libgmobile0 libgmobile-common` 无 display-panels；`strings libgmobile.so.0` 里能看到内嵌的 `"border-radius": 93` 等 JSON 片段 |
| 本机版本/形态 | `libgmobile0 0.3.1-1`（Debian trixie）+ phosh 0.46；**0.3.1 的键是标量 `border-radius`**（`strings` 无 `corner-radii`）；上游 `main` 已改成 `corner-radii: [4 值]` |

⇒ **部署方式只有两条**：(a) 用 Debian 源码包重编 `libgmobile` 并替换 `libgmobile.so.0`（下游补丁）；(b) 向上游 gmobile 提 MR 让条目进官方包。**不能**往 `/usr/share/gmobile/...` 丢 JSON。

## 2. 面板几何真值

| 量 | 值 | 来源 |
|---|---|---|
| 分辨率 | **1904 × 3040**（竖）/ 3040×1904（横） | 设备 `wlr-randr`、`/sys/class/drm`、DRM modes |
| 尺寸/比例 | **8.8"、16:10** | 官方发布页 / 多家媒体（3040×1904、8.8 英寸） |
| 机身 | **207.58 × 128.5 × 6.99 mm** | 官方对比图与发布稿（见下「素材链接」） |
| 有效显示区（推算） | **118.6 × 189.4 mm**（由 8.8" 对角 + 16:10 算） | 计算；误差 <1% |
| 像素密度 | **≈16.05 px/mm** | 1904 / 118.6 |
| 挖孔/刘海 | **无**（官方：无开孔设计） | 发布稿；`dumpsys window` 的 `mDisplayCutout` 为空（cell 侧） |
| 圆角 | **有硬件圆角**，半径待测 | 原厂 ROM `super_6.img` 里 `vendor.display.enable_rounded_corner=1` 与 SDM 的 `RCDriverIntfImpl`/`PostPrepareJsonBasedRC` 字符串；但半径是面板 RC blob，不在可读文本 |

> **圆角半径是本条目唯一的未知量。** 说明：`adb screencap`/`grim` 看到的四角都是方的（软件帧缓冲不体现物理遮罩），所以不能从截图读；原厂 Android 的 `mRoundedCorners` 在 droidloom cell 里被 `org.droidloom.framework.display.overlay` 归零。

**测量协议（下一步，二选一）**

1. **实物尺量**（最省事）：屏幕全白 → 用直尺量左上角弧线起止点的切点距离 `d`（mm），半径 `r ≈ d`；`border-radius(px) = round(r_mm × 16.05)`。
2. **官图量**：找正面正视高清渲染图，量「显示区角弧半径 / 显示区短边」的像素比 `k`，则 `radius_px = k × 1904`。

**候选带（仅作编译试值，不作结论）**：同类圆角手机条目实测半径 6–8 mm（`fairphone,fp5` 135 px/18 px·mm⁻¹ ≈ 7.5 mm、`motorola,river` 118/15.88 ≈ 7.4 mm）；
本板 px/mm≈16.05 ⇒ **≈96–136 px（6–8.5 mm）**是合理起测带。先用 **120 px** 编一版看顶栏内缩量，再按实物微调。

## 3. 可直接用的条目（草稿）

两套 schema 都已放好（半径字段待替换）：

- `patches-userland/gmobile-elden-20261128/lenovo,elden.json` —— **本机 0.3.1 用**（标量 `border-radius`）：
  ```json
  {"name":"Lenovo Legion Y700 Gen4","x-res":1904,"y-res":3040,
   "border-radius":0,"width":119,"height":189,"cutouts":[]}
  ```
- `patches-userland/gmobile-elden-20261128/lenovo,elden.upstream.json` —— **上游 main 用**（`corner-radii:[r,r,r,r]`）。

条目形态对照（上游 `main`，实测抓取）：`fairphone,fp5.json` =
`{"name","x-res","y-res","corner-radii":[135,135,135,135],"width","height","cutouts":[{"name":"notch","path":"M …"}]}`；
本机 0.3.1 的 `fairphone,fp5` 内嵌片段 = `{"name","x-res","y-res","border-radius":100,"width","height","cutouts":[…]}`。

`cutouts` 留空数组 = 不做遮罩（本机无开孔，正确）。

## 4. 构建路径（**本轮不执行**，给下一步）

```sh
# 0) 取 Debian 源码（0.3.1，与本机同版）
cd /tmp && curl -LO https://deb.debian.org/debian/pool/main/g/gmobile/gmobile_0.3.1.orig.tar.xz
tar xf gmobile_0.3.1.orig.tar.xz && cd gmobile-0.3.1
# 1) 放条目 + 在 gresource 里登记（文件名必须 = compatible）
cp <repo>/patches-userland/gmobile-elden-20261128/lenovo,elden.json data/devices/display-panels/
sed -i '/purism,librem5.json/a\    <file preprocess="json-stripblanks">devices/display-panels/lenovo,elden.json</file>' \
    data/gmobile.gresources.xml
# 2) 交叉编（需 aarch64 sysroot；本机 sysroot 现不在盘，先跑 rootfs/build-sysroot.sh 或走 build-slot）
meson setup _b --cross-file rootfs/cross-aarch64.ini --prefix=/usr -Dgtk_doc=false
ninja -C _b && DESTDIR=/tmp/gm-root ninja -C _b install
# 3) 部署（先备份；替换 .so 要 dpkg-divert/hold 思路同 PITFALLS #654）
sudo cp /usr/lib/aarch64-linux-gnu/libgmobile.so.0.300.1{,.bak-20261128}
sudo install -m644 /tmp/gm-root/usr/lib/aarch64-linux-gnu/libgmobile.so.0.300.1 /usr/lib/aarch64-linux-gnu/
```

> 备选：直接在 `data/` 加 JSON，用 GNOME 的 `glib-compile-resources` 单独编一个 gresource **覆盖**? —— **不行**：gmobile 的 lookup 固定读 `/mobi/phosh/gmobile/...` 且 `.so` 里已注册自己的 prefix；只能换 `.so`。
> 若要避开重编：升级到 Debian pool 里的 `gmobile 0.7.5` + phosh ≥0.5x（ABI/schema 一起动）属另一条升级线，不在本条目范围。

## 5. 可验收的下一步（本报告建议的「一条」）

**目标**：`border-radius` 取自实测值（先 120 px 试装）后，phosh 顶栏在左上/右上角自动内缩，且 phosh 0.46 布局不破。

判据（全绿才算成）：

1. **lookup 命中**：`gdbus`/小 C 程序调 `gm_device_info_new({"lenovo,elden"})` + `gm_device_info_get_display_panel()` 返回非 NULL，`gm_display_panel_get_border_radius()` = 设定值。
2. **视觉**：宿主 `grim` 截图里顶栏左端图标不再压在圆角上（对比装前/装后同图裁左上 120×120）。
3. **布局不破**：`systemctl --failed` = 0、phosh/phoc 进程在、`deploy-desktop-shell.sh --check` MISS=0、`grim` 截图 > 20 KB 且有顶栏。
4. **可回退**：`.so.bak-20261128` 一条 `cp` 还原；`ldconfig -p | grep gmobile` 版本号不变。
5. **不写死来源**：条目随 Debian 包重装会丢 ⇒ 若要长期保留，需固化成下游 patch / 上游 MR（与 `PITFALLS #654` 同型的「自编件被包管理器冲掉」风险）。

**上游化（顺路，按 §7 口径只立账不投）**：条目本身是纯数据，适合直接提 gmobile MR（`lenovo,elden.json` + gresource 一行）。要不要提，等本机验完半径再说。

## 6. 素材链接（本轮实际抓取/核对）

- 上游表 38 条（`data/devices/display-panels/`，GitLab `World/Phosh/gmobile`，project 22559，`main`）；本机 0.3.1 内嵌 26 条
- `fairphone,fp5.json`（上游 main，几何形态样例）
- 官方/媒体规格：8.8" 16:10、3040×1904、机身 207.58×128.5×6.99 mm、无开孔（联想发布稿与 gamersky/新浪/搜狐转载；检索词与命中见下一行）
  - gsmarena `lenovo_legion_y700_(gen_4)-13993`、devicespecifications `10c564ee`、gamersky `202505/1924006.shtml`、搜狐 `a/893283833_163726`（含官方对比图，确认 207.58×128.5 mm）
- 原厂 ROM `backup/official-rom-15.10.259/super_6.img`：`vendor.display.enable_rounded_corner=1`、SDM `RCDriverIntfImpl`/`PostPrepareJsonBasedRC` 字符串
