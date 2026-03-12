--==================================================
-- BSS AUTO FARM v5 — ABYSS THEME
-- Script Hub Style | Neon Blue | Dark Abyss
--==================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local VIM              = game:GetService("VirtualInputManager")
local TweenService     = game:GetService("TweenService")
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
-- ABYSS COLOR PALETTE
--==================================================
local C = {
	-- Background layers
	bg         = Color3.fromRGB(6,  8,  14),   -- deepest void
	bg2        = Color3.fromRGB(10, 13, 22),   -- panel bg
	bg3        = Color3.fromRGB(14, 18, 30),   -- card bg
	surface    = Color3.fromRGB(18, 24, 40),   -- element bg

	-- Neon blue spectrum
	neon       = Color3.fromRGB(0,  180, 255), -- primary neon
	neonDim    = Color3.fromRGB(0,  120, 200), -- dim neon
	neonGlow   = Color3.fromRGB(40, 200, 255), -- bright glow
	neonLine   = Color3.fromRGB(0,  160, 230), -- border color

	-- Accent colors
	accent     = Color3.fromRGB(0,  200, 255),
	accentGreen= Color3.fromRGB(0,  230, 140),
	accentOrange=Color3.fromRGB(255,160,  40),
	accentRed  = Color3.fromRGB(255, 70,  70),
	accentPurple=Color3.fromRGB(140, 80, 255),

	-- Tab colors
	tabActive  = Color3.fromRGB(0,  160, 220),
	tabInactive= Color3.fromRGB(14, 18, 30),

	-- Text
	textPrimary= Color3.new(1, 1, 1),
	textSub    = Color3.fromRGB(140, 180, 220),
	textMuted  = Color3.fromRGB(70,  100, 140),
	textNeon   = Color3.fromRGB(0,   210, 255),

	-- Buttons
	btnDefault = Color3.fromRGB(16, 22, 38),
	btnOn      = Color3.fromRGB(0,  120, 180),
	btnHover   = Color3.fromRGB(20, 30, 55),
}

--==================================================
-- UTILITY
--==================================================
local function applyNeonStroke(inst, thickness, color)
	local s = Instance.new("UIStroke", inst)
	s.Thickness = thickness or 1
	s.Color = color or C.neonLine
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return s
end

local function makeCorner(inst, radius)
	Instance.new("UICorner", inst).CornerRadius = UDim.new(0, radius or 6)
end

local function makePadding(inst, all, lr, tb)
	local p = Instance.new("UIPadding", inst)
	if all then
		p.PaddingLeft=UDim.new(0,all); p.PaddingRight=UDim.new(0,all)
		p.PaddingTop=UDim.new(0,all);  p.PaddingBottom=UDim.new(0,all)
	else
		p.PaddingLeft=UDim.new(0,lr or 0);  p.PaddingRight=UDim.new(0,lr or 0)
		p.PaddingTop=UDim.new(0,tb or 0);   p.PaddingBottom=UDim.new(0,tb or 0)
	end
	return p
end

