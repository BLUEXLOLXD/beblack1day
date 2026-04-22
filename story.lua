local Story = {}

function Story.GetNext(team, ReplicatedStorage)
    local worlds = {"OnePiece", "Namek", "Naruto", "TokyoGhoul", "SAO", "JJK", "TrashGround"}
    local pd = ReplicatedStorage:WaitForChild("Player_Data")
    
    for _, w in ipairs(worlds) do
        for i = 1, 5 do
            local stageName = w .. "_Chapter" .. i
            local needsClear = false
            for _, name in ipairs(team) do
                local d = pd:FindFirstChild(name)
                if d and d:FindFirstChild("StageClears") and not d.StageClears:FindFirstChild(stageName) then
                    needsClear = true; break
                end
            end
            if needsClear then return w, stageName end
        end
    end
    return nil, nil
end

function Story.CreateRoom(Remote, world, chapter, UI, delay)
    print("[F9 LOG] Story Clear Action: " .. chapter)
    Remote:FireServer("Create") task.wait(delay)
    Remote:FireServer("Change-World", { World = world }) task.wait(delay)
    Remote:FireServer("Change-Chapter", { Chapter = chapter }) task.wait(delay)
    Remote:FireServer("Submit")
    UI.Update("🛠 สร้างห้อง Story: " .. chapter)
end

return Story
