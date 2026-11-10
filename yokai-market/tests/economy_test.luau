-- Economy 단위 테스트. yokai-market 폴더에서 실행:
--   cargo run --manifest-path tools/luau-check/Cargo.toml -- tests/economy_test.luau src/*/*.luau
local Config = loadmodule("src/shared/Config.luau")()

-- Roblox의 require(script.Parent.Config) 를 흉내 낸다
script = { Parent = { Config = "Config" } }
require = function(name)
	assert(name == "Config")
	return Config
end
local Economy = loadmodule("src/shared/Economy.luau")()

local function eq(actual, expected, what)
	if actual ~= expected then
		error(string.format("%s: 기대 %s, 실제 %s", what, tostring(expected), tostring(actual)), 2)
	end
end

local umbrella = Economy.getYokai("umbrella")

-- 가격 / 수익 / 판매가
eq(Economy.price(umbrella, nil), 25, "기본 가격")
eq(Economy.price(umbrella, "gold"), 50, "금박 가격")
eq(Economy.yokaiIncome(umbrella, nil, 1), 1, "기본 수익")
eq(Economy.yokaiIncome(umbrella, "cursed", 2), 1 * 8 * 4, "저주 +1 수익")
eq(Economy.sellValue(umbrella, nil, 1), 12, "판매가는 절반(내림)")
eq(Economy.sellValue(umbrella, nil, 2), 37, "합성 요괴 판매가 = 재료 3마리 값")

-- 합성은 항상 이득이어야 한다 (1마리 수익 > 재료 3마리 수익)
assert(Config.FUSE_INCOME_MULT > Config.FUSE_COUNT, "합성이 손해")

-- 환생
eq(Economy.rebirthMultiplier(0), 1, "환생 0회 배율")
eq(Economy.rebirthMultiplier(2), 2, "환생 2회 배율")
eq(Economy.rebirthCost(0), 100000, "첫 환생 비용")
eq(Economy.rebirthCost(2), 6400000, "세 번째 환생 비용")

eq(
	Economy.totalIncome({ { id = "umbrella", level = 1 }, { id = "dust", mutation = "gold", level = 1 } }, 1),
	(1 + 6) * 1.5,
	"총 수익"
)
eq(Economy.totalIncome({}, 3), 0, "빈 좌판 수익")

-- 등급 추첨: 가중치 60/25/10/4/1, 비밀 등급은 절대 안 나온다
eq(Economy.rollRarity(0), "Common", "roll 0")
eq(Economy.rollRarity(0.599), "Common", "roll 0.599")
eq(Economy.rollRarity(0.6), "Rare", "roll 0.6")
eq(Economy.rollRarity(0.85), "Epic", "roll 0.85")
eq(Economy.rollRarity(0.95), "Legendary", "roll 0.95")
eq(Economy.rollRarity(0.995), "Mythic", "roll 0.995")
eq(Economy.rollRarity(0.9999999), "Mythic", "roll 최댓값")
for _, def in Config.YOKAI do
	assert(Config.RARITIES[def.rarity], def.id .. " 의 등급이 없다")
end
assert(#Economy.yokaiOfRarity(Config.BELL_RARITY) > 0, "새벽 종 등급에 요괴가 없다")

-- 변이 추첨
eq(Economy.rollMutation(0), "cursed", "변이 0")
eq(Economy.rollMutation(0.01), "moon", "변이 0.01")
eq(Economy.rollMutation(0.05), "gold", "변이 0.05")
eq(Economy.rollMutation(0.068), nil, "변이 없음 경계")
eq(Economy.rollMutation(0.5), nil, "변이 없음")

-- 합성 대상 찾기
eq(Economy.findFusable({ { id = "a", level = 1 }, { id = "a", level = 1 } }), nil, "2마리는 합성 불가")
local group = Economy.findFusable({
	{ id = "a", level = 1 },
	{ id = "b", level = 1 },
	{ id = "a", mutation = "gold", level = 1 }, -- 변이가 다르면 다른 요괴
	{ id = "a", level = 2 }, -- 단계가 다르면 다른 요괴
	{ id = "a", level = 1 },
	{ id = "a", level = 1 },
})
eq(table.concat(group, ","), "1,5,6", "합성 그룹")
local maxed = { id = "a", level = Config.MAX_LEVEL }
eq(Economy.findFusable({ maxed, maxed, maxed }), nil, "최대 단계는 합성 불가")

-- 숫자 표기
eq(Economy.format(0), "0", "format 0")
eq(Economy.format(999.9), "999", "format 999.9")
eq(Economy.format(1000), "1K", "format 1000")
eq(Economy.format(1250), "1.2K", "format 1250")
eq(Economy.format(999999), "999.9K", "format 999999")
eq(Economy.format(1000000), "1M", "format 1e6")
eq(Economy.format(2500000), "2.5M", "format 2.5e6")
eq(Economy.format(1e18), "1000000T", "format 상한 접미사")

print("economy_test: 전부 통과")
