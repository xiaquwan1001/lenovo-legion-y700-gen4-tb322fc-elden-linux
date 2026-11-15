# 门禁（2026-11-15，本 lane 实跑，原始输出）

基线 = 上游 `gh/master` = **`9d66f26fef`（Linux 7.4-rc3）**。系列 = 本目录 `0001`+`0002`。

## 0. 基线说明（先说清限制，别让门禁看起来比实际强）

`build/m3v2-7.3rc7`（7.3-rc7 + payload）的 `.git` **pack 有 3 个坏 object**，`git worktree add` 与
`git archive gh/master` 都会中途失败：

```
$ git -C build/m3v2-7.3rc7 worktree add --detach /tmp/wt-csiphy 9d66f26fef
error: failed to read delta base object a1a5720996b708d4b6e9ae9d189ec65a81af6dfd ...
fatal: 打包对象 92e6fca861f64a52e51e77bda4ac3278be20e5fb ... 已损坏
$ git -C build/m3v2-7.3rc7 archive gh/master | tar -x -C /tmp/csiphy-src
tar: 归档文件中异常的 EOF          # 941 MB 后截断
```

⇒ **无法得到一棵完整的 7.4-rc3 可编译树**。本轮用两条替代路径，二者的「被改文件」内容都是
`gh/master` 的 blob 原文：

| 用途 | 树 | 说明 |
|---|---|---|
| 门禁 ①（`git apply --check`） | `/tmp/csiphy-git` | 只含本次改动的 **4 个文件**，内容 = `git show gh/master:<path>` 原样，`git init` 后 commit 成 `base`。补丁只触及这 4 个文件，所以 `apply --check` 的判据完整。 |
| 门禁 ①②③④ | `/tmp/csiphy-build` | `rsync -a --exclude=.git build/m3v2-7.3rc7/` 的工作树副本（7.3-rc7 + payload，原本就可编译），再把**这四个文件**覆盖成 `gh/master` 的 blob 后`git apply` 本系列。⇒ 编译门禁证明的是「本枚 + gh/master 的 `drivers/phy/qualcomm/phy-qcom-mipi-csi2*.{c,h}` + gh/master 的 binding 在 arm64 W=1 下干净」，**不是**「整棵 7.4-rc3 全绿」。 |

`build/m3v2-7.3rc7` 本身**全程零改动**（`git status --short` 里没有本系列任何文件；该树原有的 9 项
改动来自本 lane 之前的工作，与本轮无关）。收尾 `/tmp/csiphy-*` 全部可删。

## 1. `git apply --check`（纯净 gh/master blob）

```
$ git -C /tmp/csiphy-git checkout $(git log --format=%H | tail -1)   # = base，4 文件均为 gh/master 原样
$ git -C /tmp/csiphy-git apply --check -v $D/0*.patch
正在检查补丁 Documentation/devicetree/bindings/phy/qcom,x1e80100-csi2-phy.yaml...
rc=0
正在检查补丁 drivers/phy/qualcomm/phy-qcom-mipi-csi2-3ph-dphy.c...
正在检查补丁 drivers/phy/qualcomm/phy-qcom-mipi-csi2-core.c...
正在检查补丁 drivers/phy/qualcomm/phy-qcom-mipi-csi2.h...
rc=0
```

原始日志：`logs/00-apply-check-pure-master.log`。
在 `/tmp/csiphy-build`（同样是 gh/master 的四文件）上顺序 `apply --check` 亦 **rc=0**：
`logs/01-apply-check.log`。

## 2. `checkpatch.pl --strict`（按系列顺序应用后逐个跑）

`--strict` + `--no-signoff`（`--no-signoff` 只关掉「必须带 SoB」这一条，SoB 在补丁里本来就有）。
在此树内跑而不用 `--no-tree`，避免 `--no-tree` 的假阳性。

```
$ ./scripts/checkpatch.pl --strict --no-signoff 0001-*.patch
total: 0 errors, 0 warnings, 0 checks, 10 lines checked
... has no obvious style problems and is ready for submission.
rc=0

$ ./scripts/checkpatch.pl --strict --no-signoff 0002-*.patch
total: 0 errors, 0 warnings, 0 checks, 162 lines checked
... has no obvious style problems and is ready for submission.
rc=0
```

