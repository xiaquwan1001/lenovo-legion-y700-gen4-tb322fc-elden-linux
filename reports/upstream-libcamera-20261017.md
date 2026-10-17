# libcamera 上游提交记录（2026-10-17）

- 目标：把相机 AE 的两个通用改动按上游规范提交到 **libcamera**（`libcamera-devel` 邮件列表）。
- 系列：`[PATCH 0/2] ipa: libipa: add sensor helpers for GC08A8/S5KJNS and make the AGC target tunable`

## 1. 提交内容（已进 git 库 `/tmp/lc-git`，基于 tag `v0.7.1`）

| # | 提交 | 文件 | 说明 |
|---|---|---|---|
| 1 | `ipa: libipa: add camera sensor helpers for GC08A8 and S5KJNS` | `src/ipa/libipa/camera_sensor_helper.cpp` | 增益模型（1/1024、1/32）+ 黑电平 4096 |
| 2 | `ipa: simple: agc: make the exposure target tunable` | `src/ipa/simple/algorithms/{agc.h,agc.cpp}` | tuning 键 `exposureTarget`，默认 0.5 保持旧行为 |

补丁归档：`patches/camera-ae-fix-20261017/0002-…patch`、`0003-…patch`（内容与 git 提交一致）。

**风格自检**：`utils/checkstyle.py HEAD~2..HEAD` 只报 "Missing clang-format / reuse"
（主机未装这两件工具），**已手工核对 0 行 >80 列**。若要跑全量 checkstyle：
`sudo apt install clang-format reuse` 后重跑。

## 2. 投递事实（2026-10-17 23:33 CST）

| 项 | 值 |
|---|---|
| 通道 | `git send-email` → `smtp.ustc.edu.cn:465`（Message-ID 保真） |
| To | `libcamera-devel@lists.libcamera.org` |
| Cc | Milan Zamazal、Hans de Goede、Kieran Bingham、Laurent Pinchart |
| Message-ID（cover） | `20261017153344.436818-1-xiaqinghuan@mail.ustc.edu.cn` |
| Message-ID（patch 1） | `…-2-…`、patch 2 `…-3-…` |
| 列表属性 | **members-only** ⇒ 非成员直接投被 hold（"Post by non-member to a members-only list"） |
| 处置 | 已发订阅确认（token `5c7937…`）；hold 通知里另给了 3 个 cancel URL（保留在邮箱 INBOX 6488–6490） |

**下一步**：等 `Welcome to libcamera-devel` → 若 held 的 3 封仍未放行，重发同一系列
（`git send-email` 同一组文件即可，Message-ID 会变，属正常重投）。

## 3. 复核方法

```bash
# 归档（Pipermail，非 lore）
curl -s https://lists.libcamera.org/pipermail/libcamera-devel/2026-October/date.html | grep -i Qianhui
# 回信/放行状态
python3 ~/.local/bin/read-mail-ustc.py --days 1 --grep libcamera
```

## 4. 踩坑（已登记 `PITFALLS #305`）

1. `libcamera-devel` 是 **members-only**：未订阅的投递会被 hold，必须**先订阅并回确认信**再投。
2. 订阅确认信有**两封 token**（request 回的 + 列表自动发的），任一回一次即可；
   Mailman 2 的确认可以「保持 Subject 原样回复」，也可以发 `confirm <token>` 到 `-request`。
3. libcamera 的提交前缀带**文件名**（例：`ipa: libipa: camera_sensor_helper: add ov02c10`）。
   我们的第 1 补丁写成 `ipa: libipa: add camera sensor helpers …`，若被要求，可在 v2 改成
   `ipa: libipa: camera_sensor_helper: add GC08A8 and S5KJNS helpers`。
