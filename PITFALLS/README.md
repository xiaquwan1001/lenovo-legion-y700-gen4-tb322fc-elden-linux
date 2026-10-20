# 踩坑总表（TB322FC / elden mainline Linux）

> 📇 **先看 `INDEX.md`**（文档地图 + 状态裁决）。
> **给下一个会话：先读 `INDEX.md`（文档结构），再扫本文件。** 这里全是花过代价换来的教训，按主题归类。
> **本文件 = 开发经验（踩坑）唯一入口**；**「谁执行、允不允许自动跑」的行为/授权标准在 `.pi/AGENT-OPS.md`**，本文件不定义授权边界。
> 最后更新：2026-10-19。**条目编号范围不写死**（写死必漂）：现查 `scripts/check-doctor.sh §8` 的正文编号对账。
> 条目唯一性 = 每个 `#NNN` 在 `sessions/*.md` 里**只被定义一次**；新增条目取当前最大号 +1。

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

| # | 主题 | 正文 |
| --- | --- | --- |
| 01 | 引导 / fastboot / 重启交接 | [01-引导fastboot重启交接.md](sessions/01-引导fastboot重启交接.md) |
| 02 | 内核 / DTS / 构建 | [02-内核DTS构建.md](sessions/02-内核DTS构建.md) |
| 03 | 存储 / 分区 / 持久化 | [03-存储分区持久化.md](sessions/03-存储分区持久化.md) |
| 04 | 固件 / 外设（反提取 vendor 资源） | [04-固件外设.md](sessions/04-固件外设.md) |
| 05 | 设备上装包 / 环境 | [05-设备上装包环境.md](sessions/05-设备上装包环境.md) |
| 06 | 脚本 / 工具 | [06-脚本工具.md](sessions/06-脚本工具.md) |
| 07 | Wayland / 桌面（weston） | [07-Wayland桌面.md](sessions/07-Wayland桌面.md) |
| 08 | 恢复 Android / 免解 BL root 资产 | [08-恢复Android免解BLroot资产.md](sessions/08-恢复Android免解BLroot资产.md) |
| 09 | WiFi / ath12k / 装包 | [09-WiFiath12k装包.md](sessions/09-WiFiath12k装包.md) |
| 10 | 桌面 / Phosh | [10-桌面Phosh.md](sessions/10-桌面Phosh.md) |
| 11 | 存储 / TF 卡 / 扩分区 | [11-存储TF卡扩分区.md](sessions/11-存储TF卡扩分区.md) |
| 12 | userdata 缩容（TWRP 路线） | [12-userdata缩容.md](sessions/12-userdata缩容.md) |
| 13 | AVB / 免签 / KSU | [13-AVB免签KSU.md](sessions/13-AVB免签KSU.md) |
| 14 | 睡眠 / 挂起 | [14-睡眠挂起.md](sessions/14-睡眠挂起.md) |
| 15 | 过时 / 废弃 / 功能缺陷登记（DEPRECATED） | [15-过时废弃功能缺陷登记.md](sessions/15-过时废弃功能缺陷登记.md) |
| 16 | 自动旋转锁死 / 开关置灰 = iio-sensor-proxy 启动时序 | [16-自动旋转方向锁死开关置灰—iio-sensor-proxy启动时序.md](sessions/16-自动旋转方向锁死开关置灰—iio-sensor-proxy启动时序.md) |
| 17 | 设备侧自动化：会话总线 / DPMS / 传感器总线 | [17-设备侧自动化踩坑：会话总线DPMS传感器总线.md](sessions/17-设备侧自动化踩坑：会话总线DPMS传感器总线.md) |
| 18 | GUI/GPU 负载压测与「gfx 电源域」读法 | [18-GUIGPU负载压测与「gfx电源域」读法.md](sessions/18-GUIGPU负载压测与「gfx电源域」读法.md) |
| 19 | 重启通道 / A/B 槽位 / ramdisk 层叠 / Q28 判据 | [19-重启通道AB槽位ramdisk层叠Q28判据.md](sessions/19-重启通道AB槽位ramdisk层叠Q28判据.md) |
| 20 | 相机模块加载：第三次栽在「静默跳过」 | [20-相机模块加载：一天之内第三次栽在"静默跳过"上.md](sessions/20-相机模块加载：一天之内第三次栽在"静默跳过"上.md) |
| 21 | 相机 ⇄ 熄屏 = 互斥（+ 新工具自测的坑） | [21-相机⇄熄屏=互斥+新工具自测暴露的坑.md](sessions/21-相机⇄熄屏=互斥+新工具自测暴露的坑.md) |
| 22 | 构建守卫 & Q28 变量纠正 | [22-构建守卫&Q28变量纠正.md](sessions/22-构建守卫&Q28变量纠正.md) |
| 23 | Q24 复现定案 + Q28「版本串」变量 + 测试协议陷阱 | [23-Q24复现定案+Q28「版本串」变量+测试协议陷阱.md](sessions/23-Q24复现定案+Q28「版本串」变量+测试协议陷阱.md) |
| 24 | Waydroid 容器（音频/媒体） | [24-Waydroid容器.md](sessions/24-Waydroid容器.md) |
| 25 | Q28 冷起判定 = 内核构建身份法则（+ 冷起 A/B 补丁作废） | [25-Q28冷起判定=内核构建身份法则+冷起AB测补丁作废.md](sessions/25-Q28冷起判定=内核构建身份法则+冷起AB测补丁作废.md) |
| 26 | 跨树驱动比对陷阱：`to_primary_dsi` DSI0/DSI1 伪线索 | [26-跨树驱动比对的方法陷阱：to_primary_dsiDSI0DSI1伪线索.md](sessions/26-跨树驱动比对的方法陷阱：to_primary_dsiDSI0DSI1伪线索.md) |
| 27 | Q24 台架 / 工具链教训 | [27-Q24台架工具链教训.md](sessions/27-Q24台架工具链教训.md) |
| 28 | 上游邮件通道 | [28-上游邮件通道.md](sessions/28-上游邮件通道.md) |
| 29 | Waydroid 马达透传（vibrator HAL → aw86927 FF） | [29-Waydroid马达透传.md](sessions/29-Waydroid马达透传.md) |
| 30 | Waydroid 马达透传二期：AIDL HAL 替换 | [30-Waydroid马达透传二期：AIDLHAL替换.md](sessions/30-Waydroid马达透传二期：AIDLHAL替换.md) |
| 31 | M1-7.3 上机：缺 `=m` 模块被误判为代码回归 | [31-M1-7.3上机：缺=m模块被误判为代码回归.md](sessions/31-M1-7.3上机：缺=m模块被误判为代码回归.md) |
| 32 | 上游显示栈 bring-up：DRM GOOD ≠ 面板有画面 | [32-上游显示栈bring-up：DRMGOOD≠面板有画面.md](sessions/32-上游显示栈bring-up：DRMGOOD≠面板有画面.md) |
| 33 | 「精确 UTS / 单变量打包」三连坑 | [33-盯“精确UTS单变量打包”的三连坑.md](sessions/33-盯“精确UTS单变量打包”的三连坑.md) |
| 34 | WCN MHI 首探必失败、重发即成功 | [34-WCN首探MHI必失败重发即成功.md](sessions/34-WCN首探MHI必失败重发即成功.md) |
| 35 | WCN 首探修法：只有「整轮重探」有效 | [35-WCN首探修法：只有整轮重探有效.md](sessions/35-WCN首探修法：只有整轮重探有效.md) |
| 36 | 构建落点（内存盘）与调试信息实测 | [36-构建落点与调试信息实测.md](sessions/36-构建落点与调试信息实测.md) |
| 37 | Q28 arm A：命令路径否证、「面板黑」是不变量 | [37-Q28-armA：命令路径否证与「面板黑」是不变量.md](sessions/37-Q28-armA：命令路径否证与「面板黑」是不变量.md) |
| 38 | M1-7.3 模块树补建：`ARCH` / vermagic 双坑 + 相机栈跑通 | [38-M1-7.3模块树补建：ARCH与vermagic双坑+相机栈跑通.md](sessions/38-M1-7.3模块树补建：ARCH与vermagic双坑+相机栈跑通.md) |
| 39 | 能力靠实测不靠 `--help`：`fastboot fetch` 不存在等四类记错 | [39-能力靠实测不靠help：fastboot无fetch与同类记错.md](sessions/39-能力靠实测不靠help：fastboot无fetch与同类记错.md) |
| 40 | RAM 启动不部署模块树 ⇒ 无 DRM（会误判成 Q28） | [40-RAM起新内核不部署模块树就没有DRM.md](sessions/40-RAM起新内核不部署模块树就没有DRM.md) |
| 41 | 设备侧熄屏自动化：`dpms` 只读、坏发 boot 上会话先崩后稳 | [41-设备侧熄屏自动化：dpms只读与坏发会话崩溃.md](sessions/41-设备侧熄屏自动化：dpms只读与坏发会话崩溃.md) |
| 42 | 相机 AE 三坑：无 sensor helper / 黑电平 / 设备无外网 | [42-相机AE三坑：helper缺失-黑电平-tuning.md](sessions/42-相机AE三坑：helper缺失-黑电平-tuning.md) |
| 43 | 相机 AE 正解落地：交叉编译、签名、设备时钟 | [43-相机AE正解交叉编译与设备时钟.md](sessions/43-相机AE正解交叉编译与设备时钟.md) |
| 44 | 容器 camera provider 前期：64 位自编 / vendor.img / ABI / YUYV | [44-容器侧camera-provider：64位自编-ABI崩溃-YUYV协商.md](sessions/44-容器侧camera-provider：64位自编-ABI崩溃-YUYV协商.md) |
| 45 | 冷起无桌面 = `greetd` 崩；出流成功 ≠ 成像正确 | [45-冷起无桌面与相机成像验收.md](sessions/45-冷起无桌面与相机成像验收.md) |
| 46 | 相机 AE 三个独立 bug：`exposureTarget` / 增益步长 / helper 语义 | [46-相机黑帧真根因AGC-target与主机交叉编译.md](sessions/46-相机黑帧真根因AGC-target与主机交叉编译.md) |
| 47 | 刷机取证 + 相机 App 无画面 = portal 后端 | [47-刷机取证与相机App-portal根因.md](sessions/47-刷机取证与相机App-portal根因.md) |
| 48 | 输入法「唤起即崩桌面」= phoc × wlroots 0.20 的 `data=NULL` 约定 | [48-输入法崩溃phoc-wlroots-NULL约定.md](sessions/48-输入法崩溃phoc-wlroots-NULL约定.md) |
| 49 | 设备 HTTPS 全废 / git 随机失败 = 0 字节证书 + PMTU 黑洞 | [49-设备网络HTTPS全废与PMTU黑洞.md](sessions/49-设备网络HTTPS全废与PMTU黑洞.md) |
| 50 | 相机 App 一直转圈 = phoc 无键盘 ⇒ GTK `is-active` 恒假 | [50-相机App转圈真根因-phoc无键盘致is-active恒假.md](sessions/50-相机App转圈真根因-phoc无键盘致is-active恒假.md) |
| 51 | 容器 camera provider 真根因：`IBinder` vtable 错位 + 符号抢占 | [51-容器camera-provider真根因-vtable错位与符号抢占.md](sessions/51-容器camera-provider真根因-vtable错位与符号抢占.md) |
| 52 | WiFi 候选榜只剩已连接项 = 连通态 NM 不复扫（bgscan 写死 86400 s） | [52-WiFi候选榜塌成1项-连通态NM不复扫.md](sessions/52-WiFi候选榜塌成1项-连通态NM不复扫.md) |
| 53 | 用户态：先查内置能力，phosh 旋转磁贴重复造轮子 | [53-用户态先查内置能力-phosh旋转磁贴重复造轮子.md](sessions/53-用户态先查内置能力-phosh旋转磁贴重复造轮子.md) |
| 54 | 构建机随机 ICE / `bad reloc symbol index` = **内存页缓存位翻转**（非磁盘）；三读法判据 + 禁止「重写文件当修复」 | [54-构建机静默文件损坏与坏对象.md](sessions/54-构建机静默文件损坏与坏对象.md) |
| 55 | **#360** 改内核 config 会改 ABI：模块不重编 ⇒ 早期 panic（指令字节当指针） | [55-config改ABI-模块不重编早期panic.md](sessions/55-config改ABI-模块不重编早期panic.md) |
| 56 | **#361** `BindsTo=` + `Restart=always` 不重连：串口日志静默停摆 | [55-config改ABI-模块不重编早期panic.md](sessions/55-config改ABI-模块不重编早期panic.md) |
| 57 | **#362** `make olddefconfig` 不带 ARCH 会把 `.config` 写成 x86（ABI 全变） | [57-olddefconfig不带ARCH把配置写成x86.md](sessions/57-olddefconfig不带ARCH把配置写成x86.md) |
| 58 | **#363** `nohup` 起的设备脚本不随终端中断而死：会持续折腾设备 | [58-nohup设备脚本不随终端中断而死.md](sessions/58-nohup设备脚本不随终端中断而死.md) |
| 59 | 触屏中文输入法三处「看着在跑其实不通」：缺 `fcitx5-gtk` / fcitx5 抢 IM 槽位 / 自编候选条多余 | [59-触屏中文输入法-GTK-IM模块与OSK槽位.md](sessions/59-触屏中文输入法-GTK-IM模块与OSK槽位.md) |

> **索引只放「一句话主题」**：结论、命令、数字一律在正文 `sessions/NN-*.md`（唯一事实源）。
> 单行超过 800 字节即视为「索引在做正文的活」，`scripts/check-doctor.sh` §8 会报错。
> 编号不写死上下界；唯一性由 §8 的正文编号对账保证。
