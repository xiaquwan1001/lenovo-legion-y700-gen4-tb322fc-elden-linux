## #447 `mod-loop.sh` 的「reloaded」曾经是假的 —— 三处静默失败 + 一个把自己搞坏的 `make -B`

> 2026-10-27 devcam-ab lane 首轮踩到、收口时修掉。本条记录**两类**教训：
> ① 工具链的静默失败（已修，`scripts/mod-loop.sh`）；② **诊断时用破坏性命令验证非破坏性问题**（我自己的操作错误，留下一处需人工恢复的现场）。

### 一、`mod-loop.sh --reload` 的三处静默失败（已修）

三处叠加后，脚本在**模块根本没换**的情况下逐行打印成功，并以 `rc=0` 退出：

① **名字归一化缺失（最致命）**：传入的是 `.ko` 基名 `qcom-camss`（连字符），而 `lsmod`/`modprobe` 用的是 `qcom_camss`（下划线）。
   旧代码 `lsmod | grep -q '^$m '` 匹配不到 ⇒ **`rmmod` 那一步从不执行**；随后的 `modprobe 'qcom-camss'` 也不存在该名 ⇒ 失败被 `2>/dev/null` 吞掉；
   由于用的是 `|| echo 'WARN'`，循环继续，最后仍打印 `[mod] reloaded qcom-camss`。
② **`modules_install` 的目的地来自 `include/config/kernel.release`**，而 `M=<dir>` 构建**不会刷新**该文件。
   树里是 `…-dirty+`（`setlocalversion` 给脏树补 `+`）、设备要 `…-debug-vk172` ⇒ 模块被装进**错误的 `<KV>` 目录**，`depmod` 索引里没有它，热载静默无效。
③ **`modules_install` 还依赖全局 `modules.order`**：`.config` 一churn，该目标就可能不重建 ⇒ `no .ko staged`，
   而旧文案把这句**误报成「driver is built-in」**，把人引向翻 tristate 的错方向。

**修法（已落地）**：不再走 `modules_install` 这一跳 —— 直接从 `$KDIR/$DIR` 收 `.ko`，以 `updates/<name>.ko` 布局上传
（`updates/` 在 `depmod` 搜索序里优先于树内 `kernel/` 副本）；名字归一化 `tr '-' '_'`；`modprobe` 失败**必须非零退出**；
并新增 **build-id 硬校验**：比对 `/sys/module/<mu>/notes/.note.gnu.build-id` 与刚编出的 `.ko`，
不一致或缺失则 `exit 1`。

**判据（本机实测，2026-10-27）**：

```
[mod] built: qcom-camss
[mod] reloaded qcom-camss (as qcom_camss)
[mod] ✅ build-id match qcom_camss: 1fe5d2ccc6d241ff1c2e134366da51d7897c8f05
```
负向测试（故意传不存在的名字 `qcom-camss-nonexistent`）现在正确打印
`❌ … device keeps the OLD module` + `❌ 热载未确认成功` 并以 **rc=1** 退出（旧版在同样情形下 rc=0 且打印 reloaded）。

### 二、纪律：不要用 `make -B` 去「验证」一个关于生成文件的猜想

修第二处（`modules_install` 的目的地）时我想确认「`include/config/kernel.release` 能否按需重建」，于是跑了
`make -B -s include/config/kernel.release`。`-B` 会**无条件重建该目标的整条依赖链（含 syncconfig）**，
结果把 `build/vk151/.config` 从 12 047 行 / `=m` 1464 项**改写成 9 042 行 / `=m` 686 项**，
`CONFIG_VIDEO_QCOM_CAMSS` 等 900 多个符号被清掉 —— 也就是**把日常线内核树的配置搞坏了**。

- **恢复**：`.config` 不被 git 跟踪，但 **`out/boot-elden-vk172.manifest` 记了 `config_sha256=91dbc727…`**，
  且 `patches/config-vk163-modular-v2-20261026` 的 sha256 前缀正是 `91dbc727` ⇒ 用该快照逐字还原，
  校验 `sha / 行数 / =m 数 / CAMSS 行` 四项全部回到原值。**教训**：配置文件本身要有可校验的还原源（本仓靠 manifest 的 sha256 反查快照）。
- **规矩**：验证「某生成文件能否重建」应该用**只读**手段（读 `Makefile` 的 target 定义、或在**一次性 worktree/副本**里试），
  绝不在日常线树上跑 `-B`/`clean`/`mrproper`。这与 #54（构建机静默文件损坏）同类：**验证动作本身不能有副作用**。

### 三、连带规则

- 凡「热载/部署/刷写」类脚本，**成功判据必须是外部可观测事实**（build-id、`lsmod` 里模块的存在、读回校验），
  不能是脚本自己打印的一行字。与 #364/#365 的「调用返回 0 ≠ 动作发生」同源。
- 设备恢复基线时**回原始 ko**比回「重编的同源 ko」更严格：`rmmod` → 删 `updates/*.ko` → `depmod -a` → `modprobe`，
  再用 build-id 确认回到了开机那颗（本机基线 `2dd23e54…`）。
