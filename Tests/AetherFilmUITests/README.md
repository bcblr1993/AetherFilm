# AetherFilm UI regression

共享 XCUITest 文件分别加入 macOS 和 iOS 的 UI test target，测试语言固定为中文。macOS 自动化只能在 Tart `macos27` 虚拟机运行；脚本会拒绝宿主 Mac。iOS 必须传入明确的模拟器或设备 destination。

```sh
scripts/test_ui.sh macOS
scripts/test_ui.sh iOS 'platform=iOS Simulator,id=SIMULATOR_UUID'
```

物理 iPhone 运行时传入已授权设备 UUID，并设置 `AETHERFILM_UI_SIGNING=YES`。产物默认写入 `build/ui-results/`，包含日志、独立 `.xcresult` 和截图 attachments；可通过 `AETHERFILM_UI_RESULTS` 指定目录。截图需要逐张检查布局，测试通过不代表已完成视觉验收。

## DEBUG fixture contract

- `--ui-testing`：启用隔离测试模式，禁止读写真实影片列表、真实 NAS 登录信息和钥匙串。
- `--ui-test-session=<UUID>`：每个 test case 独立目录；同一 case 重启应用使用同一目录，以验证持久化。
- `--ui-empty`：空片源和空播放记录。
- `--ui-fixtures`：两部可实际解码的本地 MP4 / MKV；脚本生成每部 30 秒的自建样片。
- `--ui-source-error`：选择虚拟 NAS；首次与重试都会经过 2 秒加载，再返回安全的错误文案。
- `--ui-source-fixtures`：选择固定 UUID `33CCCCCC-4444-5555-8888-AAAABBBBCCCC` 的虚拟 NAS，根目录包含 `Movies` 文件夹，`Movies` 中包含 `Empty` 空文件夹。
- `--ui-appearance=light|dark`、`--ui-width=620`、`--ui-height=440`：外观和最小 macOS 窗口验证。
- `--ui-content-size=accessibility3`：大字体布局验证。

减少透明度测试读取实际系统状态（macOS 的 `NSWorkspace`、iOS 的 `UIAccessibility`）。未启用时会明确标记 skipped；需要在虚拟机或测试设备启用系统设置后单独运行此 case，并保存 / 恢复原设置。启动参数不能替代这个验收条件。

在专用 iOS Simulator 上，可在本轮生成的 `.xctestrun` 的 UI target `EnvironmentVariables` 中设置 `AETHERFILM_UI_CHANGE_ACCESSIBILITY=1`。此可选流程通过原生 Settings 打开 Reduce Transparency，由 `UIAccessibility` 检查实际值，结束后恢复原开关状态；普通运行不修改系统设置。测试播放偏好使用独立 `AetherFilmUITests.<session>` defaults suite。

播放器使用 `player.surface`、`player.close`、`player.playPause`、`player.time`、`player.duration`、`player.error` 等 identifier；`player.time` 的 label 随实际播放时间更新。测试点击实际视频区域唤回自动隐藏的控制层，双击跳转十秒，并检查真实 thumb 按住五秒、播放时自动隐藏、暂停时保持显示。iOS 图标按钮要求实际可访问性 frame 至少 44×44 点。macOS 全屏测试要求实际视频画面占显示器宽高的至少 90%；iOS 会旋转真实模拟器方向，并检查横屏控件仍在屏幕内。

## 覆盖范围

每个平台目前 19 个 case：本地和续播空状态、文件导入入口、SMB 必填 / 端口 / 取消、格式与播放入口、播放时间推进、控制层显示隐藏、倍速 / 播放设置、全屏或横屏、续播和已看持久化、清除记录和移除列表条目、目录失败重试、无法播放视频的错误 / 重试 / 退出、目录进入 / 空目录 / 返回 / 片源切换、列表筛选无结果、浅深色和窄窗口、大字体与减少透明度，以及可访问性描述审计。UI 脚本只运行 UI target；协议和解码测试由各自 runner 独立执行。

实际 NAS 认证、SMB 范围读取、断网和真实 iPhone 解码需要独立集成验收。列表移除后原始文件仍存在，需要在存储集成测试中检查真实文件，UI suite 只检查列表行为。
