local UI = {}

function UI.Setup(lp)
    local pg = lp:WaitForChild("PlayerGui")
    if pg:FindFirstChild("AutoSystemGui") then pg.AutoSystemGui:Destroy() end
    
    local sg = Instance.new("ScreenGui", pg)
    sg.Name = "AutoSystemGui"
    local frame = Instance.new("Frame", sg)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    frame.Position = UDim2.new(0.5, -110, 0.02, 0) 
    frame.Size = UDim2.new(0, 220, 0, 100)
    Instance.new("UICorner", frame)

    local label = Instance.new("TextLabel", frame)
    label.Name = "StatusLabel"
    label.Position = UDim2.new(0, 10, 0, 10)
    label.Size = UDim2.new(1, -20, 1, -20)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamMedium
    label.TextColor3 = Color3.fromRGB(0, 255, 180)
    label.TextSize = 10
    label.TextWrapped = true
    label.Text = "System Booting..."
    
    UI.Label = label
    print("[F9 LOG] UI Module Initialized.")
end

function UI.Update(text, color)
    if UI.Label then
        UI.Label.Text = text
        if color then UI.Label.TextColor3 = color end
    end
end

return UI
