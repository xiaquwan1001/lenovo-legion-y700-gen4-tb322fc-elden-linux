# v3（iris colorspace 单贴）：只改 commit message，**未发**

- **产物**：`0003-v3-fill-default-colorspace.patch`（新文件；`0002-v2-…patch` 与 `SENT.md` 既有段落一字未动，
  v2 sha256 复跑仍 `35816a1bc7db3db9…`）
- **v3 sha256**：`713c41d2cfe81ff7668ce22f34eccf581cd1a2a5b701af35e33a64c319eb6e99`（116 行）
- **性质**：**v3 = v2 + 仅 commit message 重写**；`diff --git` 起的代码区逐字节相同（§2 有空 diff 证据）
- **门禁**：本机 checkpatch `--no-tree --strict` = **0 errors, 0 warnings, 0 checks**（改前 v2 = **2 errors, 4 warnings**）
- **判据来源**：media CI `10490`（`2026-11-28T01:27:06Z`）对我方 v2 判
  `ERROR: Fails one or more mandatory checkpatch tests`；明细见 `reports/comms-track-20261128-b.md` §3
- **未做**：未发信、未改 git 历史、未动 `TASKS/`/其他报告、未真发 `git send-email`（只跑 `--dry-run`）

---

## 1. 改动点清单（v2 → v3，全部在 commit message 内）

判红根因两条 + 一条同源风险，逐条对应：

| # | v2 原文（行号 = patch 文件行号） | checkpatch 规则 | v3 处置 |
|---|---|---|---|
| 1 | `:27  commit 1facae9bc3c1 ("media: iris: Fix bus_info prefix in` + `:28  VIDIOC_QUERYCAP", Vishnu Reddy, …` | **ERROR `GIT_COMMIT_ID`** | 压成**同一行** `:32 commit 1facae9bc3c1 ("media: iris: Fix bus_info prefix in VIDIOC_QUERYCAP")`（**75 字符，正好在 75 上限内**；标题用 `git.kernel.org` commit 页逐字核过） |
| 2 | `:29  Cc: stable@vger.kernel.org), which is already in mainline. My tree predates`（行首 `Cc:` + 前导空格） | **WARNING `BAD_SIGN_OFF`**（"Do not use whitespace before Cc:"，之后连带 2 条 email 格式 WARN） | 正文里**不再出现** `stable@vger.kernel.org` 与该行；改写成 `:35 Fixes tag and a stable Cc.  My tree predates it, …`；`Cc: stable@vger.kernel.org` **只做 trailer**（`:56`，无前导空格） |
| 3 | `:43  38fc8beaba55 ("media: iris: implement reqbuf ioctl with vb2_queue_setup"), which`（行首裸 sha + **80 字符**） | **ERROR `GIT_COMMIT_ID`**（裸 sha 被当作 commit 引用但无 `commit` 关键字/引号）+ **WARNING `COMMIT_LOG_LONG_LINE`** | 该引用的规范形态需 **80 字符**（>75 必 WARN），故改成 trailer 的 **`Link:`** 行（`:55`，checkpatch 对 `Link:`/`Fixes:`/签名行豁免行长与 commit-id 检查）；标题本身在 prose 里改为「the reqbuf ioctl commit that created iris_vdec.c」 |
| 4 | `:12`/`:21`/`:39` 等 5 行 76–80 字符（`COMMIT_LOG_LONG_LINE` 只报一次，故 CI 明细里看不到） | WARNING `COMMIT_LOG_LONG_LINE` | 全篇重排为 **≤75 字符**（唯二例外 = `Fixes:` 78 / `Link:` 96，均为规则显式豁免的 tag 行） |
| 5 | 正文 1/3、3/3 说明 | — | **保留语义**：`:29-38` 讲「1/3 与主线 `1facae9bc3c1` 重复 ⇒ 请 drop」，并**正面回应** Bryan 16:04Z 的「add Fixes/Cc」（"there is nothing left to tag there now that the fix is upstream"）；`:40-44` 讲「3/3 已被主线 `iris_vdec_s_fmt()` 无条件 crop seed 取代 ⇒ Dropped」 |
| 6 | `Subject: [PATCH v2]` / `Date:` | — | `[PATCH v3]`；`Date:` 更新为生成时刻（**实际发送时 git send-email 会重写为当前时间**，§5 dry-run 已证：patch 内 10:34:06 vs 报文 `10:34:21`） |

- 逐条纪律核对（派工单）：正文**无任何以 `Fixes:` / `Cc:` 开头的行** ✅；`commit <sha> ("<title>")` **不折行** ✅；
  `Cc: stable@vger.kernel.org` **只在 trailer** ✅；`Fixes:` 仍在 trailer（`:54`）✅。
