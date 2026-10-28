#!/usr/bin/env python3
"""lore-fetch-raw.py — 按 Message-ID 直接从 lore 取 raw（自动过 Anubis PoW）。

为什么不用 curl：lore 已上 Anubis PoW，`curl` 带 UA 也只回挑战页（`PITFALLS #444`）；
本脚本复用 `~/.local/bin/lore-query.py` 的过挑战逻辑（含 cookie 缓存 `/tmp/lore-cookies.txt`），
只把结果换成 raw 原文，便于**逐字节**复核投递。

用法：
    scripts/lore-fetch-raw.py <list|all> <message-id> [<message-id> ...] [-o DIR]
例：
    # 单封
    scripts/lore-fetch-raw.py all 20261028034105.326535-6-xiaqinghuan@mail.ustc.edu.cn
    # 整串（自动把每封写进 DIR/<序号>.raw，并打印 Subject）
    scripts/lore-fetch-raw.py all $(for i in $(seq 1 10); do \
        echo 20261028034105.326535-$i-xiaqinghuan@mail.ustc.edu.cn; done) -o /tmp/lore-m4

坑（都踩过）：
  * **Message-ID 不要带尖括号**：`/all/<...>/raw` 会让 Anubis 的 pass-challenge 返回 404；
    直接拼 `https://lore.kernel.org/<list>/<msgid>/raw` 即可。
  * 归档列表名不是邮箱列表名：`devicetree` → `/linux-devicetree/`、`lkml` → `/linux-kernel/`、
    `linux-arm-msm` 两者同名；拿不准先用 `all`。
  * 整串复核判据（推荐）：把取回的 raw 拼成 mbox，**去掉 0/N 的 cover letter**（它没有 diff，
    `git am` 会报「补丁为空」），在 pristine 上 `git am`，再与源分支 `git diff` 比 —— 空 =
    标题/正文/diff 全链路逐字节一致。
"""
import importlib.util
import pathlib
import sys

LQ = pathlib.Path.home() / ".local/bin/lore-query.py"
if not LQ.exists():
    sys.exit(f"缺少 {LQ}（Anubis 过挑战实现）")

spec = importlib.util.spec_from_file_location("lq", LQ)
lq = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lq)

args = sys.argv[1:]
outdir = None
if "-o" in args:
    i = args.index("-o")
    outdir = pathlib.Path(args[i + 1])
    del args[i:i + 2]
if len(args) < 2:
    sys.exit(__doc__)
lst, msgids = args[0], args[1:]
if outdir:
    outdir.mkdir(parents=True, exist_ok=True)

rc = 0
for n, mid in enumerate(msgids, 1):
    url = f"https://lore.kernel.org/{lst}/{mid.lstrip('<').rstrip('>')}/raw"
    final, body = lq.fetch(url)
    if isinstance(final, str) and final.startswith("!!"):
        print(f"{n:3d}  {final}  {mid}", file=sys.stderr)
        rc = 1
        continue
    subject = next((l for l in body.splitlines() if l.startswith("Subject:")), "?")
    if outdir:
        (outdir / f"{n}.raw").write_text(body)
        print(f"{n:3d}  {len(body):7d} B  {subject[:78]}  -> {outdir}/{n}.raw")
    else:
        sys.stdout.write(body)
sys.exit(rc)
