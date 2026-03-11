--==================================================
-- BSS AUTO FARM - STABLE BUILD v4
-- Make Honey: ติดตาม pollen real-time ไม่ใช้ timer
-- Watchdog: stuck detection, respawn recovery
--==================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local VIM              = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

if player.PlayerGui:FindFirstChild("AutoFarmGui") then
	player.PlayerGui.AutoFarmGui:Destroy()
end

--==================================================
-- CONFIG
--==================================================
local CFG = {
	Speed      = 78,
	Jump       = 100,
	AutoClick  = false,
	AutoHoney  = false,
	PathActive = false,
}

--==================================================
-- STATE
--==================================================
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

	-- Watchdog
	LastPos      = nil,
	StuckTick    = 0,

	-- Convert safety timer
	ConvertStart = nil,
}

--==================================================
-- GUI
--==================================================
local gui = Instance.new("ScreenGui")
gui.Name = "AutoFarmGui"; gui.ResetOnSpawn = false
gui.Parent = player.PlayerGui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0,244,0,0)
frame.Position = UDim2.new(0,10,0,80)
frame.BackgroundColor3 = Color3.fromRGB(22,22,22)
frame.BorderSizePixel = 0
frame.AutomaticSize = Enum.AutomaticSize.Y

local uiList = Instance.new("UIListLayout", frame)
uiList.Padding = UDim.new(0,4)
uiList.SortOrder = Enum.SortOrder.LayoutOrder
local uiPad = Instance.new("UIPadding", frame)
uiPad.PaddingLeft   = UDim.new(0,6); uiPad.PaddingRight  = UDim.new(0,6)
uiPad.PaddingTop    = UDim.new(0,6); uiPad.PaddingBottom = UDim.new(0,6)

do
	local drag,ds,sp = false,nil,nil
	frame.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			drag=true; ds=i.Position; sp=frame.Position
		end
	end)
	frame.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then drag=false end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
			local d = i.Position-ds
			frame.Position = UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
		end
	end)
end

local order = 0
local function nO() order+=1; return order end

local function mkLabel(text,bg)
	local l = Instance.new("TextLabel",frame)
	l.Size = UDim2.new(1,0,0,26); l.Text = text
	l.BackgroundColor3 = bg or Color3.fromRGB(40,40,40)
	l.TextColor3 = Color3.new(1,1,1); l.BorderSizePixel = 0
	l.TextSize = 12; l.TextXAlignment = Enum.TextXAlignment.Center
	l.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")
	l.LayoutOrder = nO(); return l
end

local function mkBtn(text,bg)
	local b = Instance.new("TextButton",frame)
	b.Size = UDim2.new(1,0,0,32); b.Text = text
	b.BackgroundColor3 = bg; b.TextColor3 = Color3.new(1,1,1)
	b.BorderSizePixel = 0; b.TextSize = 13
	b.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json",Enum.FontWeight.Bold)
	b.LayoutOrder = nO(); return b
end

local function mkInput(label,default)
	local wrap = Instance.new("Frame",frame)
	wrap.Size = UDim2.new(1,0,0,42)
	wrap.BackgroundColor3 = Color3.fromRGB(35,35,35)
	wrap.BorderSizePixel = 0; wrap.LayoutOrder = nO()
	local lbl = Instance.new("TextLabel",wrap)
	lbl.Size = UDim2.new(1,0,0,18); lbl.Text = label
	lbl.TextColor3 = Color3.fromRGB(180,180,180)
	lbl.BackgroundTransparency = 1; lbl.TextSize = 11; lbl.BorderSizePixel = 0
	local box = Instance.new("TextBox",wrap)
	box.Size = UDim2.new(1,0,0,22); box.Position = UDim2.new(0,0,0,20)
	box.Text = tostring(default)
	box.BackgroundColor3 = Color3.fromRGB(50,50,50)
	box.TextColor3 = Color3.new(1,1,1); box.BorderSizePixel = 0; box.TextSize = 13
	return box
end

local function toggle(btn,state,onC,offC,onT,offT)
	btn.Text = state and onT or offT
	btn.BackgroundColor3 = state and onC or offC
