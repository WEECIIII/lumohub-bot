-- LumoHub Premium - Rayfield Edition
-- Key Validation URL hosted on Render
local KEY_URL = "https://lumohub-bot.onrender.com/keys"

if not game:IsLoaded() then game.Loaded:Wait() end

-- Clean up old instances to prevent screen blur bugs
pcall(function()
    for _, v in pairs(game:GetService("CoreGui"):GetChildren()) do
        if v.Name == "Rayfield" or v.Name == "LumoHubAuth" then v:Destroy() end
    end
    for _, v in pairs(game:GetService("Lighting"):GetChildren()) do
        if v:IsA("BlurEffect") then v:Destroy() end
    end
    local lp = game:GetService("Players").LocalPlayer
    if lp and lp:FindFirstChild("PlayerGui") then
        for _, v in pairs(lp.PlayerGui:GetChildren()) do
            if v.Name == "Rayfield" or v.Name == "LumoHubAuth" then v:Destroy() end
        end
    end
end)

-- ──────────────────────────────────────────────────────────────
-- GLOBAL CLEANUP (Prevents lag/bugs on re-execution)
-- ──────────────────────────────────────────────────────────────
if _G.LumoHub_Connections then
    for _, conn in pairs(_G.LumoHub_Connections) do
        pcall(function() conn:Disconnect() end)
    end
end
_G.LumoHub_Connections = {}

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
                        -- Fix sliders (LoadingFrame destruction removed to prevent UI crash)
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

local function CreateProtectionsTab(Window)
    local MiscTab = Window:CreateTab("Misc & Protections 🛡️", 4483362458)
    
    MiscTab:CreateSection("Protections")
    MiscTab:CreateToggle({
        Name = "Anti-AFK (Stealth / Undetected)",
        CurrentValue = false,
        Flag = "AntiAFK",
        Callback = function(Value)
            _G.AntiAFKEnabled = Value
            if Value then
                if getconnections then
                    for _, conn in pairs(getconnections(Player.Idled)) do
                        if conn.Disable then conn:Disable() end
                    end
                    Rayfield:Notify({Title = "Anti-AFK Enabled", Content = "Stealth method active! You won't be kicked for idling.", Duration = 3})
                else
                    -- Fallback for executors without getconnections
                    _G.AntiAFKConnection = Player.Idled:Connect(function()
                        if _G.AntiAFKEnabled then
                            local vim = game:GetService("VirtualInputManager")
                            vim:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                            task.wait(0.1)
                            vim:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                        end
                    end)
                    Rayfield:Notify({Title = "Anti-AFK Enabled", Content = "Fallback method active!", Duration = 3})
                end
            else
                if getconnections then
                    for _, conn in pairs(getconnections(Player.Idled)) do
                        if conn.Enable then conn:Enable() end
                    end
                end
                if _G.AntiAFKConnection then
                    _G.AntiAFKConnection:Disconnect()
                    _G.AntiAFKConnection = nil
                end
            end
        end,
    })

    MiscTab:CreateButton({
        Name = "Anti-Kick (Metatable Hook)",
        Callback = function()
            if not hookmetamethod then
                Rayfield:Notify({Title = "Error", Content = "Your executor does not support hookmetamethod!", Duration = 3})
                return
            end
            
            if _G.AntiKickHooked then
                Rayfield:Notify({Title = "Already Hooked", Content = "Anti-Kick is already running.", Duration = 2})
                return
            end
            _G.AntiKickHooked = true
            
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if not checkcaller() and (method == "Kick" or method == "kick") and self == Player then
                    return -- Ignore the kick
                end
                return oldNamecall(self, ...)
            end))
            Rayfield:Notify({Title = "Anti-Kick Enabled", Content = "Client-sided kicks will now be blocked.", Duration = 3})
        end,
    })

    MiscTab:CreateSection("Quality of Life")
    MiscTab:CreateButton({
        Name = "Server Hopper (Smallest Server)",
        Callback = function()
            Rayfield:Notify({Title = "Searching...", Content = "Looking for a small server...", Duration = 3})
            local HttpService = game:GetService("HttpService")
            local TeleportService = game:GetService("TeleportService")
            pcall(function()
                local Servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"))
                for _, server in pairs(Servers.data) do
                    if server.playing < server.maxPlayers and server.id ~= game.JobId then
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, Player)
                        break
                    end
                end
            end)
        end,
    })

    MiscTab:CreateButton({
        Name = "FPS Booster (Potato PC Mode)",
        Callback = function()
            local workspace = game:GetService("Workspace")
            local lighting = game:GetService("Lighting")
            local terrain = workspace:FindFirstChildOfClass('Terrain')
            if terrain then
                terrain.WaterWaveSize = 0
                terrain.WaterWaveSpeed = 0
                terrain.WaterReflectance = 0
                terrain.WaterTransparency = 0
            end
            lighting.GlobalShadows = false
            lighting.FogEnd = 9e9
            settings().Rendering.QualityLevel = 1
            for _, v in pairs(game:GetDescendants()) do
                if v:IsA("Part") or v:IsA("UnionOperation") or v:IsA("MeshPart") then
                    v.Material = Enum.Material.Plastic
                    v.Reflectance = 0
                elseif (v:IsA("Decal") or v:IsA("Texture")) then
                    v.Transparency = 1
                elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
                    v.Lifetime = NumberRange.new(0)
                end
            end
            Rayfield:Notify({Title = "FPS Boosted", Content = "Graphics have been completely stripped for max performance.", Duration = 3})
        end,
    })
end

