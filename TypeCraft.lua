
------------------------------------------------------------------------CONSTANTS------------------------------------------------------------------------
local GREEN = { r = 0, g = 1, b = 0 }
local RED = { r = 1, g = 0, b = 0 }
local WHITE = { r = 1, g = 1, b = 1 }

-- Constants
local MAX_LINE_WIDTH = 80  -- Adjust based on your frame/font
local CHAR_WIDTH = 8  -- approximate width of one character in pixels (adjust if needed)
local shareChannels = {
    { text = "Say", value = "SAY" },
    { text = "Party", value = "PARTY" },
    { text = "Raid", value = "RAID" },
    { text = "Guild", value = "GUILD" },
}

------------------------------------------------------------------------INITIALIZATION------------------------------------------------------------------------

--ui
local mainFrame, mainCloseButton, currentLineText, nextLineText, messageText, inputField, resetButton, settingsButton
local timerText, lastWpmText, bestSessionWpmText
local floatingFeedback, animGroup, moveUp, fadeOut
local resultsFrame, resultsWpmText, resultsAccuracyText, resultsKpmText, shareButton, shareChannelDropdown
local settingsFrame, timerDropdownLabel, timerDropdown, includeTitle
local easyCheckbox, mediumCheckbox, hardCheckbox, fantasyCheckbox, goofyCheckbox, acronymCheckbox
--core game logic
local currentWords = {}
local nextWords = {}
local challengeActive = false
local timerRunning = false
local timerRemaining = 0
--results stuff
local correctCount = 0
local characterCount = 0
local totalKeystrokes = 0
local errorCount = 0
local bestSessionWPM = 0
local lastWPM, lastAccuracy, lastKPM
--settings
local timerDuration = 30
local selectedChannel = "SAY" -- default


------------------------------------------------------------------------CORE LOGIC------------------------------------------------------------------------
-- Function to trim whitespace from input
local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function ShowMessage(message, color)
    messageText:SetTextColor(color.r, color.g, color.b)
    messageText:SetText(message)
end

local function ShowTemporaryMessage(message, color)
    messageText:SetTextColor(color.r, color.g, color.b)
    messageText:SetText(message)
    C_Timer.After(0.3, function()
        messageText:SetText("")
    end)
end

-- Function to update the word display
local function UpdateWordDisplay()
    local displayText = ""
    for _, word in ipairs(currentWords) do
        displayText = displayText .. word .. " "
    end
    currentLineText:SetText(displayText)
    local nextDisplayText = ""
    for _, word in ipairs(nextWords) do
        nextDisplayText = nextDisplayText .. word .. " "
    end
    nextLineText:SetText(nextDisplayText)
end

-- Function to highlight the current word
local function HighlightCurrentWord()
    if not currentWords or #currentWords == 0 then
        currentLineText:SetText("")
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
    currentLineText:SetText(displayText)
end

local function CopyTable(source)
    local copy = {}
    for i, v in ipairs(source) do
        copy[i] = v
    end
    return copy
end

local function BuildWordLine()
    local line = {}
    local charCount = 0

    while true do
        local word = TypeCraftWords.pickRandomWord()
        local wordLength = #word + 1  -- +1 for space
        if charCount + wordLength > MAX_LINE_WIDTH then break end
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
    TypeCraftWords.updateCombinedWordList()
    resultsFrame:Hide()
    correctCount = 0
    characterCount = 0
    totalKeystrokes = 0
    errorCount = 0
    currentWords = {}
    nextWords= {}
    challengeActive = true
    timerRunning = false
    timerRemaining = timerDuration
    timerText:SetText("Time: " .. timerRemaining)
    currentLineText:SetText("")
    ShowMessage("Time begins when you enter the first character.", WHITE)
    StartNewLine()
    mainFrame:Show()
    inputField:SetText("")
    inputField:SetFocus()
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
    lastWpmText:SetText("WPM (Last): " .. wpm)
    if (wpm > bestSessionWPM) then
        bestSessionWPM = wpm
        bestSessionWpmText:SetText("WPM (Best): " .. bestSessionWPM)
    end
    currentLineText:SetText("")
    nextLineText:SetText("")
    ShowMessage("Time's up!", WHITE)

    -- Show the results
    resultsWpmText:SetText("Words per Minute: " .. wpm)
    resultsAccuracyText:SetText("Accuracy: " .. accuracy .. "%")
    resultsKpmText:SetText("Keystrokes per Minute: " .. kpm)
    resultsFrame:Show()
