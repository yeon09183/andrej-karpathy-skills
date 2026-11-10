local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local World = require(script.Parent.World)

local world = World.build()
local plots = world.plots
local rng = Random.new()
local bellActive = false

-- [Player] = { plot, rumor, rebirths, bounty, carrying, lastSwing, canSave, stats }
local profiles = {}

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(name)
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remotes
	return event
end
local announceRemote = remote("Announce") -- 서버 -> 클라: 안내 문구
local knockbackRemote = remote("Knockback") -- 서버 -> 클라: 밀려나는 속도
local rebirthRemote = remote("Rebirth") -- 클라 -> 서버
local fuseRemote = remote("Fuse") -- 클라 -> 서버
remotes.Parent = ReplicatedStorage

local function notify(player, text)
	announceRemote:FireClient(player, text)
end

local function rgb(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

----------------------------------------------------------------------
-- 요괴
-- yokai = { def, mutation, level, part, label, prompt, plot, slot, carrier }
----------------------------------------------------------------------

local function refreshLabel(yokai)
	local rarity = Config.RARITIES[yokai.def.rarity]
	local mutation = Economy.getMutation(yokai.mutation)
	local name = yokai.def.name
	if mutation then
		name = mutation.name .. " " .. name
	end
	if yokai.level > 1 then
		name ..= " +" .. (yokai.level - 1)
	end
	local income = Economy.yokaiIncome(yokai.def, yokai.mutation, yokai.level)
	yokai.label.Text = string.format("[%s] %s\n소문 %s/초", rarity.name, name, Economy.format(income))
	yokai.label.TextColor3 = rgb(mutation and mutation.color or rarity.color)
end

local function createYokai(def, mutationId, level)
	local rarity = Config.RARITIES[def.rarity]
	local mutation = Economy.getMutation(mutationId)
	local size = rarity.size + (level - 1) * 0.75

	local part = Instance.new("Part")
	part.Name = def.id
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(size, size, size)
	part.Color = rgb(mutation and mutation.color or rarity.color)
	part.Material = mutation and Enum.Material.Neon or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false

	local yokai = {
		def = def,
		mutation = mutationId,
		level = level,
		part = part,
		label = World.billboard(part, size / 2 + 1.5, 2.5),
	}
	refreshLabel(yokai)
	return yokai
end

local function freeSlot(plot)
	for slot = 1, Config.SLOTS do
		if not plot.yokai[slot] then
			return slot
		end
	end
	return nil
end

local function slotCFrame(yokai)
	return CFrame.new(yokai.plot.slots[yokai.slot] + Vector3.new(0, yokai.part.Size.Y / 2 + 0.1, 0))
end

local function isLocked(plot)
	return not bellActive and os.clock() < plot.lockedUntil
end

-- 업혀 있던 요괴를 도둑에게서 떼어낸다 (어디에 놓을지는 호출한 쪽이 정한다)
local function detach(yokai)
	local thief = yokai.carrier
	if not thief then
		return
	end
	yokai.carrier = nil
	local weld = yokai.part:FindFirstChildOfClass("WeldConstraint")
	if weld then
		weld:Destroy()
	end
	yokai.part.Anchored = true
	local profile = profiles[thief]
	if profile then
		profile.carrying = nil
	end
	local humanoid = thief.Character and thief.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Config.WALK_SPEED
	end
end

-- 훔치다 실패: 원래 자리로 돌아간다
local function returnYokai(yokai)
	detach(yokai)
	yokai.part.CFrame = slotCFrame(yokai)
	yokai.prompt.Enabled = true
end

local function removeYokai(yokai)
	detach(yokai)
	yokai.plot.yokai[yokai.slot] = nil
	yokai.part:Destroy()
end

local onPlacedPrompt

local function placeYokai(plot, slot, yokai)
	yokai.plot = plot
	yokai.slot = slot
	plot.yokai[slot] = yokai

	local part = yokai.part
	part.Anchored = true
	part.CFrame = slotCFrame(yokai)
	part:SetAttribute("OwnerId", plot.owner.UserId)
	CollectionService:AddTag(part, "PlacedYokai")

	if not yokai.prompt then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "훔치기" -- 주인에게는 클라이언트가 "판매"로 바꿔 보여준다
		prompt.ObjectText = yokai.def.name
		prompt.HoldDuration = Config.STEAL_HOLD
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function(player)
			onPlacedPrompt(yokai, player)
		end)
		prompt.Parent = part
		yokai.prompt = prompt
	end
	yokai.prompt.Enabled = true
	part.Parent = world.folder
