# droidloom 附属仓库整理 + 上游缺陷/社区分叉评估（D24 常设 lane，首轮进行中）

> **状态：lane 运行中**（2026-11-26 派出，`researcher` / `custom.ustc-pool/ustc-dsf`）。本文件为占位，lane 完成后由该 lane 覆写为完整报告。
> 维度登记 = `TASKS/dim/D24.md`；派发入口 = `TASKS/NEXT.md` §4.0。
> 首轮要交付的四块：① 本仓 droidloom 资产清单 + 重复/漂移清单 + 常设入口建议；② 上游 `denialwm/droidloom` open issue 聚类 ↔ 我方实测缺陷对照 + 「值得回复/新开 issue」候选（只草拟不发）；③ forks 现查与「跟不跟」二值建议 + 本地补丁最小可维护形态；④ 三态判断（继续投 / 只当实验 / 停）+ 两周最小行动 + 上游升级时本地改动如何保住。
> **本轮已被父代理定因、lane 不重做的三项**：全屏 = per-app 窗口覆写（`reports/droidloom-display-sizing-20261126.md`）；cell 无网 = SSID 永久禁用 + DHCP responder 硬编码 DNS（`reports/droidloom-cell-network-20261126.md`）；键盘 = 占位 IME `onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE`（`reports/droidloom-ime-keyboard-20261126.md`）。
