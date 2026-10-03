# Google Drive 大文件 ZIP64：只下载特定条目的 Range 提取法

场景：Google Drive 上的固件 zip 6.63 GiB（ZIP64），直连下载只有 ~330 KB/s 且易断（SSL EOF / 下载中断产生"大小占位 + 内容全零空洞"的坏文件）。实际只需要包内 1-2 个文件（如 vendor_boot.img 压缩后 7.6 MB）——**不必下载整个包**。

## 1. 下载前先拿 confirm token（模拟 gdown）
大文件确认页（`Virus scan warning`）需要 uuid+confirm 才能下载：
```python
# urllib + CookieJar 访问 uc?export=download&id=<ID>，正则提取:
#   name="uuid" value="..."   name="confirm" value="..."   （confirm 无则用 "t"）
# 下载 URL = https://drive.usercontent.google.com/download?id=<ID>&export=download&confirm=<c>&uuid=<u>
```

## 2. 解析 ZIP64 central directory（服务器端，Range 只拉末尾）
- Range 请求末尾 ~400 KB → 找标准 EOCD（magic `PK\x05\x06`）
- **ZIP64 判别**：EOCD 里 `cd_offset` 字段 = `0xFFFFFFFF` → 在 EOCD 前 20 字节找 ZIP64 EOCD locator（`PK\x06\x07`）→ locator+8 处 8 字节 = ZIP64 EOCD 偏移 → 拉该区 100 B → 字段：entries@32(8B) cd_size@40(8B) **cd_offset@48(8B)**
- 拉 CD 区间（cd_offset..+cd_size，几十 KB）→ 解析条目（`PK\x01\x02` 头：crc@16 csize@20 usize@24 fname_len@28 extra_len@30 lho32@42）

## 3. ZIP64 local-header-offset 陷阱（容易算错）
标准 CD 的 `local header offset`（@42）若是 `0xFFFFFFFF`，真实值在 **extra 字段**（header_id 0x0001）里。**extra 只包含值为 0xFFFFFFFF 的字段，按 usize→csize→lho 顺序排列**：
```python
epos = 4
for std in (usize, csize, lho32):
    if std == 0xFFFFFFFF:
        v = struct.unpack_from('<Q', extra, epos)[0]; epos += 8
    else:
        v = std
    if std == lho32:
        lho = v
```
（只有 lho 是 0xFFFFFFFF 时，lho 就是 extra 里第一个 8 字节——不要固定偏移 20。）

## 4. Range 拉条目 + inflate + CRC 验证
- Range: `bytes=<lho>-(<lho>+30+4096+csize-1)`（本地头 30 B + fname/extra 预留 + 压缩数据）
- 解析本地头（`PK\x03\x04`：csize@18 fname_len@26 extra_len@28）→ 压缩数据 = 30+fname_len+extra_len 起 csize 字节
- `zlib.decompress(comp, -15)`（deflate）→ 用 CD 里的 CRC 和 usize 验证
- 失败重试：curl `--retry 8 --retry-all-errors` 比 python urllib 稳（urllib 直连 Google Drive 常见 `SSLEOFError`）

## 5. 已下载文件的损坏诊断（区分"坏文件"和"占位空洞"）
下载中断且下载器预分配时：文件**大小完全正确**但内容损坏。快速诊断：
- 开头 `PK\x03\x04` 正常 + **末尾 16 B 全零 + 末尾段无 EOCD（rfind `PK\x05\x06` = -1）** → 尾部是空洞，下载在 ~47 MB 处中断
- 7z 报 `Physical Size = 46.8 MB / Tail Size = 7 GB` 或 python zipfile `BadZipFile: File is not a zip file` → 同一症状
- 修复：删掉重下（aria2/Motrix `-c` 断点续传），或改用本文件的 Range 提取法（服务器端文件完好时）

## 工具痕迹
- 系统装了 Motrix Next（aria2 内核 GUI）：`motrix-next-engine` 进程、`.aria2` 控制文件在下载目录；`pgrep -af aria2` 可见
- 环境变量配了 `http://127.0.0.1:7890` 代理但 clash 经常没开——下载慢时先测 `curl -x http://127.0.0.1:7890 -sI https://drive.google.com`，可用则 aria2 `--all-proxy` 加速
