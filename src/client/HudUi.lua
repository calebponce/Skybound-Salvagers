local HudUi = {}

function HudUi.addCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = parent
end

function HudUi.addStroke(parent, color, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Transparency = transparency or 0
    stroke.Thickness = 1
    stroke.Parent = parent
    return stroke
end

function HudUi.text(parent, value, position, size, font, textSize, color, alignment)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = position
    label.Size = size
    label.Font = font
    label.Text = value
    label.TextSize = textSize
    label.TextColor3 = color
    label.TextXAlignment = alignment or Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Parent = parent
    return label
end

function HudUi.makePanel(parent, theme, name, position, size)
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.Position = position
    frame.Size = size
    frame.BackgroundColor3 = theme.Panel
    frame.BackgroundTransparency = 0.05
    frame.Parent = parent
    HudUi.addCorner(frame, 14)
    HudUi.addStroke(frame, theme.Border, 0.36)
    return frame
end

function HudUi.scaleForViewport(frame, designWidth, minimumScale)
    local scale = Instance.new("UIScale")
    scale.Parent = frame
    local viewportConnection
    local function update()
        local camera = workspace.CurrentCamera
        if not camera then return end
        scale.Scale = math.min(1, math.max(minimumScale, (camera.ViewportSize.X - 24) / designWidth))
    end
    local function watchCamera()
        if viewportConnection then viewportConnection:Disconnect() end
        local camera = workspace.CurrentCamera
        if camera then viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update) end
        update()
    end
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
    watchCamera()
end

return HudUi