end

local function steal(yokai, player, profile)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 or profile.carrying then
		return
	end
	if isLocked(yokai.plot) then
		notify(player, "결계가 쳐져 있다!")
		return
	end

	yokai.carrier = player
	profile.carrying = yokai
	yokai.prompt.Enabled = false

	local part = yokai.part
	part.Massless = true
	part.CFrame = root.CFrame * CFrame.new(0, 1, part.Size.Z / 2 + 1)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Anchored = false

	humanoid.WalkSpeed = Config.WALK_SPEED * Config.RARITIES[yokai.def.rarity].carrySpeed
	notify(yokai.plot.owner, player.DisplayName .. " 이(가) " .. yokai.def.name .. " 을(를) 훔쳐가는 중!")
end

function onPlacedPrompt(yokai, player)
	local profile = profiles[player]
	if not profile or yokai.carrier or yokai.part.Parent == nil then
		return
	end
	if yokai.plot == profile.plot then
		profile.rumor += Economy.sellValue(yokai.def, yokai.mutation, yokai.level)
		removeYokai(yokai)
	else
		steal(yokai, player, profile)
	end
end

-- 도둑이 자기 좌판에 도착했다
local function deliver(yokai, thief, profile)
	local slot = freeSlot(profile.plot)
	if not slot then
		returnYokai(yokai)
		notify(thief, "좌판에 빈자리가 없어 요괴가 돌아갔다.")
		return
	end
	local victim = yokai.plot.owner
	detach(yokai)
	yokai.plot.yokai[yokai.slot] = nil
	placeYokai(profile.plot, slot, yokai)

	profile.bounty += math.floor(Economy.price(yokai.def, yokai.mutation) * Config.BOUNTY_RATE)
	notify(thief, yokai.def.name .. " 을(를) 훔쳤다!")
	notify(victim, thief.DisplayName .. " 에게 " .. yokai.def.name .. " 을(를) 빼앗겼다...")
end

----------------------------------------------------------------------
-- 골목: 요괴가 지나가고, 소문을 내면 영입된다
----------------------------------------------------------------------

local function spawnWalker(rarityKey)
	local pool = Economy.yokaiOfRarity(rarityKey)
	local def = pool[rng:NextInteger(1, #pool)]
	local mutationId = Economy.rollMutation(rng:NextNumber())
	local price = Economy.price(def, mutationId)
	local yokai = createYokai(def, mutationId, 1)
	local part = yokai.part
	local height = Vector3.new(0, part.Size.Y / 2 + 0.2, 0)
	part.CFrame = CFrame.new(world.alleyStart + height)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "영입"
	prompt.ObjectText = "소문 " .. Economy.format(price)
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	local distance = (world.alleyEnd - world.alleyStart).Magnitude
	local tween = TweenService:Create(
		part,
		TweenInfo.new(distance / Config.WALKER_SPEED, Enum.EasingStyle.Linear),
		{ CFrame = CFrame.new(world.alleyEnd + height) }
	)
	tween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			part:Destroy()
		end
	end)

	prompt.Triggered:Connect(function(player)
		local profile = profiles[player]
		if not profile or yokai.plot then
			return
		end
		local rarity = Config.RARITIES[def.rarity]
		if profile.rebirths < rarity.minRebirth then
			notify(player, string.format("%s 등급은 환생 %d회부터 영입할 수 있다.", rarity.name, rarity.minRebirth))
			return
		end
		if profile.rumor < price then
			notify(player, "소문이 부족하다.")
			return
		end
		local slot = freeSlot(profile.plot)
		if not slot then
			notify(player, "좌판에 빈자리가 없다. 요괴를 팔거나 합성하자.")
			return
		end
		profile.rumor -= price
		tween:Cancel()
		prompt:Destroy()
		placeYokai(profile.plot, slot, yokai)
	end)

	part.Parent = world.folder
	tween:Play()
	return yokai
end

task.spawn(function()
	while true do
		task.wait(Config.SPAWN_INTERVAL)
		spawnWalker(Economy.rollRarity(rng:NextNumber()))
	end
end)

----------------------------------------------------------------------
-- 결계와 새벽 종
----------------------------------------------------------------------

for _, plot in plots do
	plot.lockPad.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		local now = os.clock()
		if player == nil or player ~= plot.owner or bellActive or now < plot.lockReadyAt then
			return
		end
		plot.lockedUntil = now + Config.LOCK_DURATION
		plot.lockReadyAt = now + Config.LOCK_COOLDOWN
	end)
