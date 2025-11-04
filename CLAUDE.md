# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Network Connection Checker (nc) is a bash-based tool for validating network connectivity to hosts and URLs defined in `.env` files. It performs DNS lookups, ping tests, and HTTP/HTTPS requests to verify that external services and dependencies are reachable.

## Core Architecture

### Main Script: `check.sh`

The core logic resides in a single bash script (`check.sh`) that:

1. **Parses `.env` files** - Identifies variables matching patterns: `*_HOST`, `*_URL`, `*_ENDPOINT`, `*_URI`, `*_ADDRESS`
2. **Performs three types of connectivity tests**:
   - DNS resolution (using `nslookup`, `dig`, or `host`)
   - ICMP ping tests (using `ping`)
   - HTTP/HTTPS requests (using `curl`)
3. **Supports multiple execution modes**:
   - Native bash execution
   - Docker containerized execution (Alpine-based)
   - Makefile shortcuts

### Environment Variable Pattern Matching

The script specifically looks for environment variables with these suffixes/patterns:
- `*_HOST` - Host addresses (e.g., `DB_HOST=mysql.example.com`)
- `*_URL` - Full URLs (e.g., `API_URL=https://api.example.com`)
- `*_ENDPOINT` - API endpoints
- `*_URI` - URIs (e.g., database connection strings)
- `*_ADDRESS` - Server addresses

Variables containing local references (`localhost`, `127.0.0.1`, `::1`) or placeholders (`null`, `undefined`, `$VARIABLE`) are automatically skipped.

## Commands

### Running Tests

**Host execution** (requires bash, curl, ping, nslookup/dig/host):
```bash
./check.sh -e .env                    # Test single .env file
./check.sh -e .env.dev -e .env.prod   # Test multiple files
./check.sh -e .env -t ping            # Run only ping tests
./check.sh -e .env -t dns             # Run only DNS tests
./check.sh -e .env -t curl            # Run only HTTP tests
./check.sh -e .env --verbose          # Verbose output
```

**Docker execution**:
```bash
# Using pre-built image
docker build -t connection-checker .
docker run --rm -v $(pwd):/workspace connection-checker -e .env

# Using Alpine directly
docker run --rm -v $(pwd):/workspace alpine:latest \
    sh -c "apk add --no-cache curl bash bind-tools iputils && \
           bash /workspace/check.sh -e .env"
```

**Makefile shortcuts**:
```bash
make test          # Run on host with .env file
make test-docker   # Run in Docker with .env file
make build-docker  # Build Docker image
make clean         # Remove log files
```

### Test Types

- `all` (default) - Runs DNS, ping, and HTTP tests (HTTP only for URL/ENDPOINT/URI variables)
- `ping` - ICMP ping only
- `dns` - DNS resolution only
- `curl` - HTTP/HTTPS requests only

## Docker Configuration

The project uses a minimal Alpine Linux base image (`alpine:3.18`) with these dependencies:
- `bash` - Shell interpreter
- `curl` - HTTP testing
- `bind-tools` - DNS utilities (nslookup, dig)
- `iputils` - Ping utility
- `ca-certificates` - SSL certificate validation

The Dockerfile sets `/workspace` as the working directory for volume mounts and `/app/check.sh` as the entrypoint.

## Expected .env Format

```bash
# Database connections
DB_HOST=mysql.example.com
DATABASE_URL=postgres://db.example.com:5432/mydb

# API endpoints
API_HOST=api.example.com
API_URL=https://api.example.com
API_ENDPOINT=https://api.example.com/v1

# Other services
REDIS_HOST=redis.example.com
ELASTIC_HOST=elastic.example.com

# These will be skipped:
LOCAL_HOST=localhost           # Local reference
INTERNAL_HOST=127.0.0.1       # Local IP
PLACEHOLDER_URL=$API_URL      # Variable reference
```

## Development Notes

### Script Structure

The script follows a modular function-based architecture:
- `parse_args()` - Command-line argument parsing
- `load_env_file()` - Loads and filters environment variables
- `parse_host()` - Extracts hostnames from URLs
- `test_ping()`, `test_dns()`, `test_curl()` - Individual test functions
- `run_tests()` - Test orchestration based on type
- `main()` - Entry point and flow control

### Error Handling

The script uses `set -e` for strict error handling and includes:
- File existence validation
- Command availability checks (gracefully handles missing tools)
- Timeout protection (3-5 second timeouts on network operations)
- Input validation for arguments

### Color Coding

Output uses ANSI color codes for visual clarity:
- GREEN: Success/headers
- RED: Failures
- YELLOW: Warnings/test labels
- BLUE: Information
- CYAN: Discovered hosts

### Test Execution Logic

HTTP tests are conditionally applied:
- Only variables matching `*URL`, `*ENDPOINT`, `*URI` patterns get HTTP tested
- Variables beginning with `http://` or `https://` are also HTTP tested
- All other hosts get DNS + ping only
