local M = {}

---@param bufnr integer
---@param suggestion_ui nes.EditSuggestionUI
---@param ns_id integer
local function _dismiss_suggestion_ui(bufnr, suggestion_ui, ns_id)
    pcall(vim.api.nvim_win_close, suggestion_ui.preview_winnr, true)
    pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns_id, 0, -1)
end

---@param bufnr? integer
---@param ns_id integer
function M.clear_suggestion(bufnr, ns_id)
    bufnr = bufnr and bufnr > 0 and bufnr or vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    ---@type copilotlsp.InlineEdit
    local state = vim.b[bufnr].nes_state
    if not state then
        return
    end

    _dismiss_suggestion_ui(bufnr, state.ui, ns_id)
    vim.b[bufnr].nes_state = nil
end

local function trim_end(s)
    return s:gsub("%s+$", "")
end

---@private
---@param suggestion copilotlsp.InlineEdit
---@return nes.LineCalculationResult
function M._calculate_lines(suggestion)
    local deleted_lines_count = suggestion.range["end"].line - suggestion.range.start.line
    local added_lines = vim.split(trim_end(suggestion.newText), "\n")
    local added_lines_count = suggestion.newText == "" and 0 or #added_lines
    local same_line = 0

    if deleted_lines_count == 0 and added_lines_count == 1 then
        ---changing within line
        deleted_lines_count = 1
        same_line = 1
    end

    -- if
    --     suggestion.range.start.line == suggestion.range["end"].line
    --     and suggestion.range.start.character == suggestion.range["end"].character
    -- then
    --     --add only
    --     TODO: Do we need to position specifically for add only?
    --     UI tests seem to say no
    -- end

    -- Calculate positions for delete highlight extmark
    ---@type nes.DeleteExtmark
    local delete_extmark = {
        row = suggestion.range.start.line,
        end_row = (
            suggestion.range["end"].character ~= 0 and suggestion.range["end"].line + 1
            or suggestion.range["end"].line
        ),
    }

    -- Calculate positions for virtual lines extmark
    ---@type nes.VirtLinesExtmark
    local virt_lines_extmark = {
        row = (
            suggestion.range["end"].character ~= 0 and suggestion.range["end"].line
            or suggestion.range["end"].line - 1
        ),
        virt_lines_count = added_lines_count,
    }

    -- Calculate positions for floating window
    ---@type nes.FloatWin
    local float_win = {
        height = #added_lines,
        row = suggestion.range["end"].line + deleted_lines_count + (suggestion.range["end"].character ~= 0 and 1 or 0),
    }

    return {
        deleted_lines_count = deleted_lines_count,
        added_lines = added_lines,
        added_lines_count = added_lines_count,
        same_line = same_line,
        delete_extmark = delete_extmark,
        virt_lines_extmark = virt_lines_extmark,
        float_win = float_win,
    }
end

---@private
---@param edits copilotlsp.InlineEdit[]
---@param ns_id integer
function M._display_next_suggestion(edits, ns_id)
    local state = vim.b[vim.api.nvim_get_current_buf()].nes_state
    if state then
        M.clear_suggestion(vim.api.nvim_get_current_buf(), ns_id)
    end

    if not edits or #edits == 0 then
        -- vim.notify("No suggestion available", vim.log.levels.INFO)
        return
    end
    local bufnr = vim.uri_to_bufnr(edits[1].textDocument.uri)
    local win_id = vim.fn.win_findbuf(bufnr)[1]
    local suggestion = edits[1]

    local ui = {}
    local lines = M._calculate_lines(suggestion)

    if lines.deleted_lines_count > 0 then
        -- Deleted range red highlight
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, lines.delete_extmark.row, 0, {
            hl_group = "NesDelete",
            end_row = lines.delete_extmark.end_row,
        })
    end
    if lines.added_lines_count > 0 then
        -- Create space for float
        local virt_lines = {}
        for _ = 1, lines.virt_lines_extmark.virt_lines_count do
            table.insert(virt_lines, {
                { "", "Normal" },
            })
        end
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, lines.virt_lines_extmark.row, 0, {
            virt_lines = virt_lines,
        })

        local preview_bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(preview_bufnr, 0, -1, false, lines.added_lines)
        vim.bo[preview_bufnr].modifiable = false
        vim.bo[preview_bufnr].buflisted = false
        vim.bo[preview_bufnr].bufhidden = "wipe"
        vim.bo[preview_bufnr].filetype = vim.bo[bufnr].filetype

        local cursor = vim.api.nvim_win_get_cursor(win_id)
        local win_width = vim.api.nvim_win_get_width(win_id)
        local offset = vim.fn.getwininfo(win_id)[1].textoff
        local preview_winnr = vim.api.nvim_open_win(preview_bufnr, false, {
            relative = "cursor",
            width = win_width - offset,
            height = lines.float_win.height,
            row = lines.float_win.row - cursor[1],
            col = 0,
            style = "minimal",
            border = "none",
        })
        vim.wo[preview_winnr].number = false
        vim.wo[preview_winnr].winhighlight = "Normal:NesAdd"
        vim.wo[preview_winnr].winblend = 0

        ui.preview_winnr = preview_winnr
    end

    suggestion.ui = ui

    vim.b[bufnr].nes_state = suggestion

    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        buffer = bufnr,
        callback = function()
            if not vim.b.nes_state then
                return true
            end

            local accepted_cursor = vim.b.nes_state.accepted_cursor
            if accepted_cursor then
                local cursor = vim.api.nvim_win_get_cursor(win_id)
                if cursor[1] == accepted_cursor[1] and cursor[2] == accepted_cursor[2] then
                    return
                end
            end

            M.clear_suggestion(bufnr, ns_id)
            return true
        end,
    })
end

return M
