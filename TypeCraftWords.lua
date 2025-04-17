
TypeCraftWords = {}

TypeCraftWords.easy = { "the", "of", "to", "and", "a", "in", "is", "it", "you", "that" }
TypeCraftWords.medium = { "because", "between", "through", "during", "against", "without" }
TypeCraftWords.hard = { "consequence", "hypothesis", "phenomenon", "architecture", "consciousness" }
TypeCraftWords.fantasy = { "dragon", "wizard", "sorcery", "kingdom", "quest", "mythical" }
TypeCraftWords.funny = { "banana", "giggle", "snort", "blubber", "wobble", "pickle" }
TypeCraftWords.acronyms = { "LFG", "PST", "WTS", "BRD", "lol", "rofl", "rtfm" }

TypeCraftWords.enabledPools = {
    easy = true,
    medium = false,
    hard = false,
    fantasy = false,
    funny = false,
    acronyms = false
}

TypeCraftWords.combinedWordList = {}

function TypeCraftWords.updateCombinedWordList()
    TypeCraftWords.combinedWordList = {}
    for poolName, isEnabled in pairs(TypeCraftWords.enabledPools) do
        if isEnabled and TypeCraftWords[poolName] then
            for _, word in ipairs(TypeCraftWords[poolName]) do
                table.insert(TypeCraftWords.combinedWordList, word)
            end
        end
    end
end

function TypeCraftWords.pickRandomWord()
    local pool = TypeCraftWords.enabledPools
    local combinedWords = {}

    for difficulty, isEnabled in pairs(pool) do
        if isEnabled and TypeCraftWords[difficulty] then
            for _, word in ipairs(TypeCraftWords[difficulty]) do
                table.insert(combinedWords, word)
            end
        end
    end

    -- Define a fallback pool
    local fallbackPool = TypeCraftWords.fallback or { "none", "empty", "null", "void", "nil", "nada", "zilch", "zero"}

    -- Use fallback if combinedWords is empty
    if #combinedWords == 0 then
        combinedWords = fallbackPool
    end

    local index = math.random(1, #combinedWords)
    return combinedWords[index]
end

return TypeCraftWords