end

local function refreshLock(plot)
	local now = os.clock()
	local locked = isLocked(plot)
	plot.dome.Transparency = locked and 0.5 or 1
	if not plot.owner then
		plot.lockLabel.Text = ""
	elseif bellActive then
		plot.lockLabel.Text = "새벽 종! 결계 해제"
	elseif locked then
		plot.lockLabel.Text = string.format("결계 %d초", math.ceil(plot.lockedUntil - now))
	elseif now < plot.lockReadyAt then
		plot.lockLabel.Text = string.format("빈틈! 재충전 %d초", math.ceil(plot.lockReadyAt - now))
	else
		plot.lockLabel.Text = "밟아서 결계 치기"
	end
end

local function scheduleBell()
	workspace:SetAttribute("BellActive", bellActive)
	workspace:SetAttribute(
		"BellChangeAt",
		workspace:GetServerTimeNow() + (bellActive and Config.BELL_DURATION or Config.BELL_INTERVAL)
	)
end

task.spawn(function()
	while true do
		scheduleBell()
		task.wait(Config.BELL_INTERVAL)

		bellActive = true
		scheduleBell()
		for _, plot in plots do
			plot.lockedUntil = 0
			plot.lockReadyAt = 0
		end
		spawnWalker(Config.BELL_RARITY)
		announceRemote:FireAllClients("새벽 종이 울린다! 모든 결계가 풀렸다!")
		task.wait(Config.BELL_DURATION)

		bellActive = false
		announceRemote:FireAllClients("종소리가 멎었다. 결계를 다시 칠 수 있다.")
	end
end)

----------------------------------------------------------------------
-- 부채: 때리면 밀려나고, 업고 있던 요괴를 떨어뜨린다
----------------------------------------------------------------------

local function swing(attacker)
	local profile = profiles[attacker]
	local root = attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart")
	local now = os.clock()
	if not profile or not root or now - profile.lastSwing < Config.FAN_COOLDOWN then
		return
	end
	profile.lastSwing = now

	for victim, victimProfile in profiles do
		local victimRoot = victim.Character and victim.Character:FindFirstChild("HumanoidRootPart")
		if victim ~= attacker and victimRoot then
			local offset = victimRoot.Position - root.Position
			if offset.Magnitude <= Config.FAN_RANGE and offset:Dot(root.CFrame.LookVector) > 0 then
				local direction = Vector3.new(offset.X, 0, offset.Z)
				if direction.Magnitude > 0 then
					direction = direction.Unit
				end
				-- 캐릭터 물리는 그 플레이어의 클라이언트가 소유하므로 클라이언트에서 적용한다
				knockbackRemote:FireClient(victim, direction * Config.KNOCKBACK + Vector3.new(0, 30, 0))

				if victimProfile.carrying then
					local yokai = victimProfile.carrying
					returnYokai(yokai)
					notify(victim, "얻어맞아 요괴를 놓쳤다!")
					notify(yokai.plot.owner, yokai.def.name .. " 이(가) 좌판으로 돌아왔다.")
				end
				if victimProfile.bounty > 0 then
					profile.rumor += victimProfile.bounty
					announceRemote:FireAllClients(
						string.format(
							"%s 이(가) %s 의 현상금 %s 을(를) 챙겼다!",
							attacker.DisplayName,
							victim.DisplayName,
							Economy.format(victimProfile.bounty)
						)
					)
					victimProfile.bounty = 0
				end
			end
		end
	end
end

local function giveFan(player)
	local tool = Instance.new("Tool")
	tool.Name = "부채"
	tool.CanBeDropped = false
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 2.5, 1.5)
	handle.Color = Color3.fromRGB(230, 60, 60)
	handle.Parent = tool
	tool.Activated:Connect(function()
		swing(player)
	end)
	tool.Parent = player:WaitForChild("Backpack")
