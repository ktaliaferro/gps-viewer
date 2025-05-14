local m_log, app_name = ...

local M = {}
M.m_log = m_log
M.app_name = app_name

--function cache
local math_floor = math.floor
local math_fmod = math.fmod
local string_gmatch = string.gmatch
local string_gsub = string.gsub
local string_len = string.len
local string_sub = string.sub
local string_char = string.char
local string_byte = string.byte

--local m_log = require("./LogViewer/lib_log")

function M.split(text)
    local cnt = 0
    local result = {}
    local text2 = string_gsub(text, ",,", ", ,")
    for val in string_gmatch(text2, "([^,]+),?") do
        cnt = cnt + 1
        result[cnt] = val
    end
    return result, cnt
end

function M.split_pipe(text)
    local cnt = 0
    local result = {}
    for val in string.gmatch(string.gsub(text, "||", "| |"), "([^|]+)|?") do
        cnt = cnt + 1
        result[cnt] = val
    end
    M.m_log.info("split_pipe: #col: %d (%s)", cnt, text)
    M.m_log.info("split_pipe: #col: %d [1-%s, 2-%s, ...]", cnt, result[1], result[2])
    return result, cnt
end

-- remove trailing and leading whitespace from string.
-- http://en.wikipedia.org/wiki/Trim_(programming)
function M.trim(s)
    if s == nil then
        return nil
    end
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

function M.trim_safe(s)
    if s == nil then
        return ""
    end
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

---------------------------------------------------------------------------------------------------

function M.periodicInit()
    local t = {}
    t.startTime = -1;
    t.durationMili = -1;
    return t
end

function M.periodicStart(t, durationMili)
    t.startTime = getTime();
    t.durationMili = durationMili;
end

function M.periodicHasPassed(t)
    -- not started yet
    if (t.durationMili <= 0) then
        return false;
    end

    local elapsed = getTime() - t.startTime;
    local elapsedMili = elapsed * 10;
    if (elapsedMili < t.durationMili) then
        return false;
    end
    return true;
end

function M.periodicGetElapsedTime(t)
    local elapsed = getTime() - t.startTime;
    local elapsedMili = elapsed * 10;
    return elapsedMili;
end

function M.periodicReset(t)
    t.startTime = getTime();
    m_log.info("periodicReset()");
    M.periodicGetElapsedTime(t)
end

-----------------------------------------------------------------

function M.timeProfilerInit()
    local prof = {
        periodicProfiler = M.periodicInit(),
        profTimes = {},
        last_t = 0
    }
    return prof
end

function M.timeProfilerStart()
    M.periodicStart(M.prof.periodicProfiler)
    M.prof.profTimes = {}
end

function M.timeProfilerAdd(name, t1)
    --return;
    local t2 = getTime()
    if t1 == nil then
        t1 = M.prof.last_t
    end
    M.prof.last_t = t2
    local timeSpan = t2 - t1
    local oldValues = M.prof.profTimes[name];
    if oldValues == nil then
        oldValues = { 0, 0, 0, 0 } -- count, total-time, last-time, max-time
    end

    local max = oldValues[4]
    if (timeSpan > oldValues[4]) then
        max = timeSpan
    end

    M.prof.profTimes[name] = { oldValues[1] + 1, oldValues[2] + timeSpan, timeSpan, max }; -- count, total-time, last-time, max-time
end

function M.timeProfilerShow(is_now)
    --return;
    if (is_now or M.periodicHasPassed(M.prof.periodicProfiler)) then
        local s = "profiler: \n"

        for name, valArr in pairs(M.prof.profTimes) do
            M.m_log.info("profiler4: " .. name .. ", " .. valArr[1])
            local s1 = string.format("xx  /%-15s - avg:%02.1f, max:%2d, last:%2d (count:%5s, tot:%03.3fsec)\n",
                name, valArr[2] / valArr[1], valArr[4], valArr[3], valArr[1], valArr[2]/1000)
            s = s .. s1
        end
        M.m_log.info(s);
        M.periodicReset(M.prof.periodicProfiler)
    end
end
-----------------------------------------------------------------

function M.larger(file,size_KB)
    -- determine if file is larger than size_KB
    io.seek(file, size_KB * 1024)
    s = io.read(file, 1)
    return string.len(s) > 0
end

function M.get_size(filename)
    if filename == nil then
        return 0
    end
    -- compute file size in KB using binary search
    local file = io.open("/LOGS/" .. filename, "r")
    local size_upper_limit = 1
    while M.larger(file,size_upper_limit) do
        size_upper_limit = size_upper_limit * 2
    end
    local size_lower_limit = 0
    local midpoint = nil
    while size_upper_limit - size_lower_limit > 2 do
        local midpoint = math.floor((size_upper_limit + size_lower_limit) * .5)
        if M.larger(file,midpoint) then
            size_lower_limit = midpoint
        else
            size_upper_limit = midpoint
        end
    end
    io.close(file)
    return size_upper_limit
end

M.prof = M.timeProfilerInit()
return M
