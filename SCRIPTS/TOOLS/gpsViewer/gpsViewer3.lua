local m_log,m_utils,m_tables,m_lib_file_parser,m_index_file,m_libgui, m_config  = ...

local M = {}

---- #########################################################################
---- #                                                                       #
---- # License GPLv3: https://www.gnu.org/licenses/gpl-3.0.html              #
---- #                                                                       #
---- # This program is free software; you can redistribute it and/or modify  #
---- # it under the terms of the GNU General Public License version 2 as     #
---- # published by the Free Software Foundation.                            #
---- #                                                                       #
---- # This program is distributed in the hope that it will be useful        #
---- # but WITHOUT ANY WARRANTY; without even the implied warranty of        #
---- # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
---- # GNU General Public License for more details.                          #
---- #                                                                       #
---- #########################################################################

-- Original Authors: Herman Kruisman and Offer Shmuely (https://github.com/offer-shmuely/edgetx-x10-scripts/tree/main/SCRIPTS/TOOLS)
-- Current Author: Kenny Taliaferro

local app_ver = "1.0"

function M.getVer()
    return app_ver
end

local maps = m_config.maps

--function cache
local math_floor = math.floor
local math_fmod = math.fmod
local string_gmatch = string.gmatch
local string_gsub = string.gsub
local string_len = string.len
local string_sub = string.sub
local string_char = string.char
local string_byte = string.byte

local heap = 2048
local hFile
local min_log_length_sec = m_config.min_log_length_sec
local max_log_size_mb = m_config.max_log_size_mb

-- read_and_index_file_list()
local log_file_list_raw = {}
local log_file_list_raw_idx = -1

local log_file_list_filtered = {}
local log_file_list_filtered2 = {}
local filter_model_name
local filter_model_name_idx = 1
local filter_date
local filter_date_idx = 1
local model_name_list = { "-- all --" }
local date_list = { "-- all --" }
local accuracy_list = { "1/1 (read every line)", "1/2 (every 2nd line)", "1/5 (every 5th line)", "1/10 (every 10th line)" }
local ddModel = nil
local ddLogFile = nil -- log-file dropDown object
local ddIndexType = nil

local INDEX_TYPE = {ALL=1, TODAY=2, LAST=3}
local index_type = INDEX_TYPE.ALL

local filename
local filename_idx = 1

local columns_by_header = {}
local columns_with_data = {}
local current_session = nil
local FIRST_VALID_COL = 2

-- state machine
local STATE = {
    SPLASH = 0,
    SELECT_INDEX_TYPE_INIT = 1,
    SELECT_INDEX_TYPE = 2,
    INDEX_FILES_INIT = 3,
    INDEX_FILES = 4,
    SELECT_FILE_INIT = 5,
    SELECT_FILE = 6,

    SELECT_SENSORS_INIT = 7,
    SELECT_SENSORS = 8,

    READ_FILE_DATA = 9,
    PARSE_DATA = 10,

    SHOW_GRAPH = 11
}

local state = STATE.SPLASH
--Graph data
local _values = {}
local _points = {}
local conversionSensorId = 0
local conversionSensorProgress = 0

--File reading data
local valPos = 0
local skipLines = 0
local lines = 0
local index = 0
local buffer = ""

local current_option = 1

local sensorSelection = {
    { y = 80, label = "Field 1", values = {}, idx = 1, colId = 0, min = 0 },
    { y = 105, label = "Field 2", values = {}, idx = 1, colId = 0, min = 0 },
    { y = 130, label = "Field 3", values = {}, idx = 1, colId = 0, min = 0 },
    { y = 155, label = "Field 4", values = {}, idx = 1, colId = 0, min = 0 }
}

local cursor = 0

local gui_drawn = false

local GRAPH_MODE = {
    CURSOR = 0,
    ZOOM = 1,
    SCROLL = 2,
    GRAPH_MINMAX = 3
}
local graphMode = GRAPH_MODE.CURSOR
local graphStart = 0
local graphSize = 0
local graphTimeBase = 0
local graphMinMaxEditorIndex = 0

--local img_bg1 = Bitmap.open("/SCRIPTS/TOOLS/gpsViewer/bg1.png")
--local img_bg2 = Bitmap.open("/SCRIPTS/TOOLS/gpsViewer/bg2.png")
--local img_bg3 = Bitmap.open("/SCRIPTS/TOOLS/gpsViewer/bg3.png")

map_names = {}
for i=1, #maps, 1 do
    map_names[i]=maps[i]["name"]
end

local selected_map = 1

local styles = {"Points", "Curve"}
local selected_style=1

local point_sizes = {1,2,3,4}
local selected_point_size = 4

-- Instantiate a new GUI object
local ctx1 = m_libgui.newGUI()
local ctx2 = m_libgui.newGUI()
local ctx3 = m_libgui.newGUI()
local select_file_gui_init = false

local selected_point = 0
local start_proportion = 0
local end_proportion = 1
local telemetry_index = 1
local show_ui = 0
local map_drawn = false
local map_draws = 0
local n_values = 0
local start_point = 0
local end_point = 0

---- #########################################################################

local function get_key(table,value)
    for k, v in pairs(table) do
        if v == value then
            return k
        end
    end
    return nil
end

--------------------------------------------------------------
local function log(fmt, ...)
    m_log.info(fmt, ...)
end
--------------------------------------------------------------

local function toDuration1(totalSeconds)
    local hours = math_floor(totalSeconds / 3600)
    totalSeconds = totalSeconds - (hours * 3600)
    local minutes = math_floor(totalSeconds / 60)
    local seconds = totalSeconds - (minutes * 60)

    return string.format("%02.0f",hours) .. ":" .. string.format("%02.0f",minutes) .. ":" .. string.format("%04.1f",seconds)
end

local function get_lat(s)
    local coordinates = {}
    for coordinate in string_gmatch(s,"[^%s]+")
    do
        table.insert(coordinates,coordinate)
    end
    return coordinates[1]
end

local function get_long(s)
    local coordinates = {}
    for coordinate in string_gmatch(s,"[^%s]+")
    do
        table.insert(coordinates,coordinate)
    end
    return coordinates[2]
end

local function collectData()
    if hFile == nil then
        buffer = ""
        hFile = io.open("/LOGS/" .. filename, "r")
        io.seek(hFile, current_session.startIndex)
        index = current_session.startIndex

        valPos = 0
        lines = 0
        log(string.format("current_session.total_lines: %d", current_session.total_lines))

        _points = {}
        _values = {}

        for varIndex = 1, 4, 1 do
            if sensorSelection[varIndex].idx >= FIRST_VALID_COL then
                _points[varIndex] = {}
                _values[varIndex] = {}
            end
        end
    end

    local read = io.read(hFile, heap)
    if read == "" then
        io.close(hFile)
        hFile = nil
        return true
    end

    buffer = buffer .. read
    local i = 0

    for line in string_gmatch(buffer, "([^\n]+)\n") do
        if math.fmod(lines, skipLines) == 0 then
            local vals = m_utils.split(line)

            for varIndex = 1, 4, 1 do
                if sensorSelection[varIndex].idx >= FIRST_VALID_COL then
                    local colId = sensorSelection[varIndex].colId
                    local gpsID = get_key(columns_by_header,"GPS")
                    if columns_by_header[colId] == "latitude" then
                        _values[varIndex][valPos] = get_lat(vals[gpsID])
                    elseif columns_by_header[colId] == "longitude" then
                        _values[varIndex][valPos] = get_long(vals[gpsID])
                    else
                        _values[varIndex][valPos] = vals[colId]
                    end
                end
            end

            valPos = valPos + 1
        end

        lines = lines + 1

        if lines > current_session.total_lines then
            io.close(hFile)
            hFile = nil
            return true
        end

        i = i + string.len(line) + 1 --dont forget the newline ;)
    end

    buffer = string.sub(buffer, i + 1) --dont forget the newline ;
    index = index + heap
    io.seek(hFile, index)
    return false
