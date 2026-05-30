-- LumoHub Premium - Rayfield Edition
-- Key Validation URL hosted on Render
local KEY_URL = "https://lumohub-bot.onrender.com/keys"

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
while not Player do task.wait(0.1) Player = Players.LocalPlayer end

local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")

-- Fetch Keys
local validKeys = {}
local success, rawKeys = pcall(function()
    return game:HttpGet(KEY_URL)
end)

if success and typeof(rawKeys) == "string" then
    for k in string.gmatch(rawKeys, "[^\r\n]+") do
        local cleaned = string.gsub(k, "%s+", "")
        if #cleaned > 0 then
            table.insert(validKeys, cleaned)
        end
    end
end

if #validKeys == 0 then
    -- If server is down, insert a dummy key so Rayfield doesn't error, but they won't guess it.
    table.insert(validKeys, "SERVER_OFFLINE_OR_ERROR")
end

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local function FixRayfieldSliders()
    task.spawn(function()
        while task.wait(0.1) do
            local success = pcall(function()
                local coreGui = game:GetService("CoreGui")
                local rayfield = coreGui:FindFirstChild("Rayfield")
                if rayfield then
                    for _, v in ipairs(rayfield:GetDescendants()) do
                        -- Kill the giant annoying Rayfield splash text popup completely
                        if v.Name == "LoadingFrame" then
                            v.Visible = false
                            v:Destroy()
                        end
                        
                        -- Find sliders by their structure (since Rayfield renames them to the setting name)
                        if v:IsA("Frame") then
                            local main = v:FindFirstChild("Main")
                            if main then
                                local progress = main:FindFirstChild("Progress")
                                if progress and progress:IsA("Frame") then
                                    main.ClipsDescendants = true -- Prevent blue fill from sticking out
                                    local corner = progress:FindFirstChildOfClass("UICorner")
                                    if corner then corner.CornerRadius = UDim.new(0, 4) end
                                    local stroke = progress:FindFirstChildOfClass("UIStroke")
                                    if stroke then stroke.Transparency = 1 end -- remove ugly outline on the fill
                                    
                                    local mainCorner = main:FindFirstChildOfClass("UICorner")
                                    if mainCorner then mainCorner.CornerRadius = UDim.new(0, 4) end
                                end
                            end
                        end
                    end
                end
            end)
        end
    end)
end
FixRayfieldSliders()

local function LoadLumoHub(activeKey, authGui)
    if game.GameId == 4777817887 or game.PlaceId == 13772394625 or workspace:FindFirstChild("Balls") then
        local Window = Rayfield:CreateWindow({
            Name = "LumoHub Premium | Blade Ball ⚔️",
            Icon = 0,
            LoadingTitle = "LumoHub Premium",
            LoadingSubtitle = "Injecting Blade Ball Modules...",
            Theme = "Default",
            DisableRayfieldPrompts = true,
            DisableBuildWarnings = true,
            ConfigurationSaving = {
                Enabled = false,
                FolderName = "LumoHubConfig",
                FileName = "BladeBallConfig"
            },
            Discord = {
                Enabled = true,
                Invite = "qkCRXBeEpB",
                RememberJoins = true
            },
            KeySystem = false
        })

        local CombatTab = Window:CreateTab("Combat", 4483362458)
        
        local AutoParryEnabled = false
        local SpamParryEnabled = false

        local VirtualInputManager = game:GetService("VirtualInputManager")
        local function Parry()
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        end

        local ParryDistance = 10 -- default distance multiplier

        task.spawn(function()
            local Balls = workspace:WaitForChild("Balls", 9e9)

            local function VerifyBall(Ball)
                if typeof(Ball) == "Instance" and Ball:IsA("BasePart") and Ball:IsDescendantOf(Balls) and Ball:GetAttribute("realBall") == true then
                    return true
                end
            end

            local function IsTarget()
                return (Player.Character and Player.Character:FindFirstChild("Highlight"))
            end

            local function TrackBall(Ball)
                if not VerifyBall(Ball) then return end
                
                local OldPosition = Ball.Position
                local OldTick = tick()

                Ball:GetPropertyChangedSignal("Position"):Connect(function()
                    if not AutoParryEnabled then return end
                    if IsTarget() then
                        local Distance = (Ball.Position - workspace.CurrentCamera.Focus.Position).Magnitude
                        local Velocity = (OldPosition - Ball.Position).Magnitude

                        if Velocity > 0 and (Distance / Velocity) <= ParryDistance then
                            Parry()
                        end
                    end

                    if (tick() - OldTick >= 1/60) then
                        OldTick = tick()
                        OldPosition = Ball.Position
                    end
                end)
            end

            Balls.ChildAdded:Connect(TrackBall)
            for _, b in ipairs(Balls:GetChildren()) do
                TrackBall(b)
            end
        end)

        CombatTab:CreateToggle({
            Name = "Auto Parry",
            CurrentValue = false,
            Flag = "AutoParry",
            Callback = function(Value)
                AutoParryEnabled = Value
            end,
        })

        CombatTab:CreateSlider({
            Name = "Parry Timing (Distance)",
            Range = {5, 25},
            Increment = 0.5,
            Suffix = "Frames",
            CurrentValue = 10,
            Flag = "ParryDistance",
            Callback = function(Value)
                ParryDistance = Value
            end,
        })

        local SpamConnection
        CombatTab:CreateToggle({
            Name = "Hold 'C' to Spam Parry",
            CurrentValue = false,
            Flag = "SpamParry",
            Callback = function(Value)
                SpamParryEnabled = Value
                if Value then
                    local lastSpam = 0
                    SpamConnection = RunService.Heartbeat:Connect(function()
                        if UserInputService:IsKeyDown(Enum.KeyCode.C) then
                            if tick() - lastSpam >= 0.08 then -- ~12 clicks per second max (Safe for Anti-Cheat)
                                lastSpam = tick()
                                Parry()
                            end
                        end
                    end)
                else
                    if SpamConnection then
                        SpamConnection:Disconnect()
                    end
                end
            end,
        })

        Rayfield:LoadConfiguration()
    else
        local Window = Rayfield:CreateWindow({
            Name = "LumoHub Premium | Streetz War 2",
        Icon = 0, -- Removed the original icon so it's perfectly clean
        LoadingTitle = "LumoHub Premium",
        LoadingSubtitle = "Injecting Modules...",
        Theme = "Default", -- Switched to Default for sleek black/white professional sliders

        DisableRayfieldPrompts = true,
        DisableBuildWarnings = true,
        ConfigurationSaving = {
            Enabled = false,
            FolderName = "LumoHubConfig",
            FileName = "Config"
        },
        Discord = {
            Enabled = true,
            Invite = "qkCRXBeEpB",
            RememberJoins = true
        },
        KeySystem = false -- We are using our custom gorgeous key system now!
    })

