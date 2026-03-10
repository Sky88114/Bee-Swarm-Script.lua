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

-- ล้าง GUI เก่า
if player.PlayerGui:FindFirstChild("MyAutoFarmGui") then player.PlayerGui.MyAutoFarmGui:Destroy() end
if workspace:FindFirstChild("TokenAreaVisual") then workspace:FindFirstChild("TokenAreaVisual"):Destroy() end

-- [ 1. สร้าง GUI ]
local screenGui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
screenGui.Name = "MyAutoFarmGui"
local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size = UDim2.new(0, 220, 0, 350)
mainFrame.Position = UDim2.new(0.1, 0, 0.1, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)

local layout = Instance.new("UIListLayout", mainFrame)
layout.Padding = UDim.new(0, 10); layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function createInput(name, default)
    local container = Instance.new("Frame", mainFrame)
    container.Size = UDim2.new(0.9, 0, 0, 50); container.BackgroundTransparency = 1
    local label = Instance.new("TextLabel", container)
    label.Size = UDim2.new(1, 0, 0.4, 0); label.Text = name; label.TextColor3 = Color3.new(1,1,1)
    local box = Instance.new("TextBox", container)
    box.Size = UDim2.new(1, 0, 0.6, 0); box.Position = UDim2.new(0, 0, 0.4, 0); box.Text = tostring(default); box.Name = "ValueBox"
    return box
end

local radiusBox = createInput("Radius", 30)
local speedBox = createInput("WalkSpeed", 78)
local jumpBox = createInput("JumpPower", 100)
local toggleBtn = Instance.new("TextButton", mainFrame)
toggleBtn.Size = UDim2.new(0.9, 0, 0, 40); toggleBtn.Text = "Auto Click: OFF"; toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)

-- [ 2. Visualizer (Area Rainbow) ]
local areaVisual = Instance.new("Part", workspace)
areaVisual.Name = "TokenAreaVisual"; areaVisual.Shape = Enum.PartType.Cylinder; areaVisual.Transparency = 0.8; areaVisual.Anchored = true; areaVisual.CanCollide = false
local highlight = Instance.new("SelectionBox", areaVisual); highlight.Adornee = areaVisual

-- [ 3. Logic ฟาร์มแบบ Lock-on (แก้เดินวน) ]
local autoClick = false
local lockedTarget = nil

toggleBtn.MouseButton1Click:Connect(function() 
    autoClick = not autoClick
    toggleBtn.Text = autoClick and "Auto Click: ON" or "Auto Click: OFF"
    toggleBtn.BackgroundColor3 = autoClick and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(200, 50, 50)
end)

RunService.Heartbeat:Connect(function()
    local char = player.Character; if not char then return end
    local hum = char:FindFirstChild("Humanoid"); local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end

    -- บังคับค่า Stats
    hum.WalkSpeed = tonumber(speedBox.ValueBox.Text) or 78
    hum.JumpPower = tonumber(jumpBox.ValueBox.Text) or 100
    
    -- อัปเดต Area
    local r = tonumber(radiusBox.ValueBox.Text) or 30
    areaVisual.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
    areaVisual.Size = Vector3.new(0.1, r * 2, r * 2)
    highlight.Color3 = Color3.fromHSV(tick() % 5 / 5, 1, 1)

    -- ฟาร์ม
    local remote = findObject("ToolCollect")
    if autoClick and remote then remote:FireServer() end
    
    -- ระบบ Lock-on เป้าหมาย (แก้เดินวน)
    local collectibles = findObject("Collectibles")
    if collectibles then
        -- ถ้าเป้าหมายเดิมยังอยู่และอยู่ในระยะ ให้เดินไปหาตัวเดิม
        if lockedTarget and lockedTarget.Parent and (root.Position - lockedTarget.Position).Magnitude <= (r + 10) then
            hum:MoveTo(lockedTarget.Position)
        else
            -- หาทีใกล้ที่สุดใหม่
            lockedTarget = nil
            local distShort = r
            for _, v in pairs(collectibles:GetChildren()) do
                if v:IsA("BasePart") then
                    local d = (root.Position - v.Position).Magnitude
                    if d < distShort then distShort = d; lockedTarget = v end
                end
            end
            if lockedTarget then hum:MoveTo(lockedTarget.Position) else hum:MoveTo(root.Position) end
        end
    end
end)
