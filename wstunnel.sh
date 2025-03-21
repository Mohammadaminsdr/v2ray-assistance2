#!/bin/bash

# Function to check and install WSTunnel if missing
check_and_install_wstunnel() {
    if ! command -v wstunnel &> /dev/null; then
        echo -e "\033[1;31m? WSTunnel is not installed!\033[0m"
        install_wstunnel
    fi
}
# Function to check if a port is already in use
is_port_used() {
    local port=$1
    if sudo lsof -i :$port >/dev/null 2>&1; then
        return 0  # Port is in use
    else
        return 1  # Port is not in use
    fi
}
install_wstunnel() {
    # Check and install required dependencies if missing
    for pkg in tar jq wget; do
        if ! command -v $pkg &>/dev/null; then
            echo "$pkg not found, installing..."
            sudo apt-get update
            sudo apt-get install -y $pkg
        fi
    done

    clear
    echo "Fetching the last 10 wstunnel releases..."

    # Get the last 10 releases from GitHub API
    releases=$(curl -s https://api.github.com/repos/erebe/wstunnel/releases | jq -r '.[0:10] | .[].tag_name')

    echo "Select a version to install:"
    select version in $releases; do
        if [ -n "$version" ]; then
            echo "You selected version: $version"
            break
        else
            echo "Invalid selection. Please choose a valid version."
        fi
    done

    # Detect system architecture (amd64, arm64, etc.)
    arch=$(uname -m)
    if [[ "$arch" == "x86_64" ]]; then
        arch="amd64"
    elif [[ "$arch" == "aarch64" ]]; then
        arch="arm64"
    else
        echo "Unsupported architecture: $arch"
        return
    fi

    # Construct the download URL for the selected release
    url="https://github.com/erebe/wstunnel/releases/download/${version}/wstunnel_${version:1}_linux_${arch}.tar.gz"

    # Download and install wstunnel
    wget $url -O /tmp/wstunnel.tar.gz
    tar -xzvf /tmp/wstunnel.tar.gz -C /tmp
    sudo mv /tmp/wstunnel /usr/local/bin/
    sudo chmod +x /usr/local/bin/wstunnel

    # Verify installation
    wstunnel --version
    echo "wstunnel installed successfully!"
    read -p "Press Enter to continue..."
}


# Show wstunnel version
wstunnel_version=$(wstunnel -V 2>&1)

# Main Menu Function
main_menu() {
    while true; do
        clear
        echo -e "\033[1;32m===================================\033[0m"
        echo -e "          \033[1;36mwstunnel Management Menu\033[0m"
        echo -e "\033[1;32m===================================\033[0m"

        echo -e " \033[1;34m1.\033[0m Install wstunnel"
        echo -e " \033[1;34m2.\033[0m Setup wstunnel"
        echo -e " \033[1;34m3.\033[0m Manage Tunnel Services"
        echo -e " \033[1;34m4.\033[0m Remove wstunnel"
        echo -e " \033[1;31m0.\033[0m Exit"
        echo -e "\033[1;32m===================================\033[0m"

        read -p "Please select an option: " option

        case $option in
            1) install_wstunnel ;;
            2) configure_wstunnel ;;
            3) select_service_to_manage ;;
            4) remove_wstunnel ;;
            0) 
                echo -e "\033[1;31mExiting... Goodbye!\033[0m"
                exit 0
                ;;
            *) 
                echo -e "\033[1;31mInvalid option! Please try again.\033[0m"
                sleep 1
                ;;
        esac
    done
}
remove_wstunnel() {
    # Remove wstunnel binary
    sudo rm -f /usr/local/bin/wstunnel
    echo "wstunnel removed successfully!"
    read -p "Press Enter to continue..."
}
# Function to Setup wstunnel (Server-side or Client-side)
configure_wstunnel() {
    clear
    echo -e "\033[1;32m=====================================\033[0m"
    echo -e "          \033[1;36mSetup wstunnel\033[0m"
    echo -e "\033[1;32m=====================================\033[0m"

    echo -e "\033[1;34mPlease select the mode for wstunnel:\033[0m"
    echo -e " \033[1;34m1.\033[0m \033[1;33mServer-side (kharej)\033[0m"
    echo -e " \033[1;34m2.\033[0m \033[1;33mClient-side (iran)\033[0m"
    echo -e " \033[1;31m0. \033[1;37mBack to Main Menu\033[0m"
    read -p "Enter your choice: " mode_choice

    case $mode_choice in
        1)  # Server-side (Listening)
            
            # Select ws or wss for server-side
            echo -e "\033[1;34mSelect the protocol type:\033[0m"
            select protocol_type in "ws" "wss"; do
                case $protocol_type in
                    ws|wss) break ;;
                    *) echo -e "\033[1;31mInvalid option. Please select 'ws' or 'wss'.\033[0m" ;;
                esac
            done
            

            while true; do
                read -p "Enter the communication port (press Enter for default 8880): " local_port
                
                if is_port_used $local_port; then
                    echo -e "\033[1;31mPort $local_port is already in use. Please enter a different port.\033[0m"
                else
                    echo -e "\033[1;32mPort $local_port is available.\033[0m"
                    break  # Exit the loop if the port is free
                fi
            done
            local_port=${local_port:-8880}

            # Define wstunnel options for Server-side (Listening)
            wstunnel_OPTIONS="server --log-lvl OFF ${protocol_type}://[::]:${local_port}"

            # Create and start service
            service_name="${local_port}"
            create_wstunnel_service "$service_name" "$wstunnel_OPTIONS"
            start_service "$service_name"
            ;;
        2)  # Client-side (Connecting)
            
            # Select ws or wss for client-side
            echo -e "\033[1;34mSelect the protocol type:\033[0m"
            echo -e "\033[1;33mUse ws for CDN (cloudflare etc) when proxy is on or wss when proxy is off\033[0m"
            select protocol_type in "ws" "wss"; do
                case $protocol_type in
                    ws|wss) break ;;
                    *) echo -e "\033[1;31mInvalid option. Please select 'ws' or 'wss'.\033[0m" ;;
                esac
            done



              # Select the protocol (tcp or udp)
              echo -e "\033[1;34mSelect the protocol:\033[0m"
              select protocol in "tcp" "udp"; do
                  case $protocol in
                      tcp|udp) break ;;
                      *) echo -e "\033[1;31mInvalid option. Please select 'tcp' or 'udp'.\033[0m" ;;
                  esac
              done
              
              
              
              # Prompt the user for multiple inbound ports
            while true; do
                read -p "Enter the listening (config) ports (comma-separated, e.g., 8080,9090): " local_ports
                # Convert the comma-separated input into an array
                IFS=',' read -ra lport_array <<< "$local_ports"
                
                # Flag to track if all ports are available
                all_ports_available=true
                
                # Check each port to see if it is in use
                for port in "${lport_array[@]}"; do
                    # Validate if the port is numeric
                    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
                        echo -e "\033[1;31mInvalid port: $port. Please enter valid numeric ports.\033[0m"
                        all_ports_available=false
                        break
                    fi
            
                    # Check if the port is already in use
                    if is_port_used $port; then
                        echo -e "\033[1;31mPort $port is already in use. Please enter a different port.\033[0m"
                        all_ports_available=false
                        break
                    fi
                done
                
                # If all ports are available, break out of the loop
                if $all_ports_available; then
                    echo -e "\033[1;32mAll ports are available: ${lport_array[*]}\033[0m"
                    break
                fi
            done


            read -p "Enter the remote server domain or IP (e.g., www.speedtest.net or 104.17.148.22): " remote_address
              # Check if input is an IPv6 address and format it properly
                          if [[ $remote_address =~ : ]]; then
                              remote_address="[$remote_address]"
                          fi
                          echo "Formatted IP: $remote_address"
              

              while true; do
                 read -p "Enter the communication port (press Enter for default 8880): " remote_port
                
                if is_port_used $remote_port; then
                    echo -e "\033[1;31mPort $remote_port is already in use. Please enter a different port.\033[0m"
                else
                    echo -e "\033[1;32mPort $remote_port is available.\033[0m"
                    break  # Exit the loop if the port is free
                fi
            done
              remote_port=${remote_port:-8880}
              
              # Convert comma-separated local ports into an array
              IFS=',' read -r -a ports_array <<< "$local_ports"
              
              # Initialize the wstunnel_OPTIONS string
              wstunnel_OPTIONS="client --log-lvl OFF"
              
              # Loop through the array of local ports and append each port configuration to wstunnel_OPTIONS
              for port in "${ports_array[@]}"; do
                  wstunnel_OPTIONS="$wstunnel_OPTIONS -L ${protocol}://0.0.0.0:${port}:127.0.0.1:${port}"
              done
              
              # Append the remote server details
              wstunnel_OPTIONS="$wstunnel_OPTIONS ${protocol_type}://${remote_address}:${remote_port}"
              
              # Display the constructed options
              echo -e "\033[1;32mwstunnel command:\033[0m $wstunnel_OPTIONS"
              
              # Now you can run the wstunnel command
              # wstunnel $wstunnel_OPTIONS

            
            # Create and start service
            service_name="${remote_port}"
            create_wstunnel_service "$service_name" "$wstunnel_OPTIONS"
            start_service "$service_name"
            ;;
        0)  # Back to Main Menu
            return
            ;;
        *)
            echo -e "\033[1;31mInvalid option! Please try again.\033[0m"
            sleep 1
            configure_wstunnel
            ;;
    esac
}




