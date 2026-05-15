#!/bin/bash
# sync-agent-plugin GitHub 업로드 스크립트
# 사용법: 이 파일을 직접 실행하거나, 한 줄씩 복사해서 터미널에 붙여넣기
#
#   chmod +x setup-and-push.sh && ./setup-and-push.sh
#
# 또는 한 줄씩:
#   cd ~/Documents/obsidian_vault/SyncAgentDocs
#   (아래 명령어 순서대로)

set -e
cd "$(dirname "$0")"

echo "📁 작업 폴더: $(pwd)"
echo ""

# 1. sandbox에서 만들다 만 부분 .git 정리
if [ -d ".git" ]; then
  echo "🧹 기존 .git 폴더 정리 중 (sandbox 잔여물 제거)..."
  rm -rf .git
fi

# 2. git 초기화 + 커밋
echo "🌱 git 초기화..."
git init -b main
git config user.name "juwon.cha"
git config user.email "juwon.cha@teamsparta.co"

echo ""
echo "📦 파일 staging..."
git add .

echo ""
echo "📝 첫 커밋..."
git commit -m "Initial commit: sync-agent plugin

- Plugin manifest (.claude-plugin/plugin.json, marketplace.json)
- /sync command: Unity 프로젝트 간 시스템 sync 워크플로우 (Phase 0-6)
- /sync-init command: TO 프로젝트 컨벤션 자동 감지 + 가이드 생성
- _SYNC_GUIDE.template.md: 프로젝트별 가이드 템플릿
- 16개 변환 규칙 + 호출 그래프 역추적 + 8개 결선 체크리스트
- README.md: 설치/사용/트러블슈팅"

# 3. remote 설정 + push
echo ""
echo "🔗 remote 추가..."
git remote add origin git@github.com:juwon-cha-rocketdan/sync-agent-plugin.git || \
  git remote set-url origin git@github.com:juwon-cha-rocketdan/sync-agent-plugin.git

echo ""
echo "🚀 GitHub로 push..."
git push -u origin main

echo ""
echo "✅ 완료!"
echo ""
echo "📤 동료에게 공유할 두 줄:"
echo ""
echo "    /plugin marketplace add juwon-cha-rocketdan/sync-agent-plugin"
echo "    /plugin install sync-agent@sync-agent-marketplace"
echo ""
