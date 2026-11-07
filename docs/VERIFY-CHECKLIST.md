# 真机验证清单（v1.3.0）

明天接上谷歌遥控器后，按这个顺序走一遍即可。所有命令都在仓库根目录执行。

## 0. 现在的状态

- 代码：`TheShadow178/vRemoter`，`main` 分支
- 产物：`vRemoter-1.2.2-*.zip`（`vRemote.app` + 安装脚本）
- 已修：Chromecast 按键失效（root helper 抢占 HID）、遥控器麦优先 + 本地麦自动回退
- 未做：两路独立设备（要改驱动）、AEC/降噪、Developer ID 签名与公证

## 1. 安装

```sh
cp -R vRemote.app ~/Applications/
xattr -dr com.apple.quarantine ~/Applications/vRemote.app   # 未公证，先解隔离
sudo ./install-helper.sh                                    # 只有按键映射需要
```

`install-helper.sh` 需要你自己输密码；装完后应打印 `Status: running`。

## 2. 启动并看日志

App 是 `LSUIElement`（无 Dock 图标），日志走 stdout，所以从终端启动最方便：

```sh
~/Applications/vRemote.app/Contents/MacOS/vRemote
```

helper 是 launchd 常驻，`print` 不会进日志文件。要单独看 helper 输出就先停掉它再前台跑：

```sh
sudo launchctl bootout system/local.simaqingfeng.vRemote.hidhelper
sudo /Library/PrivilegedHelperTools/local.simaqingfeng.vRemote.hidhelper
# Ctrl-C 之后恢复常驻：
sudo launchctl bootstrap system /Library/LaunchDaemons/local.simaqingfeng.vRemote.hidhelper.plist
```

## 3. 语音链路

1. 系统设置 → 蓝牙，配对遥控器
2. 菜单栏 → 打开控制台，确认遥控器显示「已连接」
3. 短按语音键：应打开豆包开始录音，再短按关闭
4. 长按语音键说话、松手：应结束并提交文字

日志应出现：

```
[AUDIO] 麦克风优先链路开启 · 遥控器优先，断开自动回退本地麦
[AUDIO] X6 首次输出 frames=...
```

## 4. 按键映射

1. 控制台 → 按键映射 → 选 Chromecast → 打开「启用映射」
2. 依次按方向、确认、返回、Home、静音、音量 ±
3. 再按电源、YouTube、Netflix、信源（默认是「禁用」，但应能在日志里看到 usage）

日志对照：

| 日志 | 含义 |
|---|---|
| `[CAST-HID] privileged helper active` | helper 生效，独占成功 |
| `[CAST-HID] privileged helper unavailable; ... 0xE00002C1` | helper 没装或没起来，按键必然无效 |
| `[CAST-MAP] 方向上 single DOWN -> ...` | 单击命中，映射已下发 |
| `[CAST-MAP] 确认 double DOWN -> ...` | 双击命中 |
| `[CAST-MAP] 返回 long UP -> ...` | 长按松手 |
| `[CAST-MAP] 未知按键 usage=XX` | 遥控器上报了这个 usage，但表里没有 |
| 什么都没打印 | 报告格式或 reportID 与解析不符，见第 6 节 |

### 手势验证（1.3.0）

映射行左侧多了「单击 / 双击 / 长按」选择器。给某个键（建议先拿不常用的「信源」试）配置：

1. 手势选「双击」，目标选「打开 App…」，点文件夹图标选一个 App
2. 手势选「长按」，目标选一个快捷键或另一个 App
3. 快速点两下 → 应打开双击对应的 App；按住 0.6 秒再松手 → 应触发长按目标
4. 单击方向键 → 应立刻响应、无 0.28 秒延迟；按住方向键 → 应持续重复

注意：只有配置了双击或长按的按键才走手势判定，其余按键保持旧版即时语义。

## 5. 内置 usage 表（`RemoteMappingSupport.swift`）

| usage | 按键 | 默认映射 |
|---|---|---|
| `01` | 电源 | 禁用 |
| `03` / `04` / `05` / `06` | 上 / 下 / 左 / 右 | 方向键 |
| `07` | 确认 | Return |
| `0A` | Home | 显示桌面 |
| `0B` | 返回 | Esc |
| `08` | 静音 | 系统静音 |
| `0C` / `0D` | 音量 + / − | 系统音量 |
| `0E` | YouTube | 禁用 |
| `0F` | Netflix | 禁用 |
| `11` | 信源 | 禁用 |
| `voice` | 语音键 | 豆包（走 ATVV，不经 HID） |

## 6. 如果按键 usage 对不上

1. 先看 `[CAST-MAP] 未知按键 usage=XX`，记下 XX
2. 在 `Sources/vRemote/RemoteMappingSupport.swift` 的 `chromecastButtons`（约第 52 行）加一条：

```swift
.init(id: "XX", title: L10n.text("新按键", "New Key"), symbol: "star", defaultTarget: .disabled),
```

3. `./package-app.sh` 重新打包，替换 `~/Applications/vRemote.app`
4. 如果**什么日志都没有**：说明 helper 解析的 reportID/首字节与真机不符。这时前台跑 helper（第 2 节），在 `Sources/vRemoteHIDHelper/main.swift` 的 `handleReport` 里临时打印 `reportID` 和整包字节，再按实际格式修解析。

## 7. 音频回退验证

1. 遥控器连着，按住语音键说话 → 只有遥控器声音，不应有「两个声音叠加」
2. 断开遥控器蓝牙 → 用录音软件（QuickTime 新建音频录制）选 `vRemoteDr 2ch` 说话
   - 应有声音，日志出现 `[AUDIO] MacBook 麦克风采集已启动: <设备名>`
   - 设备名应为 `27C1U-D` 一类真实设备，绝不能是 `MiRemoteV` / `vRemoteDr` / `BlackHole`
3. 若日志是 `[AUDIO] 找不到可用的本地麦克风` → 回退音源没选上，需要检查 `preferredLocalInputDevice`

## 8. 已知限制

- 包只有 **arm64**，Intel 不能跑
- ad-hoc 签名、未公证，首次打开要在「隐私与安全性」放行
- 按键映射依赖 root helper；不装只有语音可用
- 没有 AEC/降噪：扬声器外放时，本地麦可能收到回授（遥控器麦离得远，影响小）
- 只有一个虚拟设备 `vRemoteDr 2ch`；豆包和会议软件不能各选各的
- 不要把 `vRemoteDr 2ch` 设为系统默认输入（本机当前默认输入挂在 SayAll 的 `MiRemoteV 2ch`，先不动）

## 9. 下次候选改动（按优先级）

1. 按真机实测补齐 `chromecastButtons` 的 usage 表
2. 若确认 TTS 回授：豆包播放时压低本地麦，或给本地麦开 `VoiceProcessingIO`
3. 若要「豆包/会议各选一麦」：复制第二份 patched BlackHole bundle，做两个虚拟设备（不需要 Xcode，但 `sudo` 装两份并重启 `coreaudiod`）

## 10. 关键文件

- 按键解析：`Sources/vRemoteHIDHelper/main.swift`
- 按键映射：`Sources/vRemote/ChromecastRemoteHIDBridge.swift`、`Sources/vRemote/RemoteMappingSupport.swift`
- 音频优先级与回退：`Sources/vRemote/AudioPipe.swift`
- 打包：`package-app.sh`；helper 安装：`install-helper.sh`