# Ensure script is run as root
check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "$(tput setaf 1)Error: You must run this script as root!$(tput sgr0)"
        exit 1
    fi
}

# Function to create a service for wstunnel (port forwarding or relay mode)
create_wstunnel_service() {
    local service_name=$1
    local wstunnel_OPTIONS=$2
    echo -e "\033[1;34mCreating wstunnel service for $service_name...\033[0m"

    # Create the systemd service file with dynamic options
    cat <<EOF > /etc/systemd/system/wstunnel-${service_name}.service
[Unit]
Description=wstunnel ${service_name} Service
After=network.target

[Service]
ExecStart=/usr/local/bin/wstunnel ${wstunnel_OPTIONS}
Environment="wstunnel_LOGGER_LEVEL=fatal"
StandardOutput=null
StandardError=null
Restart=always
User=root
WorkingDirectory=/root
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd to recognize the new service
    systemctl daemon-reload
    sleep 1
}

# Function to start the service
start_service() {
    local service_name=$1
    echo -e "\033[1;32mStarting $service_name service...\033[0m"
    systemctl start wstunnel-${service_name}
    systemctl enable wstunnel-${service_name}  # Ensure it starts on boot
    systemctl status wstunnel-${service_name}
    sleep 1
    read -p "Press Enter to continue..."
}

