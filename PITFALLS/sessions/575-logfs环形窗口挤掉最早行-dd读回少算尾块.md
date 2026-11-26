# 「六、脚本/工具」抽出：#575（原 `06-脚本工具.md` 内条目）

## #575：logfs 的 8 KiB 环形窗口会**挤掉最早的行**；`dd bs=1M count=N` 读回镜像会少算尾块 ⇒ 两个假结论

- 场景（2026-11-09，p61 落地一发）：
  1. 想用「某行在不在 logfs 里」判「补丁有没有执行」——`[K] esp blk=`（函数第一行）不见、`[K] esp fs=`（后几行）在。
     这不是补丁失效，是 `SBLOG01 tag=preeb len=8192` **只留最后 8 KiB**，早的行被挤掉。
     ⇒ 存在性判据只对**窗口内靠后**的行有效；要靠前的行，就把标记挪到**函数入口**或缩短前面的输出。
  2. 读回校验 `dd if=…/boot_a bs=1M count=64 | head -c 67194880` —— `64 MiB = 67 108 864 < 67 194 880`
     ⇒ 尾块缺失、sha 不等于主机件，差点判「刷进去的不是这个镜像」。
     正确做法：`bs=4096 count=$(( (N+4095)/4096 ))` + `head -c N`（或 `bs=1 count=` 太慢）。
  3. 附带：`grep -ac "[K] "` 在二进制里会因 `[K]` 被当**字符类**而命中任意「K+空格」；查二进制串用
     `grep -aF` 或 `python -c 'open(...,"rb").read().find(b"...")'`。

## 索引回填（编号 228）：574 Mu 树浅克隆 + 活线改动只在工作区 ⇒ 整文件快照

**#228** Mu 树单提交浅克隆（`.git/shallow`）+ loader 改动只在工作区 ⇒ R55–R65 各代 `Loader-*.efi` 曾整体不可再生。修法 = 整文件快照 `patches/uefi/20261109R65-loader-snapshot/`（基线 `6b6ac42a` + 放回路径 + `stuart_build` 命令）；别做累计 patch（与 R54/R61/R62 重叠会冲突），也别指望逐字节复现（`__DATE__/__TIME__`，#510 同族）。

## 索引回填（编号 229）：575 logfs 环形窗口挤掉最早行 + dd 管道尾块丢失

**#229** 8 KiB 环形窗口会挤掉最早的行 ⇒ 存在性判据只对窗口内靠后的行有效，标记放函数入口。`dd bs=1M count=N | head -c <len>` 读回会少算尾块（64 MiB < 67 194 880 B）导致假「刷进去的不是这个件」；`grep "[K] "` 在二进制里是字符类。

## 索引回填（编号 235）：581 脏基线不是基线

**#235** `reset_tree()` 回滚失败残留越积越多，`manifest.worktree_after` 列 29 个 `M` 看着像「本来就该脏」，某些补丁此时必然 apply 失败。可复算做法 = 逐子模块 `git checkout -- .` 归零后按配方顺序重放（2026-11-09 实测 p62 配方 80/80 全部应用成功）。重建前先归零。原文：reports/uefi-p62-r63-fastboot-trial-20261109.md

## 索引回填（编号 236）：582 资产清理打断世代可重放

**#236** `scripts/uefi-repack-v2aligned.py` 默认 `--base` 指向 11-03 归档里的 boot_b-live.img，该目录已被后续清理删掉 ⇒ `--gen p6x` repack 段 `FileNotFoundError`。删档前先 `grep -rn "<路径>" scripts/ out/`；临时解 = 显式 `--base <同基座 boot.img>`（`only-kernel-differs` 断言会把关）。原文：reports/uefi-p62-r63-fastboot-trial-20261109.md

## 索引回填（编号 237）：583 fastboot getvar 在设备离开 fastboot 时阻塞到 timeout

**#237** 采样器每 3 s 探 ABL 存活，交棒后 90 采样串行能挂十几分钟（看着像脚本死了）。改法 = 先 `fastboot devices | grep -qx $SER` 再发 getvar，否则记 `alive=gone`。原文：reports/uefi-p62-r63-fastboot-trial-20261109.md

## 索引回填（编号 238）：584 fastboot | grep -q 的 SIGPIPE 打断 bulk 通道

**#238** `fastboot … | grep -q`（或 `| head`/`| tail`）把 SIGPIPE 送回 fastboot 客户端，打断设备侧 bulk 通道 ⇒ 之后 `fastboot devices` 空。纪律：fastboot 输出重定向到文件再分析，别接会早退的管道。原文：reports/uefi-p62-r63-fastboot-trial-20261109.md

## 索引回填（编号 239）：585 ssh+fastboot 复合命令挂住、timeout 失效：挂点在开头裸 ssh

**#239** 复合命令整条挂住时先怀疑开头的裸 `ssh`（无 ServerAliveInterval/无 ConnectTimeout），不是 fastboot；给 ssh 段套 `timeout -k` 与 `-o ConnectTimeout=` 后即可被截断。原文：reports/tooling-hang-investigation-20261109.md

## 索引回填（编号 241）：587 dump 先断言字节数；首扇区 FAT12 不是「读到别的分区」的证据

**#241** `ssh … 'dd if=…' > file` 会静默短读（实测少尾 32 KiB，恰好丢光唯一记录区）；本机 logfs 本身就是 vfat，偏移 3 也是 `MSDOS5.0` ⇒ 不能拿「首扇区 FAT12」当「读到了别的分区」的判据（当时据此写进坑里，是错的）。纪律：`dd` 后断言 `stat -c%s` = 期望容量（logfs = 8 388 608）；取件一律 `/dev/disk/by-partlabel/logfs`；分析前 `cmp` `0x7FC000` 的 `SBLOG01` 头块。原文：reports/beacon-recheck-20261110.md

## 索引回填（编号 244）：两件「静默挂死/静默消失」工具坑（挂 50 min、零输出）

**#244** 与 #583（getvar 阻塞）/#585（裸 ssh 挂住）同族：长跑采样器里的阻塞调用必须逐个套 `timeout -k`，管道早退会静默吞掉输出；两实例完整时间线见原文：reports/uefi-p63-p66-beacon-20261109.md

## 索引回填（编号 247）：593 计时判据只能作正控，不能作反证

**#247** 给 PrePi 加 25 s 停留（R70）：`fastboot boot` 形态 54.5→128.7 s（+74.3≈3×25，仪器成立），flashed 形态 +0 s。当时推断「+0 ⇒ 没跑到 PrePi」是错的——flashed 是**硬复位**，复位把停留整段剪断，与「从没跑过」不可分。正解：先测同形态无停留基线（`_b` 回暖 ≈18 s），差值才是失败发寿命（≈10 s）；判「跑到哪」用复位后仍存的通道。原文：reports/uefi-p69-flashed-and-vbmeta-20261110.md
