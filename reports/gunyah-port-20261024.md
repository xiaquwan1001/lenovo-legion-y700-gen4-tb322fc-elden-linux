# Gunyah Linux guest 驱动移植到 7.3-rc7（编译 + 静态审查）

日期：2026-10-24
范围：仅「编译通过 + 静态审查」，**不上机**、不写 boot、不动 build/vk151。
参考源：reference/gunyah-android15-6.6/（6.6/android15 树）
目标树：build/gunyah-port（worktree @ 24223e4，与在机 vk152 构建树 build/vk151 同 HEAD）

## 0. TL;DR

（待填：最终 0 err/0 warn？.ko 数量？vermagic 一致？）

## 1. 环境与 worktree 创建

（待填：命令 + 输出）

## 2. 源码拷贝与挂接（Kconfig/Makefile/Kbuild）

（待填）

## 3. 6.6 → 7.3-rc7 API 漂移适配表

（待填：逐条漂移 + 解法）

## 4. 构建配方与结果

（待填：命令、输出尾部、0 err/0 warn 证明）

## 5. .ko 清单（sha256 + vermagic）

（待填）

## 6. 静态审查与就绪度清单

- 现在就能跑（不依赖 DT capid）：
  - （待填 3 个验证点）
- 必须等 DT capid 节点：
  - （待填）

## 7. DT 需求（对照 gunyah-dt-capid-20261024.md 实测）

（待填）

## 8. 上机计划与回退

（待填）

## 9. 失败 / 未证实项

（待填；若空则记「无」）
