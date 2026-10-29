--[[
    Block Spin · Items Snipe  (v7 — restyled)
    กดปุ่ม rarity = ดูเฉพาะเซิร์ฟที่มีแรร์นั้น
    wss://api.boblox-script.com/block-spin/items-snipe/ws
]]

local HttpService      = game:GetService("HttpService")
local Players          = game:GetService("Players")
local TeleportService  = game:GetService("TeleportService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui          = game:GetService("CoreGui")

local LP = Players.LocalPlayer
local WS_URL = "wss://api.boblox-script.com/block-spin/items-snipe/ws"
local PER_PAGE = 7

-- ═══════════════════════════════════════
--  WebSocket
-- ═══════════════════════════════════════
local function getWS()
    if syn and syn.websocket and syn.websocket.connect then
        return function(u) return syn.websocket.connect(u) end
    elseif WebSocket and WebSocket.connect then
        return function(u) return WebSocket.connect(u) end
    elseif fluxus and fluxus.websocket and fluxus.websocket.connect then
        return function(u) return fluxus.websocket.connect(u) end
    elseif krnl and krnl.websocket and krnl.websocket.connect then
        return function(u) return krnl.websocket.connect(u) end
    elseif getgenv and getgenv().WebSocket and getgenv().WebSocket.connect then
        return function(u) return getgenv().WebSocket.connect(u) end
    end
end

local connectWS = getWS()
if not connectWS then warn("[Snipe] No WebSocket") return end

local function parsePlaceId(s)
    if type(s) ~= "string" then return nil end
    local id = s:match("%((%d+)%)")
    return id and tonumber(id)
end

local function joinServer(jobId, server)
    if not jobId or jobId == "" then return false end
    local placeId = parsePlaceId(server) or game.PlaceId
    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, jobId, LP)
    end)
    return ok
end

-- ═══════════════════════════════════════
--  Theme  (one accent, rarity colors only as small markers)
-- ═══════════════════════════════════════
local C = {
    bg     = Color3.fromRGB(9, 9, 12),
    panel  = Color3.fromRGB(15, 15, 20),
    row    = Color3.fromRGB(21, 21, 29),
    line   = Color3.fromRGB(36, 36, 48),
    accent = Color3.fromRGB(255, 46, 126),
    text   = Color3.fromRGB(236, 236, 242),
    sub    = Color3.fromRGB(150, 150, 168),
    mute   = Color3.fromRGB(88, 88, 106),
    ok     = Color3.fromRGB(120, 255, 170),
    warn   = Color3.fromRGB(255, 200, 80),
    bad    = Color3.fromRGB(255, 80, 90),
}

local RARITY = {
    Omega     = Color3.fromRGB(255, 72, 72),
    Legendary = Color3.fromRGB(255, 196, 64),
    Epic      = Color3.fromRGB(176, 110, 255),
    AirDrop   = Color3.fromRGB(64, 200, 255),
    Default   = Color3.fromRGB(140, 140, 160),
}

local FONT_MONO = Enum.Font.Code

-- ═══════════════════════════════════════
--  Helpers
-- ═══════════════════════════════════════
local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 3)
    c.Parent = p
    return c
end

local function stroke(p, col, th)
    local s = Instance.new("UIStroke")
    s.Color = col or C.line
    s.Thickness = th or 1
    s.Parent = p
    return s
end

