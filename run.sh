#!/bin/bash

#
#   You can also pass some arguments to script to set some these options:
#       --config: change the user and password to grafana and specify the mikrotik IP address
#        stop: stop docker containers
#   For example:
#       sh run.sh --config
#        
#
#

set -e

REPO=Grafana-Mikrotik
ENV_FILE=${ENV_FILE:-.env}
IP=$(grep -R 'MIKROTIK_IP' ./.env | cut -d= -f2)

#? Colors
RED=$(printf '\033[31m')
GREEN=$(printf '\033[32m')
YELLOW=$(printf '\033[33m')
BLUE=$(printf '\033[34m')
BOLD=$(printf '\033[1m')
RESET=$(printf '\033[m') #? No Color

BOLD=$(printf '\033[1m')

#? Docker
DCUID=$(id -u)
DCGID=$(id -g)

ask() {
    local prompt default reply

    if [[ ${2:-} = 'Y' ]]; then
        prompt='Y/n'
        default='Y'
    elif [[ ${2:-} = 'N' ]]; then
        prompt='y/N'
        default='N'
    else
        prompt='y/n'
        default=''
    fi

    while true; do

        #? Ask the question (not using "read -p" as it uses stderr not stdout)
        echo -n "$1 [$prompt] "

        #? Read the answer (use /dev/tty in case stdin is redirected from somewhere else)
        read -r reply </dev/tty

        #? Default?
        if [[ -z $reply ]]; then
            reply=$default
        fi

        #? Check if the reply is valid
        case "$reply" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac
    done
}

command_exists() {
  command -v "$@" >/dev/null 2>&1
}

fmt_error() {
  printf '%sError: %s%s\n' "$BOLD$RED" "$*" "$RESET" >&2
}

helper() {
    if [ "$HELP" = yes ]; then
        cat <<EOF

You can also pass some arguments to script to set some these options:
    --config: change the user and password to grafana and specify the mikrotik IP address
    stop: stop docker containers

For example:
    sh run.sh --config

EOF
        exit 1
    return
    fi
}

clone_git() {

  echo "${BLUE}Git cloning ${REPO}...${RESET}"

  command_exists git || {
    fmt_error "git is not installed"
    exit 1
  }

  git clone --depth=1 https://github.com/IgorKha/$REPO.git \
    || {
    fmt_error "git clone of ${REPO} repo failed"
    exit 1
  }

  echo
}

router_ip() {
    if [ "$CONFIG" = yes ]; then
        echo -e "\n${BLUE}===================================="
        echo -e "\n${BOLD}Prometheus${RESET}\n"
        if ask "Change target mikrotik IP address ? (current ${IP})" Y; then
            read -rp 'Enter target mikrotik IP address: ' IP
            if [ -d "./${REPO}" ]; then
                sed -ri -e '/mikrotik_ip/s/(- ).*( #.*)/\1'"${IP}"'\2/g' \
                ${REPO}/prometheus/prometheus.yml
                sed -ri -e 's/^(MIKROTIK_IP=)(.*)$/\1'"$IP"'/g' "$ENV_FILE"
                echo -e "\n${GREEN}... Prometheus target IP changed to ${IP}"
            else
                sed -ri -e '/mikrotik_ip/s/(- ).*( #.*)/\1'"${IP}"'\2/g' \
                ./prometheus/prometheus.yml
                sed -ri -e 's/^(MIKROTIK_IP=)(.*)$/\1'"$IP"'/g' "$ENV_FILE"
                echo -e "\n${GREEN}... Prometheus target IP changed to ${IP}"
            fi
        return
        fi
        echo -e "\n${BLUE}...Skipped step"
    return
    fi
}

# snmp_on() {
#     if [ "$CONFIG" = yes ]; then
#         echo -e "\n${BLUE}===================================="
#         echo -e "${BOLD}Mikrotik SNMP ACTIVATION${RESET}"
#         if ask "Activate snmp mikrotik using ssh?" N; then
#             read -rp 'Enter login: ' MK_LOGIN
#             # read -rsp 'Enter password: ' MK_PASSWD

#             COMM="
#             snmp
#             "
#             ssh ${MK_LOGIN}@$IP "${COMM}"

#         else
#             echo "skipped"
#         fi
#         return
#     fi
# }

grafana_credentials() {
    if [ "$CONFIG" = yes ]; then
        echo -e "\n${YELLOW}===================================="
        echo -e "\n${BOLD}Grafana${RESET}\n"
        if ask "Change default credentials Grafana ?" N; then
            read -rp 'Enter grafana Username: ' GF_USER
            read -rsp 'Enter grafana Password: ' GF_PASSWD

            sed -ri -e 's/^(GF_ADMIN_USER=)(.*)$/\1'"$GF_USER"'/g' "$ENV_FILE"
            sed -ri -e 's/^(GF_ADMIN_PASSWORD=)(.*)$/\1'"$GF_PASSWD"'/g' "$ENV_FILE"
        else
            echo "Default Grafana:
            User: ${YELLOW}admin${RESET}
            Password: ${YELLOW}mikrotik${RESET}"
        fi
        return
    fi
}

docker() {
    if ! command_exists docker-compose; then
        echo "${YELLOW}docker-compose is not installed.${RESET} Please install docker-compose first."
        echo "https://docs.docker.com/compose/install/"
        exit 1
    else
         if [ "$STOP" = yes ]; then
            if [ -d "./${REPO}" ]; then
                cd ${REPO} && docker-compose down
            else
                docker-compose down
            fi
        else
            if [ -d "./${REPO}" ]; then
                cd ${REPO} && docker-compose up -d
                print_success
            else
                docker-compose up -d
                print_success
            fi
        fi
    fi
}

print_success() {
    echo "============================================="
    echo "${GREEN}Grafana http://localhost:3000"
    echo "Prometheus http://localhost:9090/targets${RESET}"
}

main() {
    #? init
    if [ -d "./${REPO}" ]; then
        ENV_FILE=${REPO}/.env
    else
        if [[ -e $ENV_FILE ]]; then
            :
        else
            clone_git
            ENV_FILE=${REPO}/.env
        fi
    fi

    #? Parse arguments
    while [ $# -gt 0 ]; do
        case $1 in
        --help) HELP=yes;;
        --config) CONFIG=yes ;;
        stop) STOP=yes ;;
        esac
        shift
    done

    helper
    router_ip
    # snmp_on
    grafana_credentials

    # Change UID:GID prometheus container to current user
    sed -ri -e 's/^(CURRENT_USER=)(.*)$/\1'"$DCUID\:$DCGID"'/g' "$ENV_FILE"

    docker

}

main "$@"
