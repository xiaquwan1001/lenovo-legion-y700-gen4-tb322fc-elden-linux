# H2 完整性巡检报告 — 2026-11-11

范围：本仓（y700-elden）静态巡检。环境约束：仅校园网直连，全部本机操作。

## §1 scripts/check-doctor.sh 结果

- `bash scripts/check-doctor.sh`：**FAIL = 0，WARN = 6**，exit 0，通过。
- WARN 明细（全文 grep `[warn]`）：

（待补：warn 全列表）已补齐，汇总如下（共 6 条 warn，均非 FAIL）：

1. `vk183-fastrpc`：registry 前历史镜像无 manifest（历史留白）。
2. 在途豁免 2 项：`vk187(num_ne_tag(vk184))`、`vk187b(num_ne_tag(vk184),uts_dup2)`。
3. 账本已登记例外（vk-ledger-known-issues.tsv 有理由）：大量 uts_dup/num_ne_tag 项（约 70 余条）。
4. 内核段不可读 4 件：`boot-elden-posctrl-markspin{,2,3,3gz}-v2-20261103.img`（免于身份核对）。
5. 无版本号构建拷贝 1 个：`boot-elden.img`。
6. 报告无人引用 3 份：`integrity-h2-20261111.md`（本报告）、`project-audit-20261111.md`、`t14-userland-recipe-20261111.md`。

注：警告 6 为本次巡检新增报告自身所致，属预期自指现象。

## §2 out/ 镜像 sha256 对账（O_DIRECT）

按表头命令逐件复算（O_DIRECT，`dd iflag=direct`；共 123 条数据行，另 RETIRED 2 件已从基线移出不参与）：

| 结果 | 件数 | 明细 |
|---|---|---|
| OK（sha256 一致） | **123** | 全部，无异常 |
| MISMATCH | **0** | — |
| MISSING（文件不存在） | **0** | — |

复算过程无 dd 错误输出（stderr 为空），O_DIRECT 生效。RETIRED 2 件（boot-elden-posctrl-20261103.img、boot-elden.img）按表头注释不参与复算。

## §3 git fsck --full（本仓 + geekidos-linux）

| 仓 | error | dangling | 明细 |
|---|---|---|---|
| y700-elden（本仓） | 0 | 0 | 无任何输出 |
| geekidos-linux（`/home/xuqianhui/y700-elden/geekidos-linux`） | 0 | 0 | 无任何输出 |

两仓均 `git fsck --full --no-progress` 全清。

## §4 磁盘空间与 SMART

- `df -h`：`/dev/nvme0n1p2`（`/`）937G，已用 562G，可用 328G（64%）；`/boot/efi` 1.1G 用 1%（6.4M）。无压力。
- `smartctl -H /dev/nvme0n1`：**跳过** —— Permission denied，需 sudo；本轮约束下不提权，仅注明。

## §5 结论与差异

- **未发现真损坏**：doctor FAIL=0；123 件镜像 O_DIRECT sha256 全部与 2026-11-05 基线一致，无 mismatch/缺失；两仓 fsck 全清。
- WARN 6 条均为既有账本/留白类（在途豁免、已登记例外、无 manifest 历史件、内核段不可读件、无版本号拷贝）+ 本报告自身的「无人引用」自指 warn，非损坏。
- 与 `reports/integrity-audit-20261105.md` 差异：基线后 2 件被有意 RETIRED（boot-elden-posctrl-20261103.img、boot-elden.img，删除理由见表头注释指向的 tidy/asset-cleanup 报告），故本轮复算集为 123 件（原先含这 2 件）；除此之外结论一致、无新增损坏。
- 遗留建议（未改动任何文件）：为本报告及 project-audit-20261111、t14-userland-recipe 三份报告在对应 README/TASKS 补指针，消除 doctor warn 6；smartctl 需 sudo 时另安排。

DONE

