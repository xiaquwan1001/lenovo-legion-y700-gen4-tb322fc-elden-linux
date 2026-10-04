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
