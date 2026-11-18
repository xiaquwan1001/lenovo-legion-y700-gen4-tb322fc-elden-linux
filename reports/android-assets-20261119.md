# 安卓原厂资产 → Linux 可用包（纯主机侧）

日期 2026-11-19 · lane = android-assets · 设备零接触（无 adb/fastboot/ssh/sudo/loop mount）
产物：`assets/android-20261119/`（319 MiB / **178 文件** / 333,966,309 B，每行 sha256 实测）、
`scripts/android-assets-extract-20261119.py`（可完全重建）、`scripts/asset-install-linux.sh`（--check/--apply/--revert）
中间件：`out/android-assets-20261119/staging/`（812 MB，含 3 个原 apk + 解出的原始资源池，可删；脚本会重建）

## 0. 数字结论

| 类别 | 文件 | 体积 | 说明 |
|---|---:|---:|---|
| `wallpapers/system-media` | 14 | 29.3 MB | `/system/media/wallpapers` 原厂壁纸（3000×3000） |
| `wallpapers/lockscreen` | 1 | 5.3 MB | `/system/media/wallpapers/lockscreen/wallpaper` |
| `wallpapers/zui-wallpaper-setting` | 19 | 136.8 MB | ZUI 壁纸商店 apk 内 ≥1904px 大图（3000×3000，含 1 张 2560×2560） |
| `lockscreen/` | 14 | 74.6 MB | framework-res 三档默认壁纸 + AOSP 锁屏时钟字体图 + 10 张 AOD/锁屏背景（3000×3000 摄影） |
| `sounds/{alarms,notifications,ringtones,ui}` | 112 | 45.1 MB | 9/39/42/22，其中 6 条 `StereoLenovo*` 为 ZUI 专有铃声 |
| `bootanimation/` | 4 | 32.1 MB | boot/shutdown + ZUI×McDonald's 联名两版 |
| `fonts/` | 12 | 10.8 MB | 7 个 `/system/fonts` 特色字体 + 5 个 ZUI 锁屏/AOD 时钟字体 |
| `meta/` | 2 | 4 KB | 壁纸/桌面配置 xml |

MANIFEST 校验：`manifest: 178 行实测 sha256, 不符 0`（`--check` 全量重算，非抽样）。
重复内容 3 组（同内容不同名，均保留原名）：`wallpaper{,_land,_port}`+`default_wallpaper.png`（4）、
`wallpaper_fifa_*`/`wallpapers_fifa`（5）、`wallpapers_pandaer*`（5）。

## 1. 方法与证据（可复现）

只用 `debugfs` 读 ext4 镜像，**不 loop mount、不 sudo**（本会话 sudo 不可用，也不需要）：

```
$ /usr/sbin/debugfs -R "ls -l /system/media" out/android-min-20261118/new/system_a.img
  2923   40755 (2) 0 0     4096 audio
  3040  100644 (1) 0 0  6694287 bootanimation.zip
  3044   40755 (2) 0 0     4096 wallpapers
$ /usr/sbin/debugfs -R "rdump /system/media out/android-assets-20261119/staging/media" <img>
$ /usr/sbin/debugfs -R "dump /system/priv-app/ZuiWallpaperSetting/ZuiWallpaperSetting.apk <out>" <img>
```
`rdump` 会打印 `Operation not permitted while changing ownership`——非 root 正常现象，文件内容已完整落盘（用 `unzip -t`、`file`、Pillow 三把尺子复核）。

尺子：mime = `file --mime-type`（file-5.46）；分辨率 = Pillow 12.1.1（`identify` 本机未装）；
音频时长 = `ffprobe 8.0.1`（vorbis/ogg，例：`sounds/ringtones/StereoLenovoDynamic.ogg` 12.34 s / 44100 Hz / 2ch）；
字体族名 = `fc-scan`。

## 2. 每一项的判用途

