-- Define constants
local GREEN = { r = 0, g = 1, b = 0 }
local RED = { r = 1, g = 0, b = 0 }
local WHITE = { r = 1, g = 1, b = 1 }

local shareChannels = {
    { text = "Say", value = "SAY" },
    { text = "Party", value = "PARTY" },
    { text = "Raid", value = "RAID" },
    { text = "Guild", value = "GUILD" },
}


-- Function to pick a random word from the list
local function PickRandomWord()
    return TypeCraftWords[math.random(#TypeCraftWords)]
end

-- Initialize variables
local TypeCraftFrame, TypeCraftWord, TypeCraftWordNext, TypeCraftMessage, TypeCraftInput, TypeCraftTimerText, TypeCraftWPMText
local floatingFeedback, animGroup, moveUp, fadeOut
local ResultsTitle, ResultsWPM, ResultsAccuracy, ResultsKPM, TypeCraftResultsFrame, CloseResultsButton
local currentWords = {}
local nextWords = {}
local challengeActive = false
local timerRunning = false
local timerDuration = 30
local correctCount = 0
local characterCount = 0
local totalKeystrokes = 0
local errorCount = 0
local timerRemaining = timerDuration
local timerTicker
local bestAllTimeWPM = 0
local bestSessionWPM = 0
local lastWPM, lastAccuracy,lastKPM
local selectedChannel = "SAY" -- default
-- Constants
local CHAR_WIDTH = 8  -- approximate width of one character in pixels (adjust if needed)
local LINE_PADDING = 5


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
            displayText = displayText .. "|cff4c99ff" .. word .. "|r "
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
local MAX_CHAR_WIDTH = 80  -- Adjust based on your frame/font

local function BuildWordLine()
    local line = {}
    local charCount = 0

    while true do
        local word = PickRandomWord()
        local wordLength = #word + 1  -- +1 for space
        if charCount + wordLength > MAX_CHAR_WIDTH then break end
        table.insert(line, word)
        charCount = charCount + wordLength
    end

    return line
end

local function StartNewLine()
    -- Promote nextWords to currentWords if it exists
    if nextWords and #nextWords > 0 then
        currentWords = CopyTable(nextWords)
    else
        currentWords = BuildWordLine()
    end

    nextWords = BuildWordLine()

    UpdateWordDisplay()
    HighlightCurrentWord()
end
-- Function to start a new typing challenge
local function StartNewChallenge()
    if timerTicker then
        timerTicker:Cancel()
        timerTicker = nil
    end
    TypeCraftResultsFrame:Hide()
    correctCount = 0
    characterCount = 0
    totalKeystrokes = 0
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
    local kpm = math.floor(totalKeystrokes / timeInMinutes)
    local accuracy = totalKeystrokes > 0 and math.floor((characterCount / totalKeystrokes) * 100) or 0
    local chatMsg = string.format(
        "I just scored %d WPM with %d%% accuracy and %d KPM in TypeCraft!",
        wpm, accuracy, kpm
    )
    lastWPM = wpm
    lastAccuracy = accuracy
    lastKPM = kpm
    TypeCraftWPMText:SetText("WPM (Last): " .. wpm)
    if (wpm > bestSessionWPM) then
        bestSessionWPM = wpm
        BestResultsWPMText:SetText("WPM (Best): " .. bestSessionWPM)
    end
    TypeCraftWord:SetText("")
    TypeCraftWordNext:SetText("")
    ShowMessage("Time's up!", WHITE)

    -- Show the results
    ResultsWPM:SetText("Words per Minute: " .. wpm)
    ResultsAccuracy:SetText("Accuracy: " .. accuracy .. "%")
    ResultsKPM:SetText("Keystrokes per Minute: " .. kpm)
    TypeCraftResultsFrame:Show()
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
        if timerRemaining <= 1 then
            timerRemaining = 0
            UpdateTimerDisplay()
            EndCurrentChallenge()
        else
            timerRemaining = timerRemaining - 1
            UpdateTimerDisplay()
        end
    end)
end

local function ShowFloatingWordFeedback(word, playerTyped)
    local wasCorrect = word == playerTyped

    local r, g, b = 0, 1, 0 -- green
    if not wasCorrect then
        r, g, b = 1, 0, 0 -- red
    end

    floatingFeedback:SetFontObject(TypeCraftWord:GetFontObject())
    floatingFeedback:SetText(playerTyped)
    floatingFeedback:SetTextColor(r, g, b)

    -- Calculate total width of remaining text
    local fullText = table.concat(currentWords, " ")
    local fullTextWidth = string.len(fullText) * CHAR_WIDTH
    local wordIndex = nil
    for i, w in ipairs(currentWords) do
        if w == word then
            wordIndex = i
            break
        end
    end

    if not wordIndex then
        -- Word not found; handle accordingly
        return
    end
    -- Calculate the number of characters after the word
    local afterChars = 0
    for i = wordIndex + 1, #currentWords do
        afterChars = afterChars + string.len(currentWords[i]) + 1  -- word + space
    end

    -- Offset from center, working backwards from the full string width
    local wordLength = string.len(playerTyped)
    local wordOffsetPixels = afterChars * CHAR_WIDTH + (wordLength * CHAR_WIDTH / 2)

    local centerX, centerY = TypeCraftWord:GetCenter()
    local wordX = centerX + (fullTextWidth / 2) - wordOffsetPixels

    floatingFeedback:ClearAllPoints()
    floatingFeedback:SetPoint("CENTER", UIParent, "BOTTOMLEFT", wordX, centerY)
    floatingFeedback:SetAlpha(1)
    floatingFeedback:Show()

    animGroup:Stop()
    animGroup:Play()
end
-- Function to handle word entry
local function HandleWordEntry(input)
    if not challengeActive or not currentWords or #currentWords == 0 then return end
    local trimmedInput = trim(input)
    if trimmedInput:lower() == currentWords[1]:lower() then
        ShowTemporaryMessage("Correct!", GREEN)
        correctCount = correctCount + 1 
        characterCount = characterCount + #currentWords[1] + 1  -- +1 for the space
    else
        ShowTemporaryMessage("Wrong :(", RED)
        errorCount = errorCount + 1
    end
    ShowFloatingWordFeedback(currentWords[1], trimmedInput)
    totalKeystrokes = totalKeystrokes + #currentWords[1] + 1
    table.remove(currentWords, 1)
    if #currentWords == 0 then
        StartNewLine()
    else
        HighlightCurrentWord()
    end
end

-- Create the main frame
TypeCraftFrame = CreateFrame("Frame", "TypeCraftFrame", UIParent, "BackdropTemplate")
TypeCraftFrame:SetSize(700, 160)
TypeCraftFrame:SetPoint("CENTER")
TypeCraftFrame:SetMovable(true)
TypeCraftFrame:EnableMouse(true)
TypeCraftFrame:RegisterForDrag("LeftButton")
TypeCraftFrame:SetScript("OnDragStart", TypeCraftFrame.StartMoving)
TypeCraftFrame:SetScript("OnDragStop", TypeCraftFrame.StopMovingOrSizing)
TypeCraftFrame:Hide()
TypeCraftFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})