local function makeTween(obj, props, dur, style, dir)
	local ti = TweenInfo.new(dur or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
	return TweenService:Create(obj, ti, props)
end

--==================================================
-- GUI ROOT
--==================================================
local gui = Instance.new("ScreenGui")
gui.Name = "AutoFarmGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player.PlayerGui

-- Main window
local win = Instance.new("Frame", gui)
win.Name = "Window"
win.Size = UDim2.new(0, 300, 0, 420)
win.Position = UDim2.new(0, 20, 0, 60)
win.BackgroundColor3 = C.bg
win.BorderSizePixel = 0
makeCorner(win, 10)
applyNeonStroke(win, 1.5, C.neonLine)

-- Scanline texture overlay (visual depth)
local scanOverlay = Instance.new("Frame", win)
scanOverlay.Size = UDim2.new(1,0,1,0)
scanOverlay.BackgroundTransparency = 1
scanOverlay.ZIndex = 10

-- Corner glow decorations
local function mkCornerGlow(parent, pos)
	local g = Instance.new("Frame", parent)
	g.Size = UDim2.new(0, 60, 0, 60)
	g.Position = pos
	g.BackgroundTransparency = 1
	g.ZIndex = 2
	local img = Instance.new("ImageLabel", g)
	img.Size = UDim2.new(1,0,1,0)
	img.BackgroundTransparency = 1
	img.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
	img.ImageColor3 = C.neon
	img.ImageTransparency = 0.85
	return g
end

--==================================================
-- TITLE BAR
--==================================================
local titleBar = Instance.new("Frame", win)
titleBar.Size = UDim2.new(1, 0, 0, 44)
titleBar.Position = UDim2.new(0, 0, 0, 0)
titleBar.BackgroundColor3 = C.bg2
titleBar.BorderSizePixel = 0
makeCorner(titleBar, 10)

-- Bottom mask to square off bottom of titlebar
local titleMask = Instance.new("Frame", titleBar)
titleMask.Size = UDim2.new(1,0,0,10)
titleMask.Position = UDim2.new(0,0,1,-10)
titleMask.BackgroundColor3 = C.bg2
titleMask.BorderSizePixel = 0

-- Neon accent line under title
local titleLine = Instance.new("Frame", titleBar)
titleLine.Size = UDim2.new(1, 0, 0, 1)
titleLine.Position = UDim2.new(0, 0, 1, -1)
titleLine.BackgroundColor3 = C.neon
titleLine.BorderSizePixel = 0

-- Glowing dot indicator
local statusDot = Instance.new("Frame", titleBar)
statusDot.Size = UDim2.new(0, 8, 0, 8)
statusDot.Position = UDim2.new(0, 12, 0.5, -4)
statusDot.BackgroundColor3 = C.accentGreen
statusDot.BorderSizePixel = 0
makeCorner(statusDot, 4)
applyNeonStroke(statusDot, 1, C.accentGreen)

-- Title text
local titleTxt = Instance.new("TextLabel", titleBar)
titleTxt.Size = UDim2.new(1, -80, 1, 0)
titleTxt.Position = UDim2.new(0, 28, 0, 0)
titleTxt.BackgroundTransparency = 1
titleTxt.Text = "BSS  AUTO FARM"
titleTxt.TextColor3 = C.textNeon
titleTxt.TextSize = 13
titleTxt.TextXAlignment = Enum.TextXAlignment.Left
titleTxt.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

local versionTxt = Instance.new("TextLabel", titleBar)
versionTxt.Size = UDim2.new(0, 60, 1, 0)
versionTxt.Position = UDim2.new(1, -68, 0, 0)
versionTxt.BackgroundTransparency = 1
versionTxt.Text = "v5  ◈"
versionTxt.TextColor3 = C.textMuted
versionTxt.TextSize = 10
versionTxt.TextXAlignment = Enum.TextXAlignment.Right
versionTxt.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

-- Drag
do
	local drag, ds, sp = false, nil, nil
	titleBar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			drag=true; ds=i.Position; sp=win.Position
		end
	end)
	titleBar.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then drag=false end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
			local d = i.Position-ds
			win.Position = UDim2.new(sp.X.Scale, sp.X.Offset+d.X, sp.Y.Scale, sp.Y.Offset+d.Y)
		end
	end)
end

--==================================================
-- STATUS BAR (below title)
--==================================================
local statusBar = Instance.new("Frame", win)
statusBar.Size = UDim2.new(1, -16, 0, 28)
statusBar.Position = UDim2.new(0, 8, 0, 50)
statusBar.BackgroundColor3 = C.bg3
statusBar.BorderSizePixel = 0
makeCorner(statusBar, 5)
applyNeonStroke(statusBar, 1, Color3.fromRGB(20, 40, 70))

local statusList = Instance.new("UIListLayout", statusBar)
statusList.FillDirection = Enum.FillDirection.Horizontal
statusList.VerticalAlignment = Enum.VerticalAlignment.Center
statusList.Padding = UDim.new(0, 0)
makePadding(statusBar, nil, 8, 0)

local statusLbl = Instance.new("TextLabel", statusBar)
statusLbl.Size = UDim2.new(0.5, 0, 1, 0)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "◉  Ready"
statusLbl.TextColor3 = C.accentGreen
statusLbl.TextSize = 10
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

local pollenLbl = Instance.new("TextLabel", statusBar)
pollenLbl.Size = UDim2.new(0.5, 0, 1, 0)
pollenLbl.BackgroundTransparency = 1
pollenLbl.Text = "🌼  --/--"
pollenLbl.TextColor3 = C.textSub
pollenLbl.TextSize = 10
pollenLbl.TextXAlignment = Enum.TextXAlignment.Right
pollenLbl.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")

local modeLbl = Instance.new("TextLabel", win)
modeLbl.Size = UDim2.new(1, -16, 0, 18)
modeLbl.Position = UDim2.new(0, 8, 0, 82)
modeLbl.BackgroundTransparency = 1
modeLbl.Text = "Mode: Idle"
modeLbl.TextColor3 = C.textMuted
modeLbl.TextSize = 9
modeLbl.TextXAlignment = Enum.TextXAlignment.Left
modeLbl.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")

--==================================================
-- TAB BAR
--==================================================
local TAB_NAMES = {"MAIN", "FIELD", "PATH", "BOOST"}
local TAB_ICONS = {"⚙", "🌿", "📍", "⚡"}
local activeTab = 1
local tabButtons = {}
local tabPages   = {}

local tabBar = Instance.new("Frame", win)
tabBar.Size = UDim2.new(1, -16, 0, 30)
tabBar.Position = UDim2.new(0, 8, 0, 103)
tabBar.BackgroundColor3 = C.bg3
tabBar.BorderSizePixel = 0
makeCorner(tabBar, 6)
applyNeonStroke(tabBar, 1, Color3.fromRGB(15,25,50))

local tabLayout = Instance.new("UIListLayout", tabBar)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Padding = UDim.new(0, 2)
makePadding(tabBar, nil, 2, 2)

