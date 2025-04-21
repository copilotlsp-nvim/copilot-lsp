local M = {}

M.messages = {}

---@param td lsp.VersionedTextDocumentIdentifier
---@return copilotlsp.copilotInlineEditResponse
local function getNesResponse(td)
    local filename = vim.fs.basename(vim.uri_to_fname(td.uri))
    ---@type table<string, copilotlsp.copilotInlineEditResponse>
    local responses = {
        ["sameline_edit.txt"] = {
            edits = {
                {
                    command = { title = "mock", command = "mock" },
                    range = {
                        start = { line = 0, character = 0 },
                        ["end"] = { line = 0, character = 3 },
                    },
                    textDocument = td,
                    text = "xyz",
                    ---@diagnostic disable-next-line: assign-type-mismatch
                    newText = nil,
                },
            },
        },
        ["multiline_edit.txt"] = {
            edits = {
                {
                    command = { title = "mock", command = "mock" },
                    range = {
                        start = { line = 0, character = 0 },
                        ["end"] = { line = 1, character = 8 },
                    },
                    textDocument = td,
                    text = "new line one\nnew line two",
                    ---@diagnostic disable-next-line: assign-type-mismatch
                    newText = nil,
                },
            },
        },
        ["removal_edit.txt"] = {
            edits = {
                {
                    command = { title = "mock", command = "mock" },
                    range = {
                        start = { line = 0, character = 7 },
                        ["end"] = { line = 1, character = 8 },
                    },
                    textDocument = td,
                    text = "",
                    ---@diagnostic disable-next-line: assign-type-mismatch
                    newText = nil,
                },
            },
        },
    }
    local response = responses[filename]
    assert(response, "unhandled doc")
    return response
end

function M.server()
    local closing = false
    local srv = {}

    function srv.request(method, params, handler)
        table.insert(M.messages, { method = method, params = params })
        if method == "initialize" then
            handler(nil, {
                capabilities = {},
            })
        elseif method == "shutdown" then
            handler(nil, nil)
        elseif method == "textDocument/copilotInlineEdit" then
            local response = getNesResponse(params.textDocument)
            handler(nil, response)
        else
            assert(false, "Unhandled method: " .. method)
        end
    end

    function srv.notify(method, params)
        table.insert(M.messages, { method = method, params = params })
        if method == "exit" then
            closing = true
        elseif method == "fakesignin" then
            --
        end
    end

    function srv.is_closing()
        return closing
    end

    function srv.terminate()
        closing = true
    end

    return srv
end

function M.Reset()
    M.messages = {}
end

return M
