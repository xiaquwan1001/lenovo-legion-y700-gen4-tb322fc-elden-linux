# #467 容器里「早就装好」的 App 可能并不存在；APK 推进容器不能走宿主 data 目录

## 结论（2026-10-29 实测）

① **10-28 记录「Binary Eye 早已装在容器」（`~/.local/share/waydroid/data/app/…`）已失效**：
   本机 `pm list packages` 只有 177 个包，无 `de.markusfisch.android.binaryeye`、**也无
   `net.sourceforge.opencamera`**（10-23 记录里的另一条也已不成立）。`/data/app` 只有 3 个
   GAPPS 相关目录 ⇒ 容器 data 早已被重置过。**凡「镜像里本来就有 X」都要 `pm list packages` 现查**。

② **APK 推进容器不能写宿主 data 目录**：容器 `/data` 是宿主 `/dev/sda18`（f2fs）分区，
   不是 `~/.local/share/waydroid/data`（那个是 `/root/…` 或 `~/.local/share` 下的另一份，未挂载）。
   把 apk 拷到 `~/.local/share/waydroid/data/local/tmp/` 后容器里看不到 ⇒
   `pm install` 报 `Error: Unable to open file` / `Can't open file`。

   **可行做法**（无需 adb）：
   ```sh
   ssh root@dev "lxc-attach -P /var/lib/waydroid/lxc -n waydroid -e -- /system/bin/sh -c 'cat > /data/local/tmp/x.apk'" < x.apk
   ssh root@dev 'L="lxc-attach … -- /system/bin/sh -c"; $L "pm install -r /data/local/tmp/x.apk"'
   ```

③ **APK 来源**：`f-droid.org` 本机直连**超时**（60 s 无响应）；**TUNA 的 F-Droid 镜像可直连且快**：
   - `https://mirrors.tuna.tsinghua.edu.cn/fdroid/repo/index-v2.json`（68 MB，一次拿全量元数据）
   - `https://mirrors.tuna.tsinghua.edu.cn/fdroid/repo/<包名>_<versionCode>.apk`
   - 取到后**必须比对 `index-v2.json` 里的 sha256**（本轮 `binaryeye_180.apk` = `568cec65…`，一致）。

④ Binary Eye 首启会先出 `WelcomeActivity`，`am start …/.activity.CameraActivity` 才是打开相机的入口；
   `SplashActivity` 存在但 `MainActivity` 不存在（`Error type 3` 是正常的，不代表包没装）。
