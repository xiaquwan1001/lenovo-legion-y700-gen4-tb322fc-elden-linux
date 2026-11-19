# #687 split-super 必须「缺片即硬拒」，但别把它泛化到 userdata（官方包刻意不带件）

## 背景（LTBox 评估 P1-4 / P2-1 / P2-2，2026-11-19 落地）

`rawprogram*.xml` 里一个分区可以被拆成多片写（官方 15.10.259 包：`super_1.img … super_8.img`，
8 个 `<program>` 节点都写 `label="super"`、各自 `start_sector` 与 `num_partition_sectors`）。
qdl 对「少一片」的处理是**静默跳过**（尤其配了 `-f/--allow-missing`），结果是写出一个
「分区头合法、内容缺段」的 super ⇒ 能安装、起不来、且原因不可见。所以预检必须**硬拒**。

## 三条实测教训（本轮都是踩出来的，不是推的）

- **按 label 收不到分片**：分片信息在 `filename`（`super_1.img`）里，`label` 一律是 `super`。
  第一版按 `label` 匹配 ⇒ R6 永远不触发（自检里「`--allow-missing` 放过缺片」那条抓到的就是这个）。
- **只能限定 `stem == super`**：同一包里`userdata_1..11.img` 也被声明成一系列程序节点，但
  **刻意不带件**（`/data` 由 `fastboot -w` / 首次开发现建）。把 R6 泛化到「所有 `<stem>_<n>`」
  ⇒ 官方包立刻 **假 FAIL=11**。现在 `userdata` 是**默认豁免的缺件 label**（`--exempt-missing` 可扩），
  但几何判据（越界/重叠/大小）照做。
- **官方 XML 的表达式带尾点**：`start_sector="NUM_DISK_SECTORS-5."`（量产包 BackupGPT 节点）。
  严格档允许**一个**可选尾点，其余修饰（下划线/空白/单位/正负号）一律报错——
  Python 的 `int("1_0")` 会静默吃下划线 ⇒ 旧实现会把 `1_0` 当 10 去写。

## 现在的判据（`scripts/rawprogram-preflight.py`）

| 规则 | 内容 | 可复跑 |
|---|---|---|
| R6 | `super_<n>` 索引必须 1..N 连续 + 每片在盘；缺片 ⇒ FAIL，**`--allow-missing` 不适用** | `--selftest` 的 split 两例（默认档 / `--allow-missing` 档都必须 rc=1） |
| R7-a | 几何属性只接受 `[0-9]+` / `0x…` / `NUM_DISK_SECTORS(-n)?` + 可选尾点 | 自检 `start_sector="1_0"` 必 FAIL |
| R7-b | `file_sector_offset + 跨度 ≤ 镜像扇区数`（sparse 跳过；`>2^40` 判荒谬） | 自检 `file_sector_offset=4096` 必 FAIL |
| R5 | 缺件默认 FAIL；`userdata` 默认豁免（warn）；`--exempt-missing LABEL` 可重复扩 | 官方包整包 rc=0 / WARN=16 |
| §18 门 | 从「只跑 rawprogram4」扩到**整包 6 XML + 6 张主表**（只有给全 LUN 表，`NUM_DISK_SECTORS-5.` 才解析得出来；只给 0 号表会把 LUN1..5 的 BackupGPT 判成「字段不是整数」，那是真判据不是假阳性） | `bash scripts/doctor/18-flashpkg-geometry.sh` → 2 ok |

## 结论数字

- 官方 15.10.259 整包：**153 个 program 节点 / 6 XML / 72 件镜像 / FAIL=0 WARN=16**（WARN = 11 条 userdata 豁免 + 5 条占位 0 跨度）。
- 自检：**7 类坏包全抓**（R1..R7），正确包 0 FAIL。
- 未做：P2-3（`<patch filename="DISK">` 容量边界）—— 本包无 `<patch>` 节点，且需要 qdl patch 语义支持，先登记。
