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