local function LoadLumoHub(activeKey, authGui)
    local success, info = pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId) end)
    local GameName = (success and info) and info.Name or "Unknown Game"



    if game.GameId == 7436755782 or game.PlaceId == 126884695634066 or string.find(string.lower(GameName), "garden") then
            local Window = Rayfield:CreateWindow({
                Name = "LumoHub Premium | " .. GameName,
                Icon = 0,
                LoadingTitle = "LumoHub Premium",
                LoadingSubtitle = "Injecting Modules...",
                Theme = "Default",
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
                KeySystem = false
            })

            local GardenTab = Window:CreateTab("Grow a Garden 🌱", 4483362458)
            local MovementTab = Window:CreateTab("Movement 🏃", 4483362458)
            local TeleportTab = Window:CreateTab("Teleports 📍", 4483362458)
            local SettingsTab = Window:CreateTab("Settings ⚙️", 4483362458)

            GardenTab:CreateSection("Economy & Selling")

            GardenTab:CreateButton({
                Name = "Sell All Pets",
                Callback = function()
                    pcall(function()
                        game:GetService("ReplicatedStorage").GameEvents.SellAllPets_RE:FireServer()
                    end)
                    Rayfield:Notify({Title = "Grow a Garden", Content = "Sold all pets!", Duration = 3})
                end,
            })

            GardenTab:CreateButton({
                Name = "Sell All Inventory (Food/Crops)",
                Callback = function()
                    pcall(function()
                        game:GetService("ReplicatedStorage").GameEvents.Sell_Inventory:FireServer()
                        game:GetService("ReplicatedStorage").GameEvents.SellFood_RE:FireServer()
                    end)
                    Rayfield:Notify({Title = "Grow a Garden", Content = "Sold all inventory items!", Duration = 3})
                end,
            })

            GardenTab:CreateSection("Auto Farming")

            local AutoCollect = false
            GardenTab:CreateToggle({
                Name = "Auto Collect / Harvest",
                CurrentValue = false,
                Flag = "Garden_AutoCollect",
                Callback = function(Value)
                    AutoCollect = Value
                    if Value then
                        task.spawn(function()
                            while AutoCollect do
                                task.wait(0.2)
                                pcall(function()
                                    for _, prompt in pairs(workspace:GetDescendants()) do
                                        if prompt:IsA("ProximityPrompt") and prompt.ActionText:lower():match("collect") then
                                            if prompt.Parent and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                                                if (prompt.Parent.Position - Player.Character.HumanoidRootPart.Position).Magnitude <= (prompt.MaxActivationDistance + 5) then
                                                    fireproximityprompt(prompt, 1)
                                                end
                                            end
                                        end
                                    end
                                end)
                            end
                        end)
                    end
                end,
            })



            local AutoWater = false
            GardenTab:CreateToggle({
                Name = "Auto Water / Fertilize",
                CurrentValue = false,
                Flag = "Garden_AutoWater",
                Callback = function(Value)
                    AutoWater = Value
                    if Value then
                        task.spawn(function()
                            while AutoWater do
                                task.wait(1)
                                pcall(function()
                                    game:GetService("ReplicatedStorage").GameEvents.Water_RE:FireServer()
                                    game:GetService("ReplicatedStorage").GameEvents.Sprinkler_RE:FireServer()
                                end)
                            end
                        end)
                    end
                end,
            })

            local AutoSkip = false
            GardenTab:CreateToggle({
                Name = "Auto Skip Growth (If Available)",
                CurrentValue = false,
                Flag = "Garden_AutoSkip",
                Callback = function(Value)
                    AutoSkip = Value
                    if Value then
                        task.spawn(function()
                            while AutoSkip do
                                task.wait(0.5)
                                pcall(function()
                                    for _, prompt in pairs(workspace:GetDescendants()) do
                                        if prompt:IsA("ProximityPrompt") and prompt.ActionText:lower():match("skip") then
                                            if prompt.Parent and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                                                if (prompt.Parent.Position - Player.Character.HumanoidRootPart.Position).Magnitude <= (prompt.MaxActivationDistance + 5) then
                                                    fireproximityprompt(prompt, 1)
                                                end
                                            end
                                        end
                                    end
                                end)
                            end
                        end)
                    end
                end,
            })

            GardenTab:CreateSection("Limits & Inventory")

            GardenTab:CreateButton({
                Name = "Bypass Local Limits & Inventory Overflow",
                Callback = function()
                    pcall(function()
                        for _, val in pairs(Player:GetDescendants()) do
                            if (val:IsA("IntValue") or val:IsA("NumberValue")) and string.match(val.Name:lower(), "max") then
                                val.Value = 999999999
                            end
                        end
                    end)
                    Rayfield:Notify({Title = "Grow a Garden", Content = "Local Limits bypassed! (Server-sided limits cannot be bypassed)", Duration = 4})
                end,
            })
            MovementTab:CreateSection("Speed & Jump")
            
            local walkSpeed = 16
            local jumpPower = 50
            local function UpdatePlayerProperties()
                if Player.Character and Player.Character:FindFirstChildOfClass("Humanoid") then
                    local humanoid = Player.Character:FindFirstChildOfClass("Humanoid")
                    humanoid.WalkSpeed = walkSpeed
                    humanoid.JumpPower = jumpPower
                end
            end
            
            Player.CharacterAdded:Connect(function()
                task.wait(0.5)
                UpdatePlayerProperties()
            end)

            MovementTab:CreateSlider({
                Name = "Walk Speed",
                Range = {16, 150},
                Increment = 1,
                Suffix = " WS",
                CurrentValue = 16,
                Flag = "Garden_WS",
                Callback = function(Value)
                    walkSpeed = Value
                    UpdatePlayerProperties()
                end,
            })
            
            MovementTab:CreateSlider({
                Name = "Jump Power",
                Range = {50, 200},
                Increment = 1,
                Suffix = " JP",
                CurrentValue = 50,
                Flag = "Garden_JP",
                Callback = function(Value)
                    jumpPower = Value
                    UpdatePlayerProperties()
                end,
            })

            TeleportTab:CreateSection("Shops & Locations")
            
            local function tp(pos)
                pcall(function()
                    local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        root.CFrame = CFrame.new(pos) + Vector3.new(0, 3, 0)
                        Rayfield:Notify({Title = "Teleport", Content = "Teleported successfully!", Duration = 2})
                    end
                end)
            end

            TeleportTab:CreateButton({ Name = "Seeds", Callback = function() tp(Vector3.new(36.59, 3.00, -27.00)) end })
            TeleportTab:CreateButton({ Name = "Sell Stuff", Callback = function() tp(Vector3.new(36.59, 3.00, 0.43)) end })
            TeleportTab:CreateButton({ Name = "Pet Eggs", Callback = function() tp(Vector3.new(-235.34, 3.00, 8.37)) end })
            TeleportTab:CreateButton({ Name = "Gears", Callback = function() tp(Vector3.new(-235.41, 3.00, -4.95)) end })
            TeleportTab:CreateButton({ Name = "Cosmetics / Crafting", Callback = function() tp(Vector3.new(-236.01, 3.00, -15.86)) end })

            SettingsTab:CreateSection("Menu Settings")

            SettingsTab:CreateButton({
                Name = "Unload Menu",
                Callback = function()
                    pcall(function() Rayfield:Destroy() end)
                end,
            })

            CreateProtectionsTab(Window)
            Rayfield:LoadConfiguration()
            
        elseif game.GameId == 66654135 or game.PlaceId == 142823291 or GameName:lower():find("murder mystery 2") then
        local Window = Rayfield:CreateWindow({
            Name = "LumoHub Premium 🔪 | Murder Mystery 2",
            LoadingTitle = "LumoHub Premium",
            LoadingSubtitle = "by LumoHub Team",
            ConfigurationSaving = {
                Enabled = false,
                FolderName = "LumoHubConfig",
                FileName = "MM2"
            },
            Discord = {
                Enabled = true,
                Invite = "qkCRXBeEpB",
                RememberJoins = true
            },
            KeySystem = false
        })

        Rayfield:Notify({
            Title = "Game Detected",
            Content = "Murder Mystery 2 scripts loaded!",
            Duration = 3,
            Image = 4483362458,
        })
        
        local RolesTab = Window:CreateTab("Roles & ESP 👁️", 4483362458)
        local CombatTab = Window:CreateTab("Combat & Auto ⚔️", 4483345998)
        local MovementTab = Window:CreateTab("Movement 🏃", 4483362458)
        local TeleportTab = Window:CreateTab("Teleports 📍", 4483362458)
        local NotifyTab = Window:CreateTab("Notifications 🔔", 4483345998)
        
        local MM2_NoclipToggle
        local MM2_AutoEvadeToggle

        RolesTab:CreateSection("Role ESP")
        
        local espLoop
        local function UpdateRoleESP()
            for _, v in pairs(game.Players:GetPlayers()) do
                if v ~= Player and v.Character and v.Character:FindFirstChild("Head") then
                    local highlight = v.Character:FindFirstChild("MM2ESP")
                    if not highlight then
                        highlight = Instance.new("Highlight")
                        highlight.Name = "MM2ESP"
                        highlight.Parent = v.Character
                        highlight.FillTransparency = 0.5
                        highlight.OutlineTransparency = 0.2
                    end
                    
                    local bp = v.Backpack
                    local char = v.Character
                    local isMurderer = (bp:FindFirstChild("Knife") or char:FindFirstChild("Knife"))
                    local isSheriff = (bp:FindFirstChild("Gun") or char:FindFirstChild("Gun"))
                    
                    if isMurderer then
                        highlight.FillColor = Color3.fromRGB(255, 0, 0)
                        highlight.OutlineColor = Color3.fromRGB(200, 0, 0)
                    elseif isSheriff then
                        highlight.FillColor = Color3.fromRGB(0, 0, 255)
                        highlight.OutlineColor = Color3.fromRGB(0, 0, 200)
                    else
                        highlight.FillColor = Color3.fromRGB(0, 255, 0)
                        highlight.OutlineColor = Color3.fromRGB(0, 200, 0)
                    end
                end
            end
        end

        RolesTab:CreateToggle({
            Name = "Role ESP (Murderer=Red, Sheriff=Blue)",
            CurrentValue = false,
            Flag = "MM2_ESP",
            Callback = function(Value)
                if Value then
                    espLoop = game:GetService("RunService").RenderStepped:Connect(function(...) end) -- dummy
                    if _G.MM2_ESP then _G.MM2_ESP:Disconnect() end
                    _G.MM2_ESP = game:GetService("RunService").RenderStepped:Connect(function()
                        pcall(UpdateRoleESP)
                    end)
                    Rayfield:Notify({Title = "ESP Enabled", Content = "Tracking roles dynamically.", Duration = 2})
                else
                    if _G.MM2_ESP then _G.MM2_ESP:Disconnect() end
                    for _, v in pairs(game.Players:GetPlayers()) do
                        if v.Character and v.Character:FindFirstChild("MM2ESP") then
                            v.Character.MM2ESP:Destroy()
                        end
                    end
                end
            end,
        })
        
        CombatTab:CreateSection("Auto Win & Guns")
        
        local autoGrabGun = false
        local autoGrabConn
        CombatTab:CreateToggle({
            Name = "Auto Grab Dropped Gun",
            CurrentValue = false,
            Flag = "AutoGrabGun",
            Callback = function(Value)
                autoGrabGun = Value
                if Value then
                    if _G.MM2_AutoGrab then _G.MM2_AutoGrab:Disconnect() end
                    _G.MM2_AutoGrab = workspace.DescendantAdded:Connect(function(descendant)
                        if descendant.Name == "GunDrop" and autoGrabGun then
                            task.wait(0.1) -- Wait for part to fully spawn in workspace
                            if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                                local oldPos = Player.Character.HumanoidRootPart.CFrame
                                Player.Character.HumanoidRootPart.CFrame = descendant.CFrame
                                task.wait(0.2)
                                if firetouchinterest then
                                    pcall(function()
                                        firetouchinterest(Player.Character.HumanoidRootPart, descendant, 0)
                                        task.wait(0.1)
                                        firetouchinterest(Player.Character.HumanoidRootPart, descendant, 1)
                                    end)
                                end
                                task.wait(0.2)
                                Player.Character.HumanoidRootPart.CFrame = oldPos
                                Rayfield:Notify({Title = "Gun Auto-Grabbed", Content = "You are now the Sheriff!", Duration = 3})
                            end
                        end
                    end)
                else
                    if _G.MM2_AutoGrab then _G.MM2_AutoGrab:Disconnect() end
                end
            end,
        })

        local autoEvade = false
        local evadeLoop
        MM2_AutoEvadeToggle = CombatTab:CreateToggle({
            Name = "Anti-Murderer (Auto Evade)",
            CurrentValue = false,
            Flag = "AutoEvade",
            Callback = function(Value)
                autoEvade = Value
                if Value then
                    if _G.MM2_Evade then _G.MM2_Evade:Disconnect() end
                    _G.MM2_Evade = game:GetService("RunService").Heartbeat:Connect(function()
                        if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then return end
                        
                        local murderer = nil
                        for _, v in pairs(game.Players:GetPlayers()) do
                            if v ~= Player and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                                if v.Character:FindFirstChild("Knife") or (v.Backpack and v.Backpack:FindFirstChild("Knife")) then
                                    murderer = v
                                    break
                                end
                            end
                        end
                        
                        if murderer and murderer.Character and murderer.Character:FindFirstChild("HumanoidRootPart") then
                            local myPos = Player.Character.HumanoidRootPart.Position
                            local murdPos = murderer.Character.HumanoidRootPart.Position
                            local dist = (myPos - murdPos).Magnitude
                            
                            -- If murderer gets within 15 studs, blink away
                            if dist < 15 then
                                local dir = (myPos - murdPos).Unit
                                if dir.X ~= dir.X then dir = Vector3.new(0, 1, 0) end -- Fallback if perfectly overlapping
                                
                                -- Teleport 30 studs in the opposite direction
                                Player.Character.HumanoidRootPart.CFrame = Player.Character.HumanoidRootPart.CFrame + (dir * 30)
                            end
                        end
                    end)
                else
                    if _G.MM2_Evade then _G.MM2_Evade:Disconnect() end
                end
            end,
        })

        
        CombatTab:CreateButton({
            Name = "Grab Dropped Gun",
            Callback = function()
                local gunDrop = workspace:FindFirstChild("GunDrop", true)
                if gunDrop and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                    local oldPos = Player.Character.HumanoidRootPart.CFrame
                    
                    -- Teleport to gun
                    Player.Character.HumanoidRootPart.CFrame = gunDrop.CFrame
                    task.wait(0.2)
                    
                    -- Try to fire touch interest just in case CFrame isn't enough
                    if firetouchinterest then
                        pcall(function()
                            firetouchinterest(Player.Character.HumanoidRootPart, gunDrop, 0)
                            task.wait(0.1)
                            firetouchinterest(Player.Character.HumanoidRootPart, gunDrop, 1)
                        end)
                    end
                    
                    task.wait(0.2)
                    -- Teleport back
                    Player.Character.HumanoidRootPart.CFrame = oldPos
                    Rayfield:Notify({Title = "Gun Grabbed", Content = "Teleported to the dropped gun and returned!", Duration = 3})
                else
                    Rayfield:Notify({Title = "Not Found", Content = "Gun hasn't been dropped or doesn't exist.", Duration = 3})
                end
            end,
        })
        
        local function AttemptShoot(targetPlayer)
            if MM2_NoclipToggle then pcall(function() MM2_NoclipToggle:Set(false) end) end
            if MM2_AutoEvadeToggle then pcall(function() MM2_AutoEvadeToggle:Set(false) end) end
            if not targetPlayer or not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
            if not Player.Character or not Player.Character:FindFirstChild("Gun") then return end
            
            local gun = Player.Character.Gun
            local targetHRP = targetPlayer.Character.HumanoidRootPart
            local myHRP = Player.Character.HumanoidRootPart
            
            local VirtualInputManager = game:GetService("VirtualInputManager")
            
            -- Teleport 3 studs behind them
            myHRP.CFrame = targetHRP.CFrame * CFrame.new(0, 0, 3)
            
            -- Look exactly at them
            workspace.CurrentCamera.CFrame = CFrame.lookAt(workspace.CurrentCamera.CFrame.Position, targetHRP.Position)
            
            -- CRITICAL FIX: You MUST wait a tiny split-second after teleporting.
            -- If you click on the exact same frame you teleport, the game thinks your gun is still at the old location and the bullet hits the wall!
            task.wait(0.1)
            
            -- Force the gun to shoot via script
            gun:Activate()
            
            -- Backup simulated click just in case
            local center = workspace.CurrentCamera.ViewportSize / 2
            VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 1)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 1)
        end

        local function AttemptKill(targetPlayer)
            if MM2_NoclipToggle then pcall(function() MM2_NoclipToggle:Set(false) end) end
            if MM2_AutoEvadeToggle then pcall(function() MM2_AutoEvadeToggle:Set(false) end) end
            if not targetPlayer or not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
            if not Player.Character or not Player.Character:FindFirstChild("Knife") then return end
            
            local knife = Player.Character.Knife
            local handle = knife:FindFirstChild("Handle")
            local targetHRP = targetPlayer.Character.HumanoidRootPart
            local myHRP = Player.Character.HumanoidRootPart
            
            local VirtualInputManager = game:GetService("VirtualInputManager")
            
            local attempts = 0
            -- Keep trying until they are dead (Max 40 attempts / 2 seconds)
            while targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") and targetPlayer.Character.Humanoid.Health > 0 and attempts < 40 do
                attempts = attempts + 1
                local currentHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
                if not currentHRP then break end
                
                -- Teleport EXACTLY inside them to guarantee the knife hitbox connects
                myHRP.CFrame = currentHRP.CFrame
                
                knife:Activate()
                local center = workspace.CurrentCamera.ViewportSize / 2
                VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 1)
                VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 1)
                
                if handle and firetouchinterest then
                    pcall(function()
                        firetouchinterest(handle, currentHRP, 0)
                        firetouchinterest(handle, currentHRP, 1)
                    end)
                end
                task.wait(0.05)
            end
        end

        CombatTab:CreateButton({
            Name = 'Kill All (Requires Murderer) <font color="#aaaaaa" size="13">[Working Properly]</font>',
            Callback = function()
                if Player.Character and Player.Character:FindFirstChild("Knife") then
                    for _, v in pairs(game.Players:GetPlayers()) do
                        if v ~= Player then
                            -- Only attempt to kill if they are alive
                            if v.Character and v.Character:FindFirstChild("Humanoid") and v.Character.Humanoid.Health > 0 then
                                AttemptKill(v)
                            end
                        end
                    end
                else
                    Rayfield:Notify({Title = "Missing Knife", Content = "You must be the murderer and equip your knife first!", Duration = 3})
                end
            end,
        })
        
        CombatTab:CreateButton({
            Name = 'Kill Sheriff (Requires Knife) <font color="#aaaaaa" size="13">[Working Properly]</font>',
            Callback = function()
                if Player.Character and Player.Character:FindFirstChild("Knife") then
                    local sheriff = nil
                    for _, v in pairs(game.Players:GetPlayers()) do
                        if v ~= Player and v.Character and v.Backpack then
                            -- Check if they have a Gun in backpack or character
                            if v.Character:FindFirstChild("Gun") or v.Backpack:FindFirstChild("Gun") then
                                sheriff = v
                                break
                            end
                        end
                    end
                    
                    if sheriff and sheriff.Character and sheriff.Character:FindFirstChild("Humanoid") and sheriff.Character.Humanoid.Health > 0 then
                        Rayfield:Notify({Title = "Targeting", Content = "Teleporting to the Sheriff...", Duration = 2})
                        AttemptKill(sheriff)
                    else
                        Rayfield:Notify({Title = "Not Found", Content = "Could not locate a living Sheriff.", Duration = 3})
                    end
                else
                    Rayfield:Notify({Title = "Missing Knife", Content = "You must be the murderer and equip your knife first!", Duration = 3})
                end
            end,
        })
        
        CombatTab:CreateButton({
            Name = 'Kill Murderer (Requires Gun) <font color="#aaaaaa" size="13">[Might Miss]</font>',
            Callback = function()
                if Player.Character and Player.Character:FindFirstChild("Gun") then
                    local murderer = nil
                    for _, v in pairs(game.Players:GetPlayers()) do
                        if v ~= Player and v.Character and v.Backpack then
                            if v.Character:FindFirstChild("Knife") or v.Backpack:FindFirstChild("Knife") then
                                murderer = v
                                break
                            end
                        end
                    end
                    
                    if murderer and murderer.Character and murderer.Character:FindFirstChild("Humanoid") and murderer.Character.Humanoid.Health > 0 then
                        Rayfield:Notify({Title = "Targeting", Content = "Teleporting to the Murderer...", Duration = 2})
                        AttemptShoot(murderer)
                    else
                        Rayfield:Notify({Title = "Not Found", Content = "Could not locate a living Murderer.", Duration = 3})
                    end
                else
                    Rayfield:Notify({Title = "Missing Gun", Content = "You must have the gun equipped first!", Duration = 3})
                end
            end,
        })


        local noclipLoop
        MovementTab:CreateSection("Physics Bypasses")
        MM2_NoclipToggle = MovementTab:CreateToggle({
            Name = "Noclip (Walk through walls)",
            CurrentValue = false,
            Flag = "MM2_Noclip",
            Callback = function(Value)
                if Value then
                    if _G.MM2_Noclip then _G.MM2_Noclip:Disconnect() end
                    _G.MM2_Noclip = game:GetService("RunService").Stepped:Connect(function()
                        if Player.Character then
                            for _, v in pairs(Player.Character:GetDescendants()) do
                                if v:IsA("BasePart") and v.CanCollide then
                                    v.CanCollide = false
                                end
                            end
                        end
                    end)
                    Rayfield:Notify({Title = "Noclip Enabled", Content = "You can now walk through walls.", Duration = 2})
                else
                    if _G.MM2_Noclip then _G.MM2_Noclip:Disconnect() end
                    Rayfield:Notify({Title = "Noclip Disabled", Content = "Collisions restored.", Duration = 2})
                end
            end,
        })

        MovementTab:CreateSection("Realistic Player Fly")

        local PlayerFlyEnabled = false
        local PlayerFlySpeed = 50
        MovementTab:CreateToggle({
            Name = "Realistic Player Fly",
            CurrentValue = false,
            Flag = "MM2_PlayerFly",
            Callback = function(Value)
                PlayerFlyEnabled = Value
                local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                local humanoid = Player.Character and Player.Character:FindFirstChild("Humanoid")
                
                if not root then return end
                
                if Value then
                    local bv = Instance.new("BodyVelocity")
                    bv.Name = "LumoFlyBV"
                    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    bv.Velocity = Vector3.zero
                    bv.Parent = root
                    
                    local bg = Instance.new("BodyGyro")
                    bg.Name = "LumoFlyBG"
                    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                    bg.CFrame = root.CFrame
                    bg.Parent = root
                    
                    if humanoid then humanoid.PlatformStand = true end
                    
                    task.spawn(function()
                        while PlayerFlyEnabled and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") do
                            local moveDir = Vector3.zero
                            local isMoving = false
                            
                            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Camera.CFrame.LookVector; isMoving = true end
                            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - Camera.CFrame.LookVector; isMoving = true end
                            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - Camera.CFrame.RightVector; isMoving = true end
                            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Camera.CFrame.RightVector; isMoving = true end
                            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0); isMoving = true end
                            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0, 1, 0); isMoving = true end
                            
                            if isMoving then
                                bv.Velocity = moveDir * PlayerFlySpeed
                            else
                                -- Realistic bobbing bit up and bit down
                                bv.Velocity = Vector3.new(0, math.sin(tick() * 3) * 1.5, 0)
                            end
                            
                            -- Keep player totally upright and casually standing
                            local look = Camera.CFrame.LookVector
                            bg.CFrame = CFrame.new(root.Position, root.Position + Vector3.new(look.X, 0, look.Z))
                            
                            -- Completely freeze legs and arms so they are perfectly stiff
                            if humanoid then
                                humanoid.PlatformStand = true
                                for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
                                    track:Stop()
                                end
                            end
                            
                            task.wait()
                        end
                        if bv then bv:Destroy() end
                        if bg then bg:Destroy() end
                        if humanoid then humanoid.PlatformStand = false end
                    end)
                else
                    if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
                    local oldBv = root:FindFirstChild("LumoFlyBV")
                    local oldBg = root:FindFirstChild("LumoFlyBG")
                    if oldBv then oldBv:Destroy() end
                    if oldBg then oldBg:Destroy() end
                end
            end,
        })
        
        MovementTab:CreateSlider({
            Name = "Player Fly Speed",
            Range = {10, 200},
            Increment = 1,
            Suffix = "Spd",
            CurrentValue = 50,
            Flag = "MM2_PlayerFlySpeed",
            Callback = function(Value)
                PlayerFlySpeed = Value
            end,
        })

        local notifyGunDrop = false
        local gunDropConn
        
        NotifyTab:CreateSection("Game Events")
        NotifyTab:CreateToggle({
            Name = "Notify When Sheriff Dies (Gun Drop)",
            CurrentValue = false,
            Flag = "NotifyGunDrop",
            Callback = function(Value)
                notifyGunDrop = Value
                if Value then
                    if _G.MM2_GunDrop then _G.MM2_GunDrop:Disconnect() end
                    _G.MM2_GunDrop = workspace.DescendantAdded:Connect(function(descendant)
                        if descendant.Name == "GunDrop" and notifyGunDrop then
                            Rayfield:Notify({
                                Title = "🚨 SHERIFF DIED! 🚨",
                                Content = "The gun has been dropped! Go to Combat Tab and use 'Grab Dropped Gun'.",
                                Duration = 8,
                                Image = 4483345998
                            })
                        end
                    end)
                else
                    if _G.MM2_GunDrop then _G.MM2_GunDrop:Disconnect() end
                end
            end,
        })

        TeleportTab:CreateSection("Map Locations")
        TeleportTab:CreateButton({
            Name = "Teleport to Lobby",
            Callback = function()
                if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                    Player.Character.HumanoidRootPart.CFrame = CFrame.new(-109.5, 138, 38)
                    Rayfield:Notify({Title = "Teleported", Content = "Returned to Lobby.", Duration = 2})
                end
            end,
        })


        CreateProtectionsTab(Window)
        Rayfield:LoadConfiguration()

    elseif game.GameId == 3993508361 or game.PlaceId == 11177482306 or GameName:lower():find("streetz") or GameName:lower():find("universal") then
            -- Streetz War 2
            local Window = Rayfield:CreateWindow({
                Name = "LumoHub Premium | " .. GameName,
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
local ESPTab = Window:CreateTab("ESP 👁️", 4483362458)
local AimbotTab = Window:CreateTab("Aimbot 🎯", 4483345998)
local PlayerTab = Window:CreateTab("Player 👤", 4483362458)
local GunTab = Window:CreateTab("Gun Spawn 🔫", 4483345998)
local MovementTab = Window:CreateTab("Movement 🏃", 4483362458)
local TeleportTab = Window:CreateTab("Teleports 📍", 4483345998)
local SettingsTab = Window:CreateTab("Settings ⚙️", 4483362458)

-- ──────────────────────────────────────────────────────────────
-- ESP IMPLEMENTATION
-- ──────────────────────────────────────────────────────────────
if _G.LumoESP_Conns then
    for _, c in pairs(_G.LumoESP_Conns) do pcall(function() c:Disconnect() end) end
end
pcall(function() game:GetService("RunService"):UnbindFromRenderStep("LumoESPUpdate") end)
_G.LumoESP_Conns = {}

local ESP = { 
    Drawings = {}, 
    Enabled = false,
    Box = false,
    Skeleton = false,
    Color = Color3.fromRGB(255, 255, 255),
    Thickness = 1,
    Transparency = 1
}

function ESP:ClearDrawings(player)
    local d = self.Drawings[player]
    if d then
        for _, v in pairs(d) do
            if typeof(v) == "table" then
                for _, obj in pairs(v) do 
                    pcall(function() obj.Visible = false end)
                    pcall(function() if obj.Remove then obj:Remove() end end)
                end
            else
                pcall(function() v.Visible = false end)
                pcall(function() if v.Remove then v:Remove() end end)
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
    table.insert(_G.LumoESP_Conns, player.CharacterAdded:Connect(setupCharacter))
end

function ESP:CreateDrawings(player)
    self:ClearDrawings(player)
    local function createLine()
        local l = Drawing.new("Line")
        l.Thickness = ESP.Thickness
        l.Color = ESP.Color
        l.Transparency = ESP.Transparency
        l.Visible = false
        return l
    end
    
    local d = {
        Box = {
            TL = createLine(), TR = createLine(),
            BR = createLine(), BL = createLine()
        },
        Skeleton = {
            Head = createLine(), Spine = createLine(),
            LArm = createLine(), LHand = createLine(),
            RArm = createLine(), RHand = createLine(),
            LLeg = createLine(), LFoot = createLine(),
            RLeg = createLine(), RFoot = createLine()
        }
    }
    self.Drawings[player] = d
end

function ESP:Update()
    local currentCamera = workspace.CurrentCamera
    if not currentCamera then return end
    
    for _, player in ipairs(Players:GetPlayers()) do
        local d = self.Drawings[player]
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        
        if d and player ~= Players.LocalPlayer and char and char.Parent and hrp and head and hum and hum.Health > 0 then
            pcall(function()
                local rootPos, onScreen = currentCamera:WorldToViewportPoint(hrp.Position)
                
                if onScreen then
                    -- BOX ESP
                    local headPos = currentCamera:WorldToViewportPoint(head.Position)
                    local bottomPos = currentCamera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
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
                    
                    -- SKELETON ESP
                    if ESP.Enabled and ESP.Skeleton then
                        local function connect(line, p1, p2)
                            if char:FindFirstChild(p1) and char:FindFirstChild(p2) then
                                local pos1, vis1 = currentCamera:WorldToViewportPoint(char[p1].Position)
                                local pos2, vis2 = currentCamera:WorldToViewportPoint(char[p2].Position)
                                if vis1 or vis2 then
                                    line.From = Vector2.new(pos1.X, pos1.Y)
                                    line.To = Vector2.new(pos2.X, pos2.Y)
                                    line.Color = ESP.Color
                                    line.Visible = true
                                else
                                    line.Visible = false
                                end
                            else
                                line.Visible = false
                            end
                        end
                        
                        connect(d.Skeleton.Head, "Head", "UpperTorso")
                        connect(d.Skeleton.Spine, "UpperTorso", "LowerTorso")
                        connect(d.Skeleton.LArm, "UpperTorso", "LeftUpperArm")
                        connect(d.Skeleton.LHand, "LeftUpperArm", "LeftLowerArm")
                        connect(d.Skeleton.RArm, "UpperTorso", "RightUpperArm")
                        connect(d.Skeleton.RHand, "RightUpperArm", "RightLowerArm")
                        connect(d.Skeleton.LLeg, "LowerTorso", "LeftUpperLeg")
                        connect(d.Skeleton.LFoot, "LeftUpperLeg", "LeftLowerLeg")
                        connect(d.Skeleton.RLeg, "LowerTorso", "RightUpperLeg")
                        connect(d.Skeleton.RFoot, "RightUpperLeg", "RightLowerLeg")
                    else
                        for _, line in pairs(d.Skeleton) do line.Visible = false end
                    end
                else
                    for _, line in pairs(d.Box) do line.Visible = false end
                    for _, line in pairs(d.Skeleton) do line.Visible = false end
                end
            end)
        elseif d then
            pcall(function()
                for _, line in pairs(d.Box) do line.Visible = false end
                for _, line in pairs(d.Skeleton) do line.Visible = false end
            end)
        end
    end
end

for _, p in ipairs(Players:GetPlayers()) do if p ~= Player then ESP:SetupPlayer(p) end end
table.insert(_G.LumoESP_Conns, Players.PlayerAdded:Connect(function(p) if p ~= Player then ESP:SetupPlayer(p) end end))
table.insert(_G.LumoESP_Conns, Players.PlayerRemoving:Connect(function(p) ESP:ClearDrawings(p) end))

RunService:BindToRenderStep("LumoESPUpdate", 2500, function()
    if ESP.Enabled then ESP:Update() end
end)

ESPTab:CreateSection("Visuals & ESP")

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
                        for _, line in pairs(d.Box) do pcall(function() line.Visible = false end) end
                        for _, line in pairs(d.Skeleton) do pcall(function() line.Visible = false end) end
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
    Name = "Skeletons",
    CurrentValue = false,
    Flag = "ESP_Skeleton",
    Callback = function(Value)
        ESP.Skeleton = Value
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

AimbotTab:CreateSection("Aimbot Logic")

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

PlayerTab:CreateSection("Player Modifiers")

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





PlayerTab:CreateSection("Client Sided Spoofs")

PlayerTab:CreateInput({
    Name = "Spoof Level (Visual Only)",
    PlaceholderText = "Enter desired level...",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        local num = tonumber(Text)
        if not num then
            Rayfield:Notify({Title = "Invalid Input", Content = "Please enter a valid number.", Duration = 2})
            return
        end
        pcall(function()
            local found = false
            -- Spoof overhead character tag
            if Player.Character then
                for _, obj in pairs(Player.Character:GetDescendants()) do
                    if obj:IsA("TextLabel") and (string.find(string.lower(obj.Text), "lvl") or string.find(string.lower(obj.Text), "level")) then
                        obj.Text = "LVL " .. tostring(num)
                        found = true
                    end
                end
            end
            -- Spoof UI text
            for _, obj in pairs(Player.PlayerGui:GetDescendants()) do
                if obj:IsA("TextLabel") and (string.find(string.lower(obj.Text), "lvl") or string.find(string.lower(obj.Text), "level")) then
                    -- Prevent accidentally changing non-level UI elements that happen to have the word level
                    if string.len(obj.Text) < 15 then 
                        obj.Text = "LVL " .. tostring(num)
                        found = true
                    end
                end
            end
            
            if found then
                Rayfield:Notify({Title = "Level Spoofed!", Content = "Your Level is now " .. tostring(num) .. " on your screen.", Duration = 4})
            else
                Rayfield:Notify({Title = "Error", Content = "Could not find any Level text to spoof.", Duration = 2})
            end
        end)
    end,
})


-- GUN SPAWN
-- ──────────────────────────────────────────────────────────────
local grabtoolsFunc
local autoGrabEnabled = false

local function startGrabTools()
    local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        for _, child in ipairs(workspace:GetChildren()) do
            if child:IsA("BackpackItem") and child:FindFirstChild("Handle") then
                humanoid:EquipTool(child)
            end
        end
    end
    
    if grabtoolsFunc then grabtoolsFunc:Disconnect() end
    grabtoolsFunc = workspace.ChildAdded:Connect(function(child)
        if not autoGrabEnabled then return end
        local currentHumanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
        if currentHumanoid and child:IsA("BackpackItem") and child:FindFirstChild("Handle") then
            task.spawn(function()
                for i = 1, 5 do
                    task.wait(0.2)
                    if currentHumanoid:EquipTool(child) then
                        Rayfield:Notify({Title = "LumoHub", Content = "Equipped: " .. child.Name, Duration = 2})
                        break
                    end
                end
            end)
        end
    end)
end

Player.CharacterAdded:Connect(function()
    if autoGrabEnabled then
        task.spawn(function()
            for i = 1, 5 do
                task.wait(0.5)
                if Player.Character and Player.Character:FindFirstChildOfClass("Humanoid") then
                    startGrabTools()
                    break
                end
            end
        end)
    end
end)

GunTab:CreateSection("Weapon Management")

GunTab:CreateToggle({
    Name = "Auto Grab Guns/Tools",
    CurrentValue = false,
    Flag = "AutoGrabTools",
    Callback = function(Value)
        autoGrabEnabled = Value
        if Value then
            startGrabTools()
            Rayfield:Notify({Title = "LumoHub", Content = "Auto Grab Tools Enabled!", Duration = 3})
        else
            if grabtoolsFunc then
                grabtoolsFunc:Disconnect()
                grabtoolsFunc = nil
            end
            Rayfield:Notify({Title = "LumoHub", Content = "Auto Grab Tools Disabled!", Duration = 3})
        end
    end,
})

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

MovementTab:CreateSection("Movement Bypasses")

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

        MovementTab:CreateSection("Realistic Player Fly")

        local SW2_PlayerFlyEnabled = false
        local SW2_PlayerFlySpeed = 50
        MovementTab:CreateToggle({
            Name = "Realistic Player Fly",
            CurrentValue = false,
            Flag = "SW2_PlayerFly",
            Callback = function(Value)
                SW2_PlayerFlyEnabled = Value
                local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                local humanoid = Player.Character and Player.Character:FindFirstChild("Humanoid")
                
                if not root then return end
                
                if Value then
                    local bv = Instance.new("BodyVelocity")
                    bv.Name = "SW2_LumoFlyBV"
                    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    bv.Velocity = Vector3.zero
                    bv.Parent = root
                    
                    local bg = Instance.new("BodyGyro")
                    bg.Name = "SW2_LumoFlyBG"
                    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                    bg.CFrame = root.CFrame
                    bg.Parent = root
                    
                    if humanoid then humanoid.PlatformStand = true end
                    
                    task.spawn(function()
                        while SW2_PlayerFlyEnabled and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") do
                            local moveDir = Vector3.zero
                            local isMoving = false
                            local Camera = workspace.CurrentCamera
                            local UserInputService = game:GetService("UserInputService")
                            
                            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Camera.CFrame.LookVector; isMoving = true end
                            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - Camera.CFrame.LookVector; isMoving = true end
                            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - Camera.CFrame.RightVector; isMoving = true end
                            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Camera.CFrame.RightVector; isMoving = true end
                            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0); isMoving = true end
                            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0, 1, 0); isMoving = true end
                            
                            if isMoving then
                                bv.Velocity = moveDir * SW2_PlayerFlySpeed
                            else
                                bv.Velocity = Vector3.new(0, math.sin(tick() * 3) * 1.5, 0)
                            end
                            
                            local look = Camera.CFrame.LookVector
                            bg.CFrame = CFrame.new(root.Position, root.Position + Vector3.new(look.X, 0, look.Z))
                            
                            if humanoid then
                                humanoid.PlatformStand = true
                                for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
                                    track:Stop()
                                end
                            end
                            
                            task.wait()
                        end
                        if bv then bv:Destroy() end
                        if bg then bg:Destroy() end
                        if humanoid then humanoid.PlatformStand = false end
                    end)
                else
                    if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
                    local oldBv = root:FindFirstChild("SW2_LumoFlyBV")
                    local oldBg = root:FindFirstChild("SW2_LumoFlyBG")
                    if oldBv then oldBv:Destroy() end
                    if oldBg then oldBg:Destroy() end
                end
            end,
        })
        
        MovementTab:CreateSlider({
            Name = "Player Fly Speed",
            Range = {10, 200},
            Increment = 1,
            Suffix = "Spd",
            CurrentValue = 50,
            Flag = "SW2_PlayerFlySpeed",
            Callback = function(Value)
                SW2_PlayerFlySpeed = Value
            end,
        })

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

