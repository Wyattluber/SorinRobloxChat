-- Sorin Roblox Global Chat UI Library
-- Dark + purple gradient styling, Material-inspired.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local ChatUI = {}
ChatUI.__index = ChatUI

-- Simple color palette
local palette = {
    bg = Color3.fromRGB(14, 14, 24),
    card = Color3.fromRGB(24, 24, 36),
    accent = Color3.fromRGB(140, 90, 255),
    accent2 = Color3.fromRGB(95, 60, 190),
    text = Color3.fromRGB(235, 235, 245),
    subtext = Color3.fromRGB(180, 180, 200),
    danger = Color3.fromRGB(255, 90, 120),
}

local function new(instance, props)
    local obj = Instance.new(instance)
    for k, v in pairs(props or {}) do
        obj[k] = v
    end
    return obj
end

local function gradient(parent)
    local uiGradient = new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, palette.accent2),
            ColorSequenceKeypoint.new(1, palette.accent),
        }),
        Rotation = 90,
    })
    uiGradient.Parent = parent
end

local function corner(parent, radius)
    new("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

local function padding(parent, px)
    new("UIPadding", {
        PaddingTop = UDim.new(0, px),
        PaddingBottom = UDim.new(0, px),
        PaddingLeft = UDim.new(0, px),
        PaddingRight = UDim.new(0, px),
        Parent = parent,
    })
end

local function stroke(parent, color, thickness, transparency)
    new("UIStroke", {
        Color = color,
        Thickness = thickness or 1,
        Transparency = transparency or 0.5,
        Parent = parent,
    })
end

function ChatUI:Init(opts)
    self.callbacks = opts or {}
    self.messages = {}
    self.collapsed = false
    self.currentTab = "chat"
    self.onlineSet = {}

    local screen = new("ScreenGui", {
        Name = "SorinGlobalChat",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    screen.Parent = LocalPlayer:WaitForChild("PlayerGui")
    self.screen = screen

    local frame = new("Frame", {
        Size = UDim2.new(0, 460, 0, 520),
        Position = UDim2.new(1, -480, 0, 40),
        BackgroundColor3 = palette.bg,
        BorderSizePixel = 0,
    })
    corner(frame, 16)
    stroke(frame, Color3.fromRGB(60, 60, 90), 1, 0.4)
    frame.Parent = screen
    self.frame = frame

    -- Header
    local header = new("Frame", {
        Size = UDim2.new(1, -20, 0, 64),
        Position = UDim2.new(0, 10, 0, 10),
        BackgroundColor3 = palette.card,
        BorderSizePixel = 0,
    })
    corner(header, 12)
    padding(header, 10)
    stroke(header, Color3.fromRGB(70, 70, 110), 1, 0.35)
    header.Parent = frame

    local title = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -120, 0, 22),
        Position = UDim2.new(0, 8, 0, 0),
        Font = Enum.Font.GothamBold,
        Text = "Sorin Global Chat",
        TextSize = 18,
        TextColor3 = palette.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    title.Parent = header

    local status = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -120, 0, 18),
        Position = UDim2.new(0, 8, 0, 20),
        Font = Enum.Font.Gotham,
        Text = "Connecting...",
        TextSize = 12,
        TextColor3 = palette.subtext,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    status.Parent = header
    self.status = status

    -- Tabs
    local tabChat = new("TextButton", {
        Size = UDim2.new(0, 60, 0, 28),
        Position = UDim2.new(1, -140, 0, 4),
        BackgroundColor3 = Color3.fromRGB(32, 32, 44),
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Text = "Chat",
        TextSize = 12,
        TextColor3 = palette.text,
    })
    corner(tabChat, 8)
    stroke(tabChat, Color3.fromRGB(70, 70, 110), 1, 0.25)
    tabChat.Parent = header

    local tabHome = new("TextButton", {
        Size = UDim2.new(0, 60, 0, 28),
        Position = UDim2.new(1, -74, 0, 4),
        BackgroundColor3 = Color3.fromRGB(32, 32, 44),
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Text = "Home",
        TextSize = 12,
        TextColor3 = palette.subtext,
    })
    corner(tabHome, 8)
    stroke(tabHome, Color3.fromRGB(70, 70, 110), 1, 0.25)
    tabHome.Parent = header

    -- Messages container
    local listHolder = new("Frame", {
        Size = UDim2.new(1, -20, 1, -160),
        Position = UDim2.new(0, 10, 0, 76),
        BackgroundTransparency = 1,
    })
    listHolder.Parent = frame

    local scrolling = new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 6,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    scrolling.Parent = listHolder
    self.scrolling = scrolling

    local listLayout = new("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    listLayout.Parent = scrolling
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scrolling.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20)
        scrolling.CanvasPosition = Vector2.new(0, math.max(0, listLayout.AbsoluteContentSize.Y - scrolling.AbsoluteWindowSize.Y))
    end)

    -- Input bar
    local inputBar = new("Frame", {
        Size = UDim2.new(1, -20, 0, 60),
        Position = UDim2.new(0, 10, 1, -70),
        BackgroundColor3 = palette.card,
        BorderSizePixel = 0,
    })
    corner(inputBar, 12)
    stroke(inputBar, Color3.fromRGB(70, 70, 110), 1, 0.35)
    padding(inputBar, 10)
    inputBar.Parent = frame

    local textBox = new("TextBox", {
        Size = UDim2.new(1, -120, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(18, 18, 28),
        BorderSizePixel = 0,
        Font = Enum.Font.Gotham,
        PlaceholderText = "Schreibe eine Nachricht...",
        PlaceholderColor3 = palette.subtext,
        Text = "",
        TextSize = 14,
        TextColor3 = palette.text,
        ClearTextOnFocus = false,
    })
    corner(textBox, 10)
    padding(textBox, 8)
    textBox.Parent = inputBar

    local sendBtn = new("TextButton", {
        Size = UDim2.new(0, 100, 1, 0),
        Position = UDim2.new(1, -100, 0, 0),
        BackgroundColor3 = palette.accent,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Text = "SEND",
        TextSize = 14,
        TextColor3 = Color3.fromRGB(250, 250, 255),
    })
    corner(sendBtn, 10)
    gradient(sendBtn)
    sendBtn.Parent = inputBar

    sendBtn.MouseButton1Click:Connect(function()
        local msg = textBox.Text
        textBox.Text = ""
        if self.callbacks.OnSend then
            self.callbacks.OnSend(msg)
        end
    end)

    self.textBox = textBox
    self.listHolder = listHolder
    self.inputBar = inputBar

    -- Home tab content
    local homeFrame = new("Frame", {
        Size = UDim2.new(1, -20, 1, -100),
        Position = UDim2.new(0, 10, 0, 72),
        BackgroundTransparency = 1,
        Visible = false,
    })
    homeFrame.Parent = frame

    local homeTitle = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 26),
        Position = UDim2.new(0, 0, 0, 0),
        Font = Enum.Font.GothamBold,
        Text = "Welcome",
        TextSize = 16,
        TextColor3 = palette.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    homeTitle.Parent = homeFrame

    local homeBody = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 80),
        Position = UDim2.new(0, 0, 0, 28),
        Font = Enum.Font.Gotham,
        Text = (opts and opts.HomeText) or "Credits: SorinSoftware\nRules: Be kind. No spam.",
        TextSize = 14,
        TextColor3 = palette.subtext,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
    })
    homeBody.Parent = homeFrame

    local onlineLbl = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 20),
        Position = UDim2.new(0, 0, 0, 114),
        Font = Enum.Font.GothamBold,
        Text = "Online: …",
        TextSize = 14,
        TextColor3 = palette.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    onlineLbl.Parent = homeFrame
    self.onlineLbl = onlineLbl
    self.homeFrame = homeFrame

    -- Drag handling (drag header to move)
    local dragging = false
    local dragOffset
    local function beginDrag(input)
        dragging = true
        dragOffset = frame.AbsolutePosition - input.Position
    end
    local function endDrag()
        dragging = false
    end
    local function updateDrag(input)
        if not dragging then
            return
        end
        local pos = input.Position + dragOffset
        frame.Position = UDim2.fromOffset(pos.X, pos.Y)
    end
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            beginDrag(input)
        end
    end)
    header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            endDrag()
        end
    end)
    header.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            updateDrag(input)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            updateDrag(input)
        end
    end)

    -- Tab switching
    local function setTab(tab)
        self.currentTab = tab
        local isHome = tab == "home"
        homeFrame.Visible = isHome
        listHolder.Visible = not isHome and not self.collapsed
        inputBar.Visible = not isHome and not self.collapsed
        status.Visible = not isHome
        tabChat.TextColor3 = isHome and palette.subtext or palette.text
        tabHome.TextColor3 = isHome and palette.text or palette.subtext
    end
    tabChat.MouseButton1Click:Connect(function()
        setTab("chat")
    end)
    tabHome.MouseButton1Click:Connect(function()
        setTab("home")
    end)

    return self
