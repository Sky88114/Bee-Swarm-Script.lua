local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local root = character:WaitForChild("HumanoidRootPart")

-- ระบบค้นหาไฟล์อัตโนมัติ
local function findObject(name)
    return workspace:FindFirstChild(name, true) or ReplicatedStorage:FindFirstChild(name, true)
end
local remote = findObject("ToolCollect")
local collectibles = findObject("Collectibles")

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

-- ตัวจัดเรียงอัตโนมัติ (ช่วยให้บรรทัดไม่ซ้อนกัน)
local layout = Instance.new("UIListLayout", mainFrame)
layout.Padding = UDim.new(0, 10)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder

-- [ 2. ฟังก์ชันสร้างช่องกรอกแบบมีป้ายกำกับ ]
local function createInput(labelText, placeholder, default, order)
    local container = Instance.new("Frame", mainFrame)
    container.Size = UDim2.new(0.9, 0, 0, 50); container.BackgroundTransparency = 1; container.LayoutOrder = order
    
    local label = Instance.new("TextLabel", container)
    label.Size = UDim2.new(1, 0, 0.4, 0); label.Text = labelText; label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1,1,1); label.Font = Enum.Font.SourceSansBold
    
    local box = Instance.new("TextBox", container)
    box.Size = UDim2.new(1, 0, 0.6, 0); box.Position = UDim2.new(0, 0, 0.4, 0)
    box.PlaceholderText = placeholder; box.Text = tostring(default)
    return box
end

local radiusBox = createInput("ระยะเก็บของ (Radius)", "30", Config.Radius, 1)
local speedBox = createInput("ความเร็ว (WalkSpeed)", "78", Config.Speed, 2)
local jumpBox = createInput("พลังกระโดด (JumpPower)", "100", Config.Jump, 3)

local toggleBtn = Instance.new("TextButton", mainFrame)
toggleBtn.Size = UDim2.new(0.9, 0, 0, 40); toggleBtn.Text = "Auto Click: OFF"
toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50); toggleBtn.LayoutOrder = 4

-- ระบบลากหน้าต่าง
local dragging, dragStart, startPos
mainFrame.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; dragStart = input.Position; startPos = mainFrame.Position end end)
UserInputService.InputChanged:Connect(function(input) if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then local delta = input.Position - dragStart; mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)

-- [ 3. Logic อัปเดตค่า ]
radiusBox.FocusLost:Connect(function() Config.Radius = tonumber(radiusBox.Text) or Config.Radius end)
speedBox.FocusLost:Connect(function() Config.Speed = tonumber(speedBox.Text) or Config.Speed end)
jumpBox.FocusLost:Connect(function() Config.Jump = tonumber(jumpBox.Text) or Config.Jump end)
toggleBtn.MouseButton1Click:Connect(function()
    Config.AutoClick = not Config.AutoClick
    toggleBtn.Text = Config.AutoClick and "Auto Click: ON" or "Auto Click: OFF"
    toggleBtn.BackgroundColor3 = Config.AutoClick and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(200, 50, 50)
end)

-- [ 4. ลูปหลัก ]
RunService.Heartbeat:Connect(function()
    if not root or not humanoid then return end
    humanoid.WalkSpeed = Config.Speed
    humanoid.JumpPower = Config.Jump
    if Config.AutoClick and remote then remote:FireServer() end
    
    -- เดินเก็บของ (Lock Target)
    local target = nil; local shortest = Config.Radius
    if collectibles then
        for _, v in pairs(collectibles:GetChildren()) do
            if v.Name == "C" and v:IsA("BasePart") then
                local dist = (root.Position - v.Position).Magnitude
                if dist < shortest then shortest = dist; target = v end
            end
        end
    end
    if target then humanoid:MoveTo(target.Position) else humanoid:MoveTo(root.Position) end
end)
