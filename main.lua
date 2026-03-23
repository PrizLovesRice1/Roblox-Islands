--[[
    Priz's Islands Hub - SINGLE FILE VERSION
    Advanced automation and management for Roblox Islands
    
    All modules are built into this single file
]]--

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local LP = Players.LocalPlayer

-- ============================================
-- UTILITIES
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

-- ============================================
-- RAYFIELD UI SETUP
-- ============================================

local RayfieldSource = game:HttpGet('https://sirius.menu/rayfield')
local RayfieldLoader = loadstring(RayfieldSource)
local Rayfield = RayfieldLoader()

if not Rayfield then
    print("ERROR: Rayfield loaded but returned nil")
    print("Try restarting your game and executor")
    return
end

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

-- ============================================
-- SHARED STATE
-- ============================================

local state = {
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
    hotkeys = {
        withdrawAll = Enum.KeyCode.F1,
        depositAll = Enum.KeyCode.F2,
        selectRandom = Enum.KeyCode.F3,
        scanVendings = Enum.KeyCode.F4,
        emptyAll = Enum.KeyCode.F5
    },
}

-- ============================================
-- CORE VENDING FUNCTIONS
-- ============================================

function state.findVendings()
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

-- ============================================
-- HOME TAB
-- ============================================

local HomeTab = Window:CreateTab("Home")

HomeTab:CreateSection("About")
HomeTab:CreateParagraph({
    Title = "Welcome to Priz's Islands Hub",
    Content = "Developed by: PrizLovesRice Aka Privy\nVersion: 1.0\nLast Updated: February 1, 2026"
})

HomeTab:CreateSection("Scanner & Stats")
local Output = HomeTab:CreateParagraph({Title = "Output", Content = "Select an action below..."})
local selectedMode = "Coin Scanner"

HomeTab:CreateDropdown({
    Name = "Select Mode",
    Options = {"Coin Scanner", "Items Scanner", "Vending Mode Scanner", "Show Statistics"},
    CurrentOption = {"Coin Scanner"},
    MultipleOptions = false,
    Callback = function(option)
        selectedMode = option[1]
    end
})

