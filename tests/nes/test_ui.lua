local eq = MiniTest.expect.equality
local nes_ui = require("copilot-lsp.nes.ui")

local T = MiniTest.new_set()

T["diff placement calculations"] = MiniTest.new_set({
    ---@type [ copilotlsp.InlineEdit, copilotlsp.nes.LineCalculationResult][]
    parametrize = {
        {
            --- Same line edit
            {
                command = { title = "sameline", command = "mock" },
                range = {
                    start = {
                        line = 0,
                        character = 0,
                    },
                    ["end"] = {
                        line = 0,
                        character = 10,
                    },
                },
                textDocument = {
                    uri = "mock",
                    version = 1,
                },
                text = "mock",
                newText = "mock",
            },
            {
                added_lines = { "mock" },
                added_lines_count = 1,
                delete_extmark = {
                    end_row = 1,
                    row = 0,
                },
                deleted_lines_count = 1,
                same_line = true,
                virt_lines_extmark = {
                    row = 0,
                    virt_lines_count = 1,
                },
            },
        },
        {
            --- removal only
            {
                command = { title = "removal", command = "mock" },
                range = {
                    start = {
                        line = 0,
                        character = 0,
                    },
                    ["end"] = {
                        line = 1,
                        character = 0,
                    },
                },
                textDocument = {
                    uri = "mock",
                    version = 1,
                },
                text = "",
                newText = "",
            },
            {
                added_lines = { "" },
                added_lines_count = 0,
                delete_extmark = {
                    end_row = 1,
                    row = 0,
                },
                deleted_lines_count = 1,
                same_line = false,
                virt_lines_extmark = {
                    row = 0,
                    virt_lines_count = 0,
                },
            },
        },
        {
            --- remove one add 2
            {
                command = { title = "remove1add2", command = "mock" },
                range = {
                    start = {
                        line = 0,
                        character = 0,
                    },
                    ["end"] = {
                        line = 1,
                        character = 0,
                    },
                },
                textDocument = {
                    uri = "mock",
                    version = 1,
                },
                text = "mock\nmore text",
                newText = "mock\nmore text",
            },
            {
                added_lines = { "mock", "more text" },
                added_lines_count = 2,
                delete_extmark = {
                    end_row = 1,
                    row = 0,
                },
                deleted_lines_count = 1,
                same_line = false,
                virt_lines_extmark = {
                    row = 0,
                    virt_lines_count = 2,
                },
            },
        },
        {
            --- add only
            {
                command = { title = "add only", command = "mock" },
                range = {
                    start = { line = 2, character = 0 },
                    ["end"] = { line = 2, character = 0 },
                },
                textDocument = {
                    uri = "mock",
                    version = 1,
                },
                text = "line 3\n",
                newText = "line 3\n",
            },
            {
                added_lines = { "line 3" },
                added_lines_count = 1,
                deleted_lines_count = 1,
                delete_extmark = {
                    end_row = 2,
                    row = 2,
                },
                same_line = true,
                virt_lines_extmark = {
                    row = 1,
                    virt_lines_count = 1,
                },
            },
        },
    },
})

T["diff placement calculations"]["calculates locations"] =
    ---@param edit copilotlsp.InlineEdit
    ---@param result copilotlsp.nes.LineCalculationResult
    function(edit, result)
        local placement = nes_ui._calculate_lines(edit)
        eq(result, placement)
    end

return T
