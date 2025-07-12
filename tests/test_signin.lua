local ref = function(screenshot)
    -- ignore the last, 24th line on the screen as it has differing `screenattr` values between stable and nightly
    MiniTest.expect.reference_screenshot(screenshot, nil, { ignore_attr = { 24 } })
end

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