-- ──────────────────────────────────────────────────────────────
-- TABS
-- ──────────────────────────────────────────────────────────────
local ESPTab = Window:CreateTab("ESP", 4483362458)
local AimbotTab = Window:CreateTab("Aimbot", 4483345998)
local PlayerTab = Window:CreateTab("Player", 4483362458)
local GunTab = Window:CreateTab("Gun Spawn", 4483345998)
local MovementTab = Window:CreateTab("Movement", 4483362458)
local TeleportTab = Window:CreateTab("Teleports", 4483345998)
local SettingsTab = Window:CreateTab("Settings", 4483362458)

-- ──────────────────────────────────────────────────────────────
-- ESP IMPLEMENTATION
-- ──────────────────────────────────────────────────────────────
local ESP = { 
    Drawings = {}, 
    Connections = {},
    Enabled = false,
    Box = false,
    Name = false,
    Health = false,
    Tool = false,
    Color = Color3.fromRGB(255, 255, 255)
}

function ESP:ClearDrawings(player)
    local d = self.Drawings[player]
    if d then
        for _, v in pairs(d) do
            if typeof(v) == "table" then
                for _, obj in pairs(v) do 
                    pcall(function() obj.Visible = false end)
                    pcall(function() if obj.Remove then obj:Remove() end end)
                    pcall(function() if obj.Destroy then obj:Destroy() end end)
                end
            else
                pcall(function() v.Visible = false end)
                pcall(function() if v.Remove then v:Remove() end end)
                pcall(function() if v.Destroy then v:Destroy() end end)
            end
        end
        self.Drawings[player] = nil
    end
end

function ESP:SetupPlayer(player)
    local function setupCharacter(char)
        task.spawn(function()
            char:WaitForChild("HumanoidRootPart", 3)
            char:WaitForChild("Head", 3)
            task.wait(0.1)
            ESP:ClearDrawings(player)
            ESP:CreateDrawings(player)
        end)
    end
    if player.Character then setupCharacter(player.Character) end
    table.insert(ESP.Connections, player.CharacterAdded:Connect(setupCharacter))
end

function ESP:CreateDrawings(player)
    self:ClearDrawings(player)
    local d = {
        Box = {
            TL = Drawing.new("Line"), TR = Drawing.new("Line"),
            BR = Drawing.new("Line"), BL = Drawing.new("Line")
        },
        Name = Drawing.new("Text"),
        Health = Drawing.new("Text"),
        Tool = Drawing.new("Text")
    }
    for _, line in pairs(d.Box) do
        line.Thickness = 1
        line.Color = ESP.Color
        line.Transparency = 1
        line.Visible = false
    end
    for _, text in ipairs({d.Name, d.Health, d.Tool}) do
        text.Color = ESP.Color
        text.Size = 14
        text.Center = true
        text.Outline = true
        text.Visible = false
    end
    self.Drawings[player] = d
end

function ESP:Clear(player)
    self:ClearDrawings(player)
end

