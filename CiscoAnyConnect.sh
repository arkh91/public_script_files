# --- MAIN MENU ---
while true; do
    echo -e "\n${GREEN}===== Cisco AnyConnect VPN Setup Menu =====${NC}"
    echo "1) Install VPN Server"
    echo "2) Add VPN User"
    echo "3) Uninstall VPN Server"
    echo "0) Exit"
    echo "==========================================="
    read -rp "Select an option [0-3]: " OPTION

    case $OPTION in
        1) install_server ;;
        2)
            if command -v ocserv >/dev/null 2>&1; then
                create_user
            else
                echo -e "${RED}❌ ocserv is not installed.${NC}"
            fi
            ;;
        3) uninstall_server ;;
        0) echo "👋 Exiting."; exit 0 ;;
        *) echo -e "${RED}❌ Invalid option. Try 0-3.${NC}" ;;
    esac
done
