# 上游邮件核查 + 同 SoC 参考面（2026-10-23 晚）

> 只读：未发任何邮件、未改凭据、未碰设备（设备留在 vk152 运行态）。
> 通道：`~/.local/bin/read-mail-ustc.py` / `fetchbody.py`（IMAP `mail.ustc.edu.cn:993`）+ `lore-query.py`。
> 窗口：2026-10-21 → 2026-10-23 ~21:00 CST（承接 `reports/mail-triage-20261023.md`，只写差量）。

---

## 0. 结论

1. **Q28（dispcc 复位归属）**：我方 **10-23 15:52 CST** 已回 Taniya 并接受其两点意见（clk probe 不是复位该在的地方；整块复位会闪屏），
   提出把 3 个 BCR 搬到 `msm_mdss_reset()`（= 随后 vk150/vk151/vk152 实际做法）+ 3 个待确认问题 + Fisher p=0.003 数据。
   **至核查时点 0 条新回复**（Taniya / Dmitry / Bjorn / Turquette 皆无）。
2. **battmgr / Q24**：Konrad **10-23 10:13 +0200** 追加一问 —— **“Did you try reaching out to the vendor?”**（唯一需决策的新增项；
   与厂商接触属外部干预，交用户裁定）。
3. **面板 REPORT**：`[REPORT v2]`（10-15）lore 上 **0 回复**；`[REPORT]` v1（10-13）唯一的第三方回复来自 **Pengyu Luo**
   （要点：**panel 驱动本身 OK，DPU 可能不行**；上游双 DSI + 双 DSC 面板“多数没问题，但会被 DPU 拖死”，需要 hack
   **10-bit C-PHY 的 DSI clk source select**，他说短期无法投入）。这条与我们 Q28 的机理判断同向，且指出 **DPU 侧**是缺口。
4. **同 SoC 参考面（决定性）**：
   - **本机同一台机器的上游 DT 已经有人在做**：Pengyu Luo `[PATCH v2 0/2] Introduce Lenovo Legion Y700 Gen4`（2026-07-26，
     v1 = 2026-07-19，Phoronix 有报道），新增 **`arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts`（1170 行）** ——
     **和我们树里的同名文件**（我们 3178 行，文件头已带他的 copyright）。DT 路线 = **framebuffer 需要 mdss/dispcc 关掉**；
     v2 才加 panel 节点（因为面板驱动已上游）。
   - **SM8750 显示上游的“官方现状”**：Krzysztof Kozlowski `[PATCH v4 00/19] drm/msm: Add support for SM8750`（2025-03-11）明确
     “**DSI panel on MTP8750 still shows darkness**”，所以先合 DPU/catalog；DSI 部分后置。
   - **同 SoC 的“面板点不亮”已知根因类型**：`arm64: dts: qcom: sm8750-mtp: Set sufficient voltage for panel nt37801`
     v3（2026-10-07，Ayushi Makhija/Arpit Saini，**R-b: Dmitry Baryshkov + Konrad Dybcio**）—— NT37801 spec 5.7.1 要求
     **VDDI 1.65–1.95 V**，DT 原来只给 1.2 V ⇒ 抬 `min-microvolt`。即“冷起面板黑”在 SM8750 上已有**电源/上电序列**类先例。
   - mainline 里 SM8750 板级只有 **MTP / QRD**（7.3-rc7 树内 + 我们的 elden），无手机 DTS 合并；
     `kaanapali`（SM8850，8 Elite Gen 5）与 `eliza` 复用 **`qcom,sm8750-dsi-ctrl` / `-dsi-phy-3nm`** 兼容串 ⇒ 跨代同显示块。
   - 社区侧：`sm8750-mainline/linux`（v6.16 基，OnePlus 13 WIP）、`renhiyama/pagani-linux`（7.1，display/touch/ath12k 可用）、
     kaanapali-mainline 树（Gen5：Y700 Gen5/TB323FU 已能在 7.3-rc4 起 Linux）；pmOS wiki 有 SM8750 设备页
     （OnePlus 13 `dodge`、13s `pagani`、Ace 6 `ktm`、Xiaomi Pad 8 Pro、Galaxy S25 `pa1q`、RedMagic 10 Pro `slogan`、AYN Odin 3）。

---

## 1. 邮件差量（逐条可核）

| 线程 | 时间 | 谁 | 内容 | 需我方动作 |
|---|---|---|---|---|
| dispcc-sm8750（Q28 RFC） | 10-22 22:52 +0530 | Taniya Das | 反对：复位应在 display 侧；整块复位会闪屏 | 已回（10-23 15:52） |
| 同上 | 10-23 15:52 +0800 | 我方 | 接受意见；提 `msm_mdss_reset()` + `reset_control_bulk()` 方案 + 3 问 + p=0.003 | **等 Taniya 回答 3 问** |
| qcom_battmgr power_now | 10-23 10:13 +0200 | Konrad Dybcio | “Did you try reaching out to the vendor?” | **需决策（联系厂商=外部动作）** |
| [REPORT] NT36536（v1） | 10-13 12:34 +0800 | Pengyu Luo | panel 驱动 OK、DPU 可能不行；双 DSI+双 DSC 上游可做但会被 DPU 拖；需 10-bit C-PHY clk-src hack | 已回复/无新问 |
| [REPORT v2] | 10-15 12:21Z | 我方 | 更正口径：-110 不是不变量；闩锁/modeset 都不是杠杆 | 0 回复（可考虑 ping 一次） |
| M1 / M3-1 USB v3 | — | — | 无新回复 | 等 -rc1 |

