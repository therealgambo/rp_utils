local i18n = {}

local store
local locale
local pluralizeFunction
local defaultLocale = 'en'
local fallbackLocale = defaultLocale

-- start interpolate
local interpolate = {}
local unpack = unpack or table.unpack -- lua 5.2 compat

local FORMAT_CHARS = { c=1, d=1, E=1, e=1, f=1, g=1, G=1, i=1, o=1, u=1, X=1, x=1, s=1, q=1, ['%']=1 }

-- matches a string of type %{age}
local function interpolateValue(string, variables)
  return string:gsub("(.?)%%{%s*(.-)%s*}",
    function (previous, key)
      if previous == "%" then
        return
      else
        return previous .. tostring(variables[key])
      end
    end)
end

-- matches a string of type %<age>.d
local function interpolateField(string, variables)
  return string:gsub("(.?)%%<%s*(.-)%s*>%.([cdEefgGiouXxsq])",
    function (previous, key, format)
      if previous == "%" then
        return
      else
        return previous .. string.format("%" .. format, variables[key] or "nil")
      end
    end)
end

local function escapePercentages(string)
  return string:gsub("(%%)(.?)", function(_, char)
    if FORMAT_CHARS[char] then
      return "%" .. char
    else
      return "%%" .. char
    end
  end)
end

local function unescapePercentages(string)
  return string:gsub("(%%%%)(.?)", function(_, char)
    if FORMAT_CHARS[char] then
      return "%" .. char
    else
      return "%%" .. char
    end
  end)
end

local function interpolate(pattern, variables)
  variables = variables or {}
  local result = pattern
  result = interpolateValue(result, variables)
  result = interpolateField(result, variables)
  result = escapePercentages(result)
  result = string.format(result, unpack(variables))
  result = unescapePercentages(result)
  return result
end

-- end interpolate


-- start plural

local plural = {}
local defaultFunction = nil
-- helper functions

local function assertPresentString(functionName, paramName, value)
  if type(value) ~= 'string' or #value == 0 then
    local msg = "Expected param %s of function %s to be a string, but got %s (a value of type %s) instead"
    error(msg:format(paramName, functionName, tostring(value), type(value)))
  end
end

local function assertNumber(functionName, paramName, value)
  if type(value) ~= 'number' then
    local msg = "Expected param %s of function %s to be a number, but got %s (a value of type %s) instead"
    error(msg:format(paramName, functionName, tostring(value), type(value)))
  end
end

-- transforms "foo bar baz" into {'foo','bar','baz'}
local function words(str)
  local result, length = {}, 0
  str:gsub("%S+", function(word)
    length = length + 1
    result[length] = word
  end)
  return result
end

local function isInteger(n)
  return n == math.floor(n)
end

local function between(value, min, max)
  return value >= min and value <= max
end

local function inside(v, list)
  for i=1, #list do
    if v == list[i] then return true end
  end
  return false
end


-- pluralization functions

local pluralization = {}

local f1 = function(n)
  return n == 1 and "one" or "other"
end
pluralization[f1] = words([[
  af asa bem bez bg bn brx ca cgg chr da de dv ee el
  en eo es et eu fi fo fur fy gl gsw gu ha haw he is
  it jmc kaj kcg kk kl ksb ku lb lg mas ml mn mr nah
  nb nd ne nl nn no nr ny nyn om or pa pap ps pt rm
  rof rwk saq seh sn so sq ss ssy st sv sw syr ta te
  teo tig tk tn ts ur ve vun wae xh xog zu
]])

local f2 = function(n)
  return (n == 0 or n == 1) and "one" or "other"
end
pluralization[f2] = words("ak am bh fil guw hi ln mg nso ti tl wa")

local f3 = function(n)
  if not isInteger(n) then return 'other' end
  return (n == 0 and "zero") or
         (n == 1 and "one") or
         (n == 2 and "two") or
         (between(n % 100, 3, 10) and "few") or
         (between(n % 100, 11, 99) and "many") or
         "other"
end
pluralization[f3] = {'ar'}

local f4 = function()
  return "other"