- 另新增一句事实声明（`:24-25`）：「v3 只重写 commit message，diff 与 v2 逐字节相同，故未 rebase/未重测」——
  避免维护者以为拿到新版代码。

## 2. 代码 diff 未变（证据）

```sh
cd patches/upstream/v4l2-compliance-iris-20261127
diff <(sed -n '/^diff --git/,$p' 0002-v2-fill-default-colorspace.patch) \
     <(sed -n '/^diff --git/,$p' 0003-v3-fill-default-colorspace.patch)
# → 空输出（rc=0）
sed -n '/^diff --git/,$p' 0002-v2-fill-default-colorspace.patch | sha256sum
sed -n '/^diff --git/,$p' 0003-v3-fill-default-colorspace.patch | sha256sum
# → 两者同为 8515c6c11668747388c65682f237a90b35fa0ae835da0b0cedd767e1dc94a611
```

应用性旁证（只读，未改任何 worktree）：

```sh
git -C wt/fastrpc-sensorspd-test apply --check -v 0003-v3-fill-default-colorspace.patch   # rc=0
# 块 #1/#2/#3 均「成功应用」（偏移 -1/-1/-8 行，因该 worktree 的 iris_vdec.c blob
# = 9e228b70420e，非 patch 头的 pre-image 0dd33ff447bb，属不同基线，不影响 v2≡v3 结论）
git apply --stat 0003-v3-fill-default-colorspace.patch
#  drivers/media/platform/qcom/iris/iris_vdec.c | 25 +++++++++++++++++++++----
#  1 file changed, 21 insertions(+), 4 deletions(-)
```

## 3. checkpatch 判红复现（本机真实、可重跑）

### 3.1 为什么需要 `--no-tree` + 最小树

仓内 `linux/` 只有 `scripts/`（无顶层 `Makefile`），直接跑 checkpatch 会
`Must be run from the top-level dir`。故建 `/tmp/ktree`：

```sh
mkdir -p /tmp/ktree
printf 'VERSION = 7\nPATCHLEVEL = 4\nSUBLEVEL = 0\nEXTRAVERSION = -rc3\nNAME = Baby Opossum Posse\n' > /tmp/ktree/Makefile
cp -r /home/xuqianhui/y700-elden/linux/scripts /tmp/ktree/
```

### 3.2 「patch 是否被当成源码文件」的判据（已排除该假阳性）

- 判据：输出里出现 `FILE: <path>` 且 path 是 `.patch` 本身 ⇒ 未解析成 patch，结论作废。
- 本机结果：v2/v3 **都 0 次 `FILE:`**（`grep -c '^FILE:' = 0`），且 `43 lines checked` = 代码区行数。
- 反向自证（证明门禁真的在看代码，而不是空转）：往 v3 的 hunk 里塞一个行尾空格 ⇒
  `ERROR: trailing whitespace` + `#71: FILE: drivers/media/platform/qcom/iris/iris_vdec.c:40:`；
  往 commit message 里塞一行 `  Cc: stable@…` ⇒ 复现 `WARNING: Do not use whitespace before Cc:`。
  两项都只在 `/tmp` 的临时副本上做，未污染仓内文件。

### 3.3 `GIT_COMMIT_ID` 规则要「树里有该 commit」才判得准（关键坑）

读 `scripts/checkpatch.pl:3441-3472` + `git_commit_info`（`:1267-1297`）：它用
`git log -1 <sha>` 取**真实标题**，再与我们括号里的标题**逐字比较**；无 git 对象时
`$desc` 恒为 `"commit description"`，**任何** `commit <sha> ("<真标题>")` 都会假报 ERROR。
⇒ 为了让「改后 0E」有意义，在 `/tmp/ktree` 里 `git init` 并用 `refs/heads/<12位sha>` 造出
**标题与上游逐字相同**的替身 commit（`git_commit_info` 走 `git log -1 <sha>`，refs 解析即可命中），
标题本身另行用 `git.kernel.org` 逐字核对：

| sha | 上游标题（逐字） | 核对 |
|---|---|---|
| `1facae9bc3c1` | `media: iris: Fix bus_info prefix in VIDIOC_QUERYCAP` | `commit/?id=` 页 `<title>` 命中 |
| `38fc8beaba55` | `media: iris: implement reqbuf ioctl with vb2_queue_setup` | `patch/?id=` 的 `Subject:` 命中 |
| `b530b95de22c` | `media: iris: implement s_fmt, g_fmt and try_fmt ioctls` | `patch/?id=` 的 `Subject:` 命中 |

> 替身的 commit hash 与真 sha 不同（只影响 ERROR 文案里的 id 字样），**标题比较路径与真树等价**。
> 这一步不做的话，「改后 0 errors」无法与本机复现自洽（见本节开头）。

