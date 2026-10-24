# manifest 的 `kernel_release_matches_image` 会被尾部 `+` 误判（#384）

> 日期：2026-10-24 · 场景：Gunyah 实验镜像 `out/boot-elden-gunyah1.img` 的 manifest 报 `kernel_release_matches_image=no`。

## 现象

```
kernel_release=7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty+     ← make -s kernelrelease 的查询值
kernel_uts=Linux version 7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty
kernel_release_matches_image=no
```

但**镜像本身是对的**：`vmlinux` / `Image.gz` 里 `linux_banner` 与模块 `vermagic` 都是**不带 `+`** 的那串，
模块可在该镜像上正常加载。

## 根因

`scripts/build-manifest.sh` 用 `make -s kernelrelease` 取 `KV`（查询时的环境里没有显式 `LOCALVERSION=`），
而 `scripts/setlocalversion` 在**工作树 dirty** 时会补尾部 `+`；真正构建内核时用的是带 `LOCALVERSION=` 的环境（不出 `+`）。
两者只差一个 `+`，但字符串比较是逐字相等 ⇒ 假阴性。

## 修法（已落）

比较前剥掉尾部 `+`，并把原始查询值另存为 `kernel_release_normalized`：

```sh
KV_CMP=${KV%+}
UTS_CMP=${UTS#Linux version }; UTS_CMP=${UTS_CMP%+}
K_MATCH=$([ "$KV_CMP" = "$UTS_CMP" ] && echo yes || echo no)
```

## 纪律

- **看到 `matches_image=no` 先自己从镜像里取 banner 复核**（`zcat Image.gz | strings | grep 'Linux version'`），
  别直接判镜像坏——这个字段是「查询口径」而不是「镜像内容」的直接证据。
- 反之亦然：`matches_image=yes` 也不能替代「模块 vermagic 与在机 UTS 逐字一致」的检查（两者是不同断言）。
- 任何「构建 → 打包 → manifest」里出现两次独立推导同一事实的地方，都要按同一条口径取数（本例：都用 `LOCALVERSION=` 的环境）。
