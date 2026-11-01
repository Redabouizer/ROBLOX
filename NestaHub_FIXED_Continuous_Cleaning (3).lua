
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:FindFirstChild("r26")
if not remote then
    remote = Instance.new("RemoteEvent")
    remote.Name = "r26"
    remote.Parent = ReplicatedStorage
end

local active = {}
local MAX_DISTANCE = 12
local MAX_SPOTS = 100

local function getDirtFolder()
    local job = workspace:FindFirstChild("CleaningJob")
        or (workspace:FindFirstChild("GenericModels")
            and workspace.GenericModels:FindFirstChild("CleaningJob"))

    return job and job:FindFirstChild("ActiveDirt")
end

local function hasBroom(player)
    local character = player.Character
    return character and character:FindFirstChild("Broom") ~= nil
end

local function cleanSpot(player, spot)
    if not spot or not spot:IsA("BasePart") then
        return false
    end

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if not root or not hasBroom(player) then
        return false
    end

    if (root.Position - spot.Position).Magnitude > MAX_DISTANCE then
        return false
    end

    -- Replace this with your game's actual cleaning/reward logic.
    spot:Destroy()
    return true
end

remote.OnServerEvent:Connect(function(player, action, data)
    if action == "cancel" then
        active[player] = nil
        remote:FireClient(player, "cancelled")
        return
    end

    if action ~= "start" or active[player] then
        return
    end

    if not hasBroom(player) then
        remote:FireClient(player, "error", "Equip the Broom first")
        return
    end

    local folder = getDirtFolder()
    if not folder then
        remote:FireClient(player, "error", "Dirt folder not found")
        return
    end

    active[player] = true

    task.spawn(function()
        local ok, err = pcall(function()
            while active[player] do
                local spots = folder:GetChildren()
                local found = false

                for _, spot in ipairs(spots) do
                    if not active[player] then break end

                    if spot:IsA("BasePart")
                        and spot.Name:match("^DirtSpot_%d+$") then

                        found = true

                        if cleanSpot(player, spot) then
                            remote:FireClient(player, "cleaned", spot.Name)
                        end
                    end
                end

                if not found then
                    break
                end

                task.wait()
            end
        end)

        active[player] = nil

        if ok then
            remote:FireClient(player, "done")
        else
            warn("[CleaningServer]", err)
            remote:FireClient(player, "error", "Cleaning failed")
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    active[player] = nil
end)
