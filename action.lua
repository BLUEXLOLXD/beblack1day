local Action = {}

function Action.Clean(s) return string.lower(string.gsub(tostring(s), "%s+", "")) end

function Action.IsReady(team, ReplicatedStorage)
    local room = ReplicatedStorage.PlayRoom:FindFirstChild("Waterman_Bc")
    if not room then return false end
    local inRoom = {}
    for _, v in pairs(room.Players:GetChildren()) do inRoom[Action.Clean(v.Value)] = true end
    for _, n in ipairs(team) do if not inRoom[Action.Clean(n)] then return false end end
    return true
end

return Action
