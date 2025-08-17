local m_log, app_name, m_utils, m_config = ...

local M = {}
M.m_log = m_log
M.app_name = app_name
M.m_utils = m_utils

-- configuration
local heap_index = 32 * 1024 -- number of bytes to index at a time

-- configuration imported from lib_config.lua
local max_log_size_MB = m_config.max_log_size_MB

--function cache
local math_floor = math.floor
local math_fmod = math.fmod
local string_gmatch = string.gmatch
local string_gsub = string.gsub
local string_len = string.len
local string_sub = string.sub
local string_char = string.char
local string_byte = string.byte

local buffer
local start_time
local end_time
local total_lines
local start_index
local col_with_data_str
local all_col_str

local columns_by_header
local columns_is_have_data
local columns_with_data

local index_file
local index_done
local index_progress
local index_size_KB
local index_i
local sample_col_data


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

function M.resetFileReader()
    if index_file ~= nil then
        io.close(index_file)
        index_file = nil
    end
end

function M.getFileDataInfo(fileName)
    M.m_log.info("getFileDataInfo(%s)", fileName)

    local error_message = nil
 
    if index_file == nil then
        index_size_KB = m_utils.get_size(fileName)
        
        index_file = io.open("/LOGS/" .. fileName, "r")
        buffer = ""
        start_time = nil
        end_time = nil
        total_lines = 0
        start_index = nil
        col_with_data_str = ""
        all_col_str = ""

        columns_by_header = {}
        columns_is_have_data = {}
        columns_with_data = {}
        
        index_done = false
        index_progress = 0
        index_i = 0
        sample_col_data = nil
        
        if index_size_KB > max_log_size_MB * 1024 then
            M.m_log.info("File too large, file: %s", fileName)
            io.close(index_file)
            error_message = "too large"
            index_done = true
            index_progress = 1
            index_file = nil
            return nil, nil, nil, nil, nil, nil, nil, error_message, index_done, index_progress, index_size_KB
        end

        -- read Header
        local data1 = io.read(index_file, 2048)
        start_index = string.find(data1, "\n")
        if start_index == nil then
            M.m_log.info("Header could not be found, file: %s", fileName)
            io.close(index_file)
            error_message = "no valid header"
            index_done = true
            index_progress = 1
            index_file = nil
            return nil, nil, nil, nil, nil, nil, nil, error_message, index_done, index_progress, index_size_KB
        end

        -- get header line
        local headerLine = string.sub(data1, 1, start_index - 1)

        -- get columns
        columns_by_header = M.m_utils.split(headerLine)
        
        if contains(columns_by_header,"GPS") then
            local i = #columns_by_header
            columns_by_header[i+1]="longitude"
            columns_by_header[i+2]="latitude"
        else
            M.m_log.info("No GPS column, file: %s", fileName)
            io.close(index_file)
            error_message = "no GPS column"
            index_done = true
            index_progress = 1
            index_file = nil
            return nil, nil, nil, nil, nil, nil, nil, error_message, index_done, index_progress, index_size_KB
        end

        io.seek(index_file, start_index)
        index_done = false
        index_progress = start_index / (index_size_KB * 1024)
        return nil, nil, nil, nil, nil, nil, nil, error_message, index_done, index_progress, index_size_KB
    end

    index_i = index_i + 1
    local data2 = io.read(index_file, heap_index)

    -- file read done
    if data2 == "" then
        -- done reading file
        io.close(index_file)
        index_file = nil
        
        if total_lines < 2 then
            error_message = "less than two lines of data"
            index_done = true
            index_progress = 1
            return nil, nil, nil, nil, nil, nil, nil, error_message, index_done, index_progress, index_size_KB
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

        -- calculate metadata
        local first_time_sec = M.getTotalSeconds(start_time)
        local last_time_sec = M.getTotalSeconds(end_time)
        local total_seconds = last_time_sec - first_time_sec
        if total_seconds < 0 then
            -- the flight ended on the next day
            total_seconds = total_seconds + 60 * 60 * 24
        end
        M.m_log.info("parser:getFileDataInfo: done - [%s] lines: %d, duration: %dsec", fileName, total_lines, total_seconds)

        for idxCol = 1, #columns_by_header do
            local col_name = columns_by_header[idxCol]
            col_name = string_gsub(col_name, "\n", "") -- remove newline
            col_name = M.m_utils.trim_safe(col_name) -- remove leading and trailing whitespace
            -- populate columns_with_data and col_with_data_str
            if columns_is_have_data[idxCol] == true and col_name ~= "Date" and col_name ~= "Time" then
                columns_with_data[#columns_with_data + 1] = col_name
                if string_len(col_with_data_str) == 0 then
                    col_with_data_str = col_name
                else
                    col_with_data_str = col_with_data_str .. "|" .. col_name
                end
            end

            -- populate all_col_str
            if string_len(all_col_str) == 0 then
                all_col_str = col_name
            else
                all_col_str = all_col_str .. "|" .. col_name
            end
        end

        index_done = true
        index_progress = 1
        return start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str, all_col_str, error_message, index_done, index_progress, index_size_KB
    end
        
    -- continue parsing log file
    buffer = buffer .. data2
    local idx_buff = 0

    local line_list = string_gmatch(buffer, "([^\n]+)\n")
    for line in line_list do
        total_lines = total_lines + 1
        local time = string.sub(line, 12, 19)
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

        -- compute the number of characters read from the buffer
        idx_buff = idx_buff + string.len(line) + 1 -- dont forget the newline
    end

    -- remove read characters from the buffer
    -- so that what remains is a single partial line
    buffer = string.sub(buffer, idx_buff + 1) -- dont forget the newline

    index_done = false
    index_progress = math.min((start_index + (index_i-1) * heap_index) / (index_size_KB * 1024), 1)
    return nil, nil, nil, nil, nil, nil, nil, error_message, index_done, index_progress, index_size_KB
end


return M
