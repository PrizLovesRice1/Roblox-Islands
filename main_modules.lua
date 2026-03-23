--[[
    Priz's Islands Hub - Main Entry Point
    Advanced automation and management for Roblox Islands
    
    RUN THIS FILE ONLY - All modules will be loaded automatically
]]--

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LP = Players.LocalPlayer

-- ============================================
-- INLINE UTILITIES (No require needed)
-- ============================================

local Util = {}

function Util.formatNumber(num)
    if num >= 1000000000 then
        return string.format("%.2fB", num / 1000000000)
    elseif num >= 1000000 then
        return string.format("%.2fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.2fK", num / 1000)
    else
        return tostring(num)
    end
end

function Util.parseAmount(text)
    if not text or text == "" then return nil end
    local num = tonumber(text)
    if num then return num end
    text = text:upper():gsub("%s+", "")
    local numPart, suffix = text:match("^([%d%.]+)([KMB])$")
    if not numPart then return nil end
    num = tonumber(numPart)
    if not num then return nil end
    if suffix == "K" then return math.floor(num * 1000)
    elseif suffix == "M" then return math.floor(num * 1000000)
    elseif suffix == "B" then return math.floor(num * 1000000000)
    end
    return nil
end

function Util.getDisplayName(obj)
    if not obj then return "Unknown" end
    local displayNameValue = obj:FindFirstChild("DisplayName")
    if displayNameValue and displayNameValue:IsA("StringValue") then
        return displayNameValue.Value
    end
    return obj.Name
end

function Util.IsTaken(Position)
    for _,v in next, WS.Islands:GetDescendants() do
        if v:IsA("BasePart") and v.Name ~= "Collision" then
            if (v.Position - Position).magnitude <= 2 then
                return true
            end
        end
    end
end

local activeNotifications = {}
local notificationSpacing = 45

