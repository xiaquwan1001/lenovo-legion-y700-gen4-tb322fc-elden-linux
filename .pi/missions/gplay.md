# 任务：在安卓容器中启用 Google Play 认证 + Google 账号登录（Waydroid）

你是 y700-elden（联想 Y700 四代 TB322FC / SM8750 / Alpine musl 宿主）项目的集成工程师。工作目录 `~/y700-elden`。先读 `INDEX.md`、`WAYDROID-2026-10-01.md`、`WAYDROID-AOSP-AUDIT-2026-10-01.md`。

## 现状
- 设备在线：`ssh root@192.168.7.1`。`waydroid status` 显示 Session/Container RUNNING，Vendor type **MAINLINE**，IP 192.168.240.112。
- 容器用的是**自编 Mesa 26.1.8**（bind-mount 已配置）+ AOSP 镜像；宿主为 Alpine(musl)，LXC 启动已修好（pulse 挂载 optional）。
- 项目内有 `waydroid-ota/`（system/vendor 镜像目录），可复用。

## 目标
让 Waydroid 里的 **Google Play 服务能登录 Google 账号**，并且 **Play Store 显示已认证（Play Integrity / 设备认证通过）**。开源或闭源方案均可。

## 建议路线（自行判断取舍）
1. **查明当前镜像**：`waydroid-ota/` 是 vanilla 还是含 GAPPS；用 `waydroid prop get` / `waydroid.cfg` / `session` 日志确认。
2. **装 GApps**：优先用 Waydroid 官方 **GAPPS 镜像**（SourceForge，注意本机代理 127.0.0.1:7897；大文件下载参考记忆里的 Motrix/代理坑），或用 MindTheGapps/OpenGApps 刷入 system。
3. **设备认证**：获取 `android_id`（GSF），到 `google.com/android/uncertified` 注册；必要时用 **Magisk + PlayIntegrityFix/PlayCurl 之类**，或 `waydroid prop set` 伪造 `ro.product.*`/指纹。
4. **登录**：在 Waydroid 里完成 Google 账号登录，验证 Play Store 能正常使用。

## 关键约束（务必遵守）
- **先备份现有可用的 waydroid 镜像/配置**（复制到 `backup/` 或加 `.bak-*` 后缀），任何改动可回退。
- 改动镜像/容器前**先向协调者（SageYak）报告一次**，避免与其它设备任务（音频刷 boot、性能测试）冲突。
- 宿主是 musl，注意脚本兼容；SSH 长睡会超时——启动后台任务用 `nohup ... &` 立即返回，再短命令轮询。
- 不刷 boot/内核、不动 `/data`（宿主），只操作 Waydroid 相关文件。

## 交付物
- 文档 `GPLAY-2026-10-02.md`（写在 `~/y700-elden/`）：镜像来源、安装步骤、认证方法、验证结果（Play Store 截图/日志证据）、回退方法。
- 结论与证据写入 `task progress` / `task done`；完成后 `task done` 退出。
