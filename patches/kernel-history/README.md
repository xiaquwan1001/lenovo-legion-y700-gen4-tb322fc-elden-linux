# kernel-history — 内核 elden 增量补丁集（异地留档）

本地内核树 `~/y700-elden/geekidos-linux` 是 **shallow clone**（`.git/shallow` 嫁接于
`ba28ec16f01f59ba8f5099e8af9e95b061fc5c78`），GitLab 拒绝 shallow push。
为做到「即使本机内核 .git 全丢也能复原」，这里按分支导出全部 elden 增量提交
（`git format-patch <base>..<branch>`）。

- base = `ba28ec16f01f59ba8f5099e8af9e95b061fc5c78`（GEEKiDoS `v7.2-elden`）
- 每个子目录 = 一支本地分支的增量，`git am` 可原样重放
- 真实可 clone 的异地镜像：https://git.ustc.edu.cn/xqh/y700-elden-kernel
  （分支 `main` = 合成根 + 9 个增量，见 `archive/2026-10-04-git-backfill/VERSION-MAP.txt`）

## 覆盖清单（2026-10-17 全量补齐）

`REFS.tsv` = 权威对照表（分支 → tip sha / tree sha / 增量数 / 补丁目录 / base）。
2026-10-17 已把补丁集从 6 支扩到 **全部 17 支本地 `elden-archive/*` 分支**（2.5 MB），
并逐支复验：在 base 上 `git am` 后 `rev-parse HEAD^{tree}` 与分支 tip tree **逐支相等（17/17 TREE-OK）**。

`elden-archive/archive/gitlab-mirror-vk48`（= GitLab `main`，tip `fe54fcfff`）**不需要**补丁集：
它是合成根镜像，可直接 clone；为它导出的 0001 补丁是 1.7 GB 的全树 diff，已弃用。

## ⚠️ bundle 不能当备份用（2026-10-17 实测）

`backup/kernel-git-repair-2026-10-0{8,10}/elden-all-refs-*.bundle` 在 `git bundle verify` 下报
「记录一个完整历史」，但**实测不可复原**：

```bash
git clone --bare backup/kernel-git-repair-2026-10-10/elden-all-refs-pre-boundary.bundle /tmp/x
# error: Could not read 32c6462381ca200a01d8eca67645a6f1487131b5
# fatal: Failed to traverse parents of commit ba28ec16f…（did not send all necessary objects）
```

根因：本地仓是 shallow（嫁接于 `ba28ec16f`），`git bundle create` **不写 `# shallow` 头**，
于是包里只有嫁接点以上的对象，而嫁接点 commit 仍带着指向 `32c64623` 的 parent 指针 ⇒ 任何
clone/fetch 都会因缺该对象而失败。`bundle verify` 只校验 prerequisites，**验不出这个**。

结论：**异地留档只能靠本目录的补丁集**（+ GitLab 上可 clone 的 `main`）。要让
`elden-archive/*` 真正进 GitLab 需要先 `git fetch --unshallow origin`（GEEKiDoS/linux 全史
≈4–5 GB，客户端 shallow 时服务器直接拒 push：`shallow update not allowed`）——未做，需拍板。

## 复原步骤

```bash
# 方式 A：从补丁集（最鲁棒，不依赖本机 .git）
git clone https://github.com/GEEKiDoS/linux.git elden-linux
cd elden-linux && git checkout v7.2-elden          # 确认到 base
git am <此目录>/elden_vk42-audio-thermal/*.patch   # 得到 vk48 线
# 可选：git branch elden/vp... 逐支重放

# 方式 B：直接从学校 GitLab 镜像
git clone git@git.ustc.edu.cn:xqh/y700-elden-kernel.git
```

> 同样思想见顶层仓回填 `archive/2026-10-04-git-backfill/`（顶层仓 vk1–vk40 的
> 版本叙事回填，无法复原的中间态诚实留白）。

## vk40–vk54 → commit 对照（2026-10-06 账目审查回填）

内核仓 tag 已打：`vk40 vk41 vk42 vk44 vk45 vk46 vk47 vk48 vk53 vk54`。
**版本→内核源对照**（不伪造 tag，缺源就留白；证据见
`archive/topics/VK-LEDGER-AUDIT-2026-10-06.md`）：

| vk | 内核源 | 说明 |
|---|---|---|
| vk43 | 无提交，树 = vk42 `eb432f18a` | 本号改动是 **rootfs tplg overlay**（MI2S SD0→SD1，出声），非内核源；overlay 未留档 ⇒ **UNREPRODUCIBLE** |
| vk47clean | `bd114ca33` 重建（`LOCALVERSION=-vk47clean`） | 与 vk47 同源，仅去 `-dirty` + 本地版本串；当前在机内核 |
| vk49 | 无提交，树 = vk48 `5a70ade46` | 本号改动是相机模块打包 + `.config`（非内核源）；KV = `g5a70ade46a88`，与 vk48 同串 |
| vk50 | 无提交，树 = vk48 `5a70ade46` + `LOCALVERSION=-vk50` | 相机出流会话；1 513 模块按 vk50 KV 重建 |
| vk53 | tag `vk53`@`2b5badef0`（分支 `elden/vk53-hw`） | NFC ST21NFCA + CDSP + `TYPEC_MUX_FSA4480=y`；**已补 tag**（2026-10-06 定案 `#108`：本机无 NFC 硬件 ⇒ G1-10 取消；实机失败真因 = 使能 `&i2c0`；G1-11 CDSP 经 `vkD2-cdsponly` 通过）。源=镜像可证（UTS=`vk53-g2b5badef00fb`，`clean`） |
| vk55 | 无内核改动 | 用户态会话 overhaul（主库 commit `ee72844`/`03b4777`） |
| vk60/vk61 | 无内核改动，内核 = vk47clean `bd114ca33` | 只换 initramfs/`init`（`out/boot-elden-vk60.img`/`vk61.img`） |

> 纪律：**只给「源=镜像」可证的号打 tag**。vk43/vk49/vk50 的镜像若仍存在
> （`out/boot_b-vk49.img`、`out/boot-elden-vk50.img`），请连其 manifest
> （`kernel_git_head`/`kernel_uts`）一起引用，不要用 tag 反推。