function ESP:Update()
    for _, player in ipairs(Players:GetPlayers()) do
        local d = self.Drawings[player]
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        
        -- Check if character is actually in the workspace and alive
        if d and player ~= Players.LocalPlayer and char and char.Parent and hrp and head and hum and hum.Health > 0 then
            local rootPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            
            if onScreen then
                local headPos = Camera:WorldToViewportPoint(head.Position)
                local bottomPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                local height = headPos.Y - bottomPos.Y
                local width = height / 2.2
                local tl = Vector2.new(rootPos.X - width / 2, headPos.Y)
                local tr = Vector2.new(rootPos.X + width / 2, headPos.Y)
                local bl = Vector2.new(rootPos.X - width / 2, bottomPos.Y)
                local br = Vector2.new(rootPos.X + width / 2, bottomPos.Y)
                
                d.Box.TL.From, d.Box.TL.To = tl, tr
                d.Box.TR.From, d.Box.TR.To = tr, br
                d.Box.BR.From, d.Box.BR.To = br, bl
                d.Box.BL.From, d.Box.BL.To = bl, tl
                for _, line in pairs(d.Box) do 
                    line.Color = ESP.Color
                    line.Visible = ESP.Enabled and ESP.Box 
                end
                
                d.Name.Text = player.Name
                d.Name.Position = Vector2.new(rootPos.X, tl.Y - 14)
                d.Name.Color = ESP.Color
                d.Name.Visible = ESP.Enabled and ESP.Name
                
                d.Health.Text = "HP: " .. math.floor(hum.Health)
                d.Health.Position = Vector2.new(rootPos.X, br.Y + 2)
                d.Health.Color = ESP.Color
                d.Health.Visible = ESP.Enabled and ESP.Health
                
                if ESP.Enabled and ESP.Tool then
                    local tool = char:FindFirstChildOfClass("Tool")
                    if tool then
                        d.Tool.Text = "Tool: " .. tool.Name
                        d.Tool.Position = Vector2.new(rootPos.X, br.Y + 18)
                        d.Tool.Color = ESP.Color
                        d.Tool.Visible = true
                    else
                        d.Tool.Visible = false
                    end
                else
                    d.Tool.Visible = false
                end
            else
                -- Offscreen
                for _, line in pairs(d.Box) do line.Visible = false end
                d.Name.Visible = false
                d.Health.Visible = false
                d.Tool.Visible = false
            end
        elseif d then
            for _, line in pairs(d.Box) do line.Visible = false end
            d.Name.Visible = false
            d.Health.Visible = false
            d.Tool.Visible = false
        end
    end
end

for _, p in ipairs(Players:GetPlayers()) do if p ~= Player then ESP:SetupPlayer(p) end end
table.insert(ESP.Connections, Players.PlayerAdded:Connect(function(p) if p ~= Player then ESP:SetupPlayer(p) end end))
table.insert(ESP.Connections, Players.PlayerRemoving:Connect(function(p) ESP:ClearDrawings(p) end))

table.insert(ESP.Connections, RunService.RenderStepped:Connect(function()
    if ESP.Enabled then ESP:Update() end
end))

ESPTab:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = false,
    Flag = "ESP_Enabled",
    Callback = function(Value)
        ESP.Enabled = Value
        if not Value then
            for _, p in ipairs(Players:GetPlayers()) do
                pcall(function()
                    local d = ESP.Drawings[p]
                    if d then
                        for _, line in pairs(d.Box) do 
                            pcall(function() line.Visible = false end) 
                        end
                        pcall(function() d.Name.Visible = false end)
                        pcall(function() d.Health.Visible = false end)
                        pcall(function() d.Tool.Visible = false end)
                    end
                end)
            end
        end
    end,
})

ESPTab:CreateToggle({
    Name = "Boxes",
    CurrentValue = false,
    Flag = "ESP_Box",
    Callback = function(Value)
        ESP.Box = Value
    end,
})

ESPTab:CreateToggle({
    Name = "Names",
    CurrentValue = false,
    Flag = "ESP_Name",
    Callback = function(Value)
        ESP.Name = Value
    end,
})

ESPTab:CreateToggle({
    Name = "Health Indicator",
    CurrentValue = false,
    Flag = "ESP_Health",
    Callback = function(Value)
        ESP.Health = Value
    end,
})

ESPTab:CreateToggle({
    Name = "Equipped Tools",
    CurrentValue = false,
    Flag = "ESP_Tool",
    Callback = function(Value)
        ESP.Tool = Value
    end,
})

ESPTab:CreateColorPicker({
    Name = "ESP Color",
    Color = Color3.fromRGB(255, 255, 255),
    Flag = "ESP_ColorPicker",
    Callback = function(Value)
        ESP.Color = Value
    end
})

-- ──────────────────────────────────────────────────────────────
-- AIMBOT IMPLEMENTATION
-- ──────────────────────────────────────────────────────────────
local Aimbot = {
    Enabled = false,
    AimPart = "Head",
    Sensitivity = 0.5,
    Smoothness = 0.5,
    UseSensitivity = false,
    UseSmoothness = false,
    FOV = 100,
    Target = nil,
    FOVCircle = Drawing.new("Circle")
}

