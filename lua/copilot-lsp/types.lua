---@class copilotlsp.InlineEdit
---@field command lsp.Command
---@field range lsp.Range
---@field text string
---@field newText string
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
---@field same_line number
---@field delete_extmark copilotlsp.nes.DeleteExtmark
---@field virt_lines_extmark copilotlsp.nes.AddExtmark
