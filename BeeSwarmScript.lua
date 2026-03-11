--==================================================
-- ROBLOX AUTO FARM SCRIPT
-- แก้ไขโดย: Claude | อัปเดต: 2026
-- fixes: Auto Make Honey, Convert E press, Round 2+
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
if not player then warn("Player not found!") return end

if player.PlayerGui:FindFirstChild("MyAutoFarmGui") then
	player.PlayerGui.MyAutoFarmGui:Destroy()
end

--==================================================
-- CONFIG
--==================================================
local Config = {
	Speed = 78,
	Jump = 100,
	AutoClick = false,
	AutoMakeHoney = false
}

--==================================================
-- REMOTES
--==================================================
local ToolCollect
pcall(function()
	ToolCollect = ReplicatedStorage:WaitForChild("Events"):WaitForChild("ToolCollect")
end)

--==================================================
-- STATE
--==================================================
local State = {
	PathNodes = {},
	CurrentNodeIndex = 1,
	PathActive = false,
	IsInConvertMode = false,
	RandomTarget = nil,
	RandomTimer = 0,
	FieldVisualizer = nil,
	Corner1 = nil,
	Corner2 = nil,
	LastPollenCheck = 0,
	HasTriggeredConvert = false,
	HasPressedE = false,
	MakeHoneyCooldown = 0
}

--==================================================
-- GUI
--==================================================
local gui = Instance.new("ScreenGui")
gui.Name = "MyAutoFarmGui"
gui.ResetOnSpawn = false
gui.Parent = player.PlayerGui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 240, 0, 660)
frame.Position = UDim2.new(0.1, 0, 0.1, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 0
Instance.new("UIListLayout", frame).Padding = UDim.new(0, 6)

local dragging, dragStart, startPos = false, nil, nil
frame.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true; dragStart = i.Position; startPos = frame.Position
	end
end)
frame.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)
UserInputService.InputChanged:Connect(function(i)
	if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
		local d = i.Position - dragStart
		frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)

--==================================================
-- UI HELPERS
--==================================================
local function createInput(text, value)
	local c = Instance.new("Frame", frame)
	c.Size = UDim2.new(1,0,0,45); c.BackgroundTransparency = 1; c.BorderSizePixel = 0
	local l = Instance.new("TextLabel", c)
	l.Size = UDim2.new(1,0,0.4,0); l.Text = text; l.TextColor3 = Color3.new(1,1,1)
	l.BackgroundTransparency = 1; l.BorderSizePixel = 0; l.TextSize = 14
	local b = Instance.new("TextBox", c)
	b.Size = UDim2.new(1,0,0.6,0); b.Position = UDim2.new(0,0,0.4,0)
	b.Text = tostring(value); b.BackgroundColor3 = Color3.fromRGB(50,50,50)
	b.TextColor3 = Color3.new(1,1,1); b.BorderSizePixel = 0; b.TextSize = 14
	return b
end

local function createButton(text, color)
	local b = Instance.new("TextButton", frame)
	b.Size = UDim2.new(1,0,0,35); b.Text = text; b.BackgroundColor3 = color
	b.TextColor3 = Color3.new(1,1,1); b.BorderSizePixel = 0; b.TextSize = 14
	b.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	return b
end

local function createLabel(text, color)
	local l = Instance.new("TextLabel", frame)
	l.Size = UDim2.new(1,0,0,30); l.Text = text; l.BackgroundColor3 = color
	l.TextColor3 = Color3.new(1,1,1); l.BorderSizePixel = 0; l.TextSize = 12
	l.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")
	return l
end

--==================================================
-- INPUTS & LABELS
--==================================================
local speedBox    = createInput("WalkSpeed", Config.Speed)
local jumpBox     = createInput("JumpPower",  Config.Jump)
local statusLabel = createLabel("Status: Ready",   Color3.fromRGB(60,60,60))
local modeLabel   = createLabel("Mode: Auto Farm", Color3.fromRGB(60,100,60))