local function tw(obj, props, d)
    TweenService:Create(obj, TweenInfo.new(d or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function frame(props)
    local f = Instance.new("Frame")
    f.BorderSizePixel = 0
    f.BackgroundColor3 = props.color or C.panel
    f.BackgroundTransparency = props.bgt or 0
    f.Size = props.sz or UDim2.new(1, 0, 1, 0)
    f.Position = props.pos or UDim2.new()
    f.ZIndex = props.z or 1
    if props.parent then f.Parent = props.parent end
    return f
end

local function lbl(props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.TextColor3 = props.color or C.text
    l.Font = props.font or Enum.Font.Gotham
    l.TextSize = props.size or 12
    l.TextXAlignment = props.align or Enum.TextXAlignment.Left
    l.TextYAlignment = props.valign or Enum.TextYAlignment.Center
    l.TextTruncate = Enum.TextTruncate.AtEnd
    l.Text = props.text or ""
    l.Size = props.sz or UDim2.new(1, 0, 1, 0)
    l.Position = props.pos or UDim2.new()
    if props.parent then l.Parent = props.parent end
    return l
end

-- HUD-style corner marks on the window
local function brackets(parent, col)
    local L, T = 12, 2
    local function bar(sz, pos)
        frame({color = col, sz = sz, pos = pos, parent = parent, z = 6})
    end
    bar(UDim2.new(0, L, 0, T), UDim2.new(0, -1, 0, -1))
    bar(UDim2.new(0, T, 0, L), UDim2.new(0, -1, 0, -1))
    bar(UDim2.new(0, L, 0, T), UDim2.new(1, -L + 1, 0, -1))
    bar(UDim2.new(0, T, 0, L), UDim2.new(1, -T + 1, 0, -1))
    bar(UDim2.new(0, L, 0, T), UDim2.new(0, -1, 1, -T + 1))
    bar(UDim2.new(0, T, 0, L), UDim2.new(0, -1, 1, -L + 1))
    bar(UDim2.new(0, L, 0, T), UDim2.new(1, -L + 1, 1, -T + 1))
    bar(UDim2.new(0, T, 0, L), UDim2.new(1, -T + 1, 1, -L + 1))
end

-- ═══════════════════════════════════════
--  State
-- ═══════════════════════════════════════
local selectedRarity = "All"
local currentPage = 1
local allData = {}
local rows = {}
local filterBtns = {}
local pages = {}
local renderList  -- forward declaration
local seenIds, newIds = {}, {}      -- ตามดู jobId ที่เคยเห็น / เพิ่งเข้ามาใหม่
local firstLoad, lastUpdate = true, nil
local lastSig = nil               -- ลายเซ็นของหน้าที่แสดงอยู่ ไว้เช็คว่าต้องวาดใหม่ไหม

local function selectRarity(name)
    selectedRarity = name
    currentPage = 1
    lastSig = nil
    for n, f in pairs(filterBtns) do
        local on = (n == name)
        tw(f.btn, {BackgroundColor3 = on and C.row or C.panel})
        tw(f.nameL, {TextColor3 = on and C.text or C.sub})
        f.ul.BackgroundTransparency = on and 0 or 1
    end
    renderList()
end

-- ═══════════════════════════════════════
--  Window
-- ═══════════════════════════════════════
local WIN_W, WIN_H = 520, 520
local TITLE_H = 44

local Gui = Instance.new("ScreenGui")
Gui.Name = "BSSnipe"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.IgnoreGuiInset = true
pcall(function() Gui.Parent = CoreGui end)
if not Gui.Parent then Gui.Parent = LP:WaitForChild("PlayerGui") end

local Win = frame({
    color = C.bg,
    sz = UDim2.new(0, WIN_W, 0, WIN_H),
    pos = UDim2.new(0.5, -WIN_W / 2, 0.5, -WIN_H / 2),
    parent = Gui,
})
Win.Active = true
Win.ClipsDescendants = false
stroke(Win, C.line, 1)
brackets(Win, C.accent)

-- ── Title bar ─────────────────────────────
local TitleBar = frame({color = C.panel, sz = UDim2.new(1, 0, 0, TITLE_H), parent = Win})
frame({color = C.line, sz = UDim2.new(1, 0, 0, 1), pos = UDim2.new(0, 0, 1, -1), parent = TitleBar})
frame({color = C.accent, sz = UDim2.new(0, 28, 0, 2), pos = UDim2.new(0, 14, 1, -2), parent = TitleBar, z = 2})

lbl({text = "BLOCK SPIN", parent = TitleBar, sz = UDim2.new(0, 200, 0, 16), pos = UDim2.new(0, 14, 0, 7),
    font = Enum.Font.GothamBlack, size = 13})
lbl({text = "ITEMS SNIPE  //  v7.2", parent = TitleBar, sz = UDim2.new(0, 220, 0, 12), pos = UDim2.new(0, 14, 0, 24),
    font = FONT_MONO, size = 9, color = C.mute})

local function titleBtn(text, xOff, w)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w or 24, 0, 22)
    b.Position = UDim2.new(1, xOff, 0.5, -11)
    b.BackgroundTransparency = 1
    b.Text = text
    b.TextColor3 = C.sub
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.AutoButtonColor = false
    b.Parent = TitleBar
    return b
end

local CloseBtn = titleBtn("×", -30)
local MinBtn   = titleBtn("–", -56)
local SnipeTab = titleBtn("SNIPE", -146, 56)
local InfoTab  = titleBtn("INFO", -92, 50)

CloseBtn.MouseEnter:Connect(function() tw(CloseBtn, {TextColor3 = C.bad}) end)
CloseBtn.MouseLeave:Connect(function() tw(CloseBtn, {TextColor3 = C.sub}) end)
MinBtn.MouseEnter:Connect(function() tw(MinBtn, {TextColor3 = C.text}) end)
MinBtn.MouseLeave:Connect(function() tw(MinBtn, {TextColor3 = C.sub}) end)
CloseBtn.MouseButton1Click:Connect(function() Gui:Destroy() end)

-- ── Body ──────────────────────────────────
local Body = frame({bgt = 1, sz = UDim2.new(1, 0, 1, -TITLE_H), pos = UDim2.new(0, 0, 0, TITLE_H), parent = Win})

local SnipePage = frame({bgt = 1, parent = Body})
local InfoPage  = frame({bgt = 1, parent = Body})
InfoPage.Visible = false

pages.SNIPE = {btn = SnipeTab, frame = SnipePage}
pages.INFO  = {btn = InfoTab,  frame = InfoPage}

for name, p in pairs(pages) do
    p.ul = frame({color = C.accent, sz = UDim2.new(1, -12, 0, 2), pos = UDim2.new(0, 6, 1, -2), parent = p.btn, z = 2})
end

local function showTab(name)
    for n, p in pairs(pages) do
        local on = (n == name)
        p.frame.Visible = on
        tw(p.btn, {TextColor3 = on and C.text or C.sub})
        p.ul.BackgroundTransparency = on and 0 or 1
    end
end

SnipeTab.MouseButton1Click:Connect(function() showTab("SNIPE") end)
InfoTab.MouseButton1Click:Connect(function() showTab("INFO") end)

-- ═══════════════════════════════════════
--  PAGE: SNIPE — filter bar
-- ═══════════════════════════════════════
local FilterBar = frame({bgt = 1, sz = UDim2.new(1, -28, 0, 40), pos = UDim2.new(0, 14, 0, 12), parent = SnipePage})
local FilterLayout = Instance.new("UIListLayout")
FilterLayout.FillDirection = Enum.FillDirection.Horizontal
FilterLayout.Padding = UDim.new(0, 6)
FilterLayout.SortOrder = Enum.SortOrder.LayoutOrder
FilterLayout.Parent = FilterBar

local function makeFilter(name, order)
    local isAll = (name == "All")
    local col = isAll and C.accent or RARITY[name]

    local b = Instance.new("TextButton")
    b.LayoutOrder = order
    b.Size = UDim2.new(0.2, -5, 1, 0)
    b.BackgroundColor3 = C.panel
    b.BorderSizePixel = 0
    b.Text = ""
    b.AutoButtonColor = false
    b.Parent = FilterBar
    corner(b, 3)
    stroke(b, C.line, 1)

    local nameL = lbl({
        text = isAll and "ALL" or string.upper(name), parent = b,
        sz = UDim2.new(1, 0, 0, 12), pos = UDim2.new(0, 0, 0, 6),
        font = Enum.Font.GothamBold, size = 9, color = C.sub, align = Enum.TextXAlignment.Center,
    })
    local countL = lbl({
        text = "--", parent = b,
        sz = UDim2.new(1, 0, 0, 14), pos = UDim2.new(0, 0, 0, 18),
        font = FONT_MONO, size = 12, color = col, align = Enum.TextXAlignment.Center,
    })
    local ul = frame({color = col, sz = UDim2.new(1, 0, 0, 2), pos = UDim2.new(0, 0, 1, -2), bgt = 1, parent = b, z = 2})

    filterBtns[name] = {btn = b, nameL = nameL, countL = countL, ul = ul, color = col}

    b.MouseButton1Click:Connect(function() selectRarity(name) end)
    b.MouseEnter:Connect(function()
        if selectedRarity ~= name then tw(b, {BackgroundColor3 = C.row}) end
    end)
    b.MouseLeave:Connect(function()
        if selectedRarity ~= name then tw(b, {BackgroundColor3 = C.panel}) end
    end)
end

makeFilter("All", 0)
makeFilter("Omega", 1)
makeFilter("Legendary", 2)
makeFilter("Epic", 3)
makeFilter("AirDrop", 4)
selectRarity("All")

-- hint
local HintLbl = lbl({
    text = "", parent = SnipePage,
    sz = UDim2.new(1, -28, 0, 14), pos = UDim2.new(0, 14, 0, 60),
    font = Enum.Font.Gotham, size = 10, color = C.mute,
})

-- stats
local StatsRow = frame({bgt = 1, sz = UDim2.new(1, -28, 0, 22), pos = UDim2.new(0, 14, 0, 80), parent = SnipePage})
local StatItems = lbl({text = "0 ITEMS", parent = StatsRow, sz = UDim2.new(0.5, 0, 1, 0), font = FONT_MONO, size = 11, color = C.text})
local ConnDot   = frame({color = C.warn, sz = UDim2.new(0, 6, 0, 6), pos = UDim2.new(0.5, 0, 0.5, -3), parent = StatsRow})
local StatConn  = lbl({text = "CONNECTING", parent = StatsRow, sz = UDim2.new(0.25, -12, 1, 0), pos = UDim2.new(0.5, 12, 0, 0),
    font = FONT_MONO, size = 10, color = C.warn})
local StatTime  = lbl({text = "--:--:--", parent = StatsRow, sz = UDim2.new(0.25, 0, 1, 0), pos = UDim2.new(0.75, 0, 0, 0),
    font = FONT_MONO, size = 10, color = C.mute, align = Enum.TextXAlignment.Right})

frame({color = C.line, sz = UDim2.new(1, -28, 0, 1), pos = UDim2.new(0, 14, 0, 106), parent = SnipePage})

-- list
local ListFrame = frame({color = C.panel, sz = UDim2.new(1, -28, 1, -162), pos = UDim2.new(0, 14, 0, 116), parent = SnipePage})
ListFrame.ClipsDescendants = true
stroke(ListFrame, C.line, 1)

local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, 0, 1, 0)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 2
Scroll.ScrollBarImageColor3 = C.accent
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.Parent = ListFrame

local ListLay = Instance.new("UIListLayout")
ListLay.SortOrder = Enum.SortOrder.LayoutOrder
ListLay.Padding = UDim.new(0, 4)
ListLay.Parent = Scroll

local ListPad = Instance.new("UIPadding")
ListPad.PaddingTop = UDim.new(0, 4)
ListPad.PaddingBottom = UDim.new(0, 4)
ListPad.PaddingLeft = UDim.new(0, 4)
ListPad.PaddingRight = UDim.new(0, 4)
ListPad.Parent = Scroll

local Empty = lbl({
    text = "รอข้อมูลสด...", parent = Scroll,
    sz = UDim2.new(1, 0, 0, 40), font = Enum.Font.Gotham, size = 11, color = C.mute, align = Enum.TextXAlignment.Center,
})

-- page bar
local PageBar = frame({bgt = 1, sz = UDim2.new(1, -28, 0, 28), pos = UDim2.new(0, 14, 1, -40), parent = SnipePage})

local function pageBtn(text, anchorRight)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 28, 1, 0)
    b.Position = anchorRight and UDim2.new(1, -28, 0, 0) or UDim2.new(0, 0, 0, 0)
    b.BackgroundColor3 = C.panel
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = C.text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.AutoButtonColor = false
    b.Parent = PageBar
    corner(b, 3)
    stroke(b, C.line, 1)
    b.MouseEnter:Connect(function() tw(b, {BackgroundColor3 = C.row}) end)
    b.MouseLeave:Connect(function() tw(b, {BackgroundColor3 = C.panel}) end)
    return b
