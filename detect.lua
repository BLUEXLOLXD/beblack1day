local Detect = { IsInMatch = false }

function Detect.StartLoop(lp, UI, ReplicatedStorage)
    task.spawn(function()
        while true do
            pcall(function()
                local hud = lp.PlayerGui.HUD.InGame.Main.GameInfo.Stage.Label
                local rewards = lp.PlayerGui:FindFirstChild("RewardsUI")
                
                if string.find(string.lower(hud.Text), "chapter") then
                    Detect.IsInMatch = true
                    UI.Update("⚔️ กำลัง clear story", Color3.fromRGB(0, 200, 255))
                elseif string.find(hud.Text, "Calamity") then
                    Detect.IsInMatch = true
                    UI.Update("🔥 กำลังหา sukuna", Color3.fromRGB(255, 80, 80))
                elseif rewards and rewards.Enabled then
                    local ch = rewards.Main.LeftSide.Chapter.Text
                    local st = rewards.Main.LeftSide.GameStatus.Text
                    if string.find(ch, "Chapter 5") and string.find(st, "~ WON") then
                        UI.Update("🎉 ชนะด่าน 5! เตรียมรีรัน...", Color3.fromRGB(255, 255, 0))
                        Detect.IsInMatch = true
                    end
                else
                    if ReplicatedStorage:FindFirstChild("PlayRoom") then
                        Detect.IsInMatch = false
                    end
                end
            end)
            task.wait(1.5)
        end
    end)
    print("[F9 LOG] Detection Module Running.")
end

return Detect