Aimbot.FOVCircle.Radius = Aimbot.FOV
Aimbot.FOVCircle.Thickness = 1
Aimbot.FOVCircle.Color = Color3.fromRGB(255, 255, 255)
Aimbot.FOVCircle.Visible = false
Aimbot.FOVCircle.Filled = false
Aimbot.FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

local function GetAimPart(character, aimPart)
    if aimPart == "Head" then
        return character:FindFirstChild("Head")
    elseif aimPart == "Torso" then
        return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
    elseif aimPart == "HumanoidRootPart" then
        return character:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

local function GetClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = Aimbot.FOV
    local mousePos = UserInputService:GetMouseLocation()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= Player and player.Character and player.Character:FindFirstChildOfClass("Humanoid") and player.Character.Humanoid.Health > 0 then
            local aimPart = GetAimPart(player.Character, Aimbot.AimPart)
            if aimPart then
                local partPos = Camera:WorldToViewportPoint(aimPart.Position)
                local distance = (Vector2.new(partPos.X, partPos.Y) - mousePos).Magnitude
                if distance < shortestDistance and partPos.Z > 0 then
                    closestPlayer = player
                    shortestDistance = distance
                end
            end
        end
    end
    return closestPlayer
end

RunService.RenderStepped:Connect(function()
    if Aimbot.Enabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        Aimbot.Target = GetClosestPlayer()
        if Aimbot.Target then
            local aimPart = GetAimPart(Aimbot.Target.Character, Aimbot.AimPart)
            if aimPart then
                local targetPos = Camera:WorldToViewportPoint(aimPart.Position)
                local mousePos = UserInputService:GetMouseLocation()
                if Aimbot.UseSmoothness and Aimbot.UseSensitivity then
                    local newPos = mousePos + (Vector2.new(targetPos.X, targetPos.Y) - mousePos) * Aimbot.Smoothness
                    pcall(function() mousemoverel((newPos.X - mousePos.X) * Aimbot.Sensitivity, (newPos.Y - mousePos.Y) * Aimbot.Sensitivity) end)
                else
                    pcall(function() mousemoverel(targetPos.X - mousePos.X, targetPos.Y - mousePos.Y) end)
                end
            end
        end
    else
        Aimbot.Target = nil
    end
    Aimbot.FOVCircle.Visible = Aimbot.Enabled
    Aimbot.FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end)

AimbotTab:CreateToggle({
    Name = "Enable Aimbot (Hold Right Click)",
    CurrentValue = false,
    Flag = "Aimbot_Enabled",
    Callback = function(Value)
        Aimbot.Enabled = Value
    end,
})

AimbotTab:CreateToggle({
    Name = "Use Sensitivity",
    CurrentValue = false,
    Flag = "Aimbot_UseSens",
    Callback = function(Value)
        Aimbot.UseSensitivity = Value
    end,
})

AimbotTab:CreateToggle({
    Name = "Use Smoothness",
    CurrentValue = false,
    Flag = "Aimbot_UseSmooth",
    Callback = function(Value)
        Aimbot.UseSmoothness = Value
    end,
})

AimbotTab:CreateDropdown({
    Name = "Aim Target Part",
    Options = {"Head", "Torso", "HumanoidRootPart"},
    CurrentOption = {"Head"},
    MultipleOptions = false,
    Flag = "Aimbot_Part",
    Callback = function(Option)
        Aimbot.AimPart = Option[1]
    end,
})

AimbotTab:CreateSlider({
    Name = "Aim Sensitivity",
    Range = {0, 100},
    Increment = 1,
    Suffix = "%",
    CurrentValue = 50,
    Flag = "Aimbot_Sens",
    Callback = function(Value)
        Aimbot.Sensitivity = Value / 100
    end,
})

AimbotTab:CreateSlider({
    Name = "Aim FOV Radius",
    Range = {10, 500},
    Increment = 10,
    Suffix = "px",
    CurrentValue = 100,
    Flag = "Aimbot_FOV",
    Callback = function(Value)
        Aimbot.FOV = Value
        Aimbot.FOVCircle.Radius = Value
    end,
})

AimbotTab:CreateSlider({
    Name = "Aim Smoothness",
    Range = {0, 100},
    Increment = 1,
    Suffix = "%",
    CurrentValue = 50,
    Flag = "Aimbot_Smooth",
    Callback = function(Value)
        Aimbot.Smoothness = Value / 100
    end,
})

AimbotTab:CreateColorPicker({
    Name = "FOV Circle Color",
    Color = Color3.fromRGB(255, 255, 255),
    Flag = "Aimbot_FOVColor",
    Callback = function(Value)
        Aimbot.FOVCircle.Color = Value
    end
})