end

local PrevBtn = pageBtn("‹", false)
local NextBtn = pageBtn("›", true)
local PageInfo = lbl({
    text = "01 / 01", parent = PageBar,
    sz = UDim2.new(1, -72, 1, 0), pos = UDim2.new(0, 36, 0, 0),
    font = FONT_MONO, size = 11, color = C.sub, align = Enum.TextXAlignment.Center,
})

-- ═══════════════════════════════════════
--  PAGE: INFO
-- ═══════════════════════════════════════
local InfoCard = frame({color = C.panel, sz = UDim2.new(1, -28, 0, 220), pos = UDim2.new(0, 14, 0, 14), parent = InfoPage})
corner(InfoCard, 3)
stroke(InfoCard, C.line, 1)

lbl({text = "// HOW TO USE", parent = InfoCard, sz = UDim2.new(1, -28, 0, 14), pos = UDim2.new(0, 14, 0, 14),
    font = FONT_MONO, size = 10, color = C.accent})
lbl({text = "กดแรร์ด้านบนเพื่อกรองเซิร์ฟ\nเช่น กด Omega = แสดงเฉพาะเซิร์ฟที่มี Omega", parent = InfoCard,
    sz = UDim2.new(1, -28, 0, 44), pos = UDim2.new(0, 14, 0, 38),
    font = Enum.Font.Gotham, size = 12, color = C.sub, valign = Enum.TextYAlignment.Top})
