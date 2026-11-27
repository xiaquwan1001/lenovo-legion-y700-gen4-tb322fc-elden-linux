# SENT —— coresight MODULE_DEVICE_TABLE v1（2026-11-27T11:31Z / 19:31 CST）

- 发件人：Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>（USTC smtp 通道）
- 收件人：`TO` suzuki.poulose@arm.com；`Cc` mike.leach@arm.com, james.clark@linaro.org,
  leo.yan@arm.com, alexander.shishkin@linux.intel.com, coresight@lists.linaro.org,
  linux-arm-kernel@lists.infradead.org, linux-kernel@vger.kernel.org
- 日志：`logs/sent-20261127-193137.txt`

| # | Subject | Message-ID | Result |
|---|---|---|---|
| 0/2 | [PATCH 0/2] coresight: add missing MODULE_DEVICE_TABLE() for CTCU and TPDA | `<20261127113137.931578-1-xiaqinghuan@mail.ustc.edu.cn>` | 250 |
| 1/2 | coresight: ctcu: add missing MODULE_DEVICE_TABLE() | `<20261127113137.931578-2-…>` | 250 |
| 2/2 | coresight: tpda: add missing MODULE_DEVICE_TABLE() | `<20261127113137.931578-3-…>` | 250 |

## lore 复核（2026-11-27T12:30Z 实测回填 —— **归档实证**）

**结论**：cover + 1/2 + 2/2 **三封全部进 lore 归档**，Subject **逐字未改写**，三封成串（两封 `In-Reply-To`/`References` → cover），
patchwork **已摄取，state = new**；两封均**未进** linux-next / torvalds（v7.4-rc4 现查）。**截至 12:30Z 无任何回复**。

### 可用端点（关键：UA 决定命运）

| 端点 | HTTP | 特征 |
|---|---|---|
| `GET /all/<cover-MID>/t.mbox.gz`（**默认 curl UA**） | **200** | `application/gzip` 6951 B → 解压 19534 B mbox，**3 封** ✔ |
| 同上换成浏览器 UA | 200 | Anubis 挑战页（`<title>Making sure you're not a bot!`，7746 B） |
| `GET /all/<MID>/`·`/all/<MID>/raw`·`/all/<MID>/t/` | **403** | `nginx` 裸 403，146 B |
| `GET /r/<MID>` | 302 → `/all/...` | 浏览器 UA 下 |
| `GET /all/?q=<MID 片段>`·`/linux-arm-kernel/?q=...` | 200 | **Anubis 挑战页**（非命中/未命中证据） |
| `GET /all/<伪造 MID>/t.mbox.gz` | **404** | 用于标定：403 不是「不存在」信号，404 才是 ✔ |
| `GET /linux-arm-kernel/<cover-MID>/t.mbox.gz` | 200 | `application/gzip` 6932 B（本系列主列表命中） |
| `GET /lkml/<cover-MID>/t.mbox.gz`（`/linux-kernel/` 302→`lkml`） | 200 | 6951 B |
| `GET /coresight/<MID>/t.mbox.gz` | 404 | lore 无该列表路径（不可据此判未投） |

证据串（实测）：
```
$ curl -sS -o ctc.mbox.gz -w '%{http_code} %{size_download} %{content_type}\n' \
    https://lore.kernel.org/all/20261127113137.931578-1-xiaqinghuan@mail.ustc.edu.cn/t.mbox.gz
200 6951 application/gzip
$ gunzip -c ctc.mbox.gz | grep -c '^From mboxrd'   -> 3
Subject: [PATCH 0/2] coresight: add missing MODULE_DEVICE_TABLE() for CTCU and TPDA
  Message-ID: <20261127113137.931578-1-...>  Date: Fri, 27 Nov 2026 19:31:35 +0800  List-Id: <linux-kernel.vger.kernel.org>
Subject: [PATCH 1/2] coresight: ctcu: add missing MODULE_DEVICE_TABLE()
  Message-ID: <...-2->  Date: 19:31:36  In-Reply-To/References: <...-1->
Subject: [PATCH 2/2] coresight: tpda: add missing MODULE_DEVICE_TABLE()
  Message-ID: <...-3->  Date: 19:31:37  In-Reply-To/References: <...-1->
$ curl -sS -o /dev/null -w '%{http_code}\n' https://lore.kernel.org/all/20260101000000.999999-1-nobody@example.invalid/t.mbox.gz
404            # 伪造 MID 的标定结果 —— 上面的 200 是真的命中
```

### patchwork（**已摄取**，API 可用；注意 `?msgid=` 不是有效过滤，见报告 §3）

| 对象 | id | state | 链接 |
|---|---|---|---|
| series（`linux-arm-kernel`, project 62） | **1224350** | `received_all: true`, v1, total 2 | <https://patchwork.kernel.org/series/1224350/> |
| cover 0/2 | 14177379 | cover（API 1.2 不记 state） | <https://patchwork.kernel.org/project/linux-arm-kernel/cover/20261127113137.931578-1-xiaqinghuan@mail.ustc.edu.cn/> |
| 1/2 ctcu | **15029441** | **new** | <https://patchwork.kernel.org/project/linux-arm-kernel/patch/20261127113137.931578-2-xiaqinghuan@mail.ustc.edu.cn/> |
| 2/2 tpda | **15029442** | **new** | <https://patchwork.kernel.org/project/linux-arm-kernel/patch/20261127113137.931578-3-xiaqinghuan@mail.ustc.edu.cn/> |

### 进树状态（**未进**，2026-11-27T12:35Z 查 cgit `plain`）

- `drivers/hwtracing/coresight/coresight-ctcu-core.c`（torvalds **与** linux-next 均 `v7.4-rc4`）：`ctcu_match[]` 在 294 行，**无 `MODULE_DEVICE_TABLE`**。
- `drivers/hwtracing/coresight/coresight-tpda.c`：`tpda_ids[]` 在 618 行，**无 `MODULE_DEVICE_TABLE`**；全文 `grep -c MODULE_DEVICE_TABLE` = 0。
  （另注：本系列 1/2 改的就是 `coresight-ctcu-core.c`，不是 `coresight-ctcu.c`，与上游现名一致 ✔）

> 复核脚本化提示：`curl -sS https://lore.kernel.org/all/<MID>/t.mbox.gz`（**别带浏览器 UA/header**，否则吃 Anubis 挑战页）；
> 判命中用 `gzip` magic + `grep -c '^From mboxrd'`，别用 HTTP 码单判。完整逐项证据 = `reports/upstream-sent-backfill-20261127.md`。