- **壁纸**：`/system/media/wallpapers` 是 ZUI 的「默认/人像/横屏/FIFA/Pandaer」主题壁纸；apk 内 19 张是
  **壁纸商店摄影图**（EXIF 显示 Canon EOS 6D / SONY ILCE-7RM4 / NIKON D750），分辨率足够 3040×1904 屏幕。
  apk 里另有 **16 段 mp4 动态壁纸（65.6 MB）未复制**（清单见 `meta/skipped-assets.tsv`）。
- **锁屏**：ZUI 没有独立 `com.zui.*lock*` apk；锁屏资产实际分三处——① `/system/media/wallpapers/lockscreen/wallpaper`；
  ② `framework-res.apk` 的 `default_wallpaper.png` 三档 + `assets/images/clock_font.png`（AOSP 锁屏时钟数字图）；
  ③ `ZuiStandbyMode.apk`（105 MB，息屏/AOD 应用）里的 10 张 3000×3000 背景与 5 个时钟字体
  （`LenovoDigital-2row`、`Rookery New`、`Unisono Quickpath` 等，`fc-scan` 实测族名）。充电动画只找到 AOSP 的
  `stat_sys_battery_charge_anim*.png`（hdpi 小图，未单列）；ZUI 充电动画是代码绘制，无独立大图资产。
- **音效**：112 个 ogg 全部收；`StereoLenovo{Dynamic,Electronic,Gaming,Guitar,PureTone,Symphony}` 6 条是联想自有铃声。
- **开机动画**：`desc.txt` 实测 `3040 1904 20`，part1/2/3 = 9/33/41 帧（PNG 全屏 3040×1904），
  联名版 `3040 1904 30` / 205 帧；关机 `3000 1876`。**只作 Plymouth 参考，不安装**（140 帧 × 3 MB 的容量与 Plymouth
  的脚本式动画模型不匹配，另需 initramfs 集成）。
- **字体**：`ZUKChinese.ttf`（9.0 MB，族名 **Qihei Lenovo / 汉仪旗黑 Lenovo**）= ZUI 中文主字体，
  与 AOD apk 里的 `ne.ttf` 同 sha（`c278a904…`）；`SourceSansPro` 6 个是 ZUI 拉丁正文体。
  Noto CJK 等 32 MB/26 MB 通用字体**不复制**（发行版已有），体积清单见 `meta/fonts-inventory.tsv`。

## 3. 安装脚本（已实测）

`scripts/asset-install-linux.sh`：壁纸 → `/usr/share/backgrounds/elden/`，音效 → `/usr/share/sounds/elden/` +
按 liblycanberra/freedesktop 事件名做 symlink（`power-plug.oga`、`camera-shutter.oga`、`complete.oga`、
`message-new-instant.oga`、`phone-incoming-call.oga`、`battery-{low,caution}.oga`、`button-pressed.oga` 等 15 条），
状态表 `<prefix>/lib/elden-assets/installed.tsv` 支撑精确 `--revert`（含把被顶掉的发行版同名音备份成 `*.elden-bak` 再恢复）。

```
$ bash scripts/asset-install-linux.sh --check          # 默认 prefix=/usr/share，非 root 只读
manifest: 178 行实测 sha256, 不符 0
计划: 复制 117 个文件, 建立 15 个标准名 symlink; bootanimation 4 个 zip 不安装（Plymouth 参考）
$ ELDEN_PREFIX=/tmp/elden-all bash scripts/asset-install-linux.sh --apply --all
APPLIED: 复制 146 文件, 15 symlink; 状态表 /tmp/elden-all/lib/elden-assets/installed.tsv   → 260 MB
$ ELDEN_PREFIX=/tmp/elden-all bash scripts/asset-install-linux.sh --revert
REVERTED: 处理 161 项        # 目标目录回到只剩测试前结构；bell.oga 原件按字节恢复
$ bash scripts/asset-install-linux.sh --apply        # 非 root + /usr/share
FAIL: --apply/--revert 需 root（写 /usr/share）。
```
`--apply` 的两次同参数重跑已验证幂等（状态表仍 161 行，不产生第二份 `*.elden-bak`）。