end

-- Function to update the timer display
local function UpdateTimerDisplay()
    timerText:SetText("Time: " .. timerRemaining)
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

    floatingFeedback:SetFontObject(currentLineText:GetFontObject())
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

    local centerX, centerY = currentLineText:GetCenter()
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

------------------------------------------------------------------------MAIN UI------------------------------------------------------------------------
-- Create the main frame
mainFrame = CreateFrame("Frame", "TypeCraftFrame", UIParent, "BackdropTemplate")
mainFrame:SetSize(700, 160)
mainFrame:SetPoint("CENTER")
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
mainFrame:Hide()
mainFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
mainFrame:SetBackdropColor(0, 0, 0, 0.6) -- Last value is alpha
-- Set the frame title
mainFrame.title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
mainFrame.title:SetPoint("CENTER", mainFrame, "TOP", 0, -20)
mainFrame.title:SetText("TypeCraft")

mainCloseButton = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
mainCloseButton:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -6, -6)
mainCloseButton:SetScale(0.8) -- optional, makes the button a bit smaller
-- Word display
currentLineText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
currentLineText:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -10, -50)
currentLineText:SetJustifyH("RIGHT")  -- Align text to the right
currentLineText:SetFont("Interface/AddOns/TypeCraft/fonts/RobotoMono.ttf", 12, "OUTLINE")

nextLineText =  mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
nextLineText:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -10, -70)
nextLineText:SetJustifyH("RIGHT")  -- Align text to the right
nextLineText:SetFont("Interface/AddOns/TypeCraft/fonts/RobotoMono.ttf", 12, "OUTLINE")
-- Typing input
inputField = CreateFrame("EditBox", nil, mainFrame, "InputBoxTemplate")
inputField:SetParent(mainFrame)
inputField:SetSize(200, 20)
inputField:SetPoint("BOTTOM", 0, 30)
inputField:SetAutoFocus(false)
inputField:EnableKeyboard(true)
inputField:SetScript("OnEnterPressed", function(self)
    HandleWordEntry(self:GetText())
    self:SetText("")
end)
inputField:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
end)
inputField:SetScript("OnTextChanged", function(self)
    if not timerRunning and trim(self:GetText()) ~= "" then
        StartTimer()
    end
end)
inputField:SetScript("OnKeyDown", function(self, key)
    if key == "SPACE" then
        HandleWordEntry(self:GetText())
        self:SetText("")
    end
end)
-- Result message
messageText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
messageText:SetPoint("BOTTOM", 0, 13)

-- Timer display
timerText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
timerText:SetPoint("BOTTOM", 0, 55)
timerText:SetText("Time: " .. timerDuration)

lastWpmText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
lastWpmText:SetPoint("BOTTOMRIGHT", -10, 10)
lastWpmText:SetText("WPM (Last): 0")

bestSessionWpmText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
bestSessionWpmText:SetPoint("BOTTOMRIGHT", -10, 25)
bestSessionWpmText:SetText("WPM (Best): 0")
-- Reset button
resetButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
resetButton:SetParent(mainFrame)
resetButton:SetSize(80, 22)
resetButton:SetPoint("LEFT", inputField, "RIGHT", 5, 0)
resetButton:SetText("Reset")
resetButton:SetScript("OnClick", function()
    if timerTicker then
        timerTicker:Cancel()
        timerTicker = nil
    end
    StartNewChallenge()
end)
-- settings button
settingsButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
settingsButton:SetParent(mainFrame)
settingsButton:SetSize(80, 22)
settingsButton:SetPoint("RIGHT", inputField, "LEFT", -5, 0)
settingsButton:SetText("Settings")
settingsButton:SetScript("OnClick", function()
    settingsFrame:Show()
end)
------------------------------------------------------------------------FEEDBACK UI------------------------------------------------------------------------
floatingFeedback = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
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

------------------------------------------------------------------------RESULTS UI------------------------------------------------------------------------
resultsFrame = CreateFrame("Frame", "TypeCraftResultsFrame", mainFrame, "BasicFrameTemplateWithInset")
resultsFrame:SetSize(300, 160)
resultsFrame:SetPoint("LEFT", mainFrame, "RIGHT", 5, 0)
resultsFrame:Hide()
resultsFrame.title = resultsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
resultsFrame.title:SetPoint("CENTER", resultsFrame.TitleBg, "CENTER", 0, 0)
resultsFrame.title:SetText("Challenge Complete!")
-- WPM display