end

local speedBox     = mkInput("WalkSpeed", CFG.Speed)
local jumpBox      = mkInput("JumpPower",  CFG.Jump)
local statusLbl    = mkLabel("◉ Ready",           Color3.fromRGB(40,40,40))
local modeLbl      = mkLabel("Mode: Idle",         Color3.fromRGB(40,70,40))
local pollenLbl    = mkLabel("🌼 Pollen: --/--",   Color3.fromRGB(30,50,70))
local watchdogLbl  = mkLabel("🛡 Watchdog: ON",    Color3.fromRGB(30,60,30))
local btnAutoClick = mkBtn("Auto Click : OFF",       Color3.fromRGB(160,40,40))
local btnHoney     = mkBtn("Auto Make Honey : OFF",  Color3.fromRGB(160,40,40))
local btnCorner1   = mkBtn("Set Corner 1  [Z]",      Color3.fromRGB(50,100,200))
local btnCorner2   = mkBtn("Set Corner 2  [X]",      Color3.fromRGB(50,100,200))
local btnClearFld  = mkBtn("Clear Field",            Color3.fromRGB(180,70,40))
local btnPath      = mkBtn("Path : OFF",             Color3.fromRGB(70,70,180))
local btnAddNode   = mkBtn("Add Node  [Q]",          Color3.fromRGB(50,160,80))
local btnClearNode = mkBtn("Clear Nodes",            Color3.fromRGB(180,130,30))

--==================================================
-- HELPERS
--==================================================
local function getChar()
	local c = player.Character; if not c then return nil,nil,nil end
	return c, c:FindFirstChild("Humanoid"), c:FindFirstChild("HumanoidRootPart")
end

-- อ่าน pollen และ capacity จาก CoreStats โดยตรง
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
	local best,bestD = nil, math.huge
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
	p.Material=Enum.Material.Neon; p.Color=Color3.fromRGB(100,255,150)
	p.Size=Vector3.new(math.abs(S.Corner1.X-S.Corner2.X),20,math.abs(S.Corner1.Z-S.Corner2.Z))
	p.Position=Vector3.new(c.X,c.Y+10,c.Z); p.Parent=workspace; S.FieldPart=p
end

local function spawnNodePart(pos,n)
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
-- MAKE HONEY — VIM กด E (confirmed working)
--==================================================
local function pressE()
	pcall(function()
		VIM:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
		task.wait(0.1)
		VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
	end)
end