--==================================================
-- BUTTONS
--==================================================
local autoBtn       = createButton("Auto Click : OFF",      Color3.fromRGB(200,50,50))
local honeyBtn      = createButton("Auto Make Honey : OFF", Color3.fromRGB(200,50,50))
local corner1Btn    = createButton("Set Corner 1 (Z)",      Color3.fromRGB(80,150,255))
local corner2Btn    = createButton("Set Corner 2 (X)",      Color3.fromRGB(80,150,255))
local clearFieldBtn = createButton("Clear Field",           Color3.fromRGB(255,120,80))
local pathBtn       = createButton("Path : OFF",            Color3.fromRGB(100,150,255))
local addNodeBtn    = createButton("Add Node (Q)",          Color3.fromRGB(100,200,100))
local clearNodeBtn  = createButton("Clear Nodes",           Color3.fromRGB(255,180,60))

autoBtn.MouseButton1Click:Connect(function()
	Config.AutoClick = not Config.AutoClick
	autoBtn.Text = Config.AutoClick and "Auto Click : ON" or "Auto Click : OFF"
	autoBtn.BackgroundColor3 = Config.AutoClick and Color3.fromRGB(50,200,50) or Color3.fromRGB(200,50,50)
end)

honeyBtn.MouseButton1Click:Connect(function()
	Config.AutoMakeHoney = not Config.AutoMakeHoney
	honeyBtn.Text = Config.AutoMakeHoney and "Auto Make Honey : ON" or "Auto Make Honey : OFF"
	honeyBtn.BackgroundColor3 = Config.AutoMakeHoney and Color3.fromRGB(255,180,0) or Color3.fromRGB(200,50,50)
	print("Auto Make Honey: " .. (Config.AutoMakeHoney and "ON" or "OFF"))
end)

--==================================================
-- FIELD SYSTEM
--==================================================
local function drawField()
	if not State.Corner1 or not State.Corner2 then return end
	local center = (State.Corner1 + State.Corner2) / 2
	local sizeX = math.abs(State.Corner1.X - State.Corner2.X)
	local sizeZ = math.abs(State.Corner1.Z - State.Corner2.Z)
	if State.FieldVisualizer then State.FieldVisualizer:Destroy() end
	local part = Instance.new("Part")
	part.Anchored = true; part.CanCollide = false; part.Transparency = 0.85
	part.Material = Enum.Material.Neon; part.Color = Color3.fromRGB(120,255,170)
	part.Size = Vector3.new(sizeX, 25, sizeZ)
	part.Position = Vector3.new(center.X, center.Y + 12, center.Z)
	part.Parent = workspace
	State.FieldVisualizer = part
end

local function isPlayerInsideField()
	if not State.Corner1 or not State.Corner2 then return false end
	local char = player.Character; if not char then return false end
	local root = char:FindFirstChild("HumanoidRootPart"); if not root then return false end
	local pos = root.Position
	return pos.X >= math.min(State.Corner1.X, State.Corner2.X)
		and pos.X <= math.max(State.Corner1.X, State.Corner2.X)
		and pos.Z >= math.min(State.Corner1.Z, State.Corner2.Z)
		and pos.Z <= math.max(State.Corner1.Z, State.Corner2.Z)
end

local function getTokensInField()
	local tokens = {}
	if not State.Corner1 or not State.Corner2 then return tokens end
	if not workspace:FindFirstChild("Collectibles") then return tokens end
	local minX = math.min(State.Corner1.X, State.Corner2.X)
	local maxX = math.max(State.Corner1.X, State.Corner2.X)
	local minZ = math.min(State.Corner1.Z, State.Corner2.Z)
	local maxZ = math.max(State.Corner1.Z, State.Corner2.Z)
	for _, v in pairs(workspace.Collectibles:GetChildren()) do
		if v:IsA("BasePart") then
			local p = v.Position
			if p.X >= minX and p.X <= maxX and p.Z >= minZ and p.Z <= maxZ then
				table.insert(tokens, v)
			end
		end
	end
	return tokens
end

local function getNearestToken()
	local char = player.Character; if not char then return nil end
	local root = char:FindFirstChild("HumanoidRootPart"); if not root then return nil end
	local nearest, dist = nil, math.huge
	for _, t in pairs(getTokensInField()) do
		local d = (root.Position - t.Position).Magnitude
		if d < dist then dist = d; nearest = t end
	end
	return nearest
end

