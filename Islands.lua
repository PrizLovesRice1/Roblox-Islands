--[[
    Priz's Islands Hub
    Advanced automation and management
]]--

local scriptSuccess, scriptError = pcall(function()

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local LP = Players.LocalPlayer

-- IsTaken function for crop placement
function IsTaken(Position)
    for _,v in next, workspace.Islands:GetDescendants() do
        if v:IsA("BasePart") and v.Name ~= "Collision" then
            if (v.Position - Position).magnitude <= 2 then
                return true
            end
        end
    end
end

-- Load Rayfield in two steps
local RayfieldSource = HttpService:GetAsync('https://sirius.menu/rayfield')
local RayfieldLoader = loadstring(RayfieldSource)

if not RayfieldLoader then
    print("ERROR: Failed to load Rayfield source")
    print("Try restarting your game and executor")
    error("Rayfield loader failed")
end

local Rayfield = RayfieldLoader()

if not Rayfield then
    print("ERROR: Rayfield loaded but returned nil")
    print("Try restarting your game and executor")
    error("Rayfield initialization failed")
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

local networkReady = false

task.spawn(function()
    local success = pcall(function()
        local rbxts = RS:WaitForChild("rbxts_include", 10)
        if not rbxts then error("rbxts_include not found") end
        Net = rbxts:WaitForChild("node_modules", 5):WaitForChild("@rbxts", 5):WaitForChild("net", 5):WaitForChild("out", 5):WaitForChild("_NetManaged", 5)
        Open = Net["vdejLrsuUtHdxgMnamqcwrddgseyltmjnutxAhuAdt/ohzbeybzqzfJRFwekzcvdLnpwpuaoia"]
        Edit = Net["vdejLrsuUtHdxgMnamqcwrddgseyltmjnutxAhuAdt/amv"]
        Close = Net["vdejLrsuUtHdxgMnamqcwrddgseyltmjnutxAhuAdt/uabQAzmslluxa"]
        Withdraw = Net["vdejLrsuUtHdxgMnamqcwrddgseyltmjnutxAhuAdt/cFkpxe"]
        Deposit = Net["vdejLrsuUtHdxgMnamqcwrddgseyltmjnutxAhuAdt/uvgaYvclaqh"]
        ItemRemote = Net["vdejLrsuUtHdxgMnamqcwrddgseyltmjnutxAhuAdt/clQqtBtMScmrwsnEkow"]
    end)
    networkReady = success
end)

task.spawn(function()
    repeat task.wait() until LP.Character
end)

local selectedVending, selectedItemName, allAtOnceMode, vendingRadius, useRadiusLimit, radiusRingPart, itemNameMap = nil, nil, true, 100, false, nil, {}

local function getDisplayName(obj)
 if not obj then return "Unknown" end
 local displayNameValue = obj:FindFirstChild("DisplayName")
 if displayNameValue and displayNameValue:IsA("StringValue") then
  return displayNameValue.Value
 end
 return obj.Name
end

local radiusConnection = nil

local function createRadiusRing()
 if radiusRingPart then radiusRingPart:Destroy() radiusRingPart = nil end
 if radiusConnection then radiusConnection:Disconnect() radiusConnection = nil end
 if not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then return end
 
 local adjustedRadius = vendingRadius * 0.8
 local folder = Instance.new("Folder")
 folder.Name = "RadiusRing"
 folder.Parent = WS
 radiusRingPart = folder
 
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
 
 radiusConnection = game:GetService("RunService").Heartbeat:Connect(function()
  if not radiusRingPart or not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then return end
  
  local currentPos = LP.Character.HumanoidRootPart.Position
  for _, data in ipairs(parts) do
   if data.part.Parent then
    data.part.Position = currentPos + data.offset
   end
  end
  
  task.wait(0.1)
 end)
end

local function removeRadiusRing()
 if radiusConnection then radiusConnection:Disconnect() radiusConnection = nil end
 if radiusRingPart then radiusRingPart:Destroy() radiusRingPart = nil end
end

local statistics = {coinsWithdrawn = 0, coinsDeposited = 0, itemsDeposited = 0, itemsWithdrawn = 0, vendingsModified = 0, bankDeposits = 0, bankWithdrawals = 0}
local transactionHistory = {}
local MAX_HISTORY = 50
local isUndoing = false

local performanceMode = false
local favoriteVendings, selectedFavorites, favoritesSelectionMode = {}, {}, false

local function saveFavorites()
 if not writefile then return end
 local favData = {}
 for _, vending in pairs(favoriteVendings) do table.insert(favData, {x = vending.Position.X, y = vending.Position.Y, z = vending.Position.Z, name = vending.Name}) end
 writefile("VendingManager_Favorites.json", HttpService:JSONEncode(favData))
end

local function loadFavorites()
 if not isfile or not readfile then return end
 if isfile("VendingManager_Favorites.json") then
  local success, data = pcall(function() return HttpService:JSONDecode(readfile("VendingManager_Favorites.json")) end)
  if success and data then
   local allVendings = {}
   local islands = WS:FindFirstChild("Islands")
   if islands then for _, island in pairs(islands:GetChildren()) do local blocks = island:FindFirstChild("Blocks") if blocks then for _, obj in pairs(blocks:GetChildren()) do if obj.Name:find("vending") or obj.Name:find("Vending") then table.insert(allVendings, obj) end end end end end
   favoriteVendings = {}
   for _, favData in ipairs(data) do local savedPos = Vector3.new(favData.x, favData.y, favData.z) for _, vending in ipairs(allVendings) do if (vending.Position - savedPos).Magnitude < 1 then table.insert(favoriteVendings, vending) break end end end
  end
 end
end

task.spawn(function()
 loadFavorites()
end)

local vendingESPEnabled, vendingESPObjects = false, {}

local function getVendingHealth(vending)
 local coinBalance, itemCount, vendingMode, transactionPrice = 0, 0, nil, 100
 pcall(function()
  if vending:FindFirstChild("CoinBalance") then coinBalance = vending.CoinBalance.Value end
  if vending:FindFirstChild("Mode") then vendingMode = vending.Mode.Value end
  if vending:FindFirstChild("TransactionPrice") then transactionPrice = vending.TransactionPrice.Value end
  local sellingContents = vending:FindFirstChild("SellingContents")
  if sellingContents then for _, item in pairs(sellingContents:GetChildren()) do if item:IsA("Tool") then itemCount = itemCount + (item:FindFirstChild("Amount") and item.Amount.Value or 1) end end end
 end)
 if vendingMode == 1 then
  local priceWithTax = math.floor(transactionPrice * 1.07)
  if coinBalance == 0 then return "EMPTY", Color3.fromRGB(255, 0, 0)
  elseif coinBalance < priceWithTax then return "OUT OF MONEY", Color3.fromRGB(255, 0, 0)
  elseif coinBalance < priceWithTax * 2 then return "LOW", Color3.fromRGB(255, 165, 0)
  elseif coinBalance < priceWithTax * 10 then return "MEDIUM", Color3.fromRGB(255, 255, 0)
  else return "FULL", Color3.fromRGB(0, 255, 0) end
 elseif vendingMode == 0 then
  local maxCoins = 5000000000
  local spaceLeft = maxCoins - coinBalance
  if itemCount == 0 then return "EMPTY", Color3.fromRGB(255, 0, 0)
  elseif spaceLeft < 500000000 then return "ALMOST FULL", Color3.fromRGB(255, 0, 0)
  elseif spaceLeft < 1500000000 then return "LOW SPACE", Color3.fromRGB(255, 165, 0)
  elseif spaceLeft < 3000000000 then return "MEDIUM", Color3.fromRGB(255, 255, 0)
  else return "GOOD SPACE", Color3.fromRGB(0, 255, 0) end
 else
  if coinBalance == 0 and itemCount == 0 then return "OFFLINE", Color3.fromRGB(255, 0, 0)
  else return "OFFLINE", Color3.fromRGB(128, 128, 128) end
 end
end

local function getVendingInfo(vending)
 local itemName, itemCount, coinAmount = nil, 0, 0
 pcall(function()
  local sellingContents = vending:FindFirstChild("SellingContents")
  if sellingContents then
   local firstItem = sellingContents:GetChildren()[1]
   if firstItem then
    itemName = getDisplayName(firstItem)
    itemCount = firstItem:FindFirstChild("Amount") and firstItem.Amount.Value or 1
   end
  end
  local coinBalance = vending:FindFirstChild("CoinBalance")
  if coinBalance then coinAmount = coinBalance.Value end
 end)
 return itemName, itemCount, coinAmount
end

local vendingGroups = {["Default"] = {}}
local currentGroup = "Default"

if isfile and readfile and isfile("VendingManager_Groups.json") then
 local success, groupsData = pcall(function() return HttpService:JSONDecode(readfile("VendingManager_Groups.json")) end)
 if success and groupsData then for groupName, vendingList in pairs(groupsData) do vendingGroups[groupName] = vendingList end end
end

local hotkeys = {withdrawAll = Enum.KeyCode.F1, depositAll = Enum.KeyCode.F2, selectRandom = Enum.KeyCode.F3, scanVendings = Enum.KeyCode.F4, emptyAll = Enum.KeyCode.F5}
local userSettings = {theme = "Amethyst", radius = 100, useRadius = false, processMode = true}

local activeNotifications = {}
local notificationSpacing = 45

local function updateNotification(title, content, duration)
 task.spawn(function()
  pcall(function()
   local Players = game:GetService("Players")
   local player = Players.LocalPlayer
   local playerGui = player:WaitForChild("PlayerGui")
   
   local screenGui = Instance.new("ScreenGui")
   screenGui.ResetOnSpawn = false
   screenGui.Parent = playerGui
   local frame = Instance.new("Frame")
   frame.Parent = screenGui
   frame.AnchorPoint = Vector2.new(1, 0.5)
   
   -- Make welcome notification bigger
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
   
   for i, notif in ipairs(activeNotifications) do
    local notifFrame = notif:FindFirstChildOfClass("Frame")
    if notifFrame then
     local newY = 0.93 - ((i - 1) * (notificationSpacing / 1080))
     notifFrame:TweenPosition(UDim2.new(0.98, 0, newY, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
    end
   end
   
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
   
   for i, notif in ipairs(activeNotifications) do
    local notifFrame = notif:FindFirstChildOfClass("Frame")
    if notifFrame then
     local newY = 0.93 - ((i - 1) * (notificationSpacing / 1080))
     notifFrame:TweenPosition(UDim2.new(0.98, 0, newY, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
    end
   end
  end)
 end)
end
local function checkNetwork() if not networkReady then updateNotification("Error", "Network not initialized!", 5) return false end return true end
local function formatNumber(num) if num >= 1000000000 then return string.format("%.2fB", num / 1000000000) elseif num >= 1000000 then return string.format("%.2fM", num / 1000000) elseif num >= 1000 then return string.format("%.2fK", num / 1000) else return tostring(num) end end
local function parseAmount(text)
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
local function saveSettings() 
 pcall(function()
  writefile("VendingManager_Settings.json", HttpService:JSONEncode(userSettings))
 end)
end

local function findVendings()
 if currentGroup ~= "Default" and currentGroup ~= "None" and vendingGroups[currentGroup] then
  local groupVendings, allVendings = {}, {}
  local islands = WS:FindFirstChild("Islands")
  if islands then for _, island in pairs(islands:GetChildren()) do local blocks = island:FindFirstChild("Blocks") if blocks then for _, obj in pairs(blocks:GetChildren()) do if obj.Name:find("vending") or obj.Name:find("Vending") then table.insert(allVendings, obj) end end end end end
  local group = vendingGroups[currentGroup]
  for _, vendingData in ipairs(group) do local savedPos = Vector3.new(vendingData.x, vendingData.y, vendingData.z) for _, vending in ipairs(allVendings) do if (vending.Position - savedPos).Magnitude < 1 then table.insert(groupVendings, vending) break end end end
  return groupVendings
 end
 local vendings = {}
 local islands = WS:FindFirstChild("Islands")
 if islands then for _, island in pairs(islands:GetChildren()) do local blocks = island:FindFirstChild("Blocks") if blocks then for _, obj in pairs(blocks:GetChildren()) do if obj.Name:find("vending") or obj.Name:find("Vending") then if useRadiusLimit then if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then local distance = (obj.Position - LP.Character.HumanoidRootPart.Position).Magnitude if distance <= vendingRadius then table.insert(vendings, obj) end end else table.insert(vendings, obj) end end end end end end
 return vendings
end

local function setVendingMode(vending, mode, price)
 if not checkNetwork() then return end
 pcall(function()
  local guid = HttpService:GenerateGUID(false)
  Open:FireServer(guid, {{vendingMachine = vending}})
  Edit:FireServer(guid, {{vendingMachine = vending}})
  game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("vdejLrsuUtHdxgMnamqcwrddgseyltmjnutxAhuAdt/kvkeytzzouf"):FireServer(guid, {{mode = mode, vendingMachine = vending, player_tracking_category = "join_from_web", transactionPrice = price}})
  Close:FireServer({vendingMachine = vending})
  statistics.vendingsModified = statistics.vendingsModified + 1
 end)
end

local function setVendingOffline(vending)
 if not checkNetwork() then return end
 pcall(function()
  local guid = HttpService:GenerateGUID(false)
  local currentPrice = vending:FindFirstChild("TransactionPrice") and vending.TransactionPrice.Value or 100
  Open:FireServer(guid, {{vendingMachine = vending}})
  Edit:FireServer(guid, {{vendingMachine = vending}})
  game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("vdejLrsuUtHdxgMnamqcwrddgseyltmjnutxAhuAdt/kvkeytzzouf"):FireServer(guid, {{mode = 2, vendingMachine = vending, player_tracking_category = "join_from_web", transactionPrice = currentPrice}})
  Close:FireServer({vendingMachine = vending})
  statistics.vendingsModified = statistics.vendingsModified + 1
 end)
end

local function emptyVending(vending)
 if not checkNetwork() then return end
 pcall(function()
  local guid = HttpService:GenerateGUID(false)
  Open:FireServer(guid, {{vendingMachine = vending}}) 
  Edit:FireServer(guid, {{vendingMachine = vending}}) 
  local itemsWithdrawn = {}
  local sellingContents = vending:FindFirstChild("SellingContents")
  if sellingContents then for _, item in pairs(sellingContents:GetChildren()) do if item:IsA("Tool") then local itemAmount = item:FindFirstChild("Amount") and item.Amount.Value or 9999 table.insert(itemsWithdrawn, {name = getDisplayName(item), amount = itemAmount}) ItemRemote:FireServer(guid, {{player_tracking_category = "join_from_web", amount = itemAmount, vendingMachine = vending, tool = item, action = "withdraw"}})  statistics.itemsWithdrawn = statistics.itemsWithdrawn + 1 end end end
   Close:FireServer({vendingMachine = vending})
 end)
end

local function depositItemToVending(vending, itemName, amount)
 if not checkNetwork() then return end
 pcall(function()
  local guid = HttpService:GenerateGUID(false)
  local objectName = itemNameMap[itemName] or itemName
  local item = LP:WaitForChild("Backpack"):FindFirstChild(objectName)
  if not item then updateNotification("Error", "Item not found!", 3) return end
  Open:FireServer(guid, {{vendingMachine = vending}}) 
  Edit:FireServer(guid, {{vendingMachine = vending}}) 
  ItemRemote:FireServer(guid, {{player_tracking_category = "join_from_web", amount = amount, vendingMachine = vending, tool = item, action = "deposit"}})
   Close:FireServer({vendingMachine = vending})
  statistics.itemsDeposited = statistics.itemsDeposited + 1
 end)
end

local function withdrawFromVending(vending, amount)
 if not checkNetwork() then return end
 pcall(function()
  local guid = HttpService:GenerateGUID(false)
  Open:FireServer(guid, {{vendingMachine = vending}})
  Edit:FireServer(guid, {{vendingMachine = vending}})
  Withdraw:FireServer(guid, {{vendingMachine = vending, player_tracking_category = "join_from_web", amount = amount}})
  Close:FireServer({vendingMachine = vending})
  statistics.coinsWithdrawn = statistics.coinsWithdrawn + amount
 end)
end

local function depositCoinsToVending(vending, amount)
 if not checkNetwork() then return end
 pcall(function()
  local guid = HttpService:GenerateGUID(false)
  Open:FireServer(guid, {{vendingMachine = vending}})
  Edit:FireServer(guid, {{vendingMachine = vending}})
  Deposit:FireServer(guid, {{vendingMachine = vending, player_tracking_category = "join_from_web", amount = amount}})
  Close:FireServer({vendingMachine = vending})
  statistics.coinsDeposited = statistics.coinsDeposited + amount
 end)
end


-- ============================================
--  CRITICAL FIX: SELECTION MARKER SYSTEM
-- ============================================

local Mouse = LP:GetMouse()

--  FIX #1: Added selection limit constant
local MAX_SELECTIONS = 100

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
  for _, obj in pairs(game.Workspace:GetChildren()) do
   if obj.Name == "SelectionMarker" and obj.Adornee == vending then
    obj:Destroy()
   end
  end
 end)
end

local function addSelectionMarker(vending)
 clearAllMarkers(vending)
 task.wait(0.05) --  FIX #2: Faster cleanup (was 0.1s)
 
 local billboard = Instance.new("BillboardGui")
 billboard.Name = "SelectionMarker"
 billboard.AlwaysOnTop = true
 billboard.Size = UDim2.new(0, 40, 0, 40) --  FIX #3: Smaller size (was 50x50)
 billboard.StudsOffset = Vector3.new(0, 6, 0)
 billboard.Adornee = vending
 billboard.Parent = game.Workspace
 
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

local function removeSelectionMarker(vending)
 clearAllMarkers(vending)
end

-- ============================================
-- END OF CRITICAL FIX SECTION
-- ============================================


local HomeTab = Window:CreateTab("Home")

HomeTab:CreateSection("About")

HomeTab:CreateParagraph({Title = "Welcome to Priz's Islands Hub", Content = "Developed by: PrizLovesRice Aka Privy\nVersion: 1.0\nLast Updated: February 1, 2026 10:46 PM EST\n\nJoin Discord for updates & support:\ndiscord.gg/NuUzrrNaJz"})

HomeTab:CreateSection("Scanner & Stats")

local Output = HomeTab:CreateParagraph({Title = "Output", Content = "Select an action below..."})

local selectedMode = "Player Info & Island Code"
local playerList = {}
local selectedPlayerForInfo = nil

-- Refresh player list
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

HomeTab:CreateDropdown({Name = "Select Player (for Player Info)", Options = playerList, CurrentOption = {playerList[1]}, MultipleOptions = false, Callback = function(option)
 local playerName = option[1]
 selectedPlayerForInfo = Players:FindFirstChild(playerName)
end})

HomeTab:CreateDropdown({Name = "Select Mode", Options = {"Player Info & Island Code", "Coin Scanner", "Items Scanner", "Vending Mode Scanner", "Blocks Scanner", "Show Statistics", "Show Transaction History"}, CurrentOption = {"Player Info & Island Code"}, MultipleOptions = false, Callback = function(option) selectedMode = option[1] end})

HomeTab:CreateButton({Name = "Apply", Callback = function()
 if selectedMode == "Coin Scanner" then
  local vendings = findVendings()
  local totalCoins, vendingCount = 0, 0
  for _, vending in ipairs(vendings) do pcall(function() if vending:FindFirstChild("CoinBalance") then totalCoins = totalCoins + vending.CoinBalance.Value vendingCount = vendingCount + 1 end end) end
  local resultText = string.format("Total Vendings: %d\nVendings with Coins: %d\nTotal Coins: %s", #vendings, vendingCount, formatNumber(totalCoins))
  pcall(function() Output:Set({Title = "Coin Scanner", Content = resultText}) end)
  if totalCoins > 0 then
   updateNotification("Scan Complete", formatNumber(totalCoins) .. " Coins Found", 2)
  else
   updateNotification("Scan Complete", "No Coins Found", 2)
  end
 elseif selectedMode == "Items Scanner" then
  local vendings, itemCounts = findVendings(), {}
  for _, vending in ipairs(vendings) do
   pcall(function()
    local sellingContents = vending:FindFirstChild("SellingContents")
    if sellingContents then
     for _, item in pairs(sellingContents:GetChildren()) do
      if item:IsA("Tool") then
       local displayName = getDisplayName(item)
       local amount = item:FindFirstChild("Amount") and item.Amount.Value or 1
       itemCounts[displayName] = (itemCounts[displayName] or 0) + amount
      end
     end
    end
   end)
  end
  local resultText, itemCount = "Total Types: 0\n\n", 0
  for itemName, amount in pairs(itemCounts) do itemCount = itemCount + 1 resultText = resultText .. itemName .. ": " .. amount .. "\n" end
  if itemCount == 0 then resultText = "No items found" else resultText = string.format("Total Types: %d\n\n", itemCount) .. resultText:sub(16) end
  pcall(function() Output:Set({Title = "Items Scanner", Content = resultText}) end)
  if itemCount == 0 then
   updateNotification("Scan Complete", "No Items Found", 2)
  else
   updateNotification("Scan Complete", itemCount .. " Item Types Found", 2)
  end
 elseif selectedMode == "Vending Mode Scanner" then
  local vendings = findVendings()
  local buyCount, sellCount, offlineCount = 0, 0, 0
  for _, vending in ipairs(vendings) do pcall(function() if vending:FindFirstChild("Mode") then local mode = vending.Mode.Value if mode == 0 then buyCount = buyCount + 1 elseif mode == 1 then sellCount = sellCount + 1 elseif mode == 2 then offlineCount = offlineCount + 1 end end end) end
  local resultText = string.format("Total: %d\n\n🟢 Buy: %d\n Sell: %d\n Offline: %d", #vendings, buyCount, sellCount, offlineCount)
  pcall(function() Output:Set({Title = "Vending Mode Scanner", Content = resultText}) end)
  updateNotification("Scan Complete", #vendings .. " Vendings Scanned", 2)
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
  for name, count in pairs(objectCounts) do table.insert(sortedObjects, {name = name, count = count}) end
  table.sort(sortedObjects, function(a, b) return a.count > b.count end)
  local resultText = string.format("Total: %d | Types: %d\n\n", totalObjects, #sortedObjects)
  for _, obj in ipairs(sortedObjects) do resultText = resultText .. obj.name .. ": " .. obj.count .. "\n" end
  pcall(function() Output:Set({Title = "Blocks Scanner", Content = resultText}) end)
  updateNotification("Blocks Scanner", totalObjects .. " objects!", 2)
 elseif selectedMode == "Show Statistics" then
  local statsText = string.format("Coins Withdrawn: %s\nCoins Deposited: %s\nItems Deposited: %d\nItems Withdrawn: %d\nVendings Modified: %d\nBank Deposits: %d\nBank Withdrawals: %d", formatNumber(statistics.coinsWithdrawn), formatNumber(statistics.coinsDeposited), statistics.itemsDeposited, statistics.itemsWithdrawn, statistics.vendingsModified, statistics.bankDeposits, statistics.bankWithdrawals)
  pcall(function() Output:Set({Title = "Session Statistics", Content = statsText}) end)
  updateNotification("Statistics", "Displayed!", 2)
 elseif selectedMode == "Show Transaction History" then
  local displayText, displayCount = "", math.min(10, #transactionHistory)
  if displayCount == 0 then displayText = "No transactions yet..."
  else for i = 1, displayCount do local t = transactionHistory[i] displayText = displayText .. t.time .. " | " .. t.details if i < displayCount then displayText = displayText .. "\n" end end end
  pcall(function() Output:Set({Title = "Transaction History (Last 10)", Content = displayText}) end)
  updateNotification("History", "Displayed!", 2)
 elseif selectedMode == "Player Info & Island Code" then
  if not selectedPlayerForInfo then
   updateNotification("Select a Player First", "", 2)
   return
  end
  
  local info = {
   Username = selectedPlayerForInfo.Name,
   DisplayName = selectedPlayerForInfo.DisplayName,
   UserId = selectedPlayerForInfo.UserId,
   AccountAge = selectedPlayerForInfo.AccountAge .. " days",
   Team = selectedPlayerForInfo.Team and selectedPlayerForInfo.Team.Name or "None"
  }
  
  -- Get island code
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
  updateNotification("Loaded Player Info", "", 2)
 end
end})




HomeTab:CreateSection("Openables Opener")

local cauldronEnabled = false
local autoWalkToCauldron = false
local openedCauldrons = {}
local cauldronLoopSpeed = 0.5
local cauldronOpenDelay = 0.05
local openableType = "Cauldrons (All Types)" -- Default - MUST MATCH DROPDOWN

HomeTab:CreateDropdown({Name = "Openable Type", Options = {"Cauldrons (All Types)", "Presents & Envelopes", "Treasure Chests (All Types)", "Serpent Eggs", "Dragon Eggs", "Dungeon Chests", "All"}, CurrentOption = {"Cauldrons (All Types)"}, MultipleOptions = false, Callback = function(option)
 openableType = option[1]
 openedCauldrons = {} -- Reset opened list when changing type
end})

local function findCauldrons()
 local cauldrons = {}
 if not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then return cauldrons end
 local hrp = LP.Character.HumanoidRootPart
 
 for _, island in pairs(WS.Islands:GetChildren()) do
  local blocks = island:FindFirstChild("Blocks")
  if blocks then
   for _, obj in pairs(blocks:GetChildren()) do
    local objName = obj.Name
    local objNameLower = objName:lower()
    local shouldAdd = false
    
    if openableType == "Cauldrons (All Types)" and objNameLower:find("cauldron") then
     shouldAdd = true
    elseif openableType == "Presents & Envelopes" and (objNameLower:find("present") or objNameLower:find("envelope")) then
     shouldAdd = true
    elseif openableType == "Treasure Chests (All Types)" and (objNameLower:find("treasurechest") or objNameLower:find("treasure chest") or objNameLower:find("chest")) then
     shouldAdd = true
    elseif openableType == "Serpent Eggs" and (objNameLower:find("serpent") or objNameLower:find("egg")) then
     shouldAdd = true
    elseif openableType == "Dragon Eggs" and (objNameLower:find("dragon") or (objNameLower:find("infernal") and objNameLower:find("egg"))) then
     shouldAdd = true
    elseif openableType == "Dungeon Chests" and (objNameLower:find("dungeon")) then
     shouldAdd = true
    elseif openableType == "All" then
     if objNameLower:find("cauldron") or objNameLower:find("present") or objNameLower:find("envelope") or 
        objNameLower:find("treasurechest") or objNameLower:find("treasure") or objNameLower:find("chest") or
        objNameLower:find("serpent") or objNameLower:find("dragon") or objNameLower:find("egg") or 
        objNameLower:find("dungeon") then
      shouldAdd = true
     end
    end
    
    if shouldAdd then
     local prompt = obj:FindFirstChildOfClass("ProximityPrompt", true)
     -- CHANGED: Accept prompts even if disabled (we'll try to fire them anyway)
     if prompt then
      local dist = (obj.Position - hrp.Position).Magnitude
      
      -- CHECK RADIUS LIMIT (same as findVendings)
      if useRadiusLimit then
       if dist <= vendingRadius then
        table.insert(cauldrons, {
         object = obj,
         distance = dist,
         prompt = prompt,
         name = obj.Name
        })
       end
      else
       -- No radius limit - add all
       table.insert(cauldrons, {
        object = obj,
        distance = dist,
        prompt = prompt,
        name = obj.Name
       })
      end
     end
    end
   end
  end
 end
 
 table.sort(cauldrons, function(a, b) return a.distance < b.distance end)
 return cauldrons
end

HomeTab:CreateSlider({Name = "Delay Between Opens (seconds)", Range = {0.01, 1}, Increment = 0.01, CurrentValue = 0.01, Callback = function(value) 
 cauldronLoopSpeed = value 
 cauldronOpenDelay = value
end})

HomeTab:CreateToggle({Name = "Enable Opener", CurrentValue = false, Callback = function(value)
 cauldronEnabled = value
 if value then
  updateNotification("Openables", "Enabled Opening " .. openableType, 2)
  
  -- Check if presents/envelopes - use network remote spam
  if openableType == "Presents & Envelopes" then
   task.spawn(function()
    local Net = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("client_request_22")
    
    while cauldronEnabled do
     pcall(function()
      Net:InvokeServer({})
     end)
     task.wait(cauldronOpenDelay)
    end
   end)
  else
   -- Pure delay-based opening - NO BATCHING
   task.spawn(function()
    while cauldronEnabled do
     pcall(function()
      if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
       local openables = findCauldrons()
       
       if #openables == 0 then
        task.wait(1)
        return
       end
       
       local opened = 0
       for _, openableData in ipairs(openables) do
        if not cauldronEnabled then break end
        
        if openableData.prompt and openableData.prompt.Enabled then
         pcall(function()
          fireproximityprompt(openableData.prompt)
          opened = opened + 1
         end)
         
         -- Wait user's delay between each open
         task.wait(cauldronOpenDelay)
        end
       end
       
       if opened > 0 then
        updateNotification("Opened " .. opened .. " openables", "", 1)
       end
      end
     end)
     
     -- Small pause before rescanning
     task.wait(0.5)
    end
   end)
  end
 else
  updateNotification("Openables", "Disabled Opening " .. openableType, 2)
 end
end})

local collectCauldronItems = false
HomeTab:CreateToggle({Name = "Collect Openable Items", CurrentValue = false, Callback = function(value)
 collectCauldronItems = value
 if value then
  task.spawn(function()
   while collectCauldronItems do
    task.wait(0.5)
    pcall(function()
     if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
      local hrp = LP.Character.HumanoidRootPart
      local collected = 0
      local MAX_PER_CYCLE = 8
      for _, island in pairs(WS.Islands:GetChildren()) do
       if not collectCauldronItems or collected >= MAX_PER_CYCLE then break end
       local blocks = island:FindFirstChild("Blocks")
       if blocks then
        for _, obj in pairs(blocks:GetChildren()) do
         if not collectCauldronItems or collected >= MAX_PER_CYCLE then break end
         if obj.Name:lower():find("cauldron") then
          local prompt = obj:FindFirstChildOfClass("ProximityPrompt", true)
          if prompt and prompt.Enabled then
           local dist = (obj.Position - hrp.Position).Magnitude
           if dist <= 15 then
            local success = pcall(function()
             fireproximityprompt(prompt)
            end)
            if success then
             collected = collected + 1
             task.wait(0.05)
            end
           end
          end
         end
        end
       end
      end
     end
    end)
   end
  end)
  updateNotification("Cauldron Items", "Collecting items in 15 studs!", 3)
 else
  updateNotification("Cauldron Items", "Disabled", 2)
 end
end})

HomeTab:CreateToggle({Name = "Auto Walk to Openable", CurrentValue = false, Callback = function(value)
 autoWalkToCauldron = value
 if value then
  updateNotification("Enabled Auto Walk", "", 2)
  task.spawn(function()
   local lastOpenedTime = 0
   local consecutiveErrors = 0
   local lastPosition = nil
   local stuckCounter = 0
   local lastJumpTime = 0
   while autoWalkToCauldron do
    task.wait(0.5)
    local success = pcall(function()
     if not LP or not LP.Character then return end
     local humanoid = LP.Character:FindFirstChild("Humanoid")
     local hrp = LP.Character:FindFirstChild("HumanoidRootPart")
     if not humanoid or not hrp then return end
     local cauldrons = findCauldrons()
     if #cauldrons == 0 then 
      updateNotification("No More Openables Found", "", 2)
      autoWalkToCauldron = false
      return 
     end
     local nearest = cauldrons[1]
     if not nearest or not nearest.object then return end
     local currentPos = hrp.Position
     if lastPosition then
      local distanceMoved = (currentPos - lastPosition).Magnitude
      if distanceMoved < 0.5 then
       stuckCounter = stuckCounter + 1
       if stuckCounter >= 4 then
        local currentTime = tick()
        if currentTime - lastJumpTime > 1 then
         humanoid.Jump = true
         lastJumpTime = currentTime
         task.wait(0.3)
        end
        local directionToTarget = (nearest.object.Position - hrp.Position).Unit
        local rightVector = Vector3.new(-directionToTarget.Z, 0, directionToTarget.X)
        local avoidDirection = stuckCounter % 2 == 0 and rightVector or -rightVector
        local avoidPosition = hrp.Position + (avoidDirection * 5) + (directionToTarget * 3)
        humanoid:MoveTo(avoidPosition)
        updateNotification("Unstuck", "Going around obstacle...", 1)
        task.wait(1)
        stuckCounter = 0
       end
      else
       stuckCounter = 0
      end
     end
     lastPosition = currentPos
     if nearest.distance > 12 then
      humanoid:MoveTo(nearest.object.Position)
     else
      local currentTime = tick()
      if currentTime - lastOpenedTime >= 3 then
       if nearest.prompt and nearest.prompt.Enabled and not openedCauldrons[nearest.object] then
        local openSuccess = pcall(function()
         fireproximityprompt(nearest.prompt)
         task.wait(0.5)
         pcall(function()
          local args = {
           {
            chest = nearest.object,
            player_tracking_category = "join_from_web",
            amount = 999,
            tool = Instance.new("Tool", nil),
            action = "withdraw"
           }
          }
          game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("CLIENT_CHEST_TRANSACTION"):InvokeServer(unpack(args))
         end)
         openedCauldrons[nearest.object] = true
         lastOpenedTime = currentTime
         updateNotification("Opened + Withdrew", nearest.name, 1)
        end)
        if openSuccess then
         consecutiveErrors = 0
         stuckCounter = 0
         lastPosition = nil
         task.wait(3)
        end
       end
      end
     end
    end)
    if not success then
     consecutiveErrors = consecutiveErrors + 1
     if consecutiveErrors >= 8 then
      updateNotification("Auto Walk", "Too many errors, stopping!", 3)
      autoWalkToCauldron = false
      break
     end
    else
     consecutiveErrors = 0
    end
   end
  end)
 else
  pcall(function()
   if LP.Character and LP.Character:FindFirstChild("Humanoid") then
    LP.Character.Humanoid:Move(Vector3.new(0, 0, 0))
   end
  end)
  updateNotification("Disabled Auto Walk", "", 2)
 end
end})



HomeTab:CreateSection("Chest Manager")
HomeTab:CreateParagraph({Title = "How to Use", Content = "1. Select item from dropdown\n2. Click 'Deposit to ALL Chests' or 'Withdraw from ALL Chests'"})

local autoDepositChests = false

local function findChests()
 local list = {}
 local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
 if not hrp then return list end
 for _, obj in WS.Islands:GetDescendants() do
  if obj:IsA("BasePart") and (obj.Name:find("Chest") or obj.Name:find("chest")) then
   if useRadiusLimit then
    if (obj.Position - hrp.Position).Magnitude <= vendingRadius then
     table.insert(list, obj)
    end
   else
    table.insert(list, obj)
   end
  end
 end
 return list
end

-- Get chest remotes
local CHEST_TRANSACTION = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("CLIENT_CHEST_TRANSACTION")
local CHEST_TOGGLE = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("CHEST_TOGGLE")

local function openChest(chest)
 pcall(function()
  local args = {{chest = chest, open = true}}
  CHEST_TOGGLE:InvokeServer(unpack(args))
 end)
end

local function closeChest(chest)
 pcall(function()
  local args = {{chest = chest, open = false}}
  CHEST_TOGGLE:InvokeServer(unpack(args))
 end)
end

local function deposit()
 local tool = nil
 if not useHeldItemChest then
  if not selectedChestItem or selectedChestItem == "No items" then
   updateNotification("Error", "Please select an item from dropdown!", 3)
   return
  end
  for _, item in pairs(LP.Backpack:GetChildren()) do
   if item:IsA("Tool") and getDisplayName(item) == selectedChestItem then
    tool = item
    break
   end
  end
  if not tool and LP.Character then
   for _, item in pairs(LP.Character:GetChildren()) do
    if item:IsA("Tool") and getDisplayName(item) == selectedChestItem then
     tool = item
     break
    end
   end
  end
  if not tool then
   updateNotification("Error", selectedChestItem .. " not found!", 3)
   return
  end
 else
  tool = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
  if not tool then
   updateNotification("Error", "Please hold an item in your hand!", 3)
   return
  end
 end
 
 if tool.Parent == LP.Character then
  tool.Parent = LP.Backpack
  task.wait(0.1)
 end
 
 local btool = LP.Backpack:FindFirstChild(tool.Name)
 if not btool then
  updateNotification("Error", "Item not in backpack!", 3)
  return
 end
 
 local chests = findChests()
 if #chests == 0 then
  updateNotification("Error", "No chests found!", 3)
  return
 end
 
 local amount = btool:FindFirstChild("Amount") and btool.Amount.Value or 1
 if amount <= 0 then
  updateNotification("Error", "Item is empty (0 amount)!", 3)
  return
 end
 
 for _, chest in chests do
  task.spawn(function()
   pcall(function()
    -- Direct transaction (NO open/close)
    local args = {{
     chest = chest,
     player_tracking_category = "join_from_web",
     amount = amount,
     tool = btool,
     action = "deposit"
    }}
    CHEST_TRANSACTION:InvokeServer(unpack(args))
   end)
  end)
 end
 
 task.wait(0.3)
 updateNotification("Deposited " .. formatNumber(amount) .. " to " .. #chests .. " Chests", "", 2)
end

local function withdraw()
 local chests = findChests()
 if #chests == 0 then
  updateNotification("Error", "No chests found!", 3)
  return
 end
 
 updateNotification("Withdrawing", "Processing " .. #chests .. " chests...", 2)
 local totalWithdrawn = 0
 
 for _, chest in chests do
  task.spawn(function()
   pcall(function()
    -- SEQUENCE: Open → Withdraw → Close
    openChest(chest)
    task.wait(0.1)
    
    local contents = chest:FindFirstChild("Contents")
    if contents then
     for _, chestTool in pairs(contents:GetChildren()) do
      if chestTool:IsA("Tool") then
       pcall(function()
        local amount = chestTool:FindFirstChild("Amount") and chestTool.Amount.Value or 1
        
        local withdrawArgs = {{
         chest = chest,
         player_tracking_category = "join_from_web",
         amount = amount,
         tool = chestTool,
         action = "withdraw"
        }}
        
        CHEST_TRANSACTION:InvokeServer(unpack(withdrawArgs))
        totalWithdrawn = totalWithdrawn + 1
        task.wait(0.02)
       end)
      end
     end
    end
    
    task.wait(0.1)
    closeChest(chest)
   end)
  end)
 end
 
 task.wait(1)
 updateNotification("Withdrew from " .. #chests .. " Chests", "", 2)
end


local useHeldItemChest = false
local selectedChestItem = nil
local chestItemsList = {}
local chestDropdown = nil

local function refreshChestItems()
 chestItemsList = {}
 for _, item in pairs(LP.Backpack:GetChildren()) do
  if item:IsA("Tool") then
   table.insert(chestItemsList, getDisplayName(item))
  end
 end
 table.sort(chestItemsList)
 if #chestItemsList == 0 then 
  chestItemsList = {"No items"} 
 else
  if not selectedChestItem or selectedChestItem == "No items" then
   selectedChestItem = chestItemsList[1]
  end
 end
 if chestDropdown then
  chestDropdown:Refresh(chestItemsList, true)
 end
 return chestItemsList
end

refreshChestItems()

HomeTab:CreateToggle({Name = "Use Held Item", CurrentValue = false, Callback = function(value)
 useHeldItemChest = value
 if value then
  updateNotification("Chest Mode", "Using held item", 2)
 else
  updateNotification("Chest Mode", "Using selected item from dropdown", 2)
 end
end})

HomeTab:CreateInput({Name = "Search Items", PlaceholderText = "Type to search...", RemoveTextAfterFocusLost = false, Callback = function(text)
 if text == "" then return end
 refreshChestItems()
 for _, itemName in pairs(chestItemsList) do
  if itemName:lower():find(text:lower(), 1, true) then
   selectedChestItem = itemName
   updateNotification("Selected", itemName, 2)
   return
  end
 end
 updateNotification("Not Found", "No item matches search", 2)
end})

chestDropdown = HomeTab:CreateDropdown({Name = "Select Item to Deposit", Options = chestItemsList, CurrentOption = {selectedChestItem or chestItemsList[1]}, MultipleOptions = false, Callback = function(option) 
 selectedChestItem = option[1]
 if selectedChestItem and selectedChestItem ~= "No items" then
  updateNotification("Selected", selectedChestItem, 2)
 end
end})

-- Ensure selectedChestItem is set initially
if not selectedChestItem and #chestItemsList > 0 and chestItemsList[1] ~= "No items" then
 selectedChestItem = chestItemsList[1]
end

HomeTab:CreateButton({Name = "Deposit to ALL Chests", Callback = function() deposit() end})
HomeTab:CreateButton({Name = "Withdraw from ALL Chests", Callback = function() withdraw() end})

local autoWithdrawChests = false
HomeTab:CreateToggle({Name = "Auto-Withdraw from Chests", CurrentValue = false, Callback = function(value)
 if value and autoWithdrawChests then 
  updateNotification("Error", "Already running!", 2) 
  return 
 end
 autoWithdrawChests = value
 if value then
  updateNotification("Auto Withdraw", "Withdrawing all items from chests every 3s", 3)
  task.spawn(function()
   while autoWithdrawChests do
    pcall(function()
     withdraw()
    end)
    task.wait(3)
   end
  end)
 else
  updateNotification("Auto Withdraw", "Disabled", 2)
 end
end})

HomeTab:CreateToggle({Name = "Auto-Deposit to Chests (Held Item)", CurrentValue = false, Callback = function(value)
 autoDepositChests = value
 if value then
  updateNotification("Auto Deposit", "Hold items to auto-deposit!", 3)
  task.spawn(function()
   while autoDepositChests do
    task.wait(0.05)
    pcall(function()
     local heldTool = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
     
     if heldTool then
      local toolName = heldTool.Name
      local tool = LP.Backpack:FindFirstChild(toolName) or LP.Character:FindFirstChild(toolName)
      
      if tool and tool:IsA("Tool") then
       local amount = tool:FindFirstChild("Amount") and tool.Amount.Value or 1
       
       if amount > 0 then
        local chests = findChests()
        
        if #chests > 0 then
         for _, chest in chests do
          pcall(function()
           local args = {{
            chest = chest,
            player_tracking_category = "join_from_web",
            amount = amount,
            tool = tool,
            action = "deposit"
           }}
           CHEST_TRANSACTION:InvokeServer(unpack(args))
          end)
         end
        end
       end
      end
     end
    end)
   end
  end)
 else
  updateNotification("Auto Deposit", "Disabled", 2)
 end
end})


-- ============================================
--  CRITICAL FIX: CLICK HANDLER WITH LIMIT
-- ============================================

local CLICK_LOCK = false
Mouse.Button1Down:Connect(function()
 -- ABSOLUTE LOCK
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
  
  -- Find the ROOT vending
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
  
  -- Make sure we have the ROOT vending
  while vending.Parent and vending.Parent.Name:lower():find("vending") do
   vending = vending.Parent
  end
  
  -- Check if selected
  local isSelected = false
  local selectedIndex = nil
  
  for i, v in ipairs(selectedFavorites) do
   if v == vending then
    isSelected = true
    selectedIndex = i
    break
   end
  end
  
  if isSelected then
   -- DESELECT
   table.remove(selectedFavorites, selectedIndex)
   removeSelectionMarker(vending)
   updateNotification("Deselected", vending.Name, 1)
  else
   --  CRITICAL FIX: CHECK LIMIT BEFORE ADDING
   if #selectedFavorites >= MAX_SELECTIONS then
      updateNotification("Limit Reached!", "Maximum " .. MAX_SELECTIONS .. " selections. Clear some first!", 4)
      CLICK_LOCK = false
      return
   end
   
   -- SELECT
   table.insert(selectedFavorites, vending)
   addSelectionMarker(vending)
   updateNotification("Selected ", vending.Name .. " (" .. #selectedFavorites .. "/" .. MAX_SELECTIONS .. ")", 1)
  end
  
  task.wait(0.5)
  CLICK_LOCK = false
 end)
end)

-- ============================================
-- HOTKEY BINDINGS
-- ============================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
 if gameProcessed then return end
 
 if input.KeyCode == hotkeys.withdrawAll then
  local vendings = findVendings()
  if #vendings > 0 then
   for _, vending in ipairs(vendings) do
    task.spawn(function() withdrawFromVending(vending, 999999999) end)
   end
   updateNotification("Hotkey", "Withdrew from all!", 2)
  end
  
 elseif input.KeyCode == hotkeys.depositAll then
  local vendings = findVendings()
  if #vendings > 0 then
   for _, vending in ipairs(vendings) do
    task.spawn(function() depositCoinsToVending(vending, 10000000) end)
   end
   updateNotification("Hotkey", "Deposited to all!", 2)
  end
  
 elseif input.KeyCode == hotkeys.selectRandom then
  local vendings = findVendings()
  if #vendings > 0 then
   selectedVending = vendings[math.random(1, #vendings)]
   updateNotification("Hotkey", "Selected " .. selectedVending.Name, 2)
  end
  
 elseif input.KeyCode == hotkeys.scanVendings then
  local vendings = findVendings()
  updateNotification("Hotkey", "Found " .. #vendings .. " vendings!", 2)
  
 elseif input.KeyCode == hotkeys.emptyAll then
  local vendings = findVendings()
  if #vendings > 0 then
   for _, vending in ipairs(vendings) do
    task.spawn(function() emptyVending(vending) end)
   end
   updateNotification("Hotkey", "Emptying " .. #vendings, 2)
  end
 end
end)




-- ============================================
-- VENDINGS MANAGER (UPDATED)
-- ============================================
-- ============================================
-- VENDINGS MANAGER (FIXED WITH CORRECT REMOTES)
-- ============================================
-- ============================================
-- PLAYER & ISLAND INFO
-- ============================================
-- VENDINGS MANAGER TAB
-- ============================================
local VendingsManager = Window:CreateTab("Vendings Manager")

-- Show useful information at the top
VendingsManager:CreateParagraph({Title = " Quick Guide", Content = "Buttons work on ALL vendings automatically!\n\n• ALT+Click vendings to select specific ones\n• Toggle 'Use Selected Only' in Vending Selection to operate on selected vendings\n• Leave toggle OFF to operate on all vendings"})

-- Get the network namespace safely (non-blocking)
local Net

pcall(function()
 Net = RS:WaitForChild("rbxts_include", 10):WaitForChild("node_modules", 10):WaitForChild("@rbxts", 10):WaitForChild("net", 10):WaitForChild("out", 10):WaitForChild("_NetManaged", 10)
  if Net then
   -- Test if we can access the remotes
   local testRemote = Net:FindFirstChild("deGzdggahhjo/ggzImj")
   if testRemote then
    -- Show welcome notification with Rayfield
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
   else
    Rayfield:Notify({
     Title = "Warning",
     Content = "Network ready but remotes not found",
     Duration = 3,
     Image = 4483362458,
    })
   end
  else
   Rayfield:Notify({
    Title = "Error", 
    Content = "Network failed to initialize",
    Duration = 5,
    Image = 4483362458,
   })
   end
end)

-- Helper function to check if network is ready
local function checkVendingNetwork()
 if not Net then
  updateNotification("Error", "Network not ready! Wait 2-3 seconds then try again.", 3)
  return false
 end
 return true
end

-- ============================================
-- HELPER FUNCTIONS
-- ============================================
local function openVending(vending)
 if not checkVendingNetwork() then return end
 pcall(function()
  local args = {
   HttpService:GenerateGUID(false),
   {{vendingMachine = vending}}
  }
  Net:WaitForChild("deGzdggahhjo/qkXeOxsmwiafothorpqogpS"):InvokeServer(unpack(args))
 end)
end

local function closeVending(vending)
 if not checkVendingNetwork() then return end
 pcall(function()
  local args = {{vendingMachine = vending}}
  Net:WaitForChild("deGzdggahhjo/QaardducNrilqsmxdiotkewau"):FireServer(unpack(args))
 end)
end

local function startEditingVending(vending)
 if not checkVendingNetwork() then return end
 pcall(function()
  local args = {
   HttpService:GenerateGUID(false),
   {{vendingMachine = vending}}
  }
  Net:WaitForChild("deGzdggahhjo/yceVHErjjNihyeXjwKeyzfnyrwmcnaWnCo"):FireServer(unpack(args))
 end)
end

local function stopEditingVending(vending)
 if not checkVendingNetwork() then return end
 pcall(function()
  local args = {{vendingMachine = vending}}
  Net:WaitForChild("deGzdggahhjo/ifzkjsqjzFvJn"):FireServer(unpack(args))
 end)
end

local function depositCoinsToVending(vending, amount)
 if not checkVendingNetwork() then return end
 pcall(function()
  -- SEQUENCE: Open → Edit → Action → Stop Edit → Close
  openVending(vending)
  task.wait(0.1)
  startEditingVending(vending)
  task.wait(0.1)
  
  local args = {
   HttpService:GenerateGUID(false),
   {{
    vendingMachine = vending,
    player_tracking_category = "join_from_web",
    amount = amount
   }}
  }
  Net:WaitForChild("deGzdggahhjo/ggzImj"):FireServer(unpack(args))
  
  task.wait(0.1)
  stopEditingVending(vending)
  task.wait(0.05)
  closeVending(vending)
 end)
end

local function withdrawCoinsFromVending(vending, amount)
 if not checkVendingNetwork() then return end
 pcall(function()
  -- SEQUENCE: Open → Edit → Action → Stop Edit → Close
  openVending(vending)
  task.wait(0.1)
  startEditingVending(vending)
  task.wait(0.1)
  
  local args = {
   HttpService:GenerateGUID(false),
   {{
    vendingMachine = vending,
    player_tracking_category = "join_from_web",
    amount = amount
   }}
  }
  Net:WaitForChild("deGzdggahhjo/ytaJiyomainKgxefgrkF"):FireServer(unpack(args))
  
  task.wait(0.1)
  stopEditingVending(vending)
  task.wait(0.05)
  closeVending(vending)
 end)
end

local function setVendingMode(vending, mode, price)
 if not checkVendingNetwork() then return end
 pcall(function()
  -- SEQUENCE: Open → Edit → Action → Stop Edit → Close
  openVending(vending)
  task.wait(0.1)
  startEditingVending(vending)
  task.wait(0.1)
  
  local args = {
   HttpService:GenerateGUID(false),
   {{
    mode = mode,
    vendingMachine = vending,
    player_tracking_category = "join_from_web",
    transactionPrice = price
   }}
  }
  Net:WaitForChild("deGzdggahhjo/rLPziSaNkyol"):FireServer(unpack(args))
  
  task.wait(0.1)
  stopEditingVending(vending)
  task.wait(0.05)
  closeVending(vending)
 end)
end

local function depositItemToVending(vending, itemName, amount)
 if not checkVendingNetwork() then return end
 pcall(function()
  -- Find the tool in player's inventory
  local tool = LP.Backpack:FindFirstChild(itemNameMap[itemName] or itemName)
  if not tool then return end
  
  -- SEQUENCE: Open → Edit → Action → Stop Edit → Close
  openVending(vending)
  task.wait(0.1)
  startEditingVending(vending)
  task.wait(0.1)
  
  local args = {
   HttpService:GenerateGUID(false),
   {{
    player_tracking_category = "join_from_web",
    vendingMachine = vending,
    action = "deposit",
    tool = tool,
    amount = amount
   }}
  }
  Net:WaitForChild("deGzdggahhjo/yeuvbxxakbeqDdlofjxFiBwq"):FireServer(unpack(args))
  
  task.wait(0.1)
  stopEditingVending(vending)
  task.wait(0.05)
  closeVending(vending)
 end)
end

local function withdrawFromVending(vending, amount)
 if not checkVendingNetwork() then return end
 pcall(function()
  -- Get the selling tool
  local sellingTool = nil
  if vending:FindFirstChild("SellingContents") and #vending.SellingContents:GetChildren() > 0 then
   sellingTool = vending.SellingContents:GetChildren()[1]
  end
  
  if not sellingTool then return end
  
  -- SEQUENCE: Open → Edit → Action → Stop Edit → Close
  openVending(vending)
  task.wait(0.1)
  startEditingVending(vending)
  task.wait(0.1)
  
  local args = {
   HttpService:GenerateGUID(false),
   {{
    player_tracking_category = "join_from_web",
    vendingMachine = vending,
    action = "withdraw",
    tool = sellingTool,
    amount = amount
   }}
  }
  Net:WaitForChild("deGzdggahhjo/yeuvbxxakbeqDdlofjxFiBwq"):FireServer(unpack(args))
  
  task.wait(0.1)
  stopEditingVending(vending)
  task.wait(0.05)
  closeVending(vending)
 end)
end

local function emptyVending(vending)
 if not checkVendingNetwork() then return end
 pcall(function()
  local sellingTool = nil
  if vending:FindFirstChild("SellingContents") and #vending.SellingContents:GetChildren() > 0 then
   sellingTool = vending.SellingContents:GetChildren()[1]
  end
  
  if not sellingTool then return end
  
  -- SEQUENCE: Open → Edit → Action → Stop Edit → Close
  openVending(vending)
  task.wait(0.1)
  startEditingVending(vending)
  task.wait(0.1)
  
  local args = {
   HttpService:GenerateGUID(false),
   {{
    player_tracking_category = "join_from_web",
    vendingMachine = vending,
    action = "withdraw",
    tool = sellingTool,
    amount = sellingTool.Amount.Value
   }}
  }
  Net:WaitForChild("deGzdggahhjo/yeuvbxxakbeqDdlofjxFiBwq"):FireServer(unpack(args))
  
  task.wait(0.1)
  stopEditingVending(vending)
  task.wait(0.05)
  closeVending(vending)
 end)
end

-- ============================================
-- SELECTION SYSTEM
-- ============================================
VendingsManager:CreateSection("Vending Selection")

-- Use Selected Only Mode
local useSelectedOnly = false

VendingsManager:CreateToggle({Name = "Use Selected Only", CurrentValue = false, Callback = function(value)
 useSelectedOnly = value
 if value then
  updateNotification("Mode", " Operations will apply to SELECTED vendings only", 3)
 else
  updateNotification("Mode", " Operations will apply to ALL vendings", 3)
 end
end})

-- Helper to get target vendings based on toggle
local function getTargetVendings()
 if useSelectedOnly then
  if #selectedFavorites == 0 then
   updateNotification("Error", "No vendings selected! Use ALT+Click to select", 3)
   return nil
  end
  return selectedFavorites
 else
  local vendings = findVendings()
  if #vendings == 0 then
   updateNotification("Error", "No vendings found!", 3)
   return nil
  end
  return vendings
 end
end

VendingsManager:CreateButton({Name = "Clear All Selections", Callback = function()
 for _, vending in ipairs(selectedFavorites) do
  removeSelectionMarker(vending)
 end
 selectedFavorites = {}
 updateNotification("Selection", "Cleared all selections", 2)
end})

VendingsManager:CreateButton({Name = "Select Random Vending", Callback = function()
 local vendings = findVendings()
 if #vendings == 0 then 
  updateNotification("Error", "No vendings found!", 3)
  return
 end
 
 -- Remove previous marker if exists
 if selectedVending then
  removeSelectionMarker(selectedVending)
 end
 
 -- Pick a NEW random vending (avoid selecting the same one)
 local newVending
 if #vendings > 1 then
  repeat
   newVending = vendings[math.random(1, #vendings)]
  until newVending ~= selectedVending
 else
  newVending = vendings[1]
 end
 
 selectedVending = newVending
 
 -- Check if already in favorites list
 local alreadySelected = false
 for _, v in ipairs(selectedFavorites) do
  if v == selectedVending then
   alreadySelected = true
   break
  end
 end
 
 if not alreadySelected then
  table.insert(selectedFavorites, selectedVending)
 end
 
 -- Always add marker (even if same vending)
 addSelectionMarker(selectedVending)
 updateNotification("Selected", selectedVending.Name, 2)
end})

-- ============================================
-- BANK OPERATIONS
-- ============================================


VendingsManager:CreateSection("Bank Operations")

local bankAmount = 1000000

VendingsManager:CreateInput({Name = "Bank Amount", PlaceholderText = "Enter an amount", RemoveTextAfterFocusLost = false, Callback = function(text)
 local num = parseAmount(text)
 if num then
  bankAmount = num
  updateNotification("Amount", "Set to " .. formatNumber(num), 2)
 else
  updateNotification("Error", "Invalid amount", 3)
 end
end})

VendingsManager:CreateButton({Name = "Deposit to Bank", Callback = function()
 pcall(function()
  local args = {
   HttpService:GenerateGUID(false),
   {{
    accountType = "PERSONAL",
    transferType = "DEPOSIT",
    amount = bankAmount
   }}
  }
  
  Net:WaitForChild("TransactionBankBalance"):FireServer(unpack(args))
  updateNotification("Bank", "Deposited " .. formatNumber(bankAmount), 3)
 end)
end})

VendingsManager:CreateButton({Name = "Withdraw from Bank", Callback = function()
 pcall(function()
  local args = {
   HttpService:GenerateGUID(false),
   {{
    accountType = "PERSONAL",
    transferType = "WITHDRAWAL",
    amount = bankAmount
   }}
  }
  
  Net:WaitForChild("TransactionBankBalance"):FireServer(unpack(args))
  updateNotification("Bank", "Withdrew " .. formatNumber(bankAmount), 3)
 end)
end})

-- ============================================
-- COIN OPERATIONS
-- ============================================


VendingsManager:CreateSection("Coin Operations")

local coinAmount = 10000000

VendingsManager:CreateInput({Name = "Coin Amount", PlaceholderText = "Enter an amount", RemoveTextAfterFocusLost = false, Callback = function(text)
 local num = parseAmount(text)
 if num then
  coinAmount = num
  updateNotification("Amount", "Set to " .. formatNumber(num), 2)
 end
end})

VendingsManager:CreateButton({Name = "Deposit Coins", Callback = function()
 local vendings = getTargetVendings()
 if not vendings then return end
 
 for _, vending in ipairs(vendings) do
  task.spawn(function()
   depositCoinsToVending(vending, coinAmount)
  end)
 end
 
 local target = useSelectedOnly and "selected" or "all"
 updateNotification("Success", "Deposited " .. formatNumber(coinAmount) .. " to " .. #vendings .. " " .. target .. " vendings", 3)
end})

VendingsManager:CreateButton({Name = "Withdraw Coins", Callback = function()
 local vendings = getTargetVendings()
 if not vendings then return end
 
 for _, vending in ipairs(vendings) do
  task.spawn(function()
   withdrawCoinsFromVending(vending, coinAmount)
  end)
 end
 
 local target = useSelectedOnly and "selected" or "all"
 updateNotification("Success", "Withdrew " .. formatNumber(coinAmount) .. " from " .. #vendings .. " " .. target .. " vendings", 3)
end})

VendingsManager:CreateButton({Name = "Withdraw ALL Coins", Callback = function()
 local vendings = getTargetVendings()
 if not vendings then return end
 
 for _, vending in ipairs(vendings) do
  task.spawn(function()
   local currentBalance = vending.CoinBalance and vending.CoinBalance.Value or 0
   if currentBalance > 0 then
    withdrawCoinsFromVending(vending, currentBalance)
   end
  end)
 end
 
 local target = useSelectedOnly and "selected" or "all"
 updateNotification("Success", "Withdrew all coins from " .. #vendings .. " " .. target .. " vendings", 3)
end})

-- ============================================
-- ITEM MANAGEMENT
-- ============================================


VendingsManager:CreateSection("Item Management")

local itemOptions = {}
local ItemDropdown
local function refreshItems()
 itemOptions = {}
 itemNameMap = {}
 local backpack = LP:WaitForChild("Backpack")
 for _, item in pairs(backpack:GetChildren()) do
  if item:IsA("Tool") then
   local displayName = getDisplayName(item)
   itemNameMap[displayName] = item.Name
   table.insert(itemOptions, displayName)
  end
 end
 table.sort(itemOptions)
 if #itemOptions == 0 then itemOptions = {"No items"} end
 return itemOptions
end
refreshItems()

VendingsManager:CreateInput({Name = "Search Items", PlaceholderText = "Enter an item name", RemoveTextAfterFocusLost = false, Callback = function(text)
 if text == "" then return end
 local matches = {}
 for _, itemName in pairs(itemOptions) do
  if itemName:lower():find(text:lower(), 1, true) then
   table.insert(matches, itemName)
  end
 end
 if #matches > 0 then
  selectedItemName = matches[1]
  if ItemDropdown then
   pcall(function() ItemDropdown:Set({matches[1]}) end)
  end
  updateNotification("Item", "Selected: " .. matches[1], 2)
 end
end})

ItemDropdown = VendingsManager:CreateDropdown({Name = "Select Item", Options = itemOptions, CurrentOption = {itemOptions[1]}, MultipleOptions = false, Callback = function(option)
 selectedItemName = option[1]
end})

local itemAmount = 1

VendingsManager:CreateInput({Name = "Item Amount", PlaceholderText = "Enter an amount", RemoveTextAfterFocusLost = false, Callback = function(text)
 local num = parseAmount(text)
 if num then
  itemAmount = num
  updateNotification("Amount", "Set to " .. formatNumber(num), 2)
 end
end})

VendingsManager:CreateButton({Name = "Deposit Item", Callback = function()
 if not selectedItemName or selectedItemName == "No items" then 
  updateNotification("Error", "Select an item first", 3) 
  return 
 end
 
 local vendings = getTargetVendings()
 if not vendings then return end
 
 for _, vending in ipairs(vendings) do
  task.spawn(function()
   depositItemToVending(vending, selectedItemName, itemAmount)
  end)
 end
 
 local target = useSelectedOnly and "selected" or "all"
 updateNotification("Success", "Deposited " .. formatNumber(itemAmount) .. "x " .. selectedItemName .. " to " .. #vendings .. " " .. target .. " vendings", 3)
end})

VendingsManager:CreateButton({Name = "Restock Vending", Callback = function()
 if not selectedItemName or selectedItemName == "No items" then 
  updateNotification("Error", "Select an item first", 3) 
  return 
 end
 
 local vendings = getTargetVendings()
 if not vendings then return end
 
 -- Get the actual tool instance from backpack or character
 local tool = LP.Backpack:FindFirstChild(selectedItemName) or (LP.Character and LP.Character:FindFirstChild(selectedItemName))
 
 if not tool then
  updateNotification("Error", selectedItemName .. " not found in inventory!", 3)
  return
 end
 
 local Net = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
 
 for _, vending in ipairs(vendings) do
  task.spawn(function()
   pcall(function()
    local restockArgs = {
     HttpService:GenerateGUID(false),
     {{
      player_tracking_category = "join_from_web",
      amount = itemAmount,
      vendingMachine = vending,
      tool = tool,
      action = "deposit"
     }}
    }
    
    Net:WaitForChild("deGzdggahhjo/yeuvbxxakbeqDdlofjxFiBwq"):FireServer(unpack(restockArgs))
   end)
  end)
 end
 
 local target = useSelectedOnly and "selected" or "all"
 updateNotification("Success", "Restocked " .. formatNumber(itemAmount) .. "x " .. selectedItemName .. " to " .. #vendings .. " " .. target .. " vendings", 3)
end})

VendingsManager:CreateButton({Name = "Empty Vendings", Callback = function()
 local vendings = getTargetVendings()
 if not vendings then return end
 
 for _, vending in ipairs(vendings) do
  task.spawn(function()
   emptyVending(vending)
  end)
 end
 
 local target = useSelectedOnly and "selected" or "all"
 updateNotification("Success", "Emptied " .. #vendings .. " " .. target .. " vendings", 3)
end})

-- ============================================
-- VENDING CONFIGURATION
-- ============================================


VendingsManager:CreateSection("Vending Configuration")

local vendingMode = "Sell"
local vendingPrice = 100

VendingsManager:CreateDropdown({Name = "Vending Mode", Options = {"Buy", "Sell", "Offline"}, CurrentOption = {"Sell"}, MultipleOptions = false, Callback = function(option)
 vendingMode = option[1]
end})

VendingsManager:CreateInput({Name = "Transaction Price", PlaceholderText = "Enter an amount", RemoveTextAfterFocusLost = false, Callback = function(text)
 local num = parseAmount(text)
 if num then
  vendingPrice = num
  updateNotification("Price", "Set to " .. formatNumber(num), 2)
 end
end})

VendingsManager:CreateButton({Name = "Apply Mode & Price", Callback = function()
 local vendings = getTargetVendings()
 if not vendings then return end
 
 local modeNum = vendingMode == "Buy" and 1 or (vendingMode == "Sell" and 0 or 2)
 
 for _, vending in ipairs(vendings) do
  task.spawn(function()
   setVendingMode(vending, modeNum, vendingPrice)
  end)
 end
 
 local target = useSelectedOnly and "selected" or "all"
 updateNotification("Success", "Set " .. #vendings .. " " .. target .. " vendings to " .. vendingMode .. " mode at " .. formatNumber(vendingPrice), 3)
end})

-- ============================================
-- VENDING SNIPER
-- ============================================


VendingsManager:CreateSection("Vending Sniper")

local sniperEnabled = false
local maxPrice = 1000000
local sniperSpeed = 1
local buyAmount = 999999 -- Default to all items

VendingsManager:CreateInput({Name = "Maximum Price", PlaceholderText = "Enter max price", RemoveTextAfterFocusLost = false, Callback = function(text)
 local num = parseAmount(text)
 if num then
  maxPrice = num
  updateNotification("Sniper", "Max price: " .. formatNumber(num), 2)
 end
end})

VendingsManager:CreateInput({Name = "Buy Amount Per Vending", PlaceholderText = "Enter amount", RemoveTextAfterFocusLost = false, Callback = function(text)
 local num = parseAmount(text)
 if num then
  buyAmount = num
  updateNotification("Sniper", "Will buy: " .. formatNumber(num) .. " per vending", 2)
 end
end})

VendingsManager:CreateSlider({Name = "Sniper Speed (seconds between steps)", Range = {0.01, 5}, Increment = 0.01, CurrentValue = 0.1, Callback = function(value)
 sniperSpeed = value
end})

VendingsManager:CreateToggle({Name = "Enable Vending Sniper", CurrentValue = false, Callback = function(value)
 sniperEnabled = value
 
 if value then
  updateNotification("Vending Sniper", "Started Auto Vending Snipe", 2)
  
  task.spawn(function()
   while sniperEnabled do
    local vendings = findVendings() -- Respects radius if enabled
    
    for _, vending in ipairs(vendings) do
     if not sniperEnabled then break end
     
     local itemName, itemCount, coinAmount = getVendingInfo(vending)
     local transactionPrice = vending:FindFirstChild("TransactionPrice")
     local mode = vending:FindFirstChild("Mode")
     
     -- Skip if empty or no price - BUT ALLOW OFFLINE MODE (mode 2)
     if not itemName or not itemCount or itemCount <= 0 or not transactionPrice then
      continue
     end
     
     -- Check if it's in BUY mode (mode 0) OR OFFLINE mode (mode 2)
     if not mode or (mode.Value ~= 0 and mode.Value ~= 2) then
      continue
     end
     
     local price = transactionPrice.Value
     
     -- Check price
     if price > 0 and price <= maxPrice then
      local Net = game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
      
      pcall(function()
       -- OPEN
       Net:WaitForChild("deGzdggahhjo/qkXeOxsmwiafothorpqogpS"):FireServer(game:GetService("HttpService"):GenerateGUID(false), {{vendingMachine = vending}})
       wait(sniperSpeed)
       
       -- BUY (limited by buyAmount setting)
       local actualBuyAmount = math.min(buyAmount, itemCount)
       Net:WaitForChild("deGzdggahhjo/dfiQxh"):FireServer(game:GetService("HttpService"):GenerateGUID(false), {{vendingMachine = vending, player_tracking_category = "join_from_web", amount = actualBuyAmount}})
       wait(sniperSpeed)
       
       -- CLOSE with both remotes
       local closeArgs = {{vendingMachine = vending}}
       Net:WaitForChild("deGzdggahhjo/ifzkjsqjzFvJn"):FireServer(unpack(closeArgs))
       wait(sniperSpeed)
       Net:WaitForChild("deGzdggahhjo/QaardducNrilqsmxdiotkewau"):FireServer(unpack(closeArgs))
       
       updateNotification("Purchased " .. actualBuyAmount .. "x " .. itemName, "", 2)
      end)
      
      wait(sniperSpeed)
     end
    end
    
    wait(sniperSpeed)
   end
  end)
 else
  updateNotification("Vending Sniper", "Stopped Auto Vending Snipe", 2)
 end
end})



-- ============================================
-- AUTO BUILD TAB
-- ============================================
local BlockPrinterTab = Window:CreateTab("Block Printer")

local PathfindingService = game:GetService("PathfindingService")

if isfolder and makefolder and not isfolder("autoBuilder") then
    makefolder("autoBuilder")
end

local placeDelay = 0.01
local retryDelay = 0.04
local verifyWaitTime = 1.5
local rounding = 0.1
local maxTriesPerBlock = 3

local selectedFile = nil
local isBuilding = false

local moveToBuildPosition = true
local movementThreshold = 60
local walkOffset = 15
local moveTimeout = 4
local waypointTimeout = 2.2

local floatPartName = "BuilderFloatPlatform"
local floating = false
local floatOffset = -3.1
local floatDownAmount = 0.5
local floatUpAmount = 1.5
local floatDownKey = Enum.KeyCode.Z
local floatUpKey = Enum.KeyCode.X
local hbConn
local keyDownConn
local keyUpConn
local deathConn

local VirtualInputManager
pcall(function()
    VirtualInputManager = game:GetService("VirtualInputManager")
end)

local function getRoot(char)
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getCharacterParts()
    local char = LP.Character or LP.CharacterAdded:Wait()
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    return char, humanoid, hrp
end

local function pressShift()
    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game)
        end)
    end
end

local function releaseShift()
    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
        end)
    end
end

local function cleanupFloat()
    if hbConn then
        hbConn:Disconnect()
        hbConn = nil
    end
    if keyDownConn then
        keyDownConn:Disconnect()
        keyDownConn = nil
    end
    if keyUpConn then
        keyUpConn:Disconnect()
        keyUpConn = nil
    end
    if deathConn then
        deathConn:Disconnect()
        deathConn = nil
    end

    local char = LP.Character
    if char then
        local old = char:FindFirstChild(floatPartName)
        if old then
            old:Destroy()
        end
    end

    floating = false
    floatOffset = -3.1
end

local function enableFloat()
    local char = LP.Character or LP.CharacterAdded:Wait()
    local root = getRoot(char)
    if not root then
        return
    end

    if char:FindFirstChild(floatPartName) then
        return
    end

    floating = true

    local floatPart = Instance.new("Part")
    floatPart.Name = floatPartName
    floatPart.Transparency = 1
    floatPart.Size = Vector3.new(2, 0.2, 1.5)
    floatPart.Anchored = true
    floatPart.CanCollide = true
    floatPart.Parent = char
    floatPart.CFrame = root.CFrame * CFrame.new(0, floatOffset, 0)

    keyDownConn = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then
            return
        end

        if input.KeyCode == floatDownKey then
            floatOffset -= floatDownAmount
        elseif input.KeyCode == floatUpKey then
            floatOffset += floatUpAmount
        end
    end)

    keyUpConn = UserInputService.InputEnded:Connect(function(input, gp)
        if gp then
            return
        end

        if input.KeyCode == floatDownKey then
            floatOffset += floatDownAmount
        elseif input.KeyCode == floatUpKey then
            floatOffset -= floatUpAmount
        end
    end)

    hbConn = game:GetService("RunService").Heartbeat:Connect(function()
        local currentChar = LP.Character
        local currentRoot = getRoot(currentChar)

        if not floating or not currentChar or not currentRoot or not floatPart.Parent then
            cleanupFloat()
            return
        end

        floatPart.CFrame = currentRoot.CFrame * CFrame.new(0, floatOffset, 0)
    end)

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        deathConn = humanoid.Died:Connect(function()
            cleanupFloat()
        end)
    end
end

local function toggleFloat(v)
    if v == nil then
        if floating then
            cleanupFloat()
        else
            enableFloat()
        end
    else
        if v then
            if not floating then
                enableFloat()
            end
        else
            cleanupFloat()
        end
    end
end

local function roundToStep(n, step)
    return math.floor((n / step) + 0.5) * step
end

local function vectorKey(v)
    return table.concat({
        tostring(roundToStep(v.X, rounding)),
        tostring(roundToStep(v.Y, rounding)),
        tostring(roundToStep(v.Z, rounding))
    }, "|")
end

local function makeBlockKey(blockType, cf)
    return tostring(blockType) .. "@" .. vectorKey(cf.Position)
end

local function arrayToCFrame(a)
    local pos = Vector3.new(a[1], a[2], a[3])
    local right = Vector3.new(a[4], a[5], a[6])
    local up = Vector3.new(a[7], a[8], a[9])
    return CFrame.fromMatrix(pos, right, up)
end

local function getFiles()
    local files = {}

    for _, file in ipairs(listfiles("autoBuilder")) do
        local lower = string.lower(file)
        if lower:sub(-4) == ".txt" or lower:sub(-5) == ".json" then
            table.insert(files, file:match("[^/\\]+$"))
        end
    end

    table.sort(files)
    return files
end

local function getNearestIsland()
    local islandsFolder = WS:FindFirstChild("Islands")
    if not islandsFolder then
        return nil
    end

    local _, _, hrp = getCharacterParts()
    if not hrp then
        return nil
    end

    local closestIsland = nil
    local closestDistance = math.huge

    for _, child in ipairs(islandsFolder:GetChildren()) do
        if child:IsA("Model") then
            local pivot = child:GetPivot()
            local dist = (pivot.Position - hrp.Position).Magnitude
            if dist < closestDistance then
                closestDistance = dist
                closestIsland = child
            end
        end
    end

    return closestIsland
end

local function getBlocksFolder()
    local island = getNearestIsland()
    if not island then
        return nil
    end

    return island:FindFirstChild("Blocks")
end

local function buildExistingBlockMap()
    local blocksFolder = getBlocksFolder()
    if not blocksFolder then
        return {}
    end

    local existingMap = {}
    local blocks = blocksFolder:GetChildren()

    for i = 1, #blocks do
        local block = blocks[i]
        if block:IsA("BasePart") then
            if block.Name ~= "portalToSpawn" and block.Name ~= "bedrock" then
                local key = makeBlockKey(block.Name, block.CFrame)
                existingMap[key] = true
            end
        end

        if i % 3000 == 0 then
            task.wait()
        end
    end

    return existingMap
end

local function getPlacedAndMissingBlocks(targetBlocks)
    local existingMap = buildExistingBlockMap()
    local placed = {}
    local missing = {}

    for i, block in ipairs(targetBlocks) do
        local cf = arrayToCFrame(block.cframe)
        local key = makeBlockKey(block.blockType, cf)

        if existingMap[key] then
            table.insert(placed, block)
        else
            table.insert(missing, block)
        end

        if i % 3000 == 0 then
            task.wait()
        end
    end

    return placed, missing
end

local function getMissingBlocks(targetBlocks)
    local _, missing = getPlacedAndMissingBlocks(targetBlocks)
    return missing
end

local net = RS
    :WaitForChild("rbxts_include")
    :WaitForChild("node_modules")
    :WaitForChild("@rbxts")
    :WaitForChild("net")
    :WaitForChild("out")
    :WaitForChild("_NetManaged")
    :WaitForChild("CLIENT_BLOCK_PLACE_REQUEST")

local function placeRawBlock(blockType, cf, upperBlock)
    local args = {{
        uwhiHAMdjExWka = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nffEgdldU",
        cframe = cf,
        blockType = blockType,
        upperBlock = upperBlock == true
    }}

    local ok, err = pcall(function()
        net:InvokeServer(unpack(args))
    end)

    if not ok then
        warn("Place failed:", blockType, err)
    end

    return ok
end

local function blockExists(block)
    local blocksFolder = getBlocksFolder()
    if not blocksFolder then
        return false
    end

    local cf = arrayToCFrame(block.cframe)
    local key = makeBlockKey(block.blockType, cf)

    for _, part in ipairs(blocksFolder:GetChildren()) do
        if part:IsA("BasePart") and part.Name == block.blockType then
            local existingKey = makeBlockKey(part.Name, part.CFrame)
            if existingKey == key then
                return true
            end
        end
    end

    return false
end

local function getAdaptiveWalkTarget(targetPos, hrpPos)
    local dir = hrpPos - targetPos
    if dir.Magnitude < 0.01 then
        dir = Vector3.new(0, 0, -1)
    else
        dir = dir.Unit
    end

    local yDelta = targetPos.Y - hrpPos.Y
    local verticalOffset = math.clamp(yDelta + 2, -8, 18)

    return targetPos + (dir * walkOffset) + Vector3.new(0, verticalOffset, 0)
end

local function moveToPoint(point)
    local _, humanoid = getCharacterParts()
    if not humanoid then
        return false
    end

    humanoid:MoveTo(point)

    local reached = false
    local conn
    conn = humanoid.MoveToFinished:Connect(function(ok)
        reached = ok or true
    end)

    local start = tick()
    while not reached and (tick() - start) < waypointTimeout do
        task.wait(0.05)
        if not isBuilding then
            break
        end
    end

    if conn then
        conn:Disconnect()
    end

    return reached
end

local function pathfindWalkTo(targetPoint)
    local _, humanoid, hrp = getCharacterParts()
    if not humanoid or not hrp then
        return false
    end

    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = true,
        WaypointSpacing = 4
    })

    local success = pcall(function()
        path:ComputeAsync(hrp.Position, targetPoint)
    end)

    if not success or path.Status ~= Enum.PathStatus.Success then
        pressShift()
        local ok = moveToPoint(targetPoint)
        releaseShift()
        return ok
    end

    local waypoints = path:GetWaypoints()
    if #waypoints == 0 then
        pressShift()
        local ok = moveToPoint(targetPoint)
        releaseShift()
        return ok
    end

    pressShift()

    for _, waypoint in ipairs(waypoints) do
        if not isBuilding then
            break
        end

        if waypoint.Action == Enum.PathWaypointAction.Jump then
            humanoid.Jump = true
        end

        moveToPoint(waypoint.Position)
    end

    releaseShift()
    return true
end

local function moveNearBlock(block)
    if not moveToBuildPosition then
        return
    end

    local _, _, hrp = getCharacterParts()
    if not hrp then
        return
    end

    local targetCF = arrayToCFrame(block.cframe)
    local targetPos = targetCF.Position
    local distance = (hrp.Position - targetPos).Magnitude

    if distance <= movementThreshold then
        return
    end

    local walkTarget = getAdaptiveWalkTarget(targetPos, hrp.Position)
    pathfindWalkTo(walkTarget)
end

local function placeBlock(block)
    moveNearBlock(block)
    return placeRawBlock(block.blockType, arrayToCFrame(block.cframe), block.upperBlock == true)
end

local function placeBlockList(blockList, delayTime)
    local failed = {}

    for i, block in ipairs(blockList) do
        if not isBuilding then
            break
        end

        local placed = false
        local tries = 0

        while not placed and tries < maxTriesPerBlock and isBuilding do
            tries += 1
            placeBlock(block)
            task.wait(delayTime)
            placed = blockExists(block)

            if not placed then
                task.wait(retryDelay)
            end
        end

        if not placed then
            table.insert(failed, block)
        end

        if i % 150 == 0 then
            task.wait()
        end
    end

    return failed
end

local function loadSelectedBuild()
    if not isfile or not readfile then
        updateNotification("Error", "File system not available!", 3)
        return nil
    end
    
    if not selectedFile or selectedFile == "" then
        updateNotification("No File Selected", "Please select a build file first", 3)
        return nil
    end

    local path = "autoBuilder/" .. selectedFile

    if not isfile(path) then
        updateNotification("Error", "File not found: " .. tostring(selectedFile), 4)
        return nil
    end

    local text = readfile(path)
    local success, data = pcall(function()
        return HttpService:JSONDecode(text)
    end)

    if not success or type(data) ~= "table" or type(data.blocks) ~= "table" then
        updateNotification("Error", "Invalid build JSON", 4)
        return nil
    end

    return data
end

local function runBuild(blocks, missingOnly)
    if isBuilding then
        updateNotification("Busy", "Builder is already running", 3)
        return
    end

    isBuilding = true

    task.spawn(function()
        if missingOnly then
            updateNotification("Scanning", "Checking placed and missing blocks...", 4)
            local placed, missing = getPlacedAndMissingBlocks(blocks)

            updateNotification("Scan Complete", "Placed: " .. #placed .. " | Missing: " .. #missing, 5)

            if #missing == 0 then
                isBuilding = false
                updateNotification("Nothing Missing", "All blocks are already placed", 4)
                return
            end

            local pass = 1
            local currentMissing = missing

            while isBuilding and #currentMissing > 0 do
                updateNotification("Missing Block Pass", "Pass " .. pass .. ": placing " .. #currentMissing .. " blocks", 4)

                local failed = placeBlockList(currentMissing, placeDelay)
                task.wait(verifyWaitTime)

                currentMissing = getMissingBlocks(blocks)
                pass += 1

                if #failed > 0 and #failed == #currentMissing and pass >= 4 then
                    break
                end
            end

            isBuilding = false

            local finalMissing = getMissingBlocks(blocks)
            if #finalMissing == 0 then
                updateNotification("Done", "All missing blocks have been placed", 5)
            else
                updateNotification("Finished With Skips", "Still missing " .. #finalMissing .. " block(s)", 6)
            end
        else
            updateNotification("Building Started", "Placing " .. #blocks .. " blocks", 4)

            local failed = placeBlockList(blocks, placeDelay)
            task.wait(verifyWaitTime)

            local missing = getMissingBlocks(blocks)
            local pass = 1

            while isBuilding and #missing > 0 do
                updateNotification("Retry Pass", "Pass " .. pass .. ": retrying " .. #missing .. " missing blocks", 4)

                failed = placeBlockList(missing, retryDelay)
                task.wait(verifyWaitTime)

                local newMissing = getMissingBlocks(blocks)
                if #newMissing == #missing and pass >= 4 then
                    missing = newMissing
                    break
                end

                missing = newMissing
                pass += 1
            end

            isBuilding = false

            if #missing == 0 then
                updateNotification("Build Complete", "All blocks placed successfully", 5)
            else
                updateNotification("Finished With Skips", "Could not place " .. #missing .. " block(s)", 6)
            end
        end

        releaseShift()
    end)
end

local fileDropdown = BlockPrinterTab:CreateDropdown({
    Name = "Select Build File",
    Options = getFiles(),
    CurrentOption = {},
    MultipleOptions = false,
    Flag = "FileDropdown",
    Callback = function(option)
        if typeof(option) == "table" then
            selectedFile = option[1]
        else
            selectedFile = option
        end
    end
})

BlockPrinterTab:CreateButton({
    Name = "Refresh Files",
    Callback = function()
        fileDropdown:Refresh(getFiles())
    end
})

BlockPrinterTab:CreateToggle({
    Name = "Move Near Block Before Placing",
    CurrentValue = true,
    Flag = "MoveNearBlock",
    Callback = function(v)
        moveToBuildPosition = v
    end
})

BlockPrinterTab:CreateButton({
    Name = "Build Selected File",
    Callback = function()
        local data = loadSelectedBuild()
        if not data then
            return
        end

        runBuild(data.blocks, false)
    end
})

BlockPrinterTab:CreateButton({
    Name = "Place Missing Blocks Only",
    Callback = function()
        local data = loadSelectedBuild()
        if not data then
            return
        end

        runBuild(data.blocks, true)
    end
})

BlockPrinterTab:CreateButton({
    Name = "Stop Build",
    Callback = function()
        isBuilding = false
        releaseShift()
        updateNotification("Stopped", "Build process stopped", 3)
    end
})

BlockPrinterTab:CreateToggle({
    Name = "Float Platform",
    CurrentValue = false,
    Flag = "FloatPlatformToggle",
    Callback = function(v)
        toggleFloat(v)
    end
})

BlockPrinterTab:CreateSlider({
    Name = "Down Move Amount",
    Range = {0.1, 3},
    Increment = 0.1,
    CurrentValue = 0.5,
    Flag = "FloatDownAmount",
    Callback = function(v)
        floatDownAmount = v
    end
})

BlockPrinterTab:CreateSlider({
    Name = "Up Move Amount",
    Range = {0.1, 3},
    Increment = 0.1,
    CurrentValue = 1.5,
    Flag = "FloatUpAmount",
    Callback = function(v)
        floatUpAmount = v
    end
})

BlockPrinterTab:CreateParagraph({
    Title = "Float Keybinds",
    Content = "Down: Z | Up: X"
})

BlockPrinterTab:CreateButton({
    Name = "Toggle Float Now",
    Callback = function()
        toggleFloat()
    end
})

BlockPrinterTab:CreateSection("Build Saver")

BlockPrinterTab:CreateParagraph({
    Title = "Save Island Blueprint",
    Content = "Saves your island as a JSON file that can be used with Auto Build. Creates a .json file in the autoBuilder folder."
})

local function cfToArray(cf)
    local pos = cf.Position
    local r = cf.RightVector
    local u = cf.UpVector
    local l = cf.LookVector

    return {
        pos.X, pos.Y, pos.Z,
        r.X, r.Y, r.Z,
        u.X, u.Y, u.Z
    }
end

local saveFileName = "island_blueprint"

BlockPrinterTab:CreateInput({
    Name = "Blueprint Name",
    PlaceholderText = "island_blueprint",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        if text and text ~= "" then
            saveFileName = text:gsub("[^%w_-]", "")
        end
    end
})

BlockPrinterTab:CreateButton({
    Name = "Save Island Blueprint",
    Callback = function()
        task.spawn(function()
            pcall(function()
                if isfolder and makefolder and not isfolder("autoBuilder") then
                    makefolder("autoBuilder")
                end

                local islandsFolder = WS:FindFirstChild("Islands")
                if not islandsFolder then
                    updateNotification("Error", "Islands folder not found!", 3)
                    return
                end

                local island = getNearestIsland()
                if not island then
                    updateNotification("Error", "No island found!", 3)
                    return
                end

                local blocksFolder = island:FindFirstChild("Blocks")
                if not blocksFolder then
                    updateNotification("Error", "Blocks folder not found!", 3)
                    return
                end

                local blocks = blocksFolder:GetChildren()
                local blocksData = {}
                local index = 1

                updateNotification("Saving", "Processing " .. #blocks .. " blocks...", 5)

                for i = 1, #blocks do
                    local block = blocks[i]

                    if block.Name ~= "portalToSpawn" and block.Name ~= "bedrock" and block.Name ~= "Collision" then
                        if block:IsA("BasePart") then
                            blocksData[index] = {
                                cframe = cfToArray(block.CFrame),
                                blockType = block.Name
                            }
                            index = index + 1
                        end
                    end

                    if i % 5000 == 0 then
                        task.wait()
                    end
                end

                local finalFileName = saveFileName
                if not finalFileName:match("%.json$") then
                    finalFileName = finalFileName .. ".json"
                end

                local json = HttpService:JSONEncode({
                    blocks = blocksData
                })

                local filePath = "autoBuilder/" .. finalFileName
                if writefile then writefile(filePath, json) end

                updateNotification("Success", "Saved " .. (index - 1) .. " blocks to " .. finalFileName, 5)
            end)
        end)
    end
})



local AutomationTab = Window:CreateTab("Automation")

AutomationTab:CreateSection("Auto-Restock Vendings")

local autoRestockEnabled = false
local restockItem = "grassBlock"
local restockAmount = 100
local restockInterval = 30

AutomationTab:CreateParagraph({Title = "Auto-Restock Info", Content = "Automatically restocks selected vendings with items from your inventory at set intervals."})

AutomationTab:CreateInput({Name = "Item to Restock", PlaceholderText = "Enter item name", RemoveTextAfterFocusLost = false, Callback = function(text)
 if text and text ~= "" then
  restockItem = text
  updateNotification("Auto-Restock", "Item: " .. text, 2)
 end
end})

AutomationTab:CreateInput({Name = "Restock Amount", PlaceholderText = "Enter amount", RemoveTextAfterFocusLost = false, Callback = function(text)
 local num = parseAmount(text) or tonumber(text)
 if num then
  restockAmount = num
  updateNotification("Auto-Restock", "Amount: " .. formatNumber(num), 2)
 end
end})

AutomationTab:CreateSlider({Name = "Restock Interval (seconds)", Range = {10, 300}, Increment = 10, CurrentValue = 30, Callback = function(value)
 restockInterval = value
end})

AutomationTab:CreateToggle({Name = "Enable Auto-Restock", CurrentValue = false, Callback = function(value)
 autoRestockEnabled = value
 
 if value then
  updateNotification("Auto-Restock", "Enabled! Interval: " .. restockInterval .. "s", 3)
  
  task.spawn(function()
   while autoRestockEnabled do
    wait(restockInterval)
    
    pcall(function()
     local vendings = #selectedFavorites > 0 and selectedFavorites or findVendings()
     
     if #vendings == 0 then
      updateNotification("Auto-Restock", "No vendings found!", 2)
      return
     end
     
     local tool = LP.Backpack:FindFirstChild(restockItem) or (LP.Character and LP.Character:FindFirstChild(restockItem))
     
     if not tool then
      updateNotification("Auto-Restock", "Item not in inventory: " .. restockItem, 3)
      return
     end
     
     local Net = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
     local ItemRemote = Net:WaitForChild("deGzdggahhjo/yeuvbxxakbeqDdlofjxFiBwq")
     
     local restockedCount = 0
     
     for _, vending in ipairs(vendings) do
      if not autoRestockEnabled then break end
      
      pcall(function()
       -- Check if vending already has items
       local sellingContents = vending:FindFirstChild("SellingContents")
       local currentItem = sellingContents and sellingContents:FindFirstChild(restockItem)
       
       if currentItem then
        -- Item exists - add restockAmount to it
        local currentAmount = currentItem:FindFirstChild("Amount") and currentItem.Amount.Value or 0
        local guid = HttpService:GenerateGUID(false)
        
        ItemRemote:FireServer(guid, {{
         player_tracking_category = "join_from_web",
         amount = restockAmount,
         vendingMachine = vending,
         tool = tool,
         action = "deposit"
        }})
        
        restockedCount = restockedCount + 1
       else
        -- Item doesn't exist - deposit new stack
        local guid = HttpService:GenerateGUID(false)
        
        ItemRemote:FireServer(guid, {{
         player_tracking_category = "join_from_web",
         amount = restockAmount,
         vendingMachine = vending,
         tool = tool,
         action = "deposit"
        }})
        
        restockedCount = restockedCount + 1
       end
       
       wait(0.1)
      end)
     end
     
     updateNotification("Auto-Restock", "Restocked " .. restockedCount .. " vendings with +" .. formatNumber(restockAmount) .. "x " .. restockItem, 3)
    end)
   end
  end)
 else
  updateNotification("Auto-Restock", "Disabled", 2)
 end
end})

AutomationTab:CreateSection("Bank to Vendings Automation")
local bankAutoEnabled, bankAutoAmount, bankAutoTimer = false, 1500000000, 10
AutomationTab:CreateParagraph({Title = "How It Works", Content = "Withdraws coins from bank and deposits to vendings. Smart distribution - fills up to 5B limit then moves to next vending."})
AutomationTab:CreateInput({Name = "Withdraw Amount", PlaceholderText = "Enter amount", RemoveTextAfterFocusLost = false, Callback = function(text) local num = parseAmount(text) or tonumber(text) if num then bankAutoAmount = num updateNotification("Bank Auto", "Set to " .. formatNumber(num), 2) end end})
AutomationTab:CreateSlider({Name = "Cycle Timer (seconds)", Range = {1, 60}, Increment = 1, CurrentValue = 10, Callback = function(value) bankAutoTimer = value end})
AutomationTab:CreateToggle({Name = "Enable Bank Auto-Deposit", CurrentValue = false, Callback = function(value)
 if value and bankAutoEnabled then 
  updateNotification("Error", "Already running!", 2) 
  return 
 end
 bankAutoEnabled = value
 if value then
  updateNotification("Bank Automation", "Enabled! Cycle: " .. bankAutoTimer .. "s", 3)
  task.spawn(function()
   while bankAutoEnabled do
    -- Network check removed
    pcall(function()
     local guid = HttpService:GenerateGUID(false)
     game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("GetBankAccount"):FireServer(guid, {{accountType = "PERSONAL"}})
     wait(0.1)
     game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("TransactionBankBalance"):FireServer(HttpService:GenerateGUID(false), {{accountType = "PERSONAL", transferType = "WITHDRAWAL", amount = bankAutoAmount}})
     wait(0.5)
     
     -- Use selected vendings if any, otherwise all vendings
     local vendings
     if #selectedFavorites > 0 then
      vendings = selectedFavorites
     else
      vendings = findVendings()
     end
     
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
        task.spawn(function() 
         depositCoinsToVending(vending, depositAmount) 
        end)
        remainingAmount = remainingAmount - depositAmount
        vendingsUsed = vendingsUsed + 1
        task.wait(0.1)
       end
      end
      updateNotification("Bank Auto", "Deposited " .. formatNumber(bankAutoAmount - remainingAmount) .. " to " .. vendingsUsed .. " vendings", 3)
     end
    end)
    wait(bankAutoTimer)
   end
  end)
 else
  updateNotification("Bank Automation", "Disabled", 2)
 end
end})



AutomationTab:CreateSection("Vending Auto Stocker")
local stockerEnabled, stockerAmount, stockerTimer, stockerMode = false, 5, 15, "Deposit All"
AutomationTab:CreateParagraph({Title = "How It Works", Content = "Picks a RANDOM item from your backpack and deposits it to vendings. Choose Deposit All or Split mode."})
AutomationTab:CreateInput({Name = "Item Amount", PlaceholderText = "Amount per cycle...", RemoveTextAfterFocusLost = false, Callback = function(text) local num = tonumber(text) if num then stockerAmount = num end end})
AutomationTab:CreateSlider({Name = "Cycle Timer (seconds)", Range = {1, 120}, Increment = 1, CurrentValue = 15, Callback = function(value) stockerTimer = value end})
AutomationTab:CreateDropdown({Name = "Deposit Mode", Options = {"Deposit All", "Split"}, CurrentOption = {"Deposit All"}, MultipleOptions = false, Callback = function(option) stockerMode = option[1] end})
AutomationTab:CreateToggle({Name = "Enable Auto Stocker", CurrentValue = false, Callback = function(value)
 stockerEnabled = value
 if value then
  updateNotification("Auto Stocker", "Enabled! Cycle: " .. stockerTimer .. "s", 3)
  task.spawn(function()
   while stockerEnabled do
    refreshItems()
    if #itemOptions > 0 and itemOptions[1] ~= "No items" then
     local randomItem = itemOptions[math.random(1, #itemOptions)]
     selectedItemName = randomItem
     local vendings = findVendings()
     if #vendings > 0 then
      if stockerMode == "Deposit All" then
       for _, vending in ipairs(vendings) do task.spawn(function() depositItemToVending(vending, randomItem, stockerAmount) end) end
       updateNotification("Auto Stocker", "Deposited " .. stockerAmount .. "x " .. randomItem .. " to " .. #vendings, 2)
      else
       local perVending = math.floor(stockerAmount / #vendings)
       for _, vending in ipairs(vendings) do task.spawn(function() depositItemToVending(vending, randomItem, perVending) end) end
       updateNotification("Auto Stocker", "Split " .. stockerAmount .. "x " .. randomItem .. " to " .. #vendings, 2)
      end
     end
    end
    wait(stockerTimer)
   end
  end)
 else
  updateNotification("Auto Stocker", "Disabled", 2)
 end
end})

-- ============================================
-- FARMING TAB
-- ============================================
local FarmingTab = Window:CreateTab("Farming")

FarmingTab:CreateSection("Crop Farming")

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

local cropList = {
 "(Select/None)",
 "Wheat", "Tomato", "Potato", "Carrot", "Onion",
 "Cactus", "Spinach", "Pumpkin", "Radish", "Chili",
 "Spirit", "Starfruit", "Melon", "Rice", "Seaweed",
 "Candy Cane", "Pineapple", "Dragonfruit", "Grape", "Void Parasite",
 "Berry Bush"
}

FarmingTab:CreateDropdown({Name = "Selected Crop", Options = cropList, CurrentOption = {"(Select/None)"}, MultipleOptions = false, Callback = function(option)
 if option[1] == "(Select/None)" then
  selectedCrop = nil
 else
  local cropName = option[1]
  if cropName == "Candy Cane" then
   selectedCrop = "candyCaneVine"
  elseif cropName == "Grape" then
   selectedCrop = "grapeVine"
  elseif cropName == "Chili" then
   selectedCrop = "chiliPepper"
  elseif cropName == "Spirit" then
   selectedCrop = "spiritCrop"
  elseif cropName == "Void Parasite" then
   selectedCrop = "voidParasite"
  elseif cropName == "Berry Bush" then
   selectedCrop = "berryBush"
  else
   selectedCrop = cropName:lower()
  end
 end
end})

local CropCounter = 0
local NeverExecutedBefore = false
local GetCrops

FarmingTab:CreateToggle({Name = "Farm Crops", CurrentValue = false, Callback = function(value)
 farmCropsEnabled = value
 if value then
  if not selectedCrop then
   updateNotification("Error", "Please select a crop first!", 3)
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
     
     -- SAVE positions BEFORE harvesting (only what will be harvested)
     local savedPositions = {}
     if replaceCropsEnabled then
      for _, crop in pairs(SelectedCrop) do
       if crop and crop.CFrame then
        table.insert(savedPositions, crop.CFrame)
       end
      end
     end
     
     -- Harvest crops
     Net:WaitForChild("SwingSickle"):InvokeServer("sickleDiamond", SelectedCrop)
     
     -- Replace crops ALL AT ONCE (no delays)
     if replaceCropsEnabled and #savedPositions > 0 then
      task.wait(0.5) -- Single wait after harvesting
      for _, cframe in pairs(savedPositions) do
       if not farmCropsEnabled then break end
       -- Spawn all placements simultaneously
       task.spawn(function()
        pcall(function()
         local args = {{
          uwhiHAMdjExWka = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nffEgdldU",
          cframe = cframe,
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
  updateNotification("Farm Crops", "Enabled", 2)
 else
  updateNotification("Farm Crops", "Disabled", 2)
 end
end})

FarmingTab:CreateToggle({Name = "Replace Crops", CurrentValue = false, Callback = function(value)
 replaceCropsEnabled = value
end})

-- Plant Crops in Radius (Expanding from Center)
local plantCropsEnabled = false

FarmingTab:CreateToggle({Name = "Plant Crops in Radius", CurrentValue = false, Callback = function(value)
 if value then
  if not selectedCrop then
   updateNotification("Error", "Please select a crop first!", 3)
   return
  end
  
  task.spawn(function()
   pcall(function()
    if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
     local hrp = LP.Character.HumanoidRootPart
     local playerPos = hrp.Position
     
     -- Wait for main to load
     LP:WaitForChild("main", 5)
     
     local Net = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
     
     -- Get radius
     local radius = vendingRadius or 100
     local spacing = 4
     
     -- Calculate positions in expanding spiral from center
     local positions = {}
     
     -- Start from center and expand outward
     for ring = 0, math.floor(radius / spacing) do
      local ringRadius = ring * spacing
      if ringRadius > radius then break end
      
      -- For each ring, add positions in a circle
      if ring == 0 then
       -- Center position
       table.insert(positions, {pos = playerPos, distance = 0})
      else
       -- Calculate positions around the ring
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
     
     -- Sort by distance (closest first)
     table.sort(positions, function(a, b) return a.distance < b.distance end)
     
     -- Plant all simultaneously
     local planted = 0
     for _, data in ipairs(positions) do
      if not IsTaken(data.pos) then
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
     
     updateNotification("Planted " .. planted .. " crops", "", 2)
    end
   end)
  end)
 end
end})

-- Auto Walk to Crops
local autoWalkEnabled = false
local autoWalkTween = nil

FarmingTab:CreateToggle({Name = "Auto Walk to Crops", CurrentValue = false, Callback = function(value)
 autoWalkEnabled = value
 if value then
  if not selectedCrop then
   updateNotification("Error", "Please select a crop first!", 3)
   autoWalkEnabled = false
   return
  end
  
  if not NeverExecutedBefore then
   GetCrops = CropHandler.new()
   NeverExecutedBefore = true
  end
  
  updateNotification("Auto Walk to Crops", "Enabled", 2)
  task.spawn(function()
   local lastPosition = nil
   local stuckCounter = 0
   local lastJumpTime = 0
   local lastNotificationTime = 0
   
   while autoWalkEnabled do
    task.wait(0.5)
    pcall(function()
     if not LP or not LP.Character then return end
     local humanoid = LP.Character:FindFirstChild("Humanoid")
     local hrp = LP.Character:FindFirstChild("HumanoidRootPart")
     if not humanoid or not hrp then return end
     
     -- Enable noclip
     for _, part in pairs(LP.Character:GetDescendants()) do
      if part:IsA("BasePart") then
       part.CanCollide = false
      end
     end
     
     -- Get ready crops
     local readyCrops = GetCrops:Get(selectedCrop)
     if not readyCrops or #readyCrops == 0 then
      -- Only notify every 3 seconds
      local currentTime = tick()
      if currentTime - lastNotificationTime >= 3 then
       updateNotification("No Ready Crops", "Waiting for crops to grow...", 1)
       lastNotificationTime = currentTime
      end
      return
     end
     
     -- Find nearest crop
     local nearestCrop = nil
     local nearestDistance = math.huge
     
     for _, crop in pairs(readyCrops) do
      if crop and crop:IsDescendantOf(workspace) and crop.Position then
       local distance = (hrp.Position - crop.Position).Magnitude
       if distance < nearestDistance then
        nearestDistance = distance
        nearestCrop = crop
       end
      end
     end
     
     if not nearestCrop then return end
     
     -- Check if stuck
     local currentPos = hrp.Position
     if lastPosition then
      local distanceMoved = (currentPos - lastPosition).Magnitude
      if distanceMoved < 0.5 then
       stuckCounter = stuckCounter + 1
       if stuckCounter >= 4 then
        local currentTime = tick()
        if currentTime - lastJumpTime > 1 then
         humanoid.Jump = true
         lastJumpTime = currentTime
         task.wait(0.3)
        end
        -- Try going around
        local directionToTarget = (nearestCrop.Position - hrp.Position).Unit
        local rightVector = Vector3.new(-directionToTarget.Z, 0, directionToTarget.X)
        local avoidDirection = stuckCounter % 2 == 0 and rightVector or -rightVector
        local avoidPosition = hrp.Position + (avoidDirection * 5) + (directionToTarget * 3)
        humanoid:MoveTo(avoidPosition)
        task.wait(1)
        stuckCounter = 0
       end
      else
       stuckCounter = 0
      end
     end
     lastPosition = currentPos
     
     -- Move to nearest crop
     if nearestDistance > 5 then
      humanoid:MoveTo(nearestCrop.Position)
     end
    end)
   end
   
   -- Re-enable collisions when stopped
   if LP.Character then
    for _, part in pairs(LP.Character:GetDescendants()) do
     if part:IsA("BasePart") then
      part.CanCollide = true
     end
    end
   end
  end)
 else
  pcall(function()
   if LP.Character and LP.Character:FindFirstChild("Humanoid") then
    LP.Character.Humanoid:Move(Vector3.new(0, 0, 0))
   end
   -- Re-enable collisions
   if LP.Character then
    for _, part in pairs(LP.Character:GetDescendants()) do
     if part:IsA("BasePart") then
      part.CanCollide = true
     end
    end
   end
  end)
  updateNotification("Auto Walk to Crops", "Disabled", 2)
 end
end})

FarmingTab:CreateSection("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- Auto Eat System
local autoEatEnabled = false
local autoEatItem1 = nil
local autoEatItem2 = nil
local autoEatItem3 = nil
local autoEatCooldown = 900

-- Build food list with display names for searching
local FoodItemsDisplay = {}
local FoodItemsToolNames = {}
for _,v in next, RS.Tools:GetChildren() do
    if v:FindFirstChild("food") then
        local displayName = v:FindFirstChild("DisplayName") and v.DisplayName.Value or v.Name
        table.insert(FoodItemsDisplay, displayName)
        FoodItemsToolNames[displayName] = v.Name
    end
end
table.sort(FoodItemsDisplay)

FarmingTab:CreateInput({Name = "Search 1st Item", PlaceholderText = "Type food name...", RemoveTextAfterFocusLost = false, Callback = function(text)
 local searchLower = text:lower()
 for _, displayName in ipairs(FoodItemsDisplay) do
  if displayName:lower():find(searchLower) then
   autoEatItem1 = FoodItemsToolNames[displayName]
   updateNotification("1st Item", "Set to: " .. displayName, 1)
   break
  end
 end
end})

FarmingTab:CreateInput({Name = "Search 2nd Item", PlaceholderText = "Type food name...", RemoveTextAfterFocusLost = false, Callback = function(text)
 local searchLower = text:lower()
 for _, displayName in ipairs(FoodItemsDisplay) do
  if displayName:lower():find(searchLower) then
   autoEatItem2 = FoodItemsToolNames[displayName]
   updateNotification("2nd Item", "Set to: " .. displayName, 1)
   break
  end
 end
end})

FarmingTab:CreateInput({Name = "Search 3rd Item", PlaceholderText = "Type food name...", RemoveTextAfterFocusLost = false, Callback = function(text)
 local searchLower = text:lower()
 for _, displayName in ipairs(FoodItemsDisplay) do
  if displayName:lower():find(searchLower) then
   autoEatItem3 = FoodItemsToolNames[displayName]
   updateNotification("3rd Item", "Set to: " .. displayName, 1)
   break
  end
 end
end})

FarmingTab:CreateInput({Name = "Cooldown (seconds)", PlaceholderText = "900", RemoveTextAfterFocusLost = false, Callback = function(text)
 local num = tonumber(text)
 if num and num > 0 then
  autoEatCooldown = num
 end
end})

FarmingTab:CreateToggle({Name = "Auto Eat Food", CurrentValue = false, Callback = function(value)
 autoEatEnabled = value
 if value then
  task.spawn(function()
   while autoEatEnabled do
    for _,v in next, {autoEatItem1, autoEatItem2, autoEatItem3} do 
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
  updateNotification("Auto Eat", "Enabled", 2)
 else
  updateNotification("Auto Eat", "Disabled", 2)
 end
end})

FarmingTab:CreateSection("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- Plow/UnPlow
FarmingTab:CreateSection("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- Auto Eat SystemFarmingTab:CreateToggle({Name = "Place Crops Nearby (5x5)", CurrentValue = false, Callback = function(value)
 placeCropsEnabled = value
 if value then
  if not selectedCrop then
   updateNotification("Error", "Please select a crop first!", 3)
   placeCropsEnabled = false
   return
  end
  
  task.spawn(function()
   if not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then
    updateNotification("Error", "Character not found!", 3)
    return
   end
   
   local hrp = LP.Character.HumanoidRootPart
   local playerPos = hrp.Position
   local Net = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
   
   local placed = 0
   -- 5x5 grid centered on player (-2 to +2 in X and Z)
   for x = -2, 2 do
    for z = -2, 2 do
     if not placeCropsEnabled then break end
     
     local offsetX = x * 4 -- 4 studs apart
     local offsetZ = z * 4
     local targetPos = Vector3.new(
      playerPos.X + offsetX,
      playerPos.Y,
      playerPos.Z + offsetZ
     )
     
     -- Check if position is not already taken
     if not IsTaken(targetPos) then
      pcall(function()
       local args = {{
        uwhiHAMdjExWka = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nffEgdldU",
        cframe = CFrame.new(targetPos.X, targetPos.Y, targetPos.Z, -4.371138828673793e-08, 0, -1, 0, 1, 0, 1, 0, -4.371138828673793e-08),
        blockType = selectedCrop,
        upperBlock = false
       }}
       Net:WaitForChild("CLIENT_BLOCK_PLACE_REQUEST"):InvokeServer(unpack(args))
       placed = placed + 1
      end)
      task.wait(0.1)
     end
    end
   end
   
   updateNotification("Placed Crops", "Placed " .. placed .. " crops in 5x5 grid", 2)
   placeCropsEnabled = false
  end)
 end
end})

local SettingsTab = Window:CreateTab("Settings")

SettingsTab:CreateSection("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- Performance & AFK
SettingsTab:CreateToggle({Name = "Performance Mode", CurrentValue = false, Callback = function(value)
 performanceMode = value
 if value then
  if vendingESPEnabled then
   for _, espData in ipairs(vendingESPObjects) do
    if espData.highlight then espData.highlight:Destroy() end
    if espData.billboard then espData.billboard:Destroy() end
   end
   vendingESPObjects = {}
  end
  pcall(function()
   local lighting = game:GetService("Lighting")
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
   for _, obj in pairs(WS:GetDescendants()) do
    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
     if not getgenv().PerfCache[obj] then
      getgenv().PerfCache[obj] = obj.Enabled
     end
     obj.Enabled = false
    elseif obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
     if not getgenv().PerfCache[obj] then
      getgenv().PerfCache[obj] = obj.Enabled
     end
     obj.Enabled = false
    elseif obj:IsA("MeshPart") then
     if obj.RenderFidelity ~= Enum.RenderFidelity.Performance then
      if not getgenv().PerfCache[obj] then
       getgenv().PerfCache[obj] = obj.RenderFidelity
      end
      obj.RenderFidelity = Enum.RenderFidelity.Performance
     end
    end
   end
  end)
  updateNotification("Performance", "FPS BOOST: Shadows/Effects/Particles OFF!", 3)
 else
  pcall(function()
   if getgenv().PerfCache then
    local lighting = game:GetService("Lighting")
    lighting.GlobalShadows = getgenv().PerfCache.GlobalShadows
    lighting.Technology = getgenv().PerfCache.Technology
    settings().Rendering.QualityLevel = getgenv().PerfCache.QualityLevel
    for obj, value in pairs(getgenv().PerfCache) do
     if typeof(obj) == "Instance" and obj.Parent then
      pcall(function()
       if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or
          obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") or
          obj:IsA("BloomEffect") or obj:IsA("SunRaysEffect") or 
          obj:IsA("DepthOfFieldEffect") or obj:IsA("ColorCorrectionEffect") or
          obj:IsA("BlurEffect") then
        obj.Enabled = value
       elseif obj:IsA("MeshPart") then
        obj.RenderFidelity = value
       end
      end)
     end
    end
    getgenv().PerfCache = nil
   end
  end)
  updateNotification("Performance", "Restored to normal!", 2)
 end
end})

SettingsTab:CreateToggle({Name = "Anti-AFK (Auto-Enabled)", CurrentValue = true, Callback = function(value)
 antiAFKEnabled = value
 if value then
  updateNotification("Anti-AFK", "Enabled - You won't be kicked!", 2)
 else
  updateNotification("Anti-AFK", "Disabled - You may get kicked for AFK", 3)
 end
end})

-- Player Invite/Join System
local playerActionUsername = ""
local playerActionMode = "Invite"

SettingsTab:CreateDropdown({Name = "Action Type", Options = {"Invite", "Join"}, CurrentOption = {"Invite"}, MultipleOptions = false, Callback = function(option)
 playerActionMode = option[1]
end})

SettingsTab:CreateInput({Name = "Username", PlaceholderText = "Enter username", RemoveTextAfterFocusLost = false, Callback = function(text)
 playerActionUsername = text
end})

SettingsTab:CreateButton({Name = "Apply Action", Callback = function()
 if playerActionUsername == "" then 
  updateNotification("Error", "Enter a username!", 3) 
  return 
 end
 
 if playerActionMode == "Invite" then
  task.spawn(function()
   pcall(function()
    local userId = Players:GetUserIdFromNameAsync(playerActionUsername)
    if not userId then updateNotification("Player Not Found", "", 3) return end
    
    local Net = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
    
    local args = {{userId = userId, name = playerActionUsername}}
    Net:WaitForChild("client_request_8"):InvokeServer(unpack(args))
    updateNotification("Invited " .. playerActionUsername, "", 2)
   end)
  end)
 else -- Join
  task.spawn(function()
   local success, err = pcall(function()
    -- Get userId from username
    local userId = Players:GetUserIdFromNameAsync(playerActionUsername)
    if not userId then 
     updateNotification("Error", "Player '" .. playerActionUsername .. "' not found", 3) 
     return 
    end
    
    -- Find the island owned by this userId
    local targetIsland = nil
    for _, island in pairs(workspace.Islands:GetChildren()) do
     -- Check Owner value first
     local ownerValue = island:FindFirstChild("Owner")
     if ownerValue and ownerValue.Value == userId then
      targetIsland = island
      break
     end
     
     -- Alternative: Check Owners folder
     if not targetIsland and island:FindFirstChild("Owners") then
      for _, owner in pairs(island.Owners:GetChildren()) do
       if tonumber(owner.Name) == userId then
        targetIsland = island
        break
       end
      end
     end
    end
    
    if targetIsland then
     local Net = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
     local visitRemote = Net:FindFirstChild("CLIENT_VISIT_ISLAND_REQUEST")
     if visitRemote then
      local args = {{island = targetIsland}}
      visitRemote:InvokeServer(unpack(args))
      updateNotification("Joining!", "Teleporting to " .. playerActionUsername .. "'s island", 3)
     else
      updateNotification("Error", "Visit remote not found", 3)
     end
    else
     updateNotification("Error", playerActionUsername .. " doesn't own an island or it's not loaded", 3)
    end
   end)
   
   if not success then
    updateNotification("Error", "Failed: " .. tostring(err), 3)
   end
  end)
 end
end})

SettingsTab:CreateSection("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- Process & Radius Settings
SettingsTab:CreateToggle({Name = "Process All Actions Simultaneously", CurrentValue = true, Callback = function(value) allAtOnceMode = value userSettings.processMode = value end})

SettingsTab:CreateToggle({Name = "Use Radius Limit", CurrentValue = false, Callback = function(value) useRadiusLimit = value if value then createRadiusRing() updateNotification("Radius Limit", "Enabled - " .. vendingRadius .. " studs", 2) else removeRadiusRing() updateNotification("Radius Limit", "Disabled", 2) end end})

SettingsTab:CreateSlider({Name = "Radius Distance", Range = {2, 100}, Increment = 1, CurrentValue = 100, Callback = function(value) 
 vendingRadius = value 
 userSettings.radius = value 
 if useRadiusLimit then
  if radiusConnection then radiusConnection:Disconnect() radiusConnection = nil end
  if radiusRingPart then radiusRingPart:Destroy() radiusRingPart = nil end
  createRadiusRing()
 end
end})

-- Always Day/Night
local alwaysDayEnabled = false
local alwaysNightEnabled = false

SettingsTab:CreateToggle({Name = "Always Day", CurrentValue = false, Callback = function(value)
 alwaysDayEnabled = value
 if value then
  alwaysNightEnabled = false
  spawn(function()
   while alwaysDayEnabled and task.wait() do
    game.Lighting.ClockTime = 14
   end
  end)
  updateNotification("Always Day", "Enabled", 2)
 else
  updateNotification("Always Day", "Disabled", 2)
 end
end})

SettingsTab:CreateToggle({Name = "Always Night", CurrentValue = false, Callback = function(value)
 alwaysNightEnabled = value
 if value then
  alwaysDayEnabled = false
  spawn(function()
   while alwaysNightEnabled and task.wait() do
    game.Lighting.ClockTime = 0
   end
  end)
  updateNotification("Always Night", "Enabled", 2)
 else
  updateNotification("Always Night", "Disabled", 2)
 end
end})

SettingsTab:CreateSection("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- Player Movement & ESP

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
 flyConnection = game:GetService("RunService").Heartbeat:Connect(function()
  if not flying or not bodyVelocity or not bodyGyro then 
   if flyConnection then flyConnection:Disconnect() flyConnection = nil end
   return 
  end
  local cam = workspace.CurrentCamera
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

SettingsTab:CreateToggle({Name = "Fly", CurrentValue = false, Callback = function(value)
 flying = value
 if value then
  startFly()
  updateNotification("Fly", "Enabled - WASD to move, Space/Shift up/down", 3)
 else
  stopFly()
  updateNotification("Fly", "Disabled", 2)
 end
end})

SettingsTab:CreateSlider({Name = "Fly Speed", Range = {10, 200}, Increment = 10, CurrentValue = 50, Callback = function(value)
 flySpeed = value
end})

local infiniteJumpEnabled = false
local infiniteJumpConnection = nil

SettingsTab:CreateToggle({Name = "Infinite Jump", CurrentValue = false, Callback = function(value)
 infiniteJumpEnabled = value
 if value then
  infiniteJumpConnection = UserInputService.JumpRequest:Connect(function()
   if infiniteJumpEnabled and LP.Character and LP.Character:FindFirstChild("Humanoid") then
    LP.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
   end
  end)
  updateNotification("Infinite Jump", "Enabled", 2)
 else
  if infiniteJumpConnection then
   infiniteJumpConnection:Disconnect()
   infiniteJumpConnection = nil
  end
  updateNotification("Infinite Jump", "Disabled", 2)
 end
end})

local espEnabled = false
local espConnections = {}

local function createESP(player)
 if player == LP then return end
 
 local function addESP(char)
  if not char then return end
  local hrp = char:WaitForChild("HumanoidRootPart", 5)
  if not hrp then return end
  
  local highlight = Instance.new("Highlight")
  highlight.FillColor = Color3.fromRGB(255, 0, 0)
  highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
  highlight.Parent = char
  
  local billboard = Instance.new("BillboardGui")
  billboard.AlwaysOnTop = true
  billboard.Size = UDim2.new(0, 100, 0, 50)
  billboard.StudsOffset = Vector3.new(0, 3, 0)
  billboard.Parent = char
  
  local textLabel = Instance.new("TextLabel")
  textLabel.BackgroundTransparency = 1
  textLabel.Size = UDim2.new(1, 0, 1, 0)
  textLabel.Text = player.Name
  textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
  textLabel.TextStrokeTransparency = 0
  textLabel.TextScaled = true
  textLabel.Parent = billboard
 end
 
 if player.Character then
  addESP(player.Character)
 end
 
 espConnections[player] = player.CharacterAdded:Connect(function(char)
  if espEnabled then
   addESP(char)
  end
 end)
end

local function removeESP(player)
 if player.Character then
  for _, obj in pairs(player.Character:GetChildren()) do
   if obj:IsA("Highlight") or obj:IsA("BillboardGui") then
    obj:Destroy()
   end
  end
 end
 if espConnections[player] then
  espConnections[player]:Disconnect()
  espConnections[player] = nil
 end
end

SettingsTab:CreateToggle({Name = "Player ESP", CurrentValue = false, Callback = function(value)
 espEnabled = value
 if value then
  for _, player in pairs(Players:GetPlayers()) do
   createESP(player)
  end
  updateNotification("ESP", "Enabled - See all players", 3)
 else
  for _, player in pairs(Players:GetPlayers()) do
   removeESP(player)
  end
  updateNotification("ESP", "Disabled", 2)
 end
end})

local tracersEnabled = false
local tracerConnections = {}
local tracerParts = {}

local function createTracerToPlayer(player)
 if player == LP then return end
 
 local function addTracer(char)
  if not char then return end
  local hrp = char:FindFirstChild("HumanoidRootPart")
  if not hrp then return end
  
  -- Create beam from local player to target player
  local attachment0 = Instance.new("Attachment")
  attachment0.Parent = LP.Character:WaitForChild("HumanoidRootPart")
  
  local attachment1 = Instance.new("Attachment")
  attachment1.Parent = hrp
  
  local beam = Instance.new("Beam")
  beam.Attachment0 = attachment0
  beam.Attachment1 = attachment1
  beam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
  beam.FaceCamera = true
  beam.Width0 = 0.1
  beam.Width1 = 0.1
  beam.Parent = LP.Character:WaitForChild("HumanoidRootPart")
  
  table.insert(tracerParts, {beam = beam, att0 = attachment0, att1 = attachment1})
 end
 
 if player.Character then
  addTracer(player.Character)
 end
 
 tracerConnections[player] = player.CharacterAdded:Connect(function(char)
  if tracersEnabled then
   task.wait(0.5)
   addTracer(char)
  end
 end)
end

local function removeAllTracers()
 for _, tracerData in ipairs(tracerParts) do
  if tracerData.beam then tracerData.beam:Destroy() end
  if tracerData.att0 then tracerData.att0:Destroy() end
  if tracerData.att1 then tracerData.att1:Destroy() end
 end
 tracerParts = {}
 
 for player, conn in pairs(tracerConnections) do
  conn:Disconnect()
 end
 tracerConnections = {}
end

SettingsTab:CreateToggle({Name = "Player Tracers", CurrentValue = false, Callback = function(value)
 tracersEnabled = value
 if value then
  for _, player in pairs(Players:GetPlayers()) do
   createTracerToPlayer(player)
  end
  updateNotification("Tracers", "Enabled - Lines to all players", 3)
 else
  removeAllTracers()
  updateNotification("Tracers", "Disabled", 2)
 end
end})

local noclipEnabled = false
local noclipConnection = nil

SettingsTab:CreateToggle({Name = "Noclip", CurrentValue = false, Callback = function(value)
 noclipEnabled = value
 if value then
  if noclipConnection then noclipConnection:Disconnect() end
  noclipConnection = game:GetService("RunService").Stepped:Connect(function()
   if noclipEnabled and LP.Character then
    for _, part in pairs(LP.Character:GetDescendants()) do
     if part:IsA("BasePart") then
      part.CanCollide = false
     end
    end
   end
  end)
  updateNotification("Noclip", "Enabled - Walk through walls", 3)
 else
  if noclipConnection then noclipConnection:Disconnect() noclipConnection = nil end
  if LP.Character then
   for _, part in pairs(LP.Character:GetDescendants()) do
    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
     part.CanCollide = true
    end
   end
  end
  updateNotification("Noclip", "Disabled", 2)
 end
end})

SettingsTab:CreateSection("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- Hotkeys Section
SettingsTab:CreateSection("Hotkeys")

SettingsTab:CreateInput({Name = "Withdraw All Hotkey", PlaceholderText = "Keybind...", RemoveTextAfterFocusLost = false, Callback = function(text)
 local newKey = Enum.KeyCode[text]
 if newKey then
  hotkeys.withdrawAll = newKey
  updateNotification("Keybind", "Withdraw All: " .. text, 2)
 end
end})

SettingsTab:CreateInput({Name = "Deposit All Hotkey", PlaceholderText = "Keybind...", RemoveTextAfterFocusLost = false, Callback = function(text)
 local newKey = Enum.KeyCode[text]
 if newKey then
  hotkeys.depositAll = newKey
  updateNotification("Keybind", "Deposit All: " .. text, 2)
 end
end})

SettingsTab:CreateInput({Name = "Select Random Hotkey", PlaceholderText = "Keybind...", RemoveTextAfterFocusLost = false, Callback = function(text)
 local newKey = Enum.KeyCode[text]
 if newKey then
  hotkeys.selectRandom = newKey
  updateNotification("Keybind", "Select Random: " .. text, 2)
 end
end})

SettingsTab:CreateInput({Name = "Scan Vendings Hotkey", PlaceholderText = "Keybind...", RemoveTextAfterFocusLost = false, Callback = function(text)
 local newKey = Enum.KeyCode[text]
 if newKey then
  hotkeys.scanVendings = newKey
  updateNotification("Keybind", "Scan: " .. text, 2)
 end
end})

SettingsTab:CreateInput({Name = "Empty All Hotkey", PlaceholderText = "Keybind...", RemoveTextAfterFocusLost = false, Callback = function(text)
 local newKey = Enum.KeyCode[text]
 if newKey then
  hotkeys.emptyAll = newKey
  updateNotification("Keybind", "Empty All: " .. text, 2)
 end
end})

-- ============================================
-- PRESETS TAB
-- ============================================
local PresetsTab = Window:CreateTab("Presets")

PresetsTab:CreateParagraph({Title = "Favorites & Groups Info", Content = "Save and load vending presets for quick access.\n\n• ALT+Click vendings to select them\n• Save selections as Favorites or Groups\n• Load them anytime for quick operations"})

PresetsTab:CreateSection("Selection")

local favGroupMode = "Save as Favorites"

PresetsTab:CreateToggle({Name = "Enable Selection Mode", CurrentValue = false, Callback = function(value) 
 favoritesSelectionMode = value 
 if value then 
  updateNotification("Selection Mode", "Hold ALT + click vendings to select! (" .. #selectedFavorites .. " already selected)", 4) 
 else 
  updateNotification("Selection Mode", "Disabled (" .. #selectedFavorites .. " still selected)", 2) 
 end 
end})

PresetsTab:CreateButton({Name = "Clear All Selections", Callback = function()
 for _, vending in ipairs(selectedFavorites) do
  removeSelectionMarker(vending)
 end
 selectedFavorites = {}
 updateNotification("Cleared", "All selections removed", 2)
end})

PresetsTab:CreateSection("Actions")

PresetsTab:CreateDropdown({Name = "Select Action", Options = {"Save as Favorites", "Load Favorites", "Save as Group", "Load Group", "Show Group ESP", "Hide Group ESP", "Use Group for Operations", "Use All Vendings", "Delete Group"}, CurrentOption = {"Save as Favorites"}, MultipleOptions = false, Callback = function(option) favGroupMode = option[1] end})

local groupNameInput = ""
local savedGroupsList = {"None"}
for groupName, _ in pairs(vendingGroups) do if groupName ~= "Default" then table.insert(savedGroupsList, groupName) end end
local selectedGroupName = "None"

PresetsTab:CreateInput({Name = "Group Name (for Save/Load/Delete)", PlaceholderText = "Enter group name...", RemoveTextAfterFocusLost = false, Callback = function(text) groupNameInput = text end})
PresetsTab:CreateDropdown({Name = "Select Saved Group", Options = savedGroupsList, CurrentOption = {"None"}, MultipleOptions = false, Callback = function(option) selectedGroupName = option[1] end})

local groupESPObjects = {}
local function removeGroupESP() for _, espData in ipairs(groupESPObjects) do if espData.highlight then pcall(function() espData.highlight:Destroy() end) end if espData.billboard then pcall(function() espData.billboard:Destroy() end) end end groupESPObjects = {} end

PresetsTab:CreateButton({Name = "Apply", Callback = function()
 if favGroupMode == "Save as Favorites" then if #selectedFavorites == 0 then updateNotification("Error", "No vendings selected!", 3) return end favoriteVendings = selectedFavorites saveFavorites() updateNotification("Saved", "Saved " .. #favoriteVendings .. " favorites!", 3) for _, vending in ipairs(selectedFavorites) do local heart = vending:FindFirstChild("FavoriteHeart") if heart then heart:Destroy() end end selectedFavorites = {}
 elseif favGroupMode == "Load Favorites" then loadFavorites() if #favoriteVendings > 0 then updateNotification("Loaded", "Loaded " .. #favoriteVendings .. " favorites!", 2) else updateNotification("No Favorites", "No favorites saved!", 2) end
 elseif favGroupMode == "Save as Group" then if groupNameInput == "" then updateNotification("Error", "Enter group name!", 3) return end local vendings = findVendings() if #vendings == 0 then updateNotification("Error", "No vendings!", 3) return end vendingGroups[groupNameInput] = {} for _, vending in ipairs(vendings) do table.insert(vendingGroups[groupNameInput], {x = vending.Position.X, y = vending.Position.Y, z = vending.Position.Z, name = vending.Name}) end local groupsData = {} for groupName, vendingList in pairs(vendingGroups) do if groupName ~= "Default" then groupsData[groupName] = vendingList end end pcall(function() writefile("VendingManager_Groups.json", HttpService:JSONEncode(groupsData)) end) updateNotification("Group Saved", "Saved '" .. groupNameInput .. "' with " .. #vendings .. " vendings!", 5)
 elseif favGroupMode == "Load Group" then if groupNameInput == "" and selectedGroupName == "None" then updateNotification("Error", "Enter/select group name!", 3) return end local groupToLoad = groupNameInput ~= "" and groupNameInput or selectedGroupName if vendingGroups[groupToLoad] then updateNotification("Loaded", "Group '" .. groupToLoad .. "' exists with " .. #vendingGroups[groupToLoad] .. " vendings!", 3) else updateNotification("Error", "Group not found!", 3) end
 elseif favGroupMode == "Show Group ESP" then
  if selectedGroupName == "None" or not vendingGroups[selectedGroupName] then
   updateNotification("Error", "Select group!", 3)
   return
  end
  
  removeGroupESP()
  local group = vendingGroups[selectedGroupName]
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
  
  updateNotification("ESP", "Showing " .. #groupESPObjects, 2)
 elseif favGroupMode == "Hide Group ESP" then removeGroupESP() updateNotification("ESP", "Hidden", 2)
 elseif favGroupMode == "Use Group for Operations" then if selectedGroupName == "None" or not vendingGroups[selectedGroupName] then updateNotification("Error", "Select group!", 3) return end currentGroup = selectedGroupName updateNotification("Active", "Using: " .. selectedGroupName, 3)
 elseif favGroupMode == "Use All Vendings" then currentGroup = "Default" selectedGroupName = "None" updateNotification("Active", "Using ALL vendings", 2)
 elseif favGroupMode == "Delete Group" then local groupToDelete = groupNameInput ~= "" and groupNameInput or selectedGroupName if groupToDelete == "None" or not vendingGroups[groupToDelete] then updateNotification("Error", "Select/enter group!", 3) return end vendingGroups[groupToDelete] = nil updateNotification("Deleted", "Deleted " .. groupToDelete, 3) local groupsData = {} for groupName, vendingList in pairs(vendingGroups) do if groupName ~= "Default" then groupsData[groupName] = vendingList end end if writefile then writefile("VendingManager_Groups.json", HttpService:JSONEncode(groupsData)) end currentGroup = "Default"
 end
end})


-- SCRIPT COMPLETE MESSAGE
-- ============================================

end)

if not scriptSuccess then
    print("ERROR loading Islands Hub: " .. tostring(scriptError))
else
    print("Script loaded successfully")
end