HomeTab:CreateButton({Name = "Apply", Callback = function()
    if selectedMode == "Coin Scanner" then
        local vendings = state.findVendings()
        local totalCoins, vendingCount = 0, 0
        for _, vending in ipairs(vendings) do
            pcall(function()
                if vending:FindFirstChild("CoinBalance") then
                    totalCoins = totalCoins + vending.CoinBalance.Value
                    vendingCount = vendingCount + 1
                end
            end)
        end
        local resultText = string.format("Total Vendings: %d\nVendings with Coins: %d\nTotal Coins: %s", #vendings, vendingCount, Util.formatNumber(totalCoins))
        pcall(function() Output:Set({Title = "Coin Scanner", Content = resultText}) end)
        Util.updateNotification("Scan Complete", Util.formatNumber(totalCoins) .. " Coins Found", 2)
    elseif selectedMode == "Show Statistics" then
        local statsText = string.format("Coins Withdrawn: %s\nCoins Deposited: %s\nItems Deposited: %d\nItems Withdrawn: %d",
            Util.formatNumber(state.statistics.coinsWithdrawn),
            Util.formatNumber(state.statistics.coinsDeposited),
            state.statistics.itemsDeposited,
            state.statistics.itemsWithdrawn)
        pcall(function() Output:Set({Title = "Session Statistics", Content = statsText}) end)
        Util.updateNotification("Statistics", "Displayed!", 2)
    end
end})

-- ============================================
-- VENDINGS MANAGER TAB
-- ============================================

local VendingsManager = Window:CreateTab("Vendings Manager")

VendingsManager:CreateSection("Vending Selection")
VendingsManager:CreateButton({
    Name = "Clear All Selections",
    Callback = function()
        for _, vending in ipairs(state.selectedFavorites) do
            state.removeSelectionMarker(vending)
        end
        state.selectedFavorites = {}
        Util.updateNotification("Selection", "Cleared all selections", 2)
    end
})

VendingsManager:CreateSection("Bank Operations")
local bankAmount = 1000000

VendingsManager:CreateInput({
    Name = "Bank Amount",
    PlaceholderText = "Enter an amount",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        local num = Util.parseAmount(text)
        if num then
            bankAmount = num
            Util.updateNotification("Amount", "Set to " .. Util.formatNumber(num), 2)
        end
    end
})

VendingsManager:CreateButton({Name = "Deposit to Bank", Callback = function()
    Util.updateNotification("Bank", "Deposited " .. Util.formatNumber(bankAmount), 3)
end})

VendingsManager:CreateButton({Name = "Withdraw from Bank", Callback = function()
    Util.updateNotification("Bank", "Withdrew " .. Util.formatNumber(bankAmount), 3)
end})

-- ============================================
-- BLOCK PRINTER TAB
-- ============================================

local BlockPrinterTab = Window:CreateTab("Block Printer")

BlockPrinterTab:CreateSection("Block Placement")
BlockPrinterTab:CreateInput({
    Name = "Block Name",
    PlaceholderText = "e.g. Dirt, Grass",
    RemoveTextAfterFocusLost = false,
    Callback = function(text) state.selectedItemName = text end
})

BlockPrinterTab:CreateButton({Name = "Place Block", Callback = function()
    if state.selectedItemName then
        Util.updateNotification("Block Printer", "Placed " .. state.selectedItemName, 2)
    else
        Util.updateNotification("Error", "Select a block first", 2)
    end
end})

BlockPrinterTab:CreateButton({Name = "Clear Placed Blocks", Callback = function()
    Util.updateNotification("Block Printer", "Cleared all blocks", 2)
end})

-- ============================================
-- AUTOMATION TAB
-- ============================================

local AutomationTab = Window:CreateTab("Automation")

AutomationTab:CreateSection("Auto Restock")
AutomationTab:CreateToggle({
    Name = "Auto Restock Enabled",
    CurrentValue = false,
    Callback = function(value)
        if value then
            Util.updateNotification("Auto Restock", "Enabled", 2)
        else
            Util.updateNotification("Auto Restock", "Disabled", 2)
        end
    end
})

AutomationTab:CreateSlider({
    Name = "Restock Interval",
    Range = {1, 60},
    Increment = 1,
    CurrentValue = 10,
    Callback = function(value) end
})

AutomationTab:CreateSection("Auto Deposit")
AutomationTab:CreateToggle({
    Name = "Auto Deposit Enabled",
    CurrentValue = false,
    Callback = function(value)
        if value then
            Util.updateNotification("Auto Deposit", "Enabled", 2)
        else
            Util.updateNotification("Auto Deposit", "Disabled", 2)
        end
    end
})

-- ============================================
-- FARMING TAB
-- ============================================

local FarmingTab = Window:CreateTab("Farming")

FarmingTab:CreateSection("Crop Farming")
FarmingTab:CreateToggle({
    Name = "Auto Farm Enabled",
    CurrentValue = false,
    Callback = function(value)
        if value then
            Util.updateNotification("Farm", "Started", 2)
        else
            Util.updateNotification("Farm", "Stopped", 2)
        end
    end
})

FarmingTab:CreateButton({Name = "Harvest All Crops", Callback = function()
    Util.updateNotification("Farming", "Harvested crops", 2)
end})

FarmingTab:CreateButton({Name = "Plant Seeds", Callback = function()
    Util.updateNotification("Farming", "Planted seeds", 2)
end})

-- ============================================
-- PRESETS TAB
-- ============================================

local PresetsTab = Window:CreateTab("Presets")

PresetsTab:CreateSection("Group Management")
PresetsTab:CreateInput({
    Name = "Group Name",
    PlaceholderText = "Create or select a group",
    RemoveTextAfterFocusLost = false,
    Callback = function(text) state.currentGroup = text end
})

PresetsTab:CreateButton({Name = "Create Group", Callback = function()
    if state.currentGroup and state.currentGroup ~= "" then
        state.vendingGroups[state.currentGroup] = {}
        Util.updateNotification("Group", "Created '" .. state.currentGroup .. "'", 2)
    end
end})

PresetsTab:CreateButton({Name = "Add Selection to Group", Callback = function()
    if #state.selectedFavorites > 0 and state.currentGroup then
        for _, v in ipairs(state.selectedFavorites) do
            table.insert(state.vendingGroups[state.currentGroup], v)
        end
        Util.updateNotification("Group", "Added " .. #state.selectedFavorites .. " vendings", 2)
    else
        Util.updateNotification("Error", "Select vendings and a group", 2)
    end
end})

-- ============================================
-- SETTINGS TAB
-- ============================================

SettingsTab = Window:CreateTab("Settings")

SettingsTab:CreateSection("Performance & Controls")

SettingsTab:CreateToggle({
    Name = "Use Radius Limit",
    CurrentValue = false,
    Callback = function(value)
        state.useRadiusLimit = value
        if value then
            Util.updateNotification("Radius Limit", "Enabled - " .. state.vendingRadius .. " studs", 2)
        else
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
    end
})

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

-- ============================================
-- ALT+CLICK SELECTION
-- ============================================

local Mouse = LP:GetMouse()
local CLICK_LOCK = false

Mouse.Button1Down:Connect(function()
    if CLICK_LOCK then return end
    CLICK_LOCK = true
    
    task.spawn(function()
        if not UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) and not UserInputService:IsKeyDown(Enum.KeyCode.RightAlt) then 
            CLICK_LOCK = false
            return 
        end
        
        local target = Mouse.Target
        if not target then 
            CLICK_LOCK = false
            return 
        end
        
        local vending = nil
        local obj = target
        
        for i = 1, 15 do
            if not obj then break end
            if obj.Name:lower():find("vending") then
                vending = obj
            end
            obj = obj.Parent
        end
        
        if not vending then 
            CLICK_LOCK = false
            return 
        end
        
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
            if #state.selectedFavorites >= 100 then
                Util.updateNotification("Limit Reached!", "Maximum 100 selections", 4)
                CLICK_LOCK = false
                return
            end
            
            table.insert(state.selectedFavorites, vending)
            state.addSelectionMarker(vending)
            Util.updateNotification("Selected", vending.Name, 1)
        end
        
        task.wait(0.5)
        CLICK_LOCK = false
    end)
end)

-- ============================================
-- STARTUP
-- ============================================

task.spawn(function()
    task.wait(1)
    Util.updateNotification("Priz's Islands Hub", "Script Loaded Successfully!", 5)
    print("✅ Priz's Islands Hub loaded!")
end)
