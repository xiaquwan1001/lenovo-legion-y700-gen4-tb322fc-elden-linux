# 板件 v9 备料（2026-11-24）——**未投递，等放行 + 依赖先行**

- 是什么：把板件的 USB 部分（`sm8750.dtsi` 的 HS port label + 板件 mux / 两个 usb-c-connector /
  `port@0` 的 `endpoint@0/@1`）单独成系列，2 枚。
- 依赖：需要 **dwc3 两连接器 binding** 先进树（当前在档 = v14，`../dwc3-v14-20261124/`，未投）。
  不带 binding 的树上，板件会被打 5 条 `mux-controls`/`mux-state`/`usb-role-switch` unexpected。
- 门禁：`GATES-v9.md`（含 2026-11-24 用 **v14** binding 复验的结果：dtbs_check 3/3 `DTC [C]`、0 诊断）。
- 门/依赖的交叉账：`../../reports/upstream-recheck-20261124.md` §6。
- 与 v8 prep 的关系：内容逐字节相同（只改 `[PATCH v9 N/2]` 标号），按 v8 prep 的「方案 B」拆出；
  v8 本身 = `../elden-dts-v8-prep-20261121/0000`（qcom.yaml）+ v7 原文，与本目录无关。
- 投递：**未发**。放行后 `bash SEND.sh`（默认 dry-run，`--yes` 才真发；2026-11-24 已 dry-run 通过 = 3 封格式/smtp 配置 OK）。
  前置硬条件 = **dwc3 binding 先进树**（脚本第 0 步会提醒，但机上无法自动判断）。
