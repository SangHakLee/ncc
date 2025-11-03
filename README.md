# ncc - Network Connection Checker

`.env` 파일에 정의된 HTTP/HTTPS URL들의 네트워크 연결성을 자동으로 테스트하는 도구입니다.

## 주요 기능

- ✅ `.env` 파일에서 `http://`, `https://`로 시작하는 URL 자동 검색
- Network Connection Check
    - 🔍 DNS 조회 (nslookup/dig/host)
    - 🏓 PING 테스트 (ICMP)
    - 🌐 HTTP/HTTPS 상태 확인 (curl)
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

# 상세 모드
./check.sh -e .env --verbose
```

## Docker 네트워크 설정

### 호스트 네트워크 모드
호스트의 네트워크를 직접 사용
- Docker 기본 네트워크인 [bridge](https://docs.docker.com/engine/network/drivers/bridge) 사용하는 경우 네트워크가 격리된다.
- 이 때, https://www.google.com 같은 외부 호스트는 NAT 이용해서 접근할 수 있는데, DNS에 등록하지 않고 컨테이너가 올라간 호스트 수준에서 설정한 Private한 네트워크는 접근할 수 없다.
- 이 때 컨테이너가 돌고 있는 호스트의 네트워크를 이용해서 통신하면 **호스트 수준에서 .env 파일에 접근할 수 있는지 확인할 수 있다.**

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

`http://` 또는 `https://`로 시작하는 값만 자동으로 테스트됩니다.

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

# 이런 값들은 자동으로 스킵됩니다
DB_HOST=mysql.example.com          # http/https 없음
LOCAL_API=http://localhost:8000    # localhost
PLACEHOLDER_URL=$API_URL           # 변수 참조
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
```