复现：`read-mail-ustc.py --days 2 --grep dispcc`、`--grep NT36536`；`fetchbody.py INBOX <uid>`。

## 2. 同 SoC 参考面对我们的直接用处

1. **DT 归口风险（最急）**：上游正在评审的文件路径/文件名与我们**完全相同**（`sm8750-lenovo-elden.dts`）。
   我们现在 3178 行、他 1170 行；若上游 v3 落地，我们的树必须以他为基做 delta，否则将来提交必冲突。
   Konrad 对 v2 的评审意见已可先吸收：① 删 `downstream supported features` 段（对上游树无意义）② `dr_mode`/`maximum-speed` 不该写
   ③ 解释 `CDT` 是什么 ④ 两个 USB-C 口是否只能二选一（中间有无 hub）。
2. **“面板黑”的另一类根因**：nt37801 的 VDDI 欠压先例 ⇒ 我们应把 **NT36536 的 VDDI/VSP/VSN 规格与 elden.dts 实际值对齐**
   （现有 `vreg_1v8_vddio=1.8 V`、`vsp=6.1 V`、`vsn=5.8 V`，与 Pengyu 上游 DT 同值），这是**零设备成本**的静态核对，
   补上 Q28 目前只查 DSI/dispcc、没查面板供电的空白。
3. **DPU 侧缺口**（Pengyu）：双 DSI + 双 DSC + 10-bit C-PHY 的 **clk source select** 上游未完整；与 Krzysztof 的
   “MTP 仍然黑屏”同向 ⇒ 我们的 0155（PHY `DIGTOP_PWRDN_B`）与 0154（BCR 复位）都是 DSI 侧，**DPU/INTF 侧可能还有第二个洞**。
4. **可复用资产**：`sm8750-mainline/linux`、`renhiyama/pagani-linux`（同级 SM8750 且 display/touch/ath12k 可用）、
   kaanapali-mainline（Gen5 同显示块），以及 Qualcomm 的 Debian-on-SM8750 演示流程（ramdisk + Debian rootfs + `fastboot boot`，与我们同构）。

## 3. 下一步（建议，未执行）

1. 回 Konrad：说明无下游内核源码（只有 prebuilt boot.img + 提取 config），并把“联系厂商”这一决策交用户。
2. 静态核对 NT36536 供电三路 vs spec（主机侧，0 设备）。
3. 与 Pengyu 对齐 `sm8750-lenovo-elden.dts` 归口（他手里有 TB321FU/TB322FC 系 downstream 提交清单，可能握有下游源码）。
4. Q28 下一个实验优先 **DPU/INTF 侧**变量（顺着 Pengyu 的 clk-src 提示），而不是继续在 DSI PHY 上加补丁。

---

## 4. 顺带做的静态核对（主机侧，0 成本，已做）

`build/m1-73/.../sm8750-lenovo-elden.dts` 面板节点：

```
panel0: panel@0 { compatible = "csot,pp8807hb1-1", "novatek,nt36536";
    vddio-supply = <&vreg_1v8_vddio>;   /* fixed 1.800 V, GPIO tlmm161, always-on/boot-on */
    vsp-supply   = <&vreg_6v1_vsp>;     /* fixed 6.100 V, GPIO tlmm72,  always-on/boot-on */
    vsn-supply   = <&vreg_5v8_vsn>;     /* fixed 5.800 V, GPIO tlmm73,  always-on/boot-on */
    reset-gpios  = <&tlmm 98 GPIO_ACTIVE_LOW>; }
```

- 三路电压值本身与 Pengyu 的上游 v2 DT 一致（1.8 / 6.1 / 5.8 V）；VDDI 1.8 V 落在 NT37801 那类
  “VDDI 1.65–1.95 V”窗口内 ⇒ **不是 nt37801 那种欠压型**，该项先例只能当“同类故障存在”参考，不能直接套结论。
- 但三路都是 **`regulator-fixed` + `always-on` + `boot-on`**：**面板驱动无法在 prepare 里控制上电/掉电顺序**，
  时序实际由 bootloader/常开策略决定。若 Q28 后续要验证“上电序列”假设，改动面 = 把供电交给 regulator 消费者
  （去掉 always-on）或在 panel prepare/ unprepare 中显式拉这三路 GPIO，并用示波器/面板电流确认 —— 属新实验线，未开工。
