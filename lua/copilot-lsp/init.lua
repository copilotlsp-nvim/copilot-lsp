local config = require("copilot-lsp.config")

---@class copilotlsp
---@field defaults copilotlsp.config
---@field config copilotlsp.config
---@field setup fun(opts?: copilotlsp.config): nil
local M = {}

M.defaults = config.defaults
M.config = config.config

---@param opts? copilotlsp.config configuration to merge with defaults
function M.setup(opts)
    config.setup(opts)
    M.config = config.config
end

return M