复现命令（判红）：

```sh
cd /tmp/ktree && perl scripts/checkpatch.pl --no-tree --strict \
  /home/xuqianhui/y700-elden/patches/upstream/v4l2-compliance-iris-20261127/0002-v2-fill-default-colorspace.patch
```

### 3.4 改前（v2）原始输出 —— 判红的那几行 + 规则名

```
WARNING: Prefer a maximum 75 chars per line (possible unwrapped commit description?)     <- COMMIT_LOG_LONG_LINE
#12:
A decoder cannot know the stream's colours before it parses a frame, but the

ERROR: Please use git commit description style 'commit <12+ chars of sha1> ("<title line>")' - ie: 'commit f5e82779cf0c ("media: iris: Fix bus_info prefix in VIDIOC_QUERYCAP")'   <- GIT_COMMIT_ID
#27:
  commit 1facae9bc3c1 ("media: iris: Fix bus_info prefix in

WARNING: Do not use whitespace before Cc:                                                <- BAD_SIGN_OFF
#29:
  Cc: stable@vger.kernel.org), which is already in mainline. My tree predates
```

（其后还连带 2 条 email 格式 WARN，均源自同一行 `#29`；末尾另有第二次

```
ERROR: Please use git commit description style … 'commit 3a1265417b4e ("media: iris: implement reqbuf ioctl with vb2_queue_setup")'   <- GIT_COMMIT_ID
#43:
38fc8beaba55 ("media: iris: implement reqbuf ioctl with vb2_queue_setup"), which
```

）

```
total: 2 errors, 4 warnings, 0 checks, 43 lines checked
… /0002-v2-fill-default-colorspace.patch has style problems, please review.
```

- 与 CI（`10490`）明细对齐：CI 报的 ① `WARNING: Do not use whitespace before Cc:` @ 行 29、② `ERROR: … git commit description style`
  在本机**逐字复现**，此外本机多出的第 2 个 `GIT_COMMIT_ID`（`#43` 裸 sha）与 `COMMIT_LOG_LONG_LINE`
  说明「即便只修 CI 点名的两处，仍会再红」——v3 因此三条一起修。

### 3.5 改后（v3）原始输出 —— **0 error**

```
$ cd /tmp/ktree && perl scripts/checkpatch.pl --no-tree --strict \
    …/0003-v3-fill-default-colorspace.patch
total: 0 errors, 0 warnings, 0 checks, 43 lines checked

/home/xuqianhui/y700-elden/patches/upstream/v4l2-compliance-iris-20261127/0003-v3-fill-default-colorspace.patch has no obvious style problems and is ready for submission.
```

非 `--strict` 同口径（也 0）：

```
total: 0 errors, 0 warnings, 43 lines checked
```

原始日志（含改前/改后/非 strict 三段，未加工）：
`logs/checkpatch-v2-v3-20261128.log`（50 行；头部记了 harness、主机、checkpatch sha256）。

## 4. 复跑一行版（父代理/复核者可直接抄）

```sh
# harness（若 /tmp/ktree 已被清掉）
rm -rf /tmp/ktree && mkdir -p /tmp/ktree && \
printf 'VERSION = 7\nPATCHLEVEL = 4\nSUBLEVEL = 0\nEXTRAVERSION = -rc3\nNAME = Baby Opossum Posse\n' > /tmp/ktree/Makefile && \
cp -r /home/xuqianhui/y700-elden/linux/scripts /tmp/ktree/ && cd /tmp/ktree && git init -q . && \
for s in "1facae9bc3c1|media: iris: Fix bus_info prefix in VIDIOC_QUERYCAP" \
         "38fc8beaba55|media: iris: implement reqbuf ioctl with vb2_queue_setup" \
         "b530b95de22c|media: iris: implement s_fmt, g_fmt and try_fmt ioctls"; do \
  git update-ref "refs/heads/${s%%|*}" "$(git commit-tree "$(git mktree < /dev/null)" -m "${s#*|}")"; done && \
perl scripts/checkpatch.pl --no-tree --strict \
  /home/xuqianhui/y700-elden/patches/upstream/v4l2-compliance-iris-20261127/0003-v3-fill-default-colorspace.patch
```

## 5. 发送命令（**未执行真发**；`--dry-run` 已跑通）

沿用 `SENT.md` 的收件人集合与 `--in-reply-to=<v1 cover MID>`：

