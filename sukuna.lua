local Sukuna = {}

function Sukuna.IsMissing(joiners, ReplicatedStorage)
    local pd = ReplicatedStorage:WaitForChild("Player_Data")
    for _, name in ipairs(joiners) do
        local d = pd:FindFirstChild(name)
        if d and d:FindFirstChild("Collection") and not d.Collection:FindFirstChild("Sukuna:") then
            return true
        end
    end
    return false
end

function Sukuna.CreateRoom(Remote, UI, delay)
    print("[F9 LOG] Find Unit Action: Sukuna (Calamity)")
    Remote:FireServer("Create") task.wait(delay)
    Remote:FireServer("Change-Mode", { Mode = "Calamity" }) task.wait(delay)
    Remote:FireServer("Change-Chapter", { Chapter = "Calamity_Chapter1" }) task.wait(delay)
    Remote:FireServer("Submit")
    UI.Update("💀 สร้างห้องหา Sukuna (Calamity)")
end

return Sukuna
