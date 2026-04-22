local QC = {}

-- QC 1: ตรวจสอบว่า Story 7 โลกผ่าน "ทุกคน" จริงหรือไม่
function QC.CheckStoryPass(team, ReplicatedStorage)
    local worlds = {"OnePiece", "Namek", "Naruto", "TokyoGhoul", "SAO", "JJK", "TrashGround"}
    local pd = ReplicatedStorage:WaitForChild("Player_Data")
    
    local allPass = true
    local failedMember = ""
    local failedStage = ""

    for _, w in ipairs(worlds) do
        for i = 1, 5 do
            local stage = w .. "_Chapter" .. i
            for _, name in ipairs(team) do
                local d = pd:FindFirstChild(name)
                if not (d and d:FindFirstChild("StageClears") and d.StageClears:FindFirstChild(stage)) then
                    allPass = false
                    failedMember = name
                    failedStage = stage
                    break
                end
            end
            if not allPass then break end
        end
        if not allPass then break end
    end

    return allPass, failedMember, failedStage
end

-- QC 2: ตรวจสอบว่าหลังจากรัน Calamity แล้ว Joiners ได้ Sukuna หรือยัง
function QC.CheckUnitResult(joiners, ReplicatedStorage)
    local pd = ReplicatedStorage:WaitForChild("Player_Data")
    local missingList = {}

    for _, name in ipairs(joiners) do
        local d = pd:FindFirstChild(name)
        if d and d:FindFirstChild("Collection") and not d.Collection:FindFirstChild("Sukuna:") then
            table.insert(missingList, name)
        end
    end

    return #missingList == 0, missingList
end

return QC
