# 全仓数据完整性校验报告（lane V，2026-11-05）

## §0 一句话结论
**0 件真损坏、0 件瞬时读错；1 红**（`build/m3v2-7.3rc7` 的 git fsck 报无效 HEAD reflog 条目，重试稳定，疑为浅克隆 reflog 残留，pack 完整性不受影响）；**黄 85 项**（63 份 SHA256SUMS 中 17 份引用了已缺失文件、64 件镜像无基线、4 个 0 字节文件，其中 2 个为 `.gitkeep`/空日志属预期）。

## §1 汇总表

| 项 | 件数 | 失败数 | 重试后恢复 | 真损坏 |
|---|---|---|---|---|
| git 仓库（root、geekidos-linux、m3v2-7.3rc7、base-7.2；daily 非独立仓库 SKIP） | 4 仓 ×4 命令 | 1（m3v2-7.3rc7 fsck rc=2） | 0 | 0（对象库 verify-pack OK） |
| 产物镜像 out/*.img vs manifest `image_sha256=` | 129（65 有基线全符 / 64 无基线） | 0 | 0 | 0 |
| backup/build-bundles + git-repair-20261105 的 .zst/.tar.zst（zstd -t） | 2 | 0 | 0 | 0 |
| SHA256SUMS（backup + reports/artifacts，sha256sum -c） | 63 份 | 17 份含缺失文件引用 | 0 | **0（无一条哈希不匹配）** |
| 文本层 patches/versions/scripts 双跑 sha256 | 822 文件 ×2 | 0（两次完全一致） | 0 | 0 |
| 0 字节文件 | 4 | 4（2 个 `.gitkeep`、1 个空 check 日志、1 个 `.lock`，均预期内） | — | 0 |
| `.patch` 文件格式异常（含 diff --git / `--- a/` / mbox 头任一即正常） | 全部 git 跟踪 .patch | 0（初筛 6 个疑点经 `file`+`head` 复核全为合法裸 diff / mbox，误报） | — | 0 |

已知历史损坏件复核：`out/boot-elden-m3v5-daily.img` 实测 sha256 = manifest 记录 `4d7e2ea9…e73`，**一致**（此前损坏事件应已重建修复）。

## §2 逐条异常

1. **[红] build/m3v2-7.3rc7 — git fsck 失败（重试 1 次仍失败）**
   - 期望：`git fsck --full --no-dangling` 退出 0；实测 rc=2，两次报 `error: HEAD：无效的引用日志条目 98c24fc886658f93149bba6baab1fa6fc5d1f052`（第二次运行另现 `1f368fa2…`，均为 reflog 引用）。
   - 重试：重跑一次，同样报错 → 按矩阵规则判红。
   - 定性：**疑似浅克隆 reflog 残留**（仓库有 `.git/shallow`，reflog 指向已被截断的父提交），非对象库损坏——同仓 `git verify-pack -v .git/objects/pack/*.idx` 通过、`git rev-parse HEAD` 正常（3d3b6da9bf）、HEAD@{0..2} 可读。属可清理性元数据问题（本轮只读，不处理）。
2. **[黄] 17 份 SHA256SUMS 引用缺失文件**（全部为 "No such file or directory"，**无一条真哈希不匹配**）：
   - `backup/stock-259/SHA256SUMS`（如 abl_a.img/abl_b.img 缺）
   - `backup/HA2EXB0E-16+512/pre-unlock/SHA256SUMS`（by-name.txt、dumpsys-services.txt 等）
   - `reports/artifacts/uefi-dxe{,2..11}-20261104/SHA256SUMS`（SM8750_EFI.fd、kernel.bin — 共 12 份，疑为目录只存了部分产物）
   - `reports/artifacts/uefi-vis-r1-20261031/`、`uefi-vis-control-20261031/`、`uefi-onboard-20261030/`、`uefi-rb-20261031/a2-replay/`（各缺 1–2 件）
   - 定性：清单与目录不同步（缺失），非位翻转。
3. **[黄] 64 件 out/*.img 无对应 manifest**（多为 uefi-20261101~04 系列、posctrl、linuxstop/r20-stop 调试件、dtbo-dummy 等），无法比对基线，仅记录实测 sha256 于 TSV。
4. **[黄] 0 字节文件 4 个**：`patches/out-of-tree-dm-default-key/{patches,tests}/.gitkeep`、`patches/upstream/m3-dwc3-20261104/artifacts/dt_binding_check.log`、`versions/vk-registry.tsv.lock`。

## §3 未覆盖范围
- **在机侧完全未校验**：boot_b 分区内容、GPT、设备上镜像（本轮不上机）。
- `build/daily` 不是独立 git 仓库（SKIP，其产物镜像已按 out/*.img 流程覆盖）。
- SHA256SUMS 中「缺失文件」的历史去向未追溯；root 仓 fsck 用默认 `--no-dangling`，未审 dangling 对象。
- 各仓 `git count-objects -v`、`verify-pack` 仅记录退出码，数值明细见 TSV 同行（均 OK）。

## §4 复核命令
```bash
cd /home/xuqianhui/y700-elden
# git（4 仓，m3v2-7.3rc7 预期报 reflog 无效条目）
for r in . geekidos-linux build/m3v2-7.3rc7 build/base-7.2; do (cd $r && git fsck --full --no-dangling; git count-objects -v; git verify-pack -v .git/objects/pack/*.idx | tail -2); done
# 镜像抽查（全量见 TSV）
grep -m1 '^image_sha256=' out/boot-elden-m3v5-daily.manifest; sha256sum out/boot-elden-m3v5-daily.img
# 备份件
zstd -t backup/build-bundles/*.tar.zst backup/git-repair-20261105/*.zst && echo ZST-OK
# SUMS 缺失清单
find backup reports/artifacts -name SHA256SUMS | while read -r s; do d=$(dirname "$s"); (cd "$d" && sha256sum -c SHA256SUMS 2>&1 | grep -c 'No such file' | xargs -I{} echo "$s missing={}") done | grep -v 'missing=0'
# 文本层双跑
git ls-files -z patches versions scripts | xargs -0 sha256sum > /tmp/a; git ls-files -z patches versions scripts | xargs -0 sha256sum > /tmp/b; diff /tmp/a /tmp/b && echo TEXT-STABLE
```

机器账：`reports/integrity-audit-20261105.tsv`（原始逐条 401 行含误报初筛；§2 已剔除格式误报）。
