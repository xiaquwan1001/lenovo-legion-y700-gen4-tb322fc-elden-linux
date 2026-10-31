# M6/B5 序列「邮件就绪」收尾（2026-10-31）

> 起因：`patches/local/b5-resoc-20261027/` 内容已通过门禁，但有三处**投递形态**缺陷。
> 执行：`impl-worker` lane（`0c1681e7…`）完成重出后**在 send-email 步骤被工具调用中断而死亡**（未写报告）；
> 产物已落盘，**由总管接管收尾并复核**。本文件即最终口径。

## 0. 结论

**6 个文件 = 邮件就绪**（cover + 5 枚）：门禁 `PASS=5 FAIL=0 WARN=0 退出码 0`、5 枚 checkpatch(stdin) 全 clean。
**未发送**；投递仍按 `TASKS/README.md` §7 由用户逐批放行。

## 1. 三处形态缺陷与处置

| # | 缺陷 | 处置 |
|---|---|---|
| ① | 0001–0003 混入 `Lane:`/`Agent:`/`Baseline:`/`Task:` **仓库记账 trailer** | 全部剥离（`Signed-off-by` 保留）；复核 `rg -n "^(Lane|Agent|Baseline|Task):" …` **0 命中** |
| ② | **缺 cover letter**（门禁唯一 WARN） | 新增 `0000-cover-letter.patch`（`[PATCH 0/5]`），含 AI 披露、系列定位、**明确声明不含 Q28 面板功能性修复**、门禁证据、`base-commit` |
| ③ | 0004 的 message 把「FIFO error mask」塞进 master 归属说明 | 改为只讲 master 归属（「master 是 SoC 代次属性，不是 probe 顺序」）+ 一句行为不变 |

重出后在提交层生成（`git am` → `format-patch --cover-letter --base`），因此 5 枚同时获得规范 `From/Date/Subject` 头与 `Signed-off-by`。

## 2. 总管对 cover 又改了三处（lane 产物的问题）

| 问题 | 现象 | 修正 |
|---|---|---|
| 标题重复 | `Subject:` 后紧跟一行与标题逐字相同的正文首行 | 删该行 |
| shortlog 头重复 | `Qianhui Xu (5):` 出现**两次**（手工插 shortlog 与 format-patch 自带叠加） | 只留一个 |
| 论断过强 | 「Tested on the SM8750 device itself」—— 本系列**未整包上机**（上机的是同一逻辑的 B5 第 1–4 步/在机血统） | 改为「本系列 re-home 的正是该设备 vendor 血统驱动的命令通路；系列不引入新运行时行为」，并把三道门禁单列为证据 |

`git mailinfo` 解包 rc=0、Subject/Author 正确。

## 3. 最终产物

```
patches/local/b5-resoc-20261027/
  0000-cover-letter.patch                              (2670 B, [PATCH 0/5])
  0001-dsi-manager-bonded-failure-flag.patch           (2703 B)
  0002-dsi-per-soc-bonded-cfg.patch                     (7196 B)
  0003-dsi-bonded-host-ops.patch                       (14736 B)
  0004-dsi-bonded-master-from-cfg.patch                 (6963 B)
  0005-dsi-name-fifo-error-bits.patch                  (3632 B)
```
> **文件名刻意保留旧名**（不用 format-patch 默认的 subject-slug 名）：`TASKS`/`reports`/`PITFALLS` 里多处引用旧名，改名会造成 `check-doctor` 的"文档引用不存在路径" FAIL。subject 在补丁头里，文件名不承担语义。
## 4. 门禁（总管自跑）

```console
$ bash scripts/check-series-selfcontained.sh patches/local/b5-resoc-20261027 0f1fb1c9c1 --repo build/vk151
  ok    0001 / 0002 / 0003 / 0004 / 0005
PASS  b5-resoc-20261027: 全部 6 个文件按序重放成功于 0f1fb1c9c1
== 汇总: PASS=5 FAIL=0 WARN=0 退出码=0 ==
```

- `checkpatch --strict`（**stdin**）：5 枚全 `has no obvious style problems and is ready for submission`。
- cover 走 checkpatch 会报 `ERROR: Does not appear to be a unified-diff format patch` —— **cover 无 diff 段，固有提示**（M3v5 cover 同形），不作为门禁。
- 编译门（独立临时 worktree + `git am` 5 枚 + `build/vk151/.config` + `olddefconfig`）：`make -j26 W=1 drivers/gpu/drm/msm/` **rc=0、0 warning/0 error**。

## 5. 投递参数（**未执行**，供放行时用）

```
To      : Dmitry Baryshkov <dmitry.baryshkov@oss.qualcomm.com>, Rob Clark <robdclark@gmail.com>
Cc      : linux-arm-msm@vger.kernel.org, dri-devel@lists.freedesktop.org, linux-kernel@vger.kernel.org
          （不含 devicetree：本系列无 DT 改动）
base    : 0f1fb1c9c1c8f09c711e8e9a82acbde2baeed691
```

## 6. 已知局限（投递前应知）

1. **尚未整包上机**：本系列 = 在机 vendor 血统同逻辑的 re-home，`No functional change` 由 0005 明写；若 reviewer 要求运行证据，回信给 B5 分步上机记录（2026-10-27 第 1–4 步）。
2. **`build/vk151` 工作树与序列不完全同形**（工作树曾用通用宏取代表字段）——已裁决以序列为准，工作树只是实验态，**不要**把它当对照。
3. 系列基线 `0f1fb1c9c1` 是本地 payload 快照提交，**不在公开树**；`base-commit:` 因此只作信息用途，reviewer 需按 `[PATCH 1/5]` 的上下文 rebase。若上游要求，可另出一版 rebase 到 `v7.3-rc7` 的同一改动。
