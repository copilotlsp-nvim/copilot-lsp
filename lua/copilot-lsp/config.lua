local M = {}

M.defaults = {
    nes = {
        move_count_threshold = 3,
        distance_threshold = 40,
        clear_on_large_distance = true,
        count_horizontal_moves = true,
        reset_on_approaching = true
    }
}

M.config = vim.deepcopy(M.defaults)

function M.setup(opts)
    opts = opts or {}
    M.config = vim.tbl_deep_extend("force", M.defaults, opts)
end

return M