end
pluralization[f4] = words([[
  az bm bo dz fa hu id ig ii ja jv ka kde kea km kn
  ko lo ms my root sah ses sg th to tr vi wo yo zh
]])

local f5 = function(n)
  if not isInteger(n) then return 'other' end
  local n_10, n_100 = n % 10, n % 100
  return (n_10 == 1 and n_100 ~= 11 and 'one') or
         (between(n_10, 2, 4) and not between(n_100, 12, 14) and 'few') or
         ((n_10 == 0 or between(n_10, 5, 9) or between(n_100, 11, 14)) and 'many') or
         'other'
end
pluralization[f5] = words('be bs hr ru sh sr uk')

local f6 = function(n)
  if not isInteger(n) then return 'other' end
  local n_10, n_100 = n % 10, n % 100
  return (n_10 == 1 and not inside(n_100, {11,71,91}) and 'one') or
         (n_10 == 2 and not inside(n_100, {12,72,92}) and 'two') or
         (inside(n_10, {3,4,9}) and
          not between(n_100, 10, 19) and
          not between(n_100, 70, 79) and
          not between(n_100, 90, 99)
          and 'few') or
         (n ~= 0 and n % 1000000 == 0 and 'many') or
         'other'
end
pluralization[f6] = {'br'}

local f7 = function(n)
  return (n == 1 and 'one') or
         ((n == 2 or n == 3 or n == 4) and 'few') or
         'other'
end
pluralization[f7] = {'cz', 'sk'}

local f8 = function(n)
  return (n == 0 and 'zero') or
         (n == 1 and 'one') or
         (n == 2 and 'two') or
         (n == 3 and 'few') or
         (n == 6 and 'many') or
         'other'
end
pluralization[f8] = {'cy'}

local f9 = function(n)
  return (n >= 0 and n < 2 and 'one') or
         'other'
end
pluralization[f9] = {'ff', 'fr', 'kab'}

local f10 = function(n)
  return (n == 1 and 'one') or
         (n == 2 and 'two') or
         ((n == 3 or n == 4 or n == 5 or n == 6) and 'few') or
         ((n == 7 or n == 8 or n == 9 or n == 10) and 'many') or
         'other'
end
pluralization[f10] = {'ga'}

local f11 = function(n)
  return ((n == 1 or n == 11) and 'one') or
         ((n == 2 or n == 12) and 'two') or
         (isInteger(n) and (between(n, 3, 10) or between(n, 13, 19)) and 'few') or
         'other'
end
pluralization[f11] = {'gd'}

local f12 = function(n)
  local n_10 = n % 10
  return ((n_10 == 1 or n_10 == 2 or n % 20 == 0) and 'one') or
         'other'
end
pluralization[f12] = {'gv'}

local f13 = function(n)
  return (n == 1 and 'one') or
         (n == 2 and 'two') or
         'other'
end
pluralization[f13] = words('iu kw naq se sma smi smj smn sms')

local f14 = function(n)
  return (n == 0 and 'zero') or
         (n == 1 and 'one') or
         'other'
end
pluralization[f14] = {'ksh'}

local f15 = function(n)
  return (n == 0 and 'zero') or
         (n > 0 and n < 2 and 'one') or
         'other'
end
pluralization[f15] = {'lag'}

local f16 = function(n)
  if not isInteger(n) then return 'other' end
  if between(n % 100, 11, 19) then return 'other' end
  local n_10 = n % 10
  return (n_10 == 1 and 'one') or
         (between(n_10, 2, 9) and 'few') or
         'other'
end
pluralization[f16] = {'lt'}

local f17 = function(n)
  return (n == 0 and 'zero') or
         ((n % 10 == 1 and n % 100 ~= 11) and 'one') or
         'other'
end
pluralization[f17] = {'lv'}

local f18 = function(n)
  return((n % 10 == 1 and n ~= 11) and 'one') or
         'other'
end
pluralization[f18] = {'mk'}

local f19 = function(n)
  return (n == 1 and 'one') or
         ((n == 0 or
          (n ~= 1 and isInteger(n) and between(n % 100, 1, 19)))
          and 'few') or
         'other'
