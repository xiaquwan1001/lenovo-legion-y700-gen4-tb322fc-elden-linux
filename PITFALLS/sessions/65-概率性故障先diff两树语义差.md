# 65 · **#370** 「概率性」故障先用两树 `git diff` 枚举语义差，别急着加样本

> 结论/命令/数字的唯一事实源在本文件；索引行只放一句话主题。

## 场景

Q24（熄屏 × 相机 → 硬复位）在 vk64（7.2 血统）上 n=8 死 6，在 7.3 线上 41 发 **0** 死。
两边都被当成「概率性」，于是采集→扩样→Fisher 检验，一轮一轮加样本。

## 坑

**「同一套配方、不同镜像、不同死亡率」在统计上是概率问题，在工程上是版本差问题。**
把版本差当概率处理，样本永远不够（要把 6/8 与 0/4 的差异坐实到 p<0.01 还要几十发），
而且每发都要人守着 `fastboot boot` —— 这正是「采样浪费时间」的来源。

## 正确顺序

- **[1]** **先两树静态对拍**：`diff -u A/path B/path`，逐文件，然后**只挑改语义的行**。
   本项目实测：`rpmhpd.c` 167 行 diff 里，数组重排/注释占绝大多数，**行为差异只有 1 处**。
- **[2]** **别只看新增/删除，要看「同一个函数两个版本的行为」**：
   本例 `if (a && b) continue;` → `if (b) continue;` 只差一个条件，
   但配合 `a` 在 7.2 只对 2 个 rail 置 true、7.3 对所有 rail 生效 ⇒ 语义差是 6 个 rail 的档位表。
- **[3]** **用设备上已有的 debugfs 把静态结论变成实测**：`/sys/kernel/debug/cmd-db` 一次 dump 就能读到
   `*.lvl` 原始档位表，直接算出 `enable_corner`。**这一步证伪了我自己的第一版假设**（以为是 `mmcx`，
   实测 `mmcx.lvl` 里根本没有 retention 档）。
- **[4]** **把差异与故障签名求交集**：受影响的 rail 集合 ∩ DSP 的 `proxy_pd_names` ∩ 死亡末帧里的子系统名。
   三者对上，才叫「指名了条件」。只对上两个仍属推测。
- **[5]** **最后才谈补丁/实验**，且实验只需 2–3 发验「变量生效 + 行为改变」，不是扩样。

## 判据（可直接复用）

| 现象 | 该做什么 |
|---|---|
| 两个镜像/树死亡率差很大，同配方 | **先 diff 两树语义**，不要加样本 |
| 想验证「某个档位/阈值在不在」 | 找现成 debugfs/sysfs dump，不要写探针 |
| 第一次假设被 dump 推翻 | **记录推翻过程**（`mmcx` → 真答案是 `cx/lcx/lmx`），这是最有价值的一段 |
| 两个不同干预都让故障消失 | 找它们共同的物理约束 ⇒ 机制可信度 > 任何单臂 p 值 |

## 本项目实例

- 报告：`reports/q24-retention-rootcause-20261023.md`
- 上游对应修复：`pmdomain: qcom: rpmhpd: Skip retention by default`（Mike Tipton, 2026-06-29，`Reviewed-by: Konrad Dybcio`），**7.3 已含**
- 臂：`patches/candidate-q24-retention/0001-*.patch`（+9/−5，与上游同形）

## 一句话

> **「随机」先当版本差查一遍。** 一次 `git diff` + 一次 debugfs dump 的确定性，
> 抵几十发要人守着的样本。

## 附带踩坑（同日邮件）

Cc `Ulf Hansson <ulf.hansson@linaro.org>` 收到自动回执 **"Your email to Ulf Hansson … (Exiting)"**
⇒ 该地址已停用（已离开 Linaro/generic PM 维护）。**以后 linux-pm 相关 Cc 不要带他**；
现任 generic PM domain 维护者走 linux-pm 列表本身即可。同类风险：Cc 名单要从
`MAINTAINERS` 现查，不要沿用旧邮件里的 Cc 行。

## 另一个坑：`make kernelrelease` 有缓存，改 config 后仍返回旧 UTS

改完 `CONFIG_LOCALVERSION` 后 `make kernelrelease` 仍打印旧值（`include/config/kernel.release`
是生成物缓存），看起来像"配置没生效"，实际是没重建。**必须删掉
`include/config/kernel.release` 再构建**，然后用「Image 里解出的 UTS」做最终判据，
不要信树侧命令 —— 这正是 `PITFALLS #367`（同 UTS 不同 config、模块树静默错位）的入口。

## 再一个坑：`reset_control_get_exclusive()` 会与 reset provider 自己撞 `-EBUSY`

把一个 device 树节点的 `resets` 指向某 clk 驱动（如 `dispcc`）的 BCR 时，
**dispcc 作为 reset provider 已经 exclusive 持有那些 BCR**。消费者再用
`_get_exclusive()` 必然 `-EBUSY`（`__reset_control_get_internal()` 里
`WARN_ON(!rstc->shared || !shared) → ERR_PTR(-EBUSY)`），probe 直接失败 `-16`。

两个必须一起做的修法：

- 用 **`devm_reset_control_bulk_get_shared()`**（reset 线本来允许多消费者）；
- **shared 是 deassert 引用计数**：首用必须先 `deassert()` 一次建 `deassert_count`，
   否则随后 `assert()` 撞 `WARN_ON(atomic_read(&rstc->deassert_count) == 0)` 返回 `-EINVAL`。
   ⇒ 正确顺序 = **deassert(prime) → assert → msleep → deassert**。

判据：上机后 `dmesg | grep -c "failed to acquire mdss resets"` 必须 0；
出现 `-EBUSY` 时症状是**比不带补丁还差**（显示完全不起来、phosh 不在），
容易被误读成"复位把硬件弄坏了"，实际是根本没拿到 reset。
