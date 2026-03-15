local errs = require("copilot-lsp.errors")
local nes_ui = require("copilot-lsp.nes.ui")
local utils = require("copilot-lsp.util")

local M = {}

nes_ui.set_stale_checker(function(bufnr)
    return M.clear_stale_active_nes(bufnr)
end)

local nes_ns = vim.api.nvim_create_namespace("copilotlsp.nes")

---@param bufnr integer
---@return integer
local function get_nes_ns(bufnr)
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        return nes_ns
    end

    return vim.b[bufnr].copilotlsp_nes_namespace_id or nes_ns
end

---@param state? copilotlsp.InlineEdit
---@return boolean
local function is_valid_nes(state)
    return state ~= nil
        and state.textDocument ~= nil
        and state.textDocument.uri ~= nil
        and state.range ~= nil
        and state.range.start ~= nil
        and state.range["end"] ~= nil
        and state.newText ~= nil
end

---@param bufnr integer
---@return integer?
local function get_buf_version(bufnr)
    return vim.lsp.util.buf_versions[bufnr]
end

---@param bufnr integer
---@return copilotlsp.InlineEdit?
local function get_last_nes(bufnr)
    return vim.b[bufnr].copilotlsp_nes_last_state
end

---@param bufnr integer
local function clear_last_nes(bufnr)
    vim.b[bufnr].copilotlsp_nes_last_state = nil
    vim.b[bufnr].copilotlsp_nes_last_version = nil
end

---@param bufnr integer
---@return integer?
local function get_nes_state_version(bufnr)
    return vim.b[bufnr].copilotlsp_nes_state_version
end

---@param bufnr integer
---@return integer?
local function get_nes_last_version(bufnr)
    return vim.b[bufnr].copilotlsp_nes_last_version
end

---@param bufnr integer
---@param state copilotlsp.InlineEdit
---@param request_version integer?
---@return boolean
local function is_stale_nes(bufnr, state, request_version)
    if not is_valid_nes(state) then
        return true
    end

    local current_version = get_buf_version(bufnr)

    if request_version == nil or current_version == nil then
        return true
    end

    return request_version ~= current_version
end

---@param bufnr? integer
---@return boolean --if a stale active NES was cleared
function M.clear_stale_active_nes(bufnr)
    bufnr = bufnr and bufnr > 0 and bufnr or vim.api.nvim_get_current_buf()

    if not vim.api.nvim_buf_is_valid(bufnr) then
        return false
    end

    local state = vim.b[bufnr].nes_state
    if not state then
        return false
    end

    if not is_stale_nes(bufnr, state, get_nes_state_version(bufnr)) then
        return false
    end

    vim.b[bufnr].nes_jump = false
    nes_ui.clear_suggestion(bufnr, get_nes_ns(bufnr), false)
    return true
end

