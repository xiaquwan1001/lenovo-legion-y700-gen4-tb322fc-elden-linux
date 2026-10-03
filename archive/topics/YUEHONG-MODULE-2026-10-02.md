# 月虹一键隐藏 模块 —— 评估与安装计划（2026-10-02）

## 是什么

- **月虹一键隐藏**（作者「月虹yh」，酷安/B站）：KSU / KernelSU-Next / SukiSU / APatch / Magisk 通用的一键隐藏环境模块。
- 两种模式：
  - **游戏版** → 用开源 **HMA-OSS**（`frknkrc44/HMA-OSS`，Zygisk 版隐藏应用列表）
  - **搞机版** → 用 LSPosed + 隐藏应用列表
- 主要功能：隐藏应用列表 / 配置 SUS 路径（SUSFS）/ 获取有效密钥（keybox）/ 更新 BL 列表 / uname 伪装 / 风险应用管理。
- **v5.3.2+ 明确适配 ReSukiSU 的 SUSFS**（与本机内核匹配）。模块工作目录 `/data/adb/YH_YC`，体积约 211 KB。

## 官方下载（已从官网 JS 解码出真实链接）

- 官网：`https://yhyun.asia/`（内容被 XOR+RC4+gzip 混淆防爬）
- **月虹一键隐藏**：夸克 `https://pan.quark.cn/s/ec586ada92f0`（迅雷对应链接见官网）
- 其它：游戏助手 `…/s/77a94b772ca4`、提权助手 `…/s/1f678cebc200`、一键装检测软件、YH_Hosts、越狱文件。
- ⚠️ 夸克/迅雷分享**需登录客户端**才能取文件；本项目未从第三方镜像下载。

## ⚠️ 安全提示（重要）

- 社区（B站）存在标题「**"月虹"ROOT一键隐藏模块被爆出藏有远程控制后门？真的假的？**」的讨论。
- 该模块**闭源**、脚本化、体积小，但**来源单一**。
- **建议**：拿到 zip 后先解包审脚本（`post-fs-data.sh` / `service.sh` / `webroot` / 任何下载/上报逻辑）再刷；或直接用**开源** `HMA-OSS` 替代其核心功能。
- 本会话不代从非官方镜像下载安装。

## 待办（需要你提供 zip 或确认）

1. 用夸克/迅雷下载 `月虹一键隐藏` 的 zip，放到主机或设备。
2. 我解包 **审计**（重点：网络请求、下载器、exec 外部程序、密钥/keybox 来源）。
3. 审计通过后 `ksud module install`，游戏版；重启。
4. 复测：Native Detector / Securify，看最后一项是否变化。

## 关于「最后一个审计风险」

- adb 关闭后，Securify 剩下的是 **`found_modified_system_files`**（= ReI `detectInconsistentFingerprint`）。
- 已反汇编确认：该函数只把 `ro.build.fingerprint` 按 `/`、`:` 拆成 8 段，与
  `ro.product.brand/name/device`、`ro.build.id`、`ro.build.version.release`、
  `ro.build.version.incremental`、`ro.build.type`、`ro.build.tags` 逐字节比对。
- **本机这 8 个 prop 已全部与 fingerprint 对齐**（见下表），函数仍返回 true → 判定为 **ReI 在本 ROM/Android16 上的检测瑕疵**。
- 结论：**这不是"隐藏"问题，通用隐藏模块（月虹）大概率也清不掉**；除非它替换/伪造整条 fingerprint 链并刚好命中 ReI 的另一条路径。
- 实测可行且已验证：**Native Detector = normal**（更硬核的原生检测已清白）。

| prop | 值 | fingerprint 对应段 |
|---|---|---|
| ro.product.brand | Lenovo | Lenovo |
| ro.product.name | TB322FC_PRC | TB322FC_PRC |
| ro.product.device | TB322FC | TB322FC |
| ro.build.version.release | 16 | 16 |
| ro.build.id | BQ2A.250610.001-BP2A.250605.031.A3 | 同 |
| ro.build.version.incremental | ZUXOS_1.5.10.259_260611_PRC | 同 |
| ro.build.type | user | user |
| ro.build.tags | release-keys | release-keys |