--==================================================
-- MAKE HONEY LOOP
--
-- วิธีทำงาน:
-- 1. รอจนกว่าจะอยู่ที่รัง + มี pollen
-- 2. กด E → subscribe onChange ของ Pollen value
-- 3. ทุกครั้งที่ pollen ลด = ผึ้งทำ honey รอบนึงสำเร็จ
-- 4. รอ pollen หยุดลด 2 วิ → กด E ใหม่ทันที (ไม่รอ timer ตายตัว)
-- 5. ถ้า pollen = 0 → หยุด
--==================================================
task.spawn(function()
	while true do
		task.wait(0.2)

		local _,_,root = getChar(); if not root then continue end
		local pollen,cap = getPollen()
		local hive = S.Nodes[1]
		local nearHive = hive and (root.Position-hive).Magnitude < 8

		local active = nearHive and pollen > 0 and (
			(S.Converting and S.NodeIdx == 1) or CFG.AutoHoney
		)
		if not active then continue end

		-- ── เริ่ม make honey session ──
		print("🍯 เริ่ม Make Honey | pollen="..pollen.."/"..cap)

		-- subscribe pollen onChange
		local stats = player:FindFirstChild("CoreStats")
		local pollenVal = stats and stats:FindFirstChild("Pollen")
		if not pollenVal then
			-- fallback ถ้าไม่เจอ stats
			pressE(); task.wait(10); continue
		end

		-- กด E ครั้งแรก
		pressE()

		-- ติดตาม pollen แบบ event-driven
		-- lastChangeTime = เวลาล่าสุดที่ pollen ลด
		-- ถ้าไม่ลดนาน 2 วิ = ผึ้งว่างแล้ว → กด E ใหม่
		local lastChangeTime = tick()
		local lastPollen = pollenVal.Value
		local session = true

		local conn = pollenVal.Changed:Connect(function(newVal)
			if newVal < lastPollen then
				-- pollen ลด = ผึ้งทำ honey สำเร็จ
				lastChangeTime = tick()
				lastPollen = newVal
				pollenLbl.Text = string.format("🌼 Pollen: %d/%d", newVal, cap)
			elseif newVal <= 0 then
				session = false  -- pollen หมด หยุด
			end
			lastPollen = newVal
		end)

		-- loop รอดู pollen และกด E ใหม่เมื่อผึ้งว่าง
		while session do
			task.wait(0.2)

			local p = pollenVal.Value
			if p <= 0 then
				print("⏹ pollen=0 หยุด Make Honey")
				session = false
				break
			end

			-- เช็คว่ายังอยู่ที่รังอยู่ไหม
			local _,_,r2 = getChar()
			local h2 = S.Nodes[1]
			if not r2 or not h2 or (r2.Position-h2).Magnitude >= 8 then
				print("⏹ ออกจากรัง หยุด Make Honey")
				session = false
				break
			end

			-- ถ้าไม่มี AutoHoney และออก Convert Mode แล้วก็หยุด
			if not CFG.AutoHoney and not (S.Converting and S.NodeIdx==1) then
				session = false
				break
			end

			-- pollen ไม่ลดนาน 2 วิ = ผึ้งทำเสร็จรอบนั้นแล้ว → กด E ใหม่ทันที
			if tick() - lastChangeTime >= 2 then
				lastChangeTime = tick()  -- reset เพื่อป้องกันกดซ้ำถี่
				print("🍯 ผึ้งว่าง กด E ใหม่ | pollen="..p)
				pressE()
			end
		end

		conn:Disconnect()  -- ยกเลิก listener เสมอ
	end
end)

--==================================================
-- BUTTON LOGIC
--==================================================
speedBox.FocusLost:Connect(function()
	local v=tonumber(speedBox.Text); if v then CFG.Speed=v else speedBox.Text=tostring(CFG.Speed) end
end)
jumpBox.FocusLost:Connect(function()
	local v=tonumber(jumpBox.Text); if v then CFG.Jump=v else jumpBox.Text=tostring(CFG.Jump) end
end)

btnAutoClick.MouseButton1Click:Connect(function()
	CFG.AutoClick = not CFG.AutoClick
	toggle(btnAutoClick,CFG.AutoClick,
		Color3.fromRGB(40,160,60),Color3.fromRGB(160,40,40),
		"Auto Click : ON","Auto Click : OFF")
end)

btnHoney.MouseButton1Click:Connect(function()
	CFG.AutoHoney = not CFG.AutoHoney
	toggle(btnHoney,CFG.AutoHoney,
		Color3.fromRGB(200,140,0),Color3.fromRGB(160,40,40),
		"Auto Make Honey : ON","Auto Make Honey : OFF")
end)

local function setCorner1()
	local _,_,root=getChar(); if not root then return end
	S.Corner1=root.Position; print("📍 Corner1: "..tostring(S.Corner1))
end
local function setCorner2()
	local _,_,root=getChar(); if not root then return end
	S.Corner2=root.Position; drawField(); print("📍 Corner2: "..tostring(S.Corner2))
end

btnCorner1.MouseButton1Click:Connect(setCorner1)
btnCorner2.MouseButton1Click:Connect(setCorner2)
btnClearFld.MouseButton1Click:Connect(function()
	S.Corner1=nil; S.Corner2=nil
	if S.FieldPart then S.FieldPart:Destroy(); S.FieldPart=nil end
	print("🗑 Field cleared")
end)

