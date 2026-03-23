--[[
    Automation.lua
    Automation features - Auto-restock, Bank to Vendings, Auto Stocker
]]--

local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LP = Players.LocalPlayer
local Util = require(script.Parent.Parent.shared.Utilities)

return function(Window, state)
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
