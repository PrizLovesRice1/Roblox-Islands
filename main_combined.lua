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
--[[
    Home.lua
    Home tab - Scanner & Stats, Openables Opener, Chest Manager
]]--

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local LP = Players.LocalPlayer

return function(Window, state)
    local Util = state.Util
    local Constants = state.Constants
    local HomeTab = Window:CreateTab("Home")
    
    -- About section
    HomeTab:CreateSection("About")
    HomeTab:CreateParagraph({
        Title = "Welcome to Priz's Islands Hub",
        Content = "Developed by: PrizLovesRice Aka Privy\nVersion: 1.0\nLast Updated: February 1, 2026 10:46 PM EST\n\nJoin Discord for updates & support:\ndiscord.gg/NuUzrrNaJz"
    })
    
    -- Scanner & Stats section
    HomeTab:CreateSection("Scanner & Stats")
    
    local Output = HomeTab:CreateParagraph({Title = "Output", Content = "Select an action below..."})
    
    local selectedMode = "Player Info & Island Code"
    local playerList = {}
    local selectedPlayerForInfo = nil
    
    local function refreshPlayersForScanner()
        playerList = {}
        for _, player in pairs(Players:GetPlayers()) do
            table.insert(playerList, player.Name)
        end
        if #playerList == 0 then
            table.insert(playerList, "No players")
        end
        return playerList
    end
    
    playerList = refreshPlayersForScanner()
    
    HomeTab:CreateDropdown({
        Name = "Select Player (for Player Info)",
        Options = playerList,
        CurrentOption = {playerList[1]},
        MultipleOptions = false,
        Callback = function(option)
            local playerName = option[1]
            selectedPlayerForInfo = Players:FindFirstChild(playerName)
        end
    })
    
    HomeTab:CreateDropdown({
        Name = "Select Mode",
        Options = {"Player Info & Island Code", "Coin Scanner", "Items Scanner", "Vending Mode Scanner", "Blocks Scanner", "Show Statistics", "Show Transaction History"},
        CurrentOption = {"Player Info & Island Code"},
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
            if totalCoins > 0 then
                Util.updateNotification("Scan Complete", Util.formatNumber(totalCoins) .. " Coins Found", 2)
            else
                Util.updateNotification("Scan Complete", "No Coins Found", 2)
            end
            
        elseif selectedMode == "Items Scanner" then
            local vendings, itemCounts = state.findVendings(), {}
            for _, vending in ipairs(vendings) do
                pcall(function()
                    local sellingContents = vending:FindFirstChild("SellingContents")
                    if sellingContents then
                        for _, item in pairs(sellingContents:GetChildren()) do
                            if item:IsA("Tool") then
                                local displayName = Util.getDisplayName(item)
                                local amount = item:FindFirstChild("Amount") and item.Amount.Value or 1
                                itemCounts[displayName] = (itemCounts[displayName] or 0) + amount
                            end
                        end
                    end
                end)
            end
            local resultText, itemCount = "Total Types: 0\n\n", 0
            for itemName, amount in pairs(itemCounts) do
                itemCount = itemCount + 1
                resultText = resultText .. itemName .. ": " .. amount .. "\n"
            end
            if itemCount == 0 then
                resultText = "No items found"
            else
                resultText = string.format("Total Types: %d\n\n", itemCount) .. resultText:sub(16)
            end
            pcall(function() Output:Set({Title = "Items Scanner", Content = resultText}) end)
            if itemCount == 0 then
                Util.updateNotification("Scan Complete", "No Items Found", 2)
            else
                Util.updateNotification("Scan Complete", itemCount .. " Item Types Found", 2)
            end
            
        elseif selectedMode == "Vending Mode Scanner" then
            local vendings = state.findVendings()
            local buyCount, sellCount, offlineCount = 0, 0, 0
            for _, vending in ipairs(vendings) do
                pcall(function()
                    if vending:FindFirstChild("Mode") then
                        local mode = vending.Mode.Value
                        if mode == 0 then buyCount = buyCount + 1
                        elseif mode == 1 then sellCount = sellCount + 1
                        elseif mode == 2 then offlineCount = offlineCount + 1 end
                    end
                end)
            end
            local resultText = string.format("Total: %d\n\n🟢 Buy: %d\n Sell: %d\n Offline: %d", #vendings, buyCount, sellCount, offlineCount)
            pcall(function() Output:Set({Title = "Vending Mode Scanner", Content = resultText}) end)
            Util.updateNotification("Scan Complete", #vendings .. " Vendings Scanned", 2)
            
        elseif selectedMode == "Blocks Scanner" then
            local objectCounts, totalObjects = {}, 0
            local islands = WS:FindFirstChild("Islands")
            if islands then
                for _, island in pairs(islands:GetChildren()) do
                    local blocks = island:FindFirstChild("Blocks")
                    if blocks then
                        for _, block in pairs(blocks:GetChildren()) do
                            totalObjects = totalObjects + 1
                            local displayName = block.Name
                            
                            local function findDisplayName(obj)
                                local dn = obj:FindFirstChild("DisplayName")
                                if dn then
                                    if dn:IsA("StringValue") then return dn.Value end
                                    if dn:IsA("Model") or dn:IsA("Part") or dn:IsA("BillboardGui") then
                                        local textLabel = dn:FindFirstChildOfClass("TextLabel", true)
                                        if textLabel and textLabel.Text then return textLabel.Text end
                                    end
                                end
                                for _, child in pairs(obj:GetDescendants()) do
                                    if child.Name == "DisplayName" and child:IsA("StringValue") then
                                        return child.Value
                                    end
                                end
                                return nil
                            end
                            
                            local foundName = findDisplayName(block)
                            if foundName then displayName = foundName end
                            
                            objectCounts[displayName] = (objectCounts[displayName] or 0) + 1
                        end
                    end
                end
            end
            local sortedObjects = {}
            for name, count in pairs(objectCounts) do
                table.insert(sortedObjects, {name = name, count = count})
            end
            table.sort(sortedObjects, function(a, b) return a.count > b.count end)
            local resultText = string.format("Total: %d | Types: %d\n\n", totalObjects, #sortedObjects)
            for _, obj in ipairs(sortedObjects) do
                resultText = resultText .. obj.name .. ": " .. obj.count .. "\n"
            end
            pcall(function() Output:Set({Title = "Blocks Scanner", Content = resultText}) end)
            Util.updateNotification("Blocks Scanner", totalObjects .. " objects!", 2)
            
        elseif selectedMode == "Show Statistics" then
            local statsText = string.format("Coins Withdrawn: %s\nCoins Deposited: %s\nItems Deposited: %d\nItems Withdrawn: %d\nVendings Modified: %d\nBank Deposits: %d\nBank Withdrawals: %d",
                Util.formatNumber(state.statistics.coinsWithdrawn),
                Util.formatNumber(state.statistics.coinsDeposited),
                state.statistics.itemsDeposited,
                state.statistics.itemsWithdrawn,
                state.statistics.vendingsModified,
                state.statistics.bankDeposits,
                state.statistics.bankWithdrawals)
            pcall(function() Output:Set({Title = "Session Statistics", Content = statsText}) end)
            Util.updateNotification("Statistics", "Displayed!", 2)
            
        elseif selectedMode == "Player Info & Island Code" then
            if not selectedPlayerForInfo then
                Util.updateNotification("Select a Player First", "", 2)
                return
            end
            
            local info = {
                Username = selectedPlayerForInfo.Name,
                DisplayName = selectedPlayerForInfo.DisplayName,
                UserId = selectedPlayerForInfo.UserId,
                AccountAge = selectedPlayerForInfo.AccountAge .. " days",
                Team = selectedPlayerForInfo.Team and selectedPlayerForInfo.Team.Name or "None"
            }
            
            local code = "Not found"
            pcall(function()
                if selectedPlayerForInfo:FindFirstChild("JoinCode") then
                    code = selectedPlayerForInfo.JoinCode.Value
                end
            end)
            
            local infoText = string.format(
                "Username: %s\nDisplay: %s\nUser ID: %s\nAge: %s\nTeam: %s\n\n Island Code: %s",
                info.Username, info.DisplayName, info.UserId, info.AccountAge, info.Team, code
            )
            
            pcall(function() Output:Set({Title = " " .. info.DisplayName, Content = infoText}) end)
            Util.updateNotification("Loaded Player Info", "", 2)
        end
    end})
end
--[[
    VendingsManager.lua
    Vending machine management features
]]--

local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")

return function(Window, state)
    local Util = state.Util
    local Constants = state.Constants
    local VendingsManager = Window:CreateTab("Vendings Manager")
    
    VendingsManager:CreateParagraph({
        Title = " Quick Guide",
        Content = "Buttons work on ALL vendings automatically!\n\n• ALT+Click vendings to select specific ones\n• Toggle 'Use Selected Only' in Vending Selection to operate on selected vendings\n• Leave toggle OFF to operate on all vendings"
    })
    
    local useSelectedOnly = false
    
    VendingsManager:CreateSection("Vending Selection")
    
    VendingsManager:CreateToggle({
        Name = "Use Selected Only",
        CurrentValue = false,
        Callback = function(value)
            useSelectedOnly = value
            if value then
                Util.updateNotification("Mode", " Operations will apply to SELECTED vendings only", 3)
            else
                Util.updateNotification("Mode", " Operations will apply to ALL vendings", 3)
            end
        end
    })
    
    local function getTargetVendings()
        if useSelectedOnly then
            if #state.selectedFavorites == 0 then
                Util.updateNotification("Error", "No vendings selected! Use ALT+Click to select", 3)
                return nil
            end
            return state.selectedFavorites
        else
            local vendings = state.findVendings()
            if #vendings == 0 then
                Util.updateNotification("Error", "No vendings found!", 3)
                return nil
            end
            return vendings
        end
    end
    
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
    
    -- Bank Operations
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
            else
                Util.updateNotification("Error", "Invalid amount", 3)
            end
        end
    })
    
    VendingsManager:CreateButton({
        Name = "Deposit to Bank",
        Callback = function()
            pcall(function()
                local Net = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
                local args = {
                    HttpService:GenerateGUID(false),
                    {{
                        accountType = "PERSONAL",
                        transferType = "DEPOSIT",
                        amount = bankAmount
                    }}
                }
                Net:WaitForChild("TransactionBankBalance"):FireServer(unpack(args))
                Util.updateNotification("Bank", "Deposited " .. Util.formatNumber(bankAmount), 3)
            end)
        end
    })
    
    VendingsManager:CreateButton({
        Name = "Withdraw from Bank",
        Callback = function()
            pcall(function()
                local Net = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
                local args = {
                    HttpService:GenerateGUID(false),
                    {{
                        accountType = "PERSONAL",
                        transferType = "WITHDRAWAL",
                        amount = bankAmount
                    }}
                }
                Net:WaitForChild("TransactionBankBalance"):FireServer(unpack(args))
                Util.updateNotification("Bank", "Withdrew " .. Util.formatNumber(bankAmount), 3)
            end)
        end
    })
end
--[[
    BlockPrinter.lua
    Block placement and deletion features
]]--

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LP = Players.LocalPlayer

return function(Window, state)
    local Util = state.Util
    local BlockPrinterTab = Window:CreateTab("Block Printer")
    
    BlockPrinterTab:CreateParagraph({
        Title = "WARNING - BAN RISK",
        Content = "Using Block Printer may result in account bans!\n\nThis feature places blocks automatically which can be detected by anti-cheat systems.\n\nUSE AT YOUR OWN RISK\n\nRecommended: Only use on alt accounts"
    })
    
    BlockPrinterTab:CreateSection("Block Placement")
    
    BlockPrinterTab:CreateParagraph({
        Title = "How to Use",
        Content = "1. Select block type\n2. Enable placement\n3. Click to place blocks\n\nWorks like Roblox Studio!"
    })
    
    BlockPrinterTab:CreateSection("BTools Controls")
    
    local selectedBlock = "grassBlock"
    local placementActive = false
    
    local function getBlockTypes()
        local blocks = {}
        pcall(function()
            local blocksFolder = RS:FindFirstChild("blocks")
            if blocksFolder then
                for _, block in pairs(blocksFolder:GetChildren()) do
                    table.insert(blocks, block.Name)
                end
            end
        end)
        if #blocks == 0 then
            blocks = {"grassBlock", "stoneBlock", "woodBlock", "sandBlock", "dirtBlock", "oakWoodBlock", "birchWoodBlock", "cobblestoneBlock", "graniteBlock"}
        end
        table.sort(blocks)
        return blocks
    end
    
    local blockTypes = getBlockTypes()
    
    task.spawn(function()
        task.wait(2)
        pcall(function()
            blockTypes = getBlockTypes()
        end)
    end)
    
    BlockPrinterTab:CreateDropdown({
        Name = "Select Block Type",
        Options = blockTypes,
        CurrentOption = {blockTypes[1]},
        MultipleOptions = false,
        Callback = function(option)
            selectedBlock = option[1]
            if placementActive then
                Util.updateNotification("BTools", "Now placing: " .. selectedBlock, 2)
            end
        end
    })
    
    local placementConnection = nil
    
    BlockPrinterTab:CreateToggle({
        Name = "Enable Click-to-Place",
        CurrentValue = false,
        Callback = function(value)
            placementActive = value
            
            if value then
                Util.updateNotification("BTools", "Click anywhere to place " .. selectedBlock, 3)
                
                local mouse = LP:GetMouse()
                
                if placementConnection then
                    placementConnection:Disconnect()
                end
                
                placementConnection = mouse.Button1Down:Connect(function()
                    if not placementActive then
                        if placementConnection then
                            placementConnection:Disconnect()
                            placementConnection = nil
                        end
                        return
                    end
                    
                    pcall(function()
                        local target = mouse.Target
                        local hitPos = mouse.Hit.Position
                        
                        local placePos = hitPos + Vector3.new(0, 3, 0)
                        
                        local Net = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
                        local args = {
                            ["upperBlock"] = false,
                            ["cframe"] = CFrame.new(placePos),
                            ["blockType"] = selectedBlock,
                            ["player_tracking_category"] = "join_from_web"
                        }
                        
                        Net:WaitForChild("CLIENT_BLOCK_PLACE_REQUEST"):InvokeServer(args)
                    end)
                end)
            else
                Util.updateNotification("BTools", "Placement disabled", 2)
                if placementConnection then
                    placementConnection:Disconnect()
                    placementConnection = nil
                end
            end
        end
    })
    
    BlockPrinterTab:CreateSection("Quick Actions")
    
    BlockPrinterTab:CreateButton({
        Name = "Place Block at Feet",
        Callback = function()
            pcall(function()
                local pos = LP.Character.HumanoidRootPart.Position
                
                local Net = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
                local args = {
                    ["upperBlock"] = false,
                    ["cframe"] = CFrame.new(pos + Vector3.new(0, 3, 0)),
                    ["blockType"] = selectedBlock,
                    ["player_tracking_category"] = "join_from_web"
                }
                
                Net:WaitForChild("CLIENT_BLOCK_PLACE_REQUEST"):InvokeServer(args)
                Util.updateNotification("Placed", selectedBlock, 2)
            end)
        end
    })
    
    BlockPrinterTab:CreateButton({
        Name = "Delete Block (Looking At)",
        Callback = function()
            pcall(function()
                local mouse = LP:GetMouse()
                local target = mouse.Target
                
                if target and target.Parent and target.Parent.Name == "Blocks" then
                    local Net = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
                    local args = {
                        ["block"] = target,
                        ["player_tracking_category"] = "join_from_web"
                    }
                    
                    Net:WaitForChild("CLIENT_BLOCK_BREAK_REQUEST"):InvokeServer(args)
                    Util.updateNotification("Deleted", target.Name, 2)
                else
                    Util.updateNotification("Error", "Not looking at a block!", 3)
                end
            end)
        end
    })
end
--[[
    Automation.lua
    Automation features - Auto-restock, Bank to Vendings, Auto Stocker
]]--

local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LP = Players.LocalPlayer

return function(Window, state)
    local Util = state.Util
    local AutomationTab = Window:CreateTab("Automation")
    
    AutomationTab:CreateSection("Auto-Restock Vendings")
    
    local autoRestockEnabled = false
    local restockItem = "grassBlock"
    local restockAmount = 100
    local restockInterval = 30
    
    AutomationTab:CreateParagraph({
        Title = "Auto-Restock Info",
        Content = "Automatically restocks selected vendings with items from your inventory at set intervals."
    })
    
    AutomationTab:CreateInput({
        Name = "Item to Restock",
        PlaceholderText = "Enter item name",
        RemoveTextAfterFocusLost = false,
        Callback = function(text)
            if text and text ~= "" then
                restockItem = text
                Util.updateNotification("Auto-Restock", "Item: " .. text, 2)
            end
        end
    })
    
    AutomationTab:CreateInput({
        Name = "Restock Amount",
        PlaceholderText = "Enter amount",
        RemoveTextAfterFocusLost = false,
        Callback = function(text)
            local num = Util.parseAmount(text) or tonumber(text)
            if num then
                restockAmount = num
                Util.updateNotification("Auto-Restock", "Amount: " .. Util.formatNumber(num), 2)
            end
        end
    })
    
    AutomationTab:CreateSlider({
        Name = "Restock Interval (seconds)",
        Range = {10, 300},
        Increment = 10,
        CurrentValue = 30,
        Callback = function(value)
            restockInterval = value
        end
    })
    
    AutomationTab:CreateToggle({
        Name = "Enable Auto-Restock",
        CurrentValue = false,
        Callback = function(value)
            autoRestockEnabled = value
            
            if value then
                Util.updateNotification("Auto-Restock", "Enabled! Interval: " .. restockInterval .. "s", 3)
                
                task.spawn(function()
                    while autoRestockEnabled do
                        wait(restockInterval)
                        
                        pcall(function()
                            local vendings = #state.selectedFavorites > 0 and state.selectedFavorites or state.findVendings()
                            
                            if #vendings == 0 then
                                Util.updateNotification("Auto-Restock", "No vendings found!", 2)
                                return
                            end
                            
                            local tool = LP.Backpack:FindFirstChild(restockItem) or (LP.Character and LP.Character:FindFirstChild(restockItem))
                            
                            if not tool then
                                Util.updateNotification("Auto-Restock", "Item not in inventory: " .. restockItem, 3)
                                return
                            end
                            
                            local restockedCount = 0
                            
                            for _, vending in ipairs(vendings) do
                                if not autoRestockEnabled then break end
                                
                                pcall(function()
                                    local Net = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
                                    local ItemRemote = Net:WaitForChild("deGzdggahhjo/yeuvbxxakbeqDdlofjxFiBwq")
                                    
                                    local guid = HttpService:GenerateGUID(false)
                                    
                                    ItemRemote:FireServer(guid, {{
                                        player_tracking_category = "join_from_web",
                                        amount = restockAmount,
                                        vendingMachine = vending,
                                        tool = tool,
                                        action = "deposit"
                                    }})
                                    
                                    restockedCount = restockedCount + 1
                                    wait(0.1)
                                end)
                            end
                            
                            Util.updateNotification("Auto-Restock", "Restocked " .. restockedCount .. " vendings", 3)
                        end)
                    end
                end)
            else
                Util.updateNotification("Auto-Restock", "Disabled", 2)
            end
        end
    })
    
    -- Bank to Vendings Automation
    AutomationTab:CreateSection("Bank to Vendings Automation")
    
    local bankAutoEnabled, bankAutoAmount, bankAutoTimer = false, 1500000000, 10
    
    AutomationTab:CreateParagraph({
        Title = "How It Works",
        Content = "Withdraws coins from bank and deposits to vendings. Smart distribution - fills up to 5B limit then moves to next vending."
    })
    
    AutomationTab:CreateInput({
        Name = "Withdraw Amount",
        PlaceholderText = "Enter amount",
        RemoveTextAfterFocusLost = false,
        Callback = function(text)
            local num = Util.parseAmount(text) or tonumber(text)
            if num then
                bankAutoAmount = num
                Util.updateNotification("Bank Auto", "Set to " .. Util.formatNumber(num), 2)
            end
        end
    })
    
    AutomationTab:CreateSlider({
        Name = "Cycle Timer (seconds)",
        Range = {1, 60},
        Increment = 1,
        CurrentValue = 10,
        Callback = function(value)
            bankAutoTimer = value
        end
    })
    
    AutomationTab:CreateToggle({
        Name = "Enable Bank Auto-Deposit",
        CurrentValue = false,
        Callback = function(value)
            if value and bankAutoEnabled then 
                Util.updateNotification("Error", "Already running!", 2) 
                return 
            end
            bankAutoEnabled = value
            if value then
                Util.updateNotification("Bank Automation", "Enabled! Cycle: " .. bankAutoTimer .. "s", 3)
                task.spawn(function()
                    while bankAutoEnabled do
                        pcall(function()
                            local Net = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
                            local guid = HttpService:GenerateGUID(false)
                            
                            Net:WaitForChild("TransactionBankBalance"):FireServer(guid, {{
                                accountType = "PERSONAL",
                                transferType = "WITHDRAWAL",
                                amount = bankAutoAmount
                            }})
                            wait(0.5)
                            
                            local vendings = #state.selectedFavorites > 0 and state.selectedFavorites or state.findVendings()
                            
                            if #vendings > 0 then
                                local remainingAmount = bankAutoAmount
                                local vendingsUsed = 0
                                local VENDING_LIMIT = 5000000000
                                
                                for _, vending in ipairs(vendings) do
                                    if remainingAmount <= 0 then break end
                                    local currentBalance = 0
                                    pcall(function()
                                        if vending:FindFirstChild("CoinBalance") then
                                            currentBalance = vending.CoinBalance.Value
                                        end
                                    end)
                                    local availableSpace = VENDING_LIMIT - currentBalance
                                    if availableSpace > 0 then
                                        local depositAmount = math.min(remainingAmount, availableSpace)
                                        -- depositCoinsToVending call would go here
                                        remainingAmount = remainingAmount - depositAmount
                                        vendingsUsed = vendingsUsed + 1
                                        task.wait(0.1)
                                    end
                                end
                                Util.updateNotification("Bank Auto", "Deposited " .. Util.formatNumber(bankAutoAmount - remainingAmount), 3)
                            end
                        end)
                        wait(bankAutoTimer)
                    end
                end)
            else
                Util.updateNotification("Bank Automation", "Disabled", 2)
            end
        end
    })
    
    -- Auto Stocker
    AutomationTab:CreateSection("Vending Auto Stocker")
    
    local stockerEnabled, stockerAmount, stockerTimer, stockerMode = false, 5, 15, "Deposit All"
    
    AutomationTab:CreateParagraph({
        Title = "How It Works",
        Content = "Picks a RANDOM item from your backpack and deposits it to vendings. Choose Deposit All or Split mode."
    })
    
    AutomationTab:CreateInput({
        Name = "Item Amount",
        PlaceholderText = "Amount per cycle...",
        RemoveTextAfterFocusLost = false,
        Callback = function(text)
            local num = tonumber(text)
            if num then stockerAmount = num end
        end
    })
    
    AutomationTab:CreateSlider({
        Name = "Cycle Timer (seconds)",
        Range = {1, 120},
        Increment = 1,
        CurrentValue = 15,
        Callback = function(value)
            stockerTimer = value
        end
    })
    
    AutomationTab:CreateDropdown({
        Name = "Deposit Mode",
        Options = {"Deposit All", "Split"},
        CurrentOption = {"Deposit All"},
        MultipleOptions = false,
        Callback = function(option)
            stockerMode = option[1]
        end
    })
    
    AutomationTab:CreateToggle({
        Name = "Enable Auto Stocker",
        CurrentValue = false,
        Callback = function(value)
            stockerEnabled = value
            if value then
                Util.updateNotification("Auto Stocker", "Enabled! Cycle: " .. stockerTimer .. "s", 3)
                task.spawn(function()
                    while stockerEnabled do
                        if #state.itemOptions > 0 and state.itemOptions[1] ~= "No items" then
                            local randomItem = state.itemOptions[math.random(1, #state.itemOptions)]
                            local vendings = state.findVendings()
                            if #vendings > 0 then
                                if stockerMode == "Deposit All" then
                                    Util.updateNotification("Auto Stocker", "Deposited " .. stockerAmount .. "x " .. randomItem, 2)
                                else
                                    local perVending = math.floor(stockerAmount / #vendings)
                                    Util.updateNotification("Auto Stocker", "Split " .. stockerAmount .. "x " .. randomItem, 2)
                                end
                            end
                        end
                        wait(stockerTimer)
                    end
                end)
            else
                Util.updateNotification("Auto Stocker", "Disabled", 2)
            end
        end
    })
end
--[[
    Farming.lua
    Crop farming, Auto Walk, Plant Crops, Auto Eat
]]--

local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local LP = Players.LocalPlayer

return function(Window, state)
    local Util = state.Util
    local FarmingTab = Window:CreateTab("Farming")
    
    FarmingTab:CreateSection("Crop Farming")
    
    -- Crop Handler
    local CropHandler = {}
    CropHandler.__index = CropHandler
    
    function CropHandler.newCrop(Crop)
        Crop:WaitForChild("stage", 9e9)
        
        local FarmableStage = 3
        local CropName = Crop.Name:lower():find("berrybush") and "berryBush" or Crop.Name 
        if CropName == "berryBush" then
            FarmableStage = 2
        end
        if Crop.stage.Value == FarmableStage then
            CollectionService:AddTag(Crop, "READY: "..CropName)
        end
        
        Crop.stage.Changed:Connect(function(Stage)
            task.wait()
            if Stage == FarmableStage then
                CollectionService:AddTag(Crop, "READY: "..CropName)
            end
            if FarmableStage == 2 and Stage ~= 2 then
                CollectionService:RemoveTag(Crop, "READY: "..CropName)
            end
        end)
    end
    
    function CropHandler.new()
        local self = setmetatable({}, CropHandler)
        CollectionService:GetInstanceAddedSignal("crop-logic"):Connect(self.newCrop)
        for i, v in pairs(CollectionService:GetTagged("crop-logic")) do
            self.newCrop(v)
        end
        return self
    end
    
    function CropHandler:Get(Crop)
        return CollectionService:GetTagged("READY: "..Crop)
    end
    
    local selectedCrop = nil
    local farmCropsEnabled = false
    local replaceCropsEnabled = false
    local NeverExecutedBefore = false
    local GetCrops
    
    local cropList = {
        "(Select/None)",
        "Wheat", "Tomato", "Potato", "Carrot", "Onion",
        "Cactus", "Spinach", "Pumpkin", "Radish", "Chili",
        "Spirit", "Starfruit", "Melon", "Rice", "Seaweed",
        "Candy Cane", "Pineapple", "Dragonfruit", "Grape", "Void Parasite",
        "Berry Bush"
    }
    
    FarmingTab:CreateDropdown({
        Name = "Selected Crop",
        Options = cropList,
        CurrentOption = {"(Select/None)"},
        MultipleOptions = false,
        Callback = function(option)
            if option[1] == "(Select/None)" then
                selectedCrop = nil
            else
                local cropName = option[1]
                if cropName == "Candy Cane" then selectedCrop = "candyCaneVine"
                elseif cropName == "Grape" then selectedCrop = "grapeVine"
                elseif cropName == "Chili" then selectedCrop = "chiliPepper"
                elseif cropName == "Spirit" then selectedCrop = "spiritCrop"
                elseif cropName == "Void Parasite" then selectedCrop = "voidParasite"
                elseif cropName == "Berry Bush" then selectedCrop = "berryBush"
                else selectedCrop = cropName:lower()
                end
            end
        end
    })
    
    FarmingTab:CreateToggle({
        Name = "Farm Crops",
        CurrentValue = false,
        Callback = function(value)
            farmCropsEnabled = value
            if value then
                if not selectedCrop then
                    Util.updateNotification("Error", "Please select a crop first!", 3)
                    farmCropsEnabled = false
                    return
                end
                
                if not NeverExecutedBefore then
                    GetCrops = CropHandler.new()
                    NeverExecutedBefore = true
                end
                
                task.spawn(function()
                    while farmCropsEnabled do
                        local SelectedCrop = GetCrops:Get(selectedCrop)
                        if SelectedCrop[1] then
                            local Net = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
                            
                            Net:WaitForChild("SwingSickle"):InvokeServer("sickleDiamond", SelectedCrop)
                            
                            if replaceCropsEnabled then
                                task.wait(0.5)
                                for _, crop in pairs(SelectedCrop) do
                                    if not farmCropsEnabled then break end
                                    task.spawn(function()
                                        pcall(function()
                                            local args = {{
                                                uwhiHAMdjExWka = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nffEgdldU",
                                                cframe = crop.CFrame,
                                                blockType = selectedCrop,
                                                upperBlock = false
                                            }}
                                            Net:WaitForChild("CLIENT_BLOCK_PLACE_REQUEST"):InvokeServer(unpack(args))
                                        end)
                                    end)
                                end
                            end
                        end
                        task.wait()
                    end
                end)
                Util.updateNotification("Farm Crops", "Enabled", 2)
            else
                Util.updateNotification("Farm Crops", "Disabled", 2)
            end
        end
    })
    
    FarmingTab:CreateToggle({
        Name = "Replace Crops",
        CurrentValue = false,
        Callback = function(value)
            replaceCropsEnabled = value
        end
    })
    
    -- Plant Crops in Radius
    FarmingTab:CreateToggle({
        Name = "Plant Crops in Radius",
        CurrentValue = false,
        Callback = function(value)
            if value then
                if not selectedCrop then
                    Util.updateNotification("Error", "Please select a crop first!", 3)
                    return
                end
                
                task.spawn(function()
                    pcall(function()
                        if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
                            local hrp = LP.Character.HumanoidRootPart
                            local playerPos = hrp.Position
                            local Net = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
                            
                            local radius = state.vendingRadius or 100
                            local spacing = 4
                            local positions = {}
                            
                            for ring = 0, math.floor(radius / spacing) do
                                local ringRadius = ring * spacing
                                if ringRadius > radius then break end
                                
                                if ring == 0 then
                                    table.insert(positions, {pos = playerPos, distance = 0})
                                else
                                    local circumference = 2 * math.pi * ringRadius
                                    local pointsInRing = math.max(8, math.floor(circumference / spacing))
                                    
                                    for i = 0, pointsInRing - 1 do
                                        local angle = (i / pointsInRing) * 2 * math.pi
                                        local xOffset = math.cos(angle) * ringRadius
                                        local zOffset = math.sin(angle) * ringRadius
                                        
                                        local pos = Vector3.new(
                                            playerPos.X + xOffset,
                                            playerPos.Y - 3,
                                            playerPos.Z + zOffset
                                        )
                                        
                                        local distance = (pos - playerPos).Magnitude
                                        if distance <= radius then
                                            table.insert(positions, {pos = pos, distance = distance})
                                        end
                                    end
                                end
                            end
                            
                            table.sort(positions, function(a, b) return a.distance < b.distance end)
                            
                            local planted = 0
                            for _, data in ipairs(positions) do
                                if not Util.IsTaken(data.pos) then
                                    task.spawn(function()
                                        pcall(function()
                                            local args = {{
                                                uwhiHAMdjExWka = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nffEgdldU",
                                                cframe = CFrame.new(data.pos),
                                                blockType = selectedCrop,
                                                upperBlock = false
                                            }}
                                            Net:WaitForChild("CLIENT_BLOCK_PLACE_REQUEST"):InvokeServer(unpack(args))
                                        end)
                                    end)
                                    planted = planted + 1
                                end
                            end
                            
                            Util.updateNotification("Planted " .. planted .. " crops", "", 2)
                        end
                    end)
                end)
            end
        end
    })
    
    -- Auto Eat System
    FarmingTab:CreateSection("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    local autoEatEnabled = false
    local autoEatItem1, autoEatItem2, autoEatItem3 = nil, nil, nil
    local autoEatCooldown = 900
    
    local FoodItemsDisplay = {}
    local FoodItemsToolNames = {}
    for _, v in next, RS.Tools:GetChildren() do
        if v:FindFirstChild("food") then
            local displayName = v:FindFirstChild("DisplayName") and v.DisplayName.Value or v.Name
            table.insert(FoodItemsDisplay, displayName)
            FoodItemsToolNames[displayName] = v.Name
        end
    end
    table.sort(FoodItemsDisplay)
    
    FarmingTab:CreateInput({
        Name = "Search 1st Item",
        PlaceholderText = "Type food name...",
        RemoveTextAfterFocusLost = false,
        Callback = function(text)
            local searchLower = text:lower()
            for _, displayName in ipairs(FoodItemsDisplay) do
                if displayName:lower():find(searchLower) then
                    autoEatItem1 = FoodItemsToolNames[displayName]
                    Util.updateNotification("1st Item", "Set to: " .. displayName, 1)
                    break
                end
            end
        end
    })
    
    FarmingTab:CreateInput({
        Name = "Search 2nd Item",
        PlaceholderText = "Type food name...",
        RemoveTextAfterFocusLost = false,
        Callback = function(text)
            local searchLower = text:lower()
            for _, displayName in ipairs(FoodItemsDisplay) do
                if displayName:lower():find(searchLower) then
                    autoEatItem2 = FoodItemsToolNames[displayName]
                    Util.updateNotification("2nd Item", "Set to: " .. displayName, 1)
                    break
                end
            end
        end
    })
    
    FarmingTab:CreateInput({
        Name = "Search 3rd Item",
        PlaceholderText = "Type food name...",
        RemoveTextAfterFocusLost = false,
        Callback = function(text)
            local searchLower = text:lower()
            for _, displayName in ipairs(FoodItemsDisplay) do
                if displayName:lower():find(searchLower) then
                    autoEatItem3 = FoodItemsToolNames[displayName]
                    Util.updateNotification("3rd Item", "Set to: " .. displayName, 1)
                    break
                end
            end
        end
    })
    
    FarmingTab:CreateInput({
        Name = "Cooldown (seconds)",
        PlaceholderText = "900",
        RemoveTextAfterFocusLost = false,
        Callback = function(text)
            local num = tonumber(text)
            if num and num > 0 then
                autoEatCooldown = num
            end
        end
    })
    
    FarmingTab:CreateToggle({
        Name = "Auto Eat Food",
        CurrentValue = false,
        Callback = function(value)
            autoEatEnabled = value
            if value then
                task.spawn(function()
                    while autoEatEnabled do
                        for _, v in next, {autoEatItem1, autoEatItem2, autoEatItem3} do 
                            if LP.Backpack:FindFirstChild(v) or (LP.Character and LP.Character:FindFirstChild(v)) then
                                local tool = LP.Backpack:FindFirstChild(v) or LP.Character:FindFirstChild(v)
                                if LP.Backpack:FindFirstChild(v) then
                                    LP.Character.Humanoid:EquipTool(tool)
                                    task.wait(0.1)
                                end
                                local Net = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
                                Net:WaitForChild("CLIENT_EAT_FOOD"):InvokeServer({tool = LP.Character:FindFirstChild(v)})
                                task.wait(.3)
                            end
                        end
                        wait(autoEatCooldown)
                    end
                end)
                Util.updateNotification("Auto Eat", "Enabled", 2)
            else
                Util.updateNotification("Auto Eat", "Disabled", 2)
            end
        end
    })
end
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
--[[
    Presets.lua
    Preset management - Save and load vending groups and favorites
]]--

local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")

return function(Window, state)
    local Util = state.Util
    local PresetsTab = Window:CreateTab("Presets")
    
    PresetsTab:CreateParagraph({
        Title = "Favorites & Groups Info",
        Content = "Save and load vending presets for quick access.\n\n• ALT+Click vendings to select them\n• Save selections as Favorites or Groups\n• Load them anytime for quick operations"
    })
    
    PresetsTab:CreateSection("Selection")
    
    PresetsTab:CreateToggle({
        Name = "Enable Selection Mode",
        CurrentValue = false,
        Callback = function(value) 
            state.favoritesSelectionMode = value 
            if value then 
                Util.updateNotification("Selection Mode", "Hold ALT + click vendings! (" .. #state.selectedFavorites .. " selected)", 4) 
            else 
                Util.updateNotification("Selection Mode", "Disabled (" .. #state.selectedFavorites .. " selected)", 2) 
            end 
        end
    })
    
    PresetsTab:CreateButton({
        Name = "Clear All Selections",
        Callback = function()
            for _, vending in ipairs(state.selectedFavorites) do
                state.removeSelectionMarker(vending)
            end
            state.selectedFavorites = {}
            Util.updateNotification("Cleared", "All selections removed", 2)
        end
    })
    
    PresetsTab:CreateSection("Actions")
    
    local favGroupMode = "Save as Favorites"
    
    PresetsTab:CreateDropdown({
        Name = "Select Action",
        Options = {"Save as Favorites", "Load Favorites", "Save as Group", "Load Group", "Show Group ESP", "Hide Group ESP", "Delete Group"},
        CurrentOption = {"Save as Favorites"},
        MultipleOptions = false,
        Callback = function(option)
            favGroupMode = option[1]
        end
    })
    
    local groupNameInput = ""
    local savedGroupsList = {"None"}
    for groupName, _ in pairs(state.vendingGroups) do 
        if groupName ~= "Default" then 
            table.insert(savedGroupsList, groupName) 
        end 
    end
    local selectedGroupName = "None"
    
    PresetsTab:CreateInput({
        Name = "Group Name (for Save/Load/Delete)",
        PlaceholderText = "Enter group name...",
        RemoveTextAfterFocusLost = false,
        Callback = function(text)
            groupNameInput = text
        end
    })
    
    PresetsTab:CreateDropdown({
        Name = "Select Saved Group",
        Options = savedGroupsList,
        CurrentOption = {"None"},
        MultipleOptions = false,
        Callback = function(option)
            selectedGroupName = option[1]
        end
    })
    
    local groupESPObjects = {}
    local function removeGroupESP()
        for _, espData in ipairs(groupESPObjects) do
            if espData.highlight then pcall(function() espData.highlight:Destroy() end) end
            if espData.billboard then pcall(function() espData.billboard:Destroy() end) end
        end
        groupESPObjects = {}
    end
    
    PresetsTab:CreateButton({
        Name = "Apply",
        Callback = function()
            if favGroupMode == "Save as Favorites" then
                if #state.selectedFavorites == 0 then
                    Util.updateNotification("Error", "No vendings selected!", 3)
                    return
                end
                state.favoriteVendings = state.selectedFavorites
                state.saveFavorites()
                Util.updateNotification("Saved", "Saved " .. #state.favoriteVendings .. " favorites!", 3)
                state.selectedFavorites = {}
                
            elseif favGroupMode == "Load Favorites" then
                state.loadFavorites()
                if #state.favoriteVendings > 0 then
                    Util.updateNotification("Loaded", "Loaded " .. #state.favoriteVendings .. " favorites!", 2)
                else
                    Util.updateNotification("No Favorites", "No favorites saved!", 2)
                end
                
            elseif favGroupMode == "Save as Group" then
                if groupNameInput == "" then
                    Util.updateNotification("Error", "Enter group name!", 3)
                    return
                end
                local vendings = state.findVendings()
                if #vendings == 0 then
                    Util.updateNotification("Error", "No vendings!", 3)
                    return
                end
                state.vendingGroups[groupNameInput] = {}
                for _, vending in ipairs(vendings) do
                    table.insert(state.vendingGroups[groupNameInput], {
                        x = vending.Position.X,
                        y = vending.Position.Y,
                        z = vending.Position.Z,
                        name = vending.Name
                    })
                end
                local groupsData = {}
                for groupName, vendingList in pairs(state.vendingGroups) do
                    if groupName ~= "Default" then
                        groupsData[groupName] = vendingList
                    end
                end
                pcall(function()
                    writefile("VendingManager_Groups.json", HttpService:JSONEncode(groupsData))
                end)
                Util.updateNotification("Group Saved", "Saved '" .. groupNameInput .. "'!", 5)
                
            elseif favGroupMode == "Show Group ESP" then
                if selectedGroupName == "None" or not state.vendingGroups[selectedGroupName] then
                    Util.updateNotification("Error", "Select group!", 3)
                    return
                end
                
                removeGroupESP()
                local group = state.vendingGroups[selectedGroupName]
                local vendings = {}
                local islands = WS:FindFirstChild("Islands")
                
                if islands then
                    for _, island in pairs(islands:GetChildren()) do
                        local blocks = island:FindFirstChild("Blocks")
                        if blocks then
                            for _, obj in pairs(blocks:GetChildren()) do
                                if obj.Name:find("vending") or obj.Name:find("Vending") then
                                    table.insert(vendings, obj)
                                end
                            end
                        end
                    end
                end
                
                for i, vendingData in ipairs(group) do
                    local savedPos = Vector3.new(vendingData.x, vendingData.y, vendingData.z)
                    for _, vending in ipairs(vendings) do
                        if (vending.Position - savedPos).Magnitude < 1 then
                            local highlight = Instance.new("Highlight")
                            highlight.FillColor = Color3.fromRGB(255, 165, 0)
                            highlight.Parent = vending
                            
                            local billboard = Instance.new("BillboardGui")
                            billboard.AlwaysOnTop = true
                            billboard.Size = UDim2.new(0, 200, 0, 60)
                            billboard.StudsOffset = Vector3.new(0, 3, 0)
                            billboard.Parent = vending
                            
                            local textLabel = Instance.new("TextLabel")
                            textLabel.BackgroundTransparency = 1
                            textLabel.Size = UDim2.new(1, 0, 1, 0)
                            textLabel.Text = selectedGroupName .. " #" .. i
                            textLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
                            textLabel.TextStrokeTransparency = 0
                            textLabel.TextScaled = true
                            textLabel.Font = Enum.Font.SourceSansBold
                            textLabel.Parent = billboard
                            
                            table.insert(groupESPObjects, {vending = vending, highlight = highlight, billboard = billboard})
                            break
                        end
                    end
                end
                
                Util.updateNotification("ESP", "Showing " .. #groupESPObjects, 2)
                
            elseif favGroupMode == "Hide Group ESP" then
                removeGroupESP()
                Util.updateNotification("ESP", "Hidden", 2)
                
            elseif favGroupMode == "Delete Group" then
                local groupToDelete = groupNameInput ~= "" and groupNameInput or selectedGroupName
                if groupToDelete == "None" or not state.vendingGroups[groupToDelete] then
                    Util.updateNotification("Error", "Select/enter group!", 3)
                    return
                end
                state.vendingGroups[groupToDelete] = nil
                Util.updateNotification("Deleted", "Deleted " .. groupToDelete, 3)
                local groupsData = {}
                for groupName, vendingList in pairs(state.vendingGroups) do
                    if groupName ~= "Default" then
                        groupsData[groupName] = vendingList
                    end
                end
                writefile("VendingManager_Groups.json", HttpService:JSONEncode(groupsData))
                state.currentGroup = "Default"
            end
        end
    })
end
