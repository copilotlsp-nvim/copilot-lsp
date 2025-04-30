local ref = MiniTest.expect.reference_screenshot

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set()
T["ui_preview"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.restart({ "-u", "scripts/minimal_init.lua" })
            child.api.nvim_set_hl(0, "CopilotLspNesAdd", { link = "DiffAdd", default = true })
            child.api.nvim_set_hl(0, "CopilotLspNesDelete", { link = "DiffDelete", default = true })
            child.api.nvim_set_hl(0, "CopilotLspNesApply", { link = "DiffText", default = true })
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
    },
    ["insert lines after line end"] = {
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
    },
    ["insert lines at the beginning"] = {
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
    },
}

local function set_content(content)
    child.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(content, "\n", { plain = true }))
end

do
    for name, case in pairs(cases) do
        T["ui_preview"][name] = function()
            set_content(case.content)
            ref(child.get_screenshot())

            child.g.inline_edit = case.edit
            local _preview = child.lua_func(function()
                local ns_id = vim.api.nvim_create_namespace("nes")
                local bufnr = vim.api.nvim_get_current_buf()
                local preview = require("copilot-lsp.nes.ui").caculate_preview(bufnr, vim.g.inline_edit)
                require("copilot-lsp.nes.ui").display_inline_edit_preview(bufnr, ns_id, preview)
                return preview
            end)
            ref(child.get_screenshot())
        end
    end
end

return T
