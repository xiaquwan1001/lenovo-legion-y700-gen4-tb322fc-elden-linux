# D13 — 侧滑返回意图放宽（lisgd `-r 45` + 对角/竖直手势 + 弧线注入验收）

- **日期**：2026-11-28（上机，用户 `ssh elden` 在场）
- **触发**：用户真机反馈「必须水平滑动才返回；拇指弧形不被识别；Firefox 里滑动还会被网页当上下滚动」。
- **根因**：lisgd `-r degreesofleniency` 默认 **15°**（上限 45°），方向按 45° 档分类（0=上 / 45=右上 / 90=右 / 135=右下 / 180=下 …），
  旧 helper 只绑 `LR`（左边缘）与 `RL`（右边缘）⇒ 左边缘只认 75°–105°、右边缘只认 255°–285°，
  **其余角度全是死区**，正是拇指弧线的弦角（实测 20°–45°）。

## 0. 一句话结论

helper 改为 **`-r 45`** 并按 lisgd 的分类链为两侧绑定多档手势后：**20.8°（原死区）、44.7°（左弧）、315.1°（右弧）都能触发返回并真关窗**；
中部竖划（0°，edge=N）仍不误触；原 90° 水平滑动无回归。

## 1. 改了什么

| 文件 | 改动 |
|---|---|
| `packaging/elden-userland/files/usr/local/bin/lisgd-edge-swipe`（= 设备 `/usr/local/bin/lisgd-edge-swipe`，sha `c5561107…`，4585 B） | ① 新增 `-r ${ELDEN_SWIPE_LENIENCY:-45}`（1..45 校验，越界即退出）；② 左边缘绑 `DU/DLUR/LR/ULDR`，右边缘绑 `DU/UD/URDL/RL/DRUL`；③ echo 行加 `leniency=` |
| `packaging/elden-userland/MANIFEST.tsv` | 行 40 的 sha/大小同步为 `c5561107…` / 4585 |
| `tools/uinput-touch.c` + `tools/uinput-touch-build.sh`（`-lm`） | 新增 `hold-arc X1 Y1 X2 Y2 [attach_ms] [steps] [bow]`：二次贝塞尔（控制点 = 弦中点 + bow×单位法向，默认 25% 弦长），用于复现拇指弧线；`hold-swipe` 行为不变 |

**为什么这样绑**：lisgd 的方向判定是 if/else 链（`DU→DLUR→LR→ULDR→UD→URDL→RL→DRUL`），每次只得出**一个**方向值，
再在 `-g` 表里找**第一条**匹配（只执行一条命令）。`-r 45` 让相邻档位区间重叠，按分类链实际切分为：
`[315,45]=DU、(45,90)=DLUR、(90,135]=LR、(135,180]=ULDR、(180,225]=UD、(225,270]=URDL、(270,315]=RL、(315,360)=DRUL`。
因此：

- 左边缘（接受向右/上/下）= `DU + DLUR + LR + ULDR` ⇒ 覆盖 315°…180°，**排除向左**（180°–315°）。
- 右边缘（接受向左/上/下）= `DU + UD + URDL + RL + DRUL` ⇒ 覆盖 135°…45°，**排除向右**（45°–135°）。

## 2. 验收（注入设备 + 独立 lisgd，逐例读 `/tmp/lisgd-arc-*.log` 与 foot 顶层计数）

| # | 例 | 弦角 / lisgd 度数 | 结果 | 证据 |
|---|---|---|---|---|
| 1 | **左弧** (8,2200)→(700,1500)，bow=+200 | `degrees=[44.69]`（DLUR） | ✅ `Execute …/elden-swipe-back-left`，foot **1→0** | `/tmp/lisgd-arc-left.log` |
| 2 | **右弧** (1896,2200)→(1200,1500)，bow=−200 | `degrees=[315.14]`（DRUL） | ✅ `Execute …/elden-swipe-back-right`，foot **1→0** | `/tmp/lisgd-arc-right.log` |
| 3 | **中部竖划** (900,1500)→(900,400) | `degrees=[0.00]`（DU，edge=N） | ✅ **无 Execute**，foot **1→1**（不误触） | `/tmp/lisgd-arc-mid.log` |
| 4 | **原死区 20.8°** (8,1500)→(350,600) | `degrees=[20.82]`（DU） | ✅ `Execute …left`，foot **1→0**（`-r 15` 时此角不匹配任何档） | `/tmp/lisgd-arc-dead20.log` |
| 5 | **水平（无回归）** (8,1500)→(700,1500) | `degrees=[90.00]`（LR） | ✅ `Execute …left`，foot **1→0** | `/tmp/lisgd-arc-straight.log` |

> 测试方法：先起 `foot`（`systemd-run --user foot`）作靶窗；后台 `uinput-touch hold-arc … 25000` 建设备并等 daemon attach；
> 起同参数 `lisgd -v`（**以 root 跑**，lisgd 在 afters 作为系统服务就是 root；以普通用户跑则 `uinput-back` 无 `/dev/uinput` 权限，会静默不关窗）；
> `wait` 注入结束后读日志 + `runuser -u xuqianhui1001 -- wlrctl toplevel list | grep -c '^foot:'`。
> 脚本 `/tmp/arc-test.sh`（临时件，未入库）；方法可复现步骤见下文 §4。

## 3. 固有边界（写进结论，不是 bug 修复项）

**lisgd 只旁听 evdev（`open(O_RDONLY)`，无 `EVIOCGRAB`）⇒ 同一次触摸照常送到应用。**
这就是 Firefox 里「既触发/不触发返回、网页又把竖直分量当滚动」的原因；不是配置问题。
两条候选路线（**本轮未做，需裁决**）：

1. **上游 phoc #125 路线**：在合成器层实现 edge-swipe 并吞掉事件（正解，但要改 phoc/wlroots，上游 issue 自 2020 开着）。
2. **本地边缘带 `EVIOCGRAB` + 非边缘事件重放**：复杂、有丢事件/卡触摸风险，**必须先做无设备对照**（虚拟显示器/QEMU）再上机。

在此之前接受「Firefox 内偶发误滚动」，已列进已知限制。

## 4. 复现命令（设备侧）

```sh
# 服务现态（改后）
systemctl restart lisgd-edge-swipe && systemctl is-active lisgd-edge-swipe
tail -1 /var/log/lisgd-edge-swipe.log     # => … leniency=45 … -r 45 -g 1,DU,L,… 
# 弧线注入（root 跑；需要 /dev/uinput）
sudo -n /usr/local/bin/uinput-touch hold-arc 8 2200 700 1500 25000 16 200
```

## 5. 门禁

| 门 | 结果 |
|---|---|
| `scripts/deploy-desktop-shell.sh --check` | **MISS=0**（§15「返回」链 3/3 ok：`wm close` 含 `XF86Back`、lisgd 在位、uinput-back 在位；§15 反例自检 1 正例 + 4 反例通过） |
| `packaging/elden-userland/tools/verify.sh --offline` | **FAIL=0 / WARN=0** |
| `scripts/check-userland-mirror.sh --check` | 同 sha 配对 35 ｜ 白名单漂移 0 ｜ 白名单外 0 ｜ 设备专有件 80，退出码 0 |

## 6. 回退

设备侧两份旧件已留 `/usr/local/bin/{lisgd-edge-swipe,uinput-touch}.bak-20261128`；
仓内回退 = `git checkout -- packaging/elden-userland/files/usr/local/bin/lisgd-edge-swipe packaging/elden-userland/MANIFEST.tsv tools/uinput-touch.c` + 重新部署。
