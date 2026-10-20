# 内核 ABI 变体固化：内核镜像 + 模块树必须同进同退（2026-10-20）

- **背景**：`reports/vk129-abi-fix-verified-20261020.md` 证明 `CONFIG_SUSPEND` 改的是 **ABI**（`dev->fwnode` 632→688），
  vk128/vk129 的「启动即死」全是模块树没跟着重编。
- **本轮做的事**：用户决定 **suspend 能力固化保留**（设备现跑 vk129），因此需要一套
  「内核与模块树永不脱钩」的机制，否则下一次回滚就是同型 panic。

## 1. 核心风险（为什么必须专门处理）

vk127 与 vk129 的 **UTS 字符串完全相同**：

```
vk127: Linux version 7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty
vk129: Linux version 7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty
```

⇒ 两者共用 `/lib/modules/<UTS>` 这一个路径，**但 ABI 不同**：

| 变体 | 来源配置 | `CONFIG_PM_SLEEP` | `dev->fwnode` | `coresight.ko` |
|---|---|---|---|---|
| nosuspend | vk127 | 0 | 632 | 143 032 B |
| suspend | vk129 | 1 | 688 | 3 456 536 B |

加上 `CONFIG_MODVERSIONS` 未开 ⇒ **没有任何 CRC 门**，错配会静默加载然后在 `[0.55 s]` panic。
「刷回 vk127 内核但忘了换模块树」= 立刻复现今天的故障。

## 2. 落地结构（设备上）

```
/lib/modules/7.3.0-rc7-debug-vk127-…-dirty                 → 符号链接（当前挂载点）
/lib/modules/7.3.0-rc7-debug-vk127-…-dirty-abi-suspend     ko=1497  coresight=3456536   ← 当前
/lib/modules/7.3.0-rc7-debug-vk127-…-dirty-abi-nosuspend   ko=1498  coresight=143032
/lib/modules/7.3.0-rc7-debug-vk127-…-dirty.vk127old        首次回滚备份（保留）
/lib/modules/vk127-backup-20261020                         首次全量备份（保留）
```

**挂载点是符号链接** ⇒ 切换模块树 = `ln -sfn`，原子且可秒回。

## 3. `scripts/switch-kernel-abi.sh`

把「刷内核」+「换模块树」做成一个原子操作，并**切换后验证**：

```
scripts/switch-kernel-abi.sh --list              # 清点：运行 ABI / 各变体 .ko 数 / 主机镜像
scripts/switch-kernel-abi.sh --to suspend --check # 零副作用预检
scripts/switch-kernel-abi.sh --to nosuspend      # 真切（模块树 + fastboot 刷内核）
```

设计要点：

| 要点 | 实现 |
|---|---|
| **判断运行的是哪个 ABI** | 读 `/proc/config.gz` 的 `CONFIG_PM_SLEEP` —— **不能靠 `uname -r`**（两者相同） |
| 切换前拒绝不完整变体 | 目标树 `.ko < 1000` 直接拒跑（今天踩过 1005/1497 截断） |
| **切换后探针** | `modprobe coresight` —— vk129 下这正是原崩溃点，能过 = ABI 匹配 |
| 探针失败 | 自动回滚模块树，不再往下刷内核 |
| 设备不在 fastboot | **只切模块树会报错退出（rc=2）**，明确告知「当前内核与模块树已不一致」并给出补救命令 |

## 4. 已验证

- `--list` 正确识别「运行 ABI = suspend」（依据 `CONFIG_PM_SLEEP=y`）
- `--to nosuspend --check` 预检通过（目标 1498 ko，镜像 sha `dc213263…`）
- 两个变体完整性：`coresight.ko` / `camcc-sm8750.ko` 都在，`modules.dep` 非空
- 挂载点解析正确：`readlink -f` → `…-abi-suspend`，`ko=1497`

## 5. 仍未消除的风险（如实记账）

1. **`CONFIG_MODVERSIONS` 仍是关的**。本机制靠「流程纪律 + 脚本」防错配，**不是靠内核自证**。
   真正的硬保证是开 `CONFIG_MODVERSIONS=y`：错配会在 `modprobe` 时明确报 CRC 不匹配，而不是 panic。
   → 建议作为下一步（需整树重编内核+模块，代价一轮构建）。
2. 脚本的 fastboot 分支**尚未实跑过**（今天只验证了 `--list` / `--check`）。
   首次真跑切 nosuspend 时才会走到 `[3/3]`。
3. `vk127old` / `vk127-backup-*` 两份备份占 ~180 MB，确认稳定后可删。

## 6. 关联

- `reports/vk129-abi-fix-verified-20261020.md`（根因与实证）
- `PITFALLS #360`（config 改 ABI）、`#362`（olddefconfig 写 x86）
- `TASKS/README.md` T8（已闭环）
