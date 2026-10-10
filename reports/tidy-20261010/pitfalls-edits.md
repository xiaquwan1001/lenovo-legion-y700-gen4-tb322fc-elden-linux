# PITFALLS.md 精确替换块（T3，提案，父执行）

> 只收**证据确凿、无需裁决**的三类：幻影引用更正、明显占位/笔误、旧条目尾部追加「⚠ 已被 #16x 推翻/收窄」。
> 每个 OLD 块 `grep -F` 全文件唯一性已验证（结果见 `pitfalls-audit.md` §A–C 与下方各行）。**worker 未执行任何替换**，交父代理落地。
> 删除/合并/映射存疑项一律在 `pitfalls-audit.md`「需裁决清单」，不在此处。

---

## 块 1 — 幻影引用 #299/#300 → #157（目标文件 = TASKS.md）

**理由 + 证据**：`PITFALLS` 无 #299/#300（最大编号 165）。TASKS.md G1-22 该句描述「相机模块没加载 → 是配置态、不是驱动坏」的误判，正是 **#157**「守卫静默 `exit 0` ⇒ 相机不可用被当成驱动问题（实为配置态）」所记教训。简报预批此映射（对应 #157–#159 区间，精确匹配 #157）。
**验证**：`grep -Fc 'PITFALLS #299/#300 那一类误判' TASKS.md` → `1`（唯一）。

<<<OLD file=TASKS.md
PITFALLS #299/#300 那一类误判
===
PITFALLS #157 那一类误判（守卫静默 `exit 0` 把配置态误判成驱动坏）
>>>

---

## 块 2 — 占位号「`#` 新条目」→ #162（目标文件 = PITFALLS.md §15.1）

**理由 + 证据**：§15.1「vk81/82/83 死内核」行写「构建侧已加守卫（见 `#` 新条目）」，`#` 是未填占位；该守卫条目已定稿为 **#162**（#162 正文明确「build-kernel.sh 加编后符号守卫；apply-kernel-fragment.sh 回钉」）。
**验证**：`grep -Fc '构建侧已加守卫（见 `#` 新条目）' PITFALLS.md` → `1`。

<<<OLD file=PITFALLS.md
构建侧已加守卫（见 `#` 新条目）
===
构建侧已加守卫（见 #162）
>>>

---

## 块 3 — #9 尾部追加「⚠ 收窄（#162）」（目标文件 = PITFALLS.md #9）

**理由 + 证据**：#9 说「绝不**手动**跑 olddefconfig」且「已内置校验」，但 **#162** 证实 olddefconfig 经 `apply-kernel-fragment.sh` 合并片段后**自动**运行并删 `ARCH_QCOM`，原 `grep ^ARCH_QCOM` 守卫只在编前查（有漏），现已升级为**编后符号守卫 + 片段后回钉**。属收窄，非否定 #9 主旨。
**验证**：`grep -Fc '已内置校验；根目录兼容包装 `build.sh`/`iterate.sh`/`pack.sh` 已删除。）' PITFALLS.md` → `1`。

<<<OLD file=PITFALLS.md
   （`scripts/build-kernel.sh` 已内置校验；根目录兼容包装 `build.sh`/`iterate.sh`/`pack.sh` 已删除。）
===
   （`scripts/build-kernel.sh` 已内置校验；根目录兼容包装 `build.sh`/`iterate.sh`/`pack.sh` 已删除。）
   ⚠ **收窄（#162）**：`olddefconfig` 不止手动跑——`apply-kernel-fragment.sh` 合并片段后会**自动**跑它并删 `ARCH_QCOM`（致 vk81/82/83 无 QCOM 驱动的死内核）。原 `grep ^ARCH_QCOM` 守卫只**编前**查、有漏；现已升级为**编后符号守卫**（缺 gcc_sm8750/msm_dsi_host_bonded_cmd_trigger/rpmh → exit 1）+ 片段后回钉。详见 #162。
>>>

---

## 块 4 — #16 尾部追加「⚠ 收窄/推翻（#164、#165）」（目标文件 = PITFALLS.md #16）

**理由 + 证据**：#16 把根因记为「面板 init 失败（DSI DCS 首写超时）→ DPU vblank 刷屏」、以「数风暴签名」判 GOOD。**#164** 定案根因 = bonded 双 DSI 首条 DCS 的**命令 DMA 引擎 hang**（L1），vblank/CTL reset 为其下游 L2；**#165** 指出冷起另有 **NOCARD**（无 card0、DSI PLL 未锁）模式，「无风暴签名」有盲区、GOOD 须三态。
**验证**：`grep -Fc 'logs/kmsg-vk63-nodesktop-2026-10-08.log`。' PITFALLS.md` → `1`。

<<<OLD file=PITFALLS.md
    - 待查：失败时 `dsi host`/PHY 上下文；旧基线（vk62）是否同样存在（历史 #16 即「偶见」，应非 vk63 引入）；是否与快速连续 reboot（面板无冷却）相关——下次可试完全断电冷启对比。详见 `TASKS.md` §5 Q28、`logs/kmsg-vk63-nodesktop-2026-10-08.log`。
===
    - 待查：失败时 `dsi host`/PHY 上下文；旧基线（vk62）是否同样存在（历史 #16 即「偶见」，应非 vk63 引入）；是否与快速连续 reboot（面板无冷却）相关——下次可试完全断电冷启对比。详见 `TASKS.md` §5 Q28、`logs/kmsg-vk63-nodesktop-2026-10-08.log`。
    ⚠ **收窄/推翻（#164、#165）**：根因细化为 bonded 双 DSI 首条 DCS 的**命令 DMA 引擎 hang**（L1）；vblank/CTL reset 风暴是其**下游**（L2），非独立 bug（#164）。冷起另有 **NOCARD**（无 card0、DSI PLL 未锁）模式，「无风暴签名」≠「显示好」，GOOD/BAD 判据须三态（NOCARD/STORM/GOOD，#165）。且真实变量是**冷/暖复位**而非时间（#163）。
>>>

---

## 块 5 — #60 尾部追加「⚠ 已作废（#114）」（目标文件 = PITFALLS.md #60）

**理由 + 证据**：#60 结尾仍写「每次进 fastboot 后、任何操作前，先 `fastboot --set-active=a`」。**#114**（口径更正清单）明确记录：AGENTS 原「进 fastboot 后先 `fastboot --set-active=a`」是**错误规则、已删除**，本意是不动在用的 b 槽，现改为「不要改 active slot」；槽位读写改用 `qbootctl`（#126/#133）。属规则作废。
**验证**：`grep -Fc '接 `fastboot reboot bootloader`，等 6~8 秒再单条重试。' PITFALLS.md` → `1`。

<<<OLD file=PITFALLS.md
    `fastboot boot` 报 `Status read failed` 时，接 `fastboot reboot bootloader`，等 6~8 秒再单条重试。
===
    `fastboot boot` 报 `Status read failed` 时，接 `fastboot reboot bootloader`，等 6~8 秒再单条重试。
    ⚠ **已作废（#114）**：上方「先 `fastboot --set-active=a`」是**错误规则，AGENTS 已删除**，现口径 = **不要改 active slot**（保护在用的 b 槽）。槽位读状态/mark-successful 改用 `qbootctl`（#126/#133）。本动作勿再照做。
>>>
