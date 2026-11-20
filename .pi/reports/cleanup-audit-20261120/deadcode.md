# 死代码/失效引用遍历 — 2026-11-20（只读）

生成日期 2026-11-20。依据：`shellcheck -S error scripts/*.sh`（全量 313 个入口）、`find . -name '*.pyc'`、`grep` 交叉引用、`reports/audit-20261119/A3-scripts-audit.tsv` 抽验。pyflakes/vulture/cargo **未安装**（`which` 空），对应检查未跑；项目无 Rust 树。

## 命中项
| 路径 | 判定方法 | 风险 | 状态 |
|---|---|---|---|
| `scripts/rebuild-vk64-image.sh` | `shellcheck -S error` → **SC1072/SC1073 Couldn't parse this redirection**（`fail "…反引号…"` 行，解析中断，后续检查被遮蔽） | 中：该脚本是 vk 重建门禁之一，解析失败段可能藏真 bug；也可能是纯提示文案转义问题 | 疑似真问题，建议人工看该行；修文案转义即可 |
| `scripts/lib-fastboot.sh` | SC2199 `[[ "${@: -1}" =~ ]]` 数组隐式拼接 | 低：功能在 bash 下通常仍对，但语义脆 | 疑似；改 `"${*: -1}"` 或循环 |
| `scripts/uefi-build-variant.sh` | SC2081 `[ "$SHIM" != custom:* ]` glob 不匹配 | 中：`[ ]` 不做 glob 匹配 ⇒ 该分支恒走「非 custom」路径，可能是真逻辑错误 | 疑似真问题（若 SHIM 只会是字面量 `custom:*` 则无害） |
| `scripts/lib-device-lock.sh` | SC2148 无 shebang（sourced lib，非缺陷） | 无 | 误报，加 `# shellcheck shell=bash` 即静默 |
| `scripts/wd-audio-test/Test{Audio,Codec,Record}.java` | A3 判零引用 DELETE-CANDIDATE；本轮 grep 复核 `TASKS/README.md:516`、`TASKS/sessions/2026-11-06-…C6.md:15` 按名引用 | 低 | **改判 KEEP-ARCHIVE**（死代码判定不成立，是历史证据件） |
| `tools/__pycache__/avbtool.cpython-314.pyc`、`rootfs/debian/ime/__pycache__/fcitx5-indicator.cpython-314.pyc` | find；编译缓存可再生 | 无 | 可删（删文件动作留主会话） |
| 文档引用文件存在性 | check-doctor §RUNBOOK「引用的 10 个仓内路径都在」= ok；另 5 处死指针见 `cleanup-proposals.md` (c) 表（bake-vendor.sh / custom_vm.md / tools/wd-audio-test / BRINGUP-NEW-TABLET* / docs/） | 低（文档误导） | 已列 D1 |
| 未跟踪产物 | `git status --short` → `reports/audit-20261119/`（11 文件）与 `PITFALLS/sessions/326-*.md` 未提交 | 低：审计结论未入库，断电/误清即丢 | 建议主会话 `git add` 提交（非本轮权限） |

## 未跑的检查（工具缺失）
- `pyflakes` / `vulture`：未安装。仓内 ~60 个 `scripts/*.py` 未做未用符号扫描；如需可 `pip install vulture` 后补跑。
- `cargo check`：仓库无 Rust 工程，不适用。
- shellcheck 仅跑到 `-S error` 级；`-S warning` 级噪音大未列。

## 汇总
shellcheck error 级命中 4 文件（其中 2 条疑似真逻辑问题：SC1073 解析中断、SC2081 glob 恒假）；死代码实锤 0（3 个 Java 删除候选经复核改判归档）；可再生产物 2 个 .pyc；文档死引用 5 处（列 D1）。