lbl({text = "กด JOIN เพื่อเทเลพอร์ตเข้าเซิร์ฟ", parent = InfoCard, sz = UDim2.new(1, -28, 0, 18), pos = UDim2.new(0, 14, 0, 96),
    font = Enum.Font.Gotham, size = 12, color = C.sub})
lbl({text = "BLOCK SPIN · ITEMS SNIPE", parent = InfoCard, sz = UDim2.new(1, -28, 0, 16), pos = UDim2.new(0, 14, 0, 140),
    font = FONT_MONO, size = 10, color = C.mute})
lbl({text = "v7", parent = InfoCard, sz = UDim2.new(1, -28, 0, 16), pos = UDim2.new(0, 14, 0, 158),
    font = FONT_MONO, size = 10, color = C.mute})

-- ═══════════════════════════════════════
--  List logic
-- ═══════════════════════════════════════
local function clearRows()
    for _, r in ipairs(rows) do r:Destroy() end
    table.clear(rows)
end

local function makeRow(col, idx)
    local jobId, item, rarity, players, target, server = table.unpack(col)
    local rc = RARITY[rarity] or RARITY.Default
    local isNew = jobId and newIds[jobId]

    local row = frame({color = C.panel, sz = UDim2.new(1, 0, 0, 46), parent = Scroll})
    row.LayoutOrder = idx
    row.ClipsDescendants = true
    corner(row, 3)
    stroke(row, C.line, 1)

    frame({color = rc, sz = UDim2.new(0, 2, 1, 0), parent = row, z = 2})

    -- แฟลชเมื่อมีเซิร์ฟใหม่เข้ามาแบบสด ๆ
    if isNew then
        local flash = frame({color = C.accent, bgt = 0.75, parent = row, z = 0})
        tw(flash, {BackgroundTransparency = 1}, 2)
        task.delay(2.1, function() if flash.Parent then flash:Destroy() end end)
    end

    -- บรรทัดบน: ชื่อไอเทม / แรร์ / จำนวนคน / เซิร์ฟ
    lbl({text = tostring(item or "?"), parent = row, sz = UDim2.new(0.30, 0, 0, 16), pos = UDim2.new(0, 12, 0, 5),
        font = Enum.Font.GothamBold, size = 12})
    lbl({text = string.upper(tostring(rarity or "")), parent = row, sz = UDim2.new(0.14, 0, 0, 16), pos = UDim2.new(0.32, 0, 0, 5),
        font = Enum.Font.GothamBlack, size = 9, color = rc})
    lbl({text = string.format("%02d PLR", tonumber(players) or 0), parent = row, sz = UDim2.new(0.12, 0, 0, 16),
        pos = UDim2.new(0.46, 0, 0, 5), font = FONT_MONO, size = 9, color = C.sub})
    lbl({text = tostring(server or ""), parent = row, sz = UDim2.new(0.24, 0, 0, 16), pos = UDim2.new(0.59, 0, 0, 5),
        font = FONT_MONO, size = 9, color = C.mute})

    -- บรรทัดล่าง: JobId (กดเพื่อคัดลอก) / target
    local jobBtn = Instance.new("TextButton")
    jobBtn.BackgroundTransparency = 1
    jobBtn.BorderSizePixel = 0
    jobBtn.Size = UDim2.new(0.62, 0, 0, 14)
    jobBtn.Position = UDim2.new(0, 12, 0, 25)
    jobBtn.Font = FONT_MONO
    jobBtn.TextSize = 9
    jobBtn.TextXAlignment = Enum.TextXAlignment.Left
    jobBtn.TextTruncate = Enum.TextTruncate.AtEnd
    jobBtn.TextColor3 = C.accent
    jobBtn.Text = tostring(jobId or "—")
    jobBtn.AutoButtonColor = false
    jobBtn.Parent = row
    jobBtn.MouseEnter:Connect(function() tw(jobBtn, {TextColor3 = C.text}) end)
    jobBtn.MouseLeave:Connect(function() tw(jobBtn, {TextColor3 = C.accent}) end)
    jobBtn.MouseButton1Click:Connect(function()
        local copy = setclipboard or toclipboard or (syn and syn.write_clipboard)
        if copy and jobId then pcall(copy, tostring(jobId)) end
        jobBtn.Text = "COPIED"
        task.delay(1, function()
            if jobBtn.Parent then jobBtn.Text = tostring(jobId or "—") end
        end)
    end)

    lbl({text = tostring(target or "—"), parent = row, sz = UDim2.new(0.22, 0, 0, 14), pos = UDim2.new(0.66, 0, 0, 25),
        font = FONT_MONO, size = 9, color = C.mute})

    local join = Instance.new("TextButton")
    join.Size = UDim2.new(0, 46, 0, 20)
    join.Position = UDim2.new(1, -54, 0.5, -10)
    join.BackgroundColor3 = C.accent
    join.BackgroundTransparency = 1
    join.BorderSizePixel = 0
    join.Text = "JOIN"
    join.TextColor3 = C.accent
    join.Font = Enum.Font.GothamBlack
    join.TextSize = 10
    join.AutoButtonColor = false
    join.ZIndex = 3
    join.Parent = row
    corner(join, 3)
    stroke(join, C.accent, 1)

    join.MouseEnter:Connect(function()
        tw(join, {BackgroundTransparency = 0, TextColor3 = C.bg})
    end)
    join.MouseLeave:Connect(function()
        tw(join, {BackgroundTransparency = 1, TextColor3 = C.accent})
    end)
    join.MouseButton1Click:Connect(function()
        local ok = joinServer(jobId, server)
        join.Text = ok and "···" or "FAIL"
        task.delay(1.5, function()
            if join.Parent then join.Text = "JOIN" end
        end)
    end)

    row.MouseEnter:Connect(function() tw(row, {BackgroundColor3 = C.row}) end)
    row.MouseLeave:Connect(function() tw(row, {BackgroundColor3 = C.panel}) end)

    return row
end

local function updateCounts()
    local counts = { Omega = 0, Legendary = 0, Epic = 0, AirDrop = 0 }
    for _, col in ipairs(allData) do
        local r = col[3]
        if counts[r] ~= nil then counts[r] = counts[r] + 1 end
    end
    for name, f in pairs(filterBtns) do
        if name == "All" then
            f.countL.Text = string.format("%02d", #allData)
        else
            f.countL.Text = string.format("%02d", counts[name] or 0)
        end
    end
end

local function getFiltered()
    if selectedRarity == "All" then return allData end
    local out = {}
    for _, col in ipairs(allData) do
        if col[3] == selectedRarity then table.insert(out, col) end
    end
    return out
end

renderList = function()
    updateCounts()

    local filtered = getFiltered()
    local total = #filtered
    local totalPages = math.max(1, math.ceil(total / PER_PAGE))
    currentPage = math.clamp(currentPage, 1, totalPages)

    local startIdx = (currentPage - 1) * PER_PAGE + 1
    local endIdx = math.min(startIdx + PER_PAGE - 1, total)

    -- ถ้าแถวที่มองเห็นไม่เปลี่ยน ไม่ต้องวาดใหม่ (ไม่งั้นปุ่ม JOIN โดนลบตอนกดพอดี)
    local parts = {selectedRarity, currentPage, total}
    for i = startIdx, endIdx do
        local c = filtered[i]
        parts[#parts + 1] = table.concat({tostring(c[1]), tostring(c[2]), tostring(c[3]), tostring(c[4])}, "|")
    end
    local sig = table.concat(parts, ";")
    if sig == lastSig then return end
    lastSig = sig

    local keepPos = Scroll.CanvasPosition
    clearRows()

    Empty.Visible = (total == 0)
    if #allData == 0 then
        Empty.Text = "รอข้อมูลสด..."
    elseif selectedRarity ~= "All" then
        Empty.Text = "ไม่มีเซิร์ฟที่มี " .. selectedRarity
    else
        Empty.Text = "ไม่มีรายการ"
    end

    for i = startIdx, endIdx do
        table.insert(rows, makeRow(filtered[i], i))
    end

    if selectedRarity == "All" then
        HintLbl.Text = "กดแรร์เพื่อกรองเฉพาะเซิร์ฟที่มีแรร์นั้น"
        if total == 0 then
            StatItems.Text = "0 ITEMS"
        else
            StatItems.Text = string.format("%d–%d / %d", startIdx, endIdx, total)
        end
    else
        HintLbl.Text = "กรอง: " .. selectedRarity .. "  ·  กด ALL เพื่อล้าง"
        if total == 0 then
            StatItems.Text = "0 " .. string.upper(selectedRarity)
        else
            StatItems.Text = string.format("%d–%d / %d  %s", startIdx, endIdx, total, string.upper(selectedRarity))
        end
    end

    PageInfo.Text = string.format("%02d / %02d", currentPage, totalPages)
    PrevBtn.TextColor3 = currentPage <= 1 and C.mute or C.text
    NextBtn.TextColor3 = currentPage >= totalPages and C.mute or C.text
    task.defer(function() Scroll.CanvasPosition = keepPos end)
end

PrevBtn.MouseButton1Click:Connect(function()
    if currentPage > 1 then
        currentPage = currentPage - 1
        lastSig = nil
        renderList()
    end
end)
NextBtn.MouseButton1Click:Connect(function()
    local tp = math.max(1, math.ceil(#getFiltered() / PER_PAGE))
    if currentPage < tp then
        currentPage = currentPage + 1
        lastSig = nil
        renderList()
    end
end)

local function extractCols(payload)
    if type(payload) ~= "table" then return nil end
    local d = payload.data
    if type(d) == "table" then
        if type(d.columns) == "table" then return d.columns end
        if #d > 0 then return d end
    end
    if type(payload.columns) == "table" then return payload.columns end
    if #payload > 0 then return payload end
    return nil
end

local function updateFromPayload(payload)
    local cols = extractCols(payload)
    if not cols then return end

    -- หา jobId ที่เพิ่งเข้ามาใหม่ (ไม่ flash ตอนโหลดครั้งแรก)
    table.clear(newIds)
    for _, col in ipairs(cols) do
        local id = col[1]
        if id and not seenIds[id] then
            seenIds[id] = true
            if not firstLoad then newIds[id] = true end
        end
    end
    firstLoad = false

    allData = cols
    lastUpdate = os.clock()
    renderList()
end

-- ตัวเลข "UPD 3s" เดินทุกวินาที ให้เห็นว่าข้อมูลสดอยู่
task.spawn(function()
    while Gui.Parent do
        if lastUpdate then
            StatTime.Text = string.format("UPD %ds", math.floor(os.clock() - lastUpdate))
        end
        task.wait(1)
    end
end)

local function setConn(state)
    local col, txt
    if state == "live" then
        col, txt = C.ok, "LIVE"
    elseif state == "wait" then
        col, txt = C.warn, "CONNECTING"
    elseif state == "error" then
        col, txt = C.bad, "ERROR"
    else
        col, txt = C.bad, "OFFLINE"
    end
    ConnDot.BackgroundColor3 = col
    StatConn.Text = txt
    StatConn.TextColor3 = col
end

-- ═══════════════════════════════════════
--  Websocket
-- ═══════════════════════════════════════
local ws, running = nil, true

local function onMsg(msg)
    local data = msg
    if type(msg) == "string" then
        local ok, decoded = pcall(function() return HttpService:JSONDecode(msg) end)
        if not ok then return end
        data = decoded
    end
    if type(data) == "table" and extractCols(data) then
        updateFromPayload(data)
        setConn("live")
    end
end

local function connect()
    if not running then return end
    setConn("wait")
    local ok, sock = pcall(connectWS, WS_URL)
    if not ok or not sock then
        setConn("error")
        task.delay(3, connect)
        return
    end
    ws = sock
    setConn("live")
    if sock.OnMessage then sock.OnMessage:Connect(onMsg) end
    pcall(function()
        if sock.OnClose then
            sock.OnClose:Connect(function()
                setConn("offline")
                ws = nil
                task.delay(3, connect)
            end)
        end
    end)
end

Gui.Destroying:Connect(function()
    running = false
    if ws then
        pcall(function()
            if ws.Close then ws:Close() end
            if ws.close then ws:close() end
            if ws.Disconnect then ws:Disconnect() end
        end)
    end
end)

-- ═══════════════════════════════════════
--  Minimize + drag
-- ═══════════════════════════════════════
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then Body.Visible = false end
    tw(Win, {Size = minimized and UDim2.new(0, WIN_W, 0, TITLE_H) or UDim2.new(0, WIN_W, 0, WIN_H)}, 0.25)
    if not minimized then
        task.delay(0.25, function() Body.Visible = true end)
    end
end)

do
    local dragging, dragStart, startPos
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Win.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            Win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

showTab("SNIPE")
connect()
print("[BS Snipe] v7.2")
