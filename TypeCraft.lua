-- Define color constants
local GREEN = { r = 0, g = 1, b = 0 }
local RED = { r = 1, g = 0, b = 0 }
local WHITE = { r = 1, g = 1, b = 1 }

-- Function to pick a random word from the list
local function PickRandomWord()
    return TypeCraftWords[math.random(#TypeCraftWords)]
end

-- Initialize variables
local TypeCraftFrame, TypeCraftWord, TypeCraftWordNext, TypeCraftMessage, TypeCraftInput, TypeCraftTimerText, TypeCraftWPMText
local currentWords = {}
local nextWords = {}
local challengeActive = false
local timerRunning = false
local timerDuration = 30
local correctCount = 0
local characterCount = 0;
local errorCount = 0
local timerRemaining = timerDuration
local timerTicker

-- Function to trim whitespace from input
local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function ShowMessage(message, color)
    TypeCraftMessage:SetTextColor(color.r, color.g, color.b)
    TypeCraftMessage:SetText(message)
end

local function ShowTemporaryMessage(message, color)
    TypeCraftMessage:SetTextColor(color.r, color.g, color.b)
    TypeCraftMessage:SetText(message)
    C_Timer.After(0.3, function()
        TypeCraftMessage:SetText("")
    end)
end

-- Function to update the word display
local function UpdateWordDisplay()
    local displayText = ""
    for _, word in ipairs(currentWords) do
        displayText = displayText .. word .. " "
    end
    TypeCraftWord:SetText(displayText)
    local nextDisplayText = ""
    for _, word in ipairs(nextWords) do
        nextDisplayText = nextDisplayText .. word .. " "
    end
    TypeCraftWordNext:SetText(nextDisplayText)
end

-- Function to highlight the current word
local function HighlightCurrentWord()
    if not currentWords or #currentWords == 0 then
        TypeCraftWord:SetText("")
        return
    end
    
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

local function CopyTable(source)
    local copy = {}
    for i, v in ipairs(source) do
        copy[i] = v
    end
    return copy
end

-- Function to start a new line of words
local function StartNewLine()
    if nextWords and #nextWords > 0 then
        currentWords = CopyTable(nextWords)
    else
        currentWords = {} 
        for i = 1, 10 do
            table.insert(currentWords, PickRandomWord())
        end
    end
    nextWords = {}
    for i = 1, 10 do
        table.insert(nextWords, PickRandomWord())
    end
    UpdateWordDisplay()
    HighlightCurrentWord()
end
-- Function to start a new typing challenge
local function StartNewChallenge()
    correctCount = 0
    characterCount = 0
    errorCount = 0
    currentWords = {}
    nextWords= {}
    challengeActive = true
    timerRunning = false
    timerRemaining = timerDuration
    TypeCraftTimerText:SetText("Time: " .. timerRemaining)
    TypeCraftWord:SetText("")
    ShowMessage("Time begins when you enter the first character.", WHITE)
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
    local timeInMinutes = timerDuration / 60
    local wpm = math.floor((characterCount / 5) / timeInMinutes)
    TypeCraftWPMText:SetText("WPM: " .. wpm)
    TypeCraftWord:SetText("")
    TypeCraftWordNext:SetText("")
    ShowMessage("Time's up!", WHITE)
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
    if not challengeActive or not currentWords or #currentWords == 0 then return end
    if not timerRunning then
        StartTimer()
    end

    local trimmedInput = trim(input)
    if trimmedInput:lower() == currentWords[1]:lower() then
        ShowTemporaryMessage("Correct!", GREEN)
        correctCount = correctCount + 1 
        characterCount = characterCount + #currentWords[1] + 1  -- +1 for the space
    else
        ShowTemporaryMessage("Wrong :(", RED)
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
TypeCraftFrame:SetSize(900, 160)
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
TypeCraftWord:SetFont("Interface/AddOns/TypeCraft/fonts/RobotoMono.ttf", 12, "OUTLINE")

TypeCraftWordNext =  TypeCraftFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
TypeCraftWordNext:SetPoint("TOPRIGHT", TypeCraftFrame, "TOPRIGHT", -10, -50)
TypeCraftWordNext:SetJustifyH("RIGHT")  -- Align text to the right
TypeCraftWordNext:SetFont("Interface/AddOns/TypeCraft/fonts/RobotoMono.ttf", 12, "OUTLINE")

-- Result message
TypeCraftMessage = TypeCraftFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
TypeCraftMessage:SetPoint("BOTTOM", 0, 10)

-- Timer display
TypeCraftTimerText = TypeCraftFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
TypeCraftTimerText:SetPoint("BOTTOM", 0, 55)
TypeCraftTimerText:SetText("Time: " .. timerDuration)

TypeCraftWPMText = TypeCraftFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
TypeCraftWPMText:SetPoint("BOTTOMRIGHT", -10, 10)
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
TypeCraftDropdown:SetPoint("BOTTOMLEFT", 5, 10)
UIDropDownMenu_SetWidth(TypeCraftDropdown, 100)
UIDropDownMenu_SetText(TypeCraftDropdown, "Timer")
UIDropDownMenu_Initialize(TypeCraftDropdown, InitializeDropdown)
UIDropDownMenu_SetSelectedValue(TypeCraftDropdown, timerDuration)

-- Slash command to start the game
SLASH_TYPECRAFT1 = "/typecraft"
SlashCmdList["TYPECRAFT"] = StartNewChallenge