---@param bufnr integer
local function clear_pending_nes(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    vim.b[bufnr].nes_jump = false
    nes_ui.clear_suggestion(bufnr, get_nes_ns(bufnr), false)
end

---@param err lsp.ResponseError?
---@param result copilotlsp.copilotInlineEditResponse
---@param ctx lsp.HandlerContext
---@param request_version integer?
local function handle_nes_response(request_version, err, result, ctx)
    if err then
        vim.notify("[copilot-lsp] " .. err.message)
        return
    end
    -- Validate buffer still exists before processing response
    if not vim.api.nvim_buf_is_valid(ctx.bufnr) then
        return
    end
    if request_version ~= get_buf_version(ctx.bufnr) then
        return
    end
    if not result or not result.edits or #result.edits == 0 then
        return
    end
    for _, edit in ipairs(result.edits) do
        --- Convert to textEdit fields
        edit.newText = edit.text
    end
    if nes_ui._display_next_suggestion(ctx.bufnr, get_nes_ns(ctx.bufnr), result.edits) then
        vim.b[ctx.bufnr].copilotlsp_nes_state_version = request_version
        local client = vim.lsp.get_client_by_id(ctx.client_id)
        assert(client, errs.ErrNotStarted)
        client:notify("textDocument/didShowInlineEdit", {
            item = {
                command = result.edits[1].command,
            },
        })
    end
end

--- Requests the NextEditSuggestion from the current cursor position
---@param copilot_lss? vim.lsp.Client|string
function M.request_nes(copilot_lss)
    local bufnr = vim.api.nvim_get_current_buf()
    if type(copilot_lss) == "string" then
        copilot_lss = vim.lsp.get_clients({ name = copilot_lss })[1]
    end
    assert(copilot_lss, errs.ErrNotStarted)
    if copilot_lss.attached_buffers[bufnr] then
        local version = get_buf_version(bufnr)
        local pos_params = vim.lsp.util.make_position_params(0, "utf-16")
        ---@diagnostic disable-next-line: inject-field
        pos_params.textDocument.version = version
        copilot_lss:request("textDocument/copilotInlineEdit", pos_params, function(err, result, ctx)
            handle_nes_response(version, err, result, ctx)
        end)
    end
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

    local total_lines = vim.api.nvim_buf_line_count(bufnr)
    local cursor_row, _ = unpack(vim.api.nvim_win_get_cursor(0))
    if state.range.start.line >= total_lines then
        -- If the start line is beyond the end of the buffer then we can't walk there
        -- if we are at the end of the buffer, we've walked as we can
        if cursor_row == total_lines then
            return false
        end
        -- if not, walk to the end of the buffer instead
        vim.lsp.util.show_document({
            uri = state.textDocument.uri,
            range = {
                start = { line = total_lines - 1, character = 0 },
                ["end"] = { line = total_lines - 1, character = 0 },
            },
        }, "utf-16", { focus = true })
        return true
    end
    if cursor_row - 1 ~= state.range.start.line then
        vim.b[bufnr].nes_jump = true
        -- Since we are async, we check to see if the buffer has changed
        if vim.api.nvim_get_current_buf() ~= vim.uri_to_bufnr(state.textDocument.uri) then
            return false
        end

        ---@type lsp.Location
        local jump_loc_before = {
            uri = state.textDocument.uri,
            range = {
                start = state.range["start"],
                ["end"] = state.range["start"],
            },
        }

        vim.schedule(function()
            if utils.is_named_buffer(state.textDocument.uri) then
                vim.lsp.util.show_document(jump_loc_before, "utf-16", { focus = true })
            else
                vim.api.nvim_win_set_cursor(0, { state.range.start.line + 1, state.range.start.character })
            end
        end)
        return true
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
        -- Since we are async, we check to see if the buffer has changed
        if vim.api.nvim_get_current_buf() ~= bufnr then
            return
        end

        if utils.is_named_buffer(state.textDocument.uri) then
            pcall(vim.lsp.util.show_document, jump_loc_after, "utf-16", { focus = true })
        else
            pcall(vim.api.nvim_win_set_cursor, 0, { state.range["end"].line + 1, state.range["end"].character })
        end
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
    if M.clear_stale_active_nes(bufnr) then
        return false
    end
    local active_version = get_nes_state_version(bufnr)
    vim.schedule(function()
        if is_stale_nes(bufnr, state, active_version) then
            clear_pending_nes(bufnr)
            return
        end
        utils.apply_inline_edit(state)
        vim.b[bufnr].nes_jump = false
        nes_ui.clear_suggestion(bufnr, get_nes_ns(bufnr), false)
    end)
    return true
end

--- Re-show the last dismissed NES suggestion for the buffer if it is still valid.
---@param bufnr? integer
---@return boolean --if the nes was restored
function M.restore_last_nes(bufnr)
    bufnr = bufnr and bufnr > 0 and bufnr or vim.api.nvim_get_current_buf()

    if not vim.api.nvim_buf_is_valid(bufnr) or vim.b[bufnr].nes_state then
        return false
    end

    local state = get_last_nes(bufnr)
    if not state then
        return false
    end

    local last_version = get_nes_last_version(bufnr)
    if is_stale_nes(bufnr, state, last_version) then
        clear_last_nes(bufnr)
        return false
    end

    local restored = nes_ui._display_next_suggestion(bufnr, get_nes_ns(bufnr), { vim.deepcopy(state) })
    if restored then
        vim.b[bufnr].copilotlsp_nes_state_version = last_version
    end
    return restored
end

---@param bufnr? integer
function M.clear_suggestion(bufnr)
    bufnr = bufnr and bufnr > 0 and bufnr or vim.api.nvim_get_current_buf()
    nes_ui.clear_suggestion(bufnr, get_nes_ns(bufnr))
end

--- Clear the current suggestion if it exists
---@return boolean -- true if a suggestion was cleared, false if no suggestion existed
function M.clear()
    local buf = vim.api.nvim_get_current_buf()
    if vim.b[buf].nes_state then
        nes_ui.clear_suggestion(buf, get_nes_ns(buf))
        return true
    end
    return false
end

---@param client vim.lsp.Client
---@param au integer
function M.lsp_on_init(client, au)
    --NOTE: NES Completions
    local debounced_request =
        require("copilot-lsp.util").debounce(require("copilot-lsp.nes").request_nes, vim.g.copilot_nes_debounce or 500)
    vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
        callback = function()
            debounced_request(client)
        end,
        group = au,
    })

    --NOTE: didFocus
    vim.api.nvim_create_autocmd("BufEnter", {
        callback = function()
            local td_params = vim.lsp.util.make_text_document_params()
            client:notify("textDocument/didFocus", {
                textDocument = {
                    uri = td_params.uri,
                },
            })
        end,
        group = au,
    })
end

return M
