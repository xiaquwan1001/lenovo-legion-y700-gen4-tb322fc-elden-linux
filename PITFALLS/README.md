# 踩坑总表（TB322FC / elden mainline Linux）

> 📇 **先看 `INDEX.md`**（文档地图 + 状态裁决）。
> **给下一个会话：先读 `INDEX.md`（文档结构），再扫本文件。** 这里全是花过代价换来的教训，按主题归类。
> **本文件 = 开发经验（踩坑）唯一入口**；**「谁执行、允不允许自动跑」的行为/授权标准在 `.pi/AGENT-OPS.md`**，本文件不定义授权边界。
> 最后更新：2026-10-18。**条目编号 #1–#315**（统一 `N. **标题**` 列表；条目按主题分节，物理顺序不随编号单调）。
> 最新条目集中在文末分节 §十六–§三十；**编号范围只在本行维护**，其它文档不复述具体数字。

---

## 0. 零号纪律（动手前先做这四件事）

- **先查本地既有结论再取证**：`grep -rn -iE "unlock|解锁|rollback|testkey|GPT|EDL" ~/y700-elden/*.md archive/topics/*.md .pi/skills/*/references/*.md`（PITFALLS #87）。
- **动分区/刷写前备份**：**本机 ABL 无 `fastboot fetch`**（实测 `Unable to get max-fetch-size`，**#290**）⇒ 设备侧 `dd if=/dev/disk/by-partlabel/<part>` 后取回 / 官方线刷包解出 / EDL 读回，三选一 + GPT 双表 dump；**写后读回校验**（不看"传输完成"）。
- **单一远程通道的持久系统上不做自锁式实验**（电源/熄屏/网络）；用 `fastboot boot` **零写盘**验证，而非直接改 flash。
   ⚠️ **两种「RAM 启动」别混**（#92/#93）：`-ram` 纯 RAM 变体**不启桌面/会话服务**，只适合内核/引导/分区级验证；
   **功能/服务级测试（桌面、PipeWire、蓝牙音频、Waydroid、相机出流）必须 `fastboot boot` 持久变体**（RAM 内核 + 磁盘根，同样零写盘）。
- **无设备证据不得写「已修复/已解决」**（2026-10-06 新增）：主机侧构建/编译/能进 BDS 一律只算「未上机验证」；间歇性故障**单次样本无效**（须同口径量化 + 单变量 + 长时窗）。见 `archive/topics/SESSION-AUDIT-2026-10-06.md` §3（F2/F4）。
   参 #87、#92、#93、复盘-持久化与睡眠。

> **行为/授权（谁手敲 fastboot、何时停下请用户物理干预、何时可自主执行）见 `.pi/AGENT-OPS.md` §1；本节只讲「动手前该掌握的事实」。**

## 节 → 文件 索引