local function getRandomPositionInField()
	if not State.Corner1 or not State.Corner2 then return nil end
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
	return Vector3.new(
		math.random() * (math.max(State.Corner1.X, State.Corner2.X) - math.min(State.Corner1.X, State.Corner2.X)) + math.min(State.Corner1.X, State.Corner2.X),
		char.HumanoidRootPart.Position.Y,
		math.random() * (math.max(State.Corner1.Z, State.Corner2.Z) - math.min(State.Corner1.Z, State.Corner2.Z)) + math.min(State.Corner1.Z, State.Corner2.Z)
	)
end

--==================================================
-- POLLEN
--==================================================
local function getPollen()
	local stats = player:FindFirstChild("CoreStats"); if not stats then return 0, 0 end
	local p = stats:FindFirstChild("Pollen")
	local c = stats:FindFirstChild("Capacity")
	if p and c then return p.Value, c.Value end
	return 0, 0
end

--==================================================
-- PRESS E / MAKE HONEY
-- ลำดับการลอง:
--   1. fireproximityprompt (executor function — ทำงานได้ใน Synapse/KRNL/Fluxus)
--   2. ยิง RemoteEvent ตรงๆ ถ้าเจอชื่อ remote ของเกม
--   3. VirtualInputManager fallback
--==================================================
local function pressEAtHive()
	local char = player.Character; if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end

	-- วิธี 1: fireproximityprompt
	local fired = false
	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("ProximityPrompt") then
			local part = obj.Parent
			if part and part:IsA("BasePart") and (root.Position - part.Position).Magnitude < 12 then
				pcall(function()
					fireproximityprompt(obj)
					fired = true
				end)
				if fired then
					print("⚡ fireproximityprompt OK")
					return
				end
			end
		end
	end

	-- วิธี 2: Remote Event ตรงๆ
	local remoteNames = {"MakeHoney", "ConvertPollen", "Honey", "Convert"}
	for _, name in pairs(remoteNames) do
		local r = ReplicatedStorage:FindFirstChild(name)
			or (ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild(name))
		if r and r:IsA("RemoteEvent") then
			pcall(function() r:FireServer() end)
			print("⚡ Remote '" .. name .. "' fired")
			return
		end
	end

	-- วิธี 3: VIM fallback
	pcall(function()
		local vim = game:GetService("VirtualInputManager")
		vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
		task.wait(0.1)
		vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
		print("⚡ VIM E fallback fired")
	end)
end

--==================================================
-- FIELD / NODE BUTTONS
--==================================================
local function setCorner1()
	local char = player.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		State.Corner1 = char.HumanoidRootPart.Position
		print("✓ Corner 1: " .. tostring(State.Corner1))
	end
end
local function setCorner2()
	local char = player.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		State.Corner2 = char.HumanoidRootPart.Position
		drawField()
		print("✓ Corner 2: " .. tostring(State.Corner2))
	end
end

corner1Btn.MouseButton1Click:Connect(setCorner1)
corner2Btn.MouseButton1Click:Connect(setCorner2)
clearFieldBtn.MouseButton1Click:Connect(function()
	State.Corner1 = nil; State.Corner2 = nil
	if State.FieldVisualizer then State.FieldVisualizer:Destroy(); State.FieldVisualizer = nil end
	print("✓ ลบ Field")
end)

local function addNode()
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end
	local pos = char.HumanoidRootPart.Position
	table.insert(State.PathNodes, pos)
	local n = #State.PathNodes
	local node = Instance.new("Part")
	node.Name = "PathNode_" .. n; node.Size = Vector3.new(1,1,1)
	node.Anchored = true; node.CanCollide = false; node.Material = Enum.Material.Neon
	node.Color = n == 1 and Color3.fromRGB(255,100,100) or Color3.fromRGB(0,255,127)
	node.Position = pos; node.Parent = workspace
	local bb = Instance.new("BillboardGui", node)
	bb.Size = UDim2.new(0,50,0,50); bb.MaxDistance = 100
	local tl = Instance.new("TextLabel", bb)
	tl.Size = UDim2.new(1,0,1,0); tl.BackgroundTransparency = 1
	tl.Text = tostring(n); tl.TextColor3 = Color3.new(1,1,1); tl.TextSize = 20
	print("✓ Node " .. n .. ": " .. tostring(pos))
end

