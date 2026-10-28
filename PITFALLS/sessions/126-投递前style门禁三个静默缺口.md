# #462 投递前 style 门禁的三个静默缺口（dt-check-style / yamllint / commit message）

## 结论（2026-10-28，wl2868c binding 被判「broken patch」后反查）

① **`scripts/dtc/dt-check-style` 必须用 `~/.local/opt/dtschema-venv/bin/python`**：
   系统 `python3` 会 `ModuleNotFoundError: ruamel` ⇒ 直接跑等于没跑。
② **`make dt_binding_check` 里 yamllint 那一步会被 Makefile 静默跳过**（`DT_SCHEMA_LINT` 为空），
   所以「`dt_binding_check` rc=0」**不等于** yaml 风格过关 ⇒ 必须单跑 `dt-check-style --mode=relaxed`。
③ **checkpatch 不校验 commit message 里的 diffstat**：
   手写一份 `---` + `X files changed` 贴着 `Signed-off-by:` 也能 0E/0W/0C 过关，
   而 `git format-patch` 又会自动再生成一份 ⇒ 上游看到两份 stat、且第一份紧贴 SoB 无空行，
   直接判 **broken patch**（Krzysztof Kozlowski 原话）。
   判据只能靠 `git am` 后 `git log -1 --format=%B` 回读，或 `grep -c '^---$'` / `grep -c 'files changed'` 必须各 =1。

## 定式（投递前四步）

```sh
perl $TREE/scripts/checkpatch.pl --strict --no-signoff --no-tree <patch>       # 0E/0W/0C
~/.local/opt/dtschema-venv/bin/python scripts/dtc/dt-check-style --mode=relaxed <yaml>
make dt_binding_check DT_SCHEMA_FILES=<yaml>                                   # rc=0（不覆盖第 2 步）
git am <patch> && git log -1 --format=%B | grep -c 'files changed'             # 必须 1
```

## 事实

- 真正「broken」的是**格式**，不是内容：`git apply --check` 一直 rc=0，diff 段与投递件逐字节一致。
- 修法 = 用真 commit + `git format-patch` 重生成（v2 已 3 封 250 投出）。
