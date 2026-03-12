--==================================================
-- BSS AUTO FARM v5
-- GUI: Dark Red theme, categorized sections
--==================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local VIM              = game:GetService("VirtualInputManager")
local player           = Players.LocalPlayer

if player.PlayerGui:FindFirstChild("AutoFarmGui") then
	player.PlayerGui.AutoFarmGui:Destroy()
end

--==================================================
-- CONFIG & STATE
--==================================================
local CFG = {
	Speed       = 78,
	Jump        = 100,
	AutoClick   = false,
	AutoHoney   = false,
	PathActive  = false,
	AntiAFK     = false,
	AutoBooster = false,
}

local S = {
	Nodes        = {},
	NodeIdx      = 1,
	Converting   = false,
	ConvertDone  = false,
	Corner1      = nil,
	Corner2      = nil,
	FieldPart    = nil,
	RandomTarget = nil,
	RandomTick   = 0,
	PollTick     = 0,
	LastPos      = nil,
	StuckTick    = 0,
	ConvertStart = nil,
	IsBoosting   = false,
}

--==================================================
-- GUI - Dark Red Theme
--==================================================
local C = {
	bg       = Color3.fromRGB(18, 12, 12),
	panel    = Color3.fromRGB(32, 18, 18),
	header   = Color3.fromRGB(90, 20, 20),
	btn      = Color3.fromRGB(110, 25, 25),
	btnOn    = Color3.fromRGB(180, 50, 50),
	btnGreen = Color3.fromRGB(35, 120, 55),
	btnBlue  = Color3.fromRGB(35, 75, 150),
	btnOrange= Color3.fromRGB(150, 85, 15),
	status   = Color3.fromRGB(28, 16, 16),
	text     = Color3.new(1, 1, 1),
	subtext  = Color3.fromRGB(210, 170, 170),
}

local gui = Instance.new("ScreenGui")
gui.Name = "AutoFarmGui"
gui.ResetOnSpawn = false
gui.Parent = player.PlayerGui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 248, 0, 0)
frame.Position = UDim2.new(0, 10, 0, 80)
frame.BackgroundColor3 = C.bg
frame.BorderSizePixel = 0
frame.AutomaticSize = Enum.AutomaticSize.Y
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local mainList = Instance.new("UIListLayout", frame)
mainList.Padding = UDim.new(0, 3)
mainList.SortOrder = Enum.SortOrder.LayoutOrder

local mainPad = Instance.new("UIPadding", frame)
mainPad.PaddingLeft   = UDim.new(0, 6)
mainPad.PaddingRight  = UDim.new(0, 6)
mainPad.PaddingTop    = UDim.new(0, 6)
mainPad.PaddingBottom = UDim.new(0, 6)

-- Drag support
do
	local drag, ds, sp = false, nil, nil
	frame.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			drag = true; ds = i.Position; sp = frame.Position
		end
	end)
	frame.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
			local d = i.Position - ds
			frame.Position = UDim2.new(sp.X.Scale, sp.X.Offset+d.X, sp.Y.Scale, sp.Y.Offset+d.Y)
		end
	end)
end

local order = 0
local function nO() order += 1; return order end

local function mkHeader(text)
	local f = Instance.new("Frame", frame)
	f.Size = UDim2.new(1, 0, 0, 20)
	f.BackgroundColor3 = C.header
	f.BorderSizePixel = 0
	f.LayoutOrder = nO()
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 4)
	local l = Instance.new("TextLabel", f)
	l.Size = UDim2.new(1, -8, 1, 0)
	l.Position = UDim2.new(0, 6, 0, 0)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = Color3.fromRGB(255, 195, 195)
	l.TextSize = 10
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	return f
end

local function mkLabel(text, bg)
	local l = Instance.new("TextLabel", frame)
	l.Size = UDim2.new(1, 0, 0, 22)
	l.BackgroundColor3 = bg or C.status
	l.TextColor3 = C.text
	l.BorderSizePixel = 0
	l.Text = text
	l.TextSize = 11
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")
	l.LayoutOrder = nO()
	Instance.new("UICorner", l).CornerRadius = UDim.new(0, 4)
	return l
end

