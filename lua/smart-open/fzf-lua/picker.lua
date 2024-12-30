-- local pickers = require("telescope.pickers")
-- local get_buffer_list = require("telescope._extensions.smart_open.buffers")
-- local sorters = require("telescope.sorters")
-- local weights = require("telescope._extensions.smart_open.weights")
-- local Finder = require("telescope._extensions.smart_open.finder.finder")
-- local actions = require("telescope.actions")
-- local action_state = require("telescope.actions.state")
-- local telescope_config = require("telescope.config").values
-- local smart_open_actions = require("smart-open.actions")

local core = require "fzf-lua.core"
local weights = require("smart-open.weights")
local Finder = require("smart-open.finder.finder")
local make_display = require("smart-open.display.make_display")
local history = require("smart-open.history")
local Path = require "plenary.path"

local picker
local M = {}


---@return boolean
local function buf_in_cwd(bufname, cwd)
  if cwd:sub(-1) ~= Path.path.sep then
    cwd = cwd .. Path.path.sep
  end
  local bufname_prefix = bufname:sub(1, #cwd)
  return bufname_prefix == cwd
end

local function get_buffers(opts)
  local bufnrs = vim.tbl_filter(function(bufnr)
    if 1 ~= vim.fn.buflisted(bufnr) then
      return false
    end
    -- only hide unloaded buffers if opts.show_all_buffers is false, keep them listed if true or nil
    if opts.show_all_buffers == false and not vim.api.nvim_buf_is_loaded(bufnr) then
      return false
    end
    if opts.ignore_current_buffer and bufnr == vim.api.nvim_get_current_buf() then
      return false
    end

    local bufname = vim.api.nvim_buf_get_name(bufnr)

    if opts.cwd_only and not buf_in_cwd(bufname, vim.loop.cwd()) then
      return false
    end
    if not opts.cwd_only and opts.cwd and not buf_in_cwd(bufname, opts.cwd) then
      return false
    end
    return true
  end, vim.api.nvim_list_bufs())

  return bufnrs
end

function M.start(opts)
  local db = opts.db
  local config = opts.config

  ---@diagnostic disable-next-line: param-type-mismatch
  local current = vim.fn.bufnr("%") > 0 and vim.api.nvim_buf_get_name(vim.fn.bufnr("%")) or ""

  -- TODO: fill that
  local open_buffers = get_buffers({
    show_all_buffers = true,
    ignore_current_buffer = false,
    cwd_only = false,
    -- cwd = opts.cwd,
  })

  local context = {
    cwd = opts.cwd,
    current_buffer = current,
    ---@diagnostic disable-next-line: param-type-mismatch
    alternate_buffer = vim.fn.bufnr("#") > 0 and vim.api.nvim_buf_get_name(vim.fn.bufnr("#")) or "",
    open_buffers = open_buffers,
    weights = db:get_weights(weights.default_weights),
    path_display = opts.path_display,
  }

  local finder = Finder(history, {
    display = make_display(opts),
    cwd = opts.cwd,
    cwd_only = vim.F.if_nil(opts.cwd_only, config.cwd_only),
    ignore_patterns = vim.F.if_nil(opts.ignore_patterns, config.ignore_patterns),
    show_scores = vim.F.if_nil(opts.show_scores, config.show_scores),
    match_algorithm = opts.match_algorithm or config.match_algorithm,
    result_limit = vim.F.if_nil(opts.result_limit, config.result_limit),
  }, context)
  opts.get_status_text = finder.get_status_text

  opts.actions = {
    ['default'] = function(selected)
      if current ~= selected.path then
        history:record_usage(selected.path, true)
      end
      local original_weights = db:get_weights(weights.default_weights)
      local revised_weights = weights.revise_weights(original_weights, finder.results, selected)
      db:save_weights(revised_weights)
    end
  }

  require("fzf-lua").fzf_live(function(query)
      -- local bufs = {}
      -- finder(query, function(entry)
      --   table.insert(bufs, entry.path)
      -- end, function() end)
      -- return bufs

      return function(fzf_cb)
        finder(
          query,
          function(entry)
            return fzf_cb(entry.path)
          end,
          function()
            -- fzf_cb(nil)
          end
        )
      end
    end,
    {
      prompt = "Smart > ",
      exec_empty_query = true,
      func_async_callback = false,
      actions = opts.actions
    })
end

return M
