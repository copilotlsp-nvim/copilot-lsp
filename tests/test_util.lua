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
    child.lua_func(function()
        _G.called = 0
        local fn = function()
            _G.called = _G.called + 1
        end

        local debounced_fn = require("copilot-lsp.util").debounce(fn, 450)
        debounced_fn()
    end)

    local called = child.lua_func(function()
        return _G.called
    end)
    eq(called, 0)

    vim.uv.sleep(100)
    called = child.lua_func(function()
        return _G.called
    end)
    eq(called, 0)
    vim.uv.sleep(500)
    called = child.lua_func(function()
        return _G.called
    end)
    eq(called, 1)
end
T["debounce"]["function is called with final calls params"] = function()
    child.lua_func(function()
        _G.called = 0
        local fn = function(a)
            _G.called = a
        end

        local debounced_fn = require("copilot-lsp.util").debounce(fn, 450)
        debounced_fn(1)
        debounced_fn(2)
        debounced_fn(3)
    end)

    local called = child.lua("return _G.called")
    eq(called, 0)

    vim.uv.sleep(100)
    called = child.lua("return _G.called")
    eq(called, 0)
    vim.uv.sleep(100)
    called = child.lua("return _G.called")
    eq(called, 0)
    vim.uv.sleep(500)
    called = child.lua("return _G.called")
    eq(called, 3)
end
T["debounce"]["function is only called once"] = function()
    child.lua_func(function()
        _G.called = {}
        local fn = function(a)
            table.insert(_G.called, a)
        end

        _G.debounced_fn = require("copilot-lsp.util").debounce(fn, 200)
    end)

    child.lua_func(function()
        _G.debounced_fn(0)
        _G.debounced_fn(1)
        _G.debounced_fn(2)
        _G.debounced_fn(3)
        _G.debounced_fn(4)
    end)

    local called = child.lua_func(function()
        return _G.called
    end)
    eq(#called, 0)

    vim.uv.sleep(500)

    called = child.lua_func(function()
        return _G.called
    end)
    eq(#called, 1)

    child.lua_func(function()
        _G.debounced_fn(5)
        _G.debounced_fn(6)
        _G.debounced_fn(7)
        _G.debounced_fn(8)
        _G.debounced_fn(9)
    end)

    vim.uv.sleep(500)

    called = child.lua_func(function()
        return _G.called
    end)
    eq(#called, 2)

    eq(called, { 4, 9 })
end

return T
