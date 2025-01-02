local m_log, app_name, m_utils, m_config = ...

local M = {}
M.m_log = m_log
M.app_name = app_name
M.m_utils = m_utils

local max_log_size_mb = m_config.max_log_size_mb

--function cache
local math_floor = math.floor
local math_fmod = math.fmod
local string_gmatch = string.gmatch
local string_gsub = string.gsub
local string_len = string.len
local string_sub = string.sub
local string_char = string.char
local string_byte = string.byte

--local M.m_log = require("./LogViewer/lib_log")
--local M.m_utils = require("LogViewer/utils")

function M.getTotalSeconds(time)
    local total = tonumber(string.sub(time, 1, 2)) * 3600
    total = total + tonumber(string.sub(time, 4, 5)) * 60
    total = total + tonumber(string.sub(time, 7, 8))
    return total
end

function contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

function M.getFileDataInfo(fileName)
    M.m_log.info("getFileDataInfo(%s)", fileName)

    --local t1_model =getTime()

    local hFile = io.open("/LOGS/" .. fileName, "r")
    if hFile == nil then
        return nil, nil, nil, nil, nil, nil, nil
    end

    local buffer = ""
    local start_time
    local end_time
    local total_lines = 0
    local start_index
    local col_with_data_str = ""
    local all_col_str = ""

    local columns_by_header = {}
    local columns_is_have_data = {}
    local columns_with_data = {}
    
    -- check file size
    io.seek(hFile, max_log_size_mb * 1024 * 1024)
    local s = io.read(hFile, 2)
    io.seek(hFile,0)
    if string.len(s) > 0 then
        M.m_log.info("File too large, file: %s", fileName)
        io.close(hFile)
        return nil, nil, nil, nil, nil, nil, nil
    end

    -- read Header
    local data1 = io.read(hFile, 2048)
    local index = string.find(data1, "\n")
    if index == nil then
        M.m_log.info("Header could not be found, file: %s", fileName)
        io.close(hFile)
        return nil, nil, nil, nil, nil, nil, nil
    end

    -- get header line
    local headerLine = string.sub(data1, 1, index - 1)
    --M.m_log.info("header-line: [%s]", headerLine)

    -- get columns
    columns_by_header = M.m_utils.split(headerLine)
    
    if contains(columns_by_header,"GPS") then
        local i = #columns_by_header
        columns_by_header[i+1]="longitude"
        columns_by_header[i+2]="latitude"
    else
        M.m_log.info("No GPS column, file: %s", fileName)
        io.close(hFile)
        return nil, nil, nil, nil, nil, nil, nil
    end

    start_index = index
    io.seek(hFile, index)

    -- as a backstop, stop after 2x max file size above
    local sample_col_data = nil
    for i = 1, max_log_size_mb * 1024 do
        --M.m_log.info("profiler: start")
        --local t1 =getTime()
        local data2 = io.read(hFile, 2048)
        --M.m_utils.timeProfilerAdd('read()', t1);

        -- file read done
        if data2 == "" then
            -- done reading file
            io.close(hFile)

            -- calculate data
            local first_time_sec = M.getTotalSeconds(start_time)
            local last_time_sec = M.getTotalSeconds(end_time)
            local total_seconds = last_time_sec - first_time_sec
            M.m_log.info("parser:getFileDataInfo: done - [%s] lines: %d, duration: %dsec", fileName, total_lines, total_seconds)

            for idxCol = 1, #columns_by_header do
                local col_name = columns_by_header[idxCol]
                col_name = string_gsub(col_name, "\n", "")
                col_name = M.m_utils.trim_safe(col_name)
                if columns_is_have_data[idxCol] == true and col_name ~= "Date" and col_name ~= "Time" then
                    columns_with_data[#columns_with_data + 1] = col_name
                    if string_len(col_with_data_str) == 0 then
                        col_with_data_str = col_name
                    else
                        col_with_data_str = col_with_data_str .. "|" .. col_name
                    end
                end

                if string_len(all_col_str) == 0 then
                    all_col_str = col_name
                else
                    all_col_str = all_col_str .. "|" .. col_name
                end
            end

            return start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str, all_col_str
        end

        buffer = buffer .. data2
        local idx_buff = 0

        local line_list = string_gmatch(buffer, "([^\n]+)\n")
        for line in line_list do
            total_lines = total_lines + 1
            local time = string.sub(line, 12, 19)
            --M.m_log.info("getFileDataInfo: %d. time: %s", total_lines, time)
            if start_time == nil then
                start_time = time
            end
            end_time = time
            local vals = M.m_utils.split(line) -- hot

            if sample_col_data == nil then
                sample_col_data = vals
                for idxCol = 1, #columns_by_header, 1 do
                    -- initialize to false
                    columns_is_have_data[idxCol] = false
                end
            end

            -- if the data in the current row is different from the data in the first row, then
            -- the column has variable data and will be selectable by the user for plotting
            for idxCol = 1, #columns_by_header, 1 do
                if columns_is_have_data[idxCol] == false
                    and (vals[idxCol] ~= sample_col_data[idxCol])
                    and (tonumber(vals[idxCol]) ~= nil) then
                    columns_is_have_data[idxCol] = true
                end
            end

            idx_buff = idx_buff + string.len(line) + 1 -- dont forget the newline
        end

        for idxCol = 1, #columns_by_header, 1 do
            local curr_col = columns_by_header[idxCol]

            -- always hide these columns
            local cols_to_hide = {'LSW', 'GPS', 'latitude', 'longitude'}
            for _,col in pairs(cols_to_hide) do
                if curr_col == col then columns_is_have_data[idxCol] = false end
            end

            -- always show these columns
            local cols_to_show = {'RQly', 'TQly', 'TPWR', 'RSNR', 'VFR'}
            for _,col in pairs(cols_to_show) do
                -- these columns sometimes have "(%)" at the end of the column name,
                -- so string.find() is used here
                if string.find(curr_col,"^" .. col) ~= nil then columns_is_have_data[idxCol] = true end
            end
        end

        buffer = string.sub(buffer, idx_buff + 1) -- dont forget the newline
    end

    io.close(hFile)

    M.m_log.info("File too large, file: %s", fileName)
    return nil, nil, nil, nil, nil, nil, nil
end


return M
