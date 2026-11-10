-- 맵을 코드로 만든다. 에셋 없이 빈 플레이스에서 바로 돌아가게 하기 위함.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local World = {}

local PLOT_SIZE = Vector3.new(44, 1, 30)
local PLOT_SPACING = 60
local PLOT_DISTANCE = 45 -- 골목 중심에서 좌판 중심까지
local ALLEY_HALF_LENGTH = 140

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		p[key] = value
	end
	p.Parent = props.Parent or workspace
	return p
end

-- 파트 위에 떠 있는 글자. TextLabel을 돌려준다.
function World.billboard(parent, offsetY, height)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(12, height or 2)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	gui.Parent = parent
	return label
end

local function buildPlot(index, folder)
	local side = index % 2 == 1 and -1 or 1
	local column = math.ceil(index / 2)
	local columns = Config.PLOT_COUNT / 2
	local center = Vector3.new((column - (columns + 1) / 2) * PLOT_SPACING, 0.5, side * PLOT_DISTANCE)

	part({
		Name = "Floor",
		Size = PLOT_SIZE,
		Position = center,
		Color = Color3.fromRGB(70, 45, 35),
		Material = Enum.Material.WoodPlanks,
		Parent = folder,
	})

	-- 5칸씩 여러 줄, 골목에서 먼 쪽으로 쌓는다
	local slots = {}
	for i = 1, Config.SLOTS do
		local col = (i - 1) % 5
		local row = math.floor((i - 1) / 5)
		local position = center + Vector3.new((col - 2) * 8, 0.6, side * (2 + row * 8))
		part({
			Name = "Slot",
			Size = Vector3.new(5, 0.2, 5),
			Position = position,
			Color = Color3.fromRGB(40, 30, 25),
			Parent = folder,
		})
		slots[i] = position
	end

	local lockPad = part({
		Name = "LockPad",
		Size = Vector3.new(6, 0.2, 6),
		Position = center + Vector3.new(0, 0.6, -side * 11),
		Color = Color3.fromRGB(200, 40, 40),
		Material = Enum.Material.Neon,
		Parent = folder,
	})

	local dome = part({
		Name = "Barrier",
		Size = Vector3.new(PLOT_SIZE.X, 14, PLOT_SIZE.Z),
		Position = center + Vector3.new(0, 7.5, 0),
		Color = Color3.fromRGB(255, 80, 80),
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = folder,
	})

	local signPost = part({
		Name = "Sign",
		Size = Vector3.new(1, 10, 1),
		Position = center + Vector3.new(0, 5.5, side * (PLOT_SIZE.Z / 2 - 0.5)),
		Color = Color3.fromRGB(120, 30, 30),
		Parent = folder,
	})
	local lantern = Instance.new("PointLight")
	lantern.Color = Color3.fromRGB(255, 170, 90)
	lantern.Range = 40
	lantern.Brightness = 2
	lantern.Parent = signPost

	local sign = World.billboard(signPost, 7, 3)
	sign.Text = "빈 좌판"

	return {
		index = index,
		center = center,
		slots = slots,
		lockPad = lockPad,
		lockLabel = World.billboard(lockPad, 3, 1.5),
		dome = dome,
		sign = sign,
		owner = nil,
		yokai = {}, -- [slot] = yokai
		lockedUntil = 0,
		lockReadyAt = 0,
	}
end

function World.inPlot(plot, position)
	return math.abs(position.X - plot.center.X) <= PLOT_SIZE.X / 2
		and math.abs(position.Z - plot.center.Z) <= PLOT_SIZE.Z / 2
end

function World.build()
	Lighting.ClockTime = 0
	Lighting.Brightness = 1
	Lighting.Ambient = Color3.fromRGB(70, 70, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(60, 60, 100)

	local folder = Instance.new("Folder")
	folder.Name = "NightMarket"
	folder.Parent = workspace

	part({
		Name = "Rooftop",
		Size = Vector3.new(400, 4, 400),
		Position = Vector3.new(0, -2, 0),
		Color = Color3.fromRGB(35, 35, 45),
		Material = Enum.Material.Concrete,
		Parent = folder,
	})
	part({
		Name = "Alley",
		Size = Vector3.new(ALLEY_HALF_LENGTH * 2, 0.2, 8),
		Position = Vector3.new(0, 0.1, 0),
		Color = Color3.fromRGB(255, 200, 120),
		Material = Enum.Material.Neon,
		Transparency = 0.6,
		Parent = folder,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 0.5, 14)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = folder

	local plots = {}
	for index = 1, Config.PLOT_COUNT do
		plots[index] = buildPlot(index, folder)
	end

	return {
		folder = folder,
		plots = plots,
		alleyStart = Vector3.new(-ALLEY_HALF_LENGTH, 0, 0),
		alleyEnd = Vector3.new(ALLEY_HALF_LENGTH, 0, 0),
	}
end

return World
