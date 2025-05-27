local config = require("copilot-lsp.config")

local M = {}

M.defaults = config.defaults
M.config = config.config

function M.setup(opts)
    config.setup(opts)
    M.config = config.config
end

return M
