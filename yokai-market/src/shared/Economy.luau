-- Roblox API를 쓰지 않는 순수 계산 로직. tests/economy_test.luau 로 검증한다.
local Config = require(script.Parent.Config)

local Economy = {}

local yokaiById = {}
local yokaiByRarity = {}
for _, def in Config.YOKAI do
	yokaiById[def.id] = def
	yokaiByRarity[def.rarity] = yokaiByRarity[def.rarity] or {}
	table.insert(yokaiByRarity[def.rarity], def)
end

local mutationById = {}
for _, mutation in Config.MUTATIONS do
	mutationById[mutation.id] = mutation
end

function Economy.getYokai(id)
	return yokaiById[id]
end

function Economy.getMutation(id)
	return mutationById[id]
end

function Economy.yokaiOfRarity(rarity)
	return yokaiByRarity[rarity]
end

local function mutationMult(mutationId)
	local mutation = mutationId and mutationById[mutationId]
	return mutation and mutation.mult or 1
end

function Economy.price(def, mutationId)
	return def.price * mutationMult(mutationId)
end

function Economy.yokaiIncome(def, mutationId, level)
	return def.income * mutationMult(mutationId) * Config.FUSE_INCOME_MULT ^ (level - 1)
end

function Economy.sellValue(def, mutationId, level)
	return math.floor(Economy.price(def, mutationId) * Config.SELL_RATE * Config.FUSE_COUNT ^ (level - 1))
end

function Economy.rebirthMultiplier(rebirths)
	return 1 + Config.REBIRTH_BONUS * rebirths
end

function Economy.rebirthCost(rebirths)
	return Config.REBIRTH_BASE_COST * Config.REBIRTH_COST_GROWTH ^ rebirths
end

-- list: { { id, mutation, level } }
function Economy.totalIncome(list, rebirths)
	local sum = 0
	for _, entry in list do
		sum += Economy.yokaiIncome(yokaiById[entry.id], entry.mutation, entry.level)
	end
	return sum * Economy.rebirthMultiplier(rebirths)
end

-- roll: [0, 1) 난수. 가중치에 따라 등급 키를 돌려준다.
function Economy.rollRarity(roll)
	local total = 0
	for _, key in Config.RARITY_ORDER do
		total += Config.RARITIES[key].weight
	end
	local point = roll * total
	local last
	for _, key in Config.RARITY_ORDER do
		local weight = Config.RARITIES[key].weight
		if weight > 0 then
			last = key
			if point < weight then
				return key
			end
			point -= weight
		end
	end
	return last
end

-- roll: [0, 1) 난수. 변이 id 또는 nil.
function Economy.rollMutation(roll)
	local edge = 0
	for _, mutation in Config.MUTATIONS do
		edge += mutation.chance
		if roll < edge then
			return mutation.id
		end
	end
	return nil
end

-- list: { { id, mutation, level } }
-- 합성 가능한 같은 요괴 FUSE_COUNT 마리의 list 인덱스 배열을 돌려준다. 없으면 nil.
function Economy.findFusable(list)
	local groups = {}
	for index, entry in list do
		if entry.level < Config.MAX_LEVEL then
			local key = entry.id .. "/" .. (entry.mutation or "") .. "/" .. entry.level
			local group = groups[key]
			if not group then
				group = {}
				groups[key] = group
			end
			table.insert(group, index)
			if #group == Config.FUSE_COUNT then
				return group
			end
		end
	end
	return nil
end

local SUFFIXES = { "", "K", "M", "B", "T" }

function Economy.format(amount)
	amount = math.floor(amount)
	if amount < 1000 then
		return tostring(amount)
	end
	local tier = math.min(#SUFFIXES - 1, math.floor(math.log10(amount) / 3))
	local scaled = math.floor(amount / 1000 ^ tier * 10) / 10
	return string.format("%.1f", scaled):gsub("%.0$", "") .. SUFFIXES[tier + 1]
end

return Economy
