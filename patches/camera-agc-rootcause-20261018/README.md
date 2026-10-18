# AGC exposureTarget 下限 —— 软 ISP「黑帧」真根因（2026-10-18 晚）

## 一句话

`ipa: simple: agc` 的 MSV 只有 5 个 bin（取值 1..5），
**`exposureTarget`（分数）必须 ≥ 约 0.28 才可达**；
把它设成 0.22 会让环路在**第 1 帧**就判定"已达标"从而**永不增加曝光** ⇒ 输出恒黑。
先前记的「libcrypto 构建导致黑帧」是**误判**（见 §3）。

## 数据

固定起点 `exposure=256, gain=1`（冷起），同一二进制，只改 tuning 文件：

| `exposureTarget` | AGC 收敛过程 | 末帧 mean / max |
|---|---|---|
| 0.22 | `exp 256 again 0.03` 1500 帧不变 | **0.0 / 0** |
| 0.24 | 同上 | 0.0 / 0 |
| 0.30 | `281→372→493→655→871→1158→1540→2049→2725→3174` | 11.4 / 31 |

原因（`agc.cpp`）：MSV 由 `kExposureBinsCount`=5 个 bin 的加权平均得出，
数学上落在 `[1,5]`；而 `optimal = exposureTarget * 5`。
若 `optimal + kExposureSatisfactory(0.2) <= 1`（即 target ≤ 0.24），
第 1 帧 `exposureMSV = 1` 就落在滞回带内 ⇒ 上下两支都不动作 ⇒ 曝光永不改变。
0.30 对应 `optimal=1.5`，需要 `MSV>=1.7` 才能满足，因此会一路爬升。

## 修法（两个层次，任选）

1. **纯 tuning（无需改代码，立即生效）**：`exposureTarget: 0.30`（或 0.28–0.35）。
   本树 `s5kjns.yaml` / `gc08a8.yaml` 应使用该值。
2. **代码防御**（本目录 patch）：在 `Agc::init()` 里把 `exposureTarget` 夹到可达下限
   `(1 + 2*kExposureSatisfactory) / kExposureBinsCount = 0.28`，并打 WARN。
   这样旧 tuning 文件（0.22）不会静默黑屏。

## ⚠ 训练警告：先前"libcrypto"结论已推翻

`reports/camera-linux-vk127-20261018.md` §7 与 `PITFALLS #322` 记的
「启用 libcrypto 的 libcamera 构建 ⇒ 软 ISP 黑帧」**是错的**。

- Alpine 原版包（libcrypto、签名 IPA）+ `exposureTarget: 0.30` ⇒ **能出图**（上面数据）。
- 自编「无 libcrypto」构建 + `exposureTarget: 0.22` ⇒ **同样黑帧**。
- 两构建在 `0.30` 下表现**一致**。

当时的错误来自：两种构建都是在 0.22 配方下测的，同时把"设备上系统包 vs 自编包"
当成了唯一变量，且**没有做 target 这一维的对照**。原 §7 的"pristine 构建出图"
实际上是那次会话里 tuning 文件被临时改过、未记录。

⇒ libcrypto / IPA 隔离对出图**无因果作用**（可留作性能/签名的独立话题，但不是黑帧根因）。

## 复现 / 验收

```sh
# 起点固定，排除 AE 历史
v4l2-ctl -d /dev/v4l-subdev28 -c exposure=256,analogue_gain=1
sed -i 's/exposureTarget: .*/exposureTarget: 0.30/' /usr/share/libcamera/ipa/simple/s5kjns.yaml
cam -c /base/soc@0/cci@ac7b000/i2c-bus@0/camera@56 -C250 -s width=1280,height=720 --file='/var/tmp/f_#.bin'
# 期望：后续帧 mean 单调上升到 ~10–160（取决于场景），max > 30；不是恒 0
```

## 另外两条独立坑（同日实测，与黑帧无关）

- **`cam -c2` 的编号和 `--list` 的编号不一致**：列表按 DT 顺序把后摄排 1、前摄排 2，
  但 `cam -c1` 实际打开的是 **front**（`camera@31`），`-c2` 才是 **rear**（`camera@56`）。
  用**完整 camera id**（`-c /base/.../camera@56`）避免歧义。
- **/tmp 是 7.3 G tmpfs**：1280×720×ABGR 每帧 3.7 MB，`-C500` 就写满 ⇒
  之后的抓帧全是 0 字节文件，会被误读成"黑帧"。抓帧一律写到 **/var/tmp**。
