# fqapp 电脑版

基于 ch6vip/fqapp 的 `762f0b2`，保留 GPL-3.0 许可证和原作者署名。

## 使用

Windows 10/11 x64：解压完整目录后运行 `fqapp.exe`，不要单独移动 EXE。
也可运行 `fqapp-desktop-<版本>-windows-x64-setup.exe` 安装：支持选择安装目录、
开始菜单/桌面快捷方式及卸载，无需管理员权限。卸载保留当前用户的书架、进度和缓存。
首次启动需联网初始化；已下载的书籍及媒体可从应用内离线入口打开。
数据保存在当前用户的应用数据目录，不依赖解压目录。备份使用原版 JSON 格式。
官方网页导入需要 Microsoft Edge WebView2 Runtime，并由用户在官方网页完成登录。
系统朗读使用已安装的 Windows 语音；缺少中文音色时在系统语音设置中安装。

播放器：空格播放/暂停，左右键快退/快进 10 秒，上下键音量，F 全屏，Esc 退出全屏。
推荐流 Page Up/Page Down 切换上一条/下一条。竖片完整显示，两侧留边。
阅读器使用滚轮、方向键或 Page Up/Page Down，宽窗口提供可搜索的侧边目录。
最小化后按后台播放设置继续播放，关闭窗口保存进度并退出。

### 透明小窗阅读

在小说阅读菜单中点击「小窗阅读」图标进入。拖动顶部章节名移动窗口，拖动窗口边缘缩放；
顶部提供置顶、鼠标移开时隐身、设置和恢复正常阅读按钮。鼠标移开后工具栏自动淡出。
设置中可选择深浅预设、调整字号和背景透明度，以及隐藏任务栏图标。背景默认完全透明。
文字颜色、描边颜色与粗细、阴影颜色/强度/模糊/偏移均可单独调整，支持色板和 HEX 调色，实时预览并自动保存。
设置面板采用独立的浅底深字配色，正文调色不会影响菜单文字；文字预览同时提供明暗底色。
小窗设置分为「外观（视频为画面）／窗口／按键」三个页签；窗口绑定和任务栏选项在「窗口」，翻页键与统一快捷键入口在「按键」。
面板顶部关闭按钮始终可见，Esc 关闭面板（录入快捷键时先取消录入）；自定义颜色支持粘贴带 `#` 的 HEX 和回车确认。
开启隐身后，鼠标移到小窗原来的区域会重新显示。打开设置或目录时暂停自动隐身。
分页模式下，滚轮向下翻下一页、向上翻上一页；滚动模式仍连续滚动正文。
小窗获得焦点时可用左右方向键或 Page Up/Page Down 翻页，设置底部可录入自定义翻页键或组合键，自动保存。
设置或目录打开时暂停正文快捷键；录入按键时按 Esc 取消。

默认 `Ctrl+Alt+Q` 为全局老板键：隐藏或恢复小窗，可在快捷键设置中修改或移除。老板键隐藏后不会被鼠标误触恢复，
再次按快捷键显示；恢复后移入、移出窗口才继续自动隐身。快捷键被占用时仍可进入小窗，
只提示老板键不可用，并启用鼠标恢复：临时隐藏后，将鼠标移出再移回小窗原来的区域即可显示。
鼠标恢复不依赖任务栏图标。点击「恢复正常阅读」会还原窗口大小、位置、最大化、置顶和任务栏状态，保留阅读位置。

「绑定应用窗口」可选择已打开的窗口：小窗紧邻目标窗口上方，切换到其他应用时两者均可被覆盖；
目标最小化/恢复时小窗直接隐藏/显示，不播放小窗缩放动画，也不抢焦点。绑定期间暂停独立置顶，解除绑定后恢复原置顶选项。
绑定对象是本次打开的具体窗口，不跟随其移动位置；目标关闭后自动解绑，小窗保留。

### 短剧迷你小窗

短剧推荐流与独立播放页的控制栏均提供「小窗播放」，也可按 `Ctrl+M` 进入。
小窗保留当前播放器和进度，按视频比例显示完整画面，支持拖动标题栏移动、拖动边缘缩放。
底部可播放/暂停、拖动进度、快退、切集、选集、静音和调速；画面上的滚轮切换上一集/下一集。
空格播放/暂停、左右键前后 10 秒、上下键调音量；`Ctrl+M` 或 Esc 恢复正常窗口，F 恢复后全屏。
置顶、鼠标移开隐身、任务栏隐藏、全局老板键和绑定应用窗口沿用阅读小窗的行为。
隐身、老板键隐藏或绑定窗口最小化时暂停视频，恢复时仅继续原本正在播放的视频。
视频不透明度可在小窗设置中调整，窗口偏好与小说小窗分别保存；设置和选集面板保持清晰可读。

### 视频播放工具

普通视频窗口与短剧迷你小窗的「播放工具」按钮提供播放、字幕、收藏三个分区。
鼠标停在进度条上可查看对应时间的缩略图，不改变当前播放位置；首次预览需要读取片源。
长按画面或按住 `L` 临时倍速，松开或切换窗口恢复原速度；工具面板可选择 1.5/2/2.5/3 倍。
夜间声音模式压低突发响声并收窄音量差，开关自动保存。
`Ctrl+B` 添加当前时间书签，可填写备注和台词；收藏卡额外保存当前画面及接下来 5/10/15/30 秒的声音。
「收藏」内可搜索本作品片段、回到对应集数与时间、播放声音、导出 ZIP 和删除。
字幕支持读取片源中的独立字幕轨及导入 UTF-8 SRT/VTT，可搜索台词、点击定位、调整时间偏移或隐藏字幕。
短剧画面内烧录的文字不是独立字幕轨；没有独立字幕时需自行导入字幕，台词也可手动填写。
默认 `Ctrl+Shift+P` 打开工具面板，上述按键都可在统一快捷键设置中修改。
FFmpeg 及其许可证随 Windows 程序打包，使用者无需另装；收藏与导入字幕保存在本机应用数据目录。
Windows 构建使用完整 x86_64 libmpv 20261021-git-e471496c56，首次构建会下载并校验 SHA256，提供夜间音频滤镜。

