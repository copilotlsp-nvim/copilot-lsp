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
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    ---@type copilotlsp.InlineEdit
    local state = vim.b[bufnr].nes_state
    if not state then
        return
    end

    _dismiss_suggestion(bufnr, ns_id)
    vim.b[bufnr].nes_state = nil
end

local function trim_end(s)
    return s:gsub("%s+$", "")
end

---@private
---@param suggestion copilotlsp.InlineEdit
---@return copilotlsp.nes.LineCalculationResult
function M._calculate_lines(suggestion)
    local deleted_lines_count = suggestion.range["end"].line - suggestion.range.start.line
    local added_lines = vim.split(trim_end(suggestion.newText), "\n")
    local added_lines_count = suggestion.newText == "" and 0 or #added_lines
    local same_line = false

    if deleted_lines_count == 0 and added_lines_count == 1 then
        ---changing within line
        deleted_lines_count = 1
        same_line = true
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
    ---@type copilotlsp.nes.DeleteExtmark
    local delete_extmark = {
        row = suggestion.range.start.line,
        end_row = (
            suggestion.range["end"].character ~= 0 and suggestion.range["end"].line + 1
            or suggestion.range["end"].line
        ),
    }

    -- Calculate positions for virtual lines extmark
    ---@type copilotlsp.nes.AddExtmark
    local virt_lines_extmark = {
        row = (
            suggestion.range["end"].character ~= 0 and suggestion.range["end"].line
            or suggestion.range["end"].line - 1
        ),
        virt_lines_count = added_lines_count,
    }

    return {
        deleted_lines_count = deleted_lines_count,
        added_lines = added_lines,
        added_lines_count = added_lines_count,
        same_line = same_line,
        delete_extmark = delete_extmark,
        virt_lines_extmark = virt_lines_extmark,
    }
end

---@private
---@class TextDeletion
---@field range lsp.Range

---@private
---@class InlineInsertion
---@field text string
---@field line integer
---@field character integer

---@private
---@class TextInsertion
---@field text string
---@field line integer insert lines at this line

---@private
---@class InlineEditPreview
---@field deletions? TextDeletion[]
---@field inline_insertion? InlineInsertion
---@field lines_insertion? TextInsertion

---@param bufnr integer
---@param edit lsp.TextEdit
---@return InlineEditPreview
function M.preview_inline_edit(bufnr, edit)
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
    local is_insertion = is_same_line and start_char == end_char

    if is_deletion and is_insertion then
        -- no-op
        return {}
    end

    if is_same_line and is_deletion then
        -- inline deletion
        return {
            deletions = {
                {
                    range = edit.range,
                },
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
                line_insertion = {
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
        deletions = {
            {
                range = {
                    start = { line = start_line, character = 0 },
                    ["end"] = { line = end_line, character = #old_lines[num_old_lines] },
                },
            },
        },
        lines_insertion = {
            text = insertion,
            line = end_line,
        },
    }
end

---@private
---@param edits copilotlsp.InlineEdit[]
---@param ns_id integer
function M._display_next_suggestion(edits, ns_id)
    local bufnr = vim.api.nvim_get_current_buf()
    local state = vim.b[bufnr].nes_state
    if state then
        M.clear_suggestion(vim.api.nvim_get_current_buf(), ns_id)
    end

    if not edits or #edits == 0 then
        -- vim.notify("No suggestion available", vim.log.levels.INFO)
        return
    end
    local bufnr = vim.uri_to_bufnr(edits[1].textDocument.uri)
    local suggestion = edits[1]

    local lines = M._calculate_lines(suggestion)

    local line_replacement = false
    -- check if the edit is a inline insert or delete but not a whole line replacement
    if lines.same_line then
        local row = suggestion.range.start.line
        local start_col = suggestion.range.start.character
        local end_col = suggestion.range["end"].character
        local line_text = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
        if start_col == 0 and end_col == #line_text then
            line_replacement = true
        end
    end

    if lines.same_line and not line_replacement then
        local row = suggestion.range.start.line
        local start_col = suggestion.range.start.character
        local end_col = suggestion.range["end"].character

        -- inline edit
        if start_col < end_col then
            vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, start_col, {
                hl_group = "CopilotLspNesDelete",
                end_col = end_col,
            })
        end
        if suggestion.text ~= "" then
            local virt_lines =
                require("copilot-lsp.util").hl_text_to_virt_lines(suggestion.text, vim.bo[bufnr].filetype)
            local virt_text = virt_lines[1]
            vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, end_col, {
                virt_text = virt_text,
                virt_text_pos = "inline",
            })
        end
    else
        if lines.deleted_lines_count > 0 then
            -- Deleted range red highlight
            vim.api.nvim_buf_set_extmark(bufnr, ns_id, lines.delete_extmark.row, 0, {
                hl_group = "CopilotLspNesDelete",
                end_row = lines.delete_extmark.end_row,
            })
        end
        if lines.added_lines_count > 0 then
            local text = trim_end(edits[1].text)
            local virt_lines = require("copilot-lsp.util").hl_text_to_virt_lines(text, vim.bo[bufnr].filetype)

            vim.api.nvim_buf_set_extmark(bufnr, ns_id, lines.virt_lines_extmark.row, 0, {
                virt_lines = virt_lines,
            })
        end
    end

    vim.b[bufnr].nes_state = suggestion

    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        buffer = bufnr,
        callback = function()
            if not vim.b.nes_state then
                return true
            end

            M.clear_suggestion(bufnr, ns_id)
            return true
        end,
    })
end

return M
