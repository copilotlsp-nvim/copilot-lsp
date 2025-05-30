---@class copilotlsp.config.nes
---@field move_count_threshold integer Number of cursor movements before clearing suggestion
---@field distance_threshold integer Maximum line distance before clearing suggestion
---@field clear_on_large_distance boolean Whether to clear suggestion when cursor is far away
---@field count_horizontal_moves boolean Whether to count horizontal cursor movements
---@field reset_on_approaching boolean Whether to reset counter when approaching suggestion
---@field enable_history boolean Whether to enable suggestion history for restoration

local M = {}

---@class copilotlsp.config
---@field nes copilotlsp.config.nes
M.defaults = {
    nes = {
        move_count_threshold = 3,
        distance_threshold = 40,
        clear_on_large_distance = true,
        count_horizontal_moves = true,
        reset_on_approaching = true,
        enable_history = true,
    },
}

---@type copilotlsp.config
M.config = vim.deepcopy(M.defaults)

---@param opts? copilotlsp.config configuration to merge with defaults
function M.setup(opts)
    opts = opts or {}
    M.config = vim.tbl_deep_extend("force", M.defaults, opts)
end

return M
