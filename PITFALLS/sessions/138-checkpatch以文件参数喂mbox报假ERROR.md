# #474 · `checkpatch.pl` 用「文件参数」喂 mbox 会伪造 ERROR（必须 stdin）

- 日期：2026-10-31
- 发现场景：投递前静态门禁独立复核（lane D，`reports/code-boundary-preinject-20261031.md`）
- 影响：会得出「补丁有 2–18 条 ERROR」的假 FAIL，进而错误回退/重写**本来干净**的补丁；反之若把它当噪声忽略，又会漏掉真问题。两种错都很贵。

## 现象

同一枚补丁、同一份树内 `checkpatch.pl`（v0.32），两种调用给出不同结果：

| 调用 | 结果 |
|---|---|
| `perl scripts/checkpatch.pl --strict --patch patches/upstream/xxx/0001-*.patch`（**文件参数**） | 每枚 **2–18 条 ERROR**，`lines` 计数虚高 |
| `cat 0001-*.patch \| perl scripts/checkpatch.pl --strict --patch -`（**stdin**） | 与既有回执逐字吻合（如 `0E/0W/0C, lines=91`） |

## 根因（两条独立机制）

① **邮件头被当成补丁正文**：文件参数路径下 `--patch` 的 mbox 头处理与 stdin 不一致，`From:`/`Subject:`/`Date:` 等头上报成
   非法行；diff 前的散文段被误当 body 一起 style 检查。
② **上下文空行里的单一空格被报 `trailing whitespace`**：diff 上下文行以 ` ` 开头，patch 正文里常写成 `␠`（末尾仍是空格）与
   `--␠`（签名分隔符带行尾空格是 mbox 固有形态），文件参数路径未剥离 ⇒ 每枚稳定复现 2 条以上假 ERROR。

## 判据

- 认为「补丁不干净」之前，**必须用 stdin 复跑一遍**：`cat <patch> | perl <tree>/scripts/checkpatch.pl --strict --patch -`。
- 两次结果不一致 ⇒ 以 **stdin** 为准（与上游 `git send-email` / patchwork 的输入形态一致）。
- 记录 `0E/0W/0C` 时**必须同时记 `lines`**：`lines` 明显偏大就是喂错形态的信号。

## 附带（同一 lane 的其它静默门禁坑）

- `make dt_binding_check` / `dt-validate` 的 rc **恒 0**（#470/#471）——本坑与它们同类：**rc 与计数都不能只看一层**。
- 依赖系列在 pristine 上 `git am` 才能判自足（#463）：本次 m3v5 的 `v5×2` 直接打 pristine **FAIL rc=128**，须 `v4×3` 打底。
- 有依赖的系列**必须带 cover** 说明依赖关系与「`usb_role_switch_at_endpoint()` 不在 7.3-rc7」这类前提，否则上游一律退回。
