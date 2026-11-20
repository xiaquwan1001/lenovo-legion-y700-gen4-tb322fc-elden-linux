# O_DIRECT sha 硬门接入报告（P0-5，2026-11-20）

对应 `reports/android-v3-bringup-packet-20261120.md` §0 第 9 条；证据
`~/hw-stability/evidence/inbox/20261120-y700-elden-pagecache-sha-drift/`。
本机页缓存污染曾使 v1 件 buffered 连读 5 次稳定但错（637a9965…），O_DIRECT = e3d0d26f… 才对
⇒ 旧「双 sha256 硬门」抓不到，必须 O_DIRECT。

## 1. 实现

新文件 `scripts/odirect-sha.py`：
- `os.open(O_RDONLY|O_DIRECT)`，匿名 `mmap` 分配 16 MiB 页对齐缓冲，整块 `os.read`；
  EOF 处短块只哈希实际字节（尾不对齐也可，因读长度恒为整块对齐）。
- 记录节点大小（`os.fstat`）与累计偏移（=字节数）。
- `--compare`：同一文件 buffered + O_DIRECT 各算一遍，输出 `SAME/DIFF`，不一致 rc=1。
- `--tsv`（默认）：`path<TAB>bytes<TAB>sha256`。
- `--selftest`：自建 5,255,225 B（非块对齐尾）临时文件，断言两口径 = 内存 hashlib 参考值；
  再灌 decoy 进页缓存 + 对目标 `posix_fadvise(DONTNEED)` 复测，断言不误报。
- O_DIRECT 不可用（如 tmpfs）退回 buffered 并打 stderr WARN。

实测：`python3 scripts/odirect-sha.py --selftest` →
`selftest OK: size=5255225 ref=4b5ef6d69aac1732… odirect=buffered=ref（含 fadvise 干扰复测）`，rc=0。

## 2. 接入点

- `scripts/android-v3-bringup-walkthrough.sh`：`sha_direct()` 改为调
  `odirect-sha.py --tsv`（O_DIRECT 单次即判；工具回退 buffered 时 shell 侧保留 sha256sum 兜底 + WARN）。
  `--verify` 与 preflight 均经此函数，全量接入。
- `scripts/android-super.py`：grep 确认其 sha256 只用于 liblp 头/表 **内存内** 校验
  （`hashlib.sha256(bytes(z))` 等，行 69/124/128），不存在主机大文件 sha 比对路径 ⇒ 无需改。

## 3. 实跑取证（pieces-inventory 7 件，--compare）

命令：`python3 scripts/odirect-sha.py --compare <7 件>`（见 /tmp/odirect-compare-20261120.txt）。

结果：**7/7 SAME**，两口径完全一致，rc=0：

| 件 | buffered = O_DIRECT |
|---|---|
| out/android-min-20261118/pkg/super_min.img | e3d0d26f… |
| out/android-slim-v3-20261119/new/super_min_v3.img | 51eae107… |
| out/android-slim-v3-20261119/new/super_dbg.img | **8b42f20d…** |
| out/android-slim-v2b-20261119/new/super_min_v3.img | 98a88ea0… |
| out/android-v3-bringup-20261120/metadata_stock.img | a735fbc7… |
| backup/official-rom-15.10.259/boot.img | b428a31d… |
| out/boot-elden-vk192.img | bdf47f5f… |

**关于今天 10:5x 的漂移事件**：`super_dbg.img` 现值 O_DIRECT=8b42f20d…，
与 `pieces-inventory.txt`（10:10 记）登记的 82d33151… **不一致**；该件 mtime 仍为
2026-11-19 21:18:59（`stat` 实测），文件本身未改 ⇒ 判定 82d33151… 是当时 buffered 读
命中坏缓存的产物，8b42f20d… 为真值（walkthrough PIECES 已按 8b42f20d 登记，crit=0）。
本轮两口径即时比对无新漂移。

## 4. 验收

- `python3 scripts/odirect-sha.py --selftest` → rc=0（见上）。
- `bash scripts/android-v3-bringup-walkthrough.sh --verify` → rc=0，7 件全 OK
  （sha 均与登记一致）；设备在线（linux），含 1 条 WARN「adb 上有 1 台设备但无 HA2EXB0E」
  （既有的外来设备提示，非 FAIL）。设备离线时脚本打印 offline 警告不 FAIL（既有逻辑未改）。
- `timeout -k 3 200 bash scripts/check-doctor.sh` → `FAIL=0  WARN=6`，rc=0。
  6 条 WARN 均为 C 类存量（geekidos-linux 源树已档不可核、uts_dup 豁免、4 个 posctrl 旧镜像
  内核段不可解、无内核树 .config、无构建树），与本轮改动无关；本轮未新增 WARN。

## 5. 后续接入建议（本轮未改，只列清单）

按造件路径上的 sha 比对密度排序（grep sha256sum/sha256 统计）：
1. `scripts/uefi-a-slot-prepare.sh`（8 处）、`scripts/esp-put-loader.sh`（6）、
   `scripts/esp-install-grub.sh`（6）—— UEFI/ESP 引导件链。
2. `scripts/linux-gpt-apply.sh`（5）、`scripts/f2fs-migrate.sh`（5）、
   `scripts/android-ksu-flash.sh`（5）、`scripts/android-ksu-avb-build.py`（5）—— 上机件生成/烧写链。
3. `scripts/uefi-grubcfg-arming.sh`（4）、`scripts/rebuild-vk64-image.sh`（4）、
   `scripts/out-archive.py`（4）、`scripts/esp-apply.sh`（4）。
4. 其余 1–3 处的脚本遇「登记 sha ↔ 实读比对」语义时逐个替换为 `odirect-sha.py --tsv`
   （输出第 3 列即 sha，可直接 `awk` 取）。
