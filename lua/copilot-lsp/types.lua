---@class copilotlsp.InlineEdit : lsp.TextEdit
---@field command lsp.Command
---@field text string
---@field textDocument lsp.VersionedTextDocumentIdentifier

---@class copilotlsp.copilotInlineEditResponse
---@field edits copilotlsp.InlineEdit[]

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