```sh
cd /home/xuqianhui/y700-elden && git send-email \
  --to=linux-media@vger.kernel.org --cc=linux-arm-msm@vger.kernel.org \
  --cc='Vikash Garodia <vikash.garodia@oss.qualcomm.com>' --cc='Dikshita Agarwal <dikshita.agarwal@oss.qualcomm.com>' \
  --cc='Abhinav Kumar <abhinav.kumar@linux.dev>' --cc="Bryan O'Donoghue <bod@kernel.org>" \
  --cc='Mauro Carvalho Chehab <mchehab@kernel.org>' --cc='Hans Verkuil <hverkuil@kernel.org>' \
  --cc='Stefan Schmidt <stefan.schmidt@linaro.org>' \
  --in-reply-to='<20261127152024.2149804-1-xiaqinghuan@mail.ustc.edu.cn>' \
  patches/upstream/v4l2-compliance-iris-20261127/0003-v3-fill-default-colorspace.patch
```

以上命令**加一个 `--dry-run` 即本次实际跑过的形态**（真发时删掉 `--dry-run`；`sendemail.confirm=always`
会再拦一道）。`--dry-run` 原始输出要点（2026-11-28 10:34 CST，rc=0）：

```
RCPT TO:<stable@vger.kernel.org>              <- 由 Cc: trailer 自动带入（无需 --cc）
From: Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>
To: linux-media@vger.kernel.org
Cc: linux-arm-msm@vger.kernel.org, …, Stefan Schmidt <stefan.schmidt@linaro.org>, stable@vger.kernel.org
Subject: [PATCH v3] media: iris: fill in a default colorspace for decoded formats
Date: Sat, 28 Nov 2026 10:34:21 +0800          <- 由 send-email 重写（patch 内写的是 10:34:06）
Message-ID: <20261128023421.4192096-xiaqinghuan@mail.ustc.edu.cn>
In-Reply-To: <20261127152024.2149804-1-xiaqinghuan@mail.ustc.edu.cn>
References: <20261127152024.2149804-1-xiaqinghuan@mail.ustc.edu.cn>
Result: OK
```

> 解析结论：9 个 Cc（8 收件人 + `stable@vger`）、To = linux-media、`[PATCH v3]` 未被改写、线程正确挂在 v1 cover 下。
> 只在 v3 patch 上跑，**未把 v2 一起发**（避免重复投递）。

## 6. 发后复核判据（父代理收口用）

1. 记下新 MID（`--dry-run` 显示的形态为 `<2026…-xiaqinghuan@mail.ustc.edu.cn>`，真发时以 STDOUT 为准；
   v2 的 `log/` 目录递送日志见 `logs/`，`Result: 250` 才算成功）。
2. `curl -sS --noproxy '*' 'https://lore.kernel.org/linux-media/<新MID>/t.mbox.gz'` → HTTP 200 gzip；
   Subject 逐字 `[PATCH v3] media: iris: fill in a default colorspace for decoded formats`；
   线程挂在 v1 cover 下、封数 6 → 7。
3. 等 media CI 新一轮：期望**不再**出现 `ERROR: Fails one or more mandatory checkpatch tests`。
4. 回填 `SENT.md`（**本文件与 0003 是新增；SENT.md 由父代理收口时追加，本 lane 未动**）。

## 7. 残留风险 / 待确认

1. **CI 的 checkpatch 口径未知**：media CI（`patchwork@media-ci.org`）具体参数未公开。本机用 `--no-tree --strict`
   （最严）与 `--no-tree` 两档都 0E/0W；若 CI 另有 `media-patchstyle` 私有规则（标题前缀、`Fixes:` 格式正则），
   本机无法预演 —— **待确认（下一轮 CI 结果即判据）**。
2. **`commit 1facae9bc3c1 ("…")` 正好 75 字符**：合规（规则是 `>75`），但没有任何余量；若后续有人加缩进会立刻变 WARN。
3. **`Link:` 指向 `git.kernel.org/…/torvalds/linux.git/commit/?id=38fc8beaba55`**：该 commit 在 torvalds/master 上
   可达（本次 `patch/?id=` 与 `commit/?id=` 均实测 200），若日后改写为 media-staging 分支链接需重核。
4. **未上机/未重测**：v3 代码与 v2 逐字节相同，实测数据（v4l2-compliance 47/48）仍属 v2 那次上机；
   报文已如实写「neither rebased nor retested for v3」，不主张新测量。
5. 本机 `linux/scripts/checkpatch.pl` sha256（日志头已记）用于事后对齐版本：若 CI 用的 checkpatch 比本机新，
   `GIT_COMMIT_ID` / `BAD_SIGN_OFF` 规则文本可能微调，但「折行 + 行首 `Cc:`」在所有版本都是问题。

---

**v3 sha256**（写盘后未再改动，116 行）：

```
713c41d2cfe81ff7668ce22f34eccf581cd1a2a5b701af35e33a64c319eb6e99  0003-v3-fill-default-colorspace.patch
```
