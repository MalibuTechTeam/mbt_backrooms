MBT = MBT or {}
Locales = Locales or {}

local loggedLang = nil -- dedup: RefreshLocale runs several times (SetTimeout + core/client)

local function setLocale(lang)
    lang = lang or 'en'
    if not Locales[lang] then
        -- MBTLog isn't loaded yet at the initial (load-time) call (this file loads
        -- before logger.lua), so fall back to a raw print there; at runtime it routes
        -- through the logger like everything else.
        local msg = ("Language '%s' not found in locales/ — falling back to 'en'"):format(tostring(lang))
        if MBTLog then MBTLog.Warn(msg)
        else print(("^3[%s] Warning: %s^0"):format(GetCurrentResourceName(), msg)) end
        MBT.Locale = Locales['en'] or (next(Locales) ~= nil and Locales[next(Locales)]) or {}
    else
        MBT.Locale = Locales[lang]
        -- Log once per runtime (skip the redundant refreshes); tag the side so the
        -- server + client lines read as two runtimes, not a duplicate.
        if MBTLog and lang ~= loggedLang then
            loggedLang = lang
            MBTLog.Debug('Language set to', lang, IsDuplicityVersion() and '(server)' or '(client)')
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