-- Content area
local contentArea = Instance.new("Frame", win)
contentArea.Size = UDim2.new(1, -16, 0, 264)
contentArea.Position = UDim2.new(0, 8, 0, 138)
contentArea.BackgroundTransparency = 1
contentArea.BorderSizePixel = 0
contentArea.ClipsDescendants = true

local function createTabPage()
	local page = Instance.new("ScrollingFrame", contentArea)
	page.Size = UDim2.new(1, 0, 1, 0)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 2
	page.ScrollBarImageColor3 = C.neonDim
	page.CanvasSize = UDim2.new(0, 0, 0, 0)
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.Visible = false
	local layout = Instance.new("UIListLayout", page)
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	return page, layout
end

for i, name in ipairs(TAB_NAMES) do
	local btn = Instance.new("TextButton", tabBar)
	btn.Size = UDim2.new(0.25, -2, 1, 0)
	btn.BackgroundColor3 = i==1 and C.tabActive or C.tabInactive
	btn.TextColor3 = i==1 and C.textPrimary or C.textMuted
	btn.BorderSizePixel = 0
	btn.Text = TAB_ICONS[i].." "..name
	btn.TextSize = 9
	btn.LayoutOrder = i
	btn.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	makeCorner(btn, 4)
	if i==1 then applyNeonStroke(btn, 1, C.neon) end
	tabButtons[i] = btn

	local page, _ = createTabPage()
	tabPages[i] = page

	btn.MouseButton1Click:Connect(function()
		for j, tb in ipairs(tabButtons) do
			local isActive = (j==i)
			makeTween(tb, {BackgroundColor3 = isActive and C.tabActive or C.tabInactive}, 0.15):Play()
			tb.TextColor3 = isActive and C.textPrimary or C.textMuted
			local stroke = tb:FindFirstChildOfClass("UIStroke")
			if stroke then stroke:Destroy() end
			if isActive then applyNeonStroke(tb, 1, C.neon) end
			tabPages[j].Visible = isActive
		end
		activeTab = i
	end)
end
tabPages[1].Visible = true

