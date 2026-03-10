local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

if player.PlayerGui:FindFirstChild("MyAutoFarmGui") then
	player.PlayerGui.MyAutoFarmGui:Destroy()
end

--------------------------------------------------
-- CONFIG
--------------------------------------------------

local Config = {
	Speed = 78,
	Jump = 100,
	AutoClick = false
}

--------------------------------------------------
-- REMOTES
--------------------------------------------------

local ToolCollect = ReplicatedStorage:WaitForChild("Events"):WaitForChild("ToolCollect")

--------------------------------------------------
-- NODE SYSTEM
--------------------------------------------------

local PathNodes = {}
local currentNodeIndex = 1
local pathActive = false
local movingForward = true

--------------------------------------------------
-- FIELD
--------------------------------------------------

local fieldVisualizer
local corner1
local corner2

--------------------------------------------------
-- RANDOM WALK (NEW)
--------------------------------------------------

local randomTarget = nil
local randomTimer = 0

--------------------------------------------------
-- GUI
--------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "MyAutoFarmGui"
gui.Parent = player.PlayerGui

local frame = Instance.new("Frame",gui)
frame.Size = UDim2.new(0,240,0,540)
frame.Position = UDim2.new(0.1,0,0.1,0)
frame.BackgroundColor3 = Color3.fromRGB(30,30,30)

local layout = Instance.new("UIListLayout",frame)
layout.Padding = UDim.new(0,6)

--------------------------------------------------
-- DRAG
--------------------------------------------------

local dragging
local dragStart
local startPos

frame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = frame.Position
	end
end)

frame.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)

UserInputService.InputChanged:Connect(function(input)

	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then

		local delta = input.Position - dragStart

		frame.Position = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)

	end

end)

--------------------------------------------------
-- UI HELPERS
--------------------------------------------------

local function createInput(text,value)

	local container = Instance.new("Frame",frame)
	container.Size = UDim2.new(1,0,0,45)
	container.BackgroundTransparency = 1

	local label = Instance.new("TextLabel",container)
	label.Size = UDim2.new(1,0,0.4,0)
	label.Text = text
	label.TextColor3 = Color3.new(1,1,1)
	label.BackgroundTransparency = 1

	local box = Instance.new("TextBox",container)
	box.Size = UDim2.new(1,0,0.6,0)
	box.Position = UDim2.new(0,0,0.4,0)
	box.Text = tostring(value)

	return box

end

local function createButton(text,color)

	local b = Instance.new("TextButton",frame)
	b.Size = UDim2.new(1,0,0,35)
	b.Text = text
	b.BackgroundColor3 = color
	b.TextColor3 = Color3.new(1,1,1)

	return b

end

--------------------------------------------------
-- INPUTS
--------------------------------------------------

local speedBox = createInput("WalkSpeed",Config.Speed)
local jumpBox = createInput("JumpPower",Config.Jump)

--------------------------------------------------
-- AUTO CLICK
--------------------------------------------------

local autoBtn = createButton("Auto Click : OFF",Color3.fromRGB(200,50,50))

autoBtn.MouseButton1Click:Connect(function()

	Config.AutoClick = not Config.AutoClick

	autoBtn.Text = Config.AutoClick and "Auto Click : ON" or "Auto Click : OFF"
	autoBtn.BackgroundColor3 = Config.AutoClick and Color3.fromRGB(50,200,50) or Color3.fromRGB(200,50,50)

end)

--------------------------------------------------
-- FIELD SYSTEM
--------------------------------------------------

local function drawField()

	if not corner1 or not corner2 then return end

	local center = (corner1 + corner2)/2
	local sizeX = math.abs(corner1.X-corner2.X)
	local sizeZ = math.abs(corner1.Z-corner2.Z)

	if fieldVisualizer then
		fieldVisualizer:Destroy()
	end

	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 0.85
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(120,255,170)

	part.Size = Vector3.new(sizeX,25,sizeZ)
	part.Position = Vector3.new(center.X,center.Y+12,center.Z)

	part.Parent = workspace
	fieldVisualizer = part

