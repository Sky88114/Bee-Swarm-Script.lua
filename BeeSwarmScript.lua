local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- ล้างของเก่า
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
    label.Size = UDim2.new(1, 0, 0.4, 0); label.Text = name; label.BackgroundTransparency = 1; label.TextColor3 = Color3.new(1,1,1)
    local box = Instance.new("TextBox", container)
    box.Size = UDim2.new(1, 0, 0.6, 0); box.Position = UDim2.new(0, 0, 0.4, 0); box.Text = tostring(default); box.Name = "ValueBox"
    return box
end

local radiusBox = createInput("Radius", 30)
local speedBox = createInput("WalkSpeed", 78)
local jumpBox = createInput("JumpPower", 100)
local toggleBtn = Instance.new("TextButton", mainFrame)
toggleBtn.Size = UDim2.new(0.9, 0, 0, 40); toggleBtn.Text = "Auto Click: OFF"; toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)

-- [ 2. Visualizer (Area) ]
local areaVisual = Instance.new("Part", workspace)
areaVisual.Name = "TokenAreaVisual"; areaVisual.Shape = Enum.PartType.Cylinder; areaVisual.Transparency = 0.8; areaVisual.Anchored = true; areaVisual.CanCollide = false
local highlight = Instance.new("SelectionBox", areaVisual)
highlight.Adornee = areaVisual; highlight.LineThickness = 0.1

-- [ 3. ระบบฟาร์มแบบ Lock-on ปรับปรุงใหม่ ]
local autoClick = false
local lockedTarget = nil
local lastSwitchTime = 0 -- ป้องกันการสลับเป้าหมายรัวๆ

toggleBtn.MouseButton1Click:Connect(function()
    autoClick = not autoClick
    toggleBtn.Text = autoClick and "Auto Click: ON" or "Auto Click: OFF"
    toggleBtn.BackgroundColor3 = autoClick and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(200, 50, 50)
end)

RunService.Heartbeat:Connect(function()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    
    local r = tonumber(radiusBox.ValueBox.Text) or 30
    local s = tonumber(speedBox.ValueBox.Text) or 78
    local j = tonumber(jumpBox.ValueBox.Text) or 100
    
    if hum then hum.WalkSpeed = s; hum.JumpPower = j end
    if not root then return end
    
    -- อัปเดต Area
    areaVisual.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
    areaVisual.Size = Vector3.new(0.1, r * 2, r * 2)
    highlight.Color3 = Color3.fromHSV(tick() % 5 / 5, 1, 1)
    
    if autoClick then
        local remote = workspace:FindFirstChild("ToolCollect", true) or ReplicatedStorage:FindFirstChild("ToolCollect", true)
        if remote then remote:FireServer() end
    end
    
    -- [ Logic เดินแบบใหม่: ลดการสลับเป้าหมาย ]
    local collectibles = workspace:FindFirstChild("Collectibles", true)
    
    -- เช็คเป้าหมายเดิม
    if lockedTarget and lockedTarget.Parent and (root.Position - lockedTarget.Position).Magnitude < (r + 10) then
        hum:MoveTo(lockedTarget.Position)
    else
        -- ถ้าจะเปลี่ยนเป้าหมาย ต้องทิ้งระยะห่าง 0.3 วินาที (ป้องกันการวน)
        if tick() - lastSwitchTime > 0.3 then
            lockedTarget = nil
            local bestTarget = nil
            local shortest = r
            if collectibles then
                for _, v in pairs(collectibles:GetChildren()) do
                    if v.Name == "C" and v:IsA("BasePart") then
                        local dist = (root.Position - v.Position).Magnitude
                        if dist < shortest then
                            shortest = dist
                            bestTarget = v
                        end
                    end
                end
            end
            if bestTarget then
                lockedTarget = bestTarget
                lastSwitchTime = tick()
            end
        end
        if lockedTarget then hum:MoveTo(lockedTarget.Position) else hum:MoveTo(root.Position) end
    end
end)
