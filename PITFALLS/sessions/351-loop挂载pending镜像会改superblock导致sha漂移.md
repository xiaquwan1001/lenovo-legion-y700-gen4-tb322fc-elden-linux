# #718 把 pending 镜像 loop 挂载一次 ⇒ sha 与 MANIFEST 漂移（数据块没变，变的全是 superblock/inode metadata）

> 2026-11-25 清理轮实测。`out/android-slim-v3-20261119/new/system_a.img`（`versions/out-artifacts.tsv:11`
> 标 **pending / 禁删** 的唯一 final 件之一）实测 sha = `0b400b93…`，而它自己的 `MANIFEST.md` /
> `SHA256SUMS` 记的是 `db74cd06…`；`~/hw-stability/evidence/inbox/20261119-y700-elden-super-bitflip/hashes.txt`
> 第 3 行同样记 `db74cd06…` ⇒ 三方账面一致、只有实物变了。

## 判据：先分清「内容漂移」还是「metadata 漂移」

```sh
cmp -l /tmp/rbex/system_a.img out/android-slim-v3-20261119/new/system_a.img | wc -l     # 13880（4.1 GB 里）
cmp -l … | awk 'NR==1{print "first="$1} END{print "last="$1}'                            # 1037 … 3674211024
dumpe2fs -h <img> | grep -E 'Filesystem UUID|Filesystem created|Last mount time'
#   两边 UUID/created 相同（同一个 fs），但实物那件 Last mount time = 2026-11-19 21:18:35，干净件 = n/a
```

- 差异**全部落在 ext4 metadata 区**（superblock 偏移 1024 起 + inode/group 表），`UUID` 与
  `Filesystem created` 两边逐字相同 ⇒ **不是重新 `mke2fs -d`，也不是页缓存位翻转，是 rw 挂载一次**内核回写的
  mount time / mount count / state / journal。
- 实物文件 `mtime = 11-19 21:18`、属主 `xuqianhui`（同目录其余件为 `root:root` 20:27）⇒ 时间点自洽。

## 危害

`pending` 件的判据就是「sha 与 MANIFEST 一致 + 上机首启通过」。挂载一次即让两边永久对不上，
下一轮核对会把它报成「SSOT 漂移 / 疑似损坏」，而实际上**数据块完全没变**（可 flash 的
`super_min_v3.img` 一直 `51eae107…` 未动）。真实事故成本 = 白查一轮、甚至误删唯一好件。

## 处置（本轮已做）

- 用**与 MANIFEST 逐字节相同**的干净件还原：`cp --reflink=auto /tmp/rbex/system_a.img out/…/new/system_a.img`，
   `scripts/odirect-sha.py` 复核 = `db74cd06…` ⇒ 账面恢复一致，`/tmp/rbex` 才可删。
- 纪律：**待上机/待验收的 pending 镜像一律只读处理**——要查内容用 `debugfs -R`（只读）或
   `mount -o ro,loop`，**绝不 rw 挂载**；确需修改就先在工作副本上做，再重算 MANIFEST/SHA256SUMS。
- 判据前移：`check-doctor` §29（候选件 sha 账目）之外，`out-artifacts.tsv` 标 pending 的目录也应跑一次
   O_DIRECT sha 对账（本轮手工跑过，drift 只此一件）。
