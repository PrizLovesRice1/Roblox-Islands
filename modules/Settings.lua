--[[
    Settings.lua
    Settings tab - Performance, Player controls, Always Day/Night, Hotkeys
]]--

local game = game
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local LP = Players.LocalPlayer
local WS = game.Workspace

return function(Window, state)
    local Util = state.Util
    local Constants = state.Constants
    local SettingsTab = Window:CreateTab("Settings")
    
    SettingsTab:CreateSection("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    -- Performance Mode
    local performanceMode = false
    
    SettingsTab:CreateToggle({
        Name = "Performance Mode",
        CurrentValue = false,
        Callback = function(value)
            performanceMode = value
            if value then
                pcall(function()
                    local lighting = Lighting
                    if not getgenv().PerfCache then
                        getgenv().PerfCache = {
                            GlobalShadows = lighting.GlobalShadows,
                            Technology = lighting.Technology,
                            QualityLevel = settings().Rendering.QualityLevel
                        }
                    end
                    lighting.GlobalShadows = false
                    lighting.Technology = Enum.Technology.Compatibility
                    for _, effect in pairs(lighting:GetChildren()) do
                        if effect:IsA("BloomEffect") or effect:IsA("SunRaysEffect") or 
                           effect:IsA("DepthOfFieldEffect") or effect:IsA("ColorCorrectionEffect") or
                           effect:IsA("BlurEffect") then
                            if not getgenv().PerfCache[effect] then
                                getgenv().PerfCache[effect] = effect.Enabled
                            end
                            effect.Enabled = false
                        end
                    end
                    settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
                end)
                Util.updateNotification("Performance", "FPS BOOST: Shadows/Effects/Particles OFF!", 3)
            else
                pcall(function()
                    if getgenv().PerfCache then
                        local lighting = Lighting
                        lighting.GlobalShadows = getgenv().PerfCache.GlobalShadows
                        lighting.Technology = getgenv().PerfCache.Technology
                        settings().Rendering.QualityLevel = getgenv().PerfCache.QualityLevel
                        getgenv().PerfCache = nil
                    end
                end)
                Util.updateNotification("Performance", "Restored to normal!", 2)
            end
        end
    })
    
    -- Anti-AFK
    local antiAFKEnabled = true
    
    SettingsTab:CreateToggle({
        Name = "Anti-AFK (Auto-Enabled)",
        CurrentValue = true,
        Callback = function(value)
            antiAFKEnabled = value
            if value then
                Util.updateNotification("Anti-AFK", "Enabled - You won't be kicked!", 2)
            else
                Util.updateNotification("Anti-AFK", "Disabled - You may get kicked for AFK", 3)
            end
        end
    })
    
    SettingsTab:CreateSection("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    -- Player Actions
    local playerActionUsername = ""
    local playerActionMode = "Invite"
    
    SettingsTab:CreateDropdown({
        Name = "Action Type",
        Options = {"Invite", "Join"},
        CurrentOption = {"Invite"},
        MultipleOptions = false,
        Callback = function(option)
            playerActionMode = option[1]
        end
    })
    
    SettingsTab:CreateInput({
        Name = "Username",
        PlaceholderText = "Enter username",
        RemoveTextAfterFocusLost = false,
        Callback = function(text)
            playerActionUsername = text
        end
    })
    
    SettingsTab:CreateButton({
        Name = "Apply Action",
        Callback = function()
            if playerActionUsername == "" then 
                Util.updateNotification("Error", "Enter a username!", 3) 
                return 
            end
            
            if playerActionMode == "Invite" then
                task.spawn(function()
                    pcall(function()
                        local userId = Players:GetUserIdFromNameAsync(playerActionUsername)
                        if not userId then 
                            Util.updateNotification("Player Not Found", "", 3) 
                            return 
                        end
                        Util.updateNotification("Invited " .. playerActionUsername, "", 2)
                    end)
                end)
            end
        end
    })
    
    SettingsTab:CreateSection("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    -- Process & Radius Settings
    SettingsTab:CreateToggle({
        Name = "Process All Actions Simultaneously",
        CurrentValue = true,
        Callback = function(value)
            state.allAtOnceMode = value
        end
    })
    
    SettingsTab:CreateToggle({
        Name = "Use Radius Limit",
        CurrentValue = false,
        Callback = function(value)
            state.useRadiusLimit = value
            if value then
                state.createRadiusRing()
                Util.updateNotification("Radius Limit", "Enabled - " .. state.vendingRadius .. " studs", 2)
            else
                state.removeRadiusRing()
                Util.updateNotification("Radius Limit", "Disabled", 2)
            end
        end
    })
    
    SettingsTab:CreateSlider({
        Name = "Radius Distance",
        Range = {2, 100},
        Increment = 1,
        CurrentValue = 100,
        Callback = function(value) 
            state.vendingRadius = value
            if state.useRadiusLimit then
                if state.radiusConnection then 
                    state.radiusConnection:Disconnect() 
                    state.radiusConnection = nil 
                end
                if state.radiusRingPart then 
                    state.radiusRingPart:Destroy() 
                    state.radiusRingPart = nil 
                end
                state.createRadiusRing()
            end
        end
    })
    
    -- Always Day/Night
    local alwaysDayEnabled = false
    local alwaysNightEnabled = false
    
    SettingsTab:CreateToggle({
        Name = "Always Day",
        CurrentValue = false,
        Callback = function(value)
            alwaysDayEnabled = value
            if value then
                alwaysNightEnabled = false
                spawn(function()
                    while alwaysDayEnabled and task.wait() do
                        Lighting.ClockTime = 14
                    end
                end)
                Util.updateNotification("Always Day", "Enabled", 2)
            else
                Util.updateNotification("Always Day", "Disabled", 2)
            end
        end
    })
    
    SettingsTab:CreateToggle({
        Name = "Always Night",
        CurrentValue = false,
        Callback = function(value)
            alwaysNightEnabled = value
            if value then
                alwaysDayEnabled = false
                spawn(function()
                    while alwaysNightEnabled and task.wait() do
                        Lighting.ClockTime = 0
                    end
                end)
                Util.updateNotification("Always Night", "Enabled", 2)
            else
                Util.updateNotification("Always Night", "Disabled", 2)
            end
        end
    })
    
    SettingsTab:CreateSection("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    -- Player Movement & Controls
    local flying, flySpeed = false, 50
    local bodyVelocity, bodyGyro, flyConnection = nil, nil, nil
    
    local function startFly()
        local char = LP.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        local hrp = char.HumanoidRootPart
        
        bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.Parent = hrp
        
        bodyGyro = Instance.new("BodyGyro")
        bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        bodyGyro.P = 9e4
        bodyGyro.Parent = hrp
        
        if flyConnection then flyConnection:Disconnect() end
        flyConnection = RunService.Heartbeat:Connect(function()
            if not flying or not bodyVelocity or not bodyGyro then 
                if flyConnection then flyConnection:Disconnect() flyConnection = nil end
                return 
            end
            local cam = WS.CurrentCamera
            local moveDir = Vector3.new()
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0, 1, 0) end
            if bodyVelocity then bodyVelocity.Velocity = moveDir * flySpeed end
            if bodyGyro then bodyGyro.CFrame = cam.CFrame end
        end)
    end
    
    local function stopFly()
        flying = false
        if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
        if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
        if flyConnection then flyConnection:Disconnect() flyConnection = nil end
    end
    
    SettingsTab:CreateToggle({
        Name = "Fly",
        CurrentValue = false,
        Callback = function(value)
            flying = value
            if value then
                startFly()
                Util.updateNotification("Fly", "Enabled - WASD to move, Space/Shift up/down", 3)
            else
                stopFly()
                Util.updateNotification("Fly", "Disabled", 2)
            end
        end
    })
    
    SettingsTab:CreateSlider({
        Name = "Fly Speed",
        Range = {10, 200},
        Increment = 10,
        CurrentValue = 50,
        Callback = function(value)
            flySpeed = value
        end
    })
    
    -- Infinite Jump
    local infiniteJumpEnabled = false
    local infiniteJumpConnection = nil
    
    SettingsTab:CreateToggle({
        Name = "Infinite Jump",
        CurrentValue = false,
        Callback = function(value)
            infiniteJumpEnabled = value
            if value then
                infiniteJumpConnection = UserInputService.JumpRequest:Connect(function()
                    if infiniteJumpEnabled and LP.Character and LP.Character:FindFirstChild("Humanoid") then
                        LP.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                    end
                end)
                Util.updateNotification("Infinite Jump", "Enabled", 2)
            else
                if infiniteJumpConnection then
                    infiniteJumpConnection:Disconnect()
                    infiniteJumpConnection = nil
                end
                Util.updateNotification("Infinite Jump", "Disabled", 2)
            end
        end
    })
    
    -- Noclip
    local noclipEnabled = false
    local noclipConnection = nil
    
    SettingsTab:CreateToggle({
        Name = "Noclip",
        CurrentValue = false,
        Callback = function(value)
            noclipEnabled = value
            if value then
                if noclipConnection then noclipConnection:Disconnect() end
                noclipConnection = RunService.Stepped:Connect(function()
                    if noclipEnabled and LP.Character then
                        for _, part in pairs(LP.Character:GetDescendants()) do
                            if part:IsA("BasePart") then
                                part.CanCollide = false
                            end
                        end
                    end
                end)
                Util.updateNotification("Noclip", "Enabled - Walk through walls", 3)
            else
                if noclipConnection then noclipConnection:Disconnect() noclipConnection = nil end
                if LP.Character then
                    for _, part in pairs(LP.Character:GetDescendants()) do
                        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                            part.CanCollide = true
                        end
                    end
                end
                Util.updateNotification("Noclip", "Disabled", 2)
            end
        end
    })
    
    SettingsTab:CreateSection("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    -- Hotkeys Section
    SettingsTab:CreateSection("Hotkeys")
    
    SettingsTab:CreateInput({
        Name = "Withdraw All Hotkey",
        PlaceholderText = "Keybind...",
        RemoveTextAfterFocusLost = false,
        Callback = function(text)
            local newKey = Enum.KeyCode[text]
            if newKey then
                state.hotkeys.withdrawAll = newKey
                Util.updateNotification("Keybind", "Withdraw All: " .. text, 2)
            end
        end
    })
    
    SettingsTab:CreateInput({
        Name = "Deposit All Hotkey",
        PlaceholderText = "Keybind...",
        RemoveTextAfterFocusLost = false,
        Callback = function(text)
            local newKey = Enum.KeyCode[text]
            if newKey then
                state.hotkeys.depositAll = newKey
                Util.updateNotification("Keybind", "Deposit All: " .. text, 2)
            end
        end
    })
    
    SettingsTab:CreateInput({
        Name = "Select Random Hotkey",
        PlaceholderText = "Keybind...",
        RemoveTextAfterFocusLost = false,
        Callback = function(text)
            local newKey = Enum.KeyCode[text]
            if newKey then
                state.hotkeys.selectRandom = newKey
                Util.updateNotification("Keybind", "Select Random: " .. text, 2)
            end
        end
    })
end
