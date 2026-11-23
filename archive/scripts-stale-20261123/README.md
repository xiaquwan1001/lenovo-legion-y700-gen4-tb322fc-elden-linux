# archive/scripts-stale-20261123/ — STALE 脚本归档（2026-11-23，D5 批 4）

**只移动、不删除**：三个文件的字节与归档前一致（sha256 记在 `MANIFEST.tsv` 第 6 列），
目录内的副本可直接 `sh/bash` 运行（shebang 未改，路径依赖靠 `dirname $0/..` 的相对根，
所以从归档目录直接跑会指向 `archive/` 而不是仓库根 —— 要真跑请先按 MANIFEST 的「回退命令」移回 `scripts/`）。

来源判定：`reports/scripts-audit-20261122.md` §5 批 3 第 11 条建议的 4 件里，
**3 件落地归档**，1 件（`android-assets-extract-20261119.py`）复判为「保留」——
它是 `assets/android-20261119/`（319 MB，已 gitignore）唯一的重建路径，且 `scripts/asset-install-linux.sh:108`
的报错文案直接指向它。逐条证据见 `reports/scripts-hardening-4-20261123.md` §2。

- `MANIFEST.tsv`：原名 / 归档后名 / 原路径 / 归档路径 / 字节 / sha256 / 理由 / 回退命令
- 复原单件：`mv archive/scripts-stale-20261123/<原名> scripts/<原名>`
- 复原整批：`cd archive/scripts-stale-20261123 && awk -F'\t' '$1!~/^#/{print "mv " $1" ../../scripts/"$1}' MANIFEST.tsv | sh`

⚠ 归档后的已知悬挂指针（都在本轮写域之外，留给各自 owner）：
- `scripts/README.md` 索引（结构指纹会判过期，刷新 = `python3 scripts/gen-scripts-index.py`，属索引 owner）
- `scripts/deploy-modules.sh:7` 的历史形态注释 —— **本轮已就地改指到归档路径**（同批改动，不算悬挂）
- `reports/`（历史记录，按「历史账不追改」口径保留）：`reports/m1-73-port-bringup-20261013.md:26,33`、
  `reports/audit-20261119/A3-scripts-audit.tsv`、`reports/stale-alpine-audit-scripts-20261119.md`
- `.pi/memory/notes-camera-waydroid.md:76`（agent 记忆，指向 `waydroid-headless-restart.sh`；后继 = `waydroid-cam-restart.sh`）