TeleportTab:CreateSection("Streetz War 2 Locations")

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
SettingsTab:CreateSection("Menu Settings")

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

        CreateProtectionsTab(Window)
        Rayfield:LoadConfiguration()

    elseif game.PlaceId == 621129760 or game.GameId == 228028122 then
        -- KAT! (Knife Ability Test) Hub
        local Window = Rayfield:CreateWindow({
            Name = "LumoHub Premium 🔪 | KAT!",
            LoadingTitle = "LumoHub Premium",
            LoadingSubtitle = "Injecting KAT Scripts...",
            ConfigurationSaving = { Enabled = false },
            Discord = { Enabled = true, Invite = "qkCRXBeEpB", RememberJoins = true },
            KeySystem = false
        })

        local MainTab = Window:CreateTab("Combat ⚔️", 4483362458)
        local PlayerTab = Window:CreateTab("LocalPlayer 👤", 4483362458)

        -- Combat Features
        MainTab:CreateSection("Weapons & Combat")
        
        local uniEspFolder = Instance.new("Folder")
        uniEspFolder.Name = "LumoKAT_ESP"
        pcall(function() uniEspFolder.Parent = game:GetService("CoreGui") end)
        
        MainTab:CreateToggle({
            Name = "Player ESP (Wallhacks)",
            CurrentValue = false,
            Flag = "KAT_ESP",
            Callback = function(Value)
                if Value then
                    if _G.KAT_ESP then _G.KAT_ESP:Disconnect() end
                    _G.KAT_ESP = game:GetService("RunService").RenderStepped:Connect(function()
                        for _, v in pairs(game.Players:GetPlayers()) do
                            if v ~= Player and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                                local h = uniEspFolder:FindFirstChild(v.Name .. "_ESP")
                                if not h then
                                    h = Instance.new("Highlight")
                                    h.Name = v.Name .. "_ESP"
                                    h.FillColor = Color3.fromRGB(255, 0, 0)
                                    h.FillTransparency = 0.5
                                    h.OutlineColor = Color3.fromRGB(255, 255, 255)
                                    h.Parent = uniEspFolder
                                end
                                h.Adornee = v.Character
                            end
                        end
                    end)
                else
                    if _G.KAT_ESP then _G.KAT_ESP:Disconnect() end
                    uniEspFolder:ClearAllChildren()
                end
            end,
        })

        local hitboxSize = 2
        MainTab:CreateSlider({
            Name = "Hitbox Expander (Size)",
            Range = {2, 20},
            Increment = 1,
            Suffix = " Studs",
            CurrentValue = 2,
            Flag = "KAT_HitboxSize",
            Callback = function(Value)
                hitboxSize = Value
            end,
        })
        
        MainTab:CreateToggle({
            Name = "Enable Hitbox Expander",
            CurrentValue = false,
            Flag = "KAT_Hitbox",
            Callback = function(Value)
                if Value then
                    if _G.KAT_Hitbox then _G.KAT_Hitbox:Disconnect() end
                    _G.KAT_Hitbox = game:GetService("RunService").RenderStepped:Connect(function()
                        for _, v in pairs(game.Players:GetPlayers()) do
                            if v ~= Player and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                                pcall(function()
                                    v.Character.HumanoidRootPart.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
                                    v.Character.HumanoidRootPart.Transparency = 0.7
                                    v.Character.HumanoidRootPart.CanCollide = false
                                end)
                            end
                        end
                    end)
                else
                    if _G.KAT_Hitbox then _G.KAT_Hitbox:Disconnect() end
                    for _, v in pairs(game.Players:GetPlayers()) do
                        if v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                            pcall(function()
                                v.Character.HumanoidRootPart.Size = Vector3.new(2, 2, 1)
                                v.Character.HumanoidRootPart.Transparency = 1
                            end)
                        end
                    end
                end
            end,
        })
        
        local wallbangLoop
        MainTab:CreateToggle({
            Name = "Wallbang (Shoot & See Through Walls)",
            CurrentValue = false,
            Flag = "KAT_Wallbang",
            Callback = function(Value)
                if Value then
                    wallbangLoop = game:GetService("RunService").Stepped:Connect(function()
                        -- Attempt to find the map folder, or just iterate workspace
                        local mapFolder = workspace:FindFirstChild("Map") or workspace:FindFirstChild("CurrentMap") or workspace
                        for _, v in pairs(mapFolder:GetDescendants()) do
                            if v:IsA("BasePart") and not v.Parent:FindFirstChild("Humanoid") and v.Name ~= "Baseplate" and v.Name ~= "Floor" then
                                pcall(function() 
                                    v.CanQuery = false 
                                    v.Transparency = 0.5 -- Visual feedback so the user knows it works
                                end)
                            end
                        end
                    end)
                    Rayfield:Notify({Title = "Wallbang", Content = "Walls are now ghosted! You can shoot through them.", Duration = 3})
                else
                    if wallbangLoop then wallbangLoop:Disconnect() end
                    local mapFolder = workspace:FindFirstChild("Map") or workspace:FindFirstChild("CurrentMap") or workspace
                    for _, v in pairs(mapFolder:GetDescendants()) do
                        if v:IsA("BasePart") and not v.Parent:FindFirstChild("Humanoid") then
                            pcall(function() 
                                v.CanQuery = true 
                                if v.Transparency == 0.5 then v.Transparency = 0 end
                            end)
                        end
                    end
                end
            end,
        })

        local noReloadLoop
        MainTab:CreateToggle({
            Name = "No Reload & Rapid Fire",
            CurrentValue = false,
            Flag = "KAT_NoReload",
            Callback = function(Value)
                if Value then
                    noReloadLoop = game:GetService("RunService").Heartbeat:Connect(function()
                        local char = Player.Character
                        if not char then return end
                        
                        local function modWeapon(tool)
                            if not tool:IsA("Tool") then return end
                            for _, v in ipairs(tool:GetDescendants()) do
                                if v:IsA("ValueBase") then
                                    local name = string.lower(v.Name)
                                    if name == "reloadtime" or name == "firerate" or name == "cooldown" then
                                        v.Value = 0
                                    elseif name == "ammo" or name == "clip" or name == "maxammo" then
                                        v.Value = 999
                                    end
                                end
                            end
                        end
                        
                        for _, v in ipairs(char:GetChildren()) do modWeapon(v) end
                        if Player:FindFirstChild("Backpack") then
                            for _, v in ipairs(Player.Backpack:GetChildren()) do modWeapon(v) end
                        end
                        
                        pcall(function()
                            for _, v in ipairs(getgc(true)) do
                                if type(v) == "table" then
                                    if rawget(v, "ReloadTime") then rawset(v, "ReloadTime", 0) end
                                    if rawget(v, "FireRate") then rawset(v, "FireRate", 0) end
                                    if rawget(v, "Ammo") and type(rawget(v, "Ammo")) == "number" then rawset(v, "Ammo", 999) end
                                end
                            end
                        end)
                    end)
                else
                    if noReloadLoop then noReloadLoop:Disconnect() end
                end
            end,
        })
        
        local camLock = false
        MainTab:CreateToggle({
            Name = "Right-Click Camera Lock (Aimbot)",
            CurrentValue = false,
            Flag = "KAT_CamLock",
            Callback = function(Value)
                camLock = Value
                if Value then
                    if _G.KAT_CamLock then _G.KAT_CamLock:Disconnect() end
                    _G.KAT_CamLock = game:GetService("RunService").RenderStepped:Connect(function()
                        if game:GetService("UserInputService"):IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                            local closest, shortest = nil, math.huge
                            local mouse = Player:GetMouse()
                            for _, v in pairs(game.Players:GetPlayers()) do
                                if v ~= Player and v.Character and v.Character:FindFirstChild("HumanoidRootPart") and v.Character:FindFirstChild("Humanoid") and v.Character.Humanoid.Health > 0 then
                                    local pos, vis = workspace.CurrentCamera:WorldToViewportPoint(v.Character.HumanoidRootPart.Position)
                                    if vis then
                                        local dist = (Vector2.new(pos.X, pos.Y) - Vector2.new(mouse.X, mouse.Y)).Magnitude
                                        if dist < shortest then
                                            shortest, closest = dist, v
                                        end
                                    end
                                end
                            end
                            if closest and closest.Character and closest.Character:FindFirstChild("Head") then
                                workspace.CurrentCamera.CFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position, closest.Character.Head.Position)
                            end
                        end
                    end)
                else
                    if _G.KAT_CamLock then _G.KAT_CamLock:Disconnect() end
                end
            end,
        })

        -- Player Features
        PlayerTab:CreateSection("God Mode & Defenses")
        
        local godModeLoop
        PlayerTab:CreateToggle({
            Name = "KAT God Mode (Invincible)",
            CurrentValue = false,
            Flag = "KAT_GodMode",
            Callback = function(Value)
                if Value then
                    godModeLoop = game:GetService("RunService").Heartbeat:Connect(function()
                        if Player.Character then
                            pcall(function()
                                -- Removing hitboxes makes you immune to knives and guns in KAT
                                if Player.Character:FindFirstChild("Head") then
                                    Player.Character.Head:Destroy()
                                end
                                if Player.Character:FindFirstChild("Hitbox") then
                                    Player.Character.Hitbox:Destroy()
                                end
                            end)
                        end
                    end)
                    Rayfield:Notify({Title = "God Mode", Content = "You are now immune to most attacks! (Reset character to disable)", Duration = 4})
                else
                    if godModeLoop then godModeLoop:Disconnect() end
                end
            end,
        })

        PlayerTab:CreateSlider({
            Name = "Walk Speed",
            Range = {16, 200},
            Increment = 1,
            Suffix = " WS",
            CurrentValue = 16,
            Flag = "KAT_WS",
            Callback = function(Value)
                if Player.Character and Player.Character:FindFirstChildOfClass("Humanoid") then
                    Player.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = Value
                end
            end,
        })
        
        PlayerTab:CreateSlider({
            Name = "Jump Power",
            Range = {50, 200},
            Increment = 1,
            Suffix = " JP",
            CurrentValue = 50,
            Flag = "KAT_JP",
            Callback = function(Value)
                if Player.Character and Player.Character:FindFirstChildOfClass("Humanoid") then
                    Player.Character:FindFirstChildOfClass("Humanoid").JumpPower = Value
                end
            end,
        })

        local InfJump = false
        game:GetService("UserInputService").JumpRequest:Connect(function()
            if InfJump and Player.Character and Player.Character:FindFirstChildOfClass("Humanoid") then
                Player.Character:FindFirstChildOfClass("Humanoid"):ChangeState("Jumping")
            end
        end)
        PlayerTab:CreateToggle({
            Name = "Infinite Jump",
            CurrentValue = false,
            Flag = "KAT_InfJump",
            Callback = function(Value)
                InfJump = Value
            end,
        })
        
        local Noclip = false
        PlayerTab:CreateToggle({
            Name = "Noclip (Walk Through Walls)",
            CurrentValue = false,
            Flag = "KAT_Noclip",
            Callback = function(Value)
                Noclip = Value
                if Value then
                    if _G.KAT_Noclip then _G.KAT_Noclip:Disconnect() end
                    _G.KAT_Noclip = game:GetService("RunService").Stepped:Connect(function()
                        if Player.Character then
                            for _, v in pairs(Player.Character:GetDescendants()) do
                                if v:IsA("BasePart") then v.CanCollide = false end
                            end
                        end
                    end)
                else
                    if _G.KAT_Noclip then _G.KAT_Noclip:Disconnect() end
                end
            end,
        })

        Rayfield:LoadConfiguration()
        
    elseif game.PlaceId == 135648408848758 then
        -- [FPS] One Scope Hub
        local Window = Rayfield:CreateWindow({
            Name = "LumoHub Premium 🎯 | One Scope",
            LoadingTitle = "LumoHub Premium",
            LoadingSubtitle = "Injecting Sniper Scripts...",
            ConfigurationSaving = { Enabled = false },
            Discord = { Enabled = true, Invite = "qkCRXBeEpB", RememberJoins = true },
            KeySystem = false
        })

        local MainTab = Window:CreateTab("Combat ⚔️", 4483362458)
        local PlayerTab = Window:CreateTab("LocalPlayer 👤", 4483362458)
        
        -- One Scope Combat
        MainTab:CreateSection("Visuals")
        local osEspSettings = {
            Boxes = false,
            Tracers = false,
            Names = false
        }
        
        local osEspDrawings = {}
        
        local function clearOSEsp()
            for _, drawings in pairs(osEspDrawings) do
                if drawings.Box then drawings.Box:Remove() end
                if drawings.Tracer then drawings.Tracer:Remove() end
                if drawings.Name then drawings.Name:Remove() end
            end
            osEspDrawings = {}
        end
        
        game:GetService("RunService").RenderStepped:Connect(function()
            local Camera = workspace.CurrentCamera
            for _, v in pairs(game.Players:GetPlayers()) do
                if v ~= Player and v.Character and v.Character:FindFirstChild("HumanoidRootPart") and v.Character:FindFirstChild("Humanoid") and v.Character.Humanoid.Health > 0 then
                    local hrp = v.Character.HumanoidRootPart
                    local head = v.Character:FindFirstChild("Head")
                    local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                    
                    if not osEspDrawings[v] then
                        osEspDrawings[v] = {}
                        if Drawing then
                            pcall(function()
                                osEspDrawings[v].Box = Drawing.new("Square")
                                osEspDrawings[v].Box.Color = Color3.fromRGB(255, 0, 0)
                                osEspDrawings[v].Box.Thickness = 1
                                osEspDrawings[v].Box.Filled = false
                                osEspDrawings[v].Box.Transparency = 1
                                
                                osEspDrawings[v].Tracer = Drawing.new("Line")
                                osEspDrawings[v].Tracer.Color = Color3.fromRGB(255, 0, 0)
                                osEspDrawings[v].Tracer.Thickness = 1
                                osEspDrawings[v].Tracer.Transparency = 1
                                
                                osEspDrawings[v].Name = Drawing.new("Text")
                                osEspDrawings[v].Name.Color = Color3.fromRGB(255, 255, 255)
                                osEspDrawings[v].Name.Size = 16
                                osEspDrawings[v].Name.Center = true
                                osEspDrawings[v].Name.Outline = true
                            end)
                        end
                    end
                    
                    local drawings = osEspDrawings[v]
                    if drawings.Box then
                        if onScreen and head then
                            local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                            local legPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                            local height = math.abs(headPos.Y - legPos.Y)
                            local width = height / 2
                            
                            drawings.Box.Size = Vector2.new(width, height)
                            drawings.Box.Position = Vector2.new(pos.X - width / 2, headPos.Y)
                            drawings.Box.Visible = osEspSettings.Boxes
                            
                            drawings.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                            drawings.Tracer.To = Vector2.new(pos.X, pos.Y)
                            drawings.Tracer.Visible = osEspSettings.Tracers
                            
                            drawings.Name.Text = v.Name
                            drawings.Name.Position = Vector2.new(pos.X, headPos.Y - 20)
                            drawings.Name.Visible = osEspSettings.Names
                        else
                            drawings.Box.Visible = false
                            drawings.Tracer.Visible = false
                            drawings.Name.Visible = false
                        end
                    end
                elseif osEspDrawings[v] then
                    if osEspDrawings[v].Box then osEspDrawings[v].Box:Remove() end
                    if osEspDrawings[v].Tracer then osEspDrawings[v].Tracer:Remove() end
                    if osEspDrawings[v].Name then osEspDrawings[v].Name:Remove() end
                    osEspDrawings[v] = nil
                end
            end
        end)
        
        MainTab:CreateToggle({
            Name = "Player Boxes",
            CurrentValue = false,
            Flag = "OS_ESP_Boxes",
            Callback = function(Value)
                osEspSettings.Boxes = Value
            end,
        })
        
        MainTab:CreateToggle({
            Name = "Player Tracers",
            CurrentValue = false,
            Flag = "OS_ESP_Tracers",
            Callback = function(Value)
                osEspSettings.Tracers = Value
            end,
        })
        
        MainTab:CreateToggle({
            Name = "Player Names",
            CurrentValue = false,
            Flag = "OS_ESP_Names",
            Callback = function(Value)
                osEspSettings.Names = Value
            end,
        })
        local osFovCircle = nil
        if Drawing then
            pcall(function()
                osFovCircle = Drawing.new("Circle")
                osFovCircle.Visible = false
                osFovCircle.Color = Color3.fromRGB(255, 255, 255)
                osFovCircle.Thickness = 1
                osFovCircle.NumSides = 100
                osFovCircle.Radius = 150
                osFovCircle.Filled = false
            end)
        end
        
        game:GetService("RunService").RenderStepped:Connect(function()
            if osFovCircle then
                local mouse = game:GetService("Players").LocalPlayer:GetMouse()
                pcall(function() osFovCircle.Position = Vector2.new(mouse.X, mouse.Y + 36) end)
            end
        end)
        
        MainTab:CreateSection("Aimbot")
        local camLock = false
        MainTab:CreateToggle({
            Name = "Right-Click Camera Lock (Aimbot)",
            CurrentValue = false,
            Flag = "OS_CamLock",
            Callback = function(Value)
                camLock = Value
                if Value then
                    if _G.OS_CamLock then _G.OS_CamLock:Disconnect() end
                    _G.OS_CamLock = game:GetService("RunService").RenderStepped:Connect(function()
                        if game:GetService("UserInputService"):IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                            local closest, shortest = nil, math.huge
                            local mouse = Player:GetMouse()
                            for _, v in pairs(game.Players:GetPlayers()) do
                                if v ~= Player and v.Character and v.Character:FindFirstChild("HumanoidRootPart") and v.Character:FindFirstChild("Humanoid") and v.Character.Humanoid.Health > 0 then
                                    local pos, vis = workspace.CurrentCamera:WorldToViewportPoint(v.Character.HumanoidRootPart.Position)
                                    if vis then
                                        local dist = (Vector2.new(pos.X, pos.Y) - Vector2.new(mouse.X, mouse.Y)).Magnitude
                                        if dist < shortest then
                                            shortest, closest = dist, v
                                        end
                                    end
                                end
                            end
                            if closest and closest.Character and closest.Character:FindFirstChild("Head") then
                                pcall(function() workspace.CurrentCamera.CFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position, closest.Character.Head.Position) end)
                            end
                        end
                    end)
                else
                    if _G.OS_CamLock then _G.OS_CamLock:Disconnect() end
                end
            end,
        })
        
        local osSilentAimFOV = 150
        MainTab:CreateSlider({
            Name = "Silent Aim FOV",
            Range = {50, 600},
            Increment = 10,
            Suffix = " Radius",
            CurrentValue = 150,
            Flag = "OS_SilentAimFOV",
            Callback = function(Value)
                osSilentAimFOV = Value
                if osFovCircle then pcall(function() osFovCircle.Radius = Value end) end
            end,
        })
        
        local osSilentAimEnabled = false
        MainTab:CreateToggle({
            Name = "Silent Aim (Bullet Magnetism)",
            CurrentValue = false,
            Flag = "OS_SilentAim",
            Callback = function(Value)
                osSilentAimEnabled = Value
                if osFovCircle then pcall(function() osFovCircle.Visible = Value end) end
            end,
        })
        
        -- Hook for Silent Aim
        local osGm = getrawmetatable and getrawmetatable(game)
        local osSetreadonly = setreadonly or make_writeable
        if osGm and osSetreadonly and newcclosure and getnamecallmethod then
            pcall(function()
                osSetreadonly(osGm, false)
                local namecall = osGm.__namecall
                osGm.__namecall = newcclosure(function(self, ...)
                    local args = {...}
                    local method = getnamecallmethod()
                    
                    if osSilentAimEnabled and not checkcaller() and (method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist" or method == "FindPartOnRay" or method == "Raycast") then
                        local closestPart = nil
                        local shortestDistance = osSilentAimFOV
                        local mouse = Player:GetMouse()
                        local mousePos = Vector2.new(mouse.X, mouse.Y)
                        
                        for _, v in pairs(game.Players:GetPlayers()) do
                            if v ~= Player and v.Character and v.Character:FindFirstChild("Head") and v.Character:FindFirstChild("Humanoid") and v.Character.Humanoid.Health > 0 then
                                local pos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(v.Character.Head.Position)
                                if onScreen then
                                    local dist = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                                    if dist < shortestDistance then
                                        closestPart = v.Character.Head
                                        shortestDistance = dist
                                    end
                                end
                            end
                        end
                        
                        if closestPart then
                            local origin = args[1].Origin
                            if method == "Raycast" then
                                origin = args[1]
                                local direction = (closestPart.Position - origin).Unit * 1000
                                args[2] = direction
                            else
                                local direction = (closestPart.Position - origin).Unit * 1000
                                args[1] = Ray.new(origin, direction)
                            end
                            return namecall(self, unpack(args))
                        end
                    end
                    return namecall(self, ...)
                end)
                osSetreadonly(osGm, true)
            end)
        end
        
        -- One Scope Player
        PlayerTab:CreateSection("Movement")
        
        PlayerTab:CreateSlider({
            Name = "Walk Speed",
            Range = {16, 250},
            Increment = 1,
            Suffix = " WS",
            CurrentValue = 16,
            Flag = "OS_WS",
            Callback = function(Value)
                if Player.Character and Player.Character:FindFirstChildOfClass("Humanoid") then
                    Player.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = Value
                end
            end,
        })
        
        PlayerTab:CreateSlider({
            Name = "Jump Power",
            Range = {50, 200},
            Increment = 1,
            Suffix = " JP",
            CurrentValue = 50,
            Flag = "OS_JP",
            Callback = function(Value)
                if Player.Character and Player.Character:FindFirstChildOfClass("Humanoid") then
                    Player.Character:FindFirstChildOfClass("Humanoid").JumpPower = Value
                end
            end,
        })

        local InfJump = false
        game:GetService("UserInputService").JumpRequest:Connect(function()
            if InfJump and Player.Character and Player.Character:FindFirstChildOfClass("Humanoid") then
                Player.Character:FindFirstChildOfClass("Humanoid"):ChangeState("Jumping")
            end
        end)
        PlayerTab:CreateToggle({
            Name = "Infinite Jump",
            CurrentValue = false,
            Flag = "OS_InfJump",
            Callback = function(Value)
                InfJump = Value
            end,
        })

        local Noclip = false
        PlayerTab:CreateToggle({
            Name = "Noclip (Walk Through Walls)",
            CurrentValue = false,
            Flag = "OS_Noclip",
            Callback = function(Value)
                Noclip = Value
                if Value then
                    if _G.OS_Noclip then _G.OS_Noclip:Disconnect() end
                    _G.OS_Noclip = game:GetService("RunService").Stepped:Connect(function()
                        if Player.Character then
                            for _, v in pairs(Player.Character:GetDescendants()) do
                                if v:IsA("BasePart") then v.CanCollide = false end
                            end
                        end
                    end)
                else
                    if _G.OS_Noclip then _G.OS_Noclip:Disconnect() end
                end
            end,
        })
        
        CreateProtectionsTab(Window)
        
        local SettingsTab = Window:CreateTab("Settings ⚙️", 4483362458)
        SettingsTab:CreateSection("Menu Settings")
        SettingsTab:CreateButton({
            Name = "Unload Menu",
            Callback = function()
                clearOSEsp()
                if osFovCircle then pcall(function() osFovCircle:Remove() end) end
                pcall(function() Rayfield:Destroy() end)
            end,
        })

        Rayfield:LoadConfiguration()


    end
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
-- End of LoadLumoHub function

-- ──────────────────────────────────────────────────────────────
-- CUSTOM KEY AUTHENTICATION GUI
-- ──────────────────────────────────────────────────────────────
local function CheckSavedKey()
    local saved = ""
    pcall(function() saved = readfile("LumoHubKeyFile.txt") end)
    if saved and saved ~= "" then
        saved = string.gsub(saved, "%s+", "")
        local HWID = ""
        pcall(function() HWID = game:GetService("RbxAnalyticsService"):GetClientId() end)
        
        local success, result = pcall(function()
            return game:HttpGet("https://lumohub-bot.onrender.com/verify?key=" .. saved .. "&hwid=" .. HWID)
        end)
        
        if success and result == "VALID" then
            return saved
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
    local oldGui = game:GetService("CoreGui"):FindFirstChild("LumoHubAuth") or (Player:WaitForChild("PlayerGui") and Player.PlayerGui:FindFirstChild("LumoHubAuth"))
    if oldGui then oldGui:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "LumoHubAuth"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.DisplayOrder = 100 -- Ensure it covers Rayfield splash screen
    ScreenGui.IgnoreGuiInset = true -- Ensure it covers the whole screen
    
    local success = pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
    if not success then ScreenGui.Parent = Player:WaitForChild("PlayerGui") end

    -- Background frame to darken the blurred screen
    local BackgroundDim = Instance.new("Frame")
    BackgroundDim.Size = UDim2.new(1, 0, 1, 0)
    BackgroundDim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    BackgroundDim.BackgroundTransparency = 0.5
    BackgroundDim.BorderSizePixel = 0
    BackgroundDim.Parent = ScreenGui

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

        Status.TextColor3 = Color3.fromRGB(254, 204, 35)
        Status.Text = "Verifying HWID..."

        local HWID = ""
        pcall(function() HWID = game:GetService("RbxAnalyticsService"):GetClientId() end)
        
        local success, result = pcall(function()
            return game:HttpGet("https://lumohub-bot.onrender.com/verify?key=" .. entered .. "&hwid=" .. HWID)
        end)
        
        if success then
            if result == "VALID" then
                Status.TextColor3 = Color3.fromRGB(100, 255, 100)
                Status.Text = "Key Validated! Loading LumoHub..."
                pcall(function() writefile("LumoHubKeyFile.txt", entered) end)
                
                task.wait(0.5)
                MainFrame.Visible = false
                
                LoadLumoHub(entered, ScreenGui)
            elseif result == "INVALID_HWID" then
                Status.TextColor3 = Color3.fromRGB(255, 100, 100)
                Status.Text = "Key claimed by another device!"
            else
                Status.TextColor3 = Color3.fromRGB(255, 100, 100)
                Status.Text = "Invalid or Expired Key!"
            end
        else
            Status.TextColor3 = Color3.fromRGB(255, 100, 100)
            Status.Text = "Failed to connect to verification server."
        end
    end)
end
