-- Define color constants
local GREEN = { r = 0, g = 1, b = 0 }
local RED = { r = 1, g = 0, b = 0 }

-- Function to pick a random word from the list
local function PickRandomWord()
    return TypeCraftWords[math.random(#TypeCraftWords)]
end

-- Initialize variables
local TypeCraftFrame, TypeCraftWord, TypeCraftResult, TypeCraftInput, TypeCraftTimerText
local currentWords = {}
local challengeActive = false
local timerRunning = false
local timerDuration = 30
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

-- Function to update the timer display
local function UpdateTimerDisplay()
    TypeCraftTimerText:SetText("Time: " .. timerRemaining)
end

-- Function to start the timer
local function StartTimer()
    if timerRunning then return end
    timerRunning = true
    timerTicker = C_Timer.NewTicker(1, function()
        timerRemaining = timerRemaining - 1
        UpdateTimerDisplay()
        if timerRemaining <= 0 then
            timerTicker:Cancel()
            challengeActive = false
            TypeCraftWord:SetText("")
            ShowTemporaryResultMessage("⏰ Time's up!", RED)
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
    else
        ShowTemporaryResultMessage("Wrong :(", RED)
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
TypeCraftFrame:SetSize(700, 120)
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

-- Result message
TypeCraftResult = TypeCraftFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
TypeCraftResult:SetPoint("BOTTOM", 0, 10)

-- Timer display
TypeCraftTimerText = TypeCraftFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
TypeCraftTimerText:SetPoint("BOTTOMLEFT", 10, 10)
TypeCraftTimerText:SetText("Time: " .. timerDuration)

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

-- Slash command to start the game
SLASH_TYPECRAFT1 = "/typecraft"
SlashCmdList["TYPECRAFT"] = StartNewChallenge
