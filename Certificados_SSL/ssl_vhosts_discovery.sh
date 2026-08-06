#!/bin/bash
###########################################################################
#
# Nome        : ssl_vhosts_discovery
# Descricao   : Descobre vhosts SSL ativos em Apache e Nginx com validacao DNS
# Author      : Jose Edson Moreno Jr.
# Email       : edson.moreno@gmail.com
# Versao      : 0.3 - 20260630
# Data        : 30/06/2026
# Copyright   : (C) 2026 by Edson Moreno
# Dependencia :
# Parametros  : prog
# Uso ./ssl_vhosts_discovery.sh <opcao>
# Opcoes:
#    -d          : enable debug output
#    -v          : show the plugin version
#    -h          : Show this help
#
# CHANGELOG   :
# 30/06/2026: Adiciona deduplicacao por host/porta e valida apontamento DNS local
############################################################################

VERSION=$(grep -E "^# Versao" "$0" | awk -F': ' '{print $2}')
PROGNAME="$0"
DEBUG="false"
declare -A LOCAL_IPS
declare -A SEEN_VHOSTS

show_version() {
    echo "$PROGNAME $VERSION"
}

show_help() {
    echo "Usage $PROGNAME [-d|--debug] [-v|--version] [-h|--help], where:"
    echo "-d: enable debug output"
    echo "-v: show the plugin version"
    echo "-h: Show this help"
    echo
    echo "Optional environment:"
    echo "SSL_DISCOVERY_EXTRA_LOCAL_IPS: space/comma separated IPs accepted as local"
}

writeDebug() {
    [ "$DEBUG" = "true" ] && echo "$1" >&2
}

normalize_vhost_name() {
    local name="$1"

    name="${name%%#*}"
    name="${name%%:*}"
    name="${name%.}"
    name="${name,,}"

    printf "%s" "$name"
}

is_ignored_vhost_name() {
    local name="$1"

    [[ -z "$name" ]] && return 0
    [[ "$name" == "_" ]] && return 0
    [[ "$name" == "*" ]] && return 0
    [[ "$name" == "_default_" ]] && return 0
    [[ "$name" == "~"* ]] && return 0
    [[ "$name" == "~^"* ]] && return 0
    [[ "$name" == .* ]] && return 0
    [[ "$name" == "*."* ]] && return 0
    [[ "$name" == *'$'* ]] && return 0

    return 1
}

