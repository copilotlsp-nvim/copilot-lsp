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
    local timer = vim.uv.new_timer()
    return function(...)
        local argv = vim.F.pack_len(...)
        timer:start(delay, 0, function()
            timer:stop()
            vim.schedule_wrap(fn)(vim.F.unpack_len(argv))
        end)
    end
end

return M
