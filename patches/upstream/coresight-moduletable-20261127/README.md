# coresight CTCU/TPDA 缺 MODULE_DEVICE_TABLE —— v1（2026-11-27）

> 来源：`reports/capbatch-vk194-20261127.md` §7、`reports/upstream-coresight-fixes-20261127.md`
> 状态：**v1 备料完成，门禁全绿**（见 `GATES.md`）。投递走 `SEND.sh`（默认 dry-run）。
> 口径：`TASKS/README.md` §7 —— 用户 2026-11-26 全面放行，备料+门禁全绿即可投。
> （本目录此前的 `0001`/`0002` 裸 diff 已由 `v1-*` 正式件取代；TNOC 的 DTS 部分已拆到
> `../sm8750-tnoc-periphid-20261127/`，因为它还要求 binding 改动，收件人不同。）

## 1. 缺陷

| 驱动 | 缺陷 | 证据（同一台 SM8750，vk195/vk196） |
|---|---|---|
| `coresight-ctcu` | `ctcu_match[]`（只有 `qcom,sa8775p-ctcu`，SM8750 节点以 `qcom,sm8750-ctcu` 回退匹配它）**没有** `MODULE_DEVICE_TABLE(of, ctcu_match)` ⇒ 编成模块无 `of:` alias ⇒ udev 不会自动加载 | `lsmod \| grep -c coresight_ctcu` = 0；`modinfo -F alias coresight-ctcu` = 空；手动 `modprobe` 后 `10001000.ctcu` 立即绑定 |
| `coresight-tpda` | `tpda_ids[]`（amba）同样没导出 ⇒ 无 `amba:` modalias | 5 个 tpda 节点不绑；手动 `modprobe coresight-tpda` 后立即绑定 |

## 2. 补丁（v1）

| 文件 | 内容 |
|---|---|
| `v1-0000-cover-letter.patch` | [PATCH 0/2] coresight: add missing MODULE_DEVICE_TABLE() for CTCU and TPDA |
| `v1-0001-coresight-ctcu-add-missing-MODULE_DEVICE_TABLE.patch` | +`MODULE_DEVICE_TABLE(of, ctcu_match);` |
| `v1-0002-coresight-tpda-add-missing-MODULE_DEVICE_TABLE.patch` | +`MODULE_DEVICE_TABLE(amba, tpda_ids);` |

基线 = `build/daily` HEAD `4da9a8b69fc85`（Linux 7.3.1）；上游 7.4-rc3（`build/elden-tree`）同样缺这两行。

## 3. 实测（打上补丁后）

- 模块 alias：`of:N*T*Cqcom,sa8775p-ctcu` / `amba:d???F0F??`（`modinfo -F alias`）。
- **撤掉 `/etc/modules-load.d/elden-coresight.conf` 后开机自动加载**：
  `lsmod` 有 `coresight_ctcu` + `coresight_tpda`，`/sys/bus/amba/devices/*` 未绑定数 = **0**。
- 该兜底文件即由本缺陷产生，上游合入后可删（本机已移除，见 `reports/upstream-coresight-fixes-20261127.md` §3）。

## 4. 收件人

`TO` = Suzuki K Poulose；`Cc` = Mike Leach / James Clark / Leo Yan / Alexander Shishkin /
`coresight@lists.linaro.org` / `linux-arm-kernel` / `linux-kernel`（`SEND.sh` 内固化）。

## 5. 投递后

`SENT.md` 记 cover MID + 每封 Result；lore 复核 `coresight` 与 `linux-arm-kernel` 两处。
