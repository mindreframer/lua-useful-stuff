--[[

    Babel, a simple internationalisation tool for LÖVE 2D and standalone
    Lua applications (using lfs).
    Copyright (C) 2013  MARTIN Damien

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.


    CONTRIBUTORS
    ------------

        KOLL Thomas R.

            Github:  http://github.com/TomK32
            Website: http://ananasblau.com

        YONABA Roland

            Github: http://github.com/Yonaba
            Website: http://yonaba.github.com

]]

local babel = {}

babel.current_locale  = nil     -- Remember the current locale
babel.debug           = false   -- Display debug informations
babel.locales_folders = {}      -- List of all the folders look in

-- We test if we are in a LÖVE application or not
-- This make Babel usable for LÖVE application and
-- standalone applications.

local in_love = love
local file_exists = function() end
local load = function() end

if not in_love then
    -- We are not in LÖVE so we must use lfs instead
    lfs = require "lfs"
    file_exists = function( file )
        local test, err_msg = lfs.attributes( file )
        if test then return true else return false end
    end
    load = function( file )
        local chunk, msg = loadfile(file)
        if not chunk then
            msg = msg:gsub('^%w+%.lua:%d+:','')
            return error(('Error reading locale file: "%s":\n\t%s'):format(file,msg),2)
        end
        return chunk
    end
else
    -- We are in LÖVE
    file_exists = love.filesystem.exists
    load = love.filesystem.load
end

--- Merge two tables in one. t2 elements will be added to t1 and t2 elements will
-- override existing elements in t2.
-- @param t1 The table who will be used to be merged.
-- @param t2 The tabls who will be merged with.
-- @return The merge tables.
local mergeTables = function( t1, t2 )

    for k, v in pairs( t2 ) do
        t1[k] = v
    end

    return t1

end


