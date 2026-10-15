# B1 首样本诊断：缺口是「没人请求重试」（2026-10-15）

> 证据：`logs/b1-sampling-20261015/b1-s1/`（dmesg 全量）、trial
> `reports/trials/20261015T120428Z-b1-recoverable-s1-dark.json`。
> 用户目视确认：黑屏 + **电源键不能控背光**（= B 型亚型，与 baseline s4/s6 同类）。

---

## 0. 一句话

**B1 的两处改动都按设计生效了，但面板依然黑** —— 因为
**「让失败非致命」是必要条件、不是充分条件**：整条链路里**没有任何一方会去重走 modeset**。
这正好把方案 B 的剩余工作面（B3）暴露出来。

---

## 1. 铁证：B1 (a) 生效、闩锁未置位

```
[12.243559] msm_dsi ae94000.dsi: bonded command DMA failed: master=-110 peer=-110
[12.243564] dsi: bonded command failure 1/3 (command DMA timeout), will retry   ← B1 新增日志
[12.243569] panel-novatek-nt36536 ae94000.dsi.0: sending dcs data ff 20 failed: -110
[12.243576] panel-novatek-nt36536 ae94000.dsi.0: Failed to initialize panel: -110
[12.243681] msm_dsi ae94000.dsi: panel is not prepared; refusing video enable
[12.243690] dsi: bonded command failure 2/3 (panel not prepared), will retry     ← 第 2 次，仍未耗尽
（全 boot 无 "giving up"）
```

⇒ `dsi_bonded_cmd_failed` **从未被置位**（预算 3，只用了 2）⇒ **(a) 有界重试正确工作**。
⇒ 与 baseline 的差别：baseline 此处会一次性闩死；B1 不会。

## 2. 但**没有任何第二次尝试**

| 量 | 值 | 含义 |
|---|---|---|
| `Failed to initialize panel` 出现次数 | **1** | panel init 只跑过一次 |
| `panel prepared` 出现次数 | **0** | 从未成功 |
| 「重走 modeset」迹象 | **无** | 没有第二次 atomic commit |

DRM 在失败后**自行放弃**（而不是等重试）：
```
[13.713538] hw recovery is not complete for ctl:1        ← 192 次（= reset failure 次数）
[13.713986] [drm:dpu_encoder_phys_vid_prepare_for_kickoff:576] enc35 intf1 ctl 1 reset failure: -22
[13.765808] [drm:dpu_encoder_frame_done_timeout:2762] enc35 frame done timeout
```
`hw recovery is not complete` 出处 = `dpu_hw_ctl.c:459`（`dpu_hw_ctl_poll_reset_status` 超时，返回 `-EINVAL`）
⇒ **DPU CTL 的软复位永远完不成** ⇒ kickoff 持续 `-22`。

## 3. 结论：缺口精确定位在「调用方」

**为什么没有重试**（代码层面）：
- `drm_panel_prepare()` 由 **DRM panel bridge 框架**在 **atomic commit** 里调用一次；
- panel init 失败后，**没有新的 atomic commit 被发起**；
- B1 只解开了「闩锁」这个**守卫**，但**守卫后面本来就没有重试循环**。

⇒ **B1 不是错的设计，但它单独不足以恢复。** 需要补上「谁发起重试」。

## 4. 下一步：B3 的两个候选形态

| 形态 | 做法 | 风险/成本 |
|---|---|---|
| **B3-a（内核内）** | panel `prepare` 失败时**不返回致命错**，而是让 bridge 层把该 CRTC 标记为「需重试」，由 DPU/DRM 的 **error worker** 重发一次 commit | 需改 DRM 语义；`PITFALLS #106`（重试循环卡死）风险要高守卫 |
| **B3-b（用户态）** | panel init 失败 ⇒ **不置 DRM 模式**，由用户态（phoc/greetd 重启、或 udev 规则）触发第二次 modeset | 轻量；但「重走 modeset ≡ 冷启」已由 P1 证明**安全**（在 GOOD 台上），**是否等价于冷启仍需在坏发台上验** |

**★ B3-b 更符合项目现状**：`PITFALLS #253` 已记「显示坏态下 `reboot` 会卡 DRM cleanup，
可靠恢复 = `sysrq-b`」；而**重启 phoc 会话**（非整机）正是我们 P1 实测安全操作
⇒ 可立刻做「坏发台上重启 phoc，看面板是否点亮」的**零构建实验**。

## 5. 关联既有结论

- **arm A（`reports/q28-armA-20261015.md`）**：证明「`-110` 与面板黑可分离」。
  本样本**再次**印证：B1 让 `-110` 不再致命，**面板仍黑**。
- **`PITFALLS #275`**：本发软件侧又是「假 GOOD」（`card0-DSI-1 connected` + session 起来 +
  `backlight=160`），**只有用户目视抓住了它**。
- **B 型亚型**：本发「电源键不能控背光」⇒ 与 baseline 坏发同亚型；
  说明 **B1 没有改变故障亚型**（至少本样本如此）。
