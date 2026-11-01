
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:WaitForChild("r26")

local running = false

local function startCleaning()
    if running then return end

    running = true
    remote:FireServer("start")
end

local function stopCleaning()
    if not running then return end

    running = false
    remote:FireServer("cancel")
end

remote.OnClientEvent:Connect(function(action, data)
    if action == "cleaned" then
        print("Cleaned:", data)

    elseif action == "done" then
        running = false
        print("All dirt spots cleaned")

    elseif action == "cancelled" then
        running = false

    elseif action == "error" then
        running = false
        warn("Cleaning error:", data)
    end
end)

-- Start automatically:
startCleaning()

-- To stop from another LocalScript:
_G.StopCleaning = stopCleaning
