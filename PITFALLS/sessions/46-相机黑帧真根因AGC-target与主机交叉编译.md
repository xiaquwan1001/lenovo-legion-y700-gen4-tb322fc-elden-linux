# 四十六、相机「黑帧」真根因 = AGC exposureTarget 不可达；并附主机交叉编译管线与两个抓帧陷阱（#323–#327）

> 本节**推翻 §45 #322**（「libcrypto 构建导致黑帧」）。
> 详细报告：`reports/camera-linux-vk127-20261018-agc-rootcause.md`；
> 补丁与配方：`patches/camera-agc-rootcause-20261018/`。

| # | 教训 |
|---|---|
| **#323** | **`exposureTarget` 有不可达下限。** `ipa: simple: agc` 的 MSV 由 5 个 bin 加权平均得出，**必然落在 `[1,5]`**；判决用 `optimal = target×5` 与滞回 `±0.2`。若 `target ≤ 0.24`，第 1 帧 `MSV=1` 已落在带内 ⇒ **上下两支都不动作，曝光冻结在起始值** ⇒ 恒黑。实测同一二进制、固定起点 `exp=256 gain=1`：target 0.22/0.24 ⇒ 1500 帧 `exp` 一动不动、末帧 mean **0.0**；target 0.30 ⇒ `281→372→…→3174` 爬满、mean 11.4。**改 tuning 文件即可，无需改代码**；代码兜底把 target 夹到 `(1+2×0.2)/5 = 0.28` 并 WARN。 |
| **#324** | **推翻 #322 的方法论教训：只变一个变量，且要变的是"可疑的那一维"。** #322 把"系统包 vs 自编包"当唯一变量，但两臂都在 `target=0.22` 配方下跑过（那次调目标值改动未记录），于是把「构建方式」误判成因果。**平台/构建差异类假设，必须先在同一配方下证明两臂结论不同**。本次反证：Alpine 原版（libcrypto）在 0.30 下正常出图；自编无 libcrypto 在 0.22 下同样黑帧 ⇒ libcrypto/IPA 隔离**对出图无因果作用**。 |
| **#325** | **主机交叉编译 aarch64-musl（Alpine）的三件套**：① GNU ld 2.37 读不了 Alpine 的 **`.relr.dyn`** ⇒ `-B/tmp/lldbin`（`ld`→`ld.lld` 软链）或直接 clang+lld；② `pkg-config` 与 `PKG_CONFIG_LIBDIR` 必须指向**设备 sysroot 的 `.pc`**，否则静默链上主机 x86 库；③ 头文件用 `-idirafter` 而非 `-isystem`，让工具链 musl 头优先。本机 **28 核全量 ≈ 10 s**（release），对比平板 `-j4` 的 4–6 min。 |
| **#326** | **`cam -cN` 的编号与 `cam --list` 的编号不一致。** 列表按 DT 顺序给（1=后摄 `camera@56`、2=前摄 `camera@31`），但 `cam -c1` 实际打开**前摄**、`-c2` 才是**后摄**。前后摄对比实验若按 `-c1/-c2` 记标签会整体张冠李戴 ⇒ **一律用完整 camera id**。 |
| **#327** | **设备 `/tmp` 是 7.3 G tmpfs。** 1280×720 ABGR 每帧 3.7 MB，`-C500` 即写满；写满后抓到的帧全是 **0 字节**（或半写），会被判成"黑帧/ISP 不写"。抓帧写 `/var/tmp`，并**在判图前先查 `ls -la` 的尺寸**。 |
