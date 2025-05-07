local lcs = require("copilot-lsp.lcs")
local M = {}

---@param lines string[]
---@param range lsp.Range
local function extract_lines_from_range(lines, range)
    local start_row = range.start.line + 1
    local start_col = range.start.character + 1
    local end_row = range["end"].line + 1
    local end_col = range["end"].character + 1

    local source_lines = {}
    -- Loop through the zero-indexed range [source_start_row, source_end_row)
    for i = start_row, end_row do
        local line = lines[i]

        if i == start_row then
            line = line:sub(start_col, -1)
        elseif i == end_row then
            line = line:sub(1, end_col - 1)
        end

        -- strip CR characters when neovim fails to identify the correct file format
        if vim.endswith(line, "\r") then
            table.insert(source_lines, line:sub(1, -2))
        else
            table.insert(source_lines, line)
        end
    end

    return source_lines
end

---@param source_buf string[]
---@param target_edit lsp.TextEdit
---@return lsp.TextEdit[]
function M.compute_minimal_edits(source_buf, target_edit)
    local source_lines = extract_lines_from_range(source_buf, target_edit.range)
    local target_lines = vim.split(target_edit.newText, "\r?\n")

    local source_text = table.concat(source_lines, "\n")
    local target_text = table.concat(target_lines, "\n")

    local indices = vim.diff(source_text, target_text, {
        algorithm = "histogram",
        result_type = "indices",
    })
    assert(type(indices) == "table")

    ---@type lsp.TextEdit[]
    local edits = {}

    for _, idx in ipairs(indices) do
        local source_line_start, source_line_count, target_line_start, target_line_count = unpack(idx)
        local source_line_end = source_line_start + source_line_count - 1
        local target_line_end = target_line_start + target_line_count - 1

        local source = table.concat(source_lines, "\n", source_line_start, source_line_end)
        local target = table.concat(target_lines, "\n", target_line_start, target_line_end)

        local text_edits = lcs.to_lsp_edits(
            lcs.diff(source, target),
            source_line_start + target_edit.range.start.line - 1,
            target_edit.range.start.character
        )

        vim.list_extend(edits, text_edits)
    end

    local contains_non_whitespace_edit = vim.iter(edits):any(function(edit)
        return edit.newText:find("%S") ~= nil
    end)

    -- Diff the whole text if we encounter a non whitespace character in the edit.
    -- This might happen when the formatted document deletes many lines
    -- and `vim.diff` split those deletions into multiple hunks.
    if contains_non_whitespace_edit then
        edits = lcs.to_lsp_edits(
            lcs.diff(source_text, target_text),
            target_edit.range.start.line,
            target_edit.range.start.character
        )
    end

    return edits
end

return M
