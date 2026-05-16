#!/bin/bash
# 监听 Hyprland 显示器热插事件:有新屏接入时重贴当前壁纸。
# swww 不会自动给热插上来的输出套壁纸(只给黑色填充),所以这里补一刀。
# 由 autostart.conf 以 exec-once 启动,依赖 socat。

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

socat -U - "UNIX-CONNECT:$SOCKET" | while read -r line; do
    case "$line" in
        monitoradded*)
            # 等输出就绪再贴,避免 swww 还没注册新屏
            sleep 0.5
            waypaper --restore
            ;;
    esac
done
