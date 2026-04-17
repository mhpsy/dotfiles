# Hyprland 配置与快捷键手册

> 配置目录：`~/.config/hypr/`
> 主修饰键：`Super`（Windows 键）

---

## 快捷键

### 应用启动

| 快捷键 | 功能 |
|--------|------|
| `Super + Enter` | 打开终端（Kitty） |
| `Super + B` | 打开浏览器（Google Chrome） |
| `Super + E` | 打开文件管理器（Dolphin） |
| `Alt + Space` | 应用启动器（Rofi） |

### 窗口操作

| 快捷键 | 功能 |
|--------|------|
| `Super + Q` | 关闭当前窗口 |
| `Super + F` | 切换全屏（完全全屏） |
| `Super + M` | 切换最大化（保留间距和 bar） |
| `Super + T` | 切换浮动/平铺 |
| `Super + \` | 交换分割方向（水平/垂直） |
| `Super + Ctrl + J` | 切换分割方式 |

### 窗口焦点移动

支持 Vim 风格和方向键两种方式：

| 快捷键 | 功能 |
|--------|------|
| `Super + H` / `Super + ←` | 聚焦左侧窗口 |
| `Super + L` / `Super + →` | 聚焦右侧窗口 |
| `Super + K` / `Super + ↑` | 聚焦上方窗口 |
| `Super + J` / `Super + ↓` | 聚焦下方窗口 |
| `Alt + Tab` | 循环切换窗口 |

### 窗口大小调整

支持 Vim 风格和方向键两种方式：

| 快捷键 | 功能 |
|--------|------|
| `Super + Shift + H` / `Super + Shift + ←` | 向左缩小 100px |
| `Super + Shift + L` / `Super + Shift + →` | 向右扩大 100px |
| `Super + Shift + K` / `Super + Shift + ↑` | 向上缩小 100px |
| `Super + Shift + J` / `Super + Shift + ↓` | 向下扩大 100px |

### 窗口交换位置

支持 Vim 风格和方向键两种方式：

| 快捷键 | 功能 |
|--------|------|
| `Super + Alt + H` / `Super + Alt + ←` | 与左侧窗口交换 |
| `Super + Alt + L` / `Super + Alt + →` | 与右侧窗口交换 |
| `Super + Alt + K` / `Super + Alt + ↑` | 与上方窗口交换 |
| `Super + Alt + J` / `Super + Alt + ↓` | 与下方窗口交换 |

### 浮动窗口移动

| 快捷键 | 功能 |
|--------|------|
| `Super + Shift + Alt + H` | 向左移动 50px |
| `Super + Shift + Alt + L` | 向右移动 50px |
| `Super + Shift + Alt + K` | 向上移动 50px |
| `Super + Shift + Alt + J` | 向下移动 50px |

### 鼠标操作

| 快捷键 | 功能 |
|--------|------|
| `Super + 鼠标左键拖动` | 移动窗口 |
| `Super + 鼠标右键拖动` | 调整窗口大小 |

### 窗口分组（Group / Tabbed）

将多个窗口叠在同一位置，通过标签切换，节省屏幕空间。

| 快捷键 | 功能 |
|--------|------|
| `Super + G` | 创建/解散窗口组 |
| `Super + ]` | 切换到组内下一个窗口 |
| `Super + [` | 切换到组内上一个窗口 |
| `Super + Shift + G` | 将当前窗口移出组 |
| `Super + Ctrl + H` | 将当前窗口移入左侧的组 |
| `Super + Ctrl + J` | 将当前窗口移入下方的组 |
| `Super + Ctrl + K` | 将当前窗口移入上方的组 |
| `Super + Ctrl + L` | 将当前窗口移入右侧的组 |

### 工作区

| 快捷键 | 功能 |
|--------|------|
| `Super + 1~9, 0` | 切换到工作区 1~10 |
| `Super + Shift + 1~9, 0` | 将当前窗口移至工作区 1~10 |
| `Super + Tab` | 切换到下一个工作区 |
| `Super + Shift + Tab` | 切换到上一个工作区 |
| `Super + 鼠标滚轮下` | 切换到下一个工作区 |
| `Super + 鼠标滚轮上` | 切换到上一个工作区 |
| `Super + Ctrl + ↓` | 跳转到空工作区 |

### 多显示器

| 快捷键 | 功能 |
|--------|------|
| `Super + Shift + ,` | 将当前工作区移到左侧显示器 |
| `Super + Shift + .` | 将当前工作区移到右侧显示器 |

### 系统操作

| 快捷键 | 功能 |
|--------|------|
| `Super + Ctrl + Q` | 锁屏（Hyprlock） |
| `Super + Ctrl + W` | 电源菜单（wlogout） |
| `Super + Ctrl + R` | 重新加载 Hyprland 配置 |
| `Super + Shift + B` | 重启 Waybar |

### 截图

| 快捷键 | 功能 |
|--------|------|
| `Super + PrintScreen` | 截图（交互式） |
| `Super + Alt + F` | 快速截取当前窗口 |
| `Super + Alt + S` | 快速截取选区 |

### 剪贴板与通知

| 快捷键 | 功能 |
|--------|------|
| `Super + V` | 剪贴板历史（通过 Rofi 选择） |
| `Super + N` | 打开/关闭通知中心（SwayNC） |

### 屏幕缩放

| 快捷键 | 功能 |
|--------|------|
| `Super + Shift + 鼠标滚轮下` | 放大屏幕 |
| `Super + Shift + 鼠标滚轮上` | 缩小屏幕 |
| `Super + Shift + Z` | 重置缩放为 1x |

### 多媒体 / Fn 键

| 快捷键 | 功能 |
|--------|------|
| `亮度+` | 屏幕亮度增加 10% |
| `亮度-` | 屏幕亮度减少 10% |
| `音量+` | 音量增加 5% |
| `音量-` | 音量减少 5% |
| `静音` | 切换静音 |
| `播放/暂停` | 播放/暂停媒体 |
| `下一曲` | 下一首 |
| `上一曲` | 上一首 |
| `麦克风静音` | 切换麦克风静音 |
| `锁定键` | 锁屏 |

---

## 配置概览

### 显示器（monitor.conf）

```
monitor = , preferred, auto, 1
```

自动检测显示器，使用首选分辨率，缩放比例 1。

### 窗口（window.conf）

- 内间距：10px
- 外间距：20px
- 边框宽度：2px
- 激活窗口边框：`$primary`（蓝色 #adc6ff）
- 非激活窗口边框：`$outline_variant`（深灰 #44474f）
- 布局：dwindle（螺旋平铺）
- 边框拖动调整大小：启用

### 装饰（decoration.conf）

- 窗口圆角：10px
- 激活窗口透明度：1.0
- 非激活窗口透明度：0.9
- 模糊：启用（size=4, passes=4）
- 阴影：启用（range=32）

### 动画（animation.conf）

- 窗口打开/关闭：popin 60% 弹出效果
- 工作区切换：滑动效果
- 多种贝塞尔曲线：Material Design 3 风格

### 输入（keyboard.conf）

- 键盘布局：US
- 数字锁默认开启
- 跟随鼠标聚焦
- 触摸板自然滚动

### 自启动（autostart.conf）

| 服务 | 说明 |
|------|------|
| polkit-gnome | 权限认证代理 |
| swaync | 通知守护进程 |
| swww-daemon | 壁纸守护进程 |
| hypridle | 空闲管理 |
| wl-paste + cliphist | 剪贴板历史 |
| waybar | 状态栏 |
| fcitx5 | 中文输入法 |

### 环境变量（environment.conf）

- Wayland 相关：XDG、QT、GDK、Mozilla、SDL
- NVIDIA 驱动适配
- 输入法：fcitx5
- 光标：Bibata-Modern-Ice, 24px

### 窗口规则（windowrule.conf）

以下窗口默认浮动居中：

- pavucontrol（音量控制）
- blueman-manager（蓝牙管理）
- Picture-in-Picture（画中画）
- hyprland-share-picker（屏幕共享选择器）
- nm-connection-editor（网络连接编辑器）
- gnome-calculator（计算器）

---

## 配置文件结构

```
~/.config/hypr/
├── hyprland.conf          # 主配置（source 各子配置）
├── colors.conf            # Matugen 生成的颜色主题
├── hyprlock.conf          # 锁屏配置
├── hyprpaper.conf         # 壁纸配置（未使用，已切换 swww）
├── wallpapers/            # 壁纸文件夹
│   └── wallhaven-w51676.png
├── scripts/               # 脚本
│   └── screenshot.sh
└── conf/
    ├── monitor.conf       # 显示器
    ├── window.conf        # 窗口/边框/布局
    ├── decoration.conf    # 装饰/模糊/阴影
    ├── animation.conf     # 动画
    ├── keybinding.conf    # 快捷键
    ├── autostart.conf     # 自启动
    ├── environment.conf   # 环境变量
    ├── keyboard.conf      # 输入设备
    ├── cursor.conf        # 光标主题
    ├── layout.conf        # 布局引擎
    ├── misc.conf          # 杂项
    ├── windowrule.conf    # 窗口规则
    ├── workspace.conf     # 工作区规则
    └── custom.conf        # 自定义
```
