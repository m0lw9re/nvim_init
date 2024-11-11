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

-- config debug for java
-- befor config, need to doing following instruction
-- install jdtls via https://github.com/eclipse/eclipse.jdt.ls
-- clone https://github.com/microsoft/java-debug and run `./mvnw clean install`
-- clone https://github.com/microsoft/vscode-java-test and run `npm install && npm run build-plugin`

local home = os.getenv('HOME')
local jdtls = require('jdtls')

-- File types that signify a Java project's root directory. This will be
-- used by eclipse to determine what constitutes a workspace
local root_markers = {'gradlew', 'mvnw', '.git'}
local root_dir = require('jdtls.setup').find_root(root_markers)

-- eclipse.jdt.ls stores project specific data within a folder. If you are working
-- with multiple different projects, each project must use a dedicated data directory.
-- This variable is used to configure eclipse to use the directory name of the
-- current project found using the root_marker as the folder for project specific data.
local workspace_folder = home .. "/.local/share/eclipse/" .. vim.fn.fnamemodify(root_dir, ":p:h:t")

-- Helper function for creating keymaps
function nnoremap(rhs, lhs, bufopts, desc)
  bufopts.desc = desc
  vim.keymap.set("n", rhs, lhs, bufopts)
end

-- The on_attach function is used to set key maps after the language server
-- attaches to the current buffer
local on_attach = function(client, bufnr)
  client.server_capabilities.semanticTokensProvider = nil
  if client.name == "jdtls" then
          jdtls = require("jdtls")
          jdtls.setup_dap({ hotcodereplace = "auto" })
          jdtls.setup.add_commands()
          -- Auto-detect main and setup dap config
          require("jdtls.dap").setup_dap_main_class_configs({
            config_overrides = {
              vmArgs = "-Dspring.profiles.active=local",
            },
          })

          -- Regular Neovim LSP client keymappings
          local bufopts = { noremap=true, silent=true, buffer=bufnr }
          nnoremap('gD', vim.lsp.buf.declaration, bufopts, "Go to declaration")
          nnoremap('gd', vim.lsp.buf.definition, bufopts, "Go to definition")
          nnoremap('gi', vim.lsp.buf.implementation, bufopts, "Go to implementation")
          nnoremap('K', vim.lsp.buf.hover, bufopts, "Hover text")
          nnoremap('<C-k>', vim.lsp.buf.signature_help, bufopts, "Show signature")
          nnoremap('<space>wa', vim.lsp.buf.add_workspace_folder, bufopts, "Add workspace folder")
          nnoremap('<space>wr', vim.lsp.buf.remove_workspace_folder, bufopts, "Remove workspace folder")
          nnoremap('<space>wl', function()
            print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
          end, bufopts, "List workspace folders")
          nnoremap('<space>D', vim.lsp.buf.type_definition, bufopts, "Go to type definition")
          nnoremap('<space>rn', vim.lsp.buf.rename, bufopts, "Rename")
          nnoremap('<space>ca', vim.lsp.buf.code_action, bufopts, "Code actions")
          vim.keymap.set('v', "<space>ca", "<ESC><CMD>lua vim.lsp.buf.range_code_action()<CR>",
            { noremap=true, silent=true, buffer=bufnr, desc = "Code actions" })
          nnoremap('<space>f', function() vim.lsp.buf.format { async = true } end, bufopts, "Format file")

          -- Java extensions provided by jdtls
          nnoremap("<C-o>", jdtls.organize_imports, bufopts, "Organize imports")
          nnoremap("<space>ev", jdtls.extract_variable, bufopts, "Extract variable")
          nnoremap("<space>ec", jdtls.extract_constant, bufopts, "Extract constant")
          vim.keymap.set('v', "<space>em", [[<ESC><CMD>lua require('jdtls').extract_method(true)<CR>]],
            { noremap=true, silent=true, buffer=bufnr, desc = "Extract method" })
          nnoremap("<leader>vc", jdtls.test_class, bufopts, "Test class (DAP)")
          nnoremap("<leader>vm", jdtls.test_nearest_method, bufopts, "Test method (DAP)")
  end
end

local bundles = {
  vim.fn.glob(home .. '/tools/java-debug/com.microsoft.java.debug.plugin/target/com.microsoft.java.debug.plugin-*.jar'),
}

vim.list_extend(bundles, vim.split(vim.fn.glob("/tools/vscode-java-test/server/*.jar", 1), "\n"))

