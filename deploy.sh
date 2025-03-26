#!/bin/bash

# deploy.sh

# Colors for output
RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
NC='\033[0m'

CURRENT_STATUS="Initializing"
VERBOSE=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --verbose) VERBOSE=true; shift ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
done

if [ "$VERBOSE" = false ]; then
    verbose_output_handle() {
        "$@" > /dev/null 2>&1
    }
else
    verbose_output_handle() {
        "$@"
    }
fi

show_status() {
    echo -e "\n${BLUE}Current Status: $CURRENT_STATUS${NC}\n"
}

show_progress() {
    local pids=("$@")
    local spinner=('|' '/' '-' '\')
    local i=0
    local all_done=false
    while [ "$all_done" = false ]; do
        all_done=true
        for pid in "${pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                all_done=false
                break
            fi
        done
        if [ "$all_done" = false ]; then
            printf "\r${BLUE}Running Ansible playbooks... %s${NC}" "${spinner[$i]}"
            i=$(( (i + 1) % 4 ))
            sleep 0.2
        fi
    done
    printf "\r${BLUE}Running Ansible playbooks... Done${NC}\n"
}

# Trap for CTRL+C (interrupt)
trap 'echo -e "\n${RED}Script interrupted by CTRL+C${NC}"; show_status; exit 1' INT

if [ ! -f "variables.env" ]; then
    echo -e "${RED}Error: variables.env not found!${NC}"
    exit 1
fi
source ./variables.env

# Validate required variables
for var in DO_TOKEN SSH_KEY_NAME C2_REDIRECTOR_DOMAIN EVILGINX_DOMAIN; do
    if [ -z "${!var}" ]; then
        echo -e "${RED}Error: $var is not set in variables.env${NC}"
        exit 1
    fi
done

SSH_KEY_PATH="$PWD/keys/${SSH_KEY_NAME}"

if [ ! -f "$SSH_KEY_PATH" ]; then
    echo -e "${RED}Error: SSH key file not found at $SSH_KEY_PATH${NC}"
    exit 1
fi

CURRENT_STATUS="Changing to terraform directory"
show_status
cd terraform || { echo -e "${RED}Error: Cannot change to terraform directory${NC}"; exit 1; }

CURRENT_STATUS="Initializing Terraform"
show_status
verbose_output_handle terraform init

CURRENT_STATUS="Applying Terraform configuration"
show_status
verbose_output_handle terraform apply -auto-approve \
    -var "do_token=${DO_TOKEN}" \
    -var "ssh_key_name=${SSH_KEY_NAME}"

CURRENT_STATUS="Extracting droplet IPs"
show_status
C2_REDIRECTOR_IP=$(terraform output -raw c2_redirector_ip 2>/dev/null || echo "")
C2_HAVOC_IP=$(terraform output -raw c2_havoc_ip 2>/dev/null || echo "")
EVILGINX_SERVER_IP=$(terraform output -raw evilginx_server_ip 2>/dev/null || echo "")
GOPHISH_SERVER_IP=$(terraform output -raw gophish_server_ip 2>/dev/null || echo "")

# Validate IPs
for ip in C2_REDIRECTOR_IP C2_HAVOC_IP EVILGINX_SERVER_IP GOPHISH_SERVER_IP; do
    if [ -z "${!ip}" ]; then
        echo -e "${RED}Error: Failed to retrieve $ip${NC}"
        exit 1
    fi
done

CURRENT_STATUS="Updating variables.env with IPs"
show_status
sed -i.bak "s/C2_REDIRECTOR_IP=.*/C2_REDIRECTOR_IP=\"$C2_REDIRECTOR_IP\"/" ../variables.env && rm -f ../variables.env.bak
sed -i.bak "s/C2_HAVOC_IP=.*/C2_HAVOC_IP=\"$C2_HAVOC_IP\"/" ../variables.env && rm -f ../variables.env.bak
sed -i.bak "s/EVILGINX_SERVER_IP=.*/EVILGINX_SERVER_IP=\"$EVILGINX_SERVER_IP\"/" ../variables.env && rm -f ../variables.env.bak
sed -i.bak "s/GOPHISH_SERVER_IP=.*/GOPHISH_SERVER_IP=\"$GOPHISH_SERVER_IP\"/" ../variables.env && rm -f ../variables.env.bak

CURRENT_STATUS="Updating Ansible inventory"
show_status
cd ../ansible || { echo -e "${RED}Error: Cannot change to ansible directory${NC}"; exit 1; }
sed -i.bak "s/A\.A\.A\.A/$C2_REDIRECTOR_IP/" inventory.ini && rm -f inventory.ini.bak
sed -i.bak "s/B\.B\.B\.B/$C2_HAVOC_IP/" inventory.ini && rm -f inventory.ini.bak
sed -i.bak "s/C\.C\.C\.C/$EVILGINX_SERVER_IP/" inventory.ini && rm -f inventory.ini.bak
sed -i.bak "s/D\.D\.D\.D/$GOPHISH_SERVER_IP/" inventory.ini && rm -f inventory.ini.bak
sed -i.bak "s|ansible_ssh_private_key_file=.*|ansible_ssh_private_key_file=$SSH_KEY_PATH|" inventory.ini && rm -f inventory.ini.bak

# Update Ansible playbooks with domains
sed -i.bak "s/domain: .*/domain: \"$C2_REDIRECTOR_DOMAIN\"/" c2_redirector.yml && rm -f c2_redirector.yml.bak
sed -i.bak "s/domain: .*/domain: \"$EVILGINX_DOMAIN\"/" evilginx_tmux.yml && rm -f evilginx_tmux.yml.bak

CURRENT_STATUS="Waiting for domain confirmation"
show_status
echo -e "${BLUE}Please confirm the following domain mappings:${NC}"
echo -e "${GREEN}C2 Redirector IP: $C2_REDIRECTOR_IP -> C2 Redirector Domain: $C2_REDIRECTOR_DOMAIN${NC}"
echo -e "${GREEN}Evilginx IP: $EVILGINX_SERVER_IP -> Evilginx Domain: $EVILGINX_DOMAIN${NC}"
echo -e ""
while true; do
    if ! read -t 60 -p "Have the domains been pointed to these servers? (Y/N): " DOMAIN_CONFIRMATION; then
        echo -e "\n${RED}Error: No response within 60 seconds. Exiting...${NC}"
        exit 1
    fi
    case $DOMAIN_CONFIRMATION in
        [Yy]|[Yy][Ee][Ss]) break ;;
        [Nn]|[Nn][Oo]) echo -e "${RED}Error: Domains not pointed. Exiting...${NC}"; exit 1 ;;
        *) echo -e "${RED}Please answer Y/y or N/n${NC}" ;;
    esac
