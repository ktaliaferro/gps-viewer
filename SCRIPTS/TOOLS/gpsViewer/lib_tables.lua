local m_log, app_name = ...

local M = {}
M.m_log = m_log
M.app_name = app_name


function M.tprint(t, s)
    for k, v in pairs(t) do
        local kfmt = '["' .. tostring(k) .. '"]'
        if type(k) ~= 'string' then
            kfmt = '[' .. k .. ']'
        end
        local vfmt = '"' .. tostring(v) .. '"'
        if type(v) == 'table' then
            M.tprint(v, (s or '') .. kfmt)
        else
            if type(v) ~= 'string' then
                vfmt = tostring(v)
            end
            M.m_log.info(type(t) .. (s or '') .. kfmt .. ' = ' .. vfmt)
        end
    end
end

function M.table_clear(tbl)
    -- clean without creating a new list
    for i = 0, #tbl do
        table.remove(tbl, 1)
    end
end

function M.table_print(prefix, tbl)
    M.m_log.info(">>> table_print (%s)", prefix)
    for i = 1, #tbl, 1 do
        local val = tbl[i]
        if type(val) ~= "table" then
            M.m_log.info(string.format("%d. %s: %s", i, prefix, val))
        else
            local t_val = val
            M.m_log.info("-++++------------ %d %s", #val, type(t_val))
            for j = 1, #t_val, 1 do
                local val = t_val[j]
                 M.m_log.info(string.format("%d. %s: %s", i, prefix, val))
            end
        end
    end
    M.m_log.info("<<< table_print end (%s) ", prefix)
end

function M.list_ordered_insert(lst, newVal, cmp, firstValAt)
    -- sort
    for i = firstValAt, #lst, 1 do
        -- remove duplication
        if newVal == lst[i] then
            return
        end

        if cmp(newVal, lst[i]) == true then
            table.insert(lst, i, newVal)
            return
        end
    end
    table.insert(lst, newVal)
end


return M