end
pluralization[f19] = {'mo', 'ro'}

local f20 = function(n)
  if n == 1 then return 'one' end
  if not isInteger(n) then return 'other' end
  local n_100 = n % 100
  return ((n == 0 or between(n_100, 2, 10)) and 'few') or
         (between(n_100, 11, 19) and 'many') or
         'other'
end
pluralization[f20] = {'mt'}

local f21 = function(n)
  if n == 1 then return 'one' end
  if not isInteger(n) then return 'other' end
  local n_10, n_100 = n % 10, n % 100

  return ((between(n_10, 2, 4) and not between(n_100, 12, 14)) and 'few') or
         ((n_10 == 0 or n_10 == 1 or between(n_10, 5, 9) or between(n_100, 12, 14)) and 'many') or
         'other'
end
pluralization[f21] = {'pl'}

local f22 = function(n)
  return (n == 0 or n == 1) and 'one' or
         'other'
end
pluralization[f22] = {'shi'}

local f23 = function(n)
  local n_100 = n % 100
  return (n_100 == 1 and 'one') or
         (n_100 == 2 and 'two') or
         ((n_100 == 3 or n_100 == 4) and 'few') or
         'other'
end
pluralization[f23] = {'sl'}

local f24 = function(n)
  return (isInteger(n) and (n == 0 or n == 1 or between(n, 11, 99)) and 'one')
         or 'other'
end
pluralization[f24] = {'tzm'}

local pluralizationFunctions = {}
for f,locales in pairs(pluralization) do
  for _,locale in ipairs(locales) do
    pluralizationFunctions[locale] = f
  end
end

-- public interface

function plural.get(locale, n)
  assertPresentString('i18n.plural.get', 'locale', locale)
  assertNumber('i18n.plural.get', 'n', n)

  local f = pluralizationFunctions[locale] or defaultFunction

  return f(math.abs(n))
end

function plural.setDefaultFunction(f)
  defaultFunction = f
end

function plural.reset()
  defaultFunction = pluralizationFunctions['en']
end

plural.reset()

-- end plural

-- start variants

local variants = {}

local function reverse(arr, length)
  local result = {}
  for i=1, length do result[i] = arr[length-i+1] end
  return result, length
end

local function concat(arr1, len1, arr2, len2)
  for i = 1, len2 do
    arr1[len1 + i] = arr2[i]
  end
  return arr1, len1 + len2
end

function variants.ancestry(locale)
  local result, length, accum = {},0,nil
  locale:gsub("[^%-]+", function(c)
    length = length + 1
    accum = accum and (accum .. '-' .. c) or c
    result[length] = accum
  end)
  return reverse(result, length)
end

function variants.isParent(parent, child)
  return not not child:match("^".. parent .. "%-")
end

function variants.root(locale)
  return locale:match("[^%-]+")
end

function variants.fallbacks(locale, fallbackLocale)
  if locale == fallbackLocale or
     variants.isParent(fallbackLocale, locale) then
     return variants.ancestry(locale)
  end
  if variants.isParent(locale, fallbackLocale) then
    return variants.ancestry(fallbackLocale)
  end

  local ancestry1, length1 = variants.ancestry(locale)
  local ancestry2, length2 = variants.ancestry(fallbackLocale)

  return concat(ancestry1, length1, ancestry2, length2)
end

-- end variants


i18n.plural, i18n.interpolate, i18n.variants = plural, interpolate, variants

-- private stuff

local function dotSplit(str)
  local fields, length = {},0
    str:gsub("[^%.]+", function(c)
    length = length + 1
    fields[length] = c
  end)
  return fields, length
end

local function isPluralTable(t)
  return type(t) == 'table' and type(t.other) == 'string'
end

local function isPresent(str)
  return type(str) == 'string' and #str > 0
end

local function assertPresent(functionName, paramName, value)
  if isPresent(value) then return end

  local msg = "i18n.%s requires a non-empty string on its %s. Got %s (a %s value)."
  error(msg:format(functionName, paramName, tostring(value), type(value)))
end

