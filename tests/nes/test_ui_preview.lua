local ref = function(screenshot)
    -- ignore the last, 24th line on the screen as it has differing `screenattr` values between stable and nightly
    MiniTest.expect.reference_screenshot(screenshot, nil, { ignore_attr = { 24 } })
end
local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set()
T["ui_preview"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.restart({ "-u", "scripts/minimal_init.lua" })
            child.bo.filetype = "txt"
        end,
        post_once = child.stop,
    },
})

local cases = {
    ["inline insertion"] = {
        content = "123456\nabcdefg\nhijklmn",
        edit = {
            range = {
                start = {
                    line = 1,
                    character = 2,
                },
                ["end"] = {
                    line = 1,
                    character = 2,
                },
            },
            newText = "XYZ",
        },
        preview = {
            inline_insertion = {
                text = "XYZ",
                line = 1,
                character = 2,
            },
        },
        final = "123456\nabXYZcdefg\nhijklmn",
    },
    ["inline deletion"] = {
        content = "123456\nabcdefg\nhijklmn",
        edit = {
            range = {
                start = {
                    line = 1,
                    character = 2,
                },
                ["end"] = {
                    line = 1,
                    character = 5,
                },
            },
            newText = "",
        },
        preview = {
            deletion = {
                range = {
                    start = {
                        line = 1,
                        character = 2,
                    },
                    ["end"] = {
                        line = 1,
                        character = 5,
                    },
                },
            },
        },
        final = "123456\nabfg\nhijklmn",
    },
    ["insert lines below"] = {
        content = "123456\nabcdefg\nhijklmn",
        edit = {
            range = {
                start = {
                    line = 1,
                    character = 7,
                },
                ["end"] = {
                    line = 1,
                    character = 7,
                },
            },
            newText = "\nXXXX\nYYY",
        },
        preview = {
            lines_insertion = {
                text = "XXXX\nYYY",
                line = 1,
            },
        },
        final = "123456\nabcdefg\nXXXX\nYYY\nhijklmn",
    },
    ["insert lines above"] = {
        content = "123456\nabcdefg\nhijklmn",
        edit = {
            range = {
                start = {
                    line = 1,
                    character = 0,
                },
                ["end"] = {
                    line = 1,
                    character = 0,
                },
            },
            newText = "XXXX\nYYY\n",
        },
        preview = {
            lines_insertion = {
                text = "XXXX\nYYY",
                line = 1,
                above = true,
            },
        },
        final = "123456\nXXXX\nYYY\nabcdefg\nhijklmn",
    },
    ["inline replacement"] = {
        content = "123456\nabcdefg\nhijklmn",
        edit = {
            range = {
                start = {
                    line = 0,
                    character = 3,
                },
                ["end"] = {
                    line = 1,
                    character = 4,
                },
            },
            newText = "XXXX\nYYY",
        },
        preview = {
            deletion = {
                range = {
                    ["end"] = {
                        character = 7,
                        line = 1,
                    },
                    start = {
                        character = 0,
                        line = 0,
                    },
                },
            },
            lines_insertion = {
                line = 1,
                text = "123XXXX\nYYYefg",
            },
        },
        final = "123XXXX\nYYYefg\nhijklmn",
    },
    ["single line replacement"] = {
        content = "123456\nabcdefg\nhijklmn",
        edit = {
            range = {
                start = {
                    line = 1,
                    character = 0,
                },
                ["end"] = {
                    line = 1,
                    character = 8,
                },
            },
            newText = "XXXX",
        },
        preview = {
            deletion = {
                range = {
                    ["end"] = {
                        character = 7,
                        line = 1,
                    },
                    start = {
                        character = 0,
                        line = 1,
                    },
                },
            },
            lines_insertion = {
                line = 1,
                text = "XXXX",
            },
        },
        final = "123456\nXXXX\nhijklmn",
    },
    ["delete lines"] = {
        content = "123456\nabcdefg\nhijklmn",
        edit = {
            range = {
                start = {
                    line = 0,
                    character = 0,
                },
                ["end"] = {
                    line = 2,
                    character = 0,
                },
            },
            newText = "",
        },
        preview = {
            deletion = {
                range = {
                    ["end"] = {
                        character = 0,
                        line = 2,
                    },
                    start = {
                        character = 0,
                        line = 0,
                    },
                },
            },
        },
        final = "hijklmn",
    },
}

local function set_content(content)
    child.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(content, "\n", { plain = true }))
end

