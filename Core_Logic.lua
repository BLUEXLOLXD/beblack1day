return function(Config, UI, Utils)
    local lp = game:GetService("Players").LocalPlayer
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RemoteEvent = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("Server"):WaitForChild("PlayRoom"):WaitForChild("Event")
    local IsInMatch = false

    -- [ Monitor System ]
    task.spawn(function()
        while true do
            pcall(function()
                local hudLabel = lp.PlayerGui.HUD.InGame.Main.GameInfo.Stage.Label
                local rewardsUI = lp.PlayerGui:FindFirstChild("RewardsUI")
                
                if string.find(string.lower(hudLabel.Text), "chapter") then
                    IsInMatch = true
                    UI.StatusLabel.Text = "⚔️ กำลัง clear story"
                    UI.StatusLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
                elseif string.find(hudLabel.Text, "Calamity") then
                    IsInMatch = true
                    UI.StatusLabel.Text = "🔥 กำลังหา sukuna"
                    UI.StatusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
                elseif rewardsUI and rewardsUI.Enabled then
                    local chapterTxt = rewardsUI.Main.LeftSide.Chapter.Text
                    local statusTxt = rewardsUI.Main.LeftSide.GameStatus.Text
                    if string.find(chapterTxt, "Chapter 5") and string.find(statusTxt, "~ WON") then
                        IsInMatch = true
                        UI.StatusLabel.Text = "🎉 ชนะด่าน 5 แล้ว! รีรัน..."
                    end
                else
                    if ReplicatedStorage:FindFirstChild("PlayRoom") then IsInMatch = false end
                end
            end)
            task.wait(2)
        end
    end)

    -- [ Host / Joiner Logic ]
    local myIdentity = Utils.cleanName(lp.Name)
    if myIdentity == Utils.cleanName(Config.HostName) then
        -- Host Code (ย่อจาก V10.1)
        task.spawn(function()
            print("[HOST] Leader Started.")
            while true do
                if not IsInMatch then
                    -- ... (Logic หาด่านและสร้างห้องเหมือน V10.1) ...
                    -- (เพื่อให้สั้น ผมขอละไว้ในฐานที่เข้าใจว่ายกจากตัวเก่ามาใส่ที่นี่ได้เลย)
                end
                task.wait(3)
            end
        end)
    else
        -- Joiner Code
        task.spawn(function()
            print("[JOINER] Follower Started.")
            while true do
                if not IsInMatch then
                    pcall(function()
                        local room = ReplicatedStorage.PlayRoom:FindFirstChild(Config.HostName)
                        if room and not Utils.isTeamInRoom({lp.Name}, Config.HostName) then
                            RemoteEvent:FireServer("Join-Room", { Room = room })
                        end
                    end)
                end
                task.wait(2)
            end
        end)
    end
end