### 快捷键设置

从「设置 → 快捷键」或小窗设置中的「管理所有快捷键」进入，按通用、小说阅读、小窗、听书、短剧推荐、视频播放分组。
支持修改组合键、添加备用键、移除和逐项恢复默认；同一使用场景下的冲突会提示。
除小窗老板键外，快捷键仅在当前应用及对应页面生效；输入文字、录入快捷键时暂停页面操作。
听书默认空格播放/暂停，左右键前后 15 秒，Page Up/Page Down 切章。

## 构建和验证

需要 Flutter 3.44.6 / Dart 3.12.2、Rust stable、Visual Studio 2022 C++ 桌面工具
（MSVC v143、ATL、CMake、Windows SDK 10.0.26100）、NuGet CLI 和 FFmpeg。
仅安装 SDK 10.0.19041 时，旧版 C++/WinRT 头文件与 C++20 不兼容，会导致 WebView 编译失败。
执行 `pwsh -File scripts/build_windows.ps1 -FlutterRoot <Flutter SDK 路径>`。
原生 DLL 由 Windows CMake 构建自动调用 Cargo 编译；C 解密核心由 Rust build.rs 编译。
构建脚本对中文工作区使用临时英文目录联接，不移动源码。
Flutter 插件需要 Windows 开发者模式或符号链接权限。
普通构建和 Windows CI 使用官方 Flutter SDK，不要求修改 SDK。
若复现 Flutter 3.44.6 在路由/提示层切换时的 Windows 无障碍树崩溃，
可对专用 SDK 显式使用 `-ApplySemanticsBackport`，或单独运行
`scripts/prepare_flutter_windows.ps1`；出处和回归用例见 `scripts/patches/README.md`。
该可选补丁不会关闭无障碍功能，也不会自动修改共享 SDK。
需要安装版时，在 release 构建和许可证收集完成后执行
`pwsh -File scripts/build_windows_installer.ps1 -IsccPath <Inno Setup 的 ISCC.exe 路径>`。

`python scripts/verify_windows_media.py` 使用真实 Windows DLL、FFmpeg 生成的 CENC 夹具，
核对视频和音频逐帧哈希、在线/离线随机 Range、访问限制和会话关闭。
这些离线测试不代表上游在线内容或用户账号导入已通过真实验收。

`dart compile exe scripts/verify_windows_player.dart -o build/verify_windows_player.exe`
后运行 `build/verify_windows_player.exe`，使用与产品一致的 AOT 模式和随包 libmpv，核对加密媒体的 H264 解码尺寸、
播放/暂停/拖动/续播、倍速和静音；该测试不显示视频窗口，窗口及 GPU 呈现需另行实机验收。

`flutter test integration_test/windows_playback_test.dart -d windows --no-pub --dart-define=FQAPP_TEST_MEDIA=<encrypted.mp4 绝对路径>`
会运行真实 Windows 播放页，验证无键盘焦点时的自动起播、连续推进、暂停、进度条拖动与续播。
夹具由上一条原生播放器校验脚本生成；测试不会读取用户的书架进度作为测试数据。

Windows 适配修复可见但未聚焦的窗口被误判为后台、导致只显示首帧的问题，
并保护窗口销毁时的原生回调，避免退出时再次访问已销毁的 Flutter 视图。
`scripts/verify_windows_shutdown.dart` 是独立的退出回归入口，可用
`flutter build windows --debug --target scripts/verify_windows_shutdown.dart --no-pub`
构建后从工作区启动 Debug 程序；它会自动执行正常关闭回调并退出。
退出检查完成后，交付版本须重新使用默认 `lib/main.dart` 入口构建 release。

Android 保留 ExoPlayer；只引用 `media_kit_libs_windows_video`，不打包 Android
libmpv/FFmpeg 原生库。执行 Flutter 测试后构建 Android release 时，须保留 pub
步骤（不要给 `flutter build apk` 加 `--no-pub`），以清除 dev-only 集成测试注册项。
`.github/workflows/windows.yml` 会在相关 PR 中使用未修改的 SDK 构建并验证
桌面布局与原生媒体解密接口；程序包仅作为 Actions artifact 保存。
额外的无界面 libmpv 诊断由手动参数 `verify_player` 显式启用：
目前托管 Windows Server 2025 在释放播放器时持续出现 `0xC0000005`，尚未解决，
不计为通过。本机交互桌面的播放/销毁及窗口集成检查通过，服务端诊断结果单独记录。

## 第三方组件

沿用 Flutter/Rust/C 架构。Windows 播放采用 media_kit/libmpv，系统媒体控制采用 smtc_windows，
文件选择采用 file_selector，系统朗读采用 flutter_tts，窗口管理采用 window_manager。
WebView2 适配器基于 webview_windows 0.4.0，其 MIT 许可和修改说明保存在 third_party/webview_windows。
原项目及第三方许可证随源码/程序一并保留；Flutter 的许可证页面可查看 Dart 依赖许可。
