# 달빛 야시장 — 요괴를 훔쳐라

로블록스 "훔치기류" 장르의 오리지널 게임. 골목을 지나가는 요괴를 영입해 좌판에 앉히면 소문(화폐)이 쌓이고, 남의 좌판에서 요괴를 업어 와 내 것으로 만든다.

## 실행

**가장 쉬운 방법:** `yokai-market.rbxlx` 를 Roblox Studio로 열고 Play. 맵은 스크립트가 실행 시점에 만든다.

**Rojo로 개발할 때:**

```
rojo serve            # Studio의 Rojo 플러그인으로 연결
rojo build -o yokai-market.rbxlx   # 플레이스 파일 다시 만들기
```

게시할 때 설정할 것:
- 서버 최대 인원을 **8명**으로 (`Config.PLOT_COUNT` 와 같아야 함)
- 저장을 쓰려면 Game Settings → Security → *Enable Studio Access to API Services*

## 조작

| 행동 | 방법 |
|---|---|
| 영입 | 골목의 요괴에 다가가 E |
| 판매 | 내 좌판의 요괴에서 E 길게 |
| 훔치기 | 남의 좌판 요괴에서 E 길게 → 업고 내 좌판까지 뛰기 |
| 결계 | 좌판 앞 빨간 발판 밟기 (40초 잠금, 이후 30초 빈틈) |
| 부채 | 장착 후 클릭. 맞은 상대는 밀려나고 업은 요괴를 놓친다. 현상금이 있으면 가져온다 |
| 합성 / 환생 | 화면 오른쪽 버튼 |

15분마다 **새벽 종**이 울려 30초 동안 모든 결계가 풀리고, 이때만 비밀 등급 요괴가 골목에 나온다.

## 구조

```
src/shared/Config.luau       수치 전부 (요괴, 등급, 변이, 쿨타임)
src/shared/Economy.luau      순수 계산 (수익, 환생 비용, 추첨, 합성 판정)
src/server/World.luau        맵 생성
src/server/Main.server.luau  게임 규칙 전부 (서버 권한)
src/client/Hud.client.luau   UI
tests/economy_test.luau      Economy 단위 테스트
tools/luau-check/            테스트/문법 검사용 작은 실행기 (Rust + mlua)
```

테스트:

```
cargo run --manifest-path tools/luau-check/Cargo.toml -- tests/economy_test.luau src/*/*.luau
```

## 검증 상태

- 됨: Economy 단위 테스트 통과, 전 파일 Luau 컴파일 통과, Rojo 빌드 성공
- **안 됨: Roblox Studio에서 실제로 플레이해 보지 않았다.** 서버·클라이언트 스크립트는 Roblox API에 의존해 이 저장소의 도구로는 실행할 수 없다. 처음 열면 Output 창의 오류부터 확인할 것.

## 아직 없는 것

- 모델/애니메이션/사운드 (요괴는 색깔 공 + 이름표)
- 요괴 고유 능력, 함정·경비 요괴, 층(옥상) 이동과 엔딩 서사
- 게임패스·상점 등 수익화