--==================================================
-- ELEMENT BUILDERS
--==================================================
local function sectionHeader(parent, text, icon, layoutOrder)
	local f = Instance.new("Frame", parent)
	f.Size = UDim2.new(1, 0, 0, 22)
	f.BackgroundColor3 = Color3.fromRGB(8, 14, 28)
	f.BorderSizePixel = 0
	f.LayoutOrder = layoutOrder or 0
	makeCorner(f, 4)
	applyNeonStroke(f, 1, Color3.fromRGB(0, 80, 130))

	local line = Instance.new("Frame", f)
	line.Size = UDim2.new(0, 2, 0.7, 0)
	line.Position = UDim2.new(0, 6, 0.15, 0)
	line.BackgroundColor3 = C.neon
	line.BorderSizePixel = 0
	makeCorner(line, 1)

	local lbl = Instance.new("TextLabel", f)
	lbl.Size = UDim2.new(1, -20, 1, 0)
	lbl.Position = UDim2.new(0, 14, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = (icon and icon.." " or "") .. string.upper(text)
	lbl.TextColor3 = C.textNeon
	lbl.TextSize = 9
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	return f
end

local btnOrder = 0
local function nBtn() btnOrder+=1; return btnOrder end

local function mkToggleBtn(parent, text, onText, offText, lo)
	local isOn = false
	local b = Instance.new("TextButton", parent)
	b.Size = UDim2.new(1, 0, 0, 30)
	b.BackgroundColor3 = C.btnDefault
	b.TextColor3 = C.textSub
	b.BorderSizePixel = 0
	b.Text = "  ○  " .. text .. "  :  OFF"
	b.TextSize = 11
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.LayoutOrder = lo or nBtn()
	b.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	makeCorner(b, 5)
	applyNeonStroke(b, 1, Color3.fromRGB(20, 35, 60))
	makePadding(b, nil, 8, 0)

	-- Status indicator pill on right
	local pill = Instance.new("Frame", b)
	pill.Size = UDim2.new(0, 36, 0, 16)
	pill.Position = UDim2.new(1, -44, 0.5, -8)
	pill.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
	pill.BorderSizePixel = 0
	makeCorner(pill, 8)
	local pillTxt = Instance.new("TextLabel", pill)
	pillTxt.Size = UDim2.new(1, 0, 1, 0)
	pillTxt.BackgroundTransparency = 1
	pillTxt.Text = "OFF"
	pillTxt.TextColor3 = C.textMuted
	pillTxt.TextSize = 8
	pillTxt.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

	local function refresh()
		if isOn then
			makeTween(b, {BackgroundColor3 = Color3.fromRGB(0, 30, 55)}, 0.15):Play()
			local stroke = b:FindFirstChildOfClass("UIStroke")
			if stroke then makeTween(stroke, {Color = C.neon}, 0.15):Play() end
			b.TextColor3 = C.textNeon
			b.Text = "  ●  " .. (onText or text) .. "  :  ON"
			makeTween(pill, {BackgroundColor3 = C.neon}, 0.15):Play()
			pillTxt.TextColor3 = C.bg
			pillTxt.Text = "ON"
		else
			makeTween(b, {BackgroundColor3 = C.btnDefault}, 0.15):Play()
			local stroke = b:FindFirstChildOfClass("UIStroke")
			if stroke then makeTween(stroke, {Color = Color3.fromRGB(20,35,60)}, 0.15):Play() end
			b.TextColor3 = C.textSub
			b.Text = "  ○  " .. (offText or text) .. "  :  OFF"
			makeTween(pill, {BackgroundColor3 = Color3.fromRGB(30,40,60)}, 0.15):Play()
			pillTxt.TextColor3 = C.textMuted
			pillTxt.Text = "OFF"
		end
	end

	return b, pill, function() isOn = not isOn; refresh(); return isOn end, function() return isOn end, function(v) isOn=v; refresh() end
end

local function mkActionBtn(parent, text, color, lo)
	local b = Instance.new("TextButton", parent)
	b.Size = UDim2.new(1, 0, 0, 30)
	b.BackgroundColor3 = color or C.btnDefault
	b.TextColor3 = C.textPrimary
	b.BorderSizePixel = 0
	b.Text = text
	b.TextSize = 11
	b.LayoutOrder = lo or nBtn()
	b.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	makeCorner(b, 5)
	applyNeonStroke(b, 1, color and color or Color3.fromRGB(20,35,60))
	b.MouseEnter:Connect(function()
		makeTween(b, {BackgroundColor3 = Color3.fromRGB(
			math.min(b.BackgroundColor3.R*255+15,255)/255,
			math.min(b.BackgroundColor3.G*255+15,255)/255,
			math.min(b.BackgroundColor3.B*255+15,255)/255
		)}, 0.1):Play()
	end)
	b.MouseLeave:Connect(function()
		makeTween(b, {BackgroundColor3 = color or C.btnDefault}, 0.1):Play()
	end)
	return b
end

local function mkHalfRow(parent, textA, colorA, textB, colorB, lo)
	local row = Instance.new("Frame", parent)
	row.Size = UDim2.new(1, 0, 0, 30)
	row.BackgroundTransparency = 1
	row.LayoutOrder = lo or nBtn()

	local rl = Instance.new("UIListLayout", row)
	rl.FillDirection = Enum.FillDirection.Horizontal
	rl.Padding = UDim.new(0, 5)

	local function mkHalf(text, color, lo2)
		local b = Instance.new("TextButton", row)
		b.Size = UDim2.new(0.5, -3, 1, 0)
		b.BackgroundColor3 = color or C.btnDefault
		b.TextColor3 = C.textPrimary
		b.BorderSizePixel = 0
		b.Text = text
		b.TextSize = 10
		b.LayoutOrder = lo2
		b.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
		makeCorner(b, 5)
		applyNeonStroke(b, 1, color or Color3.fromRGB(20,35,60))
		return b
	end
	return row, mkHalf(textA, colorA, 1), mkHalf(textB, colorB, 2)
end

local function mkInputCard(parent, label, default, lo)
	local card = Instance.new("Frame", parent)
	card.Size = UDim2.new(1, 0, 0, 46)
	card.BackgroundColor3 = C.bg3
	card.BorderSizePixel = 0
	card.LayoutOrder = lo or nBtn()
	makeCorner(card, 5)
	applyNeonStroke(card, 1, Color3.fromRGB(15,25,50))

	local lbl = Instance.new("TextLabel", card)
	lbl.Size = UDim2.new(1, -8, 0, 18)
	lbl.Position = UDim2.new(0, 8, 0, 3)
	lbl.BackgroundTransparency = 1
	lbl.Text = label
	lbl.TextColor3 = C.textMuted
	lbl.TextSize = 9
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")

	local box = Instance.new("TextBox", card)
	box.Size = UDim2.new(1, -12, 0, 20)
	box.Position = UDim2.new(0, 6, 0, 22)
	box.BackgroundColor3 = C.surface
	box.TextColor3 = C.textNeon
	box.BorderSizePixel = 0
	box.Text = tostring(default)
	box.TextSize = 11
	box.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	makeCorner(box, 4)
	applyNeonStroke(box, 1, C.neonDim)
	return box
end

--==================================================
-- PAGE 1: MAIN (Settings + Automation)
--==================================================
local p1 = tabPages[1]

sectionHeader(p1, "Settings", "⚙", 1)

local speedBox = mkInputCard(p1, "WALK SPEED", CFG.Speed, 2)
local jumpBox  = mkInputCard(p1, "JUMP POWER",  CFG.Jump,  3)

sectionHeader(p1, "Automation", "🤖", 4)

local btnAutoClick, _, toggleAutoClick = mkToggleBtn(p1, "Auto Click", nil, nil, 5)
local btnHoney,     _, toggleHoney     = mkToggleBtn(p1, "Auto Make Honey", nil, nil, 6)
local btnAntiAFK,   _, toggleAntiAFK   = mkToggleBtn(p1, "Anti-AFK", nil, nil, 7)

--==================================================
-- PAGE 2: FIELD
--==================================================
local p2 = tabPages[2]

sectionHeader(p2, "Field Corners", "📐", 1)

local _, btnC1, btnC2 = mkHalfRow(p2,
	"[Z] Corner 1", Color3.fromRGB(0,40,90),
	"[X] Corner 2", Color3.fromRGB(0,40,90), 2)
applyNeonStroke(btnC1, 1, C.neonDim)
applyNeonStroke(btnC2, 1, C.neonDim)

local btnClearFld = mkActionBtn(p2, "✕  Clear Field", Color3.fromRGB(40,10,10), 3)
applyNeonStroke(btnClearFld, 1, C.accentRed)

-- Field status info box
local fieldInfo = Instance.new("Frame", p2)
fieldInfo.Size = UDim2.new(1, 0, 0, 38)
fieldInfo.BackgroundColor3 = C.bg3
fieldInfo.BorderSizePixel = 0
fieldInfo.LayoutOrder = 4
makeCorner(fieldInfo, 5)
applyNeonStroke(fieldInfo, 1, Color3.fromRGB(15,25,50))
local fiTxt = Instance.new("TextLabel", fieldInfo)
fiTxt.Size = UDim2.new(1, -10, 1, 0)
fiTxt.Position = UDim2.new(0, 8, 0, 0)
fiTxt.BackgroundTransparency = 1
fiTxt.Text = "Corner 1: Not Set\nCorner 2: Not Set"
fiTxt.TextColor3 = C.textMuted
fiTxt.TextSize = 9
fiTxt.TextXAlignment = Enum.TextXAlignment.Left
fiTxt.TextYAlignment = Enum.TextYAlignment.Center
fiTxt.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")

--==================================================
-- PAGE 3: PATH & NODES
--==================================================
local p3 = tabPages[3]

sectionHeader(p3, "Path Control", "🗺", 1)

local btnPath, _, togglePath = mkToggleBtn(p3, "Path Farming", "Path ON", "Path OFF", 2)

sectionHeader(p3, "Nodes  [Q to Add]", "📌", 3)

local _, btnAddNode, btnClearNode = mkHalfRow(p3,
	"[Q]  Add Node", Color3.fromRGB(0,55,25),
	"Clear All",     Color3.fromRGB(50,25,0), 4)
applyNeonStroke(btnAddNode,   1, C.accentGreen)
applyNeonStroke(btnClearNode, 1, C.accentOrange)

local nodeCountLbl = Instance.new("TextLabel", p3)
nodeCountLbl.Size = UDim2.new(1, 0, 0, 24)
nodeCountLbl.BackgroundColor3 = C.bg3
nodeCountLbl.TextColor3 = C.textSub
nodeCountLbl.BorderSizePixel = 0
nodeCountLbl.Text = "Nodes: 0  |  Current: 0"
nodeCountLbl.TextSize = 10
nodeCountLbl.LayoutOrder = 5
nodeCountLbl.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")
makeCorner(nodeCountLbl, 4)
applyNeonStroke(nodeCountLbl, 1, Color3.fromRGB(15,25,50))

--==================================================
-- PAGE 4: BOOSTER
--==================================================
local p4 = tabPages[4]

sectionHeader(p4, "Auto Field Booster", "⚡", 1)

local btnBooster, _, toggleBooster = mkToggleBtn(p4, "Auto Booster", nil, nil, 2)

sectionHeader(p4, "Booster Status", "🔋", 3)

local BOOSTERS = {
	{name="Blue Field Booster",  pos=Vector3.new(271,65,82),    label="BLUE",  color=Color3.fromRGB(0,50,140)},
	{name="Red Field Booster",   pos=Vector3.new(-316,28,243),  label="RED",   color=Color3.fromRGB(100,15,15)},
	{name="Field Booster",       pos=Vector3.new(-40,184,-190), label="MOUNT", color=Color3.fromRGB(20,70,20)},
}
local BOOSTER_CD = 45*60
local lastUsed   = {}
local bCards     = {}

for i, b in ipairs(BOOSTERS) do
	local card = Instance.new("Frame", p4)
	card.Size = UDim2.new(1, 0, 0, 44)
	card.BackgroundColor3 = C.bg3
	card.BorderSizePixel = 0
	card.LayoutOrder = 3+i
	makeCorner(card, 5)
	applyNeonStroke(card, 1, b.color)

	local accent = Instance.new("Frame", card)
	accent.Size = UDim2.new(0, 3, 1, -8)
	accent.Position = UDim2.new(0, 0, 0, 4)
	accent.BackgroundColor3 = b.color
	accent.BorderSizePixel = 0
	makeCorner(accent, 2)

	local nameLbl = Instance.new("TextLabel", card)
	nameLbl.Size = UDim2.new(0.6, 0, 0, 22)
	nameLbl.Position = UDim2.new(0, 10, 0, 2)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = b.label .. " BOOSTER"
	nameLbl.TextColor3 = C.textPrimary
	nameLbl.TextSize = 10
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

	local timeLbl = Instance.new("TextLabel", card)
	timeLbl.Size = UDim2.new(1, -12, 0, 18)
	timeLbl.Position = UDim2.new(0, 10, 0, 23)
	timeLbl.BackgroundTransparency = 1
	timeLbl.Text = "✅ READY"
	timeLbl.TextColor3 = C.accentGreen
	timeLbl.TextSize = 9
	timeLbl.TextXAlignment = Enum.TextXAlignment.Left
	timeLbl.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")

	local statPill = Instance.new("Frame", card)
	statPill.Size = UDim2.new(0, 48, 0, 18)
	statPill.Position = UDim2.new(1, -54, 0.5, -9)
	statPill.BackgroundColor3 = C.accentGreen
	statPill.BorderSizePixel = 0
	makeCorner(statPill, 9)
	local statTxt = Instance.new("TextLabel", statPill)
	statTxt.Size = UDim2.new(1,0,1,0)
	statTxt.BackgroundTransparency = 1
	statTxt.Text = "READY"
	statTxt.TextColor3 = C.bg
	statTxt.TextSize = 8
	statTxt.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

	bCards[i] = {timeLbl=timeLbl, statPill=statPill, statTxt=statTxt, defColor=b.color}
end

--==================================================
-- BOTTOM HOTKEY HINT
--==================================================
local hintBar = Instance.new("Frame", win)
hintBar.Size = UDim2.new(1, -16, 0, 18)
hintBar.Position = UDim2.new(0, 8, 1, -24)
hintBar.BackgroundTransparency = 1
hintBar.BorderSizePixel = 0

local hintLine = Instance.new("Frame", hintBar)
hintLine.Size = UDim2.new(1, 0, 0, 1)
hintLine.Position = UDim2.new(0,0,0,0)
hintLine.BackgroundColor3 = Color3.fromRGB(15,25,50)
hintLine.BorderSizePixel = 0

local hintTxt = Instance.new("TextLabel", hintBar)
hintTxt.Size = UDim2.new(1, 0, 1, 0)
hintTxt.Position = UDim2.new(0, 0, 0, 4)
hintTxt.BackgroundTransparency = 1
hintTxt.Text = "Z / X — Corners  |  Q — Add Node"
hintTxt.TextColor3 = C.textMuted
hintTxt.TextSize = 8
hintTxt.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")

--==================================================
-- PULSE ANIMATION ON STATUS DOT
--==================================================
task.spawn(function()
	while true do
		makeTween(statusDot, {BackgroundTransparency=0.3}, 0.8, Enum.EasingStyle.Sine):Play()
		task.wait(0.8)
		makeTween(statusDot, {BackgroundTransparency=0}, 0.8, Enum.EasingStyle.Sine):Play()
		task.wait(0.8)
	end
end)

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
	p.Anchored=true; p.CanCollide=false; p.Transparency=0.85
	p.Material=Enum.Material.Neon; p.Color=C.neon
	p.Size=Vector3.new(math.abs(S.Corner1.X-S.Corner2.X),20,math.abs(S.Corner1.Z-S.Corner2.Z))
	p.Position=Vector3.new(c.X,c.Y+10,c.Z); p.Parent=workspace; S.FieldPart=p
end

local function updateFieldInfo()
	local t1 = S.Corner1 and string.format("(%.0f, %.0f, %.0f)", S.Corner1.X, S.Corner1.Y, S.Corner1.Z) or "Not Set"
	local t2 = S.Corner2 and string.format("(%.0f, %.0f, %.0f)", S.Corner2.X, S.Corner2.Y, S.Corner2.Z) or "Not Set"
	fiTxt.Text = "C1: "..t1.."\nC2: "..t2
end

local function spawnNodePart(pos, n)
	local p = Instance.new("Part")
	p.Name="AutoFarmNode_"..n; p.Size=Vector3.new(1,1,1)
	p.Anchored=true; p.CanCollide=false; p.Material=Enum.Material.Neon
	p.Color = n==1 and Color3.fromRGB(0,180,255) or Color3.fromRGB(0,230,120)
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

local function updateNodeLbl()
	nodeCountLbl.Text = "Nodes: "..#S.Nodes.."  |  Current: "..S.NodeIdx
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
	CFG.AutoClick = toggleAutoClick()
end)

