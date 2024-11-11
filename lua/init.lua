local dap, dapui =require("dap"),require("dapui")
dap.listeners.after.event_initialized["dapui_config"]=function()
  dapui.open()
end
dap.listeners.before.event_terminated["dapui_config"]=function()
  dapui.close()
end
dap.listeners.before.event_exited["dapui_config"]=function()
  dapui.close()
end

-- treesitter
require "nvim-treesitter.configs".setup {
  highlight = {
    enable = true, -- false will disable the whole extension
    disable = { "java" }, -- list of language that will be disabled
  },
}

-- utils

local M = {}

local is_unix = vim.fn.has("unix") == 1
local is_win32 = vim.fn.has("win32") == 1
local is_wsl = vim.fn.has("wsl") == 1
local extension_path
local codelldb_path
local liblldb_path

if is_wsl then
  extension_path = vim.env.HOME .. "/.vscode-server/extensions/vadimcn.vscode-lldb-1.9.2/"
  codelldb_path = extension_path .. "adapter/codelldb"
  liblldb_path = extension_path .. "lldb/lib/liblldb.so"
elseif is_unix then
  extension_path = vim.env.HOME .. "/.vscode/extensions/vadimcn.vscode-lldb-1.9.2/"
  codelldb_path = extension_path .. "adapter/codelldb"
  liblldb_path = extension_path .. "lldb/lib/liblldb.so"
elseif is_win32 then
  extension_path = vim.env.HOME .. "C:\\Users\\senhu\\.vscode\\extensions\\vadimcn.vscode-lldb-1.9.2\\"
  codelldb_path = extension_path .. "adapter\\codelldb"
  liblldb_path = extension_path .. "lldb\\lib\\liblldb.so"
end

M.codelldb_path = codelldb_path
M.liblldb_path = liblldb_path

local scan = require("plenary.scandir")

local contains = function(tbl, str)
  for _, v in ipairs(tbl) do
    if v == str then
      return true
    end
  end
  return false
end

local F = {}
--- Check if a path
F.exists = function(dir, file_pattern)
  local dirs = scan.scan_dir(dir, { depth = 1, search_pattern = file_pattern })
  return contains(dirs, dir .. "/" .. file_pattern)
end

-- Adjust the path to your executable
local codelldb = M

local dap = require("dap")

dap.adapters.codelldb = {
  type = "server",
  port = "${port}",
  executable = {
    -- CHANGE THIS to your path!
    command = codelldb.codelldb_path,
    args = { "--port", "${port}" },

    -- On windows you may have to uncomment this:
    -- detached = false,
  }
}

-- config for c
local file = F
local dap = require("dap")

dap.configurations.c = {
  {
    name = "C Debug And Run",
    type = "codelldb",
    request = "launch",
    program = function()
      -- First, check if exists CMakeLists.txt
      local cwd = vim.fn.getcwd()
      if (file.exists(cwd, "CMakeLists.txt")) then
        -- Todo. Then invoke cmake commands
        -- Then ask user to provide execute file
        return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
      else
        local fileName = vim.fn.expand("%:t:r")
        if (not file.exists(cwd, "bin")) then
          -- create this directory
          os.execute("mkdir " .. "bin")
        end
        local cmd = "!gcc -g % -o bin/" .. fileName
        -- First, compile it
        vim.cmd(cmd)
        -- Then, return it
        return "${fileDirname}/bin/" .. fileName
      end
    end,
    cwd = "${workspaceFolder}",
    stopOnEntry = false
  },
}

-- config for cpp
local file = F
local dap = require("dap")

dap.defaults.fallback.terminal_win_cmd = "10split new"

dap.configurations.cpp = {
  {
    name = "C++ Debug And Run",
    type = "codelldb",
    request = "launch",
    program = function()
      -- First, check if exists CMakeLists.txt
      local cwd = vim.fn.getcwd()
      if file.exists(cwd, "CMakeLists.txt") then
        -- Then invoke cmake commands
        -- Then ask user to provide execute file
        return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
      else
        local fileName = vim.fn.expand("%:t:r")
        -- create this directory
        os.execute("mkdir -p " .. "bin")
        local cmd = "!g++ -g % -o bin/" .. fileName
        -- First, compile it
        vim.cmd(cmd)
        -- Then, return it
        return "${fileDirname}/bin/" .. fileName
      end
    end,
    cwd = "${workspaceFolder}",
    stopOnEntry = false,
    runInTerminal = true,
    console = "integratedTerminal",
  },
}

-- config debug for rust
dap.configurations.rust = {
  {
    name = "Rust debug",
    type = "codelldb",
    request = "launch",
    program = function()
        local root_dir = vim.fs.dirname(vim.fs.find({'.git/', '.sh'}, { upward = true })[1])
        -- First, compile it
        vim.fn.jobstart('cargo build')
        -- Then, return it
        local filePath = vim.fn.getcwd() .. "/target/debug/" .. vim.fs.basename(root_dir)
        return filePath
    end,
    cwd = '${workspaceFolder}',
    stopOnEntry = true,
  },
}

-- config telescope
local telescope = require('telescope')
telescope.load_extension('dap')

local map = vim.keymap.set
local tsbuiltin = require('telescope.builtin')

map('n', '<leader>b', tsbuiltin.buffers, {
  noremap=true, silent=true
})
map('n', '<leader>o', tsbuiltin.oldfiles, {})

require("ibl").setup()
