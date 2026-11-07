# 更新日志

## v1.3.0 · 2026-11-07（本 Fork）

### 新增

- 按键支持手势级映射：单击 / 双击 / 长按各自可配置不同目标（对应 SayAll 的 `doubleClick` / `longPress` 能力）。
- 新增「打开 App…」目标，可选 `/Applications` 下的应用，按 bundle id 启动。
- 映射行增加手势选择器；自定义组合键与打开 App 按手势分别保存。

### 行为

- 只有显式配置了双击或长按的按键才进入手势判定；其余按键保持原来的即时按下 / 松开，因此方向键零延迟、按住仍可重复。
- 双击窗口 0.28 秒，长按阈值 0.60 秒；未配置的手势回落到单击映射。

## v1.2.2 · 2026-11-07（本 Fork）

### 变更

- 按下未内置的按键时打印 `[CAST-MAP] 未知按键 usage=XX`，便于真机补齐映射表。
- 新增 [docs/VERIFY-CHECKLIST.md](docs/VERIFY-CHECKLIST.md)：安装、日志关键字、usage 表、回退验证与排查步骤。

## v1.2.1 · 2026-11-07（本 Fork）

### 变更

- 音频输入改为「遥控器麦优先」：遥控器有音频流时只输出遥控器音频，不再与本地麦等权叠加，避免双讲造成的梳状滤波与底噪叠加。
- 遥控器断开或没有音频流时自动回退本地麦克风，虚拟设备不再输出纯静音，避免会议软件等其它 App 失声。
- 本地麦克风选择从「只认内置麦」扩展为「内置麦 → 任意非虚拟输入设备」，并排除 `vRemoteDr` / `MiRemoteV` / `BlackHole` / `Parrot` 等回环设备，防止回退进入自身。
- 遥控器优先期间本地麦只保留最近 0.25 秒缓冲，回退接近实时；仅在双路同时有流时保留 120 ms 对齐延迟。
- 界面文案由「参与混合 / 两路已合并」改为「参与输入 / 遥控器优先 · 断开回退」。

## v1.2.0 · 2026-11-07（本 Fork）

### 修复

- 修复 macOS 26 上 Chromecast Voice Remote 按键映射全部失效的问题（原仓库 Issue #3 / #4，日志 `manager open failed: 0xE00002C1`）。原因是键盘类 HID collection 的 `kIOHIDOptionsTypeSeizeDevice` 只允许特权进程，非 root 一定得到 `kIOReturnNotPrivileged`。
- 新增 root 守护进程 `vRemoteHIDHelper`，由 launchd 常驻，独占遥控器 HID collection 并通过 XPC 回传按键事件。
- App 侧新增 `ChromecastHIDHelperClient`：启动探测 helper，1.2 秒内不可用则回退原进程内路径并明确打印失败原因。
- helper 校验对端进程代码签名 identifier，非本 App 的连接一律拒绝。

### 变更

- 移除 TelemetryDeck 依赖与 `VRTelemetryDeck*`、`VRCommerceConfigURL` 配置：App 不再上报遥测，也不再拉取商业配置。
- 新增 `install-helper.sh` / `uninstall-helper.sh`。
- `package-app.sh` 会把 helper 打进 `vRemote.app/Contents/Helpers/` 并先签 helper 再签 App。

### 更新说明

- 首次使用按键映射需要执行一次 `sudo ./install-helper.sh`；不安装时语音功能不受影响。

## v1.1.1 · 2026-09-03

### 修复

- 修复 Chromecast Voice Remote 使用一段时间后，短按偶尔只打开豆包、遥控器麦克风却未持续收音的问题。
- 修复电脑 Option 关闭豆包时，较晚到达的音频状态可能短暂重新开启遥控器音频的问题。
- 改进双遥控器同时连接时的会话隔离、开麦确认与有限重试，避免一台设备的旧事件干扰另一台设备。
- 修复 X6 第一次短按开麦可能被误判为旧音频事件的问题。
- 更新按键映射页中的 Chromecast Remote 产品图，移除白底与标注线并优化显示尺寸。

### 更新说明

- 本次音频驱动没有变化。首次安装请使用 PKG；已经安装过驱动的用户可使用 DMG 只更新 APP。
- X6 官方支持范围仍为短按切换；Chromecast 官方支持短按切换与长按说话。

## v1.1.0 · 2026-09-03

### 新功能

- 新增 Chromecast Voice Remote（VID `0x18D1` / PID `0x9450`）支持。
- Chromecast 语音键支持短按切换和长按说话、松开结束。
- 新增 X6 Remote 与 Chromecast Voice Remote 按键映射页面。
- 支持方向、确认、返回、Home、音量、静音、YouTube、Netflix、信源及自定义键盘快捷键映射。
- 豆包语音触发键可选择 Option、Command、Control、Shift 或 Fn，默认 Option。
- 按键设置按遥控器型号保存，不绑定某一只实体设备。

### 改进与修复

- 主控制台统一使用“遥控器”措辞，不再把音频能力限定为 X6。
- X6 与 Chromecast Remote 可以同时连接并保持各自的语音链路。
- 启用映射时改为独占匹配型号的 HID 集合，再由 APP 重放映射后的动作，避免原始媒体行为与新映射同时触发。
- 关闭映射时保留系统原行为，用户可随时恢复。

### 支持边界

- Chromecast 当前只确认 VID `0x18D1`、PID `0x9450` 的型号档案，不代表支持所有 Chromecast 遥控器。
- X6 鼠标模式切换键由设备固件内部处理，不能单独重映射；启用映射后仍会透传鼠标移动、点击、滚轮和背面标准键盘。
- 语音键固定用于豆包语音控制，不作为普通按键映射。
- Fn 的触发效果依赖具体 Mac 与豆包输入法配置，首次使用时应现场确认。

## v1.0.1 · 2026-08-28

- 暂停 APP 与官网的购买遥控器入口。
- 没有启用且有效的购买链接时，APP 自动隐藏购买按钮。
- 本次驱动没有变化，已安装用户可使用 DMG 只更新 APP。

## v1.0.0 · 2026-08-27

- 首个公开版本。
- PKG 同时安装 vRemoter APP 与 `vRemoteDr 2ch` 音频驱动。