load_local_ips() {
    local ip_addr=""
    local extra_ip=""

    while read -r ip_addr; do
        [ -n "$ip_addr" ] && LOCAL_IPS["$ip_addr"]=1
    done < <(
        if command -v ip >/dev/null 2>&1; then
            ip -o addr show scope global 2>/dev/null | awk '{ split($4, addr, "/"); print addr[1] }'
        fi

        hostname -I 2>/dev/null | tr ' ' '\n'
    )

    for extra_ip in ${SSL_DISCOVERY_EXTRA_LOCAL_IPS//,/ }; do
        [ -n "$extra_ip" ] && LOCAL_IPS["$extra_ip"]=1
    done
}

host_points_to_local_machine() {
    local host="$1"
    local resolved_ip=""
    local matched="false"

    if [[ "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ || "$host" == *:* ]]; then
        if [[ -n "${LOCAL_IPS[$host]:-}" ]]; then
            return 0
        fi

        writeDebug "Ignorando $host: IP nao pertence a esta maquina"
        return 1
    fi

    while read -r resolved_ip; do
        [ -z "$resolved_ip" ] && continue
        if [[ -n "${LOCAL_IPS[$resolved_ip]:-}" ]]; then
            matched="true"
            break
        fi
    done < <(getent ahosts "$host" 2>/dev/null | awk '{ print $1 }' | sort -u)

    if [ "$matched" = "true" ]; then
        return 0
    fi

    writeDebug "Ignorando $host: DNS nao aponta para IP local"
    return 1
}

filter_valid_unique_vhosts() {
    local webserver=""
    local raw_name=""
    local port=""
    local cert=""
    local name=""
    local key=""

    load_local_ips

    while IFS='|' read -r webserver raw_name port cert; do
        name=$(normalize_vhost_name "$raw_name")

        if is_ignored_vhost_name "$name"; then
            writeDebug "Ignorando $raw_name: nome generico, wildcard, regex ou vazio"
            continue
        fi

        if ! host_points_to_local_machine "$name"; then
            continue
        fi

        key="${name}|${port}"
        if [[ -n "${SEEN_VHOSTS[$key]:-}" ]]; then
            writeDebug "Ignorando $name:$port: vhost duplicado"
            continue
        fi

        SEEN_VHOSTS["$key"]=1
        printf "%s|%s|%s|%s\n" "$webserver" "$name" "$port" "$cert"
    done
}

list_apache_config_files() {
    find -L /etc/apache2/sites-enabled /etc/httpd/conf.d /etc/httpd/sites-enabled \
        -maxdepth 1 \( -type f -o -type l \) 2>/dev/null | sort -u
}

list_nginx_config_files() {
    find -L /etc/nginx/sites-enabled /etc/nginx/conf.d \
        -maxdepth 1 \( -type f -o -type l \) 2>/dev/null | sort -u
}

discover_apache_ssl_vhosts() {
    local apache_files=()

    mapfile -t apache_files < <(list_apache_config_files)
    [ "${#apache_files[@]}" -eq 0 ] && return 0

    writeDebug "Apache detectado via arquivos de configuracao"

    awk '
        function trim(v) {
            sub(/^[[:space:]]+/, "", v)
            sub(/[[:space:]]+$/, "", v)
            return v
        }

        function reset_vhost() {
            in_vhost = 0
            ssl_vhost = 0
            port = ""
            cert = ""
            names = ""
        }

        function emit_vhost(    count, i, name) {
            if (!in_vhost || !ssl_vhost || names == "" || port == "") {
                return
            }

            count = split(names, arr, /[[:space:]]+/)
            for (i = 1; i <= count; i++) {
                name = arr[i]
                if (name == "" || name == "*" || name == "_default_") {
                    continue
                }
                printf "apache|%s|%s|%s\n", name, port, cert
            }
        }

        BEGIN {
            reset_vhost()
        }

        /^[[:space:]]*<VirtualHost[[:space:]]+/ {
            reset_vhost()
            in_vhost = 1

            line = $0
            if (match(line, /:([0-9]{2,5})>/, m)) {
                port = m[1]
            }
            next
        }

        /^[[:space:]]*<\/VirtualHost>/ {
            emit_vhost()
            reset_vhost()
            next
        }

        {
            if (!in_vhost) {
                next
            }

            line = $0
            sub(/[[:space:]]*#.*/, "", line)

            if (line ~ /^[[:space:]]*SSLEngine[[:space:]]+on([[:space:]]|$)/) {
                ssl_vhost = 1
            }

            if (line ~ /^[[:space:]]*SSLCertificateFile[[:space:]]+/) {
                ssl_vhost = 1
                sub(/^[[:space:]]*SSLCertificateFile[[:space:]]+/, "", line)
                cert = trim(line)
            }

            if (line ~ /^[[:space:]]*ServerName[[:space:]]+/) {
                sub(/^[[:space:]]*ServerName[[:space:]]+/, "", line)
                names = trim(line)
            }

            if (line ~ /^[[:space:]]*ServerAlias[[:space:]]+/) {
                sub(/^[[:space:]]*ServerAlias[[:space:]]+/, "", line)
                line = trim(line)
                if (names == "") {
                    names = line
                } else {
                    names = names " " line
                }
            }
        }
    ' "${apache_files[@]}"
}

discover_nginx_ssl_vhosts() {
    local nginx_files=()

    mapfile -t nginx_files < <(list_nginx_config_files)
    [ "${#nginx_files[@]}" -eq 0 ] && return 0

    writeDebug "Nginx detectado via arquivos de configuracao"

    awk '
        function trim(v) {
            sub(/^[[:space:]]+/, "", v)
            sub(/[[:space:]]+$/, "", v)
            return v
        }

        function reset_server() {
            in_server = 0
            depth = 0
            ssl_server = 0
            port = ""
            cert = ""
            names = ""
        }

        function emit_server(    count, i, name) {
            if (!in_server || !ssl_server || names == "") {
                return
            }

            count = split(names, arr, /[[:space:]]+/)
            for (i = 1; i <= count; i++) {
                name = arr[i]
                if (name == "" || name == "_" || name == "*") {
                    continue
                }
                printf "nginx|%s|%s|%s\n", name, (port == "" ? "443" : port), cert
            }
        }

        BEGIN {
            reset_server()
        }

        /^[[:space:]]*server[[:space:]]*\{/ {
            reset_server()
            in_server = 1
            depth = 1
            next
        }

        {
            if (!in_server) {
                next
            }

            line = $0
            sub(/[[:space:]]*#.*/, "", line)

            opens = gsub(/\{/, "{", line)
            closes = gsub(/\}/, "}", line)

            if (line ~ /^[[:space:]]*listen[[:space:]]+/) {
                listen_line = line
                gsub(/;/, "", listen_line)
                if (listen_line ~ /(^|[[:space:]:])443([[:space:]]|$)/ || listen_line ~ /[[:space:]]ssl([[:space:]]|$)/) {
                    ssl_server = 1
                    if (match(listen_line, /([0-9]{2,5})/, m)) {
                        port = m[1]
                    } else if (port == "") {
                        port = "443"
                    }
                }
            }

            if (line ~ /^[[:space:]]*server_name[[:space:]]+/) {
                sub(/^[[:space:]]*server_name[[:space:]]+/, "", line)
                gsub(/;/, "", line)
                names = trim(line)
            }

            if (line ~ /^[[:space:]]*ssl_certificate[[:space:]]+/) {
                sub(/^[[:space:]]*ssl_certificate[[:space:]]+/, "", line)
                gsub(/;/, "", line)
                cert = trim(line)
                ssl_server = 1
            }

            depth += opens - closes
            if (depth <= 0) {
                emit_server()
                reset_server()
            }
        }
    ' "${nginx_files[@]}"
}

emit_json() {
    awk -F'|' '
        function esc(v) {
            gsub(/\\/,"\\\\",v)
            gsub(/"/,"\\\"",v)
            return v
        }

        BEGIN {
            print "{\"data\":["
        }

        {
            if (NR > 1) {
                printf ","
            }

            printf "{\"{#WEBSERVER}\":\"%s\",\"{#SSL_VHOST}\":\"%s\",\"{#SSL_PORT}\":\"%s\",\"{#SSL_CERT}\":\"%s\"}",
                esc($1), esc($2), esc($3), esc($4)
        }

        END {
            print "]}"
        }
    '
}

while (( "$#" )); do
    case "$1" in
        -d|--debug)
            DEBUG="true"
            writeDebug "Debug enabled!"
            ;;
        -h|--help)
            show_help
            exit 1
            ;;
        -v|--version)
            show_version
            exit 1
            ;;
    esac
    shift
done

{
    discover_apache_ssl_vhosts
    discover_nginx_ssl_vhosts
} | sort -u | filter_valid_unique_vhosts | emit_json

exit 0
