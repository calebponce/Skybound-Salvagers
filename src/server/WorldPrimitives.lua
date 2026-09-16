-- Reusable world-building primitives. Keeping these independent makes larger
-- harbor and expedition builders easier to read and safer to extend.
return function(defaultColor)
    local Primitives = {}

    function Primitives.createPart(parent, properties)
        local part = Instance.new("Part")
        part.Anchored = true
        part.CanCollide = properties.CanCollide ~= false
        part.Material = properties.Material or Enum.Material.SmoothPlastic
        part.Color = properties.Color or defaultColor
        part.Size = properties.Size or Vector3.new(4, 1, 4)
        part.CFrame = properties.CFrame or CFrame.new()
        part.Name = properties.Name or "Part"
        part.Parent = parent
        return part
    end

    function Primitives.addBillboard(part, value, color, options)
        options = options or {}
        local gui = Instance.new("BillboardGui")
        gui.Size = UDim2.fromOffset(165, 36)
        gui.StudsOffset = Vector3.new(0, 3, 0)
        -- Nearby interaction labels should not cover the skyline or distant islands.
        gui.MaxDistance = options.MaxDistance or 40
        gui.AlwaysOnTop = false
        gui.Parent = part

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromScale(1, 1)
        label.Font = Enum.Font.GothamMedium
        label.TextScaled = true
        local textLimit = Instance.new("UITextSizeConstraint")
        textLimit.MaxTextSize = 14
        textLimit.Parent = label
        label.TextColor3 = color or Color3.new(1, 1, 1)
        label.TextStrokeTransparency = 0.78
        label.Text = value
        label.Parent = gui
        return label
    end

    function Primitives.addPrompt(part, actionText, objectText, holdDuration)
        local prompt = Instance.new("ProximityPrompt")
        prompt.ActionText = actionText
        prompt.ObjectText = objectText
        prompt.HoldDuration = holdDuration or 0
        prompt.MaxActivationDistance = 11
        prompt.RequiresLineOfSight = false
        prompt.KeyboardKeyCode = Enum.KeyCode.E
        prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
        prompt.Parent = part
        return prompt
    end

    return Primitives
end
