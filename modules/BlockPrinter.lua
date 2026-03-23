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
