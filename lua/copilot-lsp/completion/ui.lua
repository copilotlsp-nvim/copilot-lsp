local M = {}
local comp_util = require("copilot-lsp.completion.util")

local comp_ns = vim.api.nvim_create_namespace("copilot-comp")
local ext_id

---@param completion lsp.InlineCompletionItem
function M.draw_completion(completion)
    local existing_text =
        vim.api.nvim_buf_get_lines(0, completion.range.start.line, completion.range.start.line + 1, false)[1]

    local insertText = completion.insertText
    if type(insertText) == "string" then
        local insertion = comp_util.uncommon_tail(existing_text, insertText)
        local insertion_lines = vim.split(insertion, "\n")
        local virt_lines = {}
        local virt_text = {}
        for i, line in ipairs(insertion_lines) do
            if i == 1 then
                table.insert(virt_text, { line, "Comment" })
            else
                virt_lines[i - 1] = {}
                table.insert(virt_lines[i - 1], { line, "Comment" })
            end
        end
        dd(virt_lines)
        vim.api.nvim_buf_set_extmark(
            0,
            comp_ns,
            completion.range.start.line,
            vim.fn.strdisplaywidth(existing_text) - 1,
            {
                id = ext_id,
                virt_text_pos = "inline",
                virt_text = virt_text,
                virt_lines = virt_lines,
                virt_lines_overflow = "scroll",
                strict = false,
            }
        )
    else
        dd("insertText is not string string")
    end
end

return M
