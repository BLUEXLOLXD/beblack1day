return function(Config, UI, Utils)
    local lp = game:GetService("Players").LocalPlayer
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RemoteEvent = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("Server"):WaitForChild("PlayRoom"):WaitForChild("Event")
    local PlayerData = ReplicatedStorage:WaitForChild("Player_Data")

    print("[CORE] System V15 - Action Mode (Detection Removed)")

    local myName = Utils.cleanName(lp.Name)
    local fullTeam = {Config.HostName}
    for _, j in ipairs(Config.Joiners) do table.insert(fullTeam, j) end

    -- [[ 1. HOST LOGIC ]] --
    if myName == Utils.cleanName(Config.HostName) then
        task.spawn(function()
            while true do
                -- เช็คว่าอยู่ล็อบบี้ไหม (ถ้าไม่มี PlayRoom Folder = ไม่อยู่ล็อบบี้)
                if not ReplicatedStorage:FindFirstChild("PlayRoom") then 
                    task.wait(5) 
                    continue 
                end

                local targetChapter, targetWorld, modeType = nil, nil, "Story"

                -- สแกนหาด่าน
                local worlds = {"OnePiece", "Namek", "Naruto", "TokyoGhoul", "SAO", "JJK", "TrashGround"}
                for _, w in ipairs(worlds) do
                    for i = 1, 5 do
                        local sName = w .. "_Chapter" .. i
                        local someoneNeeds = false
                        for _, member in ipairs(fullTeam) do
                            local d = PlayerData:FindFirstChild(member)
                            if d and d:FindFirstChild("StageClears") and not d.StageClears:FindFirstChild(sName) then
                                someoneNeeds = true; break
                            end
                        end
                        if someoneNeeds then targetWorld, targetChapter = w, sName; break end
                    end
                    if targetChapter then break end
                end

                -- สแกน Sukuna (ถ้า Story ครบ)
                if not targetChapter and Config.CheckSukuna then
                    local missing = false
                    for _, j in ipairs(Config.Joiners) do
                        local d = PlayerData:FindFirstChild(j)
                        if d and d:FindFirstChild("Collection") and not d.Collection:FindFirstChild("Sukuna:") then
                            missing = true; break
                        end
                    end
                    if missing then
                        modeType, targetWorld, targetChapter = "Calamity", "Calamity", "Calamity_Chapter1"
                    end
                end

                -- สร้างห้อง
                if targetChapter then
                    print("[CORE] Leader Creating: " .. targetChapter)
                    RemoteEvent:FireServer("Create")
                    task.wait(Config.DelayTime)

                    if modeType == "Story" then
                        RemoteEvent:FireServer("Change-World", { World = targetWorld })
                    else
                        RemoteEvent:FireServer("Change-Mode", { Mode = "Calamity" })
                    end
                    task.wait(Config.DelayTime)

                    RemoteEvent:FireServer("Change-Chapter", { Chapter = targetChapter })
                    task.wait(Config.DelayTime)
                    RemoteEvent:FireServer("Submit")

                    while not Utils.isTeamInRoom(fullTeam, Config.HostName) do
                        if not ReplicatedStorage:FindFirstChild("PlayRoom") then break end
                        task.wait(2)
                    end

                    if Config.AutoSubmit and ReplicatedStorage:FindFirstChild("PlayRoom") then
                        warn("[CORE] All Ready. Starting!")
                        task.wait(Config.DelayTime)
                        RemoteEvent:FireServer("Start")
                        task.wait(10)
                    end
                end
                task.wait(5)
            end
        end)

    -- [[ 2. JOINER LOGIC ]] --
    else
        task.spawn(function()
            while true do
                if ReplicatedStorage:FindFirstChild("PlayRoom") then
                    pcall(function()
                        local room = ReplicatedStorage.PlayRoom:FindFirstChild(Config.HostName)
                        if room and not Utils.isTeamInRoom({lp.Name}, Config.HostName) then
                            RemoteEvent:FireServer("Join-Room", { Room = room })
                        end
                    end)
                end
                task.wait(3)
            end
        end)
    end
end