原始日志：`logs/02-checkpatch-0001.log`、`logs/03-checkpatch-0002.log`。

⚠ 顺序敏感（踩过）：`0002` 单独跑会得到 1 条
`WARNING: DT compatible string "qcom,sm8750-csi2-phy" appears un-documented`——因为那条 check 是
在**当前树**的 `Documentation/` 里 grep 兼容串。`0001` 先落地后就是 0/0/0。这正是把 binding 拆成
`0001` 的原因之一（另一个原因是「驱动不许凭空自造 compatible」）。

另外本轮初稿踩到两条真实 style 问题，已在成品里修掉（记录在此以便复现时别再犯）：

```
WARNING: line length of 102/103 exceeds 100 columns
+	{.reg_addr = 0x0094, .reg_data = 0x07, .delay_us = 0x01, .param_type = CSIPHY_DEFAULT_PARAMS},
CHECK: Please don't use multiple blank lines
```

⇒ 表里 5 条带 `delay_us` 的项**折成两行**（`lane_regs_x1e80100[]` 里同样的行是 102/103 列，属存量风格，
本枚新增表不能沿用）；cfg 与既有 struct 之间只留一个空行。

## 3. `W=1` 单独编译

```
$ make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j26 W=1 drivers/phy/qualcomm/
  CC [M]  drivers/phy/qualcomm/phy-qcom-mipi-csi2-core.o
  CC [M]  drivers/phy/qualcomm/phy-qcom-mipi-csi2-3ph-dphy.o
  ...
  LD [M]  drivers/phy/qualcomm/phy-qcom-mipi-csi2.o
rc=0
```

`.config` 来自树副本（`CONFIG_PHY_QCOM_MIPI_CSI2=m`，第 10694 行），未做 `olddefconfig`
（树副本的 `.config` 与源码同源；`ARCH=arm64` 一直显式给出，避免宿主 x86 解析抹掉 `ARCH_QCOM`）。

`grep -icE 'warning|error'` = **0**；`rc=0`。原始日志：`logs/10-build-W1.log`。

## 4. `dt_binding_check`（本轮改了 binding ⇒ 必跑）

```
$ make ARCH=arm64 dt_binding_check DT_SCHEMA_FILES=Documentation/devicetree/bindings/phy/qcom,x1e80100-csi2-phy.yaml
  SCHEMA  Documentation/devicetree/bindings/processed-schema.json
  CHKDT   ./Documentation/devicetree/bindings
  LINT    ./Documentation/devicetree/bindings
  STYLE   ./Documentation/devicetree/bindings
  DTEX    Documentation/devicetree/bindings/phy/qcom,x1e80100-csi2-phy.example.dts
  DTC [C] Documentation/devicetree/bindings/phy/qcom,x1e80100-csi2-phy.example.dtb
rc=0
```

原始日志：`logs/30-dt_binding_check.log`。
环境坑：宿主 `python3` 没有 `dtschema`，且 Debian 的 PEP 668 拒绝 `pip --user`；本轮用
`python3 -m pip install --user --break-system-packages dtschema`（装到 `~/.local`，dtschema 2026.9）。
`python3 -m venv` 不可用（`ensurepip` 缺 `python3.14-venv`）。

## 5. 表内容对账（13 条 data 是否全覆盖）

