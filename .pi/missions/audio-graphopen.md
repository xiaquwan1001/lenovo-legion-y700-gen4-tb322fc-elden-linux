# 任务（已收官，墓碑）：打通 APM_CMD_GRAPH_OPEN

**本任务书不再执行。** 原阻塞 `APM_CMD_GRAPH_OPEN status=1` 已于 2026-10-04 解决：真根因不在内核 Graph Open 报文（本树与 linux-piano PR#16 逐字节同构，「缺 43 commit」假设被证伪），而是 **tplg 设备子图 MI2S SD 线错（SD0→SD1）**；vk43 修后真机听声 ✅（`TASKS.md` G1-4 ✅）。

- 根因链与取证：`archive/topics/AUDIO-SDLINE-2026-10-04.md`（前史 `AUDIO-2026-09-30/10-01/10-02.md` 同目录）。
- 音频残余工作（R1 耳麦 / R2 双麦）：见 `.pi/missions/audio.md`。