local function clearNodes()
	State.PathNodes = {}; State.CurrentNodeIndex = 1; State.PathActive = false
	State.IsInConvertMode = false; State.HasTriggeredConvert = false
	State.HasPressedE = false; State.MakeHoneyCooldown = 0
	for _, v in pairs(workspace:GetChildren()) do
		if v.Name:match("^PathNode_") then v:Destroy() end
	end
	print("✓ ลบ Nodes ทั้งหมด")
end

addNodeBtn.MouseButton1Click:Connect(addNode)
clearNodeBtn.MouseButton1Click:Connect(clearNodes)
pathBtn.MouseButton1Click:Connect(function()
	State.PathActive = not State.PathActive
	pathBtn.Text = State.PathActive and "Path : ON" or "Path : OFF"
	pathBtn.BackgroundColor3 = State.PathActive and Color3.fromRGB(50,200,50) or Color3.fromRGB(100,150,255)
	State.CurrentNodeIndex = 1; State.IsInConvertMode = false
	State.HasTriggeredConvert = false; State.HasPressedE = false
	print("Path: " .. (State.PathActive and "ON" or "OFF"))
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.Z then setCorner1()
	elseif input.KeyCode == Enum.KeyCode.X then setCorner2()
	elseif input.KeyCode == Enum.KeyCode.Q then addNode() end
end)

speedBox.FocusLost:Connect(function()
	local v = tonumber(speedBox.Text)
	if v then Config.Speed = v else speedBox.Text = tostring(Config.Speed) end
end)
jumpBox.FocusLost:Connect(function()
	local v = tonumber(jumpBox.Text)
	if v then Config.Jump = v else jumpBox.Text = tostring(Config.Jump) end
end)

--==================================================
-- AUTO CLICK LOOP
--==================================================
task.spawn(function()
	while true do
		if Config.AutoClick and ToolCollect then
			pcall(function() ToolCollect:FireServer() end)
		end
		task.wait(0.05)
	end
end)

--==================================================
-- AUTO MAKE HONEY LOOP
--==================================================
task.spawn(function()
	while true do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hive = State.PathNodes[1]

		if State.MakeHoneyCooldown > 0 then
			State.MakeHoneyCooldown = State.MakeHoneyCooldown - 1
		end

		local nearHive = root and hive and (root.Position - hive).Magnitude < 10

		-- กรณี 1: Convert Mode เดินมาถึง Node 1 แล้ว → กด E อัตโนมัติ
		if State.IsInConvertMode and State.CurrentNodeIndex == 1
			and not State.HasPressedE and nearHive and State.MakeHoneyCooldown <= 0 then

			State.HasPressedE = true
			State.MakeHoneyCooldown = 20
			print("⚡ Convert: กด E ที่รัง")
			pressEAtHive()
			task.wait(2)
		end

		-- กรณี 2: Manual Auto Make Honey — กดทุก 3 วิ ตราบที่อยู่ใกล้รัง
		if Config.AutoMakeHoney and nearHive
			and State.MakeHoneyCooldown <= 0 and not State.IsInConvertMode then

			State.MakeHoneyCooldown = 30
			print("⚡ Auto Make Honey: กด E")
			pressEAtHive()
			task.wait(2)
		end

		if not nearHive or not State.IsInConvertMode then
			State.HasPressedE = false
		end

		task.wait(0.1)
	end
end)