done

# Run c2_havoc.yml first to set variables.env and Havoc server
CURRENT_STATUS="Running Havoc playbook"
show_status
verbose_output_handle ansible-playbook -i inventory.ini c2_havoc_tmux.yml -e "ansible_host_key_checking=False"
# Check if it failed
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Ansible playbook 'c2_havoc_tmux.yml' failed.${NC}"
    exit 1
fi

# Run remaining Ansible playbooks in parallel with progress indicator
CURRENT_STATUS="Running remaining Ansible playbooks"
show_status

# Associative array to map PIDs to playbook names
declare -A playbook_map

# Start remaining playbooks in the background and map PIDs to names
verbose_output_handle ansible-playbook -i inventory.ini c2_redirector.yml -e "ansible_host_key_checking=False" &
PID1=$!
playbook_map[$PID1]="c2_redirector.yml"
verbose_output_handle ansible-playbook -i inventory.ini evilginx_tmux.yml -e "ansible_host_key_checking=False" &
PID2=$!
playbook_map[$PID2]="evilginx_tmux.yml"
verbose_output_handle ansible-playbook -i inventory.ini gophish_tmux.yml -e "ansible_host_key_checking=False" &
PID3=$!
playbook_map[$PID3]="gophish_tmux.yml"

# Array of PIDs for show_progress
PIDS=($PID1 $PID2 $PID3)

show_progress "${PIDS[@]}"

# Check for playbook failures and report specific playbook name
for pid in "${PIDS[@]}"; do
    wait "$pid"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Ansible playbook '${playbook_map[$pid]}' (PID $pid) failed.${NC}"
        exit 1
    fi
done

CURRENT_STATUS="Fetching C2 Internal IP for display"
show_status
if [ -f "../variables.env" ]; then
    # Source variables.env to load the latest values into the shell
    source ../variables.env
    if [ -n "$C2_INTERNAL_IP" ] && [ "$C2_INTERNAL_IP" != "unknown" ]; then
        echo -e "${GREEN}C2 Internal IP retrieved: $C2_INTERNAL_IP${NC}"
    else
        echo -e "${RED}Warning: C2_INTERNAL_IP not set or invalid in variables.env, setting to 'unknown'${NC}"
        C2_INTERNAL_IP="unknown"
    fi
else
    echo -e "${RED}Error: variables.env not found, cannot retrieve C2_INTERNAL_IP${NC}"
    C2_INTERNAL_IP="unknown"
fi

CURRENT_STATUS="Fetching Gophish admin password"
show_status
if [ "$VERBOSE" = false ]; then
    GOPHISH_PASSWORD=$(ansible gophish -i inventory.ini -m shell -a "grep 'Please login with the username admin and the password' /opt/gophish/gophish.log | awk '{gsub(/\"/, \"\", \$NF); print \$NF}'" 2>/dev/null | tail -n 1)
else
    GOPHISH_PASSWORD=$(ansible gophish -i inventory.ini -m shell -a "grep 'Please login with the username admin and the password' /opt/gophish/gophish.log | awk '{gsub(/\"/, \"\", \$NF); print \$NF}'" | tail -n 1)
fi
if [ -z "$GOPHISH_PASSWORD" ]; then
    echo -e "${RED}Warning: Could not retrieve Gophish admin password, displaying as unknown${NC}"
    GOPHISH_PASSWORD="unknown"
fi

CURRENT_STATUS="Deployment completed"
show_status
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}C2 Redirector IP: $C2_REDIRECTOR_IP${NC}"
echo -e "${GREEN}C2 Havoc IP: $C2_HAVOC_IP${NC}"
echo -e "${GREEN}Evilginx Server IP: $EVILGINX_SERVER_IP${NC}"
echo -e "${GREEN}Gophish Server IP: $GOPHISH_SERVER_IP${NC}"
echo -e "${GREEN}C2 Internal IP: $C2_INTERNAL_IP (Public IP traffic redirects to this IP on port 8000 when User-Agent is 'ThisIsNotC2' - defined in ansbile/c2_redirector.yml)${NC}"
echo -e "${GREEN}Gophish Admin Password: $GOPHISH_PASSWORD (Login at https://$GOPHISH_SERVER_IP:3333)${NC}"

# Clear traps
trap - INT
