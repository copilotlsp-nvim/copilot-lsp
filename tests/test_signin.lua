local eq = MiniTest.expect.equality
local ref = MiniTest.expect.reference_screenshot

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set()
T["signin"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.restart({ "-u", "scripts/minimal_init.lua" })
            child.lua_func(function()
                vim.lsp.config("copilot_ls", {
                    cmd = require("tests.mock_lsp").server,
                })
                vim.lsp.enable("copilot_ls")
            end)
        end,
        post_once = child.stop,
    },
})

T["signin"]["shows modal"] = function()
    child.cmd("edit tests/fixtures/signin.txt")
    ref(child.get_screenshot())
    vim.uv.sleep(500)
    local lsp_name = child.lua_func(function()
        return vim.lsp.get_clients()[1].name
    end)
    eq(lsp_name, "copilot_ls")
    child.lua_func(function()
        local copilot = vim.lsp.get_clients()[1]
        copilot.handlers["signIn"](nil, {
            userCode = "ABCD-EFGH",
            verificationUri = "https://example.com",
            command = {
                command = "github.copilot.finishDeviceFlow",
                arguments = {},
                title = "Sign in",
            },
        }, { client_id = copilot.id, method = "signIn" })
    end)
    ref(child.get_screenshot())
end

return T
