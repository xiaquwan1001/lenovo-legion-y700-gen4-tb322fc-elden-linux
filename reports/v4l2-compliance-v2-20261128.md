# iris v4l2-compliance 系列：机械对账后 v2 只剩 1 贴（2026-11-28 早，无人值守）

- **一句话结论**：v1 三贴里 **1/3 是已合入主线的重复**（`1facae9bc3c1`，2026-09-29）、**3/3 已被主线 s_fmt 重写取代**（v7.4-rc3 的 `inst->crop` 在两条分支都从用户格式 seed），**只有 2/3（colorspace 默认）仍成立**；已按 Bryan 的要求重做成 rebase 到 **v7.4-rc3** 的单贴（带 `Fixes:` + `Cc: stable`），编译与 `checkpatch --strict` 全绿、`git apply --check` 通过，**投递被 keyring 锁挡住（GDM greeter 会话）⇒ 需用户登录后发**。
- **性质**：主机侧（上游机械核对 + 编译），无设备操作、无外发。
- **触发**：Bryan O'Donoghue 2026-11-27T16:04:09Z 在 v1 的 1/3 回帖「Please add an appropriate Fixes: and Cc: stable@vger.kernel.org」（MID `<6505dda0-f534-4705-bcea-ecf5f6b9ec30@kernel.org>`，`In-Reply-To` = v1 2/3 MID）。

---

## 1. v1 三贴逐条核对（对 mainline 现态）

| 贴 | v1 判据 | 主线现态（v7.4-rc3 = `aebb72744764`，`iris_vdec.c` 与 master 逐字节同 md5 `d0fcea9459de…`） | 结论 |
|---|---|---|---|
| 1/3 `report a platform bus_info prefix` | `plat:` → `platform:` | **已修**：`1facae9bc3c1` *media: iris: Fix bus_info prefix in VIDIOC_QUERYCAP*（Vishnu Reddy，2026-09-29，`Fixes: 94ef75095d5e`、`Cc: stable`）与我的 1/3 **逐字节同**（同一 `snprintf` 行同改法） | **撤**（重复）。我方日常树 base 早于该提交，所以仍见 `plat:` |
| 2/3 `fill in a default colorspace` | 捕获/输出 `colorspace/xfer_func/ycbcr_enc/quantization` 留在 `*_DEFAULT` | **仍成立**：`iris_vdec_inst_init()` 的 fmt_dst 四个字段仍是 `V4L2_*_DEFAULT`（`iris_vdec.c:52-55`），`iris_vdec_try_fmt()` 完全不碰 colorspace（`:169-212`），fmt_src 干脆没赋值（kzalloc ⇒ 0 = DEFAULT） | **保留，重做 v2** |
| 3/3 `seed the crop rectangle when only CAPTURE is formatted` | `inst->crop` 未 seed ⇒ G_SELECTION 0x0 | **已不适用**：主线 v7.4-rc3 `iris_vdec_s_fmt()` 在 OUTPUT 与 CAPTURE **两条分支都**无条件 seed（`iris_vdec.c:271-274` 与 `:309-312`），CAPTURE-only 的 S_FMT 不再是 0x0 | **撤**（被主线重写取代） |

> 说明：3/3 是针对**我方树**（2026-10-14 base + 1222157 backport 后的 `min()` clamp 形态）写的；主线已换成无条件 seed，两者不共存。

## 2. v2（单贴）做了什么

产物 = `patches/upstream/v4l2-compliance-iris-20261127/0002-v2-fill-default-colorspace.patch`（sha256 `35816a1bc7db3db9…`，2026-11-28 二版：Fixes 段落加了一句甄别）：

1. `iris_vdec_inst_init()`：fmt_src（OUTPUT）补 `REC709 / XFER_709 / YCBCR_709 / LIM_RANGE`；fmt_dst（CAPTURE）把四行 `*_DEFAULT` 换成同一组值。
2. `iris_vdec_try_fmt()`：`pixmp->colorspace == V4L2_COLORSPACE_DEFAULT` 时归一成同一组值（保证 `G_FMT → S_FMT` 幂等、TRY_FMT 自洽）。
3. 报文：v2 changelog 明写「1/3 重复 `1facae9bc3c1`、3/3 被主线 s_fmt 重写取代，请 drop」+ AI 披露 + `Fixes: b530b95de22c ("media: iris: implement s_fmt, g_fmt and try_fmt ioctls")` + `Cc: stable@vger.kernel.org`。
   - `Fixes:` 取值依据（**本轮被独立复核纠正过一次，记下过程**）：父代理初查「`b530b95de22c` 的 raw 文件里有这 4 行」就判为引入点；lane 独立复核指出**该提交的 parent `38fc8beaba55` 里这 4 行就已存在** ⇒ 初查结论作废。父代理复跑确认：`iris_vdec.c` 在 **`38fc8beaba55`**（"media: iris: implement reqbuf ioctl with vb2_queue_setup"，Dikshita，2025-02-07）**才被创建**，其 parent `bb8a95aa038e` 该文件不存在（raw 404）⇒ **初始化**的引入点 = `38fc8beaba55`；但**「S_FMT 原样存下客户端 DEFAULT、G_FMT 原样回吐」这条行为**由 `b530b95de22c`（s_fmt/g_fmt/try_fmt 实现，同日）引入，缺陷的**可观测形态**从这里开始。
   - **决定**：`Fixes: b530b95de22c`（行为引入点），并在报文里**点名两个 sha** 说明「初始化器更早（38fc8bea），原样存取的是 b530b95」——让维护者一眼判定，不赌单点。