end

local function avatarHeadshot(userId)
    local thumbType = Enum.ThumbnailType.HeadShot
    local thumbSize = Enum.ThumbnailSize.Size100x100
    local content, _ = Players:GetUserThumbnailAsync(userId or 1, thumbType, thumbSize)
    return content
end

function ChatUI:AddMessage(msg)
    if not self.scrolling then
        return
    end
    local id = msg.id or HttpService:GenerateGUID(false)
    local userId = tonumber(msg.roblox_user_id) or msg.user_id or 0
    local username = msg.username or ("User_" .. tostring(userId))
    local content = msg.content or ""
    local gameName = msg.game_name or ("Place " .. tostring(msg.place_id or "?"))
    local isDeleted = msg.is_deleted
    if userId then
        self.onlineSet[userId] = true
        if self.onlineLbl then
            local count = 0
            for _ in pairs(self.onlineSet) do
                count += 1
            end
            self.onlineLbl.Text = "Online: " .. tostring(count)
        end
    end

    if self.messages[id] then
        -- update text if needed
        local card = self.messages[id]
        if isDeleted then
            card.content.Text = "[deleted]"
        else
            card.content.Text = content
        end
        return
    end

    local card = new("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 80),
        BackgroundColor3 = palette.card,
        BorderSizePixel = 0,
        LayoutOrder = msg.created_at or os.time(),
    })
    corner(card, 12)
    stroke(card, Color3.fromRGB(70, 70, 110), 1, 0.35)
    padding(card, 10)
    card.Parent = self.scrolling

    local avatar = new("ImageLabel", {
        Size = UDim2.new(0, 52, 0, 52),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(18, 18, 28),
        BorderSizePixel = 0,
        Image = avatarHeadshot(userId),
    })
    corner(avatar, 12)
    avatar.Parent = card

    local nameLbl = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -120, 0, 22),
        Position = UDim2.new(0, 62, 0, 0),
        Font = Enum.Font.GothamBold,
        Text = username,
        TextSize = 15,
        TextColor3 = palette.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    nameLbl.Parent = card

    local meta = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -120, 0, 18),
        Position = UDim2.new(0, 62, 0, 20),
        Font = Enum.Font.Gotham,
        Text = gameName,
        TextSize = 12,
        TextColor3 = palette.subtext,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    meta.Parent = card

    local contentLbl = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -120, 0, 24),
        Position = UDim2.new(0, 62, 0, 38),
        Font = Enum.Font.Gotham,
        Text = isDeleted and "[deleted]" or content,
        TextSize = 14,
        TextColor3 = palette.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
    })
    contentLbl.Parent = card

    local delBtn = new("TextButton", {
        Size = UDim2.new(0, 32, 0, 32),
        Position = UDim2.new(1, -42, 0, 0),
        BackgroundColor3 = Color3.fromRGB(30, 20, 30),
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Text = "X",
        TextSize = 12,
        TextColor3 = palette.danger,
        Visible = msg.can_delete == true,
    })
    corner(delBtn, 8)
    stroke(delBtn, palette.danger, 1, 0.3)
    delBtn.Parent = card

    delBtn.MouseButton1Click:Connect(function()
        if self.callbacks.OnDelete then
            self.callbacks.OnDelete(id)
        end
    end)

    self.messages[id] = {
        card = card,
        content = contentLbl,
    }
end

function ChatUI:RemoveMessage(id)
    local record = self.messages[id]
    if not record then
        return
    end
    if record.card then
        record.card:Destroy()
    end
    self.messages[id] = nil
end

function ChatUI:SetStatus(text)
    if self.status then
        self.status.Text = text
    end
end

return setmetatable({}, ChatUI)
