#!/bin/bash

clear

RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
CYAN='\e[1;36m'
NC='\e[0m'

cat << 'EOF'
==============================================
       L4D2 Server Installation Script
==============================================
**Warning: This script needs to be run after the dependency installation is completed and you have a certain Linux foundation.**
**警告: 本脚本需要建立在已完成依赖安装后运行,并且您具备一定的Linux基础**

This script will help you:
1. Install L4D2 Dedicated Server
2. Download and install plugins
3. Create management scripts for easier management
4. Customize server with a daily restart schedule
5. Support multiple server management

本脚本将帮助您：
1. 安装Left 4 Dead 2 服务端
2. 下载并安装插件
3. 创建方便管理的脚本
4. 自定义服务器的每日重启计划
5. 支持多服务器管理

Created by: HANA
==============================================
EOF

LANGUAGE="en"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
SERVER_PATHS=()

check_root() {
    if [ "$EUID" -eq 0 ]; then
        echo -e "${RED}This script should NOT be run as root.${NC}"
        echo -e "${RED}Please run as a normal user (preferably the steam user).${NC}"
        echo -e "${RED}不要使用root权限运行此脚本。${NC}"
        echo -e "${RED}请使用普通用户（最好是steam用户）运行。${NC}"
        exit 1
    fi
}

confirm() {
    local response
    read -r response
    case "$response" in
        [Yy]|[Yy][Ee][Ss]|"") return 0 ;;
        *) return 1 ;;
    esac
}

echo -e "\e[1;36m=== Language Selection ===\e[0m"
echo -e "\e[1;33m1. English\e[0m"
echo -e "\e[1;33m2. 中文\e[0m"
read -p "Enter your choice (1 or 2): " lang_choice

if [ "$lang_choice" == "2" ]; then
    LANGUAGE="zh"
fi

function echo_lang() {
    local en_msg=$1
    local zh_msg=$2
    if [ "$LANGUAGE" == "en" ]; then
        echo -e "\e[1;32m$en_msg\e[0m"
    else
        echo -e "\e[1;32m$zh_msg\e[0m"
    fi
}

function echo_section() {
    local en_msg=$1
    local zh_msg=$2
    echo -e "\n\e[1;36m=== $en_msg / $zh_msg ===\e[0m"
}

echo_section "Server Configuration" "服务器配置"
echo_lang "Do you want to set up multiple servers? [Y/n]" "是否要设置多个服务器？[Y/n]"
if confirm; then
    echo_lang "How many servers do you want to set up?" "您想设置多少个服务器？"
    read -r server_count
    for ((i=1; i<=server_count; i++)); do
        echo_lang "Enter installation path for server $i (e.g., /home/hana/l4d2_$i):" "请输入服务器 $i 的安装路径（例如 /home/hana/l4d2_$i）:"
        read -r server_path
        SERVER_PATHS+=("$(realpath "$server_path")")
        mkdir -p "$server_path"
    done
else
    echo_lang "Please enter the installation path (e.g., /home/hana/l4d2):" "请输入安装路径（例如 /home/hana/l4d2）:"
    read -r INSTALL_PATH
    SERVER_PATHS+=("$(realpath "$INSTALL_PATH")")
    mkdir -p "$INSTALL_PATH"
fi

for path in "${SERVER_PATHS[@]}"; do
    echo_lang "Installation path set to: $path" "安装路径设置为: $path"
done

function setup_steamcmd() {
    echo_section "SteamCMD Setup" "SteamCMD 设置"
    
    STEAMCMD_DIR="$HOME/steamcmd"
    if [ ! -d "$STEAMCMD_DIR" ]; then
        mkdir -p "$STEAMCMD_DIR"
        cd "$STEAMCMD_DIR" || exit 1
        
        echo_lang "Downloading SteamCMD..." "正在下载 SteamCMD..."
        curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -
    else
        echo_lang "SteamCMD already installed, skipping download." "SteamCMD 已安装，跳过下载。"
    fi
}