local function assertPresentOrPlural(functionName, paramName, value)
  if isPresent(value) or isPluralTable(value) then return end

  local msg = "i18n.%s requires a non-empty string or plural-form table on its %s. Got %s (a %s value)."
  error(msg:format(functionName, paramName, tostring(value), type(value)))
end

local function assertPresentOrTable(functionName, paramName, value)
  if isPresent(value) or type(value) == 'table' then return end

  local msg = "i18n.%s requires a non-empty string or table on its %s. Got %s (a %s value)."
  error(msg:format(functionName, paramName, tostring(value), type(value)))
end

local function assertFunctionOrNil(functionName, paramName, value)
  if value == nil or type(value) == 'function' then return end

  local msg = "i18n.%s requires a function (or nil) on param %s. Got %s (a %s value)."
  error(msg:format(functionName, paramName, tostring(value), type(value)))
end

local function defaultPluralizeFunction(count)
  return plural.get(variants.root(I18nGetLocale()), count)
end

local function pluralize(t, data)
  assertPresentOrPlural('interpolatePluralTable', 't', t)
  data = data or {}
  local count = data.count or 1
  local plural_form = pluralizeFunction(count)
  return t[plural_form]
end

local function treatNode(node, data)
  if type(node) == 'string' then
    return interpolate(node, data)
  elseif isPluralTable(node) then
    return interpolate(pluralize(node, data), data)
  end
  return node
end

local function recursiveLoad(currentContext, data)
  local composedKey
  for k,v in pairs(data) do
    composedKey = (currentContext and (currentContext .. '.') or "") .. tostring(k)
    assertPresent('load', composedKey, k)
    assertPresentOrTable('load', composedKey, v)
    if type(v) == 'string' then
      I18nSet(composedKey, v)
    else
      recursiveLoad(composedKey, v)
    end
  end
end

local function localizedTranslate(key, loc, data)
  local path, length = dotSplit(loc .. "." .. key)
  local node = store

  for i=1, length do
    node = node[path[i]]
    if not node then return nil end
  end

  return treatNode(node, data)
end

-- public interface

function I18nSet(key, value)
  assertPresent('set', 'key', key)
  assertPresentOrPlural('set', 'value', value)

  local path, length = dotSplit(key)
  local node = store

  for i=1, length-1 do
    key = path[i]
    node[key] = node[key] or {}
    node = node[key]
  end

  local lastKey = path[length]
  node[lastKey] = value
end

function I18nTranslate(key, data)
  assertPresent('translate', 'key', key)

  data = data or {}
  local usedLocale = data.locale or locale

  local fallbacks = variants.fallbacks(usedLocale, fallbackLocale)
  for i=1, #fallbacks do
    local value = localizedTranslate(key, fallbacks[i], data)
    if value then return value end
  end

  return data.default
end

function I18nSetLocale(newLocale, newPluralizeFunction)
  assertPresent('setLocale', 'newLocale', newLocale)
  assertFunctionOrNil('setLocale', 'newPluralizeFunction', newPluralizeFunction)
  locale = newLocale
  pluralizeFunction = newPluralizeFunction or defaultPluralizeFunction
end

function I18nSetFallbackLocale(newFallbackLocale)
  assertPresent('setFallbackLocale', 'newFallbackLocale', newFallbackLocale)
  fallbackLocale = newFallbackLocale
end

function I18nGetFallbackLocale()
  return fallbackLocale
end

function I18nGetLocale()
  return locale
end

function I18nReset()
  store = {}
  plural.reset()
  I18nSetLocale(defaultLocale)
  I18nSetFallbackLocale(defaultLocale)
end

function I18nLoad(data)
  recursiveLoad(nil, data)
end

function I18nLoadFileFromResource(resource,path)
  local code = load(LoadResourceFile(GetCurrentResourceName(), path))
  local data = code()
  I18nLoad(data)
end

function I18nLoadFile(path)
  I18nLoadFileFromResource(GetCurrentResourceName(), path)
end

setmetatable(i18n, {__call = function(_, ...) return I18nTranslate(...) end})
I18nReset()