local function mkBtn(text, bg)
	local b = Instance.new("TextButton", frame)
	b.Size = UDim2.new(1, 0, 0, 28)
	b.BackgroundColor3 = bg or C.btn
	b.TextColor3 = C.text
	b.BorderSizePixel = 0
	b.Text = text
	b.TextSize = 12
	b.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	b.LayoutOrder = nO()
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
	return b
end

local function mkBtnRow(textA, bgA, textB, bgB)
	local f = Instance.new("Frame", frame)
	f.Size = UDim2.new(1, 0, 0, 28)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.LayoutOrder = nO()
	local row = Instance.new("UIListLayout", f)
	row.FillDirection = Enum.FillDirection.Horizontal
	row.Padding = UDim.new(0, 4)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	local function mkHalf(text, bg, lo)
		local b = Instance.new("TextButton", f)
		b.Size = UDim2.new(0.5, -2, 1, 0)
		b.BackgroundColor3 = bg or C.btn
		b.TextColor3 = C.text
		b.BorderSizePixel = 0
		b.Text = text
		b.TextSize = 11
		b.LayoutOrder = lo
		b.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
		return b
	end
	return f, mkHalf(textA, bgA, 1), mkHalf(textB, bgB, 2)
end

local function mkInput(label, default)
	local wrap = Instance.new("Frame", frame)
	wrap.Size = UDim2.new(1, 0, 0, 44)
	wrap.BackgroundColor3 = C.panel
	wrap.BorderSizePixel = 0
	wrap.LayoutOrder = nO()
	Instance.new("UICorner", wrap).CornerRadius = UDim.new(0, 4)
	local lbl = Instance.new("TextLabel", wrap)
	lbl.Size = UDim2.new(1, -8, 0, 18)
	lbl.Position = UDim2.new(0, 6, 0, 2)
	lbl.Text = label
	lbl.TextColor3 = C.subtext
	lbl.BackgroundTransparency = 1
	lbl.TextSize = 10
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")
	local box = Instance.new("TextBox", wrap)
	box.Size = UDim2.new(1, -8, 0, 20)
	box.Position = UDim2.new(0, 4, 0, 20)
	box.Text = tostring(default)
	box.BackgroundColor3 = Color3.fromRGB(55, 28, 28)
	box.TextColor3 = C.text
	box.BorderSizePixel = 0
	box.TextSize = 12
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
	return box
end

local function toggle(btn, state, onT, offT, onC, offC)
	btn.Text = state and onT or offT
	btn.BackgroundColor3 = state and (onC or C.btnOn) or (offC or C.btn)
end

--==================================================
-- BUILD GUI ELEMENTS
--==================================================

-- Title
local titleLbl = Instance.new("TextLabel", frame)
titleLbl.Size = UDim2.new(1, 0, 0, 30)
titleLbl.BackgroundColor3 = Color3.fromRGB(65, 8, 8)
titleLbl.TextColor3 = Color3.fromRGB(255, 185, 185)
titleLbl.BorderSizePixel = 0
titleLbl.Text = "🍯  BSS Auto Farm  v5"
titleLbl.TextSize = 13
titleLbl.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
titleLbl.LayoutOrder = nO()
Instance.new("UICorner", titleLbl).CornerRadius = UDim.new(0, 6)

-- ── STATUS ──
mkHeader("▸  STATUS")
local statusLbl = mkLabel("◉  Ready", C.status)
local modeLbl   = mkLabel("Mode: Idle", C.status)
local pollenLbl = mkLabel("🌼  Pollen: --/--", Color3.fromRGB(28, 18, 40))

-- ── SETTINGS ──
mkHeader("▸  SETTINGS")
local speedBox = mkInput("WalkSpeed", CFG.Speed)
local jumpBox  = mkInput("JumpPower",  CFG.Jump)

-- ── AUTOMATION ──
mkHeader("▸  AUTOMATION")
local btnAutoClick = mkBtn("Auto Click : OFF",       C.btn)
local btnHoney     = mkBtn("Auto Make Honey : OFF",  C.btn)
local btnAntiAFK   = mkBtn("Anti-AFK : OFF",         C.btn)