local function addNode()
	local _,_,root=getChar(); if not root then return end
	table.insert(S.Nodes,root.Position)
	spawnNodePart(root.Position,#S.Nodes)
	print("📌 Node "..#S.Nodes..": "..tostring(root.Position))
end

local function clearNodes()
	S.Nodes={}; S.NodeIdx=1; S.Converting=false; S.ConvertDone=false
	clearNodeParts(); print("🗑 Nodes cleared")
end

btnAddNode.MouseButton1Click:Connect(addNode)
btnClearNode.MouseButton1Click:Connect(clearNodes)

btnPath.MouseButton1Click:Connect(function()
	CFG.PathActive = not CFG.PathActive
	S.NodeIdx=1; S.Converting=false; S.ConvertDone=false
	toggle(btnPath,CFG.PathActive,
		Color3.fromRGB(40,160,60),Color3.fromRGB(70,70,180),
		"Path : ON","Path : OFF")
	print("Path: "..(CFG.PathActive and "ON" or "OFF"))
end)

UserInputService.InputBegan:Connect(function(i,gp)
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
-- WATCHDOG — ตรวจจับ stuck ทุก 8 วิ
--==================================================
task.spawn(function()
	while true do
		task.wait(8)
		local _,hum,root=getChar()
		if not root or not hum or hum.Health<=0 then continue end

		local pos = root.Position
		if S.LastPos and (pos-S.LastPos).Magnitude < 2 then
			-- stuck — สุ่ม target ใหม่
			S.StuckTick += 1
			watchdogLbl.Text = "⚠ Stuck x"..S.StuckTick.." — Fixing..."
			watchdogLbl.BackgroundColor3 = Color3.fromRGB(160,60,0)
			print("⚠ STUCK! reset target")

			if not S.Converting then
				S.RandomTarget = randomInField(pos.Y)
				S.RandomTick = 0
			end

			task.wait(2)
			watchdogLbl.Text = "🛡 Watchdog: ON"
			watchdogLbl.BackgroundColor3 = Color3.fromRGB(30,60,30)
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
		local _,hum,_=getChar(); if not hum then continue end
		if hum.Health <= 0 then
			print("💀 ตาย — รอ respawn...")
			modeLbl.Text="💀 Dead — Waiting respawn"
			modeLbl.BackgroundColor3=Color3.fromRGB(100,20,20)
			task.wait(6)
			S.Converting=false; S.ConvertDone=false
			S.NodeIdx=1; S.RandomTarget=nil; S.RandomTick=0
			S.LastPos=nil; S.ConvertStart=nil
			print("✅ Respawn recovery done")
			modeLbl.Text="Mode: Collecting"
			modeLbl.BackgroundColor3=Color3.fromRGB(40,100,50)
		end
	end
end)

--==================================================
-- CONVERT SAFETY RESET (ค้างนาน 3 นาที → force reset)
--==================================================
task.spawn(function()
	while true do
		task.wait(5)
		if S.Converting then
			S.ConvertStart = S.ConvertStart or tick()
			if tick()-S.ConvertStart > 180 then
				print("⚠ Convert ค้าง 3 นาที → force reset")
				S.Converting=false; S.ConvertDone=false
				S.NodeIdx=1; S.ConvertStart=nil
				modeLbl.Text="Mode: Collecting (force reset)"
				modeLbl.BackgroundColor3=Color3.fromRGB(40,100,50)
			end
		else
			S.ConvertStart=nil
		end
	end
end)

--==================================================
-- MAIN HEARTBEAT LOOP
--==================================================
RunService.Heartbeat:Connect(function()
	local _,hum,root=getChar()
	if not hum or not root or hum.Health<=0 then return end

	hum.WalkSpeed = CFG.Speed
	hum.JumpPower  = CFG.Jump

	local pollen,cap = getPollen()

	-- อัพเดต pollen label
	pollenLbl.Text = string.format("🌼 Pollen: %d/%d", pollen, cap)

	S.PollTick += 1
	if S.PollTick >= 20 then
		S.PollTick = 0

		-- pollen เต็ม → เข้า Convert Mode
		if CFG.PathActive and #S.Nodes>=2
			and pollen>=cap and cap>0
			and not S.Converting and not S.ConvertDone then
			S.Converting=true; S.ConvertDone=true
			S.NodeIdx=#S.Nodes
			S.ConvertStart=tick()
			print("🔄 Pollen FULL → Converting")
			modeLbl.BackgroundColor3=Color3.fromRGB(180,70,30)
			modeLbl.Text="⚠ Converting..."
		end

		-- pollen=0 → ออก Convert Mode
		if S.Converting and pollen<=0 then
			S.Converting=false; S.ConvertDone=false
			S.NodeIdx=1; S.ConvertStart=nil
			print("✅ Convert done! เดินไปแปลง")
			modeLbl.BackgroundColor3=Color3.fromRGB(40,100,50)
			modeLbl.Text="Mode: Collecting"
		end
	end

	-- PATH SYSTEM
	if CFG.PathActive and #S.Nodes>=2 then

		-- Convert: เดิน node สุดท้าย → 1
		if S.Converting then
			local target=S.Nodes[S.NodeIdx]
			if target then
				hum:MoveTo(target)
				statusLbl.Text=string.format("🔄 [%d/%d] Pollen: %d/%d",S.NodeIdx,#S.Nodes,pollen,cap)
				if (root.Position-target).Magnitude<4 and S.NodeIdx>1 then
					S.NodeIdx-=1
				end
			end
			return
		end

		-- Collect: อยู่ในแปลง → เก็บ token / random walk
		if insideField(root.Position) then
			local token=nearestToken(root)
			if token then
				hum:MoveTo(token.Position)
				statusLbl.Text="📦 Token | "..pollen.."/"..cap
				modeLbl.Text="Field: Token"; modeLbl.BackgroundColor3=Color3.fromRGB(40,120,40)
				return
			end
			S.RandomTick+=1
			if S.RandomTick>40 then
				S.RandomTarget=randomInField(root.Position.Y); S.RandomTick=0
			end
			if S.RandomTarget then
				hum:MoveTo(S.RandomTarget)
				statusLbl.Text="🚶 Random | "..pollen.."/"..cap
				modeLbl.Text="Field: Walk"; modeLbl.BackgroundColor3=Color3.fromRGB(40,80,160)
			end
			return
		end

		-- เดิน node 1→สุดท้าย ผ่านทุก node ตามลำดับ
		while S.NodeIdx < #S.Nodes do
			if (root.Position-S.Nodes[S.NodeIdx]).Magnitude < 4 then
				S.NodeIdx+=1
			else break end
		end
		local target=S.Nodes[S.NodeIdx]
		if target then
			hum:MoveTo(target)
			statusLbl.Text=string.format("📍 [%d/%d] Pollen: %d/%d",S.NodeIdx,#S.Nodes,pollen,cap)
			modeLbl.Text="Path: To Field"; modeLbl.BackgroundColor3=Color3.fromRGB(40,100,50)
			if (root.Position-target).Magnitude<4 and S.NodeIdx<#S.Nodes then
				S.NodeIdx+=1
			end
		end

	elseif S.Corner1 and S.Corner2 then
		if insideField(root.Position) then
			local token=nearestToken(root)
			if token then
				hum:MoveTo(token.Position)
				statusLbl.Text="📦 Field | "..pollen.."/"..cap
				modeLbl.Text="Field: Token"; modeLbl.BackgroundColor3=Color3.fromRGB(40,100,40)
				return
			end
			S.RandomTick+=1
			if S.RandomTick>40 then
				S.RandomTarget=randomInField(root.Position.Y); S.RandomTick=0
			end
			if S.RandomTarget then
				hum:MoveTo(S.RandomTarget)
				statusLbl.Text="🚶 Random | "..pollen.."/"..cap
				modeLbl.Text="Field: Random"
			end
			return
		end
		statusLbl.Text="⏸ Outside Field"; modeLbl.Text="Idle"
		modeLbl.BackgroundColor3=Color3.fromRGB(40,40,40)
	else
		statusLbl.Text="⏸ Set Field/Path to start"; modeLbl.Text="Idle"
		modeLbl.BackgroundColor3=Color3.fromRGB(40,40,40)
	end
end)

print("✅ AutoFarm v4 loaded — Event-driven Make Honey, Watchdog ON")
