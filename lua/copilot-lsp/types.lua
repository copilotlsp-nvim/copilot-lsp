---@class copilotlsp.InlineEdit : lsp.TextEdit
---@field command lsp.Command
---@field text string
---@field textDocument lsp.VersionedTextDocumentIdentifier

---@class copilotlsp.copilotInlineEditResponse
---@field edits copilotlsp.InlineEdit[]

---@class copilotlsp.nes.EditSuggestionUI
---@field preview_winnr? integer

---@class copilotlsp.nes.DeleteExtmark
--- Holds row information for delete highlight extmark.
---@field row number
---@field end_row number

---@class copilotlsp.nes.AddExtmark
-- Holds row and virtual lines count for virtual lines extmark.
---@field row number
---@field virt_lines_count number

---@class copilotlsp.nes.LineCalculationResult
--- The result of calculating lines for inline suggestion UI.
---@field deleted_lines_count number
---@field added_lines string[]
---@field added_lines_count number
---@field same_line boolean
---@field delete_extmark copilotlsp.nes.DeleteExtmark
---@field virt_lines_extmark copilotlsp.nes.AddExtmark

---@class copilotlsp.nes.TextDeletion
---@field range lsp.Range

---@class copilotlsp.nes.InlineInsertion
---@field text string
---@field line integer
---@field character integer

---@class copilotlsp.nes.TextInsertion
---@field text string
---@field line integer insert lines at this line
---@field above? boolean above the line

---@class copilotlsp.nes.InlineEditPreview
---@field deletion? copilotlsp.nes.TextDeletion
---@field inline_insertion? copilotlsp.nes.InlineInsertion
---@field lines_insertion? copilotlsp.nes.TextInsertion
