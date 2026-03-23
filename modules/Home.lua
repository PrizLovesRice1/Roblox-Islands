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
