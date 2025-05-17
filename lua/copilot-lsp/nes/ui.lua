local M = {}

---@param bufnr integer
---@param ns_id integer
local function _dismiss_suggestion(bufnr, ns_id)
    pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns_id, 0, -1)
end

---@param bufnr? integer
---@param ns_id integer
function M.clear_suggestion(bufnr, ns_id)
    bufnr = bufnr and bufnr > 0 and bufnr or vim.api.nvim_get_current_buf()
    if vim.b[bufnr].nes_jump then
        vim.b[bufnr].nes_jump = false
        return
    end
    _dismiss_suggestion(bufnr, ns_id)
    ---@type copilotlsp.InlineEdit
    local state = vim.b[bufnr].nes_state
    if not state then
        return
    end

    vim.b[bufnr].nes_state = nil
    vim.b[bufnr].nes_last_cursor_pos = nil
end

---@private
---@param bufnr integer
---@param edit lsp.TextEdit
---@return copilotlsp.nes.InlineEditPreview
function M._calculate_preview(bufnr, edit)
    local text = edit.newText
    local range = edit.range
    local start_line = range.start.line
    local start_char = range.start.character
    local end_line = range["end"].line
    local end_char = range["end"].character

    -- Split text by newline. Use plain=true to handle trailing newline correctly.
    local new_lines = vim.split(text, "\n", { plain = true })
    local num_new_lines = #new_lines

    local old_lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line + 1, false)
    local num_old_lines = #old_lines

    local is_same_line = start_line == end_line
    local is_deletion = text == ""
    local lines_edit = is_same_line or (start_char == 0 and end_char == 0)
    local is_insertion = is_same_line and start_char == end_char

    if is_deletion and is_insertion then
        -- no-op
        return {}
    end

    if is_deletion and lines_edit then
        return {
            deletion = {
                range = edit.range,
            },
        }
    end

    if is_insertion and num_new_lines == 1 and text ~= "" then
        -- inline insertion
        return {
            inline_insertion = {
                text = text,
                line = start_line,
                character = start_char,
            },
        }
    end

    if is_insertion and num_new_lines > 1 then
        if start_char == #old_lines[1] and new_lines[1] == "" then
            -- insert lines after the start line
            return {
                lines_insertion = {
                    text = table.concat(vim.list_slice(new_lines, 2), "\n"),
                    line = start_line,
                },
            }
        end

        if end_char == 0 and new_lines[num_new_lines] == "" then
            -- insert lines before the end line
            return {
                lines_insertion = {
                    text = table.concat(vim.list_slice(new_lines, 1, num_new_lines - 1), "\n"),
                    line = start_line,
                    above = true,
                },
            }
        end
    end

    -- insert lines in the middle
    local prefix = old_lines[1]:sub(1, start_char)
    local suffix = old_lines[num_old_lines]:sub(end_char + 1)
    local new_lines_extend = vim.deepcopy(new_lines)
    new_lines_extend[1] = prefix .. new_lines_extend[1]
    new_lines_extend[num_new_lines] = new_lines_extend[num_new_lines] .. suffix
    local insertion = table.concat(new_lines_extend, "\n")

    return {
        deletion = {
            range = {
                start = { line = start_line, character = 0 },
                ["end"] = { line = end_line, character = #old_lines[num_old_lines] },
            },
        },
        lines_insertion = {
            text = insertion,
            line = end_line,
        },
    }
end

---@private
---@param bufnr integer
---@param ns_id integer
---@param preview copilotlsp.nes.InlineEditPreview
function M._display_preview(bufnr, ns_id, preview)
    if preview.deletion then
        local range = preview.deletion.range
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, range.start.line, range.start.character, {
            hl_group = "CopilotLspNesDelete",
            end_row = range["end"].line,
            end_col = range["end"].character,
        })
    end

    local inline_insertion = preview.inline_insertion
    if inline_insertion then
        local virt_lines =
            require("copilot-lsp.util").hl_text_to_virt_lines(inline_insertion.text, vim.bo[bufnr].filetype)
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, inline_insertion.line, inline_insertion.character, {
            virt_text = virt_lines[1],
            virt_text_pos = "inline",
        })
    end

    local lines_insertion = preview.lines_insertion
    if lines_insertion then
        local virt_lines =
            require("copilot-lsp.util").hl_text_to_virt_lines(lines_insertion.text, vim.bo[bufnr].filetype)
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, lines_insertion.line, 0, {
            virt_lines = virt_lines,
            virt_lines_above = lines_insertion.above,
        })
    end
end

---@private
---@param bufnr integer
---@param ns_id integer
---@param edits copilotlsp.InlineEdit[]
function M._display_next_suggestion(bufnr, ns_id, edits)
    M.clear_suggestion(bufnr, ns_id)
    if not edits or #edits == 0 then
        -- vim.notify("No suggestion available", vim.log.levels.INFO)
        return
    end

    local suggestion = edits[1]

    local preview = M._calculate_preview(bufnr, suggestion)
    M._display_preview(bufnr, ns_id, preview)

    vim.b[bufnr].nes_state = suggestion
    vim.b[bufnr].nes_namespace_id = ns_id

    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        buffer = bufnr,
        callback = function()
            if not vim.b[bufnr].nes_state then
                return true
            end

            -- Get cursor info
            local cursor = vim.api.nvim_win_get_cursor(0)
            local cursor_line = cursor[1] - 1 -- 0-indexed
            local prev_pos = vim.b[bufnr].nes_last_cursor_pos or cursor_line
            vim.b[bufnr].nes_last_cursor_pos = cursor_line
            local suggestion_line = suggestion.range.start.line

            -- Calculate distances
            local distance_to_suggestion_start = math.abs(cursor_line - suggestion_line)
            local prev_distance = math.abs(prev_pos - suggestion_line)

            -- Only clear if:
            -- 1. We're far away from the suggestion (outside buffer zone), AND
            -- 2. Either we're moving away from the suggestion, OR we're not within a reasonable viewing distance
            local buffer_zone = 2 -- Lines buffer
            local max_view_distance = 10 -- Don't clear if within reasonable viewing distance

            if
                distance_to_suggestion_start > buffer_zone
                and (
                    distance_to_suggestion_start > prev_distance -- Moving away
                    or distance_to_suggestion_start > max_view_distance
                ) -- Too far to be relevant
            then
                M.clear_suggestion(bufnr, ns_id)
                return true
            end

            return false -- Keep the autocmd
        end,
    })
    -- Also clear on text changes that affect the suggestion area
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        buffer = bufnr,
        callback = function()
            if not vim.b[bufnr].nes_state then
                return true
            end
            -- Check if the text at the suggestion position has changed
            local start_line = suggestion.range.start.line
            -- If the lines are no longer in the buffer, clear the suggestion
            if start_line >= vim.api.nvim_buf_line_count(bufnr) then
                M.clear_suggestion(bufnr, ns_id)
                return true
            end
            return false -- Keep the autocmd
        end,
    })
end

---Private
---Clear the current suggestion if it exists
---@return boolean
function M._clear_current_suggestion()
    local buf = vim.api.nvim_get_current_buf()
    if vim.b[buf].nes_state then
        -- Use stored namespace ID from buffer variable
        local ns = vim.b[buf].nes_namespace_id
        if ns then
            M.clear_suggestion(buf, ns)
            return true
        end
    end
    return false
end

return M