end

-- ---------------------------------------------------------------------------------------------------------

local function compare_dates_inc(a, b)
    return a < b
end
local function compare_dates_dec(a, b)
    return a < b
end

local function compare_names(a, b)
    return a < b
end

local function drawProgress(x, y, current, total)
    local pct = current / total
    lcd.drawFilledRectangle(x + 1, y + 1, (470 - x - 2) * pct, 14, TEXT_INVERTED_BGCOLOR)
    lcd.drawRectangle(x, y, 470 - x, 16, TEXT_COLOR)
end

local function get_log_files_list()

    -- find latest log and latest day
    local last_day = "1970-01-01"
    local on_disk_date_list = {}
    local last_log_day_time = "1970-01-01-00-00-00"
    for fn in dir("/LOGS") do
        local modelName, year, month, day, hour, min, sec, m, d, y = string.match(fn, "^(.*)-(%d+)-(%d+)-(%d+)-(%d%d)(%d%d)(%d%d).csv$")
        if year~=nil and month~=nil and day~=nil then
            local log_day = string.format("%s-%s-%s", year, month, day)
            local log_day_time = string.format("%s-%s-%s-%s-%s-%s", year, month, day, hour, min, sec)
            if log_day > last_day then
                last_day = log_day
            end
            if log_day_time > last_log_day_time then
                last_log_day_time = log_day_time
            end

            m_tables.list_ordered_insert(on_disk_date_list, log_day, compare_dates_inc, 2)
        end
    end
    log("latest day: %s", last_day)
    log("last_log: %s", last_log_day_time)


    local log_files_list_all = {}
    local log_files_list_today = {}
    local log_files_list_latest = {}
    for fn in dir("/LOGS") do

        local modelName, year, month, day, hour, min, sec, m, d, y = string.match(fn, "^(.*)-(%d+)-(%d+)-(%d+)-(%d%d)(%d%d)(%d%d).csv$")
        local log_day = string.format("%s-%s-%s", year, month, day)
        local log_day_time = string.format("%s-%s-%s-%s-%s-%s", year, month, day, hour, min, sec)

        log_files_list_all[#log_files_list_all+1] = fn

        if log_day==last_day then
            log_files_list_today[#log_files_list_today+1] = fn
        end

        if log_day_time==last_log_day_time then
            log_files_list_latest[#log_files_list_latest+1] = fn
        end
    end
    --m_tables.table_print("log_files_list_all", log_files_list_all)
    m_tables.table_print("log_files_list_today", log_files_list_today)
    m_tables.table_print("log_files_list_latest", log_files_list_latest)

    if index_type == INDEX_TYPE.ALL then
        log("using files for index of type ALL")
        return log_files_list_all
    elseif index_type == INDEX_TYPE.TODAY then
        log("using files for index of type TODAY")
        return log_files_list_today
    elseif index_type == INDEX_TYPE.LAST then
        log("using files for index of type LAST")
        return log_files_list_latest
    end

    log("internal error, unknown index_type: %s", index_type)
    return nil
end

-- read log file list
local function read_and_index_file_list()

    if (#log_file_list_raw == 0) then
        log("read_and_index_file_list: init")
        m_index_file.indexInit()

        log_file_list_raw = get_log_files_list()

        log_file_list_raw_idx = 1
        m_index_file.indexRead(log_file_list_raw)
    end
 
    while true do
        if gui_drawn == false then
            -- Draw the GUI in a separate execution of the run function.
            -- Otherwise, the GUI will be blank while the first file is indexing.
            local filename = log_file_list_raw[log_file_list_raw_idx]
            if filename ~= nil then
                -- draw top-bar
                lcd.clear()
                lcd.drawFilledRectangle(0, 0, LCD_W, 20, TITLE_BGCOLOR)
                --lcd.drawBitmap(img_bg2, 0, 0)
                --lcd.drawText(440, 1, "v" .. app_ver, WHITE + SMLSIZE)

                -- draw state
                lcd.drawText(5, 30, "Analyzing & indexing files", TEXT_COLOR + BOLD)
                lcd.drawText(5, 60, string.format("indexing files: (%d/%d)", log_file_list_raw_idx, #log_file_list_raw), TEXT_COLOR + SMLSIZE)
                lcd.drawText(5, 90, string.format("* %s", filename), TEXT_COLOR + SMLSIZE)
                lcd.drawText(30, 1, "/LOGS/" .. filename, WHITE + SMLSIZE)

                drawProgress(160, 60, log_file_list_raw_idx, #log_file_list_raw)

                log("log file: (%d/%d) %s (detecting...)", log_file_list_raw_idx, #log_file_list_raw, filename)
            end
            gui_drawn = true
            return false
        else
            -- index the log file
            local filename = log_file_list_raw[log_file_list_raw_idx]
            if filename ~= nil then
                local modelName, year, month, day, hour, min, sec, m, d, y = string.match(filename, "^(.*)-(%d+)-(%d+)-(%d+)-(%d%d)(%d%d)(%d%d).csv$")
                if modelName ~= nil then
                    local model_day = string.format("%s-%s-%s", year, month, day)

                    -- read file
                    local is_new, start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str, all_col_str = m_index_file.getFileDataInfo(filename)

                    log("read_and_index_file_list: total_seconds: %s", total_seconds)
                    m_tables.list_ordered_insert(model_name_list, modelName, compare_names, 2)
                    m_tables.list_ordered_insert(date_list, model_day, compare_dates_inc, 2)
                end
            end
            log_file_list_raw_idx = log_file_list_raw_idx + 1
            gui_drawn = false
            if log_file_list_raw_idx > #log_file_list_raw then
                return true
            end
        end
    end
end

local function onLogFileChange(obj)

    local i = obj.selected
    filename = log_file_list_filtered[i]
    log("Selected file index: %d", i)
    log("Selected file: %s", log_file_list_filtered[i])
    filename_idx = i
end

local function onAccuracyChange(obj)
    local i = obj.selected
    local accuracy = i
    log("Selected accuracy: %s (%d)", accuracy_list[i], i)

    if accuracy == 4 then
        skipLines = 10
        heap = 2048 * 16
    elseif accuracy == 3 then
        skipLines = 5
        heap = 2048 * 16
    elseif accuracy == 2 then
        skipLines = 2
        heap = 2048 * 8
    else
        skipLines = 1
        heap = 2048 * 4
    end
end

local function filter_log_file_list(filter_model_name, filter_date, need_update)
    log("need to filter by: [%s] [%s] [%s]", filter_model_name, filter_date, need_update)

    m_tables.table_clear(log_file_list_filtered)

    local log_files_index_info = m_index_file.getFileListDec()
    for i = 1, #log_files_index_info do
        local log_file_info = log_files_index_info[i]

        local modelName, year, month, day, hour, min, sec, m, d, y = string.match(log_file_info.file_name, "^(.*)-(%d+)-(%d+)-(%d+)-(%d%d)(%d%d)(%d%d).csv$")

        local is_model_name_ok
        if filter_model_name == nil or string.sub(filter_model_name, 1, 2) == "--" then
            is_model_name_ok = true
        else
            is_model_name_ok = (modelName == filter_model_name)
        end

        local is_date_ok
        if filter_date == nil or string.sub(filter_date, 1, 2) == "--" then
            is_date_ok = true
        else
            local model_day = string.format("%s-%s-%s", year, month, day)
            is_date_ok = (model_day == filter_date)
        end

        local is_duration_ok = true
        if log_file_info.total_seconds < min_log_length_sec then
            is_duration_ok = false
        end

        local is_have_data_ok = true
        if log_file_info.col_with_data_str == nil or log_file_info.col_with_data_str == "" then
            is_have_data_ok = false
        end

        if is_model_name_ok and is_date_ok and is_duration_ok and is_have_data_ok then
            --log("filter_log_file_list: [%s] - OK (%s,%s)", log_file_info.file_name, filter_model_name, filter_date)
            table.insert(log_file_list_filtered, log_file_info.file_name)
        else
        end

    end

    m_tables.table_clear(log_file_list_filtered2)

    if #log_file_list_filtered == 0 then
        table.insert(log_file_list_filtered, "not found")
        table.insert(log_file_list_filtered2, "not found")
    else
        -- prepare list with friendly names
        for i=1, #log_file_list_filtered do
            -- get duration
            local is_new, start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str, all_col_str = m_index_file.getFileDataInfo(log_file_list_filtered[i])
            log_file_list_filtered2[#log_file_list_filtered2 +1] = string.format("%s (%.0fmin)", log_file_list_filtered[i], total_seconds/60)
        end
    end

    -- update the log combo to first
    if need_update == true then
        onLogFileChange(ddLogFile)
        ddLogFile.selected = 1
    end
end

local splash_start_time = 0
local function state_SPLASH(event, touchState)

    if splash_start_time == 0 then
        splash_start_time = getTime()
    end
    local elapsed = getTime() - splash_start_time;
    local elapsedMili = elapsed * 10;
    -- was 1500, but most the time will go anyway from the load of the scripts
    if (elapsedMili >= 0) then
        state = STATE.SELECT_INDEX_TYPE_INIT
    end

    return 0
end

local function onButtonIndexTypeAll()
    log("onButtonIndexTypeAll")
    index_type = INDEX_TYPE.ALL
    state = STATE.INDEX_FILES_INIT
end
local function onButtonIndexTypeToday()
    log("onButtonIndexTypeToday")
    index_type = INDEX_TYPE.TODAY
    state = STATE.INDEX_FILES_INIT
end
local function onButtonIndexTypeLastFlight()
    log("onButtonIndexTypeLastFlight")
    index_type = INDEX_TYPE.LAST
    state = STATE.INDEX_FILES_INIT
end

local function state_SELECT_INDEX_TYPE_init(event, touchState)
    log("state_SELECT_INDEX_TYPE_init()")
    log("creating new window gui")

    ctx3.label(10, 30, 70, 24, "Indexing selection:", m_libgui.FONT_SIZES.FONT_8)

    ctx3.button(90,  60, 320, 55, "Only last flight (fast)", onButtonIndexTypeLastFlight)
    ctx3.button(90, 130, 320, 55, "Last flights day", onButtonIndexTypeToday)
    ctx3.button(90, 200, 320, 55, "All flights (slow)", onButtonIndexTypeAll)

    -- default is ALL
    index_type = INDEX_TYPE.LAST

    log_file_list_raw = {}

    state = STATE.SELECT_INDEX_TYPE
    return 0
end


local function state_SELECT_INDEX_TYPE_refresh(event, touchState)
    if event == EVT_VIRTUAL_NEXT_PAGE then
        state = STATE.INDEX_FILES_INIT
        return 0
    end

    lcd.drawText(30, 1, "Indexing type for new logs", WHITE + SMLSIZE)

    ctx3.run(event, touchState)
    return 0
end

local function state_INDEX_FILES_INIT(event, touchState)
    log("state_INDEX_FILES_INIT()")
    state = STATE.INDEX_FILES
    return 0
end

local function state_INDEX_FILES(event, touchState)
    if event == EVT_VIRTUAL_EXIT or event == EVT_VIRTUAL_PREV_PAGE then
        state = STATE.SELECT_INDEX_TYPE
        return 0
    end

    -- start init
    local is_done = read_and_index_file_list()

    collectgarbage("collect")

    if (is_done == true) then
        state = STATE.SELECT_FILE_INIT
    end

    return 0
end

local function state_SELECT_FILE_init(event, touchState)
    m_tables.table_clear(log_file_list_filtered)
    filter_log_file_list(nil, nil, false)

    if select_file_gui_init == false then
        select_file_gui_init = true
        -- creating new window gui
        log("creating new window gui")

        ctx1.label(10, 25, 120, 24, "Make selection and press \"Page>\" button.", BOLD)

        ctx1.label(10, 55, 60, 24, "Model")
        ddModel = ctx1.dropDown(90, 55, 380, 24, model_name_list, 1,
            function(obj)
                local i = obj.selected
                filter_model_name = model_name_list[i]
                filter_model_name_idx = i
                log("Selected model-name: " .. filter_model_name)
                filter_log_file_list(filter_model_name, filter_date, true)
            end
        )

        ctx1.label(10, 80, 60, 24, "Date")
        ctx1.dropDown(90, 80, 380, 24, date_list, 1,
            function(obj)
                local i = obj.selected
                filter_date = date_list[i]
                filter_date_idx = i
                log("Selected filter_date: " .. filter_date)
                filter_log_file_list(filter_model_name, filter_date, true)
            end
        )

        log("setting file combo...")
        ctx1.label(10, 105, 60, 24, "Log file")
        ddLogFile = ctx1.dropDown(90, 105, 380, 24, log_file_list_filtered2, filename_idx,
            onLogFileChange
        )
        onLogFileChange(ddLogFile)

        ctx1.label(10, 130, 60, 24, "Accuracy")
        dd4 = ctx1.dropDown(90, 130, 380, 24, accuracy_list, 1, onAccuracyChange)
        onAccuracyChange(dd4)

    end

    --filter_model_name_i
    ddModel.selected = filter_model_name_idx
    --filter_date_i
    filter_log_file_list(filter_model_name, filter_date, true)

    ddLogFile.selected = filename_idx


    state = STATE.SELECT_FILE
    return 0
end

local function state_SELECT_FILE_refresh(event, touchState)
    -- ## file selected
    if event == EVT_VIRTUAL_NEXT_PAGE or index_type == INDEX_TYPE.LAST then
        log("state_SELECT_FILE_refresh --> EVT_VIRTUAL_NEXT_PAGE: filename: %s", filename)
        if filename == "not found" then
            m_log.warn("state_SELECT_FILE_refresh: trying to next-page, but no logfile available, ignoring.")
            return 0
        end

        --Reset file load data
        log("Reset file load data")
        buffer = ""
        lines = 0
        heap = 2048 * 12

        local is_new, start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str, all_col_str = m_index_file.getFileDataInfo(filename)

        current_session = {
            startTime = start_time,
            endTime = end_time,
            total_seconds = total_seconds,
            total_lines = total_lines,
            startIndex = start_index,
            col_with_data_str = col_with_data_str,
            all_col_str = all_col_str
        }

        -- update columns
        local columns_temp, cnt = m_utils.split_pipe(col_with_data_str)
        log("state_SELECT_FILE_refresh: #col: %d", cnt)
        m_tables.table_clear(columns_with_data)
        columns_with_data[1] = "---"
        for i = 1, #columns_temp, 1 do
            local col = columns_temp[i]
            if m_utils.trim_safe(col) ~= "" then
                columns_with_data[#columns_with_data + 1] = col
                log("state_SELECT_FILE_refresh: col: [%s]", col)
            end
        end

        local columns_temp, cnt = m_utils.split_pipe(all_col_str)
        log("state_SELECT_FILE_refresh: #col: %d", cnt)
        m_tables.table_clear(columns_by_header)
        for i = 1, #columns_temp, 1 do
            local col = columns_temp[i]
            columns_by_header[#columns_by_header + 1] = col
        end

        state = STATE.SELECT_SENSORS_INIT
        return 0
    end

    ctx1.run(event, touchState)

    return 0
end

local function colWithData2ColByHeader(colWithDataId)
    local sensorName = columns_with_data[colWithDataId]
    local colByHeaderId = 0

    log("colWithData2ColByHeader: byData     - idx: %d, name: %s", colWithDataId, sensorName)

    log("#columns_by_header: %d", #columns_by_header)
    for i = 1, #columns_by_header do
        if columns_by_header[i] == sensorName then
            colByHeaderId = i
            log("colWithData2ColByHeader: byHeader - colId: %d, name: %s", colByHeaderId, columns_by_header[colByHeaderId])
            return colByHeaderId
        end
    end

    return -1
end

local function select_sensors_preset_first_4()
    if sensorSelection[1].idx ~= 1 or sensorSelection[2].idx ~= 1 or sensorSelection[3].idx ~= 1 or sensorSelection[4].idx ~= 1 then
        return -- keep the last selection
    end

    for i = 1, 4, 1 do
        if i < #columns_with_data then
            sensorSelection[i].idx = i + 1
            log("%d. sensors is: %s", i, columns_with_data[i])
            sensorSelection[i].values[i - 1] = columns_with_data[i]
        else
            sensorSelection[i].idx = 1
            sensorSelection[i].values[0] = "---"
        end
        log("state_SELECT_SENSORS_INIT %d. <= %d (%d)", i , sensorSelection[i].idx, #columns_with_data)
    end
end

local function state_SELECT_SENSORS_INIT(event, touchState)
    log("state_SELECT_SENSORS_INIT")
    m_tables.table_print("sensors-init columns_with_data", columns_with_data)

    -- select default sensor
    select_sensors_preset_first_4()

    m_tables.table_print("sensors-init columns_with_data", columns_with_data)

    current_option = 1

    -- creating new window gui
    log("creating new window gui")
    ctx2 = nil
    ctx2 = m_libgui.newGUI()

    ctx2.label(10, 25, 120, 24, "Make selection and press \"Page>\" button.", BOLD)

    log("setting field1...")
    ctx2.label(10, 55, 60+10, 24, "Field 1")
    ctx2.dropDown(90+10, 55, 380-10, 24, columns_with_data, sensorSelection[1].idx,
        function(obj)
            local i = obj.selected
            local var1 = columns_with_data[i]
            log("Selected var1: " .. var1)
            sensorSelection[1].idx = i
            sensorSelection[1].colId = colWithData2ColByHeader(i)
        end
    )
    ctx2.label(10, 80, 60+10, 24, "Field 2")
    ctx2.dropDown(90+10, 80, 380-10, 24, columns_with_data, sensorSelection[2].idx,
        function(obj)
            local i = obj.selected
            local var2 = columns_with_data[i]
            log("Selected var2: " .. var2)
            sensorSelection[2].idx = i
            sensorSelection[2].colId = colWithData2ColByHeader(i)
        end
    )
    ctx2.label(10, 105, 60+10, 24, "Map")
    ctx2.dropDown(90+10, 105, 380-10, 24, map_names, 1,
        function(obj)
            local i = obj.selected
            local var3 = map_names[i]
            log("Selected map: " .. var3)
            selected_map = i
        end
    )
    
    ctx2.label(10, 130, 60+10, 24, "Style")
    ctx2.dropDown(90+10, 130, 380-10, 24, styles, 1,
        function(obj)
            local i = obj.selected
            local var4 = styles[i]
            log("Selected style: " .. var4)
            selected_style = i
        end
    )

    sensorSelection[1].colId = colWithData2ColByHeader(sensorSelection[1].idx)
    sensorSelection[2].colId = colWithData2ColByHeader(sensorSelection[2].idx)
    sensorSelection[3].colId = get_key(columns_by_header, "latitude")
    sensorSelection[3].idx = FIRST_VALID_COL
    sensorSelection[4].colId = get_key(columns_by_header, "longitude")
    sensorSelection[4].idx = FIRST_VALID_COL

    state = STATE.SELECT_SENSORS
    return 0
end

local function state_SELECT_SENSORS_refresh(event, touchState)
    if event == EVT_VIRTUAL_EXIT or event == EVT_VIRTUAL_PREV_PAGE then
        state = STATE.SELECT_FILE_INIT
        return 0

    elseif event == EVT_VIRTUAL_NEXT_PAGE then
        state = STATE.READ_FILE_DATA
        return 0
    end

    ctx2.run(event, touchState)

    return 0
end

local function display_read_data_progress(conversionSensorId, conversionSensorProgress)
    lcd.drawText(5, 25, "Reading data from file...", TEXT_COLOR)

    lcd.drawText(5, 60, "Reading line: " .. lines, TEXT_COLOR)
    drawProgress(140, 60, lines, current_session.total_lines)

    local done_var_1 = 0
    local done_var_2 = 0
    local done_var_3 = 0
    local done_var_4 = 0
    if conversionSensorId == 1 then
        done_var_1 = conversionSensorProgress
    end
    if conversionSensorId == 2 then
        done_var_1 = valPos
        done_var_2 = conversionSensorProgress
    end
    if conversionSensorId == 3 then
        done_var_1 = valPos
        done_var_2 = valPos
        done_var_3 = conversionSensorProgress
    end
    if conversionSensorId == 4 then
        done_var_1 = valPos
        done_var_2 = valPos
        done_var_3 = valPos
        done_var_4 = conversionSensorProgress
    end
    local y = 85
    local dy = 25
    lcd.drawText(5, y, "Parsing Field 1: ", TEXT_COLOR)
    drawProgress(140, y, done_var_1, valPos)
    y = y + dy
    lcd.drawText(5, y, "Parsing Field 2: ", TEXT_COLOR)
    drawProgress(140, y, done_var_2, valPos)
    y = y + dy
    lcd.drawText(5, y, "Parsing Latitude: ", TEXT_COLOR)
    drawProgress(140, y, done_var_3, valPos)
    y = y + dy
    lcd.drawText(5, y, "Parsing Longitude: ", TEXT_COLOR)
    drawProgress(140, y, done_var_4, valPos)

end

local function state_READ_FILE_DATA_refresh(event, touchState)
    if event == EVT_VIRTUAL_EXIT or event == EVT_VIRTUAL_PREV_PAGE then
        state = STATE.SELECT_SENSORS_INIT
        return 0
    end

    display_read_data_progress(0, 0)

    local is_done = collectData()
    if is_done then
        conversionSensorId = 0
        state = STATE.PARSE_DATA
    end

    return 0
end

local function state_PARSE_DATA_refresh(event, touchState)
    if event == EVT_VIRTUAL_EXIT then
        return 2

    elseif event == EVT_VIRTUAL_EXIT or event == EVT_VIRTUAL_PREV_PAGE then
        state = STATE.SELECT_SENSORS_INIT
        return 0
    end

    display_read_data_progress(conversionSensorId, conversionSensorProgress)

    local cnt = 0

    -- prepare
    if conversionSensorId == 0 then
        conversionSensorId = 1
        conversionSensorProgress = 0
        local fileTime = m_lib_file_parser.getTotalSeconds(current_session.endTime) - m_lib_file_parser.getTotalSeconds(current_session.startTime)
        graphTimeBase = valPos / fileTime

        for varIndex = 1, 4, 1 do
            if sensorSelection[varIndex].idx >= FIRST_VALID_COL then
                local columnName = columns_with_data[sensorSelection[varIndex].idx]
                -- remove column units if exist
                local i = string.find(columnName, "%(")
                local unit = ""

                if i ~= nil then
                    unit = string.sub(columnName, i + 1, #columnName - 1)
                    columnName = string.sub(columnName, 0, i - 1)
                end
                _points[varIndex] = {
                    min = 9999,
                    max = -9999,
                    minpos = 0,
                    maxpos = 0,
                    points = {},
                    name = columnName,
                    unit = unit
                }
            end
        end
        return 0
    end

    if sensorSelection[conversionSensorId].idx >= FIRST_VALID_COL then
        for i = conversionSensorProgress, valPos - 1, 1 do
            local val = tonumber(_values[conversionSensorId][i])
            _values[conversionSensorId][i] = val
            conversionSensorProgress = conversionSensorProgress + 1
            cnt = cnt + 1

            if val ~= nil then
                if val > _points[conversionSensorId].max then
                    _points[conversionSensorId].max = val
                    _points[conversionSensorId].maxpos = i
                elseif val < _points[conversionSensorId].min then
                    _points[conversionSensorId].min = val
                    _points[conversionSensorId].minpos = i
                end
            end

            if cnt > 100 then
                return 0
            end
        end
    end

    if conversionSensorId == 4 then
        graphStart = 0
        graphSize = valPos * 0.75 -- default zoom
        cursor = 50
        graphMinMaxEditorIndex = 0
        graphMode = GRAPH_MODE.CURSOR
        state = STATE.SHOW_GRAPH
    else
        conversionSensorProgress = 0
        conversionSensorId = conversionSensorId + 1
    end

    return 0
end

local function drawMain()
    lcd.clear()

    -- draw background
    if state == STATE.SPLASH then
        --lcd.drawBitmap(img_bg1, 0, 0)
    elseif state == STATE.SHOW_GRAPH then
        --lcd.drawBitmap(img_bg3, 0, 0)
    else
        -- draw top-bar
        lcd.drawFilledRectangle(0, 0, LCD_W, 20, TITLE_BGCOLOR)
        --lcd.drawBitmap(img_bg2, 0, 0)
    end
    --lcd.drawText(440, 1, "v" .. app_ver, WHITE + SMLSIZE)

    if filename == "not found" then
        lcd.drawText(30, 1, string.format("Invalid log file (over %d MB, under %d sec, or missing GPS data)", max_log_size_mb, min_log_length_sec), WHITE + SMLSIZE)
    elseif filename ~= nil then
        lcd.drawText(30, 1, "/LOGS/" .. filename, WHITE + SMLSIZE)
    end
end

local function blank_map_boundary(points_long_min, points_long_max, points_lat_min, points_lat_max)
    -- compute longitude and latitude boundary values of the blank map so that
    -- the flight fills the screen and isn't distorted

    -- compute width and center of data points
    local height = points_lat_max - points_lat_min
    local width = points_long_max - points_long_min
    local center_x = points_long_min + width / 2
    local center_y = points_lat_min + height / 2

    -- add padding on each side
    local padding = 0.1
    width = width * (1 + padding)
    height = height * (1 + padding)

    -- account for the fact that longitude lines get closer as you move away from the equator
    local longitude_scaling_factor = math.sin((90-points_lat_max)*math.pi/180)
    local desired_height_width_ratio = LCD_H * longitude_scaling_factor / LCD_W

    if height / width < desired_height_width_ratio then
        height = width * desired_height_width_ratio
    else
        width = height / desired_height_width_ratio
    end
    local map_long_min = center_x - width / 2
    local map_long_max = center_x + width / 2
    local map_lat_min = center_y - height / 2
    local map_lat_max = center_y + height / 2

    return map_long_min, map_long_max, map_lat_min, map_lat_max
end

local function state_SHOW_GRAPH_refresh(event, touchState)
    if event == EVT_VIRTUAL_EXIT or event == EVT_VIRTUAL_PREV_PAGE then
        state = STATE.SELECT_SENSORS_INIT
        return 0
    end
    
    local c = nil
    if n_values == 0 then
        n_values = #_values[3]
    end
    
    local lat_index = 3
    local long_index = 4
    
    local long_min, long_max, lat_min, lat_max
    if maps[selected_map]["name"] == "Blank" then
        long_min, long_max, lat_min, lat_max = blank_map_boundary(
            _points[long_index]["min"],
            _points[long_index]["max"],
            _points[lat_index]["min"],
            _points[lat_index]["max"]
        )
    else
        long_min = maps[selected_map]["long_min"]
        long_max = maps[selected_map]["long_max"]
        lat_min = maps[selected_map]["lat_min"]
        lat_max = maps[selected_map]["lat_max"]
    end
    local dx = long_max - long_min
    local dy = lat_max - lat_min
    
    local selected_point_old = selected_point
    local show_ui_old = show_ui
    local telemetry_index_old = telemetry_index
    local start_point_old = start_point
    local end_point_old = end_point

    local adjust_raw
    local adjust
    local deadzone = 0.05

    -- use elevator stick to zoom
    adjust_raw = getValue('ele') / 1024
    if math.abs(adjust_raw) > deadzone then
        adjust = adjust_raw * .1
        if adjust < -1 * (end_proportion - start_proportion) / 2 then adjust = 0 end
        end_proportion = end_proportion + adjust 
        start_proportion = start_proportion - adjust
        if start_proportion < 0 then start_proportion = 0 end
        if end_proportion > 1 then end_proportion = 1 end
    end

    -- use aileron stick pan
    adjust_raw = getValue('ail') / 1024
    if math.abs(adjust_raw) > deadzone then
        adjust = adjust_raw * .1
        if adjust > (1 - end_proportion) then adjust = 1 - end_proportion end
        if adjust < -1 * start_proportion then adjust = -1 * start_proportion end
        end_proportion = end_proportion + adjust 
        start_proportion = start_proportion + adjust
    end
    
    -- apply zoom and pan to compute start and end points
    start_point = math.floor(start_proportion * n_values)
    end_point = math.floor(end_proportion * n_values)
    if start_point < 0 then start_point = 0 end
    if end_point > n_values then end_point = n_values end

    -- use scroll wheel to increment time
    if event == EVT_ROT_LEFT then
        selected_point = selected_point - 1
    end
    if event == EVT_ROT_RIGHT then
        selected_point = selected_point + 1
    end
    
    -- use rudder stick to increment time quickly
    adjust_raw = getValue('rud') / 1024
    if math.abs(adjust_raw) > deadzone then
        adjust = adjust_raw * 60
        selected_point = math.floor(selected_point + adjust)
    end
    
    
    if selected_point ~= selected_point_old then
        -- if selected point is out of bounds, then pan accordingly
        if selected_point < 0 then selected_point = 0 end
        if selected_point > n_values then selected_point = n_values end
        if selected_point < start_point then
            local shift = start_point - selected_point
            end_point = end_point - shift
            start_point = start_point - shift
        end
        if selected_point > end_point then
            local shift = selected_point - end_point
            start_point = start_point + shift
            end_point = end_point + shift
        end
        start_proportion = start_point / n_values
        end_proportion = end_point / n_values
    else
        -- if selected point is out of bounds, then scroll accordingly
        if selected_point < start_point then selected_point = start_point end
        if selected_point > end_point then selected_point = end_point end
    end

    -- press scroll wheel to toggle the user interface
    if event == EVT_ROT_BREAK then
        show_ui = (show_ui + 1) % 4
    end
    
    -- press next page to toggle telemetry
    if event == EVT_VIRTUAL_NEXT_PAGE then
        telemetry_index = (telemetry_index % 2) + 1
    end
    
    -- Redraw the map if there are any updates.
    -- Limiting redraws makes the app more responsive to stick inputs.
    if map_drawn == false or selected_point ~= selected_point_old or show_ui_old ~= show_ui or telemetry_index_old ~= telemetry_index or start_point ~= start_point_old or end_point ~= end_point_old then
        lcd.clear(DARKGREEN)
        if maps[selected_map]["image"] ~= nil then
            lcd.drawBitmap(maps[selected_map]["image"], 0, 0)
        end
          
        -- Draw map if the user selected a telemetry field.
        if sensorSelection[telemetry_index].idx ~= 1 then
            local x = 0
            local y = 0
            local z = 0
            local x_old = 0
            local y_old = 0
            local tele_max = _points[telemetry_index]["max"]
            local tele_min = _points[telemetry_index]["min"]
            local dt = tele_max - tele_min

            local n_gps_values = 0
            local n_map_values = 0

            if styles[selected_style] ==  "Curve" then
                -- draw curve using line segments
                for i = start_point, end_point, 1 do
                    if _values[long_index][i] ~= nil and _values[lat_index][i] ~= nil and _values[telemetry_index][i] ~= nil then
                        if n_gps_values > 0 then
                            -- save previous point for the beginning of the line segment
                            x_old = x
                            y_old = y
                        end
                        -- compute new point for the end of the line segment
                        x = (_values[long_index][i] - long_min) / dx * LCD_W
                        y = LCD_H - (_values[lat_index][i] - lat_min) / dy * LCD_H
                        z = (_values[telemetry_index][i] - tele_min) / dt * 255
                        if n_gps_values > 0
                            and x >= 0 and x <= LCD_W
                            and y >= 0 and y <= LCD_H
                            and z >= 0 and z <= 255
                            and x_old >= 0 and x_old <= LCD_W
                            and y_old >= 0 and y_old <= LCD_H
                            then
                            c = lcd.RGB(250,z,z)
                            lcd.drawLine(x_old,y_old,x,y,SOLID,c)
                            n_map_values = n_map_values + 1
                        end
                        n_gps_values = n_gps_values + 1
                    end
                end
            elseif styles[selected_style] ==  "Points" then
                -- draw points using rectangles 
                for i = start_point, end_point, 1 do
                    if _values[long_index][i] ~= nil and _values[lat_index][i] ~= nil and _values[telemetry_index][i] ~= nil then
                        x = (_values[long_index][i] - long_min) / dx * LCD_W
                        y = LCD_H - (_values[lat_index][i] - lat_min) / dy * LCD_H
                        z = (_values[telemetry_index][i] - tele_min) / dt * 255
                        if z < 0 then z = 0 end
                        if z > 255 then z = 255 end
                        if x >= 0 and x <= LCD_W
                            and y >= 0 and y <= LCD_H
                            and z >= 0 and z <= 255
                            then
                            c = lcd.RGB(255,z,z)
                            lcd.drawFilledRectangle(x,y,selected_point_size,selected_point_size,c)
                            n_map_values = n_map_values + 1
                        end
                        n_gps_values = n_gps_values + 1
                    end
                end
            end

            if n_gps_values == 0 then
                -- show error message if there is no GPS data
                lcd.drawFilledRectangle(75,130,200,40,BLACK)
                lcd.drawText( 80, 130, "No GPS Data", DBLSIZE + RED)
            elseif n_map_values == 0 then
                -- show error message if GPS data is a outside of the map
                lcd.drawFilledRectangle(75,130,340,40,BLACK)
                lcd.drawText( 80, 130, "GPS Data Outside Map", DBLSIZE + RED)
            end

            if show_ui == 0 or show_ui == 1 or show_ui == 2 then
                -- draw crosshairs on selected point
                if _values[long_index][selected_point] ~= nil and _values[lat_index][selected_point] ~= nil then
                    x = (_values[long_index][selected_point] - long_min) / dx * LCD_W
                    y = LCD_H - (_values[lat_index][selected_point] - lat_min) / dy * LCD_H
                    if x >= 0 and x <= LCD_W then
                        lcd.drawLine(x,0,x,LCD_H,SOLID,WHITE)
                    end
                    if y >= 0 and y <= LCD_H then
                        lcd.drawLine(0,y,LCD_W,y,SOLID,WHITE)
                    end
                end
            end

            if show_ui == 0 or show_ui == 1 then
                -- draw telemetry of selected point
                lcd.drawFilledRectangle(0,LCD_H-80-20,105,80+20,BLACK)
                lcd.drawText(0,LCD_H-100,"Time: " .. toDuration1(current_session.total_seconds * (selected_point) / (n_values)), WHITE + SMLSIZE)
                for i = 1,2,1 do
                    if sensorSelection[i].idx ~= 1 then
                        local telemetry_string = ":"
                        if _values[i][selected_point] ~= nil then
                            telemetry_string = string.format(": %.1f", _values[i][selected_point])
                        end
                        local offset = 20 * (i - 1)
                        lcd.drawText(0,LCD_H-80+offset,_points[i]["name"] .. telemetry_string, WHITE + SMLSIZE)
                    end
                end
                local lat_string = " "
                local long_string = " "
                if _values[long_index][selected_point] ~= nil and _values[lat_index][selected_point] ~= nil then
                    lat_string = string.format(" %.4f", _values[lat_index][selected_point])
                    long_string = string.format(" %.4f", _values[long_index][selected_point])
                end
                lcd.drawText(0,LCD_H-40,"lat:" .. lat_string, WHITE + SMLSIZE)
                lcd.drawText(0,LCD_H-20,"long:" .. long_string, WHITE + SMLSIZE)

                -- draw legend background
                lcd.drawFilledRectangle(0,0,60,155,BLACK)

                -- draw field name
                lcd.drawText(0,0,_points[telemetry_index]["name"], WHITE + SMLSIZE)

                -- draw scale
                for i = 0, 25, 1 do
                    lcd.drawFilledRectangle(5,20+i*5,5,5,lcd.RGB(255,255-i*10,255-i*10))
                end

                -- draw scale labels
                lcd.drawText(15, 15, string.format("%.1f", tele_max), WHITE + SMLSIZE)
                lcd.drawText(15, 135, string.format("%.1f",tele_min), WHITE + SMLSIZE)
                
                -- draw timeline
                lcd.drawFilledRectangle(LCD_W-110,LCD_H-30,110,30,BLACK)
                lcd.drawText(LCD_W-110+30,LCD_H-30,"Timeline", WHITE + SMLSIZE)
                lcd.drawFilledRectangle(LCD_W-105,LCD_H-8,1,6,WHITE)
                lcd.drawFilledRectangle(LCD_W-6,LCD_H-8,1,6,WHITE)
                local selected_proportion = selected_point / n_values
                lcd.drawFilledRectangle(LCD_W - 105 + 99 * selected_proportion,LCD_H-8,1,6,WHITE)
                local timeline_width = 100 * (end_proportion - start_proportion)
                local timeline_start = LCD_W - 105 + start_proportion * 100
                lcd.drawFilledRectangle(timeline_start,LCD_H-6,timeline_width,2,WHITE)
            end
        end

        -- draw help
        if show_ui == 0 then
            local box_width = 220
            lcd.drawFilledRectangle(LCD_W-box_width,0,box_width,140,BLACK)
            lcd.drawText(LCD_W-box_width+5,0,"elevator: zoom timeline", WHITE + SMLSIZE)
            lcd.drawText(LCD_W-box_width+5,20,"aileron: pan timeline", WHITE + SMLSIZE)
            lcd.drawText(LCD_W-box_width+5,40,"rudder: scroll timeline", WHITE + SMLSIZE)
            lcd.drawText(LCD_W-box_width+5,60,"scroll wheel: scroll slowly", WHITE + SMLSIZE)
            lcd.drawText(LCD_W-box_width+5,80,"press wheel: toggle user interface", WHITE + SMLSIZE)
            lcd.drawText(LCD_W-box_width+5,100,"next page: toggle telemetry field", WHITE + SMLSIZE)
            lcd.drawText(LCD_W-box_width+5,120,"press and hold return: exit", WHITE + SMLSIZE)
        end
        map_drawn = true
        map_draws = map_draws + 1
    end

    return 0
end

function M.init()
end

function M.run(event, touchState)
    if event == nil then
        error("Cannot be run as a model script!")
        return 2
    end

    if state ~= STATE.SHOW_GRAPH then drawMain() end

    if state == STATE.SPLASH then
        return state_SPLASH()

    elseif state == STATE.SELECT_INDEX_TYPE_INIT then
        log("STATE.SELECT_INDEX_TYPE_INIT")
        return state_SELECT_INDEX_TYPE_init(event, touchState)

    elseif state == STATE.SELECT_INDEX_TYPE then
        return state_SELECT_INDEX_TYPE_refresh(event, touchState)

    elseif state == STATE.INDEX_FILES_INIT then
        log("STATE.INDEX_FILES_INIT")
        return state_INDEX_FILES_INIT(event, touchState)

    elseif state == STATE.INDEX_FILES then
        log("STATE.INDEX_FILES")
        return state_INDEX_FILES(event, touchState)

    elseif state == STATE.SELECT_FILE_INIT then
        log("STATE.SELECT_FILE_INIT")
        return state_SELECT_FILE_init(event, touchState)

    elseif state == STATE.SELECT_FILE then
        return state_SELECT_FILE_refresh(event, touchState)

    elseif state == STATE.SELECT_SENSORS_INIT then
        log("STATE.SELECT_SENSORS_INIT")
        return state_SELECT_SENSORS_INIT(event, touchState)

    elseif state == STATE.SELECT_SENSORS then
        map_drawn = false
        return state_SELECT_SENSORS_refresh(event, touchState)

    elseif state == STATE.READ_FILE_DATA then
        log("STATE.READ_FILE_DATA")
        return state_READ_FILE_DATA_refresh(event, touchState)

    elseif state == STATE.PARSE_DATA then
        log("STATE.PARSE_DATA")
        return state_PARSE_DATA_refresh(event, touchState)

    elseif state == STATE.SHOW_GRAPH then
        return state_SHOW_GRAPH_refresh(event, touchState)

    end

    --impossible state
    error("Something went wrong with the script!")
    return 2
end

return M