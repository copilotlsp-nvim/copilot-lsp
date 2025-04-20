local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set()

T["debounce"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.restart({ "-u", "scripts/minimal_init.lua" })
        end,
        post_once = child.stop,
    },
})
T["debounce"]["debounces calls to a function"] = function()
    child.lua([[
    _G.called = 0
    local fn = function()
        _G.called = _G.called + 1
    end

    local debounced_fn = require("copilot-lsp.util").debounce(fn, 250)
    debounced_fn()
    ]])

    local called = child.lua("return _G.called")
    eq(called, 0)

    vim.loop.sleep(200)
    called = child.lua("return _G.called")
    eq(called, 0)
    vim.loop.sleep(200)
    called = child.lua("return _G.called")
    eq(called, 1)
end
T["debounce"]["function is called with final calls params"] = function()
    child.lua([[
    _G.called = 0
    local fn = function(a)
        _G.called = a
    end

    local debounced_fn = require("copilot-lsp.util").debounce(fn, 500)
    debounced_fn(1)
    debounced_fn(2)
    debounced_fn(3)
    ]])

    local called = child.lua("return _G.called")
    eq(called, 0)

    vim.loop.sleep(200)
    called = child.lua("return _G.called")
    eq(called, 0)
    vim.loop.sleep(200)
    called = child.lua("return _G.called")
    eq(called, 0)
    vim.loop.sleep(200)
    called = child.lua("return _G.called")
    eq(called, 3)
end

return T