| 节 | 文件 |
| --- | --- |
| 一、引导 / fastboot / 重启交接 | [sessions/01-引导fastboot重启交接.md](sessions/01-引导fastboot重启交接.md) |
| 二、内核 / DTS / 构建 | [sessions/02-内核DTS构建.md](sessions/02-内核DTS构建.md) |
| 三、存储 / 分区 / 持久化 | [sessions/03-存储分区持久化.md](sessions/03-存储分区持久化.md) |
| 四、固件 / 外设（反提取 vendor 资源） | [sessions/04-固件外设.md](sessions/04-固件外设.md) |
| 五、设备上装包 / 环境 | [sessions/05-设备上装包环境.md](sessions/05-设备上装包环境.md) |
| 六、脚本 / 工具 | [sessions/06-脚本工具.md](sessions/06-脚本工具.md) |
| 七、Wayland / 桌面（weston） | [sessions/07-Wayland桌面.md](sessions/07-Wayland桌面.md) |
| 八、恢复 Android / 免解 BL root 资产（2026-09-29） | [sessions/08-恢复Android免解BLroot资产.md](sessions/08-恢复Android免解BLroot资产.md) |
| 九、WiFi / ath12k / 装包（2026-09-29） | [sessions/09-WiFiath12k装包.md](sessions/09-WiFiath12k装包.md) |
| 十、桌面 / Phosh（2026-09-29） | [sessions/10-桌面Phosh.md](sessions/10-桌面Phosh.md) |
| 十一、存储 / TF 卡 / 扩分区（2026-09-29） | [sessions/11-存储TF卡扩分区.md](sessions/11-存储TF卡扩分区.md) |
| 十二、userdata 缩容（TWRP 路线实测结论，2026-09-29） | [sessions/12-userdata缩容.md](sessions/12-userdata缩容.md) |
| 十三、AVB / 免签 / KSU（2026-09-29 实测） | [sessions/13-AVB免签KSU.md](sessions/13-AVB免签KSU.md) |
| 十四、睡眠 / 挂起（2026-09-29） | [sessions/14-睡眠挂起.md](sessions/14-睡眠挂起.md) |
| 十五、过时 / 废弃 / 功能缺陷登记（DEPRECATED） | [sessions/15-过时废弃功能缺陷登记.md](sessions/15-过时废弃功能缺陷登记.md) |
| 十六、自动旋转方向锁死 / 开关置灰 — iio-sensor-proxy 启动时序（2026-10-09 实测） | [sessions/16-自动旋转方向锁死开关置灰—iio-sensor-proxy启动时序.md](sessions/16-自动旋转方向锁死开关置灰—iio-sensor-proxy启动时序.md) |
| 十七、设备侧自动化踩坑：会话总线 / DPMS / 传感器总线（2026-10-09 实测） | [sessions/17-设备侧自动化踩坑：会话总线DPMS传感器总线.md](sessions/17-设备侧自动化踩坑：会话总线DPMS传感器总线.md) |
| 十八、GUI/GPU 负载压测与「gfx 电源域」读法（2026-10-09 实测更正） | [sessions/18-GUIGPU负载压测与「gfx电源域」读法.md](sessions/18-GUIGPU负载压测与「gfx电源域」读法.md) |
| 十九、重启通道 / A/B 槽位 / ramdisk 层叠 / Q28 判据（2026-10-09 深夜实测） | [sessions/19-重启通道AB槽位ramdisk层叠Q28判据.md](sessions/19-重启通道AB槽位ramdisk层叠Q28判据.md) |
| 二十、相机模块加载：一天之内第三次栽在"静默跳过"上（2026-10-09 深夜实测） | [sessions/20-相机模块加载：一天之内第三次栽在"静默跳过"上.md](sessions/20-相机模块加载：一天之内第三次栽在"静默跳过"上.md) |
| 二十一、相机 ⇄ 熄屏 = 互斥（不是"偶发风险"）+ 新工具自测暴露的坑（2026-10-09 深夜） | [sessions/21-相机⇄熄屏=互斥+新工具自测暴露的坑.md](sessions/21-相机⇄熄屏=互斥+新工具自测暴露的坑.md) |
| 二十二、构建守卫 & Q28 变量纠正（2026-10-10 编排轮） | [sessions/22-构建守卫&Q28变量纠正.md](sessions/22-构建守卫&Q28变量纠正.md) |
| 二十三、Q24 复现定案 + Q28「版本串」变量 + 测试协议陷阱（2026-10-11 实测） | [sessions/23-Q24复现定案+Q28「版本串」变量+测试协议陷阱.md](sessions/23-Q24复现定案+Q28「版本串」变量+测试协议陷阱.md) |
| 二十四、Waydroid 容器（音频/媒体） | [sessions/24-Waydroid容器.md](sessions/24-Waydroid容器.md) |
| 二十五、Q28 冷起判定 = 内核构建身份（版本串）法则 + 冷起 A/B 测补丁作废（2026-10-11 实测） | [sessions/25-Q28冷起判定=内核构建身份法则+冷起AB测补丁作废.md](sessions/25-Q28冷起判定=内核构建身份法则+冷起AB测补丁作废.md) |
| 二十六、跨树驱动比对的方法陷阱：`to_primary_dsi` DSI0/DSI1 伪线索（2026-10-12 静态核查） | [sessions/26-跨树驱动比对的方法陷阱：to_primary_dsiDSI0DSI1伪线索.md](sessions/26-跨树驱动比对的方法陷阱：to_primary_dsiDSI0DSI1伪线索.md) |
| 二十七、Q24 台架/工具链教训（2026-10-12 第 3 轮实测） | [sessions/27-Q24台架工具链教训.md](sessions/27-Q24台架工具链教训.md) |
| 二十八、上游邮件通道（2026-10-12 实测定案） | [sessions/28-上游邮件通道.md](sessions/28-上游邮件通道.md) |
| 二十九、Waydroid 马达透传（vibrator HAL → aw86927 FF）（2026-10-13 实测） | [sessions/29-Waydroid马达透传.md](sessions/29-Waydroid马达透传.md) |
| 三十、Waydroid 马达透传二期：AIDL HAL 替换（2026-10-13 下午实测） | [sessions/30-Waydroid马达透传二期：AIDLHAL替换.md](sessions/30-Waydroid马达透传二期：AIDLHAL替换.md) |
| 三十一、M1-7.3（7.3-rc7 重基树）上机：缺 `=m` 模块被误判为代码回归（2026-10-13 深夜实测） | [sessions/31-M1-7.3上机：缺=m模块被误判为代码回归.md](sessions/31-M1-7.3上机：缺=m模块被误判为代码回归.md) |
| 三十二、上游显示栈 bring-up（P1–P2c 臂）：DRM GOOD ≠ 面板有画面（2026-10-13 深夜） | [sessions/32-上游显示栈bring-up：DRMGOOD≠面板有画面.md](sessions/32-上游显示栈bring-up：DRMGOOD≠面板有画面.md) |
| 三十三、盯“精确 UTS / 单变量打包”的三连坑（2026-10-14 E1 实测） | [sessions/33-盯“精确UTS单变量打包”的三连坑.md](sessions/33-盯“精确UTS单变量打包”的三连坑.md) |
| 三十四、WCN MHI 首探必然失败、重发即成功（2026-10-14 E3/E3a/E3c/E4 实测） | [sessions/34-WCN首探MHI必失败重发即成功.md](sessions/34-WCN首探MHI必失败重发即成功.md) |
| 三十五、WCN 首探修法：只有「整轮重探」有效（2026-10-15 F1/F2/F3 实测） | [sessions/35-WCN首探修法：只有整轮重探有效.md](sessions/35-WCN首探修法：只有整轮重探有效.md) |
| 三十六、构建落点（内存盘）与调试信息实测（2026-10-15 实测） | [sessions/36-构建落点与调试信息实测.md](sessions/36-构建落点与调试信息实测.md) |
| 三十七、Q28 arm A：命令路径否证、「面板黑」是不变量、软件侧点亮代理集体失效（2026-10-15 实测） | [sessions/37-Q28-armA：命令路径否证与「面板黑」是不变量.md](sessions/37-Q28-armA：命令路径否证与「面板黑」是不变量.md) |
| 三十九、能力靠实测不靠 `--help`：`fastboot fetch` 在本机 ABL 不存在（#290）、「客户端有≠设备支持」（#291）、文档指向已归档脚本 26 处（#292）（2026-10-17 复核） | [sessions/39-能力靠实测不靠help：fastboot无fetch与同类记错.md](sessions/39-能力靠实测不靠help：fastboot无fetch与同类记错.md) |
| 四十、RAM 启动新内核不先部署 `/lib/modules/<新UTS>` ⇒ `lsmod` 空 ⇒ DP 永久 defer ⇒ 无 `card0`（会被误判成 Q28 坏发）（#293，2026-10-17 实测） | [sessions/40-RAM起新内核不部署模块树就没有DRM.md](sessions/40-RAM起新内核不部署模块树就没有DRM.md) |
| 四十一、设备侧熄屏自动化两坑：`dpms` sysfs 只读（root 也写不进）、Q28 坏发 boot 上 `phoc` crash-loop 约 3 min 才能取到会话总线（#294–#295，2026-10-17 实测） | [sessions/41-设备侧熄屏自动化：dpms只读与坏发会话崩溃.md](sessions/41-设备侧熄屏自动化：dpms只读与坏发会话崩溃.md) |
| 四十二、相机 AE 三坑：libcamera 无 sensor helper ⇒ 把 V4L2 增益码当真实增益（#296）、软 ISP 黑电平只来自 helper/tuning 且默认 0（#297）、设备有 wlan0 IP 却无外网致就地构建不可行（#298）（2026-10-17 实测） | [sessions/42-相机AE三坑：helper缺失-黑电平-tuning.md](sessions/42-相机AE三坑：helper缺失-黑电平-tuning.md) |
| 四十三、相机 AE 正解（libcamera helper）落地路上的三坑：设备冷起时钟 **1970** ⇒ HTTPS/`apk` 全废（#299）、交叉编 IPA 的三个硬点（musl 工具链/只换 `ipa_soft_simple.so`/签名不校验，#300）、「设备失联」先认 fastboot 形态（#301，本次成因=平板编译过热被手动重启到 BL）、平板不做重编译（#302）、软 ISP 的 AE 收敛慢是设计（统计每 4 帧一次，别用一两次抓帧判 AE，#303）、相机 A/B 必须控场景与起点（含「最短曝光测 pedestal」法，#304）、libcamera-devel 是 members-only 且提交标题带文件名（#305）（2026-10-17 实测） | [sessions/43-相机AE正解交叉编译与设备时钟.md](sessions/43-相机AE正解交叉编译与设备时钟.md) |
| 四十四、容器侧 camera provider：vendor.img **100% 满** ⇒ `debugfs` 分配不到 inode（#306）、上游 external HAL 只有 **32 位**且 Waydroid 镜像无任何 camera HAL（#307）、Debian `aidl` 不认 `@VintfStability` 且必须 `--lang=ndk`（#308）、**NDK libc++ ≠ 平台 libc++** ⇒ 注册成功后首笔 `BHwBinder::transact` 即 SIGSEGV（`pc …fffe0`，先做「注释掉设备绑定」A/B 排枚举，#309）、`cannot find suitable cropping type` = ENUM 回退 + 四cc 白名单**两坑叠加**（#310）、Waydroid 1.6.2 openrc `-p pidfile` 不支持/root 不能用 `/run/user/1000`（#311）、设备侧长命令必须 `timeout` + Q28 坏发用有界重启（#312）、AVB key 重建后公钥 sha1 变 ⇒ `vbmeta_b` 必须同步重签（#313）；**VINTF manifest 是注册硬门、`debugfs` 单文件替换 manifest 会让全体 vendor HAL 注册失败**（#314）、**「谁的 ABI 不对」的判定顺序：先塞平台自产二进制做 A/B 再谈重编**（#315）（2026-10-18 实测） | [sessions/44-容器侧camera-provider：64位自编-ABI崩溃-YUYV协商.md](sessions/44-容器侧camera-provider：64位自编-ABI崩溃-YUYV协商.md) |
| 三十八、M1-7.3 模块树补建（`ARCH`/vermagic 双坑）+ 相机栈首次跑通 + `cam-mode.sh off` 反向激活 Q24 + `mxc.lvl→0` 不是死亡签名 + `sync_state` 只在开机窗口生效 + `reboot` 挂起致假 ALIVE + **`#212` 配方 12 发不可复现**（2026-10-15 晚实测） | [sessions/38-M1-7.3模块树补建：ARCH与vermagic双坑+相机栈跑通.md](sessions/38-M1-7.3模块树补建：ARCH与vermagic双坑+相机栈跑通.md) |
