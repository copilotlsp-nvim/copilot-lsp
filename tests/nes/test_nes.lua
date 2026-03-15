local eq = MiniTest.expect.equality
local ref = function(screenshot)
    -- ignore the last, 24th line on the screen as it has differing `screenattr` values between stable and nightly
    MiniTest.expect.reference_screenshot(screenshot, nil, { ignore_attr = { 24 } })
end

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set()
T["nes"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.restart({ "-u", "scripts/minimal_init.lua" })
            child.lua_func(function()
                vim.g.copilot_nes_debounce = 450
                vim.lsp.config("copilot_ls", {
                    cmd = require("tests.mock_lsp").server,
                })
                vim.lsp.enable("copilot_ls")
            end)
        end,
        post_once = child.stop,
    },
})

local function request_nes()
    child.lua_func(function()
        local copilot = vim.lsp.get_clients()[1]
        require("copilot-lsp.nes").request_nes(copilot)
    end)
    vim.uv.sleep(500)
end

local function get_content()
    return table.concat(child.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
end

local function clear_nes()
    return child.lua_func(function()
        return require("copilot-lsp.nes").clear()
    end)
end

local function restore_last_nes()
    return child.lua_func(function()
        return require("copilot-lsp.nes").restore_last_nes()
    end)
end

local function change_current_buffer_line(new_line)
    child.lua_func(function(line)
        vim.api.nvim_buf_set_lines(0, 0, 1, false, { line })
    end, new_line)
end

local function wait_for_active_nes(bufnr, should_exist)
    return child.lua_func(function(target_bufnr, expected)
        vim.wait(1000, function()
            local has_state = vim.b[target_bufnr].nes_state ~= nil
            return has_state == expected
        end)

        return vim.b[target_bufnr].nes_state ~= nil
    end, bufnr or child.api.nvim_get_current_buf(), should_exist)
end

T["nes"]["lsp starts"] = function()
    child.cmd("edit tests/fixtures/sameline_edit.txt")
    local lsp_count = child.lua_func(function()
        local count = 0
        local clients = vim.lsp.get_clients()
        for _, _ in pairs(clients) do
            --NOTE: #clients doesn't work, so we count in the loop
            count = count + 1
        end
        return count
    end)
    eq(lsp_count, 1)
end

T["nes"]["restore_last_nes returns false without saved suggestion"] = function()
    child.cmd("edit tests/fixtures/sameline_edit.txt")

    local result = child.lua_func(function()
        local bufnr = vim.api.nvim_get_current_buf()
        return {
            restored = require("copilot-lsp.nes").restore_last_nes(),
            active = vim.b[bufnr].nes_state ~= nil,
            saved = vim.b[bufnr].copilotlsp_nes_last_state ~= nil,
        }
    end)
    eq(result.restored, false)
    eq(result.active, false)
    eq(result.saved, false)
end

T["nes"]["clear saves last dismissed suggestion"] = function()
    child.cmd("edit tests/fixtures/sameline_edit.txt")
    request_nes()

    local result = child.lua_func(function()
        local bufnr = vim.api.nvim_get_current_buf()
        local state = vim.deepcopy(vim.b[bufnr].nes_state)
        return {
            cleared = require("copilot-lsp.nes").clear(),
            active = vim.b[bufnr].nes_state ~= nil,
            saved = vim.b[bufnr].copilotlsp_nes_last_state ~= nil,
            matches = vim.deep_equal(vim.b[bufnr].copilotlsp_nes_last_state, state),
        }
    end)
    eq(result.cleared, true)
    eq(result.active, false)
    eq(result.saved, true)
    eq(result.matches, true)
end

T["nes"]["restore_last_nes restores dismissed suggestion"] = function()
    child.cmd("edit tests/fixtures/sameline_edit.txt")
    request_nes()
    clear_nes()

    local result = child.lua_func(function()
        local bufnr = vim.api.nvim_get_current_buf()
        local saved = vim.deepcopy(vim.b[bufnr].copilotlsp_nes_last_state)
        return {
            restored = require("copilot-lsp.nes").restore_last_nes(),
            active = vim.b[bufnr].nes_state ~= nil,
            matches = vim.deep_equal(vim.b[bufnr].nes_state, saved),
            second = require("copilot-lsp.nes").restore_last_nes(),
        }
    end)
    eq(result.restored, true)
    eq(result.active, true)
    eq(result.matches, true)
    eq(result.second, false)
end

T["nes"]["apply_pending_nes applies matching version"] = function()
    child.cmd("edit tests/fixtures/sameline_edit.txt")
    request_nes()

    local versions = child.lua_func(function()
        local bufnr = vim.api.nvim_get_current_buf()
        return {
            current = vim.lsp.util.buf_versions[bufnr],
            request = vim.b[bufnr].copilotlsp_nes_state_version,
        }
    end)
    eq(versions.request, versions.current)

    local applied = child.lua_func(function()
        return require("copilot-lsp.nes").apply_pending_nes()
    end)
    eq(applied, true)

    vim.uv.sleep(100)

    eq(get_content(), "xyz\nbbb\nccc")
end

T["nes"]["active NES clears on text change"] = function()
    child.cmd("edit tests/fixtures/sameline_edit.txt")
    request_nes()

    local bufnr = child.api.nvim_get_current_buf()
    change_current_buffer_line("Line one")
    eq(wait_for_active_nes(bufnr, false), false)

    local result = child.lua_func(function()
        local bufnr = vim.api.nvim_get_current_buf()
        return {
            active = vim.b[bufnr].nes_state ~= nil,
            saved = vim.b[bufnr].copilotlsp_nes_last_state ~= nil,
            version = vim.b[bufnr].copilotlsp_nes_state_version,
        }
    end)
    eq(result.active, false)
    eq(result.saved, false)
    eq(result.version, nil)
    eq(get_content(), "Line one\nbbb\nccc")
end

T["nes"]["stale-cleared NES is not restorable"] = function()
    child.cmd("edit tests/fixtures/sameline_edit.txt")
    request_nes()

    local bufnr = child.api.nvim_get_current_buf()
    change_current_buffer_line("Line one")
    eq(wait_for_active_nes(bufnr, false), false)

    local result = child.lua_func(function()
        local bufnr = vim.api.nvim_get_current_buf()
        return {
            restored = require("copilot-lsp.nes").restore_last_nes(),
            active = vim.b[bufnr].nes_state ~= nil,
            saved = vim.b[bufnr].copilotlsp_nes_last_state ~= nil,
        }
    end)
    eq(result.restored, false)
    eq(result.active, false)
    eq(result.saved, false)
    eq(get_content(), "Line one\nbbb\nccc")
end

T["nes"]["restore_last_nes restored suggestion applies"] = function()
    child.cmd("edit tests/fixtures/sameline_edit.txt")
    request_nes()
    clear_nes()

    local restored = restore_last_nes()
    eq(restored, true)

    local applied = child.lua_func(function()
        return require("copilot-lsp.nes").apply_pending_nes()
    end)
    eq(applied, true)

    vim.uv.sleep(100)

    eq(get_content(), "xyz\nbbb\nccc")
end

T["nes"]["restore_last_nes rejects stale saved suggestion"] = function()
    child.cmd("edit tests/fixtures/sameline_edit.txt")
    request_nes()
    clear_nes()

    child.lua_func(function()
        vim.api.nvim_buf_set_lines(0, 0, 1, false, { "Line one" })
    end)

    local result = child.lua_func(function()
        local bufnr = vim.api.nvim_get_current_buf()
        return {
            restored = require("copilot-lsp.nes").restore_last_nes(),
            applied = require("copilot-lsp.nes").apply_pending_nes(),
            active = vim.b[bufnr].nes_state ~= nil,
            saved = vim.b[bufnr].copilotlsp_nes_last_state ~= nil,
        }
    end)
    eq(result.restored, false)
    eq(result.applied, false)
    eq(result.active, false)
    eq(result.saved, false)
    eq(get_content(), "Line one\nbbb\nccc")
end

T["nes"]["text-change stale clear is scoped per buffer"] = function()
    child.cmd("edit tests/fixtures/sameline_edit.txt")
    request_nes()
    child.lua_func(function()
        vim.g.copilotlsp_first_nes_bufnr = vim.api.nvim_get_current_buf()
    end)

    child.cmd("edit tests/fixtures/multiline_edit.txt")
    request_nes()

    local result = child.lua_func(function()
        local first_bufnr = vim.g.copilotlsp_first_nes_bufnr
        local second_bufnr = vim.api.nvim_get_current_buf()

        vim.api.nvim_buf_set_lines(second_bufnr, 0, 1, false, { "changed line" })
        vim.wait(1000, function()
            return vim.b[second_bufnr].nes_state == nil
        end)

        return {
            first_active = vim.b[first_bufnr].nes_state ~= nil,
            second_active = vim.b[second_bufnr].nes_state ~= nil,
        }
    end)

    eq(result.first_active, true)
    eq(result.second_active, false)
end

T["nes"]["restore_last_nes is scoped per buffer"] = function()
    child.cmd("edit tests/fixtures/sameline_edit.txt")
    request_nes()
    clear_nes()

    child.cmd("edit tests/fixtures/multiline_edit.txt")

    local other_result = child.lua_func(function()
        local bufnr = vim.api.nvim_get_current_buf()
        return {
            restored = require("copilot-lsp.nes").restore_last_nes(),
            saved = vim.b[bufnr].copilotlsp_nes_last_state ~= nil,
        }
    end)
    eq(other_result.restored, false)
    eq(other_result.saved, false)

    child.cmd("edit tests/fixtures/sameline_edit.txt")

    local restored = restore_last_nes()
    eq(restored, true)
end

T["nes"]["same line edit"] = function()
    child.cmd("edit tests/fixtures/sameline_edit.txt")
    ref(child.get_screenshot())
    vim.uv.sleep(500)
    child.lua_func(function()
        local copilot = vim.lsp.get_clients()[1]
        require("copilot-lsp.nes").request_nes(copilot)
    end)
    vim.uv.sleep(500)
    ref(child.get_screenshot())
    child.lua_func(function()
        local _ = require("copilot-lsp.nes").apply_pending_nes() and require("copilot-lsp.nes").walk_cursor_end_edit()
    end)
    ref(child.get_screenshot())
end

T["nes"]["multi line edit"] = function()
    child.cmd("edit tests/fixtures/multiline_edit.txt")
    ref(child.get_screenshot())
    vim.uv.sleep(500)
    child.lua_func(function()
        local copilot = vim.lsp.get_clients()[1]
        require("copilot-lsp.nes").request_nes(copilot)
    end)
    vim.uv.sleep(500)
    ref(child.get_screenshot())
    child.lua_func(function()
        local _ = require("copilot-lsp.nes").apply_pending_nes() and require("copilot-lsp.nes").walk_cursor_end_edit()
    end)
    ref(child.get_screenshot())
end

T["nes"]["removal edit"] = function()
    child.cmd("edit tests/fixtures/removal_edit.txt")
    ref(child.get_screenshot())
    vim.uv.sleep(500)
    child.lua_func(function()
        local copilot = vim.lsp.get_clients()[1]
        require("copilot-lsp.nes").request_nes(copilot)
    end)
    vim.uv.sleep(500)
    ref(child.get_screenshot())
    child.lua_func(function()
        require("copilot-lsp.nes").walk_cursor_start_edit()
    end)
    ref(child.get_screenshot())
    child.lua_func(function()
        local _ = require("copilot-lsp.nes").apply_pending_nes() and require("copilot-lsp.nes").walk_cursor_end_edit()
    end)
    ref(child.get_screenshot())
end

T["nes"]["add only edit"] = function()
    child.cmd("edit tests/fixtures/addonly_edit.txt")
    ref(child.get_screenshot())
    vim.uv.sleep(500)
    child.lua_func(function()
        local copilot = vim.lsp.get_clients()[1]
        require("copilot-lsp.nes").request_nes(copilot)
    end)
    vim.uv.sleep(500)
    ref(child.get_screenshot())
    child.lua_func(function()
        require("copilot-lsp.nes").walk_cursor_start_edit()
    end)
    vim.uv.sleep(100)
    ref(child.get_screenshot())
    child.lua_func(function()
        local _ = require("copilot-lsp.nes").apply_pending_nes() and require("copilot-lsp.nes").walk_cursor_end_edit()
    end)
    ref(child.get_screenshot())
end

T["nes"]["highlights replacement"] = function()
    child.cmd("edit tests/fixtures/highlight_test.c")
    child.lua_func(function()
        vim.cmd([[colorscheme vim]])
        vim.treesitter.start(0)
        vim.cmd([[hi! CopilotLspNesAdd guifg=NONE guibg=NONE]])
        vim.cmd([[hi! CopilotLspNesDelete guifg=NONE guibg=NONE]])
    end)
    ref(child.get_screenshot())
    vim.uv.sleep(500)
    child.lua_func(function()
        local copilot = vim.lsp.get_clients()[1]
        require("copilot-lsp.nes").request_nes(copilot)
    end)
    vim.uv.sleep(500)
    ref(child.get_screenshot())
    child.lua_func(function()
        local _ = require("copilot-lsp.nes").apply_pending_nes() and require("copilot-lsp.nes").walk_cursor_end_edit()
    end)
    ref(child.get_screenshot())
end

T["nes"]["apply_pending_nes on empty buffer"] = function()
    child.lua_func(function()
        local copilot = vim.lsp.get_clients()[1]
        require("copilot-lsp.nes").request_nes(copilot)
    end)
    vim.uv.sleep(500)
    child.lua_func(function()
        local _ = require("copilot-lsp.nes").apply_pending_nes()
    end)
    vim.uv.sleep(500)
    ref(child.get_screenshot())
end

T["nes"]["walk_cursor_end_edit on empty buffer"] = function()
    child.lua_func(function()
        local copilot = vim.lsp.get_clients()[1]
        require("copilot-lsp.nes").request_nes(copilot)
    end)
    vim.uv.sleep(500)
    child.lua_func(function()
        local _ = require("copilot-lsp.nes").apply_pending_nes() and require("copilot-lsp.nes").walk_cursor_end_edit()
    end)
    vim.uv.sleep(500)
    ref(child.get_screenshot())
end

T["nes"]["walk_cursor_start_edit on empty buffer"] = function()
    child.lua_func(function()
        local copilot = vim.lsp.get_clients()[1]
        require("copilot-lsp.nes").request_nes(copilot)
    end)
    vim.uv.sleep(500)
    child.lua_func(function()
        local _ = require("copilot-lsp.nes").apply_pending_nes() and require("copilot-lsp.nes").walk_cursor_start_edit()
    end)
    vim.uv.sleep(500)
    ref(child.get_screenshot())
end

return T