end

----------------------------------------------------------------------
-- 환생 / 합성
----------------------------------------------------------------------

local function clearPlot(plot)
	for _, yokai in plot.yokai do
		detach(yokai)
		yokai.part:Destroy()
	end
	plot.yokai = {}
end

rebirthRemote.OnServerEvent:Connect(function(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local cost = Economy.rebirthCost(profile.rebirths)
	if profile.rumor < cost then
		notify(player, "환생하려면 소문 " .. Economy.format(cost) .. " 이(가) 필요하다.")
		return
	end
	if profile.carrying then
		returnYokai(profile.carrying)
	end
	clearPlot(profile.plot)
	profile.rumor = Config.START_RUMOR
	profile.bounty = 0
	profile.rebirths += 1
	announceRemote:FireAllClients(
		string.format("%s 이(가) %d번째 환생을 했다!", player.DisplayName, profile.rebirths)
	)
end)

fuseRemote.OnServerEvent:Connect(function(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local fused = 0
	while true do
		-- 업혀 가는 중인 요괴는 합성 대상에서 뺀다
		local list = {}
		for _, yokai in profile.plot.yokai do
			if not yokai.carrier then
				table.insert(list, yokai)
			end
		end
		local group = Economy.findFusable(list)
		if not group then
			break
		end
		local keep = list[group[1]]
		for i = 2, #group do
			removeYokai(list[group[i]])
		end
		keep.level += 1
		local size = Config.RARITIES[keep.def.rarity].size + (keep.level - 1) * 0.75
		keep.part.Size = Vector3.new(size, size, size)
		keep.part.CFrame = slotCFrame(keep)
		keep.label.Parent.StudsOffset = Vector3.new(0, size / 2 + 1.5, 0)
		refreshLabel(keep)
		fused += 1
	end
	notify(player, fused > 0 and ("합성 " .. fused .. "회 완료!") or "합성할 수 있는 요괴가 없다. (같은 요괴 3마리)")
end)

----------------------------------------------------------------------
-- 저장
----------------------------------------------------------------------

local storeOk, store = pcall(function()
	return DataStoreService:GetDataStore("YokaiMarketV1")
end)
if not storeOk then
	warn("DataStore를 쓸 수 없어 저장이 꺼집니다:", store)
end

-- 성공하면 (true, data 또는 nil), 실패하면 (false)
local function loadData(player)
	if not storeOk then
		return false
	end
	local ok, data = pcall(function()
		return store:GetAsync("u" .. player.UserId)
	end)
	if not ok then
		warn("불러오기 실패:", player.Name, data)
	end
	return ok, ok and data or nil
end

local function saveData(player, profile)
	-- 불러오기에 실패한 플레이어는 저장하지 않는다 (기존 데이터를 덮어쓰지 않기 위해)
	if not profile.canSave then
		return
	end
	local list = {}
	for _, yokai in profile.plot.yokai do
		table.insert(list, { id = yokai.def.id, mutation = yokai.mutation, level = yokai.level })
	end
	local ok, err = pcall(function()
		store:SetAsync("u" .. player.UserId, {
			rumor = profile.rumor,
			rebirths = profile.rebirths,
			yokai = list,
		})
	end)
	if not ok then
		warn("저장 실패:", player.Name, err)
	end
end

----------------------------------------------------------------------
-- 플레이어
----------------------------------------------------------------------

local function onCharacter(player, character)
	local profile = profiles[player]
	if not profile then
		return
	end
	local humanoid = character:WaitForChild("Humanoid")
	local root = character:WaitForChild("HumanoidRootPart")
	humanoid.WalkSpeed = Config.WALK_SPEED
	humanoid.Died:Connect(function()
		if profile.carrying then
			returnYokai(profile.carrying)
		end
	end)

	local bounty = World.billboard(character:WaitForChild("Head"), 3.5, 1.2)
	bounty.Name = "BountyLabel"
	bounty.TextColor3 = Color3.fromRGB(255, 90, 90)
	bounty.Text = ""

	giveFan(player)
	task.defer(function()
		root.CFrame = CFrame.new(profile.plot.lockPad.Position + Vector3.new(0, 4, 0))
	end)
end

local function onPlayerAdded(player)
	local plot
	for _, candidate in plots do
		if not candidate.owner then
			plot = candidate
			break
		end
	end
	if not plot then
		player:Kick("야시장이 가득 찼습니다. 다른 서버로 접속해 주세요.")
		return
	end
	plot.owner = player
	plot.sign.Text = player.DisplayName .. " 의 좌판"

	local loaded, data = loadData(player)
	if player.Parent == nil then
		plot.owner = nil
		plot.sign.Text = "빈 좌판"
		return
	end

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local rumorStat = Instance.new("NumberValue")
	rumorStat.Name = "소문"
	rumorStat.Parent = stats
	local rebirthStat = Instance.new("IntValue")
	rebirthStat.Name = "환생"
	rebirthStat.Parent = stats
	stats.Parent = player

	local profile = {
		plot = plot,
		rumor = data and data.rumor or Config.START_RUMOR,
		rebirths = data and data.rebirths or 0,
		bounty = 0,
		carrying = nil,
		lastSwing = 0,
		canSave = loaded,
		rumorStat = rumorStat,
		rebirthStat = rebirthStat,
	}
	profiles[player] = profile

	if data and data.yokai then
		for slot, saved in data.yokai do
			local def = Economy.getYokai(saved.id)
			if def and slot <= Config.SLOTS then
				placeYokai(plot, slot, createYokai(def, saved.mutation, saved.level))
			end
		end
	end

	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		onCharacter(player, player.Character)
	end
end

local function onPlayerRemoving(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	if profile.carrying then
		returnYokai(profile.carrying)
	end
	-- 남이 업고 가던 내 요괴도 저장 전에 되돌린다
	for _, yokai in profile.plot.yokai do
		if yokai.carrier then
			returnYokai(yokai)
		end
	end
	profiles[player] = nil
	saveData(player, profile)
	clearPlot(profile.plot)
	profile.plot.owner = nil
	profile.plot.sign.Text = "빈 좌판"
	profile.plot.lockedUntil = 0
	profile.plot.lockReadyAt = 0
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	for player, profile in profiles do
		saveData(player, profile)
	end
end)

task.spawn(function()
	while true do
		task.wait(Config.AUTOSAVE_INTERVAL)
		for player, profile in profiles do
			task.spawn(saveData, player, profile)
		end
	end
end)

----------------------------------------------------------------------
-- 메인 루프: 수익 지급(1초), 훔친 요괴 도착 판정(0.2초)
----------------------------------------------------------------------

local function tickIncome()
	for player, profile in profiles do
		local earning = {}
		for _, yokai in profile.plot.yokai do
			if not yokai.carrier then
				table.insert(earning, { id = yokai.def.id, mutation = yokai.mutation, level = yokai.level })
			end
		end
		local income = Economy.totalIncome(earning, profile.rebirths)
		profile.rumor += income

		profile.rumorStat.Value = math.floor(profile.rumor)
		profile.rebirthStat.Value = profile.rebirths
		player:SetAttribute("Rumor", profile.rumor)
		player:SetAttribute("Income", income)
		player:SetAttribute("Bounty", profile.bounty)
		player:SetAttribute("Rebirths", profile.rebirths)

		local head = player.Character and player.Character:FindFirstChild("Head")
		local gui = head and head:FindFirstChildOfClass("BillboardGui")
		if gui then
			gui.BountyLabel.Text = profile.bounty > 0 and ("현상금 " .. Economy.format(profile.bounty)) or ""
		end
	end
	for _, plot in plots do
		refreshLock(plot)
	end
end

task.spawn(function()
	local elapsed = 0
	while true do
		elapsed += task.wait(0.2)
		for player, profile in profiles do
			local yokai = profile.carrying
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if yokai and root then
				if root.Position.Y < -20 then
					returnYokai(yokai) -- 옥상 밖으로 떨어지면 요괴가 같이 삭제되기 전에 되돌린다
				elseif World.inPlot(profile.plot, root.Position) then
					deliver(yokai, player, profile)
				end
			end
		end
		if elapsed >= 1 then
			elapsed -= 1
			tickIncome()
		end
	end
end)
