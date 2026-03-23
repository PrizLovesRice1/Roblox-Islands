--[[
    Utilities.lua
    Shared utility functions for Priz's Islands Hub
]]--

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

-- Format numbers with K, M, B suffixes
local function formatNumber(num)
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

-- Parse amount input (handles K, M, B suffixes)
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

-- Get display name of an object
local function getDisplayName(obj)
    if not obj then return "Unknown" end
    local displayNameValue = obj:FindFirstChild("DisplayName")
    if displayNameValue and displayNameValue:IsA("StringValue") then
        return displayNameValue.Value
    end
    return obj.Name
end

-- Check if position is taken by another crop
local function IsTaken(Position)
    for _,v in next, workspace.Islands:GetDescendants() do
        if v:IsA("BasePart") and v.Name ~= "Collision" then
            if (v.Position - Position).magnitude <= 2 then
                return true
            end
        end
    end
end

-- Update notification UI
local activeNotifications = {}
local notificationSpacing = 45

local function updateNotification(title, content, duration)
    task.spawn(function()
        pcall(function()
            local playerGui = LP:WaitForChild("PlayerGui")
            
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

return {
    formatNumber = formatNumber,
    parseAmount = parseAmount,
    getDisplayName = getDisplayName,
    IsTaken = IsTaken,
    updateNotification = updateNotification
}