function Util.updateNotification(title, content, duration)
    task.spawn(function()
        pcall(function()
            local playerGui = LP:WaitForChild("PlayerGui")
            local screenGui = Instance.new("ScreenGui")
            screenGui.ResetOnSpawn = false
            screenGui.Parent = playerGui
            local frame = Instance.new("Frame")
            frame.Parent = screenGui
            frame.AnchorPoint = Vector2.new(1, 0.5)
            if title == "Priz's Islands Hub" then
                frame.Size = UDim2.fromOffset(500, 150)
            else
                frame.Size = UDim2.fromOffset(300, 40)
            end
            frame.BackgroundTransparency = 1
            local TextLabel = Instance.new("TextLabel")
            TextLabel.Parent = frame
            TextLabel.Size = UDim2.fromScale(1, 1)
            TextLabel.BackgroundTransparency = 1
            TextLabel.RichText = true
            TextLabel.TextWrapped = true
            TextLabel.TextScaled = true
            TextLabel.Text = title .. ": " .. content
            TextLabel.Font = Enum.Font.FredokaOne
            TextLabel.TextXAlignment = Enum.TextXAlignment.Left
            TextLabel.TextYAlignment = Enum.TextYAlignment.Center
            TextLabel.TextColor3 = Color3.fromRGB(120, 180, 255)
            TextLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
            TextLabel.TextStrokeTransparency = 0.5
            TextLabel.TextTransparency = 1
            table.insert(activeNotifications, screenGui)
            local yOffset = 0.93 - ((#activeNotifications - 1) * (notificationSpacing / 1080))
            frame.Position = UDim2.new(0.98, 0, yOffset, 0)
            for i = 1, 10 do
                task.wait(0.02)
                TextLabel.TextTransparency = 1 - (i / 10)
            end
            task.wait(duration or 3)
            for i = 1, 10 do
                task.wait(0.04)
                TextLabel.TextTransparency = i / 10
            end
            task.wait(0.1)
            for i, notif in ipairs(activeNotifications) do
                if notif == screenGui then
                    table.remove(activeNotifications, i)
                    break
                end
            end
            screenGui:Destroy()
        end)
    end)
end

local Constants = {
    MAX_SELECTIONS = 100,
    MAX_HISTORY = 50,
    MAX_VENDING_BALANCE = 5000000000,
    VENDING_LIMIT = 5000000000,
    DEFAULT_HOTKEYS = {
        withdrawAll = Enum.KeyCode.F1,
        depositAll = Enum.KeyCode.F2,
        selectRandom = Enum.KeyCode.F3,
        scanVendings = Enum.KeyCode.F4,
        emptyAll = Enum.KeyCode.F5
    },
    DEFAULT_SETTINGS = {
        theme = "Amethyst",
        radius = 100,
        useRadius = false,
        processMode = true
    }
}

-- Rayfield UI Library
local RayfieldSource = game:HttpGet('https://sirius.menu/rayfield')
local RayfieldLoader = loadstring(RayfieldSource)
local Rayfield = RayfieldLoader()

if not Rayfield then
    print("ERROR: Rayfield loaded but returned nil")
    print("Try restarting your game and executor")
    return
end

-- Create main window
local Window = Rayfield:CreateWindow({
    Name = "Priz's Islands Hub",
    LoadingTitle = "Priz's Islands Hub", 
    LoadingSubtitle = "by Priz",
    Theme = "Amethyst",
    Resizable = false,
    ConfigurationSaving = {Enabled = false},
    Discord = {Enabled = false},
    KeySystem = false
})

-- Shared state between modules
local state = {
    -- Network
    networkReady = Network.isReady(),
    checkNetwork = Network.checkNetwork,
    
    -- Vending management
    selectedVending = nil,
    selectedItemName = nil,
    selectedFavorites = {},
    favoritesSelectionMode = false,
    allAtOnceMode = true,
    vendingRadius = 100,
    useRadiusLimit = false,
    radiusConnection = nil,
    radiusRingPart = nil,
    currentGroup = "Default",
    vendingGroups = {["Default"] = {}},
    favoriteVendings = {},
    itemNameMap = {},
    itemOptions = {},
    
    -- Statistics
    statistics = {
        coinsWithdrawn = 0,
        coinsDeposited = 0,
        itemsDeposited = 0,
        itemsWithdrawn = 0,
        vendingsModified = 0,
        bankDeposits = 0,
        bankWithdrawals = 0
    },
    transactionHistory = {},
    
    -- Hotkeys
    hotkeys = Constants.DEFAULT_HOTKEYS,
    userSettings = Constants.DEFAULT_SETTINGS,
    
    -- Functions to be implemented
    findVendings = function() return {} end,
    getVendingInfo = function() return nil, 0, 0 end,
    addSelectionMarker = function() end,
    removeSelectionMarker = function() end,
    createRadiusRing = function() end,
    removeRadiusRing = function() end,
    saveFavorites = function() end,
    loadFavorites = function() end,
}

-- ============================================
-- CORE VENDING FUNCTIONS
-- ============================================

function state.findVendings()
    if state.currentGroup ~= "Default" and state.currentGroup ~= "None" and state.vendingGroups[state.currentGroup] then
        local groupVendings, allVendings = {}, {}
        local islands = WS:FindFirstChild("Islands")
        if islands then
            for _, island in pairs(islands:GetChildren()) do
                local blocks = island:FindFirstChild("Blocks")
                if blocks then
                    for _, obj in pairs(blocks:GetChildren()) do
                        if obj.Name:find("vending") or obj.Name:find("Vending") then
                            table.insert(allVendings, obj)
                        end
                    end
                end
            end
        end
        local group = state.vendingGroups[state.currentGroup]
        for _, vendingData in ipairs(group) do
            local savedPos = Vector3.new(vendingData.x, vendingData.y, vendingData.z)
            for _, vending in ipairs(allVendings) do
                if (vending.Position - savedPos).Magnitude < 1 then
                    table.insert(groupVendings, vending)
                    break
                end
            end
        end
        return groupVendings
    end
    
    local vendings = {}
    local islands = WS:FindFirstChild("Islands")
    if islands then
        for _, island in pairs(islands:GetChildren()) do
            local blocks = island:FindFirstChild("Blocks")
            if blocks then
                for _, obj in pairs(blocks:GetChildren()) do
                    if obj.Name:find("vending") or obj.Name:find("Vending") then
                        if state.useRadiusLimit then
                            if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
                                local distance = (obj.Position - LP.Character.HumanoidRootPart.Position).Magnitude
                                if distance <= state.vendingRadius then
                                    table.insert(vendings, obj)
                                end
                            end
                        else
                            table.insert(vendings, obj)
                        end
                    end
                end
            end
        end
    end
    return vendings
end

function state.getVendingInfo(vending)
    local itemName, itemCount, coinAmount = nil, 0, 0
    pcall(function()
        local sellingContents = vending:FindFirstChild("SellingContents")
        if sellingContents then
            local firstItem = sellingContents:GetChildren()[1]
            if firstItem then
                itemName = Util.getDisplayName(firstItem)
                itemCount = firstItem:FindFirstChild("Amount") and firstItem.Amount.Value or 1
            end
        end
        local coinBalance = vending:FindFirstChild("CoinBalance")
        if coinBalance then coinAmount = coinBalance.Value end
    end)
    return itemName, itemCount, coinAmount
end

local function clearAllMarkers(vending)
    pcall(function()
        for _, descendant in pairs(vending:GetDescendants()) do
            if descendant.Name == "SelectionMarker" then
                descendant:Destroy()
            end
        end
    end)
    pcall(function()
        for _, child in pairs(vending:GetChildren()) do
            if child.Name == "SelectionMarker" then
                child:Destroy()
            end
        end
    end)
    pcall(function()
        for _, obj in pairs(WS:GetChildren()) do
            if obj.Name == "SelectionMarker" and obj.Adornee == vending then
                obj:Destroy()
            end
        end
    end)
end

function state.addSelectionMarker(vending)
    clearAllMarkers(vending)
    task.wait(0.05)
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "SelectionMarker"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 40, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 6, 0)
    billboard.Adornee = vending
    billboard.Parent = WS
    
    local star = Instance.new("TextLabel")
    star.BackgroundTransparency = 1
    star.Size = UDim2.new(1, 0, 1, 0)
    star.Text = "⭐"
    star.TextColor3 = Color3.fromRGB(255, 215, 0)
    star.TextStrokeTransparency = 0
    star.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    star.TextScaled = true
    star.Font = Enum.Font.SourceSansBold
    star.Parent = billboard
end

function state.removeSelectionMarker(vending)
    clearAllMarkers(vending)
end

function state.saveFavorites()
    local favData = {}
    for _, vending in pairs(state.favoriteVendings) do
        table.insert(favData, {x = vending.Position.X, y = vending.Position.Y, z = vending.Position.Z, name = vending.Name})
    end
    writefile("VendingManager_Favorites.json", HttpService:JSONEncode(favData))
end

function state.loadFavorites()
    if isfile("VendingManager_Favorites.json") then
        local success, data = pcall(function() return HttpService:JSONDecode(readfile("VendingManager_Favorites.json")) end)
        if success and data then
            local allVendings = {}
            local islands = WS:FindFirstChild("Islands")
            if islands then
                for _, island in pairs(islands:GetChildren()) do
                    local blocks = island:FindFirstChild("Blocks")
                    if blocks then
                        for _, obj in pairs(blocks:GetChildren()) do
                            if obj.Name:find("vending") or obj.Name:find("Vending") then
                                table.insert(allVendings, obj)
                            end
                        end
                    end
                end
            end
            state.favoriteVendings = {}
            for _, favData in ipairs(data) do
                local savedPos = Vector3.new(favData.x, favData.y, favData.z)
                for _, vending in ipairs(allVendings) do
                    if (vending.Position - savedPos).Magnitude < 1 then
                        table.insert(state.favoriteVendings, vending)
                        break
                    end
                end
            end
        end
    end
end

function state.createRadiusRing()
    if state.radiusRingPart then state.radiusRingPart:Destroy() state.radiusRingPart = nil end
    if state.radiusConnection then state.radiusConnection:Disconnect() state.radiusConnection = nil end
    if not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local adjustedRadius = state.vendingRadius * 0.8
    local folder = Instance.new("Folder")
    folder.Name = "RadiusRing"
    folder.Parent = WS
    state.radiusRingPart = folder
    
    local parts = {}
    for i = 1, 60 do
        local angle = (i / 60) * math.pi * 2
        local nextAngle = ((i + 1) / 60) * math.pi * 2
        local x1, z1 = math.cos(angle) * adjustedRadius, math.sin(angle) * adjustedRadius
        local x2, z2 = math.cos(nextAngle) * adjustedRadius, math.sin(nextAngle) * adjustedRadius
        local pos1, pos2 = Vector3.new(x1, 0, z1), Vector3.new(x2, 0, z2)
        local midpoint = (pos1 + pos2) / 2
        local length = (pos2 - pos1).Magnitude * 1.05
        local lookVector = (pos2 - pos1).Unit
        
        local part = Instance.new("Part")
        part.Size = Vector3.new(0.15, 0.15, length)
        part.Anchored = true
        part.CanCollide = false
        part.Material = Enum.Material.Neon
        part.Color = Color3.fromRGB(138, 43, 226)
        part.Transparency = 0.3
        part.CFrame = CFrame.fromMatrix(midpoint, Vector3.new(0, 1, 0):Cross(lookVector), lookVector:Cross(Vector3.new(0, 1, 0):Cross(lookVector)), -lookVector)
        part.Parent = folder
        
        table.insert(parts, {part = part, offset = midpoint})
    end
    
    state.radiusConnection = game:GetService("RunService").Heartbeat:Connect(function()
        if not state.radiusRingPart or not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then return end
        
        local currentPos = LP.Character.HumanoidRootPart.Position
        for _, data in ipairs(parts) do
            if data.part.Parent then
                data.part.Position = currentPos + data.offset
            end
        end
        
        task.wait(0.1)
    end)
end

function state.removeRadiusRing()
    if state.radiusConnection then state.radiusConnection:Disconnect() state.radiusConnection = nil end
    if state.radiusRingPart then state.radiusRingPart:Destroy() state.radiusRingPart = nil end
end

-- Load groups
if isfile and readfile and isfile("VendingManager_Groups.json") then
    local success, groupsData = pcall(function() return HttpService:JSONDecode(readfile("VendingManager_Groups.json")) end)
    if success and groupsData then
        for groupName, vendingList in pairs(groupsData) do
            state.vendingGroups[groupName] = vendingList
        end
    end
end

-- ============================================
-- ALT+CLICK VENDING SELECTION
-- ============================================

local Mouse = LP:GetMouse()

Mouse.Button1Down:Connect(function()
    if not UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) and not UserInputService:IsKeyDown(Enum.KeyCode.RightAlt) then 
        return 
    end
    
    local target = Mouse.Target
    if not target then return end
    
    local vending = nil
    local obj = target
    
    for i = 1, 15 do
        if not obj then break end
        if obj.Name:lower():find("vending") then
            vending = obj
        end
        obj = obj.Parent
    end
    
    if not vending then return end
    
    while vending.Parent and vending.Parent.Name:lower():find("vending") do
        vending = vending.Parent
    end
    
    local isSelected = false
    local selectedIndex = nil
    
    for i, v in ipairs(state.selectedFavorites) do
        if v == vending then
            isSelected = true
            selectedIndex = i
            break
        end
    end
    
    if isSelected then
        table.remove(state.selectedFavorites, selectedIndex)
        state.removeSelectionMarker(vending)
        Util.updateNotification("Deselected", vending.Name, 1)
    else
        if #state.selectedFavorites >= Constants.MAX_SELECTIONS then
            Util.updateNotification("Limit Reached!", "Maximum " .. Constants.MAX_SELECTIONS .. " selections", 4)
            return
        end
        
        table.insert(state.selectedFavorites, vending)
        state.addSelectionMarker(vending)
        Util.updateNotification("Selected", vending.Name .. " (" .. #state.selectedFavorites .. "/" .. Constants.MAX_SELECTIONS .. ")", 1)
    end
end)

-- ============================================
-- LOAD ALL MODULES
-- ============================================

-- Pass utilities and constants to modules
state.Util = Util
state.Constants = Constants

local Home = loadstring(game:HttpGet('https://raw.githubusercontent.com/PrizLovesRice1/Roblox-Islands/main/modules/Home.lua'))()
local VendingsManager = loadstring(game:HttpGet('https://raw.githubusercontent.com/PrizLovesRice1/Roblox-Islands/main/modules/VendingsManager.lua'))()
local BlockPrinter = loadstring(game:HttpGet('https://raw.githubusercontent.com/PrizLovesRice1/Roblox-Islands/main/modules/BlockPrinter.lua'))()
local Automation = loadstring(game:HttpGet('https://raw.githubusercontent.com/PrizLovesRice1/Roblox-Islands/main/modules/Automation.lua'))()
local Farming = loadstring(game:HttpGet('https://raw.githubusercontent.com/PrizLovesRice1/Roblox-Islands/main/modules/Farming.lua'))()
local Settings = loadstring(game:HttpGet('https://raw.githubusercontent.com/PrizLovesRice1/Roblox-Islands/main/modules/Settings.lua'))()
local Presets = loadstring(game:HttpGet('https://raw.githubusercontent.com/PrizLovesRice1/Roblox-Islands/main/modules/Presets.lua'))()

local modules = {Home, VendingsManager, BlockPrinter, Automation, Farming, Settings, Presets}

for _, moduleFunc in ipairs(modules) do
    task.spawn(function()
        pcall(function()
            moduleFunc(Window, state)
        end)
    end)
end

-- ============================================
-- STARTUP MESSAGE
-- ============================================

task.spawn(function()
    task.wait(1)
    local islandCode = "Unknown"
    pcall(function()
        if LP:FindFirstChild("JoinCode") then
            islandCode = LP.JoinCode.Value
        end
    end)
    
    Rayfield:Notify({
        Title = "Welcome " .. LP.Name .. "!",
        Content = "Username: " .. LP.Name .. "\nDisplay: " .. LP.DisplayName .. "\nUser ID: " .. LP.UserId .. "\nAge: " .. LP.AccountAge .. " days\nIsland: " .. islandCode,
        Duration = 8,
        Image = 4483362458,
    })
    
    Util.updateNotification("Priz's Islands Hub", "Script Loaded Successfully!", 5)
end)

print("✅ Priz's Islands Hub loaded successfully!")
print("Discord: discord.gg/NuUzrrNaJz")
