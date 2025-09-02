local version = vim.version()

---@type vim.lsp.Config
return {
    --NOTE: This name means that existing blink completion works
    name = "copilot_ls",
    cmd = {
        "copilot-language-server",
        "--stdio",
    },
    init_options = {
        editorInfo = {
            name = "neovim",
            version = string.format("%d.%d.%d", version.major, version.minor, version.patch),
        },
        editorPluginInfo = {
            name = "Github Copilot LSP for Neovim",
            version = "0.0.1",
        },
    },
    settings = {
        nextEditSuggestions = {
            enabled = true,
        },
    },
    handlers = require("copilot-lsp.handlers"),
    root_dir = vim.uv.cwd(),
    on_init = function(client)
        local au = vim.api.nvim_create_augroup("copilotlsp.init", { clear = true })
        --NOTE: Inline Completions
        --TODO: We dont currently use this code path, so comment for now until a UI is built
        -- vim.api.nvim_create_autocmd("TextChangedI", {
        --     callback = function()
        --         inline_completion.request_inline_completion(2)
        --     end,
        --     group = au,
        -- })

        -- TODO: make this configurable for key maps, or just expose commands to map in config
        -- vim.keymap.set("i", "<c-i>", function()
        --     inline_completion.request_inline_completion(1)
        -- end)

        require("copilot-lsp.nes").lsp_on_init(client, au)
    end,
}
