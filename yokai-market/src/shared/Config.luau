-- 게임 전체 수치. 밸런스 조정은 이 파일만 고치면 된다.
local Config = {}

Config.PLOT_COUNT = 8 -- 서버 최대 인원과 같아야 한다
Config.SLOTS = 10 -- 좌판 하나에 놓을 수 있는 요괴 수
Config.START_RUMOR = 50
Config.WALK_SPEED = 16

-- 골목(컨베이어)
Config.SPAWN_INTERVAL = 2.5 -- 초
Config.WALKER_SPEED = 10 -- 스터드/초

-- 결계
Config.LOCK_DURATION = 40
Config.LOCK_COOLDOWN = 70 -- 결계를 친 시점부터 다시 칠 수 있을 때까지 (30초의 빈틈)

-- 새벽 종
Config.BELL_INTERVAL = 15 * 60
Config.BELL_DURATION = 30

-- 훔치기 / 전투
Config.STEAL_HOLD = 1.5
Config.FAN_RANGE = 8
Config.FAN_COOLDOWN = 1
Config.KNOCKBACK = 60
Config.BOUNTY_RATE = 0.1 -- 훔친 요괴 가격 대비 현상금

-- 경제
Config.SELL_RATE = 0.5
Config.FUSE_COUNT = 3 -- 같은 요괴 몇 마리를 합치는가
Config.FUSE_INCOME_MULT = 4 -- 단계가 오를 때마다 수익 배율
Config.MAX_LEVEL = 3
Config.REBIRTH_BASE_COST = 100000
Config.REBIRTH_COST_GROWTH = 8
Config.REBIRTH_BONUS = 0.5 -- 환생 1회당 수익 배율 증가

Config.AUTOSAVE_INTERVAL = 120

-- weight: 골목 등장 가중치 (0이면 일반 등장 없음)
-- carrySpeed: 업고 뛸 때 이동속도 배율
-- minRebirth: 영입에 필요한 환생 횟수 (훔치는 건 제한 없음)
Config.RARITIES = {
	Common = { name = "흔함", weight = 60, carrySpeed = 0.9, minRebirth = 0, size = 3, color = { 170, 170, 170 } },
	Rare = { name = "희귀", weight = 25, carrySpeed = 0.8, minRebirth = 0, size = 3.5, color = { 80, 160, 255 } },
	Epic = { name = "영웅", weight = 10, carrySpeed = 0.7, minRebirth = 0, size = 4, color = { 180, 90, 255 } },
	Legendary = { name = "전설", weight = 4, carrySpeed = 0.55, minRebirth = 0, size = 4.5, color = { 255, 170, 40 } },
	Mythic = { name = "신화", weight = 1, carrySpeed = 0.45, minRebirth = 1, size = 5.5, color = { 255, 70, 90 } },
	Secret = { name = "비밀", weight = 0, carrySpeed = 0.4, minRebirth = 2, size = 6, color = { 20, 20, 30 } },
}
Config.RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

-- 새벽 종이 울릴 때만 등장하는 등급
Config.BELL_RARITY = "Secret"

Config.YOKAI = {
	{ id = "umbrella", name = "우산 도깨비", rarity = "Common", price = 25, income = 1 },
	{ id = "dust", name = "먼지 뭉치", rarity = "Common", price = 60, income = 3 },
	{ id = "lantern", name = "등불 귀신", rarity = "Common", price = 150, income = 6 },
	{ id = "tanuki", name = "떡 너구리", rarity = "Rare", price = 500, income = 15 },
	{ id = "broom", name = "빗자루 정령", rarity = "Rare", price = 1200, income = 32 },
	{ id = "crow", name = "가면 까마귀", rarity = "Epic", price = 4000, income = 90 },
	{ id = "turtle", name = "술독 거북", rarity = "Epic", price = 9000, income = 180 },
	{ id = "fox", name = "구미호 점술가", rarity = "Legendary", price = 30000, income = 500 },
	{ id = "drummer", name = "천둥 북잡이", rarity = "Legendary", price = 75000, income = 1100 },
	{ id = "toad", name = "달 먹는 두꺼비", rarity = "Mythic", price = 400000, income = 5000 },
	{ id = "nameless", name = "이름 없는 것", rarity = "Secret", price = 2500000, income = 30000 },
}

-- chance는 독립이 아니라 누적 구간으로 굴린다 (합이 1 미만, 나머지는 변이 없음)
Config.MUTATIONS = {
	{ id = "cursed", name = "저주", chance = 0.003, mult = 8, color = { 120, 0, 160 } },
	{ id = "moon", name = "달빛", chance = 0.015, mult = 4, color = { 190, 220, 255 } },
	{ id = "gold", name = "금박", chance = 0.05, mult = 2, color = { 255, 215, 0 } },
}

return Config
