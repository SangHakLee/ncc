# ncc - Network Connection Checker

[![Docker Image Version](https://img.shields.io/docker/v/sanghaklee/ncc?sort=semver&logo=docker)](https://hub.docker.com/r/sanghaklee/ncc)
[![GitHub release](https://img.shields.io/github/release/SangHakLee/ncc.svg?logo=github)](https://github.com/SangHakLee/ncc/releases)
[![GitHub CI](https://github.com/SangHakLee/ncc/workflows/CI/badge.svg)](https://github.com/SangHakLee/ncc/actions)


`.env` 파일에 정의된 **HTTP/HTTPS URL** 및 **TCP** 연결의 네트워크 연결성을 자동으로 테스트하는 도구입니다.

## 주요 기능

- ✅ `.env` 파일에서 자동 검색 및 테스트
  - http://, https://로 시작하는 URL
  - IP:PORT 형식의 TCP 연결 (예: 172.16.151.7:3306)
- Network Connection Check
    - 🔍 DNS 조회 (nslookup/dig/host)
    - 🏓 PING 테스트 (ICMP)
    - 🌐 HTTP/HTTPS 상태 확인 (curl)
    - 🔌 TCP 포트 연결 테스트 (nc(netcat))
- 🐳 Docker 환경 지원 (host network, extra hosts)
- 📁 디렉토리 단위 `.env*` 파일 일괄 테스트
    - 디렉토리를 지정할 시, `.env`로 시작하는 파일만 체크

## 빠른 시작

### Docker 사용 (권장)
```bash
docker pull sanghaklee/ncc:latest
```

```bash
# 단일 .env 파일 테스트
docker run --rm -v $(pwd):/workspace sanghaklee/ncc -e .env

# 디렉토리의 모든 .env* 파일 테스트
docker run --rm -v $(pwd):/workspace sanghaklee/ncc -e ./env/
```
- 호스트 볼륨은 환경에 맞게 수정 ~~$(pwd)~~

### 로컬 실행
```bash
git clone https://github.com/SangHakLee/ncc.git
```


```bash
# 실행 권한 부여
chmod +x check.sh

# 테스트 실행
./check.sh -e .env
```

## 사용법

```bash
./check.sh -e <ENV_FILE|DIRECTORY> [옵션]
```

### 옵션

| 옵션 | 설명 |
|------|------|
| `-e, --env FILE\|DIR` | 테스트할 `.env` 파일 또는 디렉토리 (필수) |
| `-t, --type TYPE` | 테스트 타입: `all`, `ping`, `curl`, `dns` (기본: all) |
| `-v, --verbose` | 상세 출력 모드 |
| `-h, --help` | 도움말 출력 |

#### `-t, --type TYPE`  테스트 타입 설명
- all: 모든 테스트 수행 (기본값)
- dns: DNS 조회만 수행
- ping: PING 테스트만 수행
- curl: HTTP/HTTPS 연결 테스트만 수행
- tcp: TCP 포트 연결 테스트만 수행

### 예제

```bash
# 기본 테스트
./check.sh -e .env

# 디렉토리의 모든 .env* 파일 테스트
./check.sh -e ./env/

# 여러 파일 테스트
./check.sh -e .env.dev -e .env.prod

# HTTP 테스트만 수행
./check.sh -e .env -t curl

# TCP 포트 테스트만 수행
./check.sh -e .env -t tcp

# 상세 모드
./check.sh -e .env --verbose
```

## Docker 네트워크 설정

### 호스트 네트워크 모드
호스트의 네트워크를 직접 사용
- Docker 기본 네트워크인 [bridge](https://docs.docker.com/engine/network/drivers/bridge) 사용하는 경우 네트워크가 격리된다.
- 이 때, https://www.google.com 같은 외부 호스트는 NAT 이용해서 접근할 수 있는데, DNS에 등록하지 않고 컨테이너가 올라간 호스트 수준에서 설정한 Private한 네트워크는 접근할 수 없다.
- 이 때 컨테이너가 돌고 있는 호스트의 네트워크를 이용해서 통신하면 **호스트 수준에서 .env 파일에 명시된 호스트와 IP에 접근할 수 있는지 확인할 수 있다.**

```bash
docker run --rm --network host \
  -v /opt/app/:/workspace \
  sanghaklee/ncc -e .env
```

### Bridge + Extra Hosts
커스텀 호스트 추가 사용
- `호스트 네트워크 모드`를 사용하지 않고 각 서비스들은 별도의 bridge 네트워크를 갖는 경우가 많다.
- 이 때, 컨테이너 내부에서 사설-IP 등으로 사용하는 IP들은 컨테이너 내부에서 호스트를 등록해서 쓴다.
    ```bash
    # /etc/hosts
    my.db.com 192.168.100.5
    ```
- 이 환경을 테스트하고 싶은 경우 아래와 같이 `--add-host`로 docker run 시 사용할 호스트를 명시해준다.

```bash
docker run --rm \
  --add-host api.local:192.168.1.100 \
  --add-host db.local:192.168.1.200 \
  -v $(pwd):/workspace \
  sanghaklee/ncc -e .env
```

## .env 파일 형식

### HTTP/HTTPS URL
`http://` 또는 `https://`로 시작하는 값

```bash
# API 서버
API_URL=https://api.example.com
API_ENDPOINT=https://api.example.com/v1/health

# 인증 서버
AUTH_URL=https://auth.example.com
KEYCLOAK_URI=https://keycloak.example.com

# 기타 서비스
WEBHOOK_URL=https://hooks.slack.com/services/xxx
MONITORING_URL=https://grafana.example.com
```

### TCP 연결 (IP:PORT)
IPv4:PORT 형식의 값

```bash
# 데이터베이스
MYSQL_HOST=172.16.151.7:3306
POSTGRES_HOST=172.16.151.8:5432

# 캐시 서버
REDIS_HOST=172.16.151.9:6379
MEMCACHED_HOST=172.16.151.10:11211

# 기타 서비스
CUSTOM_SERVICE=192.168.1.100:8080
MESSAGE_QUEUE=10.0.0.50:5672
```

### 자동으로 스킵되는 값들
```bash
DB_HOST=mysql.example.com          # http/https나 IP:PORT 형식이 아님
LOCAL_API=http://localhost:8000    # localhost
INTERNAL_API=http://127.0.0.1:3000 # 127.0.0.1
PLACEHOLDER_URL=$API_URL           # 변수 참조
HOSTNAME=my-server                 # 단순 호스트명
PORT=3000                          # 단순 포트 번호
```

## 출력 예시

```
  🔍 변수: API_URL=https://api.example.com
  [DNS] nslookup api.example.com
    ✅ 성공 → 93.184.216.34
  [PING] ping api.example.com
    ✅ 성공 (23.4 ms)
  [HTTP] curl https://api.example.com
    ✅ 성공 (HTTP 200)

  🔍 변수: DB_MYSQL=127.0.0.1:3306
  [TCP] nc 127.0.0.1:3306
    ✅ 포트 3306 열림 (nc)

  🔍 변수: DB_POSTGRE=127.0.0.1:5432
  [TCP] nc 127.0.0.1:5432
    ❌ 포트 3309 연결 실패
```