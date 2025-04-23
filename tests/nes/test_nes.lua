local eq = MiniTest.expect.equality
local ref = MiniTest.expect.reference_screenshot

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set()
T["nes"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.restart({ "-u", "scripts/minimal_init.lua" })
            child.lua_func(function()
                vim.g.copilot_nes_debounce = 450
                vim.lsp.config("copilot", {
                    cmd = require("tests.mock_lsp").server,
                })
                vim.lsp.enable("copilot")
            end)
        end,
        post_once = child.stop,
    },
})

T["nes"]["same line edit"] = function()
    child.cmd("edit tests/fixtures/sameline_edit.txt")
    ref(child.get_screenshot())
    vim.uv.sleep(500)
    local lsp_name = child.lua_func(function()
        return vim.lsp.get_clients()[1].name
    end)
    eq(lsp_name, "copilot")
    child.lua_func(function()
        local copilot = vim.lsp.get_clients()[1]
        require("copilot-lsp.nes").request_nes(copilot)
    end)
    vim.uv.sleep(500)
    ref(child.get_screenshot())
    child.lua_func(function()
        require("copilot-lsp.nes").apply_pending_nes(0)
    end)
    ref(child.get_screenshot())
end

T["nes"]["multi line edit"] = function()
    child.cmd("edit tests/fixtures/multiline_edit.txt")
    ref(child.get_screenshot())
    vim.uv.sleep(500)
    local lsp_name = child.lua_func(function()
        return vim.lsp.get_clients()[1].name
    end)
    eq(lsp_name, "copilot")
    child.lua_func(function()
        local copilot = vim.lsp.get_clients()[1]
        require("copilot-lsp.nes").request_nes(copilot)
    end)
    vim.uv.sleep(500)
    ref(child.get_screenshot())
    child.lua_func(function()
        require("copilot-lsp.nes").apply_pending_nes(0)
    end)
    ref(child.get_screenshot())
end

T["nes"]["removal edit"] = function()
    child.cmd("edit tests/fixtures/removal_edit.txt")
    ref(child.get_screenshot())
    vim.uv.sleep(500)
    local lsp_name = child.lua_func(function()
        return vim.lsp.get_clients()[1].name
    end)
    eq(lsp_name, "copilot")
    child.lua_func(function()
        local copilot = vim.lsp.get_clients()[1]
        require("copilot-lsp.nes").request_nes(copilot)
    end)
    vim.uv.sleep(500)
    ref(child.get_screenshot())
    child.lua_func(function()
        require("copilot-lsp.nes").apply_pending_nes(0)
    end)
    ref(child.get_screenshot())
end

T["nes"]["add only edit"] = function()
    child.cmd("edit tests/fixtures/addonly_edit.txt")
    ref(child.get_screenshot())
    vim.uv.sleep(500)
    local lsp_name = child.lua_func(function()
        return vim.lsp.get_clients()[1].name
    end)
    eq(lsp_name, "copilot")
    child.lua_func(function()
        local copilot = vim.lsp.get_clients()[1]
        require("copilot-lsp.nes").request_nes(copilot)
    end)
    vim.uv.sleep(500)
    ref(child.get_screenshot())
    child.lua_func(function()
        require("copilot-lsp.nes").apply_pending_nes(0)
    end)
    ref(child.get_screenshot())
end

T["nes"]["highlights replacement"] = function()
    child.cmd("edit tests/fixtures/highlight_test.c")
    child.lua_func(function()
        vim.cmd([[colorscheme vim]])
        vim.treesitter.start(0)
        vim.cmd([[hi! NesAdd guifg=NONE guibg=NONE]])
        vim.cmd([[hi! NesDelete guifg=NONE guibg=NONE]])
    end)
    ref(child.get_screenshot())
    vim.uv.sleep(500)
    local lsp_name = child.lua_func(function()
        return vim.lsp.get_clients()[1].name
    end)
    eq(lsp_name, "copilot")
    child.lua_func(function()
        local copilot = vim.lsp.get_clients()[1]
        require("copilot-lsp.nes").request_nes(copilot)
    end)
    vim.uv.sleep(500)
    ref(child.get_screenshot())
    child.lua_func(function()
        require("copilot-lsp.nes").apply_pending_nes(0)
    end)
    ref(child.get_screenshot())
end
return T
