# sm8750 ADSP fastrpc non-secure —— 已投（2026-11-07）

> 来源：7.3.1 重基上机时定位到的 **G1-34 在机真因**——提交树里只有 `cdsp` 的 fastrpc 节点带
> `qcom,non-secure-domain`，`adsp` 没有 ⇒ 只有 `/dev/fastrpc-adsp-secure`，`/dev/fastrpc-adsp` 永不出现，
> `libssc`/`hexagonrpcd` 连不上 sensor PD（qrtr svc 400）、`iio-sensor-proxy` 三项全 false。
> 加一行后 `/dev/fastrpc-adsp` 在、SensorProxy accel/light/prox **全 true**（vk185-adsp 实测）。

## 投递事实

| 项 | 值 |
|---|---|
| 时间 | 2026-11-07T03:26:46Z（本地 11:26 +0800） |
| 基线 | master `d48723711b`（`git am` 干净应用） |
| To | `andersson@kernel.org`, `konradybcio@kernel.org` |
| Cc | `robh@kernel.org`, `krzk+dt@kernel.org`, `conor+dt@kernel.org`, `linux-arm-msm@vger.kernel.org`, `devicetree@vger.kernel.org`, `linux-kernel@vger.kernel.org` |
| Message-ID | `<20261107032646.32363-1-xiaqinghuan@mail.ustc.edu.cn>` |
| SMTP | 1 封 `Result: 250`（日志 `out/mail-20261107/send-adsp-nonsecure.log`） |
| 回环 | 自家 INBOX 收到副本（uid 15707），**无退信** |
| patchwork | ✅ 已摄取：`2026-11-07T03:26 new`（投后约 1 h；同窗 wl2868c v9 = 1/2 `needs-ack`、2/2 `new`） |

## 门禁（发信前现跑）

```
# 干净 master worktree
git worktree add -f /tmp/adsp-up d48723711b && cd /tmp/adsp-up
git am -q .../0001-arm64-dts-qcom-sm8750-mark-the-ADSP-fastrpc-node-as-.patch     # → OK

# DT 门（对 SoC dtsi 生效的最接近上游验证：sm8750-mtp 板）
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CHECK_DTBS=y W=1 qcom/sm8750-mtp.dtb
# → 唯一 warning = dsi@ae96000 的 avoid_unnecessary_addr_size，**基线上同样存在**（已逐条对比：基线也是这条）

# 风格
perl scripts/checkpatch.pl --strict --no-tree --terse 0001-*.patch                # → 0 error / 0 warning / 0 check
```

## 备注

- 本补丁**不是** elden 板级 DTS（板件仍 held-back）；它只改 SoC dtsi 一行，对所有 SM8750 板适用。
- 若维护者要求与「板件/消费者」一起发，按 `TASKS` §7 的 M 系列口径等待，不单独 ping。

## v2 投递（2026-11-10，用户批准「先发送」）

| 项 | 值 |
|---|---|
| 时间 | 2026-11-10T02:31:53Z（本地 10:31 +0800） |
| 件 | `out/mail-20261110/0001-…-v2.patch`（= v1 + `[PATCH v2]` + v2 changelog + `Fixes:` 尾行，**diff 未变**） |
| Message-ID | `<20261110023153.84262-1-xiaqinghuan@mail.ustc.edu.cn>` |
| SMTP | `Result: 250`（日志 `out/mail-20261110/send.log`） |
| `Fixes:` 哈希 | `be9d54c35312479ed92c85aec3cd43153513210d`，**投前用 lore 原始件独立复核**（`[2/2] arm64: dts: qcom: sm8750: add ADSP fastrpc-compute-cb nodes`） |
| 门禁 | `checkpatch --strict` 0 error / 1 warning（`Unknown commit id`，本机压缩导入树无上游历史所致）；`git apply --check` 在 `build/m3v2-7.3rc7`、`build/daily` 均 OK |
| lore | ✅ 已归档：`/all/20261110023153.84262-1-…/`（2026-11-10T02:32:02Z） |
| 线程 | `In-Reply-To` 挂在 v1 上；本线程此前只有我方 v1 + sashiko 一封（11-07），无人工回复 |

备注：`read-mail-ustc.py --days 1` 本轮**崩了（SIGTRAP/core dump）**，回环与退信因此未用该脚本核对；
lore 归档 + `Result: 250` 是本轮的投递判据。下次用它之前先修脚本（另开一项）。
