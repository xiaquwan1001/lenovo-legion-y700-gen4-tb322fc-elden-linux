# 157 · UEFI：载荷执行的三层判据 + 两条通道在本机的真实边界

> 来源会话：2026-11-03 晚 ~ 11-04（UEFI 线 7 发零写盘）。
> 正文/证据：`reports/uefi-payload-execution-20261104.md`、`TASKS/sessions/2026-11-04-UEFI载荷首次被执行.md`。

## **#490** `Booting OKAY ~10.1 s` 只到「ABL 接受并跳了」这一层——判据要分三层

历史上一度把 `usb_read failed`、后来把 `Booting OKAY ~10.1 s` 当「载荷被执行」，两次都错。本轮把它拆成三层，各有独立判据：

| 层 | 判据 | 反面 |
|---|---|---|
| ① ABL 层：镜像被接受并跳转 | `Sending` 1.4–1.9 s（按体积）+ `Booting OKAY ~10.1 s` | `Sending 0.056 s` + 立刻 `usb_read failed` = 头校验阶段被拒 |
| ② shim 层：载荷第一条指令起真在跑 | 屏上色带（`splash_region` 直涂）逐段推进 | 色带不动 / 只停在第一条 |
| ③ UEFI 层：Mu 真在跑 | 屏上 `UEFI firmware (version …)`（`AndromedaPkg/PrePi/PrePi.c:137`）+ 插桩 `[Pnn]` | 只有色带、没有版本行 |

**决定 ① 的是打包/载荷头，不是代码内容**：同一份 FD，v0 `base=0x10000000` + `text_offset=UEFI_BASE` 恒 0.056 s 被拒；换 **v2 base 0 + `text_offset=0` + `image_size`=解压真实长 + `flags=0xa`** 立即被执行。
**这份配方已固化为** `scripts/uefi-repack-v2aligned.py`（含 `only-kernel-differs` 断言）。

## **#491** DDR 标记通道在「载荷被执行」类场景失效——只剩屏上串口

现象：载荷跑过之后，低 4 GiB 出现 **~1.9 GB `0xFF`**（`0x82600000`–`0xf37fffff`，含 `dsm-partition-1@84a00000` / `video@9c300000` / `dsm-partition-2@89300000` 三块 carveout 窗），把 shim 早写的 stage 页一起抹掉 ⇒ 三窗读回恒 100% `0xFF`，无法判读。

**定性靠两次零成本对照**（这是本条的方法论要点）：
- 对照 A：三窗 `prep` 清零后**纯重启**到 Linux ⇒ 窗内仍 `0x00`（正常启动链不填）；
- 对照 B：**同一 `fastboot boot` 路径启动真内核**（不改我们的载荷）⇒ 三窗仍 `0x00`（ABL 路径不填）。
⇒ 填充**只能来自我们自己的载荷**，且定位在 **PrePi 的 `MemoryPeim`/MMU 段**（`[P04]` 前后）。

⇒ 通道选择结论：**屏上串口**（实时、可判）为主；`splash_region` 会被 ABL 下次启动清屏，所以只能实时看、不能事后读回。
选通道前先跑「同一路径启动真内核」这条零成本对照，避免把自家载荷的副作用记成环境特性。

## **#492** `splash_region` 的 DT 声明尺寸不可当真——只有前 ~448 KiB 可写

- 地址本身没问题：`/proc/device-tree/reserved-memory/splash_region/reg` = `0xFC800000` / `0x02B00000`（`no-map`），写读自检 `0xFC840000` 通过。
- **坑在尺寸**：按声明整块填 43 MiB，屏上红到约 137 行后**整机无响应**（写/读更高偏移同样挂死）。可安全写的只有**前 ~448 KiB**（实测到 `0x70000`）。
- ⇒ 屏上标记一律落在前 192–448 KiB；需要「整块变蓝」这类强判据时用 192 KiB 块。
- 附带：`MU_BASECORE`、`Common/*` 等在 `build/uefi-woa-prep/repos/7-mu-lenovo` 里是 **submodule**，插桩后还原要在**子模块内** `git checkout --`（主仓 `git checkout -- <路径>` 会报「未匹配任何 Git 已知文件」）。
