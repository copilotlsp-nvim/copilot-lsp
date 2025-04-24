local M = {}

---@param a string
---@param b string
---@return string
function M.uncommon_tail(a, b)
    -- lowercase copies to do a case-insensitive match
    local la, lb = a:lower(), b:lower()
    -- try to find la at the very start of lb, plain-pattern
    local s, e = lb:find(la, 1, true)
    if s == 1 then
        -- if it matches at the start, return the rest of the original b
        return b:sub(e + 1)
    else
        -- no common prefix: return all of b
        return b
    end
end

return M
