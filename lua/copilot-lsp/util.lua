local M = {}
---@param edit copilotlsp.InlineEdit
function M.apply_inline_edit(edit)
    local bufnr = vim.uri_to_bufnr(edit.textDocument.uri)

    ---@diagnostic disable-next-line: assign-type-mismatch
    vim.lsp.util.apply_text_edits({ edit }, bufnr, "utf-16")
end

---Debounces calls to a function, and ensures it only runs once per delay
---even if called repeatedly.
---@param fn fun(...: any)
---@param delay integer
function M.debounce(fn, delay)
    local running = false
    local timer = assert(vim.uv.new_timer())

    -- Ugly hack to ensure timer is closed when the function is garbage collected
    -- unfortunate but necessary to avoid creating a new timer for each call.
    --
    -- In LuaJIT, only userdata can have finalizers. `newproxy` creates an opaque userdata
    -- which we can attach a finalizer to and use as a "canary."
    local proxy = newproxy(true)
    getmetatable(proxy).__gc = function()
        if not timer:is_closing() then
            timer:close()
        end
    end
    local args

    return function(...)
        args = { ... }
        local _ = proxy
        if running then
            return
        end
        running = true
        timer:start(
            delay,
            0,
            vim.schedule_wrap(function()
                fn(unpack(args))
                running = false
            end)
        )
    end
end

return M
