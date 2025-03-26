#!/bin/bash

# destroy.sh

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
        *) echo -e "${RED}Unknown option: $1${NC}" >&2; exit 1 ;;
    esac
done

if [ "$VERBOSE" = false ]; then
    terraform_output() {
        "$@" > /dev/null 2>&1
    }
else
    terraform_output() {
        "$@"
    }
fi

show_status() {
    echo -e "\n${BLUE}Current Status: $CURRENT_STATUS${NC}\n" >&2
}

# Trap for interrupts
trap 'echo -e "\n${RED}Script interrupted by CTRL+C${NC}" >&2; show_status; exit 1' INT

CURRENT_STATUS="Checking for variables.env"
show_status
if [ ! -f "variables.env" ]; then
    echo -e "${RED}Error: variables.env not found!${NC}" >&2
    exit 1
fi

CURRENT_STATUS="Loading variables"
show_status
source ./variables.env

if [ -z "$DO_TOKEN" ] || [ -z "$SSH_KEY_NAME" ]; then
    echo -e "${RED}Error: DO_TOKEN and SSH_KEY_NAME must be set in variables.env${NC}" >&2
    exit 1
fi

CURRENT_STATUS="Changing to terraform directory"
show_status
cd terraform || {
    echo -e "${RED}Error: Cannot change to terraform directory${NC}" >&2
    exit 1
}

CURRENT_STATUS="Checking Terraform state"
show_status
if ! terraform state list > /dev/null 2>&1; then
    echo -e "${GREEN}No Terraform resources to destroy. Exiting...${NC}" >&2
    cd ..
    exit 0
fi

CURRENT_STATUS="Initializing Terraform"
show_status
terraform_output terraform init

CURRENT_STATUS="Destroying Terraform configuration"
show_status
terraform_output terraform destroy -auto-approve \
    -var "do_token=${DO_TOKEN}" \
    -var "ssh_key_name=${SSH_KEY_NAME}"

CURRENT_STATUS="Destruction completed"
show_status
echo -e "${GREEN}Terraform resources destroyed successfully!${NC}" >&2

# Clear the trap
trap - INT

cd ..
