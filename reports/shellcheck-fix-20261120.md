# shellcheck 两处复核与全仓复跑（2026-11-20）

## 结论（数字）
- 指定的 2 处：**均为真问题，已修**，修后 `shellcheck -S error` 两文件 **0 命中**，`bash -n` 均过。
- 全仓复跑（`find scripts -name '*.sh' | xargs -P4 -n1 timeout -k 3 120 shellcheck -S error`）：
  **error 级命中 2 个文件 / 2 条**（见 §3）。
- `check-doctor.sh`：**FAIL=0，WARN=7**。本次两处修改不触及 check-doctor 检查面，WARN 组成无变化预期（本轮未留存改前 WARN 基线，故记「未见差异证据」而非「无变化」）。

## 1) scripts/rebuild-vk64-image.sh:96 — SC1073/SC1072
- 原始输出：`SC1073 (error): Couldn't parse this redirection` @ 列 63（fail 参数里的反引号串 `` `git -C $KDIR checkout -- <文件>` ``，shellcheck 把 `<文件` 当重定向解析后失配）。
- `bash -n` 原本就过 ⇒ 不是 bash 语法错，而是 shellcheck 解析限制；但它卡住了该文件后续所有检查（SC1072 "Fix any mentioned problems"），且反引号内嵌 `<` 属易踩写法。
- **改前**：fail 文案用反引号包 `git ... checkout -- <文件>`；shellcheck error 级中断解析。
- **改后**：反引号改单引号（`'git -C $KDIR checkout -- <文件>'`），**运行行为完全等价**（同一字符串字面量，且该处本无命令替换意图——原写法在 bash 里会把 `<文件` 当重定向执行、直接改写 fail 语义，属潜在逻辑坑）。

## 2) scripts/uefi-build-variant.sh:162 — SC2081
- 原始输出：`SC2081 (error): [ .. ] can't match globs. Use [[ .. ]] or case statement.` @ `[ "$SHIM" != custom:* ]`。
- **真逻辑错**：`[ ]` 做字面比较，条件只在 SHIM 恰好等于字符串 `custom:*` 时为假 ⇒ custom shim 场景下**仍会 rm BootShim 产物并跑 stock build_boot_shim.sh**（恒真分支）。
- **改前**：custom shim 时错误地重建 stock shim。
- **改后**：等价语义改 `case "$SHIM" in custom:*) ;; *) rm -f …; ./build_boot_shim.sh …;; esac`，custom 分支跳过、其余照旧。

## 3) 全仓剩余 error 级命中（2 条，未改——非本轮指定范围）
| 文件 | 码 | 判读 |
|---|---|---|
| scripts/lib-device-lock.sh:1 | SC2148 缺 shebang | **有意为之**：被 source 的 lib 片段（首行注释 `SINGLE source of the tablet device lock`），非可直接执行脚本。可加 `# shellcheck shell=bash` 消除。 |
| scripts/lib-fastboot.sh:68 | SC2199 `"${@: -1}"` 于 `[[ =~ ]]` | **疑似真问题（低危）**：数组隐式拼接在 bash 当前可工作（取最后一个参数），但属脆弱写法；建议改 `last=${*: -1}` 后再比对。留待后续轮。 |

## 4) 验证命令与结果
```
$ bash -n scripts/rebuild-vk64-image.sh && bash -n scripts/uefi-build-variant.sh   # 通过
$ shellcheck -S error scripts/rebuild-vk64-image.sh scripts/uefi-build-variant.sh  # exit=0，无输出
$ find scripts -name '*.sh' | xargs -P4 -n1 timeout -k 3 120 shellcheck -S error   # error 命中 2 条（§3）
$ timeout -k 3 240 bash scripts/check-doctor.sh                                    # 汇总: FAIL=0 WARN=7
```
