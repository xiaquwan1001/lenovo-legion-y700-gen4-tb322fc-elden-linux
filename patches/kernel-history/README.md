# kernel-history — 内核 elden 增量补丁集（异地留档）

本地内核树 `~/y700-elden/linux` 是 **shallow clone**（`.git/shallow` 嫁接于
`ba28ec16f01f59ba8f5099e8af9e95b061fc5c78`），GitLab 拒绝 shallow push。
为做到「即使本机内核 .git 全丢也能复原」，这里按分支导出全部 elden 增量提交
（`git format-patch <base>..<branch>`）。

- base = `ba28ec16f01f59ba8f5099e8af9e95b061fc5c78`（GEEKiDoS `v7.2-elden`）
- 每个子目录 = 一支本地分支的增量，`git am` 可原样重放
- 真实可 clone 的异地镜像：https://git.ustc.edu.cn/xqh/y700-elden-kernel
  （分支 `main` = 合成根 + 9 个增量，见 `archive/2026-10-04-git-backfill/VERSION-MAP.txt`）

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

内核仓 tag 已打：`vk40 vk41 vk42 vk44 vk45 vk46 vk47 vk48 vk54`。
**未打 tag 的号及其原因**（不伪造 tag，缺源就留白；证据见
`archive/topics/VK-LEDGER-AUDIT-2026-10-06.md`）：

| vk | 内核源 | 说明 |
|---|---|---|
| vk43 | 无提交，树 = vk42 `eb432f18a` | 本号改动是 **rootfs tplg overlay**（MI2S SD0→SD1，出声），非内核源；overlay 未留档 ⇒ **UNREPRODUCIBLE** |
| vk47clean | `bd114ca33` 重建（`LOCALVERSION=-vk47clean`） | 与 vk47 同源，仅去 `-dirty` + 本地版本串；当前在机内核 |
| vk49 | 无提交，树 = vk48 `5a70ade46` | 本号改动是相机模块打包 + `.config`（非内核源）；KV = `g5a70ade46a88`，与 vk48 同串 |
| vk50 | 无提交，树 = vk48 `5a70ade46` + `LOCALVERSION=-vk50` | 相机出流会话；1 513 模块按 vk50 KV 重建 |
| vk53 | 提交 `2b5badef0`（分支 `elden/vk53-hw`） | NFC ST21NFCA + CDSP + `TYPEC_MUX_FSA4480=y`；**该号正在独立审查，暂不 tag** |
| vk55 | 无内核改动 | 用户态会话 overhaul（主库 commit `ee72844`/`03b4777`） |
| vk60/vk61 | 无内核改动，内核 = vk47clean `bd114ca33` | 只换 initramfs/`init`（`out/boot-elden-vk60.img`/`vk61.img`） |

> 纪律：**只给「源=镜像」可证的号打 tag**。vk43/vk49/vk50 的镜像若仍存在
> （`out/boot_b-vk49.img`、`out/boot-elden-vk50.img`），请连其 manifest
> （`kernel_git_head`/`kernel_uts`）一起引用，不要用 tag 反推。
