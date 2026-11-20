# dwc3 v9 已发原文快照（2026-11-20 取，只读证据）

用途：v10 备料时**以已发原文为准**，不再靠本地 `patches/upstream/dwc3-v9-20261117/` 的二手副本推断。
本目录只存证据，不含新补丁；v10 正文在上一级（`../`，暂只放 `draft-binding.yaml.snippet`）。

## 1. 文件清单

| 文件 | 来源 | 字节 | sha256 |
|---|---|---|---|
| `pw-14991613.mbox` | `https://patchwork.kernel.org/patch/14991613/mbox/`（[v9,1/3] binding） | 11328 | `2bfee0b4c80112caf953f07ffc13fce807863bb8ebda19eab18f0c24d0f2e699` |
| `pw-14991611.mbox` | 同上，patch `14991611`（[v9,2/3] usb: roles） | 8960 | `792df8b8d58d9f60d05b85189760a110fe4f6b5ad8c4bd0896157d1b926fc73f` |
| `pw-14991612.mbox` | 同上，patch `14991612`（[v9,3/3] dwc3） | 26525 | `341d84e94863e81f0424855ac94a680b95b1b527118cc3c2bde4e8f21c4745c8` |
| `robh-20261118T152739Z-comment-on-3of3.txt` | patchwork comment id `27385237`，msgid `<20261118152739.GA1824160-robh@kernel.org>` | 1957 | — |
| `robh-20261118T153457Z-comment-on-1of3.txt` | patchwork comment id `27385282`，msgid `<20261118153457.GB1824160-robh@kernel.org>`（= 全文只有一个 `??` 那封） | 6699 | — |
| `mailinfo/*` | 上面三份 mbox 经 `git mailinfo` 拆出的 `msg`（commit message）与 `diff`（补丁体） | 见目录 | 下表 |

取件命令（本轮实跑，rc=0）：

```sh
for id in 14991613 14991611 14991612; do
  timeout -k 5 40 curl -sL "https://patchwork.kernel.org/patch/$id/mbox/" -o pw-$id.mbox
done
for id in 14991613 14991611 14991612; do
  ( mkdir -p /tmp/mi && cd /tmp/mi && git mailinfo msg-$id patch-$id < .../pw-$id.mbox >/dev/null )
done
```

> **API 路径坑（本轮实测）**：`/api/1.2/patches/<id>/mbox/` 返回 **404 HTML**（三份都 2889 B，`<title>404: File not found</title>`），
> 必须用 **`/patch/<id>/mbox/`**（不带 `/api/1.2`）。判别方法 = 看第一行是否为 `From patchwork ...`；是 HTML 即取件失败。

> **lore 取不到**：`https://lore.kernel.org/all/<msgid>/raw` 对本机出口返回 **403 / Anubis JS 挑战**（146 B nginx 403，加 UA 也只得到挑战页），
> 故 Rob 两封以 **patchwork 存档正文**为准（含 msgid/date 字段，可回查）。

## 2. 溯源核对：patchwork 存档 == 本地 v9 文件（逐字节）

`git mailinfo` 拆出的 diff 与本地 `patches/upstream/dwc3-v9-20261117/*.patch` 的补丁体比对：

| 枚 | patchwork diff sha256（前 16） | 本地 diff sha256（前 16） | 结论 |
|---|---|---|---|
| 1/3 binding | `0ea2e0e3ecf7b829` | `0ea2e0e3ecf7b829` | **逐字节相同**（本地文件从第 36 行起 vs mbox 补丁体第 7 行起；先 `tail -n +36` 再删尾部 `-- ` 签名块） |
| 2/3 usb: roles | `c571934004383e67` | `c571934004383e67`（`177f812d…` 为未去头部残留，见下） | **逐字节相同**（本地 diff 段需从 `diff --git` 起算；mbox 补丁体多出 4 行 `---`/pathstat，属 mailinfo 保留的分隔段） |
| 3/3 dwc3 | `068fd0893ef99ee0` | `068fd0893ef99ee0` | **逐字节相同**（各 19869 B，`diff -q` 无输出） |

⇒ 已发内容与本地备料一致，v10 可以本地文件为基线改，不需要重新从 mbox 反向生成。

## 3. 三个「已发原文」里的机械缺陷（v10 必须一并修掉）

1. **1/3 的补丁体没有 `diff --git` / `index` 行**（只有 `--- a/… +++ b/…`）。`grep -c '^diff --git' mailinfo/v9-0001-binding.diff` = **0**；
   2/3、3/3 正常。`git am` 能接受，但 patchwork/mail 客户端渲染与 `b4`/`quilt` 工具链对缺 `diff --git` 的补丁体兼容性差 ⇒ v10 一律用 `git format-patch` 出件，不许手写补丁体。
2. **1/3 邮件正文（`---` 之后）留着 DRAFT 块**：
   ```
   DRAFT: driver (3/3) still uses a GPIO and must be ported to mux_control_*
   in the same series; DTS (2/3 equivalent) must be rewritten to the new
   shape.  See README.md in this directory.
   ```
   而同一系列的 3/3 已经用 `devm_mux_control_get()`/`mux_control_select()`。Rob 的「??」正是**引用到这一段之后**给的。
   （`git am` 会丢弃 `---` 之后的内容，所以这行**没进 commit log**，只进了邮件正文 —— 只有列表读者/评审者看得到，最坏的一类泄漏。）
3. **1/3、3/3 的 commit message 是「相对上一版改了什么」**，不是「为什么要这个改动」。
   Rob 在 3/3 上单独说过（`<20261118152739.GA1824160-robh@kernel.org>`）："What changed in this version isn't really applicable for the commit message … The commit msg should answer 'why' … What has changed in each version is useful for review and that goes here after the '---'."

## 4. Rob 11-18 两封的原文定位

- 1/3（binding）上：**回复全文只有 `??`**（`robh-20261118T153457Z-comment-on-1of3.txt` **第 36 行**，两字独立成行；第 26–35 行是他引用的我方签名区 + `---` + DRAFT 块开头）。
- 3/3（driver）上：**同一天 15:27Z 一封有实质意见**（commit message 要写 why、变更日志放 `---` 之后），
  与「??」相隔 7 分钟 ⇒ 他当天在逐枚看这一串，对 binding 那枚只给了「??」。

## 5. 纪律

- 本目录只读：不改 mbox、不改 Rob 原文；新增证据另开文件。
- 不在此目录放新补丁（v10 补丁一旦生成，放 `../` 顶层并另写门禁账）。
