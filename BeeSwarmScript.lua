local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- ล้างของเก่า
if player.PlayerGui:FindFirstChild("MyAutoFarmGui") then player.PlayerGui.MyAutoFarmGui:Destroy() end
if workspace:FindFirstChild("TokenAreaVisual") then workspace:FindFirstChild("TokenAreaVisual"):Destroy() end

local Config = { Radius = 30, Speed = 78, Jump = 100, AutoClick = false }

-- [ 1. สร้าง GUI ]
local screenGui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
screenGui.Name = "MyAutoFarmGui"
local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size = UDim2.new(0, 220, 0, 350)
mainFrame.Position = UDim2.new(0.1, 0, 0.1, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0

-- ตัวจัดเรียงอัตโนมัติ
local layout = Instance.new("UIListLayout", mainFrame)
layout.Padding = UDim.new(0, 10); layout.HorizontalAlignment = Enum.HorizontalAlignment.Center; layout.SortOrder = Enum.SortOrder.LayoutOrder

-- ฟังก์ชันสร้างช่องกรอก
local function createInput(labelText, placeholder, default, order)
    local container = Instance.new("Frame", mainFrame)
    container.Size = UDim2.new(0.9, 0, 0, 50); container.BackgroundTransparency = 1; container.LayoutOrder = order
    local label = Instance.new("TextLabel", container)
    label.Size = UDim2.new(1, 0, 0.4, 0); label.Text = labelText; label.BackgroundTransparency = 1; label.TextColor3 = Color3.new(1,1,1); label.Font = Enum.Font.SourceSansBold
    local box = Instance.new("TextBox", container)
    box.Size = UDim2.new(1, 0, 0.6, 0); box.Position = UDim2.new(0, 0, 0.4, 0); box.PlaceholderText = placeholder; box.Text = tostring(default)
    return box
end

local radiusBox = createInput("1. ระยะเก็บของ (Radius)", "30", Config.Radius, 1)
local speedBox = createInput("2. ความเร็ว (WalkSpeed)", "78", Config.Speed, 2)
local jumpBox = createInput("3. พลังกระโดด (JumpPower)", "100", Config.Jump, 3)

local toggleBtn = Instance.new("TextButton", mainFrame)
toggleBtn.Size = UDim2.new(0.9, 0, 0, 40); toggleBtn.Text = "Auto Click: OFF"; toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50); toggleBtn.LayoutOrder = 4

-- ระบบลากหน้าต่าง
local dragging, dragStart, startPos
mainFrame.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; dragStart = input.Position; startPos = mainFrame.Position end end)
UserInputService.InputChanged:Connect(function(input) if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then local delta = input.Position - dragStart; mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)

-- [ 2. Visualizer (วงกลม Rainbow) ]
local areaVisual = Instance.new("Part", workspace)
areaVisual.Name = "TokenAreaVisual"; areaVisual.Shape = Enum.PartType.Cylinder; areaVisual.Transparency = 1; areaVisual.Anchored = true; areaVisual.CanCollide = false
local highlight = Instance.new("SelectionBox", areaVisual)
highlight.Adornee = areaVisual; highlight.LineThickness = 0.08

-- [ 3. Logic & ลูปหลัก ]
radiusBox.FocusLost:Connect(function() Config.Radius = tonumber(radiusBox.Text) or Config.Radius end)
speedBox.FocusLost:Connect(function() Config.Speed = tonumber(speedBox.Text) or Config.Speed end)
jumpBox.FocusLost:Connect(function() Config.Jump = tonumber(jumpBox.Text) or Config.Jump end)
toggleBtn.MouseButton1Click:Connect(function()
    Config.AutoClick = not Config.AutoClick
    toggleBtn.Text = Config.AutoClick and "Auto Click: ON" or "Auto Click: OFF"
    toggleBtn.BackgroundColor3 = Config.AutoClick and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(200, 50, 50)
end)

RunService.Heartbeat:Connect(function()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    
    if hum then
        if hum.WalkSpeed ~= Config.Speed then hum.WalkSpeed = Config.Speed end
        if hum.JumpPower ~= Config.Jump then hum.JumpPower = Config.Jump end
    end
    
    if not root then return end
    
    -- วงกลม Rainbow (ไม่หายแน่นอน)
    highlight.Color3 = Color3.fromHSV(tick() % 5 / 5, 1, 1)
    areaVisual.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
    areaVisual.Size = Vector3.new(0.1, Config.Radius * 2, Config.Radius * 2)
    
    -- ตี & เก็บของ
    if Config.AutoClick then
        local remote = workspace:FindFirstChild("ToolCollect", true) or ReplicatedStorage:FindFirstChild("ToolCollect", true)
        if remote then remote:FireServer() end
    end
    
    local collectibles = workspace:FindFirstChild("Collectibles", true)
    local target = nil; local shortest = Config.Radius
    if collectibles then
        for _, v in pairs(collectibles:GetChildren()) do
            if v.Name == "C" and v:IsA("BasePart") then
                local dist = (root.Position - v.Position).Magnitude
                if dist < shortest then shortest = dist; target = v end
            end
        end
    end
    if target then hum:MoveTo(target.Position) else hum:MoveTo(root.Position) end
end)