--==================================================
-- MAIN LOOP
--==================================================
RunService.Heartbeat:Connect(function()
	local char = player.Character; if not char then return end
	local hum  = char:FindFirstChild("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not hum or not root then return end

	hum.WalkSpeed = Config.Speed
	hum.JumpPower  = Config.Jump

	local pollen, capacity = getPollen()

	State.LastPollenCheck = State.LastPollenCheck + 1
	if State.LastPollenCheck >= 20 then
		State.LastPollenCheck = 0

		-- เข้า Convert Mode
		if pollen >= capacity and capacity > 0
			and not State.IsInConvertMode and State.PathActive
			and not State.HasTriggeredConvert then

			State.IsInConvertMode    = true
			State.HasTriggeredConvert = true
			State.HasPressedE         = false
			State.CurrentNodeIndex    = #State.PathNodes
			print("🔄 Pollen FULL! (" .. pollen .. "/" .. capacity .. ") → Converting")
			modeLabel.BackgroundColor3 = Color3.fromRGB(255,100,50)
			modeLabel.Text = "Mode: Converting"
		end

		-- ออก Convert Mode เมื่อ pollen ลดแล้ว
		if State.IsInConvertMode and pollen < (capacity * 0.15) and State.PathActive then
			State.IsInConvertMode     = false
			State.HasTriggeredConvert = false
			State.HasPressedE         = false
			State.CurrentNodeIndex    = 1
			print("✓ Convert เสร็จ! Pollen: " .. pollen .. "/" .. capacity)
			modeLabel.BackgroundColor3 = Color3.fromRGB(60,100,60)
			modeLabel.Text = "Mode: Collecting"
		end
	end

	if State.PathActive and #State.PathNodes >= 2 then

		-- เช็ค Convert Mode ก่อนเสมอ ก่อน isPlayerInsideField() จะ return ออก
		if not State.IsInConvertMode and isPlayerInsideField() then
			local token = getNearestToken()
			if token then
				hum:MoveTo(token.Position)
				statusLabel.Text = "📦 Collecting Token | Pollen: " .. pollen .. "/" .. capacity
				modeLabel.Text = "Priority: Token Collect"
				modeLabel.BackgroundColor3 = Color3.fromRGB(100,200,100)
				return
			end
			State.RandomTimer = State.RandomTimer + 1
			if State.RandomTimer > 40 then
				State.RandomTarget = getRandomPositionInField()
				State.RandomTimer  = 0
			end
			if State.RandomTarget then
				hum:MoveTo(State.RandomTarget)
				statusLabel.Text = "🚶 Random Walk | Pollen: " .. pollen .. "/" .. capacity
				modeLabel.Text = "Priority: Random Walk"
				modeLabel.BackgroundColor3 = Color3.fromRGB(100,150,255)
				return
			end
		end

		if State.IsInConvertMode then
			local target = State.PathNodes[State.CurrentNodeIndex]
			if target then
				hum:MoveTo(target)
				local dist = (root.Position - target).Magnitude
				statusLabel.Text = string.format("🔄 Converting [%d/%d] | Pollen: %d/%d",
					State.CurrentNodeIndex, #State.PathNodes, pollen, capacity)
				modeLabel.Text = "Path: Converting (End→Start)"
				modeLabel.BackgroundColor3 = Color3.fromRGB(255,100,50)
				if dist < 4 then
					State.CurrentNodeIndex = math.max(1, State.CurrentNodeIndex - 1)
				end
			end
		else
			local target = State.PathNodes[State.CurrentNodeIndex]
			if target then
				hum:MoveTo(target)
				local dist = (root.Position - target).Magnitude
				statusLabel.Text = string.format("📍 Moving [%d/%d] | Pollen: %d/%d",
					State.CurrentNodeIndex, #State.PathNodes, pollen, capacity)
				modeLabel.Text = "Path: Collecting (Start→End)"
				modeLabel.BackgroundColor3 = Color3.fromRGB(60,100,60)
				if dist < 4 then
					State.CurrentNodeIndex = math.min(#State.PathNodes, State.CurrentNodeIndex + 1)
				end
			end
		end

	else
		if isPlayerInsideField() then
			local token = getNearestToken()
			if token then
				hum:MoveTo(token.Position)
				statusLabel.Text = "📦 Collecting | Pollen: " .. pollen .. "/" .. capacity
				modeLabel.Text = "Mode: Field Collect"
				modeLabel.BackgroundColor3 = Color3.fromRGB(60,100,60)
				return
			end
			State.RandomTimer = State.RandomTimer + 1
			if State.RandomTimer > 40 then
				State.RandomTarget = getRandomPositionInField()
				State.RandomTimer  = 0
			end
			if State.RandomTarget then
				hum:MoveTo(State.RandomTarget)
				statusLabel.Text = "🚶 Random Walking"
				modeLabel.Text = "Mode: Random Walk"
				modeLabel.BackgroundColor3 = Color3.fromRGB(100,150,255)
			end
			return
		end
		statusLabel.Text = "Status: Outside Field / Path OFF"
		modeLabel.Text   = "Status: Ready"
	end
end)
