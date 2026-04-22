local Utils = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")

function Utils.cleanName(s) 
    return string.lower(string.gsub(tostring(s), "%s+", "")) 
end

function Utils.isTeamInRoom(teamList, hostName)
    local room = ReplicatedStorage:FindFirstChild("PlayRoom")
    local waterman = room and room:FindFirstChild(hostName)
    local playersFolder = waterman and waterman:FindFirstChild("Players")
    if not playersFolder then return false end
    
    local inRoom = {}
    for _, v in pairs(playersFolder:GetChildren()) do
        if v:IsA("ValueBase") or v:IsA("StringValue") then 
            inRoom[Utils.cleanName(v.Value)] = true 
        end
    end
    
    for _, name in ipairs(teamList) do
        if not inRoom[Utils.cleanName(name)] then return false end
    end
    return true
end

return Utils