local function get_content()
    return table.concat(child.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
end

do
    for name, case in pairs(cases) do
        T["ui_preview"][name] = function()
            set_content(case.content)
            ref(child.get_screenshot())

            child.g.inline_edit = case.edit
            local preview = child.lua_func(function()
                return require("copilot-lsp.nes.ui")._calculate_preview(0, vim.g.inline_edit)
            end)
            eq(preview, case.preview)

            child.g.inline_preview = preview
            child.lua_func(function()
                local ns_id = vim.api.nvim_create_namespace("nes")
                require("copilot-lsp.nes.ui")._display_preview(0, ns_id, vim.g.inline_preview)
            end)
            ref(child.get_screenshot())

            child.lua_func(function()
                local bufnr = vim.api.nvim_get_current_buf()
                vim.lsp.util.apply_text_edits({ vim.g.inline_edit }, bufnr, "utf-16")
            end)

            local final = get_content()
            eq(final, case.final)
        end
    end
end

T["ui_preview"]["cursor_aware_suggestion_clearing"] = function()
    set_content("line1\nline2\nline3\nline4\nline5\nline6\nline7\nline8")
    ref(child.get_screenshot())

    -- Create a suggestion at line 3
    local edit = {
        range = {
            start = { line = 2, character = 0 },
            ["end"] = { line = 2, character = 0 },
        },
        newText = "suggested text ",
    }

    -- Display suggestion
    child.g.test_edit = edit
    child.lua_func(function()
        local ns_id = vim.api.nvim_create_namespace("nes_test")
        local edits = { vim.g.test_edit }
        require("copilot-lsp.nes.ui")._display_next_suggestion(0, ns_id, edits)
    end)
    ref(child.get_screenshot())

    -- Test 1: Moving cursor nearby shouldn't clear the suggestion (within counter threshold)
    child.cmd("normal! gg") -- Move to first line (counter: 1 -> 2)
    child.cmd("normal! j") -- Move to line 2 (counter: 2 -> 3)
    child.lua_func(function()
        vim.uv.sleep(500) -- Give time for autocmd to process
    end)

    -- Verify suggestion still exists (should be at threshold but not exceeded)
    local suggestion_exists = child.lua_func(function()
        return vim.b[0].nes_state ~= nil
    end)
    eq(suggestion_exists, true)
    ref(child.get_screenshot())

    -- Test 2: One more move should clear the suggestion (exceeds counter threshold)
    child.cmd("normal! j")
    child.cmd("normal! j")
    child.cmd("normal! j")
    child.cmd("normal! j")
    child.cmd("normal! j")
    child.lua_func(function()
        vim.uv.sleep(500) -- Give time for autocmd to process
    end)

    -- Verify suggestion is cleared
    local suggestion_cleared = child.lua_func(function()
        return vim.b[0].nes_state == nil
    end)
    eq(suggestion_cleared, true)
    ref(child.get_screenshot())
end

T["ui_preview"]["suggestion_preserves_on_movement_towards"] = function()
    set_content("line1\nline2\nline3\nline4\nline5\nline6\nline7\nline8")
    ref(child.get_screenshot())

    -- Position cursor at line 8
    child.cmd("normal! gg7j")

    -- Create a suggestion at line 3
    local edit = {
        range = {
            start = { line = 2, character = 0 },
            ["end"] = { line = 2, character = 0 },
        },
        newText = "suggested text ",
    }

    -- Display suggestion
    child.g.test_edit = edit
    child.lua_func(function()
        local ns_id = vim.api.nvim_create_namespace("nes_test")
        local edits = { vim.g.test_edit }
        require("copilot-lsp.nes.ui")._display_next_suggestion(0, ns_id, edits)
    end)
    ref(child.get_screenshot())

    -- Test: Moving cursor towards the suggestion (even outside buffer zone) shouldn't clear it
    child.cmd("normal! 4k") -- Move to line 4, moving towards the suggestion
    child.lua_func(function()
        vim.uv.sleep(500)
    end)

    -- Verify suggestion still exists
    local suggestion_exists = child.lua_func(function()
        return vim.b[0].nes_state ~= nil
    end)
    eq(suggestion_exists, true)
    ref(child.get_screenshot())
end

T["ui_preview"]["deletions before response"] = function()
    set_content("loooooooooooooooong")
    ref(child.get_screenshot())

    -- Position cursor at end of line 0
    child.cmd("normal! gg$")

    -- Create a suggestion at line 0
    local edit = {
        range = {
            start = { line = 0, character = 0 },
            ["end"] = { line = 0, character = 19 },
        },
        newText = "long",
    }

    child.cmd("normal! xxxxxxxxxxxxx") -- Delete text

    -- Display suggestion
    child.g.test_edit = edit
    child.lua_func(function()
        local ns_id = vim.api.nvim_create_namespace("nes_test")
        local edits = { vim.g.test_edit }
        require("copilot-lsp.nes.ui")._display_next_suggestion(0, ns_id, edits)
    end)
    ref(child.get_screenshot())

    -- Test: Moving cursor towards the suggestion (even outside buffer zone) shouldn't clear it
    child.cmd("normal! 4k") -- Move to line 4, moving towards the suggestion
    child.lua_func(function()
        vim.uv.sleep(500)
    end)

    -- Verify suggestion still exists
    local suggestion_exists = child.lua_func(function()
        return vim.b[0].nes_state ~= nil
    end)
    eq(suggestion_exists, true)
    ref(child.get_screenshot())
end

return T
