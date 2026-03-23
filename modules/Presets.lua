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