function setup_server() {
    echo_section "Server Installation" "服务端安装"

    setup_steamcmd
    STEAMCMD_DIR="$HOME/steamcmd"

    # 检查是否需要快速部署模式
    local use_fast_deploy=false
    if [ ${#SERVER_PATHS[@]} -gt 1 ]; then
        echo_lang "Multiple servers detected. Use fast deployment mode? [Y/n]" "检测到多个服务器。是否使用快速部署模式？[Y/n]"
        echo_lang "(Fast mode: Download once, then copy to other servers)" "（快速模式：下载一次，然后复制到其他服务器）"
        if confirm; then
            use_fast_deploy=true
        fi
    fi

    if [ "$use_fast_deploy" = true ]; then
        # 快速部署模式：先下载到第一个服务器，然后复制
        local master_server="${SERVER_PATHS[0]}"
        echo_lang "Using fast deployment mode with master server: $master_server" "使用快速部署模式，主服务器：$master_server"

        echo_lang "Installing L4D2 Server to master location: $master_server" "正在安装 L4D2 服务端到主位置: $master_server"
        install_single_server "$master_server"

        # 复制到其他服务器
        for ((i=1; i<${#SERVER_PATHS[@]}; i++)); do
            local target_server="${SERVER_PATHS[$i]}"
            echo_lang "Copying server files to: $target_server" "正在复制服务端文件到: $target_server"

            # 创建目标目录
            mkdir -p "$target_server"

            # 复制文件（排除可能的日志和配置文件）
            echo_lang "This may take a few minutes..." "这可能需要几分钟..."
            rsync -a --progress --exclude="left4dead2/logs" --exclude="left4dead2/cfg/server.cfg" "$master_server/" "$target_server/"

            echo_lang "Server copy completed for: $target_server" "服务端复制完成：$target_server"
        done
    else
        # 传统模式：每个服务器单独下载
        for server_path in "${SERVER_PATHS[@]}"; do
            echo_lang "Installing L4D2 Server to: $server_path" "正在安装 L4D2 服务端到: $server_path"
            install_single_server "$server_path"
        done
    fi
}

function install_single_server() {
    local server_path=$1
    local STEAMCMD_DIR="$HOME/steamcmd"

    echo_lang "Creating installation script..." "正在创建安装脚本..."
    cat << STEAMCMD_EOF > "$STEAMCMD_DIR/Left4Dead2_Server.txt"
force_install_dir $server_path
login anonymous
@sSteamCmdForcePlatformType windows
app_update 222860 validate
@sSteamCmdForcePlatformType linux
app_update 222860 validate
quit
STEAMCMD_EOF

    cd "$STEAMCMD_DIR" || exit 1
    ./steamcmd.sh +runscript "$STEAMCMD_DIR/Left4Dead2_Server.txt"

    echo_lang "Server installation completed for: $server_path" "服务端安装完成：$server_path"
}

function download_plugins() {
    echo_section "Plugin Installation" "插件安装"

    echo_lang "Do you want to download plugins? [Y/n]" "是否下载插件？[Y/n]"
    if confirm; then
        echo_lang "Please select a plugin repository:" "请选择一个插件库:"
        echo_lang "1. Hana Competitive" "1. Hana Competitive"
        echo_lang "2. Sir.P 0721 Server" "2. Sir.P 的0721服务器"
        echo_lang "3. Default Competitive" "3. 默认的Zonemod"
        echo_lang "4. Not0721 Coop" "4. Not0721 战役"
        echo_lang "5. Anne's Coop" "5. Anne 药役"
        echo_lang "6. Custom repository" "6. 自定义"
        read -p "Enter your choice (1-6): " plugin_choice

        case $plugin_choice in
            1)
                PLUGIN_REPO_URL="https://github.com/cH1yoi/L4D2-Competitive-Rework.git"
                ;;
            2)
                PLUGIN_REPO_URL="https://github.com/PencilMario/L4D2-Competitive-Rework.git"
                ;;
            3)
                PLUGIN_REPO_URL="https://github.com/SirPlease/L4D2-Competitive-Rework.git"
                ;;
            4)
                PLUGIN_REPO_URL="https://github.com/PencilMario/L4D2-Not0721Here-CoopSvPlugins.git"
                ;;
            5)
                PLUGIN_REPO_URL="https://github.com/fantasylidong/CompetitiveWithAnne.git"
                ;;
            6)
                echo_lang "Please enter the custom repository URL:" "请输入自定义库地址:"
                read -r PLUGIN_REPO_URL
                ;;
            *)
                echo_lang "Invalid choice, skipping plugin download." "无效选择，跳过插件下载。"
                return
                ;;
        esac

        REPO_NAME=$(basename "$PLUGIN_REPO_URL" .git)
        echo_lang "Downloading plugins..." "正在下载插件..."
        cd "$SCRIPT_DIR" || exit 1
        git clone "$PLUGIN_REPO_URL" "$REPO_NAME"

        if [ -d "$REPO_NAME" ]; then
            for server_path in "${SERVER_PATHS[@]}"; do
                mkdir -p "$server_path/left4dead2"
                chmod 775 -R "$server_path/left4dead2"

                cp -r "$REPO_NAME"/* "$server_path/left4dead2/"

                echo_lang "Plugins installed successfully for: $server_path" "插件安装成功：$server_path"
            done

            echo_lang "Plugin installation completed." "插件安装完成。"
        else
            echo_lang "Failed to clone the repository." "克隆仓库失败。"
        fi
    fi
}



function create_game_update_script() {
    echo_lang "Creating update scripts..." "正在创建更新脚本..."
    
    cat << 'GAME_UPDATE_EOF' > "$SCRIPT_DIR/update_game.sh"
#!/bin/bash

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "$SCRIPT_DIR/server_config.sh"

RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
NC='\e[0m'

echo -e "${BLUE}==================Game Update Time==================${NC}"
TZ=UTC-8 date
echo -e "${BLUE}==================Starting Update==================${NC}"

# 使用当前用户的home目录
USER_HOME="$HOME"
STEAMCMD_DIR="$USER_HOME/steamcmd"

if [ ! -d "$STEAMCMD_DIR" ]; then
    echo -e "${YELLOW}SteamCMD not found, installing...${NC}"
    mkdir -p "$STEAMCMD_DIR"
    cd "$STEAMCMD_DIR" || exit 1
    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -
fi

for server_path in "${SERVER_PATHS[@]}"; do
    if [ ! -d "$server_path" ]; then
        echo -e "${RED}Error: Server directory $server_path does not exist${NC}"
        echo -e "${RED}Skipping this server...${NC}"
        continue
    fi
    
    echo -e "${GREEN}Updating server: $server_path${NC}"
    cd "$STEAMCMD_DIR" || exit 1
    ./steamcmd.sh +login anonymous +force_install_dir "$server_path" +app_update 222860 validate +quit
done

echo -e "${BLUE}==================Update Complete==================${NC}"
GAME_UPDATE_EOF
    chmod +x "$SCRIPT_DIR/update_game.sh"
}

function create_server_config() {
    echo_lang "Creating server configuration..." "正在创建服务器配置..."

    echo_lang "Enter the hour (0-23) for daily restart:" "请输入每日重启的小时（0-23）:"
    read -r RESTART_HOUR

    if ! [[ "$RESTART_HOUR" =~ ^[0-9]+$ ]] || [ "$RESTART_HOUR" -lt 0 ] || [ "$RESTART_HOUR" -gt 23 ]; then
        echo_lang "Invalid hour, setting default to 4" "无效的小时数，设置默认值为4点"
        RESTART_HOUR=4
    fi

    cat << EOF > "$SCRIPT_DIR/server_config.sh"
#!/bin/bash

# L4D2 Server Configuration
LANGUAGE="${LANGUAGE}"

# Server paths
SERVER_PATHS=(
EOF

    for path in "${SERVER_PATHS[@]}"; do
        echo "    \"$path\"" >> "$SCRIPT_DIR/server_config.sh"
    done

    cat << 'EOF' >> "$SCRIPT_DIR/server_config.sh"
)

# Server instances: ["port"]="name:path"
declare -A SERVERS=(
EOF

    local port=27015
    for path in "${SERVER_PATHS[@]}"; do
        local basename=$(basename "$path")
        echo "    [\"$port\"]=\"${basename}1:$path\"" >> "$SCRIPT_DIR/server_config.sh"
        ((port++))
    done

    cat << 'EOF' >> "$SCRIPT_DIR/server_config.sh"
)

# Default startup parameters
DEFAULT_PARAMS="-game left4dead2 -sv_lan 0 +sv_clockcorrection_msecs 25 -timeout 10 -tickrate 100 -maxplayers 32 +sv_setmax 32 +map c2m1_highway +servercfgfile server.cfg"

# Custom startup parameters (optional)
declare -A SERVER_PARAMS=(
EOF

    port=27015
    for path in "${SERVER_PATHS[@]}"; do
        echo "    # [\"$port\"]=\"custom parameters here\"" >> "$SCRIPT_DIR/server_config.sh"
        ((port++))
    done

    cat << EOF >> "$SCRIPT_DIR/server_config.sh"
)

# Daily restart time (0-23)
RESTART_HOUR=${RESTART_HOUR}
EOF

    chmod +x "$SCRIPT_DIR/server_config.sh"

    echo_lang "Setting up automatic daily restart..." "正在设置每日自动重启..."
    (crontab -l 2>/dev/null | grep -v "$SCRIPT_DIR/start_servers.sh restart"; echo "0 $RESTART_HOUR * * * $SCRIPT_DIR/start_servers.sh restart # L4D2_AUTO_RESTART_$(whoami)") | crontab -

    if [ "$LANGUAGE" == "zh" ]; then
        echo -e "${GREEN}配置文件已生成：$SCRIPT_DIR/server_config.sh${NC}"
        echo -e "${YELLOW}请编辑此文件来配置您的服务器实例${NC}"
        echo -e "${YELLOW}配置完成后使用 ./start_servers.sh 来管理服务器${NC}"
    else
        echo -e "${GREEN}Configuration file generated: $SCRIPT_DIR/server_config.sh${NC}"
        echo -e "${YELLOW}Please edit this file to configure your server instances${NC}"
        echo -e "${YELLOW}After configuration, use ./start_servers.sh to manage servers${NC}"
    fi
}

function create_server_start_script() {
    echo_lang "Creating server start script..." "正在创建服务器启动脚本..."
    
    cat << 'SERVER_START_EOF' > "$SCRIPT_DIR/start_servers.sh"
#!/bin/bash

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "$SCRIPT_DIR/server_config.sh"

RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
NC='\e[0m'


function start_server() {
    local PORT=$1
    local NAME="$(echo "${SERVERS[$PORT]}" | cut -d: -f1)"
    local DIR=$(echo "${SERVERS[$PORT]}" | cut -d: -f2)

    # 获取启动参数
    local PARAMS=""
    if [ -n "${SERVER_PARAMS[$PORT]}" ]; then
        # 使用配置的参数
        PARAMS="${SERVER_PARAMS[$PORT]}"
    else
        # 使用默认参数
        PARAMS="$DEFAULT_PARAMS"
    fi

    if ! screen -ls | grep -q "$NAME"; then
        echo -e "${GREEN}Starting L4D2 $NAME on port $PORT${NC}"
        echo -e "${YELLOW}Parameters: $PARAMS${NC}"
        cd "$DIR" || exit 1
        screen -dmS "$NAME" ./srcds_run $PARAMS -port "$PORT"
    else
        echo -e "${YELLOW}$NAME is already running!${NC}"
    fi
}

function stop_server() {
    local NAME=$1
    if screen -ls | grep -q "$NAME"; then
        echo -e "${YELLOW}Stopping $NAME${NC}"
        screen -X -S "$NAME" quit
    else
        echo -e "${RED}$NAME is not running${NC}"
    fi
}

function restart_server() {
    local PORT=$1
    local NAME="$(echo "${SERVERS[$PORT]}" | cut -d: -f1)"
    stop_server "$NAME"
    sleep 2
    start_server "$PORT"
}

function show_status() {
    echo -e "${YELLOW}Server Status:${NC}"
    for PORT in "${!SERVERS[@]}"; do
        local NAME=$(echo "${SERVERS[$PORT]}" | cut -d: -f1)
        local DIR=$(echo "${SERVERS[$PORT]}" | cut -d: -f2)
        echo -e "\nServer: ${GREEN}$(basename "$DIR")${NC}"
        echo -e "Instance: ${YELLOW}$NAME${NC}"
        echo -e "Port: ${YELLOW}$PORT${NC}"
        if screen -ls | grep -q "$NAME"; then
            echo -e "Status: ${GREEN}RUNNING${NC}"
        else
            echo -e "Status: ${RED}STOPPED${NC}"
        fi
    done
}

function show_help() {
    if [ "$LANGUAGE" == "zh" ]; then
        echo "用法: $0 {命令} [端口]"
        echo
        echo "命令:"
        echo "  start [端口]     启动指定端口的服务器，不指定则启动所有"
        echo "  stop [端口]       停止指定端口的服务器，不指定则停止所有"
        echo "  restart [端口]    重启指定端口的服务器，不指定则重启所有"
        echo "  status          显示所有服务器状态"
        echo
        echo "当前配置的服务器:"
        for PORT in "${!SERVERS[@]}"; do
            local NAME=$(echo "${SERVERS[$PORT]}" | cut -d: -f1)
            local DIR=$(echo "${SERVERS[$PORT]}" | cut -d: -f2)
            echo "  端口: $PORT, 名称: $NAME, 目录: $DIR"
        done
    else
        echo "Usage: $0 {command} [port]"
        echo
        echo "Commands:"
        echo "  start [port]     Start server on specified port, or all if not specified"
        echo "  stop [port]      Stop server on specified port, or all if not specified"
        echo "  restart [port]   Restart server on specified port, or all if not specified"
        echo "  status          Show status of all servers"
        echo
        echo "Configured servers:"
        for PORT in "${!SERVERS[@]}"; do
            local NAME=$(echo "${SERVERS[$PORT]}" | cut -d: -f1)
            local DIR=$(echo "${SERVERS[$PORT]}" | cut -d: -f2)
            echo "  Port: $PORT, Name: $NAME, Dir: $DIR"
        done
    fi
}

case "$1" in
    start)
        if [ -n "$2" ]; then
            if [ -n "${SERVERS[$2]}" ]; then
                start_server "$2"
            else
                echo -e "${RED}Invalid port: $2${NC}"
                show_help
            fi
        else
            for PORT in "${!SERVERS[@]}"; do
                start_server "$PORT"
            done
        fi
        ;;
    stop)
        if [ -n "$2" ]; then
            if [ -n "${SERVERS[$2]}" ]; then
                stop_server "$(echo "${SERVERS[$2]}" | cut -d: -f1)"
            else
                echo -e "${RED}Invalid port: $2${NC}"
                show_help
            fi
        else
            for PORT in "${!SERVERS[@]}"; do
                stop_server "$(echo "${SERVERS[$PORT]}" | cut -d: -f1)"
            done
        fi
        ;;
    restart)
        if [ -n "$2" ]; then
            if [ -n "${SERVERS[$2]}" ]; then
                restart_server "$2"
            else
                echo -e "${RED}Invalid port: $2${NC}"
                show_help
            fi
        else
            for PORT in "${!SERVERS[@]}"; do
                restart_server "$PORT"
            done
        fi
        ;;
    status)
        show_status
        ;;
    *)
        show_help
        exit 1
        ;;
esac

exit 0
SERVER_START_EOF
    chmod +x "$SCRIPT_DIR/start_servers.sh"
}

function show_final_message() {
    echo_section "Installation Complete" "安装完成"

    if [ "$LANGUAGE" == "zh" ]; then
        echo -e "${GREEN}安装已完成！${NC}"
        echo -e "${YELLOW}请按照以下步骤操作：${NC}"
        echo "1. 编辑 server_config.sh 配置服务器实例"
        echo "2. 使用 start_servers.sh 管理服务器"
        echo -e "${YELLOW}以下辅助脚本已生成：${NC}"
        echo "- update_game.sh：更新游戏文件"
        echo "- start_servers.sh：服务器管理脚本"
    else
        echo -e "${GREEN}Installation completed!${NC}"
        echo -e "${YELLOW}Please follow these steps:${NC}"
        echo "1. Edit server_config.sh to configure server instances"
        echo "2. Use start_servers.sh to manage servers"
        echo -e "${YELLOW}The following utility scripts have been generated:${NC}"
        echo "- update_game.sh: Update game files"
        echo "- start_servers.sh: Server management script"
    fi
}

check_root
setup_server
create_server_config
create_game_update_script
create_server_start_script
download_plugins
show_final_message