closeButton = CreateFrame("Button", nil, TypeCraftFrame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", TypeCraftFrame, "TOPRIGHT", -6, -6)
closeButton:SetScale(0.8) -- optional, makes the button a bit smaller

TypeCraftFrame:SetBackdropColor(0, 0, 0, 0.6) -- Last value is alpha
-- Set the frame title
TypeCraftFrame.title = TypeCraftFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
TypeCraftFrame.title:SetPoint("CENTER", TypeCraftFrame, "TOP", 0, -20)
TypeCraftFrame.title:SetText("TypeCraft")
-- Word display
TypeCraftWord = TypeCraftFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
TypeCraftWord:SetPoint("TOPRIGHT", TypeCraftFrame, "TOPRIGHT", -10, -50)
TypeCraftWord:SetJustifyH("RIGHT")  -- Align text to the right
TypeCraftWord:SetFont("Interface/AddOns/TypeCraft/fonts/RobotoMono.ttf", 12, "OUTLINE")

TypeCraftWordNext =  TypeCraftFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
TypeCraftWordNext:SetPoint("TOPRIGHT", TypeCraftFrame, "TOPRIGHT", -10, -70)
TypeCraftWordNext:SetJustifyH("RIGHT")  -- Align text to the right
TypeCraftWordNext:SetFont("Interface/AddOns/TypeCraft/fonts/RobotoMono.ttf", 12, "OUTLINE")

-- Result message
TypeCraftMessage = TypeCraftFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
TypeCraftMessage:SetPoint("BOTTOM", 0, 13)

-- Timer display
TypeCraftTimerText = TypeCraftFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
TypeCraftTimerText:SetPoint("BOTTOM", 0, 55)
TypeCraftTimerText:SetText("Time: " .. timerDuration)

TypeCraftWPMText = TypeCraftFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
TypeCraftWPMText:SetPoint("BOTTOMRIGHT", -10, 10)
TypeCraftWPMText:SetText("WPM (Last): 0")
-- Floating feedback text
floatingFeedback = TypeCraftFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
floatingFeedback:SetFont("Interface/AddOns/TypeCraft/fonts/RobotoMono.ttf", 12, "OUTLINE")
floatingFeedback:SetPoint("CENTER") -- initial position (will update per use)
floatingFeedback:Hide()

-- Create animation group
animGroup = floatingFeedback:CreateAnimationGroup()

-- Move up
moveUp = animGroup:CreateAnimation("Translation")
moveUp:SetOffset(0, 30)
moveUp:SetDuration(1)

-- Fade out
fadeOut = animGroup:CreateAnimation("Alpha")
fadeOut:SetFromAlpha(1)
fadeOut:SetToAlpha(0)
fadeOut:SetDuration(1)

-- Hide on finish
animGroup:SetScript("OnFinished", function()
    floatingFeedback:Hide()
end)


BestResultsWPMText = TypeCraftFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
BestResultsWPMText:SetPoint("BOTTOMRIGHT", -10, 25)
BestResultsWPMText:SetText("WPM (Best): 0")
-- Post-game results frame
TypeCraftResultsFrame = CreateFrame("Frame", "TypeCraftResultsFrame", TypeCraftFrame, "BasicFrameTemplateWithInset")
TypeCraftResultsFrame:SetSize(300, 160)
TypeCraftResultsFrame:SetPoint("LEFT", TypeCraftFrame, "RIGHT", 5, 0)
TypeCraftResultsFrame:Hide()
TypeCraftResultsFrame.title = TypeCraftResultsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
TypeCraftResultsFrame.title:SetPoint("CENTER", TypeCraftResultsFrame.TitleBg, "CENTER", 0, 0)
TypeCraftResultsFrame.title:SetText("Challenge Complete!")
-- WPM display

ResultsWPM = TypeCraftResultsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
ResultsWPM:SetPoint("TOPLEFT", 15, -45)

-- Accuracy display
ResultsAccuracy = TypeCraftResultsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
ResultsAccuracy:SetPoint("TOPLEFT", 15, -65)

-- KPM display
ResultsKPM = TypeCraftResultsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
ResultsKPM:SetPoint("TOPLEFT", 15, -85)

-- Close button
CloseResultsButton = CreateFrame("Button", nil, TypeCraftResultsFrame, "UIPanelButtonTemplate")
CloseResultsButton:SetSize(60, 22)
CloseResultsButton:SetPoint("BOTTOM", -30, 10)
CloseResultsButton:SetText("Close")
CloseResultsButton:SetScript("OnClick", function()
    TypeCraftResultsFrame:Hide()
end)
local ShareButton = CreateFrame("Button", nil, TypeCraftResultsFrame, "UIPanelButtonTemplate")
ShareButton:SetSize(60, 22)
ShareButton:SetPoint("BOTTOM", 30, 10)
ShareButton:SetText("Share")
ShareButton:SetScript("OnClick", function()
        local chatMsg = string.format(
        "I just scored %d WPM with %d%% accuracy and %d KPM in TypeCraft!",
        lastWPM or 0, lastAccuracy or 0, lastKPM or 0
    )
    SendChatMessage(chatMsg, selectedChannel)
    end)

local shareChannelDropdown = CreateFrame("Frame", "MyAddon_ShareChannelDropdown", ShareButton, "UIDropDownMenuTemplate")
shareChannelDropdown:SetPoint("BOTTOMRIGHT", TypeCraftResultsFrame, "BOTTOMRIGHT", 10, 0)
UIDropDownMenu_SetWidth(shareChannelDropdown, 60)
UIDropDownMenu_SetText(shareChannelDropdown, "Say") -- default

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
TypeCraftInput:SetScript("OnTextChanged", function(self)
    if not timerRunning and trim(self:GetText()) ~= "" then
        StartTimer()
    end
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
            StartNewChallenge()
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
UIDropDownMenu_Initialize(shareChannelDropdown, function(self, level)
    for _, option in ipairs(shareChannels) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = option.text
        info.value = option.value
        info.func = function()
            selectedChannel = option.value
            UIDropDownMenu_SetText(shareChannelDropdown, option.text)
        end
        UIDropDownMenu_AddButton(info, level)
    end
end)

-- Reset button
local ResetButton = CreateFrame("Button", nil, TypeCraftFrame, "UIPanelButtonTemplate")
ResetButton:SetSize(80, 22)
ResetButton:SetPoint("BOTTOMLEFT", 40, 45)  -- Above the dropdown
ResetButton:SetText("Reset")
ResetButton:SetScript("OnClick", function()
    if timerTicker then
        timerTicker:Cancel()
        timerTicker = nil
    end
    StartNewChallenge()
end)
chatMsg = string.format(
    "I just scored %d WPM with %d%% accuracy and %d KPM in TypeCraft!",
    wpm, accuracy, kpm
)

function SafeSendChat(msg, channel)
    if not InCombatLockdown() and msg and msg ~= "" then
        local success, err = pcall(function()
            SendChatMessage(msg, channel or "SAY")
        end)
        if not success then
            print("|cffff0000TypeCraft: Failed to send message.|r")
        end
    end
end

-- Slash command to start the game
SLASH_TYPECRAFT1 = "/typecraft"
SLASH_TYPECRAFT2 = "/tc"
SlashCmdList["TYPECRAFT"] = StartNewChallenge