-- ── FIELD ──
mkHeader("▸  FIELD")
local _, btnCorner1, btnCorner2 = mkBtnRow("Set Corner 1  [Z]", C.btnBlue, "Set Corner 2  [X]", C.btnBlue)
local btnClearFld = mkBtn("Clear Field", Color3.fromRGB(100, 38, 12))

-- ── PATH ──
mkHeader("▸  PATH & NODES")
local btnPath = mkBtn("Path : OFF", C.btnBlue)
local _, btnAddNode, btnClearNode = mkBtnRow("Add Node  [Q]", C.btnGreen, "Clear Nodes", C.btnOrange)

-- ── BOOSTER ──
mkHeader("▸  FIELD BOOSTER")
local btnBooster = mkBtn("Auto Booster : OFF", C.btn)

local bRow = Instance.new("Frame", frame)
bRow.Size = UDim2.new(1, 0, 0, 34)
bRow.BackgroundTransparency = 1
bRow.BorderSizePixel = 0
bRow.LayoutOrder = nO()
local bRowList = Instance.new("UIListLayout", bRow)
bRowList.FillDirection = Enum.FillDirection.Horizontal
bRowList.Padding = UDim.new(0, 3)
bRowList.SortOrder = Enum.SortOrder.LayoutOrder

local bColors = {
	Color3.fromRGB(28, 55, 130),
	Color3.fromRGB(110, 22, 22),
	Color3.fromRGB(28, 88, 28),
}
local bNames = {"Blue", "Red", "Mtn"}
local bLbls  = {}
for i = 1, 3 do
	local l = Instance.new("TextLabel", bRow)
	l.Size = UDim2.new(0.333, -2, 1, 0)
	l.BackgroundColor3 = bColors[i]
	l.TextColor3 = C.text
	l.BorderSizePixel = 0
	l.Text = bNames[i].."\n--"
	l.TextSize = 10
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")
	l.LayoutOrder = i
	Instance.new("UICorner", l).CornerRadius = UDim.new(0, 4)
	bLbls[i] = l
end

--==================================================
-- HELPERS
--==================================================
local function getChar()
	local c = player.Character; if not c then return nil,nil,nil end
	return c, c:FindFirstChild("Humanoid"), c:FindFirstChild("HumanoidRootPart")
end

local function getPollen()
	local stats = player:FindFirstChild("CoreStats"); if not stats then return 0,1 end
	local p   = stats:FindFirstChild("Pollen")
	local cap = stats:FindFirstChild("Capacity")
	return (p and p.Value or 0), (cap and cap.Value or 1)
end

local function insideField(pos)
	if not S.Corner1 or not S.Corner2 then return false end
	return pos.X >= math.min(S.Corner1.X,S.Corner2.X)
		and pos.X <= math.max(S.Corner1.X,S.Corner2.X)
		and pos.Z >= math.min(S.Corner1.Z,S.Corner2.Z)
		and pos.Z <= math.max(S.Corner1.Z,S.Corner2.Z)
end

local function nearestToken(root)
	local col = workspace:FindFirstChild("Collectibles"); if not col then return nil end
	local best, bestD = nil, math.huge
	for _,v in ipairs(col:GetChildren()) do
		if v:IsA("BasePart") and insideField(v.Position) then
			local d = (root.Position-v.Position).Magnitude
			if d < bestD then bestD=d; best=v end
		end
	end
	return best
end

local function randomInField(y)
	if not S.Corner1 or not S.Corner2 then return nil end
	local minX,maxX = math.min(S.Corner1.X,S.Corner2.X), math.max(S.Corner1.X,S.Corner2.X)
	local minZ,maxZ = math.min(S.Corner1.Z,S.Corner2.Z), math.max(S.Corner1.Z,S.Corner2.Z)
	return Vector3.new(minX+math.random()*(maxX-minX), y, minZ+math.random()*(maxZ-minZ))
end

local function drawField()
	if S.FieldPart then S.FieldPart:Destroy() end
	if not S.Corner1 or not S.Corner2 then return end
	local c = (S.Corner1+S.Corner2)/2
	local p = Instance.new("Part")
	p.Anchored=true; p.CanCollide=false; p.Transparency=0.82
	p.Material=Enum.Material.Neon; p.Color=Color3.fromRGB(255,100,100)
	p.Size=Vector3.new(math.abs(S.Corner1.X-S.Corner2.X),20,math.abs(S.Corner1.Z-S.Corner2.Z))
	p.Position=Vector3.new(c.X,c.Y+10,c.Z); p.Parent=workspace; S.FieldPart=p
