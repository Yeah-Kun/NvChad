-- load_config 函数：这个函数首先加载默认的配置。然后，它尝试加载用户的配置文件（custom.chadrc）。如果用户的配置文件存在并且返回一个表，那么它将合并用户的配置到默认的配置中，覆盖默认配置中的任何相同的键值对。如果用户配置文件存在但不是一个表，那么它将抛出一个错误。

-- remove_disabled_keys 函数：这个函数接受用户配置的键位映射和默认的键位映射，然后从默认的键位映射中移除用户配置中禁用的键。

-- load_mappings 函数：这个函数负责加载键位映射。它首先清除给定的映射的插件映射，然后对每个模式和键，设置一个映射。

-- merge_plugins 函数：这个函数合并默认的插件配置和用户的插件配置。它首先加载用户的插件配置。然后，如果用户配置中定义了需要移除的插件，那么它将从插件列表中移除这些插件。最后，它将用户的插件配置合并到默认的插件配置中。

-- load_override 函数：这个函数负责加载插件的选项覆盖。它首先加载用户的插件配置。然后，如果用户配置中定义了需要覆盖的插件选项，那么它将覆盖这些插件的默认选项。

-- packer_sync 函数：这个函数用于同步Packer，一个用于管理Vim插件的工具。如果当前在一个快照分支上运行，那么它将警告用户这可能会导致问题。然后，它将调用Packer的sync函数来同步插件。

local M = {}
local merge_tb = vim.tbl_deep_extend

M.load_config = function()
  local config = require "core.default_config"
  local chadrc_exists, chadrc = pcall(require, "custom.chadrc")

  if chadrc_exists then
    -- merge user config if it exists and is a table; otherwise display an error
    if type(chadrc) == "table" then
      config.mappings = M.remove_disabled_keys(chadrc.mappings, config.mappings)
      config = merge_tb("force", config, chadrc) or {}
    else
      error "chadrc must return a table!"
    end
  end

  config.mappings.disabled = nil
  return config
end

M.remove_disabled_keys = function(chadrc_mappings, default_mappings)
  if not chadrc_mappings then
    return default_mappings
  end

  -- store keys in a array with true value to compare
  local keys_to_disable = {}
  for _, mappings in pairs(chadrc_mappings) do
    for mode, section_keys in pairs(mappings) do
      if not keys_to_disable[mode] then
        keys_to_disable[mode] = {}
      end
      section_keys = (type(section_keys) == "table" and section_keys) or {}
      for k, _ in pairs(section_keys) do
        keys_to_disable[mode][k] = true
      end
    end
  end

  -- make a copy as we need to modify default_mappings
  for section_name, section_mappings in pairs(default_mappings) do
    for mode, mode_mappings in pairs(section_mappings) do
      mode_mappings = (type(mode_mappings) == "table" and mode_mappings) or {}
      for k, _ in pairs(mode_mappings) do
        -- if key if found then remove from default_mappings
        if keys_to_disable[mode] and keys_to_disable[mode][k] then
          default_mappings[section_name][mode][k] = nil
        end
      end
    end
  end

  return default_mappings
end

M.load_mappings = function(section, mapping_opt)
  local function set_section_map(section_values)
    if section_values.plugin then
      return
    end
    section_values.plugin = nil

    for mode, mode_values in pairs(section_values) do
      local default_opts = merge_tb("force", { mode = mode }, mapping_opt or {})
      for keybind, mapping_info in pairs(mode_values) do
        -- merge default + user opts
        local opts = merge_tb("force", default_opts, mapping_info.opts or {})

        mapping_info.opts, opts.mode = nil, nil
        opts.desc = mapping_info[2]

        vim.keymap.set(mode, keybind, mapping_info[1], opts)
      end
    end
  end

  local mappings = require("core.utils").load_config().mappings

  if type(section) == "string" then
    mappings[section]["plugin"] = nil
    mappings = { mappings[section] }
  end

  for _, sect in pairs(mappings) do
    set_section_map(sect)
  end
end

-- merge default/user plugin tables
M.merge_plugins = function(plugins)
  local plugin_configs = M.load_config().plugins
  local user_plugins = plugin_configs

  -- old plugin syntax for adding plugins
  if plugin_configs.user and type(plugin_configs.user) == "table" then
    user_plugins = plugin_configs.user
  end

  -- support old plugin removal syntax
  local remove_plugins = plugin_configs.remove
  if type(remove_plugins) == "table" then
    for _, v in ipairs(remove_plugins) do
      plugins[v] = nil
    end
  end

  plugins = merge_tb("force", plugins, user_plugins)

  local final_table = {}

  for key, val in pairs(plugins) do
    if val and type(val) == "table" then
      plugins[key] = val.rm_default_opts and user_plugins[key] or plugins[key]
      plugins[key][1] = key
      final_table[#final_table + 1] = plugins[key]
    end
  end

  return final_table
end

-- override plugin options table with custom ones
M.load_override = function(options_table, name)
  local plugin_configs, plugin_options = M.load_config().plugins, nil

  -- support old plugin syntax for override
  local user_override = plugin_configs.override and plugin_configs.override[name]
  if user_override and type(user_override) == "table" then
    plugin_options = user_override
  end

  -- if no old style plugin override is found, then use the new syntax
  if not plugin_options and plugin_configs[name] then
    local override_options = plugin_configs[name].override_options or {}
    if type(override_options) == "table" then
      plugin_options = override_options
    elseif type(override_options) == "function" then
      plugin_options = override_options()
    end
  end

  -- make sure the plugin options are a table
  plugin_options = type(plugin_options) == "table" and plugin_options or {}

  return merge_tb("force", options_table, plugin_options)
end

M.packer_sync = function(...)
  local git_exists, git = pcall(require, "nvchad.utils.git")
  local defaults_exists, defaults = pcall(require, "nvchad.utils.config")
  local packer_exists, packer = pcall(require, "packer")

  if git_exists and defaults_exists then
    local current_branch_name = git.get_current_branch_name()

    -- warn the user if we are on a snapshot branch
    if current_branch_name:match(defaults.snaps.base_snap_branch_name .. "(.+)" .. "$") then
      vim.api.nvim_echo({
        { "WARNING: You are trying to use ", "WarningMsg" },
        { "PackerSync" },
        {
          " on a NvChadSnapshot. This will cause issues if NvChad dependencies contain "
            .. "any breaking changes! Plugin updates will not be included in this "
            .. "snapshot, so they will be lost after switching between snapshots! Would "
            .. "you still like to continue? [y/N]\n",
          "WarningMsg",
        },
      }, false, {})

      local ans = vim.trim(string.lower(vim.fn.input "-> "))

      if ans ~= "y" then
        return
      end
    end
  end

  if packer_exists then
    packer.sync(...)

    local plugins = M.load_config().plugins
    local old_style_options = plugins.user or plugins.override or plugins.remove
    if old_style_options then
      vim.notify_once("NvChad: This plugin syntax is deprecated, use new style config.", "Error")
    end
  else
    error "Packer could not be loaded!"
  end
end

return M
