#!/bin/sh
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
        if ask "Change target mikrotik IP address ?" Y; then
            read -p 'Enter target mikrotik IP address: ' IP
            if [ -d "./${REPO}" ]; then
                sed -i -e 's/192.168.88.1/'"${IP}"'/g' \
                ${REPO}/prometheus/prometheus.yml
                sed -ri -e 's/^(MIKROTIK_IP=)(.*)$/\1'"$IP"'/g' ${REPO}/$ENV_FILE
            else
                sed -i -e 's/192.168.88.1/'"${IP}"'/g' \
                ./prometheus/prometheus.yml
                sed -ri -e 's/^(MIKROTIK_IP=)(.*)$/\1'"$IP"'/g' $ENV_FILE
            fi
        return
        fi
        return
    fi
}

grafana_credentials() {
    if [ "$CONFIG" = yes ]; then
        echo "${YELLOW}Grafana${RESET}"
        if ask "Change default credentials Grafana ?" N; then
            read -p 'Enter grafana Username: ' GF_USER
            read -sp 'Enter grafana Password: ' GF_PASSWD

            sed -ri -e 's/^(GF_ADMIN_USER=)(.*)$/\1'"$GF_USER"'/g' $ENV_FILE
            sed -ri -e 's/^(GF_ADMIN_PASSWORD=)(.*)$/\1'"$GF_PASSWD"'/g' $ENV_FILE
        else
            echo "Default Grafana:
            User: ${YELLOW}admin${RESET}
            Password: ${YELLOW}mikrotik\n${RESET}"
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
    echo "${YELLOW}Grafana http://localhost:3000${RESET}"
    echo "${BLUE}Prometheus http://localhost:9090/targets${RESET}"
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
    grafana_credentials

    # Change UID:GID prometheus container to current user
    sed -ri -e 's/^(CURRENT_USER=)(.*)$/\1'"$DCUID\:$DCGID"'/g' $ENV_FILE

    docker

}

main "$@"
