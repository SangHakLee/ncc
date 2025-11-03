# Alpine Linux 기반 가벼운 이미지
FROM alpine:3.18


# 필요한 패키지 설치
RUN apk add --no-cache \
    bash \
    curl \
    bind-tools \
    iputils \
    ca-certificates \
    coreutils \
    && rm -rf /var/cache/apk/*

# 작업 디렉토리 설정
WORKDIR /app

# 스크립트 복사
COPY check.sh /app/check.sh

# 실행 권한 부여
RUN chmod +x /app/check.sh

# 마운트 포인트
WORKDIR /workspace

# 엔트리포인트
ENTRYPOINT ["/app/check.sh"]

# 기본 명령 (도움말 표시)
CMD ["--help"]
