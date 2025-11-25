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
    bubble = Color3.fromRGB(18, 18, 28),
    disabled = Color3.fromRGB(80, 80, 90),
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
    self.currentTab = "home" -- start on Home; Chat locked until rules accepted
    self.onlineSet = {}
    self.stickerSet = {}
    self.replyContext = nil

    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    local screen = new("ScreenGui", {
        Name = "SorinGlobalChat",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    screen.Parent = LocalPlayer:WaitForChild("PlayerGui")
    self.screen = screen

    local frame = new("Frame", {
        Size = isMobile and UDim2.new(0.9, 0, 0, 420) or UDim2.new(0, 420, 0, 520),
        Position = isMobile and UDim2.new(0.05, 0, 0.25, 0) or UDim2.new(0.5, -210, 0.35, -120),
        BackgroundColor3 = palette.bg,
        BorderSizePixel = 0,
        Active = true,
    })
    corner(frame, 16)
    stroke(frame, Color3.fromRGB(60, 60, 90), 1, 0.4)
    frame.Parent = screen
    self.frame = frame
    local function clampToViewport(pos)
        local cam = workspace.CurrentCamera
        if not cam then
            return pos
        end
        local size = cam.ViewportSize
        local x = math.clamp(pos.X.Offset, 10, size.X - frame.AbsoluteSize.X - 10)
        local y = math.clamp(pos.Y.Offset, 10, size.Y - 40)
        return UDim2.fromOffset(x, y)
    end
    frame.Position = clampToViewport(frame.Position)

    -- Header
    local header = new("Frame", {
        Size = UDim2.new(1, -20, 0, 64),
        Position = UDim2.new(0, 10, 0, 10),
        BackgroundColor3 = palette.card,
        BorderSizePixel = 0,
        Active = true,
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
        Size = UDim2.new(0, 64, 0, 28),
        Position = UDim2.new(1, -148, 0, 4),
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
        Size = UDim2.new(0, 64, 0, 28),
        Position = UDim2.new(1, -78, 0, 4),
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
        PlaceholderText = "Type a message...",
        PlaceholderColor3 = palette.subtext,
        Text = "",
        TextSize = 14,
        TextColor3 = palette.text,
        ClearTextOnFocus = false,
    })
    corner(textBox, 10)
    padding(textBox, 8)
    textBox.Parent = inputBar

    local stickerBtn = new("TextButton", {
        Size = UDim2.new(0, 36, 1, 0),
        Position = UDim2.new(1, -136, 0, 0),
        BackgroundColor3 = Color3.fromRGB(40, 40, 55),
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Text = "Sticker",
        TextSize = 12,
        TextColor3 = palette.text,
    })
    corner(stickerBtn, 10)
    stroke(stickerBtn, Color3.fromRGB(70, 70, 110), 1, 0.25)
    stickerBtn.Parent = inputBar

    local sendBtn = new("TextButton", {
        Size = UDim2.new(0, 92, 1, 0),
        Position = UDim2.new(1, -92, 0, 0),
        BackgroundColor3 = Color3.fromRGB(60, 60, 80),
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Text = "SEND",
        TextSize = 14,
        TextColor3 = Color3.fromRGB(180, 180, 200),
    })
    corner(sendBtn, 10)
    gradient(sendBtn)
    sendBtn.Parent = inputBar

    -- Reply indicator
    local replyBar = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -10, 0, 18),
        Position = UDim2.new(0, 5, 0, -18),
        Font = Enum.Font.Gotham,
        Text = "",
        TextSize = 12,
        TextColor3 = palette.subtext,
        TextXAlignment = Enum.TextXAlignment.Left,
        Visible = false,
    })
    replyBar.Parent = inputBar
    self.replyBar = replyBar

    local replyCancel = new("TextButton", {
        Size = UDim2.new(0, 20, 0, 18),
        Position = UDim2.new(1, -24, 0, -18),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = "X",
        TextSize = 12,
        TextColor3 = palette.subtext,
        Visible = false,
    })
    replyCancel.Parent = inputBar
    self.replyCancel = replyCancel

    local function updateSendState()
        local hasText = string.len(textBox.Text) > 0
        sendBtn.TextColor3 = hasText and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 200)
        sendBtn.BackgroundColor3 = hasText and palette.accent or Color3.fromRGB(60, 60, 80)
    end

    sendBtn.MouseButton1Click:Connect(function()
        local msg = textBox.Text
        textBox.Text = ""
        updateSendState()
        if self.callbacks.OnSend then
            -- prefix reply marker if set
            if self.replyContext then
                msg = ("[[reply:%s|%s]] %s"):format(self.replyContext.id, self.replyContext.name, msg)
            end
            self.callbacks.OnSend(msg)
        end
        self.replyContext = nil
        replyBar.Visible = false
        replyCancel.Visible = false
    end)

    -- Enter to send (PC)
    textBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            sendBtn.MouseButton1Click:Fire()
        end
    end)
    textBox.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Keyboard and (input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter) then
            sendBtn.MouseButton1Click:Fire()
        end
    end)

    textBox:GetPropertyChangedSignal("Text"):Connect(updateSendState)

    replyCancel.MouseButton1Click:Connect(function()
        self.replyContext = nil
        replyBar.Visible = false
        replyCancel.Visible = false
    end)

    -- Sticker picker modal
    local stickerModal = new("Frame", {
        Size = UDim2.new(0, 240, 0, 220),
        Position = UDim2.new(0.5, -120, 0.5, -110),
        BackgroundColor3 = palette.card,
        BorderSizePixel = 0,
        Visible = false,
    })
    corner(stickerModal, 12)
    stroke(stickerModal, Color3.fromRGB(70, 70, 110), 1, 0.35)
    stickerModal.Parent = screen

    local stickerTitle = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -40, 0, 24),
        Position = UDim2.new(0, 10, 0, 8),
        Font = Enum.Font.GothamBold,
        Text = "Stickers",
        TextSize = 16,
        TextColor3 = palette.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    stickerTitle.Parent = stickerModal

    local closeSticker = new("TextButton", {
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(1, -32, 0, 8),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = "X",
        TextSize = 14,
        TextColor3 = palette.subtext,
    })
    closeSticker.Parent = stickerModal

    local stickerList = new("ScrollingFrame", {
        Size = UDim2.new(1, -20, 0, 130),
        Position = UDim2.new(0, 10, 0, 36),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 6,
    })
    stickerList.Parent = stickerModal
    local stickerLayout = new("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    stickerLayout.Parent = stickerList
    stickerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        stickerList.CanvasSize = UDim2.new(0, 0, 0, stickerLayout.AbsoluteContentSize.Y + 10)
    end)

    local addBox = new("TextBox", {
        Size = UDim2.new(1, -90, 0, 28),
        Position = UDim2.new(0, 10, 1, -34),
        BackgroundColor3 = palette.bubble,
        BorderSizePixel = 0,
        Font = Enum.Font.Gotham,
        PlaceholderText = "rbxassetid://123",
        PlaceholderColor3 = palette.subtext,
        Text = "",
        TextSize = 12,
        TextColor3 = palette.text,
        ClearTextOnFocus = true,
    })
    corner(addBox, 8)
    padding(addBox, 6)
    addBox.Parent = stickerModal

    local addBtn = new("TextButton", {
        Size = UDim2.new(0, 60, 0, 28),
        Position = UDim2.new(1, -70, 1, -34),
        BackgroundColor3 = palette.accent,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Text = "Add",
        TextSize = 12,
        TextColor3 = Color3.fromRGB(255, 255, 255),
    })
    corner(addBtn, 8)
    gradient(addBtn)
    addBtn.Parent = stickerModal

    local function refreshStickers()
        for _, child in ipairs(stickerList:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        for id in pairs(self.stickerSet) do
            local btn = new("TextButton", {
                Size = UDim2.new(1, 0, 0, 32),
                BackgroundColor3 = palette.bubble,
                BorderSizePixel = 0,
                Font = Enum.Font.Gotham,
                Text = tostring(id),
                TextSize = 12,
                TextColor3 = palette.text,
            })
            corner(btn, 8)
            stroke(btn, Color3.fromRGB(60, 60, 80), 1, 0.3)
            btn.Parent = stickerList
            btn.MouseButton1Click:Connect(function()
                if self.callbacks.OnSend then
                    self.callbacks.OnSend("[[sticker:" .. tostring(id) .. "]]")
                end
                stickerModal.Visible = false
            end)
        end
    end

    addBtn.MouseButton1Click:Connect(function()
        local txt = (addBox.Text or ""):gsub("rbxassetid://", "")
        local num = tonumber(txt)
        if num then
            self.stickerSet[num] = true
            refreshStickers()
            addBox.Text = ""
        end
    end)
    closeSticker.MouseButton1Click:Connect(function()
        stickerModal.Visible = false
    end)

    stickerBtn.MouseButton1Click:Connect(function()
        refreshStickers()
        stickerModal.Visible = true
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
        Text = (opts and opts.HomeText)
            or "Credits: SorinSoftware\nRules:\n1) Be kind. No spam/harassment.\n2) No NSFW.\n3) No dox/threats.\n4) Follow Roblox TOS.",
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
        Text = "Online: ...",
        TextSize = 14,
        TextColor3 = palette.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    onlineLbl.Parent = homeFrame
    self.onlineLbl = onlineLbl
    self.homeFrame = homeFrame

    -- Accept rules button (simple local flag)
    local acceptBtn = new("TextButton", {
        Size = UDim2.new(0, 160, 0, 32),
        Position = UDim2.new(0, 0, 0, 138),
        BackgroundColor3 = palette.accent,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Text = "Accept rules",
        TextSize = 13,
        TextColor3 = Color3.fromRGB(255, 255, 255),
    })
    corner(acceptBtn, 8)
    gradient(acceptBtn)
    acceptBtn.Parent = homeFrame
    self.acceptBtn = acceptBtn

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
        frame.Position = clampToViewport(UDim2.fromOffset(pos.X, pos.Y))
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
        local needRules = not self:GetAcceptedRules()
        if tab == "chat" and needRules then
            -- force stay on home until accepted
            tab = "home"
        end
        self.currentTab = tab
        local isHome = tab == "home"
        homeFrame.Visible = isHome
        listHolder.Visible = (not isHome) and not self.collapsed
        inputBar.Visible = (not isHome) and not self.collapsed
        status.Visible = not isHome
        tabChat.TextColor3 = isHome and palette.subtext or palette.text
        tabHome.TextColor3 = isHome and palette.text or palette.subtext
        if isHome and self.acceptBtn then
            self.acceptBtn.Visible = not self:GetAcceptedRules()
        end
    end
    tabChat.MouseButton1Click:Connect(function()
        setTab("chat")
    end)
    tabHome.MouseButton1Click:Connect(function()
        setTab("home")
    end)
    -- initial enforce
    setTab(self.currentTab)

    -- init rules accept handler
    self:InitRules()
    return self
end

local function avatarHeadshot(userId)
    local thumbType = Enum.ThumbnailType.HeadShot
    local thumbSize = Enum.ThumbnailSize.Size100x100
    local content, _ = Players:GetUserThumbnailAsync(userId or 1, thumbType, thumbSize)
    return content
end

local function parseContent(raw)
    local text = raw or ""
    local stickerId = text:match("%[%[sticker:(%d+)]]")
    if stickerId then
        text = text:gsub("%[%[sticker:%d+]]", "", 1)
    end
    local replyId, replyName = text:match("%[%[reply:([^|]+)|([^%]]+)]%]")
    if replyId then
        text = text:gsub("%[%[reply:[^|]+|[^%]]+]%]", "", 1)
    end
    text = text:gsub("^%s+", "")
    return {
        text = text,
        stickerId = stickerId,
        reply = replyId and { id = replyId, name = replyName } or nil,
    }
end

function ChatUI:AddMessage(msg)
    if not self.scrolling then
        return
    end
    local id = msg.id or HttpService:GenerateGUID(false)
    local userId = tonumber(msg.roblox_user_id) or msg.user_id or 0
    local displayName = msg.username or msg.display_name or ("User_" .. tostring(userId))
    local parsed = parseContent(msg.content or "")
    local content = parsed.text
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
        Size = UDim2.new(1, 0, 0, 72),
        BackgroundColor3 = palette.card,
        BorderSizePixel = 0,
        LayoutOrder = msg.created_at or os.time(),
    })
    corner(card, 12)
    stroke(card, Color3.fromRGB(70, 70, 110), 1, 0.35)
    padding(card, 10)
    card.Parent = self.scrolling

    local avatar = new("ImageLabel", {
        Size = UDim2.new(0, 44, 0, 44),
        Position = UDim2.new(0, 0, 0, 4),
        BackgroundColor3 = palette.bubble,
        BorderSizePixel = 0,
        Image = avatarHeadshot(userId),
    })
    corner(avatar, 10)
    avatar.Parent = card

    local nameLbl = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -190, 0, 18),
        Position = UDim2.new(0, 56, 0, 0),
        Font = Enum.Font.GothamBold,
        Text = displayName .. "  |  " .. gameName,
        TextSize = 14,
        TextColor3 = palette.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    nameLbl.Parent = card

    -- Date label (uses created_at timestamp)
    local ts = msg.created_at or os.time()
    local dateLbl = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 80, 0, 16),
        Position = UDim2.new(1, -90, 0, 0),
        Font = Enum.Font.Gotham,
        Text = os.date("%Y-%m-%d %H:%M", ts),
        TextSize = 11,
        TextColor3 = palette.subtext,
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    dateLbl.Parent = card

    local replyBtn = new("TextButton", {
        Size = UDim2.new(0, 28, 0, 20),
        Position = UDim2.new(1, -70, 0, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = "<-",
        TextSize = 12,
        TextColor3 = palette.subtext,
    })
    replyBtn.Parent = card

    local bubble = new("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, -120, 0, 32),
        Position = UDim2.new(0, 56, 0, 20),
        BackgroundColor3 = palette.bubble,
        BorderSizePixel = 0,
    })
    corner(bubble, 10)
    stroke(bubble, Color3.fromRGB(50, 50, 70), 1, 0.3)
    padding(bubble, 8)
    bubble.Parent = card

    local yOffset = 0
    if parsed.reply then
        local replyFrame = new("Frame", {
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
        })
        replyFrame.Parent = bubble
        local replyLbl = new("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            Font = Enum.Font.Gotham,
            Text = "<- Reply to " .. tostring(parsed.reply.name or "?"),
            TextSize = 12,
            TextColor3 = palette.subtext,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        replyLbl.Parent = replyFrame
        yOffset = 20
    end

    if parsed.stickerId then
        self.stickerSet[parsed.stickerId] = true
        local sticker = new("ImageLabel", {
            Size = UDim2.new(0, 72, 0, 72),
            Position = UDim2.new(0, 0, 0, yOffset),
            BackgroundTransparency = 1,
            Image = "rbxassetid://" .. tostring(parsed.stickerId),
            ScaleType = Enum.ScaleType.Fit,
        })
        sticker.Parent = bubble
        yOffset = yOffset + 76
    end

    local contentLbl = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.new(0, 0, 0, yOffset),
        Font = Enum.Font.Gotham,
        Text = isDeleted and "[deleted]" or content,
        TextSize = 14,
        TextColor3 = palette.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
    })
    contentLbl.Parent = bubble

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

    replyBtn.MouseButton1Click:Connect(function()
        self.replyContext = { id = id, name = displayName, preview = content }
        if self.replyBar then
            local preview = string.sub(content, 1, 40)
            self.replyBar.Text = "Replying to " .. displayName .. (preview ~= "" and (": " .. preview) or "")
            self.replyBar.Visible = true
        end
        if self.replyCancel then
            self.replyCancel.Visible = true
        end
        if self.textBox then
            self.textBox:CaptureFocus()
        end
    end)

    replyBtn.MouseButton1Click:Connect(function()
        self.replyContext = { id = id, name = displayName, preview = content }
        if self.replyBar then
            local preview = string.sub(content, 1, 40)
            self.replyBar.Text = "Replying to " .. displayName .. (preview ~= "" and (": " .. preview) or "")
            self.replyBar.Visible = true
        end
        if self.replyCancel then
            self.replyCancel.Visible = true
        end
        if self.textBox then
            self.textBox:CaptureFocus()
        end
    end)

    replyBtn.MouseButton1Click:Connect(function()
        self.replyContext = { id = id, name = displayName }
        if self.replyBar then
            self.replyBar.Visible = true
            self.replyBar.Text = "Replying to " .. displayName
        end
        if self.replyCancel then
            self.replyCancel.Visible = true
        end
        if self.textBox then
            self.textBox:CaptureFocus()
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

-- Simple local flag (session-level) for rules acceptance
function ChatUI:GetAcceptedRules()
    if getgenv then
        getgenv()._sorin_rules_ok = getgenv()._sorin_rules_ok or false
        return getgenv()._sorin_rules_ok
    end
    return self._acceptedRules == true
end

function ChatUI:SetAcceptedRules()
    if getgenv then
        getgenv()._sorin_rules_ok = true
    end
    self._acceptedRules = true
end

function ChatUI:InitRules()
    if self.acceptBtn then
        self.acceptBtn.MouseButton1Click:Connect(function()
            self:SetAcceptedRules()
            self.acceptBtn.Visible = false
            -- switch to chat
            self.currentTab = "chat"
            self.homeFrame.Visible = false
            self.listHolder.Visible = true
            self.inputBar.Visible = true
            self.status.Visible = true
        end)
        -- hide button if already accepted
        if self:GetAcceptedRules() then
            self.acceptBtn.Visible = false
        end
    end
end

-- Call at end of Init setup

return setmetatable({}, ChatUI)
