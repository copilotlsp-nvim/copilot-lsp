local M = {}

---@class copilotlsp.lcs.Edit
---@field kind copilotlsp.lcs.EditKind
---@field text string

---@enum copilotlsp.lcs.EditKind
M.edit_kind = {
    addition = "addition",
    removal = "removal",
    unchanged = "unchanged",
}

--- Computes the Long Common Subequence table.
--- Reference: [https://en.wikipedia.org/wiki/Longest_common_subsequence#Computing_the_length_of_the_LCS]
---@param source string
---@param target string
function M.generate_table(source, target)
    local n = #source + 1
    local m = #target + 1

    ---@type integer[][]
    local lcs = {}
    for i = 1, n do
        lcs[i] = {}
        for j = 1, m do
            lcs[i][j] = 0
        end
    end

    for i = 2, n do
        for j = 2, m do
            if source:byte(i - 1) == target:byte(j - 1) then
                lcs[i][j] = 1 + lcs[i - 1][j - 1]
            else
                lcs[i][j] = math.max(lcs[i - 1][j], lcs[i][j - 1])
            end
        end
    end
    return lcs
end

---@generic T
---@param tbl T[]
---@return T[]
local function reverse_table(tbl)
    local ret = {}
    for i = #tbl, 1, -1 do
        table.insert(ret, tbl[i])
    end
    return ret
end

--- Calculates a diff between two strings using LCS
---@param source string
---@param target string
---@return copilotlsp.lcs.Edit[]
function M.diff(source, target)
    local src_idx, trt_idx = #source + 1, #target + 1
    local lcs

    ---@type copilotlsp.lcs.Edit[]
    local edits = {}
    local edit_idx = 1

    local edit_kind = M.edit_kind

    while src_idx > 1 or trt_idx > 1 do
        if src_idx == 1 then
            trt_idx = trt_idx - 1
            edits[edit_idx] = {
                kind = edit_kind.addition,
                text = string.char(string.byte(target, trt_idx)),
            }
        elseif trt_idx == 1 then
            src_idx = src_idx - 1
            edits[edit_idx] = {
                kind = edit_kind.removal,
                text = string.char(string.byte(source, src_idx)),
            }
        else
            local src_char = string.byte(source, src_idx - 1)
            local trt_char = string.byte(target, trt_idx - 1)

            if src_char == trt_char then
                src_idx, trt_idx = src_idx - 1, trt_idx - 1
                edits[edit_idx] = {
                    kind = edit_kind.unchanged,
                    text = string.char(src_char),
                }
            else
                lcs = lcs or M.generate_table(source, target)
                if lcs[src_idx - 1][trt_idx] <= lcs[src_idx][trt_idx - 1] then
                    trt_idx = trt_idx - 1
                    edits[edit_idx] = {
                        kind = edit_kind.addition,
                        text = string.char(trt_char),
                    }
                else
                    src_idx = src_idx - 1
                    edits[edit_idx] = {
                        kind = edit_kind.removal,
                        text = string.char(src_char),
                    }
                end
            end
        end
        edit_idx = edit_idx + 1
    end

    return reverse_table(edits)
end

---@param edits copilotlsp.lcs.Edit[]
---@param line integer
---@param character integer
---@return lsp.TextEdit[]
function M.to_lsp_edits(edits, line, character)
    local function advance_cursor(edit)
        if edit.text == "\n" then
            line = line + 1
            character = 0
        else
            character = character + 1
        end
    end

    ---@type lsp.TextEdit[]
    local lsp_edits = {}
    local i = 1
    while i < #edits do
        -- Skip all unchanged edits and advance cursor
        while i < #edits and edits[i].kind == M.edit_kind.unchanged do
            advance_cursor(edits[i])
            i = i + 1
        end

        -- No more edits to compute
        if i >= #edits then
            break
        end

        local new_text = ""
        local start_line, start_character = line, character

        -- Collect consecutive additions and removals
        while i < #edits and edits[i].kind ~= M.edit_kind.unchanged do
            if edits[i].kind == M.edit_kind.addition then
                new_text = new_text .. edits[i].text
            elseif edits[i].kind == M.edit_kind.removal then
                advance_cursor(edits[i])
            else
                error("unexcepted edit kind " .. edits[i].kind)
            end
            i = i + 1
        end

        ---@type lsp.TextEdit
        local lsp_edit = {
            newText = new_text,
            range = {
                start = {
                    line = start_line,
                    character = start_character,
                },
                ["end"] = {
                    line = line,
                    character = character,
                },
            },
        }

        table.insert(lsp_edits, lsp_edit)
    end

    return lsp_edits
end

return M