**gsettings（本机实测键名，脚本只打印不代跑——sudo 下会写 root 的 dconf）**：
```
gsettings set org.gnome.desktop.background picture-uri      'file:///usr/share/backgrounds/elden/elden-wallpaper_port.png'
gsettings set org.gnome.desktop.background picture-uri-dark 'file:///usr/share/backgrounds/elden/elden-wallpaper_port.png'
gsettings set org.gnome.desktop.screensaver picture-uri     'file:///usr/share/backgrounds/elden/elden-wallpaper_port.png'
gsettings set org.gnome.desktop.sound theme-name freedesktop   # 键名是 theme-name（不是 theme）
```
Phosh 侧核实（`gsettings list-schemas|list-keys`）：`sm.puri.phosh.lockscreen` **只有** `require-unlock`、`shuffle-keypad`，
**没有锁屏壁纸键** ⇒ 锁屏背景只能走 `org.gnome.desktop.screensaver.picture-uri` / 跟随桌面；
音效同理需把 sound theme 切到 `freedesktop` 才命中上面那批事件名（Ubuntu 默认 `Yaru`）。

装脚本用 `set -o pipefail` 时踩到过一个坑并已修：`gsettings list-schemas | grep -qx <schema>` 中 `grep -q`
提前退出会给 gsettings 发 SIGPIPE（141），pipefail 下整条管道判失败 ⇒ 偶发误报「schema 无」。改为先取字符串再 `grep -qx <<<`。

## 4. 合法性

资产来自**本机设备的原厂固件镜像**（`/system`、随包 `framework-res.apk`/ZUI apk），仅供本机个人使用（本机桌面/锁屏美化），
**不再分发、不随仓库提交**（`.gitignore` 已加 `/assets/android-20261119/`；重建靠脚本，不靠入库字节）。
未从网络下载任何第三方素材。

## 5. 可复现命令

```
python3 scripts/android-assets-extract-20261119.py           # staging(必要时 debugfs 重 dump) → assets 树 + MANIFEST
python3 scripts/android-assets-extract-20261119.py --clean   # 删 staging/assets 后全量重来（~1 min + 812 MB）
bash scripts/asset-install-linux.sh --check                  # 校验 + 计划（无需 root）
sudo bash scripts/asset-install-linux.sh --apply [--all] [--fonts]
sudo bash scripts/asset-install-linux.sh --revert
```

## 6. 未决 / 边界

1. **`/product`、`/system_ext` 是本精简镜像里的空目录**（原为 super 内的独立分区）⇒ `/product/media/**`（可能含另一套
   bootanimation/音效）与 `/system_ext` 内容**未覆盖**。需要时按 `tools/android-super-bin/lpunpack` 从
   `~/文档/TB322FC_15.10.259/super_*.img` 拆 product/system_ext 再跑同一脚本（预计 +几分钟，主机剩 115 GB 可用）。
2. **锁屏/AOD 字体是资源名混淆件**（`gm.ttf`/`fF.otf`/`-I.otf`…）：族名已用 fc-scan 标注在 MANIFEST 用途列，
   但哪个家族对应哪套锁屏时钟样式需上机目视比对（本轮设备锁在 fastboot/Android，未做）。
3. `--apply` 只做过 `ELDEN_PREFIX=/tmp` 演练；写 `/usr/share` 与 gsettings 生效需主代理以 root + 桌面用户身份执行。
4. 动态壁纸 16 段 mp4（65.6 MB）、主题图标 mask 包（`/system/etc/themes/*/res.zip`，非壁纸）只登记未复制，
   清单在 `meta/skipped-assets.tsv` 与 `meta/themes-info.txt`。