local config = {
  flags = {
    debounce_text_changes = 80,
    allow_incremental_sync = true,
  },
  on_attach = on_attach,  -- We pass our on_attach keybindings to the configuration map
  init_options = {
    bundles = bundles
  },
  on_init = function(client)
    if client.config.settings then
      client.notify("workspace/didChangeConfiguration", { settings = client.config.settings })
    end
  end,
  root_dir = root_dir, -- Set the root directory to our found root_marker
  -- Here you can configure eclipse.jdt.ls specific settings
  -- These are defined by the eclipse.jdt.ls project and will be passed to eclipse when starting.
  -- See https://github.com/eclipse/eclipse.jdt.ls/wiki/Running-the-JAVA-LS-server-from-the-command-line#initialize-request
  -- for a list of options
  settings = {
    java = {
      signatureHelp = { enabled = true },
      contentProvider = { preferred = 'fernflower' },  -- Use fernflower to decompile library code
      -- Specify any completion options
      completion = {
        favoriteStaticMembers = {
          "org.hamcrest.MatcherAssert.assertThat",
          "org.hamcrest.Matchers.*",
          "org.hamcrest.CoreMatchers.*",
          "org.junit.jupiter.api.Assertions.*",
          "java.util.Objects.requireNonNull",
          "java.util.Objects.requireNonNullElse",
          "org.mockito.Mockito.*"
        },
        filteredTypes = {
          "com.sun.*",
          "io.micrometer.shaded.*",
          "java.awt.*",
          "jdk.*", "sun.*",
        },
      },
      -- Specify any options for organizing imports
      sources = {
        organizeImports = {
          starThreshold = 9999;
          staticStarThreshold = 9999;
        },
      },
      -- How code generation should act
      codeGeneration = {
        toString = {
          template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}"
        },
        hashCodeEquals = {
          useJava7Objects = true,
        },
        useBlocks = true,
      },
      -- If you are developing in projects with different Java versions, you need
      -- to tell eclipse.jdt.ls to use the location of the JDK for your Java version
      -- See https://github.com/eclipse/eclipse.jdt.ls/wiki/Running-the-JAVA-LS-server-from-the-command-line#initialize-request
      -- And search for `interface RuntimeOption`
      -- The `name` is NOT arbitrary, but must match one of the elements from `enum ExecutionEnvironment` in the link above
      configuration = {
        runtimes = {
          {
            name = "JavaSE-17",
            path = "/usr/lib/jvm/java-17-openjdk-amd64",
          },
          {
            name = "JavaSE-11",
            path = "/usr/lib/jvm/java-11-openjdk-amd64",
          }
        }
      }
    }
  },
  -- cmd is the command that starts the language server. Whatever is placed
  -- here is what is passed to the command line to execute jdtls.
  -- Note that eclipse.jdt.ls must be started with a Java version of 17 or higher
  -- See: https://github.com/eclipse/eclipse.jdt.ls#running-from-the-command-line
  -- for the full list of options
  cmd = {
    vim.fn.glob(home .. '/tools/jdt-language-server/bin/jdtls'),
    '/usr/lib/jvm/java-17-openjdk-amd64/bin/java',
    '-Declipse.application=org.eclipse.jdt.ls.core.id1',
    '-Dosgi.bundles.defaultStartLevel=4',
    '-Declipse.product=org.eclipse.jdt.ls.core.product',
    '-Dlog.protocol=true',
    '-Dlog.level=ALL',
    '-Xmx4g',
    '--add-modules=ALL-SYSTEM',
    '--add-opens', 'java.base/java.util=ALL-UNNAMED',
    '--add-opens', 'java.base/java.lang=ALL-UNNAMED',
    -- If you use lombok, download the lombok jar and place it in ~/.local/share/eclipse
    '-javaagent:' .. home .. '/.local/share/eclipse/lombok.jar',

    -- The jar file is located where jdtls was installed. This will need to be updated
    -- to the location where you installed jdtls
    '-jar', vim.fn.glob(home .. '/tools/jdt-language-server/plugins/org.eclipse.equinox.launcher_*.jar'),

    -- The configuration for jdtls is also placed where jdtls was installed. This will
    -- need to be updated depending on your environment
    '-configuration', home .. '/tools/jdt-language-server/config_linux',

    -- Use the workspace_folder defined above to store data for this project
    '-data', workspace_folder,
  },
}

-- Finally, start jdtls. This will run the language server using the configuration we specified,
-- setup the keymappings, and attach the LSP client to the current buffer
jdtls.start_or_attach(config)

require('dap.ext.vscode').load_launchjs()
require('telescope').load_extension('dap')
require("ibl").setup()