end

--------------------------------------------------
-- CHECK PLAYER IN FIELD
--------------------------------------------------

local function isPlayerInsideField()

	if not corner1 or not corner2 then
		return false
	end

	local char = player.Character
	if not char then return false end

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	local pos = root.Position

	local minX = math.min(corner1.X,corner2.X)
	local maxX = math.max(corner1.X,corner2.X)

	local minZ = math.min(corner1.Z,corner2.Z)
	local maxZ = math.max(corner1.Z,corner2.Z)

	if pos.X >= minX and pos.X <= maxX and pos.Z >= minZ and pos.Z <= maxZ then
		return true
	end

	return false

end

--------------------------------------------------
-- TOKEN DETECTION
--------------------------------------------------

local function getTokensInField()

	local tokens = {}

	if not corner1 or not corner2 then return tokens end
	if not workspace:FindFirstChild("Collectibles") then return tokens end

	local minX = math.min(corner1.X,corner2.X)
	local maxX = math.max(corner1.X,corner2.X)

	local minZ = math.min(corner1.Z,corner2.Z)
	local maxZ = math.max(corner1.Z,corner2.Z)

	for _,v in pairs(workspace.Collectibles:GetChildren()) do

		if v:IsA("BasePart") then

			local pos = v.Position

			if pos.X >= minX and pos.X <= maxX and pos.Z >= minZ and pos.Z <= maxZ then
				table.insert(tokens,v)
			end

		end

	end

	return tokens

end

local function getNearestToken()

	local tokens = getTokensInField()
	local char = player.Character
	if not char then return nil end

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local nearest
	local dist = math.huge

	for _,t in pairs(tokens) do

		local d = (root.Position - t.Position).Magnitude

		if d < dist then
			dist = d
			nearest = t
		end

	end

	return nearest

end

--------------------------------------------------
-- RANDOM WALK (NEW)
--------------------------------------------------

local function getRandomPositionInField()

	if not corner1 or not corner2 then return nil end

	local minX = math.min(corner1.X,corner2.X)
	local maxX = math.max(corner1.X,corner2.X)

	local minZ = math.min(corner1.Z,corner2.Z)
	local maxZ = math.max(corner1.Z,corner2.Z)

	local x = math.random()*(maxX-minX)+minX
	local z = math.random()*(maxZ-minZ)+minZ

	local y = player.Character.HumanoidRootPart.Position.Y

	return Vector3.new(x,y,z)

end

--------------------------------------------------
-- POLLEN CHECK
--------------------------------------------------

local function getPollen()

	local stats = player:FindFirstChild("CoreStats")
	if not stats then return 0,0 end

	local pollen = stats:FindFirstChild("Pollen")
	local capacity = stats:FindFirstChild("Capacity")

	if pollen and capacity then
		return pollen.Value, capacity.Value
	end

	return 0,0

end

--------------------------------------------------
-- FIELD BUTTONS
--------------------------------------------------

local corner1Btn = createButton("Set Corner 1 (Z)",Color3.fromRGB(80,150,255))
local corner2Btn = createButton("Set Corner 2 (X)",Color3.fromRGB(80,150,255))
local clearFieldBtn = createButton("Clear Field",Color3.fromRGB(255,120,80))

local function setCorner1()

	local char = player.Character
	if not char then return end

	corner1 = char.HumanoidRootPart.Position

end

local function setCorner2()

	local char = player.Character
	if not char then return end

	corner2 = char.HumanoidRootPart.Position
	drawField()

end

corner1Btn.MouseButton1Click:Connect(setCorner1)
corner2Btn.MouseButton1Click:Connect(setCorner2)

clearFieldBtn.MouseButton1Click:Connect(function()

	corner1 = nil
	corner2 = nil

	if fieldVisualizer then
		fieldVisualizer:Destroy()
	end

end)

