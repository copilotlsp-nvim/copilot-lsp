local M = {}

---@param _results table<integer, { err: lsp.ResponseError, result: lsp.InlineCompletionList}>
---@param _ctx lsp.HandlerContext
---@param _config table
local function handle_inlineCompletion_response(_results, _ctx, _config)
    -- -- Filter errors from results
    -- local results1 = {} --- @type table<integer,lsp.InlineCompletionList>
    --
    -- for client_id, resp in pairs(results) do
    --     local err, result = resp.err, resp.result
    --     if err then
    --         vim.lsp.log.error(err.code, err.message)
    --     elseif result then
    --         results1[client_id] = result
    --     end
    -- end
    --
    -- for _, result in pairs(results1) do
    --     --TODO: Ghost text for completions
    --     -- This is where we show the completion results
    --     -- However, the LSP being named "copilot_ls" is enough for blink-cmp to show the completion
    -- end
end

---@param type lsp.InlineCompletionTriggerKind
function M.request_inline_completion(type)
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
    vim.lsp.buf_request_all(0, "textDocument/inlineCompletion", params, handle_inlineCompletion_response)
end
return M
