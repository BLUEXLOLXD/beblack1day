local Detect = { IsInMatch = false }

function Detect.StartLoop(lp, UI, RS)
    task.spawn(function()
        while true do
            pcall(function()
                local hud = lp.PlayerGui.HUD.InGame.Main.GameInfo.Stage.Label
                local rewards = lp.PlayerGui:FindFirstChild("RewardsUI")
                
                -- 1. ตรวจจับขณะกำลังเล่น
                if string.find(string.lower(hud.Text), "chapter") then
                    Detect.IsInMatch = true
                    UI.Update("⚔️ กำลัง clear story", Color3.fromRGB(0, 200, 255))
                elseif string.find(hud.Text, "Calamity") then
                    Detect.IsInMatch = true
                    UI.Update("🔥 กำลังหา sukuna", Color3.fromRGB(255, 80, 80))
                
                -- 2. จุดสำคัญ: ตรวจจับเมื่อชนะด่าน 5 (Rerun ทันที)
                elseif rewards and rewards.Enabled then
                    local ch = rewards.Main.LeftSide.Chapter.Text
                    local st = rewards.Main.LeftSide.GameStatus.Text
                    
                    if string.find(ch, "Chapter 5") and string.find(st, "~ WON") then
                        UI.Update("🎉 ชนะด่าน 5! เริ่ม Rerun Story ทันที...", Color3.fromRGB(255, 255, 0))
                        
                        -- [[ FORCE RERUN LOGIC ]] --
                        -- ปลดล็อคสถานะทันที เพื่อให้ main.lua เริ่มหาด่านถัดไปโดยไม่ต้องรอกลับ Lobby
                        Detect.IsInMatch = false 
                        
                        -- หน่วงเวลาเล็กน้อยกันสคริปต์รันซ้อนรัวๆ
                        task.wait(2) 
                    end
                else
                    -- เช็คสถานะทั่วไป (เช่น อยู่ล็อบบี้)
                    if RS:FindFirstChild("PlayRoom") then
                        Detect.IsInMatch = false
                    end
                end
            end)
            task.wait(1.5)
        end
    end)
    print("[F9 LOG] Detection Module (Fast Rerun Mode) Running.")
end

return Detect
