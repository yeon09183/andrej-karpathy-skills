local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Economy"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "Hud"
gui.ResetOnSpawn = false

local function label(position, size)
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = position
	l.Size = size
	l.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	l.BackgroundTransparency = 0.3
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.Text = ""
	l.Parent = gui
	return l
end

local function button(order, color)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -12, 0.5, (order - 1) * 60)
	b.Size = UDim2.fromOffset(170, 50)
	b.BackgroundColor3 = color
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.Parent = gui
	return b
end

local bellLabel = label(UDim2.new(0.5, 0, 0, 8), UDim2.fromOffset(320, 34))
local announceLabel = label(UDim2.new(0.5, 0, 0, 50), UDim2.fromOffset(520, 40))
local statsLabel = label(UDim2.new(0.5, 0, 1, -110), UDim2.fromOffset(460, 40))
announceLabel.Visible = false

local rebirthButton = button(1, Color3.fromRGB(150, 60, 200))
local fuseButton = button(2, Color3.fromRGB(40, 130, 90))
fuseButton.Text = "합성 (같은 요괴 3마리)"

rebirthButton.Activated:Connect(function()
	remotes.Rebirth:FireServer()
end)
fuseButton.Activated:Connect(function()
	remotes.Fuse:FireServer()
end)

gui.Parent = player:WaitForChild("PlayerGui")

-- 안내 문구
local announceToken = 0
remotes.Announce.OnClientEvent:Connect(function(text)
	announceToken += 1
	local token = announceToken
	announceLabel.Text = text
	announceLabel.Visible = true
	task.wait(4)
	if token == announceToken then
		announceLabel.Visible = false
	end
end)

-- 부채에 맞았을 때 밀려나기
remotes.Knockback.OnClientEvent:Connect(function(velocity)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = velocity
	end
end)

-- 내 요괴의 프롬프트는 "판매", 남의 요괴는 "훔치기"
local function watchYokai(part)
	local function refresh()
		local prompt = part:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			local mine = part:GetAttribute("OwnerId") == player.UserId
			prompt.ActionText = mine and "판매" or "훔치기"
		end
	end
	part:GetAttributeChangedSignal("OwnerId"):Connect(refresh)
	part.ChildAdded:Connect(refresh)
	refresh()
end
CollectionService:GetInstanceAddedSignal("PlacedYokai"):Connect(watchYokai)
for _, part in CollectionService:GetTagged("PlacedYokai") do
	watchYokai(part)
end

while true do
	local rumor = player:GetAttribute("Rumor") or 0
	local income = player:GetAttribute("Income") or 0
	local bounty = player:GetAttribute("Bounty") or 0
	local rebirths = player:GetAttribute("Rebirths") or 0

	local text = string.format("소문 %s (+%s/초)", Economy.format(rumor), Economy.format(income))
	if bounty > 0 then
		text ..= " · 현상금 " .. Economy.format(bounty)
	end
	statsLabel.Text = text
	rebirthButton.Text = "환생 (소문 " .. Economy.format(Economy.rebirthCost(rebirths)) .. ")"

	local remaining = math.max(0, math.floor((workspace:GetAttribute("BellChangeAt") or 0) - workspace:GetServerTimeNow()))
	local clock = string.format("%d:%02d", remaining // 60, remaining % 60)
	if workspace:GetAttribute("BellActive") then
		bellLabel.Text = "새벽 종! 결계 해제 " .. clock
	else
		bellLabel.Text = "새벽 종까지 " .. clock
	end

	task.wait(0.25)
end
