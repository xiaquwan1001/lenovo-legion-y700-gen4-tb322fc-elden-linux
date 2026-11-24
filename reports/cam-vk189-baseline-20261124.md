# G1-5 相机基线复测（vk189 日常核，2026-11-24 设备窗轮）

> 目的：2026-11-19 重建根之后，**没有任何一轮重新证明过「日常核上两摄还能出流」**。
> 本轮补上这条基线（也顺手把 `v4l-utils` 装回根里——重建根后它丢了）。
> 设备：TB322FC / `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0` / 根 `/dev/sda17` / 相机栈**当前已在位**
> （`qcom_camss` 696320 B + `s5kjns` + `gc08a8` + `gt9764` + `v4l2_fwnode` 全 bound，`/dev/video0..16`）。

## 0. 结论（数字先行）

| 判据 | 前摄 `gc08a8` | 后摄 `s5kjns` | 判读 |
|---|---|---|---|
| 链路配置 | `msm_csiphy4 → msm_csid0 → msm_vfe0_rdi0 → /dev/video0`，`SRGGB10_1X10 3264x2448` | `msm_csiphy3 → msm_csid1 → msm_vfe1_rdi0 → /dev/video3`，`SGRBG10_1X10 4080x3072` | 与 2026-10-09/10-18 同一拓扑 |
| 10 帧 mmap | `rc=0`（`<<<<<<<<<<`） | `rc=0` | 出流成立 |
| **速率（60 帧实测）** | **27.52 fps** | **27.58 fps** | 有效 30 fps 档（用户态拷贝开销内） |
| 单帧统计（RAW10 解包后逐像素） | `min 62 / max 1023 / mean 99.3 / std 156.1 / distinct **892**` | `min 0 / max 1023 / mean 85.1 / std 128.2 / distinct **681**` | **非黑帧、非常数帧**（distinct 数百级 = 真实场景） |
| dmesg 中 camss/vfe/csiphy/EPIPE/EINVAL 命中 | 全机 **1** 条（与本轮测试无关的历史噪声） | 同 | 零新增错误 |

**判据结论：G1-5 在 vk189 日常核上仍然成立**（出流 + 满帧 + 零错误）。这不是「新功能」，是**基线复核**。

## 1. 复跑命令

```sh
# 设备侧前提（重建根后必查）
apt-get install -y --no-install-recommends v4l-utils     # media-ctl / v4l2-ctl，本轮现装 1.30.1-1
sh /tmp/camera-stream-up.sh front stream 10              # 主机 scp scripts/camera-stream-up.sh 到 /tmp
sh /tmp/camera-stream-up.sh rear  stream 10

# 速率
S=$(date +%s.%N); v4l2-ctl -d /dev/video3 --stream-mmap --stream-count=60 >/dev/null 2>&1; E=$(date +%s.%N)
awk -v s=$S -v e=$E 'BEGIN{printf "%.2f fps\n", 60/(e-s)}'

# 单帧取证（主机侧解包统计）
v4l2-ctl -d /dev/video0 --stream-mmap --stream-count=1 --stream-to=/tmp/front.raw
```

主机侧统计脚本要点：**载荷是 MIPI RAW10 打包**（5 字节 4 像素），
`bytes == w*h*10/8` 才对得上（前摄 9 987 840 B ✔）；直接按 `uint16` 读会得到 `0.625×` 的样本数并 reshape 失败（本轮踩过）。

## 2. 对 camss 上游系列的意义（把话说清楚，避免误用）

`patches/upstream/camss-csiphy-24-v2-20261117/` 缺的那次「上机出流回归」，**本轮仍不能算做掉**：
该系列基线 = `7.4-rc3 aebb727447 + kaanapali v25[01..03]`，而在机 vk189 是 **7.3.1 日常线、且不含这两枚补丁**。
在 vk189 上跑通只能证明「日常线的 CSIPHY 配置不坏」，**不能**写成「补丁已验证」——那样等于把未测说成已测。
本轮产出的正当用途 = **回归对照基线**：若将来在含补丁的核上测，任何退化都可与这张表（27.5 fps / distinct 892·681）对照。

## 3. 证据件

- `reports/artifacts/cam-vk189-20261124/front.raw`（9 987 840 B）、`rear.raw`（15 679 488 B，比理论多 12 288 B = 尾行填充）
- 原始 ssh 输出：`logs/cam-vk189-20261124/`（`stream-config.txt` / `fps.txt`）
- 拓扑脚本：`scripts/camera-stream-up.sh`（按驱动名+芯片地址运行时解析 entity，不写 I2C 总线号）