--- 
-- @author Based on the work of Sam Lie (http://lua-users.org/wiki/FormattingNumbers)
local separateThousand = function( amount, separator )
    local formatted = amount
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1' .. separator .. '%2')
        if k == 0 then
            break
        end
    end
    return formatted
end


--- 
-- @author Based on the work of Sam Lie (http://lua-users.org/wiki/FormattingNumbers)
local round = function( val, decimal )
    if decimal then
        return math.floor( ( val * 10 ^ decimal ) + 0.5 ) / ( 10 ^ decimal )
    else
        return math.floor( val + 0.5 )
    end
end


--- 
-- @author Based on the work of Sam Lie (http://lua-users.org/wiki/FormattingNumbers)
local formatNum = function( amount, digits, separator, decimal )

    local famount = math.floor( math.abs( round( amount, digits ) ) )
    local remain = round( math.abs( amount ) - famount, digits )
    local formatted = separateThousand( famount, separator )

    if digits > 0 then
        remain = string.sub( tostring( remain ), 3 )
        formatted = formatted .. decimal .. remain .. string.rep( "0", digits - string.len( remain ) )
    end

    return formatted

end


--- Init babel with the wished values.
-- @param settings A table with all the needed settings for babel.
babel.init = function( settings )

    babel.current_locale  = settings.locale or "en-UK"
    babel.locales_folders = settings.locales_folders or { "translations" }
    babel.debug           = settings.debug or false

    babel.switchToLocale( babel.current_locale )

end

babel.reset = function()
    babel.dictionary      = {}      -- List of all the translations
    babel.formats         = {}      -- List of all the formats
end

babel.loadLocalePreset = function( locale )

    local babel_path = string.gsub( debug.getinfo(1).short_src, "babel.lua", "" )
    local locale_file = ("%sbabel-locales/%s.lua"):format( babel_path, locale )

    if file_exists( locale_file ) then
        local chunk = load( locale_file )
        local preset = chunk()
        babel.formats = preset.formats
    end

end

--- Add a locales folder to the existing list.
-- @param folder The folder to look in.
babel.addLocalesFolder = function( folder )

    table.insert( babel.locales_folders, folder )
    babel.switchToLocale() -- Reload current locale

end


--- Change current locale (can be used without parameters to reload current locale).
-- Note: This function don't stop if a file with the correct name can't be
-- found in one of the folders (file existence is not mandatory).
-- @param locale The locale to use.
babel.switchToLocale = function( locale )

    locale = locale or babel.current_locale

    if not locale or locale == '' then
      return
    end

    babel.reset()
    babel.loadLocalePreset( locale )

    for _, folder in pairs( babel.locales_folders ) do

        local locale_file = ("%s/%s.lua"):format(folder, locale)

        if file_exists( locale_file ) then

            if babel.debug then
                print( ("BABEL : Loading : %s"):format(locale_file))
            end

            local chunk = load( locale_file )
            local language = chunk()
            babel.current_locale = locale
            babel.formats = mergeTables( babel.formats, language.formats or {} )
            babel.dictionary = mergeTables( babel.dictionary, language.translations or {} )

        end

    end

end


--- Translate a string to the current locale (dynamic texts could be inserted)
-- @param string The text to translate.
-- @param parameters A list of all the dynamic elements in the string
babel.translate = function( str, parameters )

    local parameters = parameters or {}
    local translation

    if not babel.dictionary[str] then
        translation = str
    else
        translation = babel.dictionary[str]
    end

    -- Replace parameters
    for key, value in pairs( parameters ) do
        translation = translation:gsub( "%%" .. key .. "%%", value )
    end

    return translation

end


--- Get the current date time or the given date time table.
-- @param date_time The table of the date time to get (look at os.date for format)
-- @param short_format A boolean to force short format or long format (default
-- is short).
babel.dateTime = function( format, date_time )

    if date_time == nil then date_time = os.date( "*t" ) end

    local H = date_time.hour                    -- Hour on 24
    local i = date_time.min                     -- Minutes
    local s = date_time.sec                     -- Seconds
    local g = ( H <= 12 ) and H or ( H - 12 )   -- Hour on 12
    local a = ( H <= 12 ) and "AM" or "PM"      -- AM/PM
    local d = date_time.day                     -- Day
    local l = babel.formats.long_day_names[date_time.wday]
    local F = babel.formats.long_month_names[date_time.month]
    local m = date_time.month                   -- Index of the month in the year
    local Y = date_time.year                    -- Year (4 digits)
    local pattern = ""                          -- date time pattern

    if not babel.formats.date_time[format] then
        pattern = format
    else
        pattern = babel.formats.date_time[format]
    end

    pattern = pattern:gsub( "%%a", a )
    pattern = pattern:gsub( "%%H", ( H < 10 ) and "0" .. H or H )
    pattern = pattern:gsub( "%%i", ( i < 10 ) and "0" .. i or i )
    pattern = pattern:gsub( "%%s", ( s < 10 ) and "0" .. s or s )
    pattern = pattern:gsub( "%%g", ( g < 10 ) and "0" .. g or g )
    pattern = pattern:gsub( "%%d", ( d < 10 ) and "0" .. d or d )
    pattern = pattern:gsub( "%%m", ( m < 10 ) and "0" .. m or m )
    pattern = pattern:gsub( "%%Y", Y )
    pattern = pattern:gsub( "%%l", l )
    pattern = pattern:gsub( "%%F", F )

    return pattern

end


---
-- @param amount The amount to display.
babel.price = function( amount )

    local pattern   = ""
    local polarity  = ""
    local digits    = babel.formats.currency.fract_digits
    local separator = babel.formats.currency.thousand_separator
    local decimal   = babel.formats.currency.decimal_symbol
    local symbol    = babel.formats.currency.symbol

    if amount < 0 then
        polarity = babel.formats.currency.negative_symbol
        pattern = babel.formats.currency.negative_format
    else
        polarity = babel.formats.currency.positive_symbol
        pattern = babel.formats.currency.positive_format
    end

    pattern = pattern:gsub( "%%p", polarity )
    pattern = pattern:gsub( "%%q", formatNum( amount, digits, separator, decimal ) )
    pattern = pattern:gsub( "%%c", symbol )

    return pattern

end


babel.number = function( number )

    local polarity  = ""
    local digits    = babel.formats.number.fract_digits
    local separator = babel.formats.number.thousand_separator
    local decimal   = babel.formats.number.decimal_symbol

    if number < 0 then
        polarity = babel.formats.number.negative_symbol
    else
        polarity = babel.formats.number.positive_symbol
    end

    return polarity .. formatNum( number, digits, separator, decimal )

end


-- Function shortcut (gettext like)
_G._ = babel.translate


return babel
