#!/bin/bash

# ========================================
# 🔍 Connection Checker Script
# 여러 .env 파일의 호스트 연결성 테스트
# ========================================

set -e

# 색상 코드 정의
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
BOLD=$'\033[0;1m'
GRAY=$'\033[0;37m'  # 추가
NC=$'\033[0m' # No Color

# 버전 정보 읽기
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="${SCRIPT_DIR}/VERSION"
VERSION="unknown"

# VERSION 파일이 있으면 읽기
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
else
    # VERSION 파일이 없으면 기본값 사용
    VERSION="dev"
fi

# 기본 설정
ENV_FILES=()
VERBOSE=false
TEST_TYPE="all"
LOADED_VARS=()

# 사용법 출력
show_usage() {
    cat << EOF
${CYAN}========================================
🔍 Connection Checker v${VERSION}
========================================${NC}

${GREEN}사용법:${NC} ./check.sh -e <ENV_FILE|DIRECTORY> [옵션]

${GREEN}필수 옵션:${NC}
    -e, --env FILE|DIR  테스트할 .env 파일 또는 디렉토리
                        • 파일: 해당 파일 테스트
                        • 디렉토리: .env*로 시작하는 모든 파일 테스트
                        • 여러 개 지정 가능

${GREEN}선택 옵션:${NC}
    -t, --type TYPE     테스트 타입 [기본: all]
                        • all   : 모든 테스트 수행
                        • ping  : Ping 테스트만
                        • curl  : HTTP/HTTPS 테스트만
                        • dns   : DNS 조회만
                        • tcp   : TCP 포트 연결 테스트만
    -v, --verbose       상세 출력 모드
    -h, --help          이 도움말 출력

${GREEN}지원 형식:${NC}
    • HTTP/HTTPS URL : http://example.com, https://api.example.com
    • TCP 연결       : 172.16.151.7:3306, 192.168.1.100:8080

${GREEN}예제:${NC}
    # 기본 테스트
    -e .env

    # 디렉토리의 모든 .env* 파일 테스트
    -e env/

    # 여러 환경 파일 테스트
    -e .env.dev -e .env.prod

    # TCP 테스트만 수행
    -e .env -t tcp

    # 상세 모드로 실행
    -e .env --verbose

${CYAN}========================================${NC}
EOF
    exit 0
}