btnHoney.MouseButton1Click:Connect(function()
	CFG.AutoHoney = toggleHoney()
end)

btnAntiAFK.MouseButton1Click:Connect(function()
	CFG.AntiAFK = toggleAntiAFK()
end)

btnBooster.MouseButton1Click:Connect(function()
	CFG.AutoBooster = toggleBooster()
end)

local function setCorner1()
	local _,_,root=getChar(); if not root then return end
	S.Corner1=root.Position
	btnC1.BackgroundColor3 = Color3.fromRGB(0,60,120)
	btnC1.Text = "✓ Corner 1 Set"
	updateFieldInfo()
	print("📍 Corner1")
end
local function setCorner2()
	local _,_,root=getChar(); if not root then return end
	S.Corner2=root.Position; drawField()
	btnC2.BackgroundColor3 = Color3.fromRGB(0,60,120)
	btnC2.Text = "✓ Corner 2 Set"
	updateFieldInfo()
	print("📍 Corner2")
end

btnC1.MouseButton1Click:Connect(setCorner1)
btnC2.MouseButton1Click:Connect(setCorner2)
btnClearFld.MouseButton1Click:Connect(function()
	S.Corner1=nil; S.Corner2=nil
	if S.FieldPart then S.FieldPart:Destroy(); S.FieldPart=nil end
	btnC1.BackgroundColor3 = Color3.fromRGB(0,40,90)
	btnC1.Text = "[Z] Corner 1"
	btnC2.BackgroundColor3 = Color3.fromRGB(0,40,90)
	btnC2.Text = "[X] Corner 2"
	updateFieldInfo()
end)

