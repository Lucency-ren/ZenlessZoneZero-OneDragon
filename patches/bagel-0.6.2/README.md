# 贝果插件本地补丁（bagel 0.6.2）

这组补丁修的是「贝果计划」插件在 0.6.2 上跑起来会踩到的几个坑。插件目录
`plugins/bagel` 被 `.gitignore` 排除、而且插件市场会在启动时覆盖它，所以补丁
以 diff 形式存在这里，插件升级后重新 apply 一次即可。

## 内容

| 文件 | 改动 |
| --- | --- |
| `app.py` | 阵亡局不计入连续失败（`_is_death_round()` 认「贝果撤离失败」与结算页 DEFEAT），连续阵亡上限放宽到失败上限的 2 倍；推送内容追加「路线统计」段（`_route_push_text()`）；连续失败达上限时先关游戏重开再跑（`_restart_game_after_limit()`：关闭游戏 → `OpenGame` → `EnterGame` → 清零连续失败/阵亡/各路线计数） |
| `config.py` | 新增 `restart_game_on_fail_limit`（默认开）与 `fail_limit_restarts`（默认 3，0 表示不限）两个配置项及启动校验；新增 `overlay_opacity`（0~100，默认 70）控制运行悬浮窗底色不透明度 |
| `gui/setting_interface.py` | 设置页新增「连续失败后重开游戏」开关与「达到上限时最多重开游戏 N 次」输入框；新增「运行悬浮窗底色不透明度」输入框，并在打开路线编辑器时把该值注入 |
| `gui/run_overlay.py` | 文本面板底色由固定 `QColor(0,0,0,190)` 改为可按百分比设置（`set_backdrop_opacity()`），0 只留文字、100 纯黑不透明 |
| `gui/route_web_editor.py` | 新增 `set_overlay_opacity()`，创建运行悬浮窗时按设置页传入的百分比初始化底色 |
| `stats.py` | 新增 `OUTCOME_DEFEATED = '阵亡局'`，汇总与推送里单独统计阵亡 |
| `route/route_stats.py` | 新增 `push_lines()` / `_push_spawn_text()`：按出生点输出「打了 N 局 · 成功率 X% · 阵亡 n · 每局收益」，超过 12 条自动收尾 |
| `route/input_worker.py` | 转向校准由「0.05 宽峰值槽投票」改为「9 个样本取中位数 + 单样本最多变化 1.25 倍」；校准值上限 2.5、离群要连续 8 笔才放行、校准只用 ≥40° 的命令、跨局可信值限定 0.5~2.0；贴墙时朝向读数跳变的样本直接丢弃 |
| `route/route_walker.py` | 失焦宽限：5 秒内等回前台、5~180 秒只暂停并每 10 秒记日志、超 180 秒才停机；前台判定改为比较根窗口（`GetAncestor(GA_ROOT)`）。朝向读数平滑 `_smooth_angle()`：≥110° 的跳变要连续 4 帧一致才采纳；停车等转 3 秒没进展就盲走一小步 `_maybe_blind_walk()`，单点最多 6 次 |
| `route/route_recorder.py` | `is_foreground()` 同步改为根窗口比较，空句柄与拿不到前台句柄都按前台处理 |

## 重新应用

插件升级（或重装）后，在实例根目录执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File patches\apply-bagel-patches.ps1
```

脚本会核对 `plugins/bagel/plugin.json` 的版本是否仍是 0.6.2，再 `git apply`
本目录里的 diff，最后用实例虚拟环境的 Python 做一次 `py_compile`。版本已经变了
就说明补丁需要重做，脚本会直接退出，不做任何修改。

手工等价操作：

```powershell
cd plugins\bagel
git apply --check ..\..\patches\bagel-0.6.2\0001-bagel-0.6.2-local.patch
git apply         ..\..\patches\bagel-0.6.2\0001-bagel-0.6.2-local.patch
```

确认补丁与当前目录是否一致（0 表示完全一致，说明补丁已经在里面）：

```powershell
git apply --reverse --check ..\..\patches\bagel-0.6.2\0001-bagel-0.6.2-local.patch
```

## 配套的实例配置

这些补丁要配合下面两处配置才不会被自动更新冲掉（`config/env.yml` 与
`config/plugin_subscription.yml` 都不在版本库里，换机器要一起带）：

- `config/env.yml`：`auto_update_code: false`、`force_update: false`、
  `plugin_update_notify: false`
- `config/plugin_subscription.yml`：贝果那一项的 `mute_update: true`

## 主程序侧的一处补丁

`src/one_dragon/base/controller/pc_game_window.py` 的 `is_win_active()` 改成
先取窗口再 `try: return win.isActive`，避免 pygetwindow 在前台是开始菜单 /
任务视图时抛 `Error code from Windows: 1400 - 无效的窗口句柄`，导致 Overlay
跟随窗口反复报错。这一处是版本库跟踪的文件，已随提交一起入库。
