local errs = require("copilot-lsp.errors")
local nes_ui = require("copilot-lsp.nes.ui")
local utils = require("copilot-lsp.util")

local M = {}

local nes_ns = vim.api.nvim_create_namespace("copilot-nes")

---@param err lsp.ResponseError?
---@param result copilotlsp.copilotInlineEditResponse
local function handle_nes_response(err, result)
    if err then
        -- vim.notify(err.message)
        return
    end
    for _, edit in ipairs(result.edits) do
        --- Convert to textEdit fields
        edit.newText = edit.text
    end
    nes_ui._display_next_suggestion(result.edits, nes_ns)
end

---@param copilot_lss vim.lsp.Client?
function M.request_nes(copilot_lss)
    local pos_params = vim.lsp.util.make_position_params(0, "utf-16")
    local version = vim.lsp.util.buf_versions[vim.api.nvim_get_current_buf()]
    assert(copilot_lss, errs.ErrNotStarted)
    ---@diagnostic disable-next-line: inject-field
    pos_params.textDocument.version = version
    copilot_lss:request("textDocument/copilotInlineEdit", pos_params, handle_nes_response)
end

---@param bufnr? integer
function M.apply_pending_nes(bufnr)
    bufnr = bufnr and bufnr > 0 and bufnr or vim.api.nvim_get_current_buf()

    ---@type copilotlsp.InlineEdit
    local state = vim.b[bufnr].nes_state
    if not state then
        return
    end
    ---@type lsp.Location
    local jump_loc = {
        uri = state.textDocument.uri,
        range = {
            start = state.range["end"],
            ["end"] = state.range["end"],
        },
    }
    vim.lsp.util.show_document(jump_loc, "utf-16", { focus = true })
    utils.apply_inline_edit(state)
    nes_ui.clear_suggestion(bufnr, nes_ns)
end

return M
