local has_fzf, fzf = pcall(require, "fzf-lua")

if not has_fzf then
  error("This plugin requires fzf-lua (https://github.com/ibhagwan/fzf-lua)")
end

local DbClient = require("smart-open.dbclient")
local picker = require("smart-open.fzf-lua.picker")
local config = require("smart-open").config

local M = {}

M.smart_open = function(opts)
  opts = opts or {}

  ---@diagnostic disable-next-line: missing-parameter
  opts.cwd = vim.fn.expand(opts.cwd or vim.fn.getcwd())
  opts.current_buffer = vim.fn.bufnr("%") > 0 and vim.api.nvim_buf_get_name(vim.fn.bufnr("%")) or ""
  opts.alternate_buffer = vim.fn.bufnr("#") > 0 and vim.api.nvim_buf_get_name(vim.fn.bufnr("#")) or ""
  opts.filename_first = opts.filename_first == nil and true or opts.filename_first

  opts.config = config

  opts.db = DbClient:new({ path = config.db_filename })

  picker.start(opts)
end

return M