# 인자 파싱
parse_args() {
    if [ $# -eq 0 ]; then
        show_usage
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--env)
                if [ -z "$2" ] || [[ "$2" == -* ]]; then
                    echo -e "${RED}❌ 오류: -e 옵션에 파일명 또는 디렉토리가 필요합니다${NC}"
                    exit 1
                fi
                # 디렉토리인 경우 .env로 시작하는 파일들 찾기
                if [ -d "$2" ]; then
                    # 디렉토리에서 .env로 시작하는 파일 찾기
                    shopt -s nullglob
                    env_dir_files=("$2"/.env*)
                    shopt -u nullglob

                    if [ ${#env_dir_files[@]} -eq 0 ]; then
                        echo -e "${YELLOW}⚠️  경고: $2 디렉토리에 .env 파일이 없습니다${NC}"
                    else
                        for file in "${env_dir_files[@]}"; do
                            # 파일인지 확인 (디렉토리 제외)
                            if [ -f "$file" ]; then
                                ENV_FILES+=("$file")
                            fi
                        done
                    fi
                else
                    # 파일인 경우 그대로 추가
                    ENV_FILES+=("$2")
                fi
                shift 2
                ;;
            -t|--type)
                if [ -z "$2" ] || [[ "$2" == -* ]]; then
                    echo -e "${RED}❌ 오류: -t 옵션에 타입이 필요합니다${NC}"
                    exit 1
                fi
                if [[ ! "$2" =~ ^(all|ping|curl|dns|tcp)$ ]]; then  # tcp 추가
                    echo -e "${RED}❌ 오류: 유효하지 않은 테스트 타입: $2${NC}"
                    echo -e "${YELLOW}유효한 타입: all, ping, curl, dns, tcp${NC}"
                    exit 1
                fi
                TEST_TYPE="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_usage
                ;;
            *)
                echo -e "${RED}❌ 알 수 없는 옵션: $1${NC}"
                echo -e "${YELLOW}도움말을 보려면: ./check.sh --help${NC}"
                exit 1
                ;;
        esac
    done

    if [ ${#ENV_FILES[@]} -eq 0 ]; then
        echo -e "${RED}❌ 오류: .env 파일 또는 디렉토리를 지정해야 합니다${NC}"
        echo -e "${YELLOW}사용법: ./check.sh -e <ENV_FILE|DIRECTORY>${NC}"
        echo -e "${YELLOW}도움말: ./check.sh --help${NC}"
        exit 1
    fi
}

# .env 파일 로드 (수정됨)
load_env_file() {
    local env_file=$1
    LOADED_VARS=()
    
    if [ ! -f "$env_file" ]; then
        echo -e "${RED}❌ 파일을 찾을 수 없음: $env_file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}📄 환경파일 로드: $env_file${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"
    
    while IFS='=' read -r key value; do
        # 주석이나 빈 줄 무시
        [[ "$key" =~ ^#.*$ ]] && continue
        [[ -z "$key" ]] && continue
        
        # 앞뒤 공백 및 따옴표 제거
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")

        # http:// 또는 https://로 시작하는 값 찾기
        if [[ "$value" =~ ^https?:// ]]; then
            # 로컬호스트나 변수 참조 제외
            if [ -n "$value" ] && \
               ! [[ "$value" =~ ^\$ ]] && \
               ! [[ "$value" =~ ^https?://(localhost|127.0.0.1|::1) ]]; then

                LOADED_VARS+=("$key=$value")
                echo -e "  ${CYAN}📌 발견:${NC} $key = $value"
            elif [ "$VERBOSE" == "true" ]; then
                echo -e "  ${YELLOW}⏩ 스킵:${NC} $key (로컬 호스트: $value)"
            fi
        # IP:PORT 형식 찾기 (추가)
        elif [[ "$value" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:[0-9]{1,5}$ ]]; then
            LOADED_VARS+=("$key=$value")
            echo -e "  ${CYAN}📌 발견:${NC} $key = $value ${GRAY}(TCP)${NC}"
        fi
    done < <(grep -v '^[[:space:]]*#' "$env_file" | grep '=')
    
    if [ ${#LOADED_VARS[@]} -eq 0 ]; then
        echo -e "  ${YELLOW}⚠️  테스트할 URL이나 TCP 연결을 찾을 수 없습니다${NC}"
    fi
    echo ""
}

# URL/호스트 파싱
parse_host() {
    local input=$1
    # 프로토콜 제거, 경로 제거, 포트 제거
    echo "$input" | sed -e 's|^[^/]*//||' -e 's|/.*$||' -e 's|:.*$||'
}

# IP:PORT 형식 파싱 (추가)
parse_tcp_endpoint() {
    local input=$1
    # IP:PORT 패턴 매칭 (IPv4:port)
    if [[ "$input" =~ ^([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}):([0-9]{1,5})$ ]]; then
        echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
        return 0
    fi
    return 1
}

# TCP 포트 연결 테스트 (추가)
test_tcp() {
    local input=$1
    local name=$2
    
    # IP:PORT 파싱
    local endpoint=$(parse_tcp_endpoint "$input")
    if [ $? -ne 0 ]; then
        # IP:PORT 형식이 아니면 스킵
        return 1
    fi
    
    local host=$(echo "$endpoint" | cut -d' ' -f1)
    local port=$(echo "$endpoint" | cut -d' ' -f2)
    
    echo -e "  ${BOLD}[TCP]${NC} nc $host:$port"
    
    local success=false
    local method=""
    
    # Method 1: nc (netcat) 우선 시도
    if command -v nc &> /dev/null; then
        if timeout 3 nc -zw2 "$host" "$port" &> /dev/null; then
            success=true
            method="nc"
            if [ "$VERBOSE" == "true" ]; then
                echo -e "      Method: netcat (nc)"
                nc -zv "$host" "$port" 2>&1 | sed 's/^/      /'
            fi
        fi
    fi
    
    # Method 2: /dev/tcp fallback
    if [ "$success" == "false" ]; then
        if timeout 3 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
            success=true
            method="/dev/tcp"
            if [ "$VERBOSE" == "true" ]; then
                echo -e "      Method: /dev/tcp (bash built-in)"
            fi
        fi
    fi
    
    # 결과 출력
    if [ "$success" == "true" ]; then
        echo -e "    ${GREEN}✅ 포트 $port 열림${NC} ($method)"
    else
        echo -e "    ${RED}❌ 포트 $port 연결 실패${NC}"
        if [ "$VERBOSE" == "true" ]; then
            echo -e "      호스트에 연결할 수 없거나 포트가 닫혀 있습니다"
        fi
    fi
    
    return $([ "$success" == "true" ] && echo 0 || echo 1)
}

# Ping 테스트
test_ping() {
    local host=$1
    local name=$2

    host=$(parse_host "$host")

    echo -e "  ${BOLD}[PING]${NC} ping $host"
    
    if command -v ping &> /dev/null; then
        if timeout 3 ping -c 1 -W 2 "$host" &> /dev/null; then
            local response_time=$(ping -c 1 "$host" 2>/dev/null | grep 'time=' | sed 's/.*time=\([^ ]*\).*/\1/')
            echo -e "    ${GREEN}✅ 성공${NC} (${response_time})"
            if [ "$VERBOSE" == "true" ]; then
                ping -c 2 "$host" 2>&1 | sed 's/^/      /'
            fi
        else
            echo -e "    ${RED}❌ 실패${NC}"
        fi
    else
        echo -e "    ${YELLOW}⚠️  ping 명령어를 사용할 수 없습니다${NC}"
    fi
}

# DNS 조회 테스트
test_dns() {
    local host=$1
    local name=$2

    host=$(parse_host "$host")

    echo -e "  ${BOLD}[DNS]${NC} nslookup $host"
    
    # nslookup 시도
    if command -v nslookup &> /dev/null; then
        if result=$(timeout 3 nslookup "$host" 2>&1); then
            ip=$(echo "$result" | grep -A1 "Name:" | grep "Address:" | tail -1 | awk '{print $2}')
            if [ -n "$ip" ]; then
                echo -e "    ${GREEN}✅ 성공${NC} → $ip"
            else
                # Alternative parsing for different nslookup output formats
                ip=$(echo "$result" | grep "Address" | tail -1 | awk '{print $NF}')
                if [ -n "$ip" ] && [[ ! "$ip" =~ ^# ]]; then
                    echo -e "    ${GREEN}✅ 성공${NC} → $ip"
                else
                    echo -e "    ${GREEN}✅ 성공${NC}"
                fi
            fi
            if [ "$VERBOSE" == "true" ]; then
                echo "$result" | head -10 | sed 's/^/      /'
            fi
        else
            echo -e "    ${RED}❌ 실패${NC}"
        fi
    # dig 시도
    elif command -v dig &> /dev/null; then
        if result=$(timeout 3 dig +short "$host" 2>&1); then
            if [ -n "$result" ] && [[ ! "$result" =~ "no servers could be reached" ]]; then
                echo -e "    ${GREEN}✅ 성공${NC} → $result"
            else
                echo -e "    ${RED}❌ 실패${NC}"
            fi
        else
            echo -e "    ${RED}❌ 실패${NC}"
        fi
    # host 명령 시도
    elif command -v host &> /dev/null; then
        if result=$(timeout 3 host "$host" 2>&1); then
            echo -e "    ${GREEN}✅ 성공${NC}"
            if [ "$VERBOSE" == "true" ]; then
                echo "$result" | head -5 | sed 's/^/      /'
            fi
        else
            echo -e "    ${RED}❌ 실패${NC}"
        fi
    else
        echo -e "    ${YELLOW}⚠️  DNS 조회 도구를 사용할 수 없습니다${NC}"
    fi
}

# HTTP/HTTPS 테스트
test_curl() {
    local url=$1
    local name=$2

    # 프로토콜이 없으면 https:// 추가
    if [[ ! "$url" =~ ^https?:// ]]; then
        url="https://$url"
    fi

    echo -e "  ${BOLD}[HTTP]${NC} curl $url"
    
    if command -v curl &> /dev/null; then
        if response=$(curl -Is --connect-timeout 3 --max-time 5 "$url" 2>&1); then
            status_line=$(echo "$response" | head -1)
            if [[ "$status_line" =~ HTTP.*\ ([0-9]{3}) ]]; then
                status_code="${BASH_REMATCH[1]}"
                if [[ "$status_code" =~ ^[23] ]]; then
                    echo -e "    ${GREEN}✅ 성공${NC} (HTTP $status_code)"
                else
                    echo -e "    ${GREEN}✅ 연결 성공${NC} ${YELLOW}(HTTP $status_code)${NC}"
                fi
                if [ "$VERBOSE" == "true" ]; then
                    echo "$response" | head -5 | sed 's/^/      /'
                fi
            else
                echo -e "    ${RED}❌ 실패${NC} (응답 없음)"
            fi
        else
            echo -e "    ${RED}❌ 실패${NC} (연결 불가)"
        fi
    else
        echo -e "    ${YELLOW}⚠️  curl 명령어를 사용할 수 없습니다${NC}"
    fi
}

# 테스트 실행 (수정됨)
run_tests() {
    local value=$1
    local key=$2

    echo -e "\n  ${CYAN}🔍 변수: $key=${value}${NC}"

    # Docker 특수 호스트 체크
    if [[ "$value" =~ ^https?://(host\.docker\.internal|docker\.for\.(mac|win)\.localhost) ]]; then
        if [ ! -f /.dockerenv ]; then
            echo -e "    ${YELLOW}⏩ SKIP${NC} - Docker 환경에서만 유효한 호스트입니다"
            return
        fi
    fi

    # IP:PORT 형식인지 확인
    if [[ "$value" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:[0-9]{1,5}$ ]]; then
        # TCP 연결 테스트
        case $TEST_TYPE in
            tcp|all)
                test_tcp "$value" "$key"
                ;;
            *)
                if [ "$VERBOSE" == "true" ]; then
                    echo -e "    ${GRAY}⏩ TCP 테스트 스킵 (현재 타입: $TEST_TYPE)${NC}"
                fi
                ;;
        esac
    # HTTP/HTTPS URL인 경우
    elif [[ "$value" =~ ^https?:// ]]; then
        case $TEST_TYPE in
            ping)
                test_ping "$value" "$key"
                ;;
            dns)
                test_dns "$value" "$key"
                ;;
            curl)
                test_curl "$value" "$key"
                ;;
            tcp)
                # TCP 타입일 때는 HTTP URL 스킵
                if [ "$VERBOSE" == "true" ]; then
                    echo -e "    ${GRAY}⏩ HTTP/HTTPS 테스트 스킵 (TCP 모드)${NC}"
                fi
                ;;
            all|*)
                test_dns "$value" "$key"
                test_ping "$value" "$key"
                test_curl "$value" "$key"
                ;;
        esac
    fi
}

# 메인 함수
main() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}🔍 Connection Checker v${VERSION}"
    echo -e "${GREEN}========================================${NC}\n"
    
    # 실행 환경 정보
    echo -e "${BLUE}📊 실행 환경:${NC}"
    if [ -f /.dockerenv ]; then
        echo -e "  ├─ 🐳 Docker 컨테이너"
    else
        echo -e "  ├─ 💻 호스트 시스템"
    fi
    echo -e "  ├─ 📅 $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "  └─ 🖥️  $(uname -s) $(uname -r)"
    echo ""
    
    # 총 결과 카운터
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    
    # 각 .env 파일 처리
    for env_file in "${ENV_FILES[@]}"; do
        echo -e "${GREEN}========================================${NC}"
        load_env_file "$env_file"
        
        if [ ${#LOADED_VARS[@]} -gt 0 ]; then
            echo -e "${GREEN}테스트 시작 (${#LOADED_VARS[@]}개 대상)${NC}"
            echo -e "${GREEN}----------------------------------------${NC}"
            
            for var in "${LOADED_VARS[@]}"; do
                key="${var%%=*}"
                value="${var#*=}"
                run_tests "$value" "$key"
            done
        fi
        
        echo ""
    done
    
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✨ 연결 테스트 완료!${NC}"
    echo -e "${GREEN}========================================${NC}"
}

# 스크립트 시작
parse_args "$@"
main
