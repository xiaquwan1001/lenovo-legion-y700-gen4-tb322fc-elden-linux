# 120 · #457 按 Message-ID 取 lore raw 的三个具体坑（投递逐字节复核）

- **日期**：2026-10-28
- **场景**：M4-2…M4-4 系列投递后复核（`PITFALLS #444` 已说「Anubis 会挡 curl」，本条是**过挑战之后**的具体操作坑）。

## 坑 1：Message-ID 带尖括号 ⇒ `pass-challenge` 返回 **404**

```sh
# ❌ 会 404（尖括号进 URL 路径，Anubis 的 redir 拼坏）
https://lore.kernel.org/all/<20261028034105.326535-6-xiaqinghuan@mail.ustc.edu.cn>/raw
# ✅
https://lore.kernel.org/all/20261028034105.326535-6-xiaqinghuan@mail.ustc.edu.cn/raw
```

症状是 `!! pass-challenge HTTP 404`，而**同一脚本、同一 cookie** 换掉尖括号立刻 200 ——
很容易误判成「Anubis 逻辑坏了」或「这封没归档」。

## 坑 2：`lore-query.py --help` 会崩（它把参数当 URL）

`ValueError: unknown url type: '--help?x=A'` —— 脚本无参数解析。要复用它的过挑战能力，
用 `importlib` 加载它、只调 `fetch(url)`（仓库版 `scripts/lore-fetch-raw.py` 就是这么做的）。

## 坑 3：整串 raw 拼 mbox 后 `git am` 会停在 **「补丁为空」**

`[PATCH 0/N]`（cover letter）**没有 diff** ⇒ `git am` 报 `补丁为空` 并停。复核整串时
**去掉 0/N 那一封**再 `git am`；判据 = 重放后与源分支 `git diff` **空**。

## 现成工具（已入库）

```sh
# 取整串（自动打印 Subject，写 DIR/<n>.raw）
python3 scripts/lore-fetch-raw.py all $(for i in $(seq 1 10); do \
  echo 20261028034105.326535-$i-xiaqinghuan@mail.ustc.edu.cn; done) -o /tmp/lore-m4
# 整串完整性复核
cat /tmp/lore-m4/{2..10}.raw > /tmp/m.mbox          # 跳过 1.raw（cover）
cd <kernel-tree> && git checkout -B verify/lore <pristine> && git am /tmp/m.mbox
git diff --stat verify/lore <源分支>                 # 空 = 标题/正文/diff 全链路一致
```

实测（2026-10-28 M4 系列）：`/all/` 10/10 归档、抽查 `/linux-media//linux-arm-msm//linux-devicetree/` 均 200、
重放 9/9 且 `git diff` 空、Sent Items 10/10、INBOX 回环 10/10。