end

local function spawnNodePart(pos, n)
	local p = Instance.new("Part")
	p.Name="AutoFarmNode_"..n; p.Size=Vector3.new(1,1,1)
	p.Anchored=true; p.CanCollide=false; p.Material=Enum.Material.Neon
	p.Color = n==1 and Color3.fromRGB(255,80,80) or Color3.fromRGB(0,230,120)
	p.Position=pos; p.Parent=workspace
	local bb=Instance.new("BillboardGui",p)
	bb.Size=UDim2.new(0,40,0,40); bb.MaxDistance=80
	local tl=Instance.new("TextLabel",bb)
	tl.Size=UDim2.new(1,0,1,0); tl.BackgroundTransparency=1
	tl.Text=tostring(n); tl.TextColor3=Color3.new(1,1,1); tl.TextSize=18
end

local function clearNodeParts()
	for _,v in ipairs(workspace:GetChildren()) do
		if v.Name:match("^AutoFarmNode_") then v:Destroy() end
	end
end

--==================================================
-- MAKE HONEY
--==================================================
local function pressE()
	pcall(function()
		VIM:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
		task.wait(0.1)
		VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
	end)
end

task.spawn(function()
	while true do
		task.wait(0.2)
		local _,_,root = getChar(); if not root then continue end
		local pollen, cap = getPollen()
		local hive = S.Nodes[1]
		local nearHive = hive and (root.Position-hive).Magnitude < 8
		local active = nearHive and pollen > 0 and (
			(S.Converting and S.NodeIdx==1) or CFG.AutoHoney
		)
		if not active then continue end

		local stats = player:FindFirstChild("CoreStats")
		local pollenVal = stats and stats:FindFirstChild("Pollen")
		if not pollenVal then pressE(); task.wait(10); continue end

		print("🍯 Make Honey | "..pollen.."/"..cap)

		local lastChangeTick = tick()
		local lastPollen     = pollenVal.Value
		local session        = true

		local conn = pollenVal.Changed:Connect(function(newVal)
			if newVal < lastPollen then
				lastChangeTick = tick()
				pollenLbl.Text = string.format("🌼  %d / %d", newVal, cap)
			end
			if newVal <= 0 then session = false end
			lastPollen = newVal
		end)

		pressE()

		while session do
			task.wait(0.2)
			local p = pollenVal.Value
			if p <= 0 then break end
			local _,_,r2 = getChar()
			local h2 = S.Nodes[1]
			if not r2 or not h2 or (r2.Position-h2).Magnitude >= 8 then break end
			if not CFG.AutoHoney and not (S.Converting and S.NodeIdx==1) then break end
			if tick() - lastChangeTick >= 2.5 then
				lastChangeTick = tick()
				pressE()
			end
		end

		conn:Disconnect()
	end
end)

--==================================================
-- BUTTON LOGIC
--==================================================
speedBox.FocusLost:Connect(function()
	local v = tonumber(speedBox.Text)
	if v then CFG.Speed=v else speedBox.Text=tostring(CFG.Speed) end
end)
jumpBox.FocusLost:Connect(function()
	local v = tonumber(jumpBox.Text)
	if v then CFG.Jump=v else jumpBox.Text=tostring(CFG.Jump) end
end)

btnAutoClick.MouseButton1Click:Connect(function()
	CFG.AutoClick = not CFG.AutoClick
	toggle(btnAutoClick, CFG.AutoClick, "Auto Click : ON", "Auto Click : OFF")
end)

btnHoney.MouseButton1Click:Connect(function()
	CFG.AutoHoney = not CFG.AutoHoney
	toggle(btnHoney, CFG.AutoHoney,
		"Auto Make Honey : ON", "Auto Make Honey : OFF", C.btnOrange, C.btn)
end)

btnAntiAFK.MouseButton1Click:Connect(function()
	CFG.AntiAFK = not CFG.AntiAFK
	toggle(btnAntiAFK, CFG.AntiAFK, "Anti-AFK : ON", "Anti-AFK : OFF")
end)

