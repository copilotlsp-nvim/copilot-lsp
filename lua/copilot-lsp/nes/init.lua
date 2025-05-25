local errs = require("copilot-lsp.errors")
local nes_ui = require("copilot-lsp.nes.ui")
local utils = require("copilot-lsp.util")
local me = require("copilot-lsp.mimimal_edits")

local M = {}

local nes_ns = vim.api.nvim_create_namespace("copilotlsp.nes")

---@param err lsp.ResponseError?
---@param result copilotlsp.copilotInlineEditResponse
---@param ctx lsp.HandlerContext
local function handle_nes_response(err, result, ctx)
    if err then
        -- vim.notify(err.message)
        return
    end
    for _, edit in ipairs(result.edits) do
        --- Convert to textEdit fields
        edit.newText = edit.text
    end
    if #result.edits == 1 then
        ---@type copilotlsp.InlineEdit[]
        local min_edits = {}

        -- minimise the edits
        local source_lines = vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        local min_te = me.compute_minimal_edits(source_lines, result.edits[1])
        for _, edit in ipairs(min_te) do
            local new_edit = {
                range = edit.range,
                newText = edit.newText,
                command = result.edits[1].command,
                textDocument = result.edits[1].textDocument,
            }
            table.insert(min_edits, new_edit)
        end

        result.edits = min_edits
    end
    nes_ui._display_next_suggestion(ctx.bufnr, nes_ns, result.edits)
end

--- Requests the NextEditSuggestion from the current cursor position
---@param copilot_lss? vim.lsp.Client|string
function M.request_nes(copilot_lss)
    local pos_params = vim.lsp.util.make_position_params(0, "utf-16")
    local version = vim.lsp.util.buf_versions[vim.api.nvim_get_current_buf()]
    if type(copilot_lss) == "string" then
        copilot_lss = vim.lsp.get_clients({ name = copilot_lss })[1]
    end
    assert(copilot_lss, errs.ErrNotStarted)
    ---@diagnostic disable-next-line: inject-field
    pos_params.textDocument.version = version
    copilot_lss:request("textDocument/copilotInlineEdit", pos_params, handle_nes_response)
end

--- Walks the cursor to the start of the edit.
--- This function returns false if there is no edit to apply or if the cursor is already at the start position of the
--- edit.
---@param bufnr? integer
---@return boolean --if the cursor walked
function M.walk_cursor_start_edit(bufnr)
    bufnr = bufnr and bufnr > 0 and bufnr or vim.api.nvim_get_current_buf()
    ---@type copilotlsp.InlineEdit
    local state = vim.b[bufnr].nes_state
    if not state then
        return false
    end

    local cursor_row, _ = unpack(vim.api.nvim_win_get_cursor(0))
    if cursor_row - 1 ~= state.range.start.line then
        vim.b[bufnr].nes_jump = true
        ---@type lsp.Location
        local jump_loc_before = {
            uri = state.textDocument.uri,
            range = {
                start = state.range["start"],
                ["end"] = state.range["start"],
            },
        }
        return vim.lsp.util.show_document(jump_loc_before, "utf-16", { focus = true })
    else
        return false
    end
end

--- Walks the cursor to the end of the edit.
--- This function returns false if there is no edit to apply or if the cursor is already at the end position of the
--- edit
---@param bufnr? integer
---@return boolean --if the cursor walked
function M.walk_cursor_end_edit(bufnr)
    bufnr = bufnr and bufnr > 0 and bufnr or vim.api.nvim_get_current_buf()
    ---@type copilotlsp.InlineEdit
    local state = vim.b[bufnr].nes_state
    if not state then
        return false
    end

    ---@type lsp.Location
    local jump_loc_after = {
        uri = state.textDocument.uri,
        range = {
            start = state.range["end"],
            ["end"] = state.range["end"],
        },
    }
    --NOTE: If last line is deletion, then this may be outside of the buffer
    vim.schedule(function()
        pcall(vim.lsp.util.show_document, jump_loc_after, "utf-16", { focus = true })
    end)
    return true
end

--- This function applies the pending nes edit to the current buffer and then clears the marks for the pending
--- suggestion
---@param bufnr? integer
---@return boolean --if the nes was applied
function M.apply_pending_nes(bufnr)
    bufnr = bufnr and bufnr > 0 and bufnr or vim.api.nvim_get_current_buf()

    ---@type copilotlsp.InlineEdit
    local state = vim.b[bufnr].nes_state
    if not state then
        return false
    end
    vim.schedule(function()
        utils.apply_inline_edit(state)
        vim.b[bufnr].nes_jump = false
        nes_ui.clear_suggestion(bufnr, nes_ns)
    end)
    return true
end

---@param bufnr? integer
function M.clear_suggestion(bufnr)
    bufnr = bufnr and bufnr > 0 and bufnr or vim.api.nvim_get_current_buf()
    nes_ui.clear_suggestion(bufnr, nes_ns)
end

return M
