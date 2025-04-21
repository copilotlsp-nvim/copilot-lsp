---@type table<string, lsp.Handler>
local M = {}

local methods = {
    signIn = "signIn",
    didChangeStatus = "didChangeStatus",
}

-- copy from copilot.lua
local function open_signin_popup(code, url)
    local lines = {
        " [Copilot-lsp] ",
        "",
        " First copy your one-time code: ",
        "   " .. code .. " ",
        " In your browser, visit: ",
        "   " .. url .. " ",
        "",
        " ...waiting, it might take a while and ",
        " this popup will auto close once done... ",
    }
    local height, width = #lines, math.max(unpack(vim.tbl_map(function(line)
        return #line
    end, lines)))

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[bufnr].buflisted = false
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].bufhidden = "wipe"
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    local winnr = vim.api.nvim_open_win(bufnr, true, {
        relative = "editor",
        style = "minimal",
        border = "single",
        row = (vim.o.lines - height) / 2,
        col = (vim.o.columns - width) / 2,
        height = height,
        width = width,
    })
    vim.wo[winnr].winhighlight = "Normal:Normal"
    vim.wo[winnr].winblend = 0

    return function()
        vim.api.nvim_win_close(winnr, true)
    end
end

local function copy_to_clipboard(s)
    vim.fn.setreg("+", s)
    vim.fn.setreg("*", s)
end

---@param res {command: lsp.Command, userCode: string, verificationUri: string}
M[methods.signIn] = function(err, res, ctx)
    if err then
        vim.notify("[copilot-lsp] failed to start signin flow: " .. vim.inspect(err), vim.log.levels.ERROR)
        return
    end

    local client = vim.lsp.get_client_by_id(ctx.client_id)
    if not client then
        return
    end

    vim.g.copilot_lsp_signin_pending = true

    local close_signin_popup = open_signin_popup(res.userCode, res.verificationUri)
    copy_to_clipboard(res.userCode)

    client:exec_cmd(
        res.command,
        { bufnr = ctx.bufnr },

        ---@param cmd_res {status: string, user: string}
        function(cmd_err, cmd_res)
            vim.g.copilot_lsp_signin_pending = nil
            close_signin_popup()

            if cmd_err then
                vim.notify("[copilot-lsp] failed to open browser: " .. vim.inspect(cmd_err), vim.log.levels.WARN)
                return
            end
            if cmd_res.status == "OK" then
                vim.notify("[copilot-lsp] successfully signed in as: " .. cmd_res.user, vim.log.levels.INFO)
            else
                vim.notify("[copilot-lsp] failed to sign in: " .. vim.inspect(cmd_res), vim.log.levels.ERROR)
            end
        end
    )
end

---@param client_id integer
---@param bufnr integer
local function sign_in(client_id, bufnr)
    if vim.g.copilot_lsp_signin_pending then
        return
    end

    local client = vim.lsp.get_client_by_id(client_id)
    if not client then
        return
    end

    for _, req in pairs(client.requests) do
        if req.method == methods.signIn and req.type == "pending" then
            return
        end
    end

    client:request(methods.signIn, vim.empty_dict(), nil, bufnr)
end

---@param res {busy: boolean, kind: 'Normal'|'Error'|'Warning'|'Incative', message: string}
M["didChangeStatus"] = function(err, res, ctx)
    if err then
        return
    end
    -- real error message: You are not signed into GitHub. Please sign in to use Copilot.
    if res.kind == "Error" and res.message:find("not signed into") then
        sign_in(ctx.client_id, ctx.bufnr)
    end
end

return M
