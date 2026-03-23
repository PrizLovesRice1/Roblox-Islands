--[[
    VendingsManager.lua
    Vending machine management features
]]--

local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")

local Util = require(script.Parent.Parent.shared.Utilities)
local Constants = require(script.Parent.Parent.shared.Constants)

return function(Window, state)
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