btnBooster.MouseButton1Click:Connect(function()
	CFG.AutoBooster = not CFG.AutoBooster
	toggle(btnBooster, CFG.AutoBooster, "Auto Booster : ON", "Auto Booster : OFF")
end)

local function setCorner1()
	local _,_,root=getChar(); if not root then return end
	S.Corner1=root.Position; print("📍 Corner1")
end
local function setCorner2()
	local _,_,root=getChar(); if not root then return end
	S.Corner2=root.Position; drawField(); print("📍 Corner2")
end

btnCorner1.MouseButton1Click:Connect(setCorner1)
btnCorner2.MouseButton1Click:Connect(setCorner2)
btnClearFld.MouseButton1Click:Connect(function()
	S.Corner1=nil; S.Corner2=nil
	if S.FieldPart then S.FieldPart:Destroy(); S.FieldPart=nil end
end)

local function addNode()
	local _,_,root=getChar(); if not root then return end
	table.insert(S.Nodes, root.Position)
	spawnNodePart(root.Position, #S.Nodes)
	print("📌 Node "..#S.Nodes)
end
local function clearNodes()
	S.Nodes={}; S.NodeIdx=1; S.Converting=false; S.ConvertDone=false
	clearNodeParts()
end

btnAddNode.MouseButton1Click:Connect(addNode)
btnClearNode.MouseButton1Click:Connect(clearNodes)

btnPath.MouseButton1Click:Connect(function()
	CFG.PathActive = not CFG.PathActive
	S.NodeIdx=1; S.Converting=false; S.ConvertDone=false
	toggle(btnPath, CFG.PathActive, "Path : ON", "Path : OFF", C.btnGreen, C.btnBlue)
end)

UserInputService.InputBegan:Connect(function(i, gp)
	if gp then return end
	if i.KeyCode==Enum.KeyCode.Z then setCorner1()
	elseif i.KeyCode==Enum.KeyCode.X then setCorner2()
	elseif i.KeyCode==Enum.KeyCode.Q then addNode()
	end
end)

--==================================================
-- AUTO CLICK
--==================================================
local ToolCollect
pcall(function()
	ToolCollect = ReplicatedStorage:WaitForChild("Events",5):WaitForChild("ToolCollect",5)
end)
task.spawn(function()
	while true do
		if CFG.AutoClick and ToolCollect then
			pcall(function() ToolCollect:FireServer() end)
		end
		task.wait(0.05)
	end
end)

--==================================================
-- AUTO FIELD BOOSTER
--==================================================
local BOOSTERS = {
	{name="Blue Field Booster",  pos=Vector3.new(271,65,82)},
	{name="Red Field Booster",   pos=Vector3.new(-316,28,243)},
	{name="Field Booster",       pos=Vector3.new(-40,184,-190)},
}
local READY_CLR  = Color3.fromRGB(35, 150, 50)
local BOOSTER_CD = 45 * 60  -- 45 นาที (2700 วิ)
local lastUsed   = {}       -- lastUsed[name] = tick() ตอนกดสำเร็จ

local function boosterReady(name)
	local t = lastUsed[name]
	if not t then return true end
	return (tick() - t) >= BOOSTER_CD
end

local function boosterTimeLeft(name)
	local t = lastUsed[name]
	if not t then return 0 end
	return math.max(0, math.floor(BOOSTER_CD - (tick() - t)))
end

-- loop อัพเดต label ทุก 1 วิ (ทำงานตลอด)
task.spawn(function()
	while true do
		task.wait(1)
		if S.IsBoosting then continue end
		for i, b in ipairs(BOOSTERS) do
			if boosterReady(b.name) then
				bLbls[i].Text = bNames[i].."\n✅ READY"
				bLbls[i].BackgroundColor3 = READY_CLR
			else
				local left = boosterTimeLeft(b.name)
				local m = math.floor(left/60)
				local s = left % 60
				bLbls[i].Text = string.format("%s\n%dm%ds", bNames[i], m, s)
				bLbls[i].BackgroundColor3 = bColors[i]
			end
		end
	end
end)

-- loop teleport ไปกด (เฉพาะตอน AutoBooster ON)
task.spawn(function()
	while true do
		task.wait(2)
		if not CFG.AutoBooster then continue end
		if S.IsBoosting then continue end
		if S.Converting then continue end

		local _,hum,root = getChar()
		if not hum or not root or hum.Health<=0 then continue end

		local pending = {}
		for i, b in ipairs(BOOSTERS) do
			if boosterReady(b.name) then
				table.insert(pending, {b=b, idx=i})
			end
		end
		if #pending == 0 then continue end

		S.IsBoosting = true
		local hivePos = S.Nodes[1]

		for _, entry in ipairs(pending) do
			local b   = entry.b
			local idx = entry.idx
			if not boosterReady(b.name) then continue end

			local _,_,r2 = getChar(); if not r2 then break end

			bLbls[idx].Text = bNames[idx].."\n⚡ Going..."
			bLbls[idx].BackgroundColor3 = C.btnOrange

			r2.CFrame = CFrame.new(b.pos + Vector3.new(0, 3, 0))
			print("🚀 → "..b.name)
			task.wait(1.5)

			pressE()
			task.wait(1)

			lastUsed[b.name] = tick()
			bLbls[idx].Text  = bNames[idx].."\n✔ Done"
			print("✅ "..b.name)
		end

		if hivePos then
			local _,_,r3 = getChar()
			if r3 then
				r3.CFrame = CFrame.new(hivePos + Vector3.new(0,3,0))
				print("🏠 กลับรัง")
				task.wait(0.5)
			end
		end

		S.IsBoosting = false
	end
end)

--==================================================
-- WATCHDOG
--==================================================
task.spawn(function()
	while true do
		task.wait(8)
		local _,hum,root = getChar()
		if not root or not hum or hum.Health<=0 then continue end
		local pos  = root.Position
		local hive = S.Nodes[1]
		local nearHive = hive and (pos-hive).Magnitude < 8
		if nearHive and (S.Converting or CFG.AutoHoney) then
			S.LastPos = pos; continue
		end
		if S.LastPos and (pos-S.LastPos).Magnitude < 2 then
			S.StuckTick += 1
			print("⚠ STUCK x"..S.StuckTick)
			if not S.Converting then
				S.RandomTarget = randomInField(pos.Y)
				S.RandomTick = 0
			end
		else
			S.StuckTick = 0
		end
		S.LastPos = pos
	end
end)

--==================================================
-- RESPAWN RECOVERY
--==================================================
task.spawn(function()
	while true do
		task.wait(1)
		local _,hum,_ = getChar(); if not hum then continue end
		if hum.Health <= 0 then
			modeLbl.Text = "💀 Respawning..."
			modeLbl.BackgroundColor3 = Color3.fromRGB(80,15,15)
			task.wait(6)
			S.Converting=false; S.ConvertDone=false
			S.NodeIdx=1; S.RandomTarget=nil; S.RandomTick=0
			S.LastPos=nil; S.ConvertStart=nil
			modeLbl.Text = "Mode: Collecting"
			modeLbl.BackgroundColor3 = C.status
		end
	end
end)

--==================================================
-- CONVERT SAFETY RESET
--==================================================
task.spawn(function()
	while true do
		task.wait(5)
		if S.Converting then
			S.ConvertStart = S.ConvertStart or tick()
			if tick()-S.ConvertStart > 180 then
				S.Converting=false; S.ConvertDone=false
				S.NodeIdx=1; S.ConvertStart=nil
				modeLbl.Text = "Mode: Collecting"
				modeLbl.BackgroundColor3 = C.status
				print("⚠ Convert force reset")
			end
		else
			S.ConvertStart = nil
		end
	end
end)

--==================================================
-- ANTI-AFK
--==================================================
task.spawn(function()
	while true do
		task.wait(120)
		if not CFG.AntiAFK then continue end
		local _,hum,_ = getChar()
		if not hum or hum.Health<=0 then continue end
		pcall(function()
			VIM:SendKeyEvent(true,  Enum.KeyCode.W, false, game)
			task.wait(0.1)
			VIM:SendKeyEvent(false, Enum.KeyCode.W, false, game)
		end)
		print("🔄 Anti-AFK")
	end
end)

--==================================================
-- MAIN LOOP
--==================================================
RunService.Heartbeat:Connect(function()
	local _,hum,root = getChar()
	if not hum or not root or hum.Health<=0 then return end

	hum.WalkSpeed = CFG.Speed
	hum.JumpPower = CFG.Jump

	local pollen, cap = getPollen()
	pollenLbl.Text = string.format("🌼  %d / %d", pollen, cap)

	S.PollTick += 1
	if S.PollTick >= 20 then
		S.PollTick = 0

		if CFG.PathActive and #S.Nodes>=2
			and pollen>=cap and cap>0
			and not S.Converting and not S.ConvertDone then
			S.Converting=true; S.ConvertDone=true
			S.NodeIdx=#S.Nodes; S.ConvertStart=tick()
			modeLbl.Text = "⚠ Converting..."
			modeLbl.BackgroundColor3 = Color3.fromRGB(130,50,15)
		end

		if S.Converting and pollen<=0 then
			S.Converting=false; S.ConvertDone=false
			S.NodeIdx=1; S.ConvertStart=nil
			modeLbl.Text = "Mode: Collecting"
			modeLbl.BackgroundColor3 = C.status
		end
	end

	if S.IsBoosting then
		statusLbl.Text = "🚀 Boosting..."
		return
	end

	if CFG.PathActive and #S.Nodes>=2 then

		if S.Converting then
			local target = S.Nodes[S.NodeIdx]
			if target then
				hum:MoveTo(target)
				statusLbl.Text = string.format("🔄 [%d/%d] %d/%d", S.NodeIdx, #S.Nodes, pollen, cap)
				if (root.Position-target).Magnitude<4 and S.NodeIdx>1 then
					S.NodeIdx -= 1
				end
			end
			return
		end

		if insideField(root.Position) then
			local token = nearestToken(root)
			if token then
				hum:MoveTo(token.Position)
				statusLbl.Text = "📦 Token | "..pollen.."/"..cap
				modeLbl.Text = "Field: Token"
				modeLbl.BackgroundColor3 = Color3.fromRGB(28,65,28)
				return
			end
			S.RandomTick += 1
			if S.RandomTick > 40 then
				S.RandomTarget = randomInField(root.Position.Y); S.RandomTick=0
			end
			if S.RandomTarget then
				hum:MoveTo(S.RandomTarget)
				statusLbl.Text = "🚶 Walking | "..pollen.."/"..cap
				modeLbl.Text = "Field: Walk"
				modeLbl.BackgroundColor3 = Color3.fromRGB(25,45,90)
			end
			return
		end

		while S.NodeIdx < #S.Nodes do
			if (root.Position-S.Nodes[S.NodeIdx]).Magnitude < 4 then
				S.NodeIdx += 1
			else break end
		end
		local target = S.Nodes[S.NodeIdx]
		if target then
			hum:MoveTo(target)
			statusLbl.Text = string.format("📍 [%d/%d] %d/%d", S.NodeIdx, #S.Nodes, pollen, cap)
			modeLbl.Text = "Path: To Field"
			modeLbl.BackgroundColor3 = C.status
			if (root.Position-target).Magnitude<4 and S.NodeIdx<#S.Nodes then
				S.NodeIdx += 1
			end
		end

	elseif S.Corner1 and S.Corner2 then
		if insideField(root.Position) then
			local token = nearestToken(root)
			if token then
				hum:MoveTo(token.Position)
				statusLbl.Text = "📦 Field | "..pollen.."/"..cap
				return
			end
			S.RandomTick += 1
			if S.RandomTick > 40 then
				S.RandomTarget = randomInField(root.Position.Y); S.RandomTick=0
			end
			if S.RandomTarget then
				hum:MoveTo(S.RandomTarget)
				statusLbl.Text = "🚶 Random | "..pollen.."/"..cap
			end
			return
		end
		statusLbl.Text = "⏸ Outside Field"
		modeLbl.Text = "Idle"; modeLbl.BackgroundColor3 = C.status
	else
		statusLbl.Text = "⏸ Set Field / Path to start"
		modeLbl.Text = "Idle"; modeLbl.BackgroundColor3 = C.status
	end
end)

print("✅ BSS AutoFarm v5 loaded")