resultsWpmText = resultsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
resultsWpmText:SetPoint("TOPLEFT", 15, -45)

-- Accuracy display
resultsAccuracyText = resultsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
resultsAccuracyText:SetPoint("TOPLEFT", 15, -65)

-- KPM display
resultsKpmText = resultsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
resultsKpmText:SetPoint("TOPLEFT", 15, -85)

shareButton = CreateFrame("Button", nil, resultsFrame, "UIPanelButtonTemplate")
shareButton:SetSize(60, 22)
shareButton:SetPoint("BOTTOM", 0, 10)
shareButton:SetText("Share")
shareButton:SetScript("OnClick", function()
        local chatMsg = string.format(
        "I just scored %d WPM with %d%% accuracy and %d KPM in TypeCraft!",
        lastWPM or 0, lastAccuracy or 0, lastKPM or 0
    )
    SendChatMessage(chatMsg, selectedChannel)
    end)

--share channel dropdown
shareChannelDropdown = CreateFrame("Frame", "MyAddon_ShareChannelDropdown", shareButton, "UIDropDownMenuTemplate")
shareChannelDropdown:SetPoint("BOTTOMRIGHT", resultsFrame, "BOTTOMRIGHT", 10, 0)
UIDropDownMenu_SetWidth(shareChannelDropdown, 60)
UIDropDownMenu_SetText(shareChannelDropdown, "Say") -- default
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
------------------------------------------------------------------------SETTINGS UI------------------------------------------------------------------------
settingsFrame = CreateFrame("Frame", "TypeCraftResultsFrame", mainFrame, "BasicFrameTemplateWithInset")
settingsFrame:SetSize(250, 160)
settingsFrame:SetPoint("RIGHT", mainFrame, "LEFT", 5, 0)
settingsFrame:Hide()
settingsFrame.title = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
settingsFrame.title:SetPoint("CENTER", settingsFrame.TitleBg, "CENTER", 0, 0)
settingsFrame.title:SetText("Settings")

timerDropdownLabel =  settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
timerDropdownLabel:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 20, -35)
timerDropdownLabel:SetText("Duration (Seconds): ")
-- Timer duration dropdown
timerDropdown = CreateFrame("Frame", "TypeCraftDropdown", settingsFrame, "UIDropDownMenuTemplate")
timerDropdown:SetPoint("LEFT", timerDropdownLabel, "RIGHT", 5, -2)
local function SetTimerDuration(value)
    timerDuration = tonumber(value) or 30
    timerRemaining = timerDuration
    timerText:SetText("Time: " .. timerRemaining)
end

local function InitializeTimerDropdown(self, level)
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
UIDropDownMenu_SetWidth(timerDropdown, 80)
UIDropDownMenu_SetText(timerDropdown, "Timer")
UIDropDownMenu_Initialize(timerDropdown, InitializeTimerDropdown)
UIDropDownMenu_SetSelectedValue(timerDropdown, timerDuration)

includeTitle = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
includeTitle:SetPoint("TOP", settingsFrame, "TOP", 0, -55)
includeTitle:SetText("Include Words")
local function CreateCheckbox(label, key, xOffset, yOffset)
    local cb = CreateFrame("CheckButton", nil, settingsFrame, "UICheckButtonTemplate")
    cb:SetPoint("CENTER", settingsFrame, "TOP", xOffset, yOffset)
    cb.text:SetText(label)
    cb:SetChecked(TypeCraftWords.enabledPools[key])
    cb:SetScript("OnClick", function(self)
        TypeCraftWords.enabledPools[key] = self:GetChecked()
        TypeCraftWords.updateCombinedWordList()
        StartNewChallenge()
    end)
    return cb
end

-- Create checkboxes for word pools
easyCheckbox = CreateCheckbox("Easy", "easy", -50,-90)
mediumCheckbox = CreateCheckbox("Medium", "medium", -50, -115)
hardCheckbox = CreateCheckbox("Hard", "hard", -50, -140)
fantasyCheckbox = CreateCheckbox("Fantasy", "fantasy", 30,-90)
goofyCheckbox = CreateCheckbox("Goofy", "goofy", 30, -115)
acronymCheckbox = CreateCheckbox("Acronyms", "acronyms", 30, -140)
------------------------------------------------------------------------MISC------------------------------------------------------------------------
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