--------------------------------------------------
-- NODE BUTTONS
--------------------------------------------------

local pathBtn = createButton("Path : OFF",Color3.fromRGB(100,150,255))
local addNodeBtn = createButton("Add Node (Q)",Color3.fromRGB(100,200,100))
local clearNodeBtn = createButton("Clear Nodes",Color3.fromRGB(255,180,60))

local function addNode()

	local char = player.Character
	if not char then return end

	local pos = char.HumanoidRootPart.Position
	table.insert(PathNodes,pos)

	local node = Instance.new("Part")
	node.Name = "PathNode"
	node.Size = Vector3.new(1,1,1)
	node.Anchored = true
	node.CanCollide = false
	node.Material = Enum.Material.Neon
	node.Color = Color3.fromRGB(0,255,127)
	node.Position = pos
	node.Parent = workspace

end

addNodeBtn.MouseButton1Click:Connect(addNode)

clearNodeBtn.MouseButton1Click:Connect(function()

	PathNodes = {}
	currentNodeIndex = 1

	for _,v in pairs(workspace:GetChildren()) do
		if v.Name == "PathNode" then
			v:Destroy()
		end
	end

end)

pathBtn.MouseButton1Click:Connect(function()

	pathActive = not pathActive

	pathBtn.Text = pathActive and "Path : ON" or "Path : OFF"

	currentNodeIndex = 1

end)

--------------------------------------------------
-- HOTKEYS
--------------------------------------------------

UserInputService.InputBegan:Connect(function(input,gp)

	if gp then return end

	if input.KeyCode == Enum.KeyCode.Z then
		setCorner1()
	end

	if input.KeyCode == Enum.KeyCode.X then
		setCorner2()
	end

	if input.KeyCode == Enum.KeyCode.Q then
		addNode()
	end

end)

--------------------------------------------------
-- CONFIG
--------------------------------------------------

speedBox.FocusLost:Connect(function()
	Config.Speed = tonumber(speedBox.Text) or Config.Speed
end)

jumpBox.FocusLost:Connect(function()
	Config.Jump = tonumber(jumpBox.Text) or Config.Jump
end)

--------------------------------------------------
-- AUTO CLICK LOOP
--------------------------------------------------

task.spawn(function()

	while true do

		if Config.AutoClick then
			pcall(function()
				ToolCollect:FireServer()
			end)
		end

		task.wait(0.05)

	end

end)

--------------------------------------------------
-- MAIN LOOP
--------------------------------------------------

RunService.Heartbeat:Connect(function()

	local char = player.Character
	if not char then return end

	local hum = char:FindFirstChild("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")

	if not hum or not root then return end

	hum.WalkSpeed = Config.Speed
	hum.JumpPower = Config.Jump

	if isPlayerInsideField() then

		local token = getNearestToken()

		if token then
			hum:MoveTo(token.Position)
			return
		end

		-- RANDOM WALK ถ้าไม่มี token
		randomTimer += 1

		if randomTimer > 40 then
			randomTarget = getRandomPositionInField()
			randomTimer = 0
		end

		if randomTarget then
			hum:MoveTo(randomTarget)
			return
		end

	end

	if pathActive and #PathNodes > 0 then

		local pollen,capacity = getPollen()

		if pollen >= capacity then
			movingForward = false
		end

		if pollen == 0 then
			movingForward = true
		end

		local target = PathNodes[currentNodeIndex]

		if target then

			hum:MoveTo(target)

			if (root.Position-target).Magnitude < 4 then

				if movingForward then
					currentNodeIndex += 1
				else
					currentNodeIndex -= 1
				end

				if currentNodeIndex > #PathNodes then
					currentNodeIndex = #PathNodes
				end

				if currentNodeIndex < 1 then
					currentNodeIndex = 1
				end

			end

		end

	end

end)
