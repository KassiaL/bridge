---@diagnostic disable-next-line: undefined-global
local bridge_context_manager = bridge_context_manager
local set_context = bridge_context_manager.set
local get_context = bridge_context_manager.get

local M = {}

M.get_context = get_context
M.set_context = set_context

return M
