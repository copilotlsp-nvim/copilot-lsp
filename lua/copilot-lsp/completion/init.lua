local M = {}
local comp_ui = require("copilot-lsp.completion.ui")

local function display_inline_completion()
    local bufnr = vim.api.nvim_get_current_buf()
    ---@type lsp.InlineCompletionList
    local inline_completion = vim.b[bufnr].copilot_inline_completion
    if not inline_completion or not inline_completion.items then
        return
    end

    local selected = vim.b[bufnr].copilot_inline_completion_selected or 1

    local completion = inline_completion.items[selected]
    if not completion then
        vim.b[bufnr].copilot_inline_completion_selected = 1
        display_inline_completion()
        return
    end
    comp_ui.draw_completion(completion)
end

---@param err lsp.ResponseError?
---@param result lsp.InlineCompletionList
---@param ctx lsp.HandlerContext
local function handle_inlineCompletion_response(err, result, ctx)
    if err then
        -- vim.notify(err.message)
        return
    end
    vim.b[vim.api.nvim_get_current_buf()].copilot_inline_completion = result
    local copilot_lsp = vim.lsp.get_client_by_id(ctx.client_id)
    if not copilot_lsp then
        return
    end
    display_inline_completion()
end

---@param type lsp.InlineCompletionTriggerKind
---@param client vim.lsp.Client?
function M.request_inline_completion(type, client)
    local bufnr = vim.api.nvim_get_current_buf()
    if vim.b[vim.api.nvim_get_current_buf()].copilot_inline_completion then
        vim.b[bufnr].copilot_inline_completion_selected = vim.b[bufnr].copilot_inline_completion_selected or 1
        display_inline_completion()
        return
    end
    assert(client, "Copilot LSP client not started")
    local params = vim.tbl_deep_extend("keep", vim.lsp.util.make_position_params(0, "utf-16"), {
        textDocument = vim.lsp.util.make_text_document_params(),
        position = vim.lsp.util.make_position_params(0, "utf-16"),
        context = {
            triggerKind = type,
        },
        formattingOptions = {
            --TODO: Grab this from editor also
            tabSize = 4,
            insertSpaces = true,
        },
    })
    client:request("textDocument/inlineCompletion", params, handle_inlineCompletion_response, 0)
end

function M.clear_inline_completion()
    local bufnr = vim.api.nvim_get_current_buf()
    if vim.b[bufnr].copilot_inline_completion then
        vim.b[bufnr].copilot_inline_completion = nil
    end
end

return M
