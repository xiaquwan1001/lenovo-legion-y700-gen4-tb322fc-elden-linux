# 截图采集记录（2026-11-23 20:09）

- `phosh-desktop-20261123.png`（3040×1902，全分辨率）：ssh root@192.168.7.1 现拍，
  `WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1001 grim /tmp/shot1.png` → scp 回。
- `phosh-desktop-half-20261123.png`（同画面 0.5 倍缩放，224 KB，便于上传）：同轮 `grim -s 0.5`。

内容 = phosh 桌面在跑：顶栏（电池 71%/时间）+ phoc 窗口管理器下并排两个应用窗口
（左侧视频播放器全屏画面、右侧图库缩略图列表），触屏点选操作正常。
设备现态 = vk192 日用，`/` = sda17（190 G），b 槽 marked successful。

未拍到的面（如实说明）：中文输入候选窗（OSK 需点击文本框弹出，远程无法注入触摸）、
A/B 槽切换界面（qbootctl 命令行操作，无 GUI）。候选窗历史截图可备用：
`reports/artifacts/ime-candidates-20261111.png`、`reports/artifacts/ime-osk-firefox-20261111.png`。
