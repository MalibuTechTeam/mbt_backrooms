MBT = MBT or {}
Locales = Locales or {}

local function setLocale(lang)
    lang = lang or 'en'
    if not Locales[lang] then
        print(("^3[%s] Warning: Language '^5%s^3' not found in locales/. Falling back to 'en'.^0")
            :format(GetCurrentResourceName(), tostring(lang)))
        MBT.Locale = Locales['en'] or (next(Locales) ~= nil and Locales[next(Locales)]) or {}
    else
        MBT.Locale = Locales[lang]
        if MBT.Debug then
            print(("[%s] | Language set to ^5%s^0"):format(GetCurrentResourceName(), tostring(lang)))
        end
    end
end

-- 1. Partial init (before config.lua has necessarily set MBT.Language)
setLocale('en')

-- 2. Exposed refresh (used after config.lua loads)
function MBT.RefreshLocale(lang)
    setLocale(lang or MBT.Language)
end

-- 3. Deferred finalization once config.lua has run
SetTimeout(0, function()
    if MBT.RefreshLocale then
        MBT.RefreshLocale(MBT.Language)
    end
end)
