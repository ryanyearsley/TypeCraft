-- Define color constants
local GREEN = { r = 0, g = 1, b = 0 }
local RED = { r = 1, g = 0, b = 0 }

-- Function to pick a random word from the list
local function PickRandomWord()
    return TypeCraftWords[math.random(#TypeCraftWords)]
end

-- Initialize variables
local TypeCraftFrame, TypeCraftWord, TypeCraftResult, TypeCraftInput, TypeCraftTimerText, TypeCraftWPMText
local currentWords = {}
local challengeActive = false
local timerRunning = false
local timerDuration = 30
local correctCount = 0
local errorCount = 0
local timerRemaining = timerDuration
local timerTicker

-- Function to trim whitespace from input
local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

-- Function to show temporary result messages
local function ShowTemporaryResultMessage(message, color)
    TypeCraftResult:SetTextColor(color.r, color.g, color.b)
    TypeCraftResult:SetText(message)
    C_Timer.After(0.3, function()
        TypeCraftResult:SetText("")
    end)
end

-- Function to update the word display
local function UpdateWordDisplay()
    local displayText = ""
    for _, word in ipairs(currentWords) do
        displayText = displayText .. word .. " "
    end
    TypeCraftWord:SetText(displayText)
end

-- Function to highlight the current word
local function HighlightCurrentWord()
    local displayText = ""
    for i, word in ipairs(currentWords) do
        if i == 1 then
            displayText = displayText .. "|cffff0000" .. word .. "|r "  -- Highlight in red
        else
            displayText = displayText .. word .. " "
        end
    end
    TypeCraftWord:SetText(displayText)
end

-- Function to start a new line of words
local function StartNewLine()
    currentWords = {}
    for i = 1, 10 do
        table.insert(currentWords, PickRandomWord())
    end
    UpdateWordDisplay()
    HighlightCurrentWord()
end

-- Function to start a new typing challenge
local function StartNewChallenge()
    correctCount = 0
    errorCount = 0
    currentWords = {}
    challengeActive = true
    timerRunning = false
    timerRemaining = timerDuration
    TypeCraftTimerText:SetText("Time: " .. timerRemaining)
    TypeCraftWord:SetText("")
    TypeCraftResult:SetText("")
    StartNewLine()
    TypeCraftFrame:Show()
    TypeCraftInput:SetText("")
    TypeCraftInput:SetFocus()
end

local function EndCurrentChallenge()
    if timerTicker then
        timerTicker:Cancel()
        timerTicker = nil
    end
    timerRemaining = 0
    timerRunning = false
    challengeActive = false
    local wordsPerMinute = math.floor((correctCount / timerDuration) * 60)
    TypeCraftWPMText:SetText("WPM: " .. wordsPerMinute)
    TypeCraftWord:SetText("")
    ShowTemporaryResultMessage(" Time's up!", RED)
end


-- Function to update the timer display
local function UpdateTimerDisplay()
    TypeCraftTimerText:SetText("Time: " .. timerRemaining)
end

-- Function to start the timer
local function StartTimer()
    if timerRunning or timerTicker then return end
    timerRunning = true
    timerTicker = C_Timer.NewTicker(1, function()
        timerRemaining = timerRemaining - 1
        UpdateTimerDisplay()
        if timerRemaining <= 0 then
            EndCurrentChallenge()
        end
    end)
end

-- Function to handle word entry
local function HandleWordEntry(input)
    if not challengeActive then return end

    if not timerRunning then
        StartTimer()
    end

    local trimmedInput = trim(input)
    if trimmedInput:lower() == currentWords[1]:lower() then
        ShowTemporaryResultMessage("Correct!", GREEN)
        correctCount = correctCount + 1
    else
        ShowTemporaryResultMessage("Wrong :(", RED)
        errorCount = errorCount + 1
    end
    table.remove(currentWords, 1)
    if #currentWords == 0 then
        StartNewLine()
    else
        HighlightCurrentWord()
    end
end

-- Create the main frame
TypeCraftFrame = CreateFrame("Frame", "TypeCraftFrame", UIParent, "BasicFrameTemplateWithInset")
TypeCraftFrame:SetSize(700, 160)
TypeCraftFrame:SetPoint("CENTER")
TypeCraftFrame:SetMovable(true)
TypeCraftFrame:EnableMouse(true)
TypeCraftFrame:RegisterForDrag("LeftButton")
TypeCraftFrame:SetScript("OnDragStart", TypeCraftFrame.StartMoving)
TypeCraftFrame:SetScript("OnDragStop", TypeCraftFrame.StopMovingOrSizing)
TypeCraftFrame:Hide()

-- Set the frame title
TypeCraftFrame.title = TypeCraftFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
TypeCraftFrame.title:SetPoint("LEFT", TypeCraftFrame.TitleBg, "LEFT", 5, 0)
TypeCraftFrame.title:SetText("TypeCraft")

-- Word display
TypeCraftWord = TypeCraftFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
TypeCraftWord:SetPoint("TOPRIGHT", TypeCraftFrame, "TOPRIGHT", -10, -30)
TypeCraftWord:SetJustifyH("RIGHT")  -- Align text to the right
TypeCraftWord:SetFont("Interface/AddOns/TypeCraft/fonts/RobotoMono.ttf", 14, "OUTLINE")

-- Result message
TypeCraftResult = TypeCraftFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
TypeCraftResult:SetPoint("BOTTOM", 0, 10)

-- Timer display
TypeCraftTimerText = TypeCraftFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
TypeCraftTimerText:SetPoint("BOTTOMLEFT", 10, 10)
TypeCraftTimerText:SetText("Time: " .. timerDuration)

TypeCraftWPMText = TypeCraftFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
TypeCraftWPMText:SetPoint("BOTTOMRIGHT", -10, 50)
TypeCraftWPMText:SetText("WPM: 0")

-- Typing input
TypeCraftInput = CreateFrame("EditBox", nil, TypeCraftFrame, "InputBoxTemplate")
TypeCraftInput:SetSize(200, 20)
TypeCraftInput:SetPoint("BOTTOM", 0, 30)
TypeCraftInput:SetAutoFocus(false)
TypeCraftInput:EnableKeyboard(true)
TypeCraftInput:SetScript("OnEnterPressed", function(self)
    HandleWordEntry(self:GetText())
    self:SetText("")
end)
TypeCraftInput:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
end)
TypeCraftInput:SetScript("OnKeyDown", function(self, key)
    if key == "SPACE" then
        HandleWordEntry(self:GetText())
        self:SetText("")
    end
end)

-- Timer duration dropdown
local function SetTimerDuration(value)
    timerDuration = tonumber(value) or 30
    timerRemaining = timerDuration
    TypeCraftTimerText:SetText("Time: " .. timerRemaining)
end

local function InitializeDropdown(self, level)
    local info = UIDropDownMenu_CreateInfo()

    for _, seconds in ipairs({15, 30, 45, 60}) do
        info = UIDropDownMenu_CreateInfo()  -- Important: fresh info each time
        info.text = seconds .. " seconds"
        info.value = seconds
        info.checked = (seconds == timerDuration)
        info.func = function()
            UIDropDownMenu_SetSelectedValue(self, seconds)
            SetTimerDuration(seconds)
            CloseDropDownMenus() -- Closes the menu after selection
        end
        UIDropDownMenu_AddButton(info, level)
    end
end

TypeCraftDropdown = CreateFrame("Frame", "TypeCraftDropdown", TypeCraftFrame, "UIDropDownMenuTemplate")
TypeCraftDropdown:SetPoint("BOTTOMRIGHT", -5, 10)
UIDropDownMenu_SetWidth(TypeCraftDropdown, 100)
UIDropDownMenu_SetText(TypeCraftDropdown, "Timer")
UIDropDownMenu_Initialize(TypeCraftDropdown, InitializeDropdown)
UIDropDownMenu_SetSelectedValue(TypeCraftDropdown, timerDuration)

-- Slash command to start the game
SLASH_TYPECRAFT1 = "/typecraft"
SlashCmdList["TYPECRAFT"] = StartNewChallenge
