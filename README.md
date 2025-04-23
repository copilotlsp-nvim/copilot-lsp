# Copilot LSP Configuration for Neovim

## Features

### Done

- TextDocument Focusing

### In Progress

- Inline Completion
- Next Edit Suggestion
- Uses native LSP Binary

### To Do

- [x] Sign In Flow
- Status Notification

## Usage

To use the plugin, add the following to your Neovim configuration:

```lua
return {
    "copilotlsp-nvim/copilot-lsp",
    init = function()
        vim.g.copilot_nes_debounce = 500
        vim.lsp.enable("copilot")
        vim.keymap.set("n", "<tab>", function()
            local _ = require("copilot-lsp.nes").walk_cursor_start_edit()
                or (
                    require("copilot-lsp.nes").apply_pending_nes() and require("copilot-lsp.nes").walk_cursor_end_edit()
                )
        end)
    end,
}
```

### Blink Integration

```lua
return {
    keymap = {
        preset = "super-tab",
        ["<Tab>"] = {
            function(cmp)
                if vim.b[vim.api.nvim_get_current_buf()].nes_state then
                    cmp.hide()
                    return (
                        require("copilot-lsp.nes").apply_pending_nes()
                        and require("copilot-lsp.nes").walk_cursor_end_edit()
                    )
                end
                if cmp.snippet_active() then
                    return cmp.accept()
                else
                    return cmp.select_and_accept()
                end
            end,
            "snippet_forward",
            "fallback",
        },
    },
}
```

It can also be combined with [fang2hou/blink-copilot](https://github.com/fang2hou/blink-copilot) to get inline completions.
Just add the completion source to your Blink configuration and it will integrate

# Requirements

- Copilot LSP installed via Mason or system and on PATH

### Screenshots

#### NES

![JS Correction](https://github.com/user-attachments/assets/8941f8f9-7d1b-4521-b8e9-f1dcd12d31e9)
![Go Insertion](https://github.com/user-attachments/assets/2c0c4ad9-873b-4860-9eff-ecdb76007234)

<https://github.com/user-attachments/assets/1d5bed4a-fd0a-491f-91f3-a3335cc28682>