## 3. 门禁（父代理自跑）

| 项 | 命令 | 结果 |
|---|---|---|
| 应用 | `git apply --check`（v7.4-rc3 树，`~/elden-cache/build/g7-tree`） | ✅ APPLY_OK，`git diff --stat` = 25 ±（21 插 / 4 删） |
| 语法/风格 | `scripts/checkpatch.pl --no-tree --strict` | ✅ **0 errors, 0 warnings, 0 checks**（43 行） |
| 编译 | `ARCH=arm64 CROSS_COMPILE="ccache aarch64-linux-gnu-" make -j8 M=drivers/media/platform/qcom/iris modules` | ✅ 全部 `.o` 编出（`iris_vdec.o` 等 06:13 刷新）；`modpost` 因该树未编 `vmlinux`（无 `Module.symvers`）报未定符号，属**该树未全量构建**的已知现象，不构成本贴问题 |
| 发信解析 | `git send-email --dry-run` | ✅ 收件人 = linux-media(To) + arm-msm/Vikash/Dikshita/Abhinav/Bryan/Mauro/Hans/Stefan + **stable@vger（从 Cc trailer 自动加）**，`In-Reply-To/References` = v1 cover |

## 4. 投递（2026-11-28 08:37 CST 已实发；原「受阻」小节降为历史）

- **结果**：`Result: 250`，MID `<20261128003737.1300698-1-xiaqinghuan@mail.ustc.edu.cn>`，日志 `out/mail-20261128/send-v2-iris-colorspace.log`；lore 复核 ✅ **HTTP 200 / 15 377 B gzip**，线程 6 封（v1 cover+3 贴+Bryan 回帖+本 v2），Subject 未改写、`Fixes:`/`Cc: stable`/SoB 逐字在档。
- 历史（当时受阻原因，留作工具事实）：本机当时只有 **GDM greeter** 会话（`loginctl` 可见 `c1 gdm-greeter`），keyring 锁着 ⇒
  `git credential fill` 报 `could not read Password for 'smtp://…@smtp.ustc.edu.cn:465'`（rc=128，8 s 超时内返回，非挂死）。
- 需人工：用户**登录图形会话**后执行下面一条（命令已 dry-run 验证过，逐字可复制）：

```sh
cd /home/xuqianhui/y700-elden && git send-email \
  --to=linux-media@vger.kernel.org --cc=linux-arm-msm@vger.kernel.org \
  --cc='Vikash Garodia <vikash.garodia@oss.qualcomm.com>' --cc='Dikshita Agarwal <dikshita.agarwal@oss.qualcomm.com>' \
  --cc='Abhinav Kumar <abhinav.kumar@linux.dev>' --cc="Bryan O'Donoghue <bod@kernel.org>" \
  --cc='Mauro Carvalho Chehab <mchehab@kernel.org>' --cc='Hans Verkuil <hverkuil@kernel.org>' \
  --cc='Stefan Schmidt <stefan.schmidt@linaro.org>' \
  --in-reply-to='<20261127152024.2149804-1-xiaqinghuan@mail.ustc.edu.cn>' \
  patches/upstream/v4l2-compliance-iris-20261127/0002-v2-fill-default-colorspace.patch
```

- 发完的复核（判据）：`curl -sS --noproxy '*' 'https://lore.kernel.org/linux-media/<新MID>/t.mbox.gz'` 返 200 gzip、Subject 未被改写、线程挂在 v1 cover 下；然后回填 `SENT.md`。

## 5. 工具事实（本轮新增，可复用）

- **cgit `blame/` 视图吃 403（Anubis）**；`log/`、`plain/`、`patch/?id=` 三个视图用默认 curl UA 都通（`patch/` 会先 301，要 `-L`）。
- **本地树的历史被截断**（`~/elden-cache/build/{daily,g7-tree}` 均报 `Could not read a2795d9c…` / 只 7920 提交）⇒ `git log -S` 与 `git blame` 会给出**假的归属**（把 iris 的门面行记到一个 EFI merge 提交上）。查引入点改用：`api.github.com/repos/torvalds/linux/commits?path=<file>` + `raw.githubusercontent.com/.../<sha>/<file>` 直接取该 sha 的文件内容做「有/无」判定。
- 判「我们的补丁是否重复上游」最快的一条：把 patch 与主线对应文件在当前 master 的 `plain/` 比一眼，再看该文件 `log/` 里有没有同名修复（本轮 1/3 就是这样 30 秒定性的）。
