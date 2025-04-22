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
                        start = { line = 1, character = 0 },
                        ["end"] = { line = 2, character = 0 },
                    },
                    textDocument = td,
                    text = "",
                    ---@diagnostic disable-next-line: assign-type-mismatch
                    newText = nil,
                },
            },
        },
        ["addonly_edit.txt"] = {
            edits = {
                {
                    command = { title = "mock", command = "mock" },
                    range = {
                        start = { line = 2, character = 0 },
                        ["end"] = { line = 2, character = 0 },
                    },
                    textDocument = td,
                    text = "line 3\n",
                    ---@diagnostic disable-next-line: assign-type-mismatch
                    newText = nil,
                },
            },
        },
        ["highlight_test.c"] = {
            edits = {
                {
                    command = { title = "mock", command = "mock" },
                    range = {
                        start = { line = 4, character = 0 },
                        ["end"] = { line = 4, character = 30 },
                    },
                    textDocument = td,
                    text = [[  printf("Goodb, %s!\n", name);]],
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
    local seen_files = {}

    function srv.request(method, params, handler)
        table.insert(M.messages, { method = method, params = params })
        if method == "initialize" then
            handler(nil, {
                capabilities = {},
            })
        elseif method == "shutdown" then
            handler(nil, nil)
        elseif method == "textDocument/copilotInlineEdit" then
            if not seen_files[params.textDocument.uri] then
                seen_files[params.textDocument.uri] = true
                local response = getNesResponse(params.textDocument)
                handler(nil, response)
                return
            end
            ---@type copilotlsp.copilotInlineEditResponse
            local empty_response = {
                edits = {},
            }
            handler(nil, empty_response)
        else
            assert(false, "Unhandled method: " .. method)
        end
    end

    function srv.notify(method, params)
        table.insert(M.messages, { method = method, params = params })
        if method == "exit" then
            closing = true
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