local function addNode()
	local _,_,root=getChar(); if not root then return end
	table.insert(S.Nodes, root.Position)
	spawnNodePart(root.Position, #S.Nodes)
	updateNodeLbl()
	print("📌 Node "..#S.Nodes)
end
local function clearNodes()
	S.Nodes={}; S.NodeIdx=1; S.Converting=false; S.ConvertDone=false
	clearNodeParts(); updateNodeLbl()
end

btnAddNode.MouseButton1Click:Connect(addNode)
btnClearNode.MouseButton1Click:Connect(clearNodes)

btnPath.MouseButton1Click:Connect(function()
	CFG.PathActive = togglePath()
	S.NodeIdx=1; S.Converting=false; S.ConvertDone=false
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
local READY_CLR = Color3.fromRGB(0,150,60)

local function boosterReady(name)
	local t = lastUsed[name]
	if not t then return true end
	return (tick()-t) >= BOOSTER_CD
end

local function boosterTimeLeft(name)
	local t = lastUsed[name]
	if not t then return 0 end
	return math.max(0, math.floor(BOOSTER_CD-(tick()-t)))
end

task.spawn(function()
	while true do
		task.wait(1)
		if S.IsBoosting then continue end
		for i, b in ipairs(BOOSTERS) do
			local card = bCards[i]
			if boosterReady(b.name) then
				card.timeLbl.Text = "✅ READY"
				card.timeLbl.TextColor3 = C.accentGreen
				card.statPill.BackgroundColor3 = C.accentGreen
				card.statTxt.Text = "READY"
			else
				local left = boosterTimeLeft(b.name)
				local m = math.floor(left/60); local s = left%60
				card.timeLbl.Text = string.format("⏱ %dm %ds", m, s)
				card.timeLbl.TextColor3 = C.textMuted
				card.statPill.BackgroundColor3 = card.defColor
				card.statTxt.Text = string.format("%d:%02d",m,s)
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(2)
		if not CFG.AutoBooster then continue end
		if S.IsBoosting then continue end
		if S.Converting then continue end
		local _,hum,root = getChar()
		if not hum or not root or hum.Health<=0 then continue end
		local pending = {}
		for i,b in ipairs(BOOSTERS) do
			if boosterReady(b.name) then table.insert(pending,{b=b,idx=i}) end
		end
		if #pending==0 then continue end
		S.IsBoosting=true
		local hivePos = S.Nodes[1]
		for _,entry in ipairs(pending) do
			local b=entry.b; local idx=entry.idx
			if not boosterReady(b.name) then continue end
			local _,_,r2=getChar(); if not r2 then break end
			bCards[idx].timeLbl.Text = "⚡ Going..."
			bCards[idx].timeLbl.TextColor3 = C.accentOrange
			bCards[idx].statPill.BackgroundColor3 = C.accentOrange
			bCards[idx].statTxt.Text = "GO"
			r2.CFrame = CFrame.new(b.pos+Vector3.new(0,3,0))
			task.wait(1.5)
			pressE(); task.wait(1)
			lastUsed[b.name]=tick()
			bCards[idx].timeLbl.Text="✔ Done"
		end
		if hivePos then
			local _,_,r3=getChar()
			if r3 then r3.CFrame=CFrame.new(hivePos+Vector3.new(0,3,0)); task.wait(0.5) end
		end
		S.IsBoosting=false
	end
end)

--==================================================
-- WATCHDOG
--==================================================
task.spawn(function()
	while true do
		task.wait(8)
		local _,hum,root=getChar()
		if not root or not hum or hum.Health<=0 then continue end
		local pos=root.Position; local hive=S.Nodes[1]
		local nearHive=hive and (pos-hive).Magnitude<8
		if nearHive and (S.Converting or CFG.AutoHoney) then S.LastPos=pos; continue end
		if S.LastPos and (pos-S.LastPos).Magnitude<2 then
			S.StuckTick+=1
			if not S.Converting then
				S.RandomTarget=randomInField(pos.Y); S.RandomTick=0
			end
		else S.StuckTick=0 end
		S.LastPos=pos
	end
end)

--==================================================
-- RESPAWN RECOVERY
--==================================================
task.spawn(function()
	while true do
		task.wait(1)
		local _,hum,_=getChar(); if not hum then continue end
		if hum.Health<=0 then
			statusLbl.Text="💀 Respawning..."
			statusLbl.TextColor3=C.accentRed
			task.wait(6)
			S.Converting=false; S.ConvertDone=false
			S.NodeIdx=1; S.RandomTarget=nil; S.RandomTick=0
			S.LastPos=nil; S.ConvertStart=nil
			statusLbl.Text="◉  Ready"
			statusLbl.TextColor3=C.accentGreen
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
			S.ConvertStart=S.ConvertStart or tick()
			if tick()-S.ConvertStart>180 then
				S.Converting=false; S.ConvertDone=false
				S.NodeIdx=1; S.ConvertStart=nil
				modeLbl.Text="Mode: Collecting"
				print("⚠ Convert force reset")
			end
		else S.ConvertStart=nil end
	end
end)

--==================================================
-- ANTI-AFK
--==================================================
task.spawn(function()
	while true do
		task.wait(120)
		if not CFG.AntiAFK then continue end
		local _,hum,_=getChar()
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
	local _,hum,root=getChar()
	if not hum or not root or hum.Health<=0 then return end

	hum.WalkSpeed=CFG.Speed
	hum.JumpPower=CFG.Jump

	local pollen,cap=getPollen()
	pollenLbl.Text=string.format("🌼  %d / %d", pollen, cap)

	S.PollTick+=1
	if S.PollTick>=20 then
		S.PollTick=0
		if CFG.PathActive and #S.Nodes>=2 and pollen>=cap and cap>0 and not S.Converting and not S.ConvertDone then
			S.Converting=true; S.ConvertDone=true
			S.NodeIdx=#S.Nodes; S.ConvertStart=tick()
			modeLbl.Text="⚠ Converting..."; modeLbl.TextColor3=C.accentOrange
		end
		if S.Converting and pollen<=0 then
			S.Converting=false; S.ConvertDone=false
			S.NodeIdx=1; S.ConvertStart=nil
			modeLbl.Text="Mode: Collecting"; modeLbl.TextColor3=C.textSub
		end
	end

	if S.IsBoosting then statusLbl.Text="🚀 Boosting..."; statusLbl.TextColor3=C.accentOrange; return end

	if CFG.PathActive and #S.Nodes>=2 then
		if S.Converting then
			local target=S.Nodes[S.NodeIdx]
			if target then
				hum:MoveTo(target)
				statusLbl.Text=string.format("🔄 Node[%d/%d]", S.NodeIdx,#S.Nodes)
				statusLbl.TextColor3=C.accentOrange
				if (root.Position-target).Magnitude<4 and S.NodeIdx>1 then S.NodeIdx-=1 end
			end
			return
		end
		if insideField(root.Position) then
			local token=nearestToken(root)
			if token then
				hum:MoveTo(token.Position)
				statusLbl.Text="📦 Collecting"; statusLbl.TextColor3=C.accentGreen
				modeLbl.Text="Field: Token"; modeLbl.TextColor3=C.accentGreen
				return
			end
			S.RandomTick+=1
			if S.RandomTick>40 then S.RandomTarget=randomInField(root.Position.Y); S.RandomTick=0 end
			if S.RandomTarget then
				hum:MoveTo(S.RandomTarget)
				statusLbl.Text="🚶 Roaming"; statusLbl.TextColor3=C.neon
				modeLbl.Text="Field: Roaming"; modeLbl.TextColor3=C.textSub
			end
			return
		end
		while S.NodeIdx<#S.Nodes do
			if (root.Position-S.Nodes[S.NodeIdx]).Magnitude<4 then S.NodeIdx+=1 else break end
		end
		local target=S.Nodes[S.NodeIdx]
		if target then
			hum:MoveTo(target)
			statusLbl.Text=string.format("📍 Path [%d/%d]", S.NodeIdx,#S.Nodes)
			statusLbl.TextColor3=C.neon
			modeLbl.Text="Path: To Field"; modeLbl.TextColor3=C.textSub
			if (root.Position-target).Magnitude<4 and S.NodeIdx<#S.Nodes then S.NodeIdx+=1 end
		end
	elseif S.Corner1 and S.Corner2 then
		if insideField(root.Position) then
			local token=nearestToken(root)
			if token then
				hum:MoveTo(token.Position)
				statusLbl.Text="📦 Field Token"; statusLbl.TextColor3=C.accentGreen
				return
			end
			S.RandomTick+=1
			if S.RandomTick>40 then S.RandomTarget=randomInField(root.Position.Y); S.RandomTick=0 end
			if S.RandomTarget then
				hum:MoveTo(S.RandomTarget)
				statusLbl.Text="🚶 Roaming"; statusLbl.TextColor3=C.neon
			end
			return
		end
		statusLbl.Text="⏸ Outside Field"; statusLbl.TextColor3=C.textMuted
		modeLbl.Text="Idle"; modeLbl.TextColor3=C.textMuted
	else
		statusLbl.Text="⏸ Setup Required"; statusLbl.TextColor3=C.textMuted
		modeLbl.Text="Set corners or path first"; modeLbl.TextColor3=C.textMuted
	end

	updateNodeLbl()
end)

print("✅ BSS AutoFarm v5 — Abyss Edition loaded")
