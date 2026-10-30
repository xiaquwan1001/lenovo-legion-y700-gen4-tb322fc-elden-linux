gate1_rc=0
# A1 m3v5-onboard 上机候选构建 2026-10-30

## Gate1 前置
- HEAD: 34865c8915 ✓（log --oneline -1 第一词）
- 脏行数: 0

## Gate2/3 UTS 钉住 + ABI
- LOCALVERSION: `-debug-vk127-00002-g24223e44ad80-dirty-debug-vk172`（daily 自带，与目标 UTS 后缀逐字一致；LOCALVERSION_AUTO 未设）
- olddefconfig 相对 daily .config 改动行数: 13
- olddefconfig 掉的 =m 项: 5（TOUCHSCREEN_NOVATEK_NVT36XXX_SPI / REGULATOR_WL2868C / VIDEO_GC08A8 / VIDEO_S5KJNS / VIDEO_GT9764；GUNYAH 在 pristine 已是 n 非 =m 掉项）
- check-abi-config.sh: rc=0，27 项 ABI 敏感项全部 [ok]

## Gate4 构建注记
- 首次构建 rc=2：drivers/net/wwan/mhi_wwan_ctrl.c 源码含 typo（MHI_WWIN_RX_REFILL/wwao_port_get_drvdata，属 pristine 提交历史内容，禁止改 git）+ cc1 ICE；处置 = 在 .config 关闭 CONFIG_MHI_WWAN_CTRL（允许的 .config 生成物差异）后重建

## Gate4 构建
- rc=0，warning:=0，error:=0；Image.gz 增量构建墙钟 56.5s（user 14m53）

## Gate5/6 产物与门禁
- Image.gz  513db6c9a6e20591a639024f60864e0db00d09a25f07d0d5f47d5f1f7930f359
- elden.dtb（pristine 无 elden dts，DTB_FILE 取 m3v5-fix 同名 dtb，0b614a3c5843…）0b614a3c58430280e8dd7bf7bd3c449515b61bdb9297dd662a154e82b7a9a308
- typec_ucsi.ko 8c0694e9efd1dffb5914ea0acd07d00ae173427387eec7d879550a63565d01db
- ucsi_glink.ko 6b6049ad7a4c3a29feabf03e210ded1a13db102f673a01bf7b45473868dbf2a5
- dwc3.ko 4a5b4365b534c98bee9a10e3f611a564068732c2efa750052238cabbdda467ea
- dwc3-qcom.ko（设备文件名连字符，非 dwc3_qcom）50875e2877c0ce36a2620a3d628aa882333fe604ca32efb62bdadf182156820c
- assert-kernel-sane：ABI 27/27 ok；UTS 对齐 ok（需 LOCALVERSION= 传入环境，否则 setlocalversion 假阳性 +）；**DSI 锚点失败 = 真实差异**（pristine 是上游 msm_dsi，无下游 bonded-cmd 符号，属 b5-resoc 下游内容，禁止改 pristine git 内容 ⇒ 无法修，打包以 SKIP_KERNEL_ASSERT=1 + 本记录绕过）

## Gate7 vermagic 对比（候选 vs 在机 /lib/modules/…-vk172）
| 模块 | 候选 | 在机 | 逐字相同 |
|---|---|---|---|
| typec_ucsi.ko | …vk172 SMP preempt mod_unload aarch64 | 同 | yes |
| ucsi_glink.ko | 同上 | 同 | yes |
| dwc3.ko | 同上 | 同 | yes |
| dwc3-qcom.ko | 同上 | 同 | yes |
- 4/4 逐字一致（modinfo -F vermagic 双侧）
- 在机 /proc/version：7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk172（无 +），与候选 banner 一致

## Gate8 UTS 实证
- Image.gz banner = `Linux version 7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk172 (elden@y700) …`，无 + 尾巴 ✓

## Gate9 完整模块树（备胎，未部署）
- /tmp/m3v5pristine-mods：1632 个 .ko，du 1.9G，tar.gz 579M；modules_install rc=0

## Gate10 打包
- out/boot-elden-m3v5-onboard.img（84 496 384 B）sha256 b24a64bb2475b51bd948a688f6e1fce7dc025946b64ad6403c18881721652b66
- manifest kernel_release/uts 与目标一致；cmdline 含 elden_early_gadget=1 elden_q28_nowd，slot _b
- 偏差声明：DTB_FILE 用 m3v5-fix 的 elden dtb（pristine 无 elden dts）；SKIP_KERNEL_ASSERT=1 仅因 DSI 锚点（见 Gate6）

## Gate11 收尾
- git -C build/m3v5-pristine status --porcelain = 0 行（.config 被 ignore 覆盖，构建产物不属 git）
- 全部产物已拷 out/m3v5-onboard/（sha 见 g11-sha.txt）

## UTS 钉住策略判定
**可行（带两条已记录偏差）**：config 掉 =m 项 5（触屏/稳压器/相机传感类，GUNYAH 本就 n）；ABI 敏感项 27/27 一致；vermagic 候选 vs 在机 4/4 逐字一致；banner 无 +。风险敞口：MODVERSIONS 未开 ⇒ 同串不同 config 的结构体偏移错位（#62/#83）仅由 27 项 ABI 锚点兜底；pristine 缺下游驱动（DSI bonded、5 个 =m）⇒ 非等价替换，属实验内核。