```
$ python3 logs/verify-table.py /tmp/csiphy-build/drivers/phy/qualcomm/phy-qcom-mipi-csi2-3ph-dphy.c \
      /tmp/base-3ph.c backup/stock-elden/vendor_dlkm/camera.ko
lane_regs_sm8750 entries: 105 (2ph power-up 2 + data/clock lanes 103)
lane_regs_x1e80100 entries: 105

-- sm8750 vs x1e80100 (ordered) --
address sequence identical: True
  0x0000  x1e=0x8e/DEFAULT  delay=0 -> sm8750=0x8c/DEFAULT  delay=0
  0x0008  x1e=0x10/SETTLE   delay=0 -> sm8750=0x19/SETTLE   delay=0
  0x0060  x1e=0xbd/SKEW     delay=0 -> sm8750=0xfd/SKEW     delay=0
  0x0e08  x1e=0x10/SETTLE   delay=0 -> sm8750=0x19/SETTLE   delay=0
  0x0400  x1e=0x8e/DEFAULT  delay=0 -> sm8750=0x8c/DEFAULT  delay=0
  0x0408  x1e=0x10/SETTLE   delay=0 -> sm8750=0x19/SETTLE   delay=0
  0x0460  x1e=0xbd/SKEW     delay=0 -> sm8750=0xfd/SKEW     delay=0
  0x0800  x1e=0x8e/DEFAULT  delay=0 -> sm8750=0x8c/DEFAULT  delay=0
  0x0808  x1e=0x10/SETTLE   delay=0 -> sm8750=0x19/SETTLE   delay=0
  0x0860  x1e=0xbd/SKEW     delay=0 -> sm8750=0xfd/SKEW     delay=0
  0x0c00  x1e=0x8e/DEFAULT  delay=0 -> sm8750=0x8c/DEFAULT  delay=0
  0x0c08  x1e=0x10/SETTLE   delay=0 -> sm8750=0x19/SETTLE   delay=0
  0x0c60  x1e=0xbd/SKEW     delay=0 -> sm8750=0xfd/SKEW     delay=0
differing entries: 13

-- vendor csiphy_2ph_v2_4_0_reg: 103 entries, .data file offset 0x303824, vaddr 0xa3d6c --
address set equal (sm8750 vs vendor): True
(addr,data,type) multiset equal: True
vendor entries with non-zero mask field: ['0x0e94->0xd1', '0x0094->0xd1', '0x0494->0xd1', '0x0894->0xd1', '0x0c94->0xd1']
sm8750 entries with non-zero delay_us: ['0x0094->0x1', '0x0e94->0x1', '0x0494->0x1', '0x0894->0x1', '0x0c94->0x1']
```

⇒ **13/13 差全覆盖**，且新表与 vendor 2.4.0 表 `(addr,data,type)` **103/103 全等**。
vendor 的 `mask=0xd1` 在 phy 驱动结构体里对应 `.delay_us = 0x01`（字段语义不同、编码相同），
上表最后两行证明 5 条延迟项一一对应。

原始日志：`logs/40-table-diff.txt`。

## 门禁汇总

| # | 门禁 | 结果 |
|---|---|---|
| ① | 纯净 gh/master blob 上 `git apply --check` | **rc=0**（2/2 枚） |
| ② | `checkpatch --strict` | **0E/0W/0C**（0001 10 行、0002 162 行） |
| ③ | `W=1` 编译 `drivers/phy/qualcomm/`（含目标文件） | **rc=0，0 warning** |
| ④ | `dt_binding_check`（改了 binding） | **rc=0** |
| 5 | 13 条 data 对账 | **13/13**，与 vendor 表 103/103 全等 |
| 6 | `git am` 实跑 | **2/2 干净落地** |

## 6. `git am` 实跑（补门禁 ① 的「能直接投」侧）

```
$ git clone -q /tmp/csiphy-git /tmp/amtest && cd /tmp/amtest
$ git checkout $(git log --format=%H | tail -1)      # base
$ git am $D/0*.patch
应用：dt-bindings: phy: qcom,x1e80100-csi2-phy: add SM8750 CSI2 PHY
应用：phy: qcom: mipi-csi2: add SM8750 2.4.0 lane settings
$ git diff --stat HEAD~2..HEAD
 .../bindings/phy/qcom,x1e80100-csi2-phy.yaml       |   4 +-
 drivers/phy/qualcomm/phy-qcom-mipi-csi2-3ph-dphy.c | 136 +++++++++++++++++++++
 drivers/phy/qualcomm/phy-qcom-mipi-csi2-core.c     |   1 +
 drivers/phy/qualcomm/phy-qcom-mipi-csi2.h          |   1 +
 4 files changed, 141 insertions(+), 1 deletion(-)
```

⇒ 2/2 枚 `git am` 干净落地，无 `-3`、无 conflict。
| 6 | `git am` 实跑 | **2/2 干净落地** |
