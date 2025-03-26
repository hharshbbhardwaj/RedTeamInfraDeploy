#!/bin/bash

# refresh.sh

# Colors for output
RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
NC='\033[0m'

CURRENT_STATUS="Starting refresh process"

show_status() { echo -e "${BLUE}Current Status: $CURRENT_STATUS${NC}"; }
trap 'show_status' INT

echo -e "${BLUE}Starting refresh of existing files to sample state...${NC}"

CURRENT_STATUS="Resetting variables.env"
show_status
if [ -f "variables.env" ]; then
    cat > variables.env <<EOF
# CHANGE THIS
# DigitalOcean API token for Terraform authentication
export DO_TOKEN="your_digitalocean_token_here"

# CHANGE THIS
# Name of the SSH key used in DigitalOcean GUI and base filename of the private key in keys/ (e.g., my_key for my_key.pem)
export SSH_KEY_NAME="my_key"

# CHANGE THIS
# Add new domain variables
export C2_REDIRECTOR_DOMAIN="c2-redirectordomain.com"
export EVILGINX_DOMAIN="evilginxdomain.com"

# These IPs will be updated by the deploy.sh script after running Terraform
# Initial placeholders, will be replaced by actual IPs
export C2_REDIRECTOR_IP="A.A.A.A"
export C2_HAVOC_IP="B.B.B.B"
export EVILGINX_SERVER_IP="C.C.C.C"
export GOPHISH_SERVER_IP="D.D.D.D"
export C2_INTERNAL_IP="E.E.E.E"
EOF
    echo -e "${GREEN}variables.env reset successfully${NC}"
else
    echo -e "${RED}Error: variables.env not found!${NC}"
    exit 1
fi

CURRENT_STATUS="Resetting terraform/provider.tf SSH key name"
show_status
if [ -f "terraform/provider.tf" ]; then
    sed -i 's/name = ".*"/name = "my_key"/' terraform/provider.tf
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}terraform/provider.tf SSH key name reset successfully${NC}"
    else
        echo -e "${RED}Error: Failed to update terraform/provider.tf${NC}"
        exit 1
    fi
else
    echo -e "${RED}Error: terraform/provider.tf not found!${NC}"
    exit 1
fi

CURRENT_STATUS="Checking terraform/main.tf"
show_status
if [ ! -f "terraform/main.tf" ]; then
    echo -e "${RED}Error: terraform/main.tf not found!${NC}"
    exit 1
fi

CURRENT_STATUS="Resetting ansible/inventory.ini"
show_status
if [ -f "ansible/inventory.ini" ]; then
    cat > ansible/inventory.ini <<EOF
[c2_redirector]
A.A.A.A ansible_user=root ansible_ssh_private_key_file=$PWD/keys/my_key

[c2_havoc]
B.B.B.B ansible_user=root ansible_ssh_private_key_file=$PWD/keys/my_key

[evilginx]
C.C.C.C ansible_user=root ansible_ssh_private_key_file=$PWD/keys/my_key

[gophish]
D.D.D.D ansible_user=root ansible_ssh_private_key_file=$PWD/keys/my_key
EOF
    echo -e "${GREEN}ansible/inventory.ini reset successfully${NC}"
else
    echo -e "${RED}Error: ansible/inventory.ini not found!${NC}"
    exit 1
fi

CURRENT_STATUS="Resetting Ansible playbooks"
show_status

if [ -f "ansible/c2_redirector.yml" ]; then
    sed -i "s/domain: .*/domain: \"c2-redirectordomain.com\"/" ansible/c2_redirector.yml
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}ansible/c2_redirector.yml reset successfully${NC}"
    else
        echo -e "${RED}Error: Failed to reset domain in ansible/c2_redirector.yml${NC}"
        exit 1
    fi
else
    echo -e "${RED}Error: ansible/c2_redirector.yml not found!${NC}"
    exit 1
fi

if [ -f "ansible/evilginx_tmux.yml" ]; then
    sed -i "s/domain: .*/domain: \"evilginxdomain.com\"/" ansible/evilginx_tmux.yml
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}ansible/evilginx_tmux.yml reset successfully${NC}"
    else
        echo -e "${RED}Error: Failed to reset domain in ansible/evilginx_tmux.yml${NC}"
        exit 1
    fi
else
    echo -e "${RED}Error: ansible/evilginx_tmux.yml not found!${NC}"
    exit 1
fi

for file in c2_havoc_tmux.yml gophish_tmux.yml; do
    if [ ! -f "ansible/$file" ]; then
        echo -e "${RED}Error: ansible/$file not found!${NC}"
        exit 1
    fi
done
echo -e "${GREEN}ansible/c2_havoc_tmux.yml and gophish_tmux.yml checked${NC}"

CURRENT_STATUS="Refresh completed"
show_status
echo -e "${GREEN}All files reset to sample state successfully!${NC}"
trap - INT