-- ──────────────────────────────────────────────────────────────
-- PLAYER PROPERTIES
-- ──────────────────────────────────────────────────────────────
_G.WalkSpeed = 16
_G.JumpPower = 50

local function UpdatePlayerProperties()
    if Player.Character and Player.Character:FindFirstChildOfClass("Humanoid") then
        local humanoid = Player.Character:FindFirstChildOfClass("Humanoid")
        humanoid.WalkSpeed = _G.WalkSpeed or 16
        humanoid.JumpPower = _G.JumpPower or 50
    end
end

Player.CharacterAdded:Connect(UpdatePlayerProperties)

PlayerTab:CreateSlider({
    Name = "Walk Speed",
    Range = {16, 100},
    Increment = 1,
    Suffix = " WS",
    CurrentValue = 16,
    Flag = "Player_WS",
    Callback = function(Value)
        _G.WalkSpeed = Value
        UpdatePlayerProperties()
    end,
})

PlayerTab:CreateSlider({
    Name = "Jump Power",
    Range = {50, 200},
    Increment = 1,
    Suffix = " JP",
    CurrentValue = 50,
    Flag = "Player_JP",
    Callback = function(Value)
        _G.JumpPower = Value
        UpdatePlayerProperties()
    end,
})

-- ──────────────────────────────────────────────────────────────
-- GUN SPAWN
-- ──────────────────────────────────────────────────────────────
local grabtoolsFunc

local function enableGrabTools()
    local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        Rayfield:Notify({Title = "LumoHub", Content = "Waiting for character...", Duration = 3})
        return
    end
    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("BackpackItem") and child:FindFirstChild("Handle") then
            humanoid:EquipTool(child)
        end
    end
    if grabtoolsFunc then grabtoolsFunc:Disconnect() end
    grabtoolsFunc = workspace.ChildAdded:Connect(function(child)
        local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid and child:IsA("BackpackItem") and child:FindFirstChild("Handle") then
            task.spawn(function()
                for i = 1, 5 do
                    task.wait(0.2)
                    if humanoid:EquipTool(child) then
                        Rayfield:Notify({Title = "LumoHub", Content = "Equipped: " .. child.Name, Duration = 2})
                        break
                    end
                end
            end)
        end
    end)
    Rayfield:Notify({Title = "LumoHub", Content = "Grabtools enabled!", Duration = 3})
end

Player.CharacterAdded:Connect(function()
    task.spawn(function()
        for i = 1, 5 do
            task.wait(0.5)
            if Player.Character and Player.Character:FindFirstChildOfClass("Humanoid") then
                enableGrabTools()
                break
            end
        end
    end)
end)

GunTab:CreateButton({
    Name = "Activate Gun Spawn/Grab Tools",
    Callback = function()
        enableGrabTools()
    end,
})

-- ──────────────────────────────────────────────────────────────
-- MOVEMENT (Fly and Noclip)
-- ──────────────────────────────────────────────────────────────
local Fly = {
    Enabled = false,
    Speed = 50,
    BodyVelocity = nil,
    BodyGyro = nil
}

local Noclip = {
    Enabled = false,
    Connection = nil
}

local function enableFly()
    if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then return end
    local hrp = Player.Character.HumanoidRootPart
    
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.Parent = hrp
    Fly.BodyVelocity = bodyVelocity

    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bodyGyro.P = 10000
    bodyGyro.D = 1000
    bodyGyro.Parent = hrp
    Fly.BodyGyro = bodyGyro

    RunService:BindToRenderStep("Fly", Enum.RenderPriority.Character.Value + 1, function()
        if not Fly.Enabled or not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then return end
        local cam = workspace.CurrentCamera
        local moveDirection = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDirection = moveDirection + cam.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDirection = moveDirection - cam.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDirection = moveDirection - cam.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDirection = moveDirection + cam.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDirection = moveDirection + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            moveDirection = moveDirection - Vector3.new(0, 1, 0)
        end
        bodyVelocity.Velocity = moveDirection * Fly.Speed
        bodyGyro.CFrame = cam.CFrame
    end)
end

local function disableFly()
    if Fly.BodyVelocity then Fly.BodyVelocity:Destroy(); Fly.BodyVelocity = nil end
    if Fly.BodyGyro then Fly.BodyGyro:Destroy(); Fly.BodyGyro = nil end
    RunService:UnbindFromRenderStep("Fly")
end

