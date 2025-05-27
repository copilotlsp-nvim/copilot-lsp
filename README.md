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
        vim.lsp.enable("copilot_ls")
        vim.keymap.set("n", "<tab>", function()
            -- Try to jump to the start of the suggestion edit.
            -- If already at the start, then apply the pending suggestion and jump to the end of the edit.
            local _ = require("copilot-lsp.nes").walk_cursor_start_edit()
                or (
                    require("copilot-lsp.nes").apply_pending_nes() and require("copilot-lsp.nes").walk_cursor_end_edit()
                )
        end)
    end,
}
```


#### Clearing suggestions with Escape

You can map the `<Esc>` key to clear suggestions while preserving its other functionality:

```lua
-- Clear copilot suggestion with Esc if visible, otherwise preserve default Esc behavior
vim.keymap.set("n", "<esc>", function()
    if not require('copilot-lsp.nes').clear() then
        -- fallback to other functionality
    end
end, { desc = "Clear Copilot suggestion or fallback" })
```

## Default Configuration


### NES (Next Edit Suggestion) Smart Clearing
You don’t need to configure anything, but you can customize the defaults:
`move_count_threshold` is the most important. It controls how many cursor moves happen before suggestions are cleared. Higher = slower to clear.

```lua
require('copilot-lsp').setup({
  -- NES smart clearing options
  move_count_threshold = 3,        -- Clear after 3 cursor movements
  distance_threshold = 40,         -- Clear if cursor is >40 lines away
  clear_on_large_distance = true,  -- Enable distance-based clearing
  count_horizontal_moves = true,   -- Count horizontal moves in normal mode
  reset_on_approaching = true,     -- Reset counter when moving toward suggestion
})
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
