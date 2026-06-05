# Sunshine Docker - NVIDIA GPU Game Streaming

Moonlight/Sunshine 게임 스트리밍 서버를 Docker로 격리 실행.

RTX 5080 + NVENC + X11 캡처 + 자동 시작(systemd) 지원.

## 요구사항

- NVIDIA GPU (RTX 20xx 이상 권장)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
- Docker & docker-compose
- X11 디스플레이 서버

## 빠른 시작

```bash
# 1. 클론
git clone <repo-url> sunshine-docker
cd sunshine-docker

# 2. 설정 편집 (디스플레이, 인코더 등)
vim config/sunshine.conf

# 3. 빌드 & 실행
docker-compose up -d

# 4. Web UI 접속 → 사용자/비밀번호 설정
# https://localhost:47990
```

## 부팅 시 자동 시작

```bash
sudo cp sunshine-docker.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now sunshine-docker.service
```

## 설정

`config/sunshine.conf`에서 주요 옵션:

| 옵션 | 기본값 | 설명 |
|------|--------|------|
| `encoder` | `nvenc` | 인코더 (nvenc / vaapi / software) |
| `fps` | `60` | 프레임레이트 |
| `bitrate` | `50000` | 비트레이트 (kbps) |
| `capture` | `x11` | 캡처 방식 (x11 / nvfbc / kms) |
| `output_name` | `1` | 출력 디스플레이 번호 (`xrandr`로 확인) |
| `origin_pin_allowed` | `true` | PIN 인증 허용 |

## 파일 구조

```
sunshine-docker/
├── Dockerfile              # 커스텀 이미지 (X11/Avahi/PulseAudio 추가)
├── docker-compose.yml      # 서비스 정의
├── sunshine-docker.service # systemd 유닛 (자동 시작)
├── config/
│   └── sunshine.conf       # Sunshine 설정 파일
└── README.md
```

## 문제 해결

```bash
# 로그 확인
docker logs sunshine

# 컨테이너 재시작
docker-compose restart

# 디스플레이 목록 확인
xrandr --listmonitors

# GPU 인식 확인
docker exec sunshine nvidia-smi
```

## 포트

| 포트 | 용도 |
|------|------|
| 47984 | Web UI (HTTPS) |
| 47989 | HTTP |
| 47990 | HTTPS |
| 48010 | RTSP |

## 라이선스

MIT