local function enableNoclip()
    if Noclip.Connection then return end
    Noclip.Connection = RunService.Stepped:Connect(function()
        if not Noclip.Enabled or not Player.Character then return end
        for _, part in ipairs(Player.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
end

local function disableNoclip()
    if Noclip.Connection then
        Noclip.Connection:Disconnect()
        Noclip.Connection = nil
    end
end

MovementTab:CreateToggle({
    Name = "Enable Fly",
    CurrentValue = false,
    Flag = "Move_Fly",
    Callback = function(Value)
        Fly.Enabled = Value
        if Value then enableFly() else disableFly() end
    end,
})

MovementTab:CreateSlider({
    Name = "Fly Speed",
    Range = {10, 200},
    Increment = 1,
    Suffix = " Spd",
    CurrentValue = 50,
    Flag = "Move_FlySpd",
    Callback = function(Value)
        Fly.Speed = Value
    end,
})

MovementTab:CreateToggle({
    Name = "Noclip Mode",
    CurrentValue = false,
    Flag = "Move_Noclip",
    Callback = function(Value)
        Noclip.Enabled = Value
        if Value then enableNoclip() else disableNoclip() end
    end,
})

-- ──────────────────────────────────────────────────────────────
-- TELEPORT SUITE
-- ──────────────────────────────────────────────────────────────
local TeleportLocations = {
    {Name = "Apartments 1", Position = Vector3.new(5, 2, 56)},
    {Name = "Apartments 2", Position = Vector3.new(730, 5, 202)},
    {Name = "Bank Vault", Position = Vector3.new(-40880.859375, 3.550363540649414, -407.64154052734375)},
    {Name = "Barber", Position = Vector3.new(129, 2, 160)},
    {Name = "Box Job", Position = Vector3.new(-111, 4, 160)},
    {Name = "Clothes Box Job", Position = Vector3.new(-43, 5, 28)},
    {Name = "Dealership", Position = Vector3.new(790, 5, -8)},
    {Name = "Father and Sons", Position = Vector3.new(66, 4, -322)},
    {Name = "Gun Shop", Position = Vector3.new(-245, 4, 39)},
    {Name = "Ice Box", Position = Vector3.new(59, 1, -229)},
    {Name = "333 Gang", Position = Vector3.new(-198, 5, -443)},
    {Name = "ABM Gang", Position = Vector3.new(575, 20, 47)},
    {Name = "AFNF Gang", Position = Vector3.new(217, 5, 130)},
    {Name = "Afro Family", Position = Vector3.new(818, 20, -755)},
    {Name = "AOD Gang", Position = Vector3.new(11, 5, 501)},
    {Name = "CTG Gang", Position = Vector3.new(325, 7, 79)},
    {Name = "DF Gang", Position = Vector3.new(860, 6, 504)},
    {Name = "FSG Gang", Position = Vector3.new(210, 20, -376)},
    {Name = "HS Gang", Position = Vector3.new(-198, 20, 371)},
    {Name = "KOS Gang", Position = Vector3.new(-499, 4, 106)},
    {Name = "LACC Gang", Position = Vector3.new(-181, 4, -765)},
    {Name = "OFB Gang", Position = Vector3.new(-247, 5, -346)},
    {Name = "OT7 Gang", Position = Vector3.new(590, 7, 223)},
    {Name = "PG Gang", Position = Vector3.new(413, 6, 496)},
    {Name = "PKM Gang", Position = Vector3.new(221, 21, -228)},
    {Name = "RGD Gang", Position = Vector3.new(560, 7, 25)},
    {Name = "TPL Gang", Position = Vector3.new(323, 7, 233)}
}

local function teleportTo(position)
    if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        Player.Character.HumanoidRootPart.CFrame = CFrame.new(position)
        Rayfield:Notify({Title = "LumoHub", Content = "Teleported!", Duration = 2})
    else
        Rayfield:Notify({Title = "LumoHub", Content = "Character not found!", Duration = 2})
    end
end

for _, location in ipairs(TeleportLocations) do
    TeleportTab:CreateButton({
        Name = "Teleport to " .. location.Name,
        Callback = function()
            teleportTo(location.Position)
        end,
    })
end

-- ──────────────────────────────────────────────────────────────
-- SETTINGS
-- ──────────────────────────────────────────────────────────────
SettingsTab:CreateButton({
    Name = "Unload Menu (Might be buggy)",
    Callback = function()
        -- Disable and fully Clean up ESP
        ESP.Enabled = false
        for _, p in ipairs(Players:GetPlayers()) do
            if ESP and ESP.ClearDrawings then ESP:ClearDrawings(p) end
        end
        -- Disconnect all ESP background events to prevent duplicate drawings on re-execution
        if ESP.Connections then
            for _, conn in ipairs(ESP.Connections) do
                if conn.Disconnect then conn:Disconnect() end
            end
            ESP.Connections = {}
        end
        
        -- Disable Aimbot
        Aimbot.Enabled = false
        if Aimbot.FOVCircle then Aimbot.FOVCircle.Visible = false end
        
        -- Disable Movement
        if Fly and Fly.Enabled then
            Fly.Enabled = false
            pcall(disableFly)
        end
        if Noclip and Noclip.Enabled then
            Noclip.Enabled = false
            pcall(disableNoclip)
        end
        
        -- Disconnect Grabtools
        if grabtoolsFunc then
            grabtoolsFunc:Disconnect()
            grabtoolsFunc = nil
        end
        
        -- Destroy Rayfield UI
        pcall(function() Rayfield:Destroy() end)
    end,
})

Rayfield:LoadConfiguration()
    end

-- ──────────────────────────────────────────────────────────────
-- KEY EXPIRATION CHECKER
-- ──────────────────────────────────────────────────────────────
task.spawn(function()
    -- Store the keys that were valid when the script was injected
    local myPossibleKeys = {}
    for _, k in ipairs(validKeys) do
        myPossibleKeys[k] = true
    end
    
    -- Ensure the actively verified key is ALWAYS in the list, even if fetched fresh
    if activeKey then
        myPossibleKeys[activeKey] = true
    end

    while task.wait(10) do
        local success, rawKeys = pcall(function()
            return game:HttpGet(KEY_URL)
        end)
        
        if success then
            local currentServerKeys = {}
            if rawKeys ~= "NO_VALID_KEYS" then
                for k in string.gmatch(rawKeys, "[^\r\n]+") do
                    local cleaned = string.gsub(k, "%s+", "")
                    if #cleaned > 0 then
                        currentServerKeys[cleaned] = true
                    end
                end
            end
            
            -- Try to find the exact key the user entered by reading Rayfield's save files
            local exactKey = nil
            local possiblePaths = {
                "LumoHubConfig/Key/LumoHubKeyFile.txt",
                "Rayfield/Key/LumoHubKeyFile.txt",
                "LumoHubKeyFile.txt"
            }
            for _, path in ipairs(possiblePaths) do
                pcall(function() 
                    local content = readfile(path)
                    if content and #content > 0 then
                        exactKey = string.gsub(content, "%s+", "")
                    end
                end)
                if exactKey then break end
            end
            
            local isExpired = false
            
            if exactKey and myPossibleKeys[exactKey] then
                -- We found the key they used, and it was valid at injection.
                -- Check if it's STILL valid on the server now.
                if not currentServerKeys[exactKey] then
                    isExpired = true
                end
            else
                -- We couldn't find/read the saved key file.
                -- Fallback: If ALL keys that were valid at injection are now gone, they must be expired.
                local anyOriginalKeyStillValid = false
                for k, _ in pairs(myPossibleKeys) do
                    if currentServerKeys[k] then
                        anyOriginalKeyStillValid = true
                        break
                    end
                end
                
                if not anyOriginalKeyStillValid then
                    isExpired = true
                end
            end
            
                if isExpired then
                    -- Close UI
                    pcall(function() Rayfield:Destroy() end)
                    
                    -- Kick player
                    Player:Kick("⏳ Your LumoHub Premium key has expired!\n\nPlease generate a new key in our Discord server.")
                    break
                end
            end
        end
    end)

    -- Destroy the Auth GUI mask completely after Rayfield has fully loaded and created tabs
    if authGui then
        pcall(function() authGui:Destroy() end)
    end
end -- End of LoadLumoHub function

-- ──────────────────────────────────────────────────────────────
-- CUSTOM KEY AUTHENTICATION GUI
-- ──────────────────────────────────────────────────────────────
local function CheckSavedKey()
    local saved = ""
    pcall(function() saved = readfile("LumoHubKeyFile.txt") end)
    if saved and saved ~= "" then
        saved = string.gsub(saved, "%s+", "")
        for _, k in ipairs(validKeys) do
            if k == saved then
                return saved
            end
        end
    end
    return nil
end

local savedValidKey = CheckSavedKey()
if savedValidKey then
    -- Key is valid and saved, bypass UI and load directly
    LoadLumoHub(savedValidKey)
else
    -- Build Custom UI
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "LumoHubAuth"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.DisplayOrder = 100 -- Ensure it covers Rayfield splash screen
    
    local success = pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
    if not success then ScreenGui.Parent = Player:WaitForChild("PlayerGui") end

    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 420, 0, 260)
    MainFrame.Position = UDim2.new(0.5, -210, 0.5, -130)
    MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35) -- Sleek dark gray
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 12)
    UICorner.Parent = MainFrame

    local UIStroke = Instance.new("UIStroke")
    UIStroke.Color = Color3.fromRGB(80, 80, 80) -- Subtle gray border
    UIStroke.Thickness = 1
    UIStroke.Parent = MainFrame

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.Position = UDim2.new(0, 0, 0, 15)
    Title.BackgroundTransparency = 1
    Title.Text = "LumoHub Premium"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255) -- Pure white
    Title.TextSize = 28
    Title.Font = Enum.Font.GothamBold
    Title.Parent = MainFrame

    local SubTitle = Instance.new("TextLabel")
    SubTitle.Size = UDim2.new(1, 0, 0, 20)
    SubTitle.Position = UDim2.new(0, 0, 0, 50)
    SubTitle.BackgroundTransparency = 1
    SubTitle.Text = "Authentication Required"
    SubTitle.TextColor3 = Color3.fromRGB(200, 200, 200)
    SubTitle.TextSize = 14
    SubTitle.Font = Enum.Font.Gotham
    SubTitle.Parent = MainFrame

    local KeyBox = Instance.new("TextBox")
    KeyBox.Size = UDim2.new(0, 360, 0, 45)
    KeyBox.Position = UDim2.new(0.5, -180, 0, 95)
    KeyBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    KeyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    KeyBox.PlaceholderText = "Paste your LumoHub Key here..."
    KeyBox.TextSize = 14
    KeyBox.Font = Enum.Font.Gotham
    KeyBox.Text = ""
    KeyBox.ClearTextOnFocus = false
    KeyBox.Parent = MainFrame

    local BoxCorner = Instance.new("UICorner")
    BoxCorner.CornerRadius = UDim.new(0, 6)
    BoxCorner.Parent = KeyBox
    
    local BoxStroke = Instance.new("UIStroke")
    BoxStroke.Color = Color3.fromRGB(50, 50, 50)
    BoxStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    BoxStroke.Parent = KeyBox

    local VerifyBtn = Instance.new("TextButton")
    VerifyBtn.Size = UDim2.new(0, 175, 0, 40)
    VerifyBtn.Position = UDim2.new(0.5, -180, 0, 155)
    VerifyBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- White button
    VerifyBtn.TextColor3 = Color3.fromRGB(35, 35, 35) -- Dark text
    VerifyBtn.Text = "Verify Key"
    VerifyBtn.TextSize = 16
    VerifyBtn.Font = Enum.Font.GothamBold
    VerifyBtn.Parent = MainFrame

    local VerifyCorner = Instance.new("UICorner")
    VerifyCorner.CornerRadius = UDim.new(0, 6)
    VerifyCorner.Parent = VerifyBtn

    local DiscordBtn = Instance.new("TextButton")
    DiscordBtn.Size = UDim2.new(0, 175, 0, 40)
    DiscordBtn.Position = UDim2.new(0.5, 5, 0, 155)
    DiscordBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
    DiscordBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    DiscordBtn.Text = "Copy Discord Link"
    DiscordBtn.TextSize = 15
    DiscordBtn.Font = Enum.Font.GothamBold
    DiscordBtn.Parent = MainFrame

    local DiscordCorner = Instance.new("UICorner")
    DiscordCorner.CornerRadius = UDim.new(0, 6)
    DiscordCorner.Parent = DiscordBtn

    local Status = Instance.new("TextLabel")
    Status.Size = UDim2.new(1, 0, 0, 20)
    Status.Position = UDim2.new(0, 0, 0, 215)
    Status.BackgroundTransparency = 1
    Status.Text = ""
    Status.TextColor3 = Color3.fromRGB(255, 100, 100)
    Status.TextSize = 14
    Status.Font = Enum.Font.Gotham
    Status.Parent = MainFrame

    DiscordBtn.MouseButton1Click:Connect(function()
        pcall(function() setclipboard("https://discord.gg/qkCRXBeEpB") end)
        Status.TextColor3 = Color3.fromRGB(100, 255, 100)
        Status.Text = "Copied Discord Invite to clipboard!"
        task.wait(2)
        if Status.Text == "Copied Discord Invite to clipboard!" then
            Status.Text = ""
        end
    end)

    VerifyBtn.MouseButton1Click:Connect(function()
        local entered = string.gsub(KeyBox.Text, "%s+", "")
        if #entered == 0 then
            Status.TextColor3 = Color3.fromRGB(255, 100, 100)
            Status.Text = "Please enter a key first!"
            return
        end

        local isValid = false
        
        -- 1) Check against the keys we fetched when the script was injected
        for _, k in ipairs(validKeys) do
            if k == entered then
                isValid = true
                break
            end
        end

        -- 2) If not found, fetch fresh keys! (in case they generated it AFTER injecting)
        if not isValid then
            Status.TextColor3 = Color3.fromRGB(254, 204, 35)
            Status.Text = "Fetching fresh keys..."
            
            local success, rawKeys = pcall(function()
                return game:HttpGet(KEY_URL)
            end)
            
            if success and rawKeys ~= "NO_VALID_KEYS" then
                for k in string.gmatch(rawKeys, "[^\r\n]+") do
                    local cleaned = string.gsub(k, "%s+", "")
                    if cleaned == entered then
                        isValid = true
                        table.insert(validKeys, entered) -- Save it internally so expiration works
                        break
                    end
                end
            end
        end

        if isValid then
            Status.TextColor3 = Color3.fromRGB(100, 255, 100)
            Status.Text = "Key Validated! Loading LumoHub..."
            pcall(function() writefile("LumoHubKeyFile.txt", entered) end)
            
            task.wait(0.5)
            MainFrame.Visible = false
            
            -- Pass the ScreenGui to LoadLumoHub so it destroys it when done
            LoadLumoHub(entered, ScreenGui)
        else
            Status.TextColor3 = Color3.fromRGB(255, 100, 100)
            Status.Text = "Invalid or Expired Key!"
        end
    end)
end