# **Function to Select a Service to Manage**
select_service_to_manage() {
    # Get a list of all wstunnel service files in /etc/systemd/system/ directory
    wstunnel_services=($(find /etc/systemd/system/ -maxdepth 1 -name 'wstunnel*.service' | sed 's/\/etc\/systemd\/system\///'))

    if [ ${#wstunnel_services[@]} -eq 0 ]; then
        echo -e "\033[1;31mNo wstunnel services found in /etc/systemd/system/!\033[0m"
        read -p "Press Enter to continue..."
        return
    fi

    echo -e "\033[1;34mSelect a wstunnel service to manage:\033[0m"
    select service_name in "${wstunnel_services[@]}"; do
        if [[ -n "$service_name" ]]; then
            echo -e "\033[1;32mYou selected: $service_name\033[0m"
            # Call a function to manage the selected service's action (start, stop, etc.)
            manage_service_action "$service_name"
            break
        else
            echo -e "\033[1;31mInvalid selection. Please choose a valid service.\033[0m"
        fi
    done
}

# **Function to Perform Actions (start, stop, restart, etc.) on Selected Service**
manage_service_action() {
    local service_name=$1

    while true; do
        clear
        echo -e "\n\033[1;34m==============================\033[0m"
        echo -e "    \033[1;36mManage Service: $service_name\033[0m"
        echo -e "\033[1;34m==============================\033[0m"
        echo -e " \033[1;34m1.\033[0m Start the Service"
        echo -e " \033[1;34m2.\033[0m Stop the Service"
        echo -e " \033[1;34m3.\033[0m Restart the Service"
        echo -e " \033[1;34m4.\033[0m Check Service Status"
        echo -e " \033[1;34m5.\033[0m Remove the Service"
        echo -e " \033[1;31m0.\033[0m Return"
        echo -e "\033[1;34m==============================\033[0m"

        read -p "Please select an action: " action_option

        case $action_option in
            1)
                systemctl start "$service_name" && echo -e "\033[1;32mService $service_name started.\033[0m"
                read -p "Press Enter to continue..."
                ;;
            2)
                systemctl stop "$service_name" && echo -e "\033[1;32mService $service_name stopped.\033[0m"
                read -p "Press Enter to continue..."
                ;;
            3)
                systemctl restart "$service_name" && echo -e "\033[1;32mService $service_name restarted.\033[0m"
                read -p "Press Enter to continue..."
                ;;
            4)
                systemctl status "$service_name"
                read -p "Press Enter to continue..."
                ;;
            5)
                systemctl stop "$service_name"
                systemctl disable "$service_name"
                rm "/etc/systemd/system/$service_name"
                systemctl daemon-reload
                echo -e "\033[1;32mService $service_name removed.\033[0m"
                read -p "Press Enter to continue..."
                ;;
            0)
                break
                ;;
            *)
                echo -e "\033[1;31mInvalid option! Please try again.\033[0m"
                sleep 2
                ;;
        esac
    done
}

# Start the main menu
check_and_install_wstunnel
main_menu
