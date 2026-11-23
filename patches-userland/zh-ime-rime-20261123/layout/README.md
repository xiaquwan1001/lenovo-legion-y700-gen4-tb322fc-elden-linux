# 方向键现状与最小布局补丁（phosh-osk-stub 0.46，2026-11-23）

## 1. 现状（源码核实，2026-11-23 本机 /tmp/osks/phosh-osk-stub-0.46.0）

- **方向键四键：驱动侧已支持、布局侧全缺失。**
  - 驱动：`KEY_LEFT/RIGHT/UP/DOWN` 在符号表 `keycodes_common[]`（`src/pos-vk-driver.c:54-57`），
    走 `zwp_virtual_keyboard_v1.key()`（evdev 4 键码），任何布局里写 `"symbol": "KEY_LEFT"` 即可用；
  - 布局：`src/layouts/` 55 个 json 里 grep `KEY_LEFT|KEY_UP|Home|End|Page` = **0 命中**——
    包括 terminal.json（唯一「终端」布局，4 个 level：默认/大写锁/数字/符号+F 键）。
    用户现在要在 shell 里移动光标，只能点文本让客户端自己处理，键盘面上没有方向键。
- **Home/End：驱动侧半缺失。** evdev 转换的 case 列表里有 `KEY_HOME`/`KEY_END`
  （`pos-vk-driver.c:277,281`，那是 electron 合法性过滤用的），但 `keycodes_common[]`
  **没有** `"KEY_HOME"/"KEY_END"` 符号条目 ⇒ 布局里写了也不映射。
- 切换方式（无补丁也能用方向键的唯一现路径）：terminal 布局 level 2/3 是 `mode: locked`
  （shift 键切 lock，`us.json` 同构）——即补丁把方向键放 level 3 后，用户点 shift 两次锁大写
  即进入符号+F 键层。无需新 UI 开关。

## 2. 补丁（见同目录 0002-osk-stub-terminal-arrows.patch）

两个文件、共 ~15 行：

1. `src/layouts/terminal.json`：level 3（locked，F 键层）第 4 行
   `["<",">"," ",",","."]` → `["←","↑","↓","→"," "]`（symbol=KEY_LEFT/UP/DOWN/RIGHT）。
   `<`/`>` 在 level 2 与 F 层第 2 行都有等价替代（`| ¢ € ¥ ^ ° = { }` 行和数字层），不丢符号。
2. `src/pos-vk-driver.c`：`keycodes_common[]` 尾部补 2 条
   `{ "KEY_HOME", KEY_HOME, NONE }`、`{ "KEY_END", KEY_END, NONE }`，
   并在 terminal.json F 层第 2 行尾补 `⇱/⇲`（symbol=KEY_HOME/KEY_END）。

风险：全 0——两条 keycode 条目是纯查表追加，不触碰任何现有映射；terminal.json 只被
`pos-input-surface.c` 的 set_keymap() 按布局 id 加载，其它布局不受影响。
需重编（布局 json 编进 gresource，`src/phosh-osk-stub.gresources.xml`），部署走与 haptic
相同的 divert+hold 路径（haptic/README.md §2 第 2-3 步）。
