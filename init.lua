-- init.lua
-- Configuración de Neovim optimizada para TypeScript/Next.js y Python

-- Configuración para ts_context_commentstring
vim.g.skip_ts_context_commentstring_module = true

-- Inicialización de lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Configuración básica
vim.g.mapleader = " "
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.tabstop = 4  -- 4 espacios para Python
vim.opt.shiftwidth = 4  -- 4 espacios para Python
vim.opt.smartindent = true
vim.opt.wrap = false
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true
vim.opt.hlsearch = false
vim.opt.incsearch = true
vim.opt.termguicolors = true
vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 50
-- vim.opt.colorcolumn = "88"

-- Configuración de plugins
require("lazy").setup({
  -- LSP
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/nvim-cmp",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "mfussenegger/nvim-jdtls",
    }
  },
  
  -- Autocompletado
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
    },
  },

  -- Python environment selector (nueva versión 2024)
  {
    "linux-cultist/venv-selector.nvim",
    dependencies = {
      "neovim/nvim-lspconfig",
      "nvim-telescope/telescope.nvim",
      "mfussenegger/nvim-dap-python",
    },
    config = function()
      require("venv-selector").setup({
        -- Nueva configuración para la versión 2024
    	stay_on_this_version = true,
        search_venv_managers = true,
        search_workspace = true,
        parents = 2,
        enabled = true,
        search = {
          -- Patrones personalizados para búsqueda
          "venv",
          ".venv",
          "env",
          ".env",
          -- Patrones para poetry, pipenv, etc.
          ".*/pypoetry/virtualenvs/.*",
          ".*/virtualenvs/.*",
          -- Patrones para conda
          "conda.*",
        },
        dap_enabled = true,
        name = {
          "venv",
          ".venv",
          "env",
          ".env",
        },
        path = vim.fn.stdpath("data") .. "/venv",
      })
    end,
  },
  -- Debug
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "rcarriga/nvim-dap-ui",
      "mfussenegger/nvim-dap-python",
    },
  },
  
  -- Formateo y linting
  {
    "jose-elias-alvarez/null-ls.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    }
  },
  "MunifTanjim/prettier.nvim",
  
  -- Utilidades
  "windwp/nvim-autopairs",
  "numToStr/Comment.nvim",
  {
    "JoosepAlviste/nvim-ts-context-commentstring",
    opts = {
      enable_autocmd = false,
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
  },
  
  -- Navegación
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    }
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
    }
  },
  
  -- Git
  "lewis6991/gitsigns.nvim",
  
  -- Tema
  {
    "morhetz/gruvbox",
    config = function()
      vim.cmd("colorscheme gruvbox")
    end
  },
})

-- Configuración de LSP
require("mason").setup()
require("mason-lspconfig").setup({
  ensure_installed = {
    -- Python
    "pyright",
    "ruff",
    -- TypeScript/JavaScript
    "ts_ls",
    "eslint",
    -- Otros
    "jdtls",  -- Añade esta línea
    "lua_ls",
    "cssls",
    "html",
    "jsonls",
  },
  automatic_installation = true,
})

local lspconfig = require('lspconfig')


-- Función común para configurar keymaps LSP
local function on_attach(client, bufnr)
  local opts = { noremap = true, silent = true }
  vim.api.nvim_buf_set_keymap(bufnr, "n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>", opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>rn", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>ca", "<cmd>lua vim.lsp.buf.code_action()<CR>", opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>f", "<cmd>lua vim.lsp.buf.format()<CR>", opts)
end

-- Configuración de Python (pyright)
lspconfig.pyright.setup({
  on_attach = on_attach,
  settings = {
    python = {
      analysis = {
        typeCheckingMode = "basic",
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
      },
    },
  },
  capabilities = require("cmp_nvim_lsp").default_capabilities(),
})

-- Configuración de ruff (actualizado de ruff_lsp)
lspconfig.ruff.setup({
  on_attach = on_attach,
  init_options = {
    settings = {
      -- Configuración de ruff
      format = {
        args = {},
      },
    },
  },
})

-- Configuración de TypeScript
lspconfig.ts_ls.setup({
  on_attach = on_attach,
  capabilities = require("cmp_nvim_lsp").default_capabilities(),
})

-- Configuración de completion
local cmp = require("cmp")
local luasnip = require("luasnip")
require("luasnip.loaders.from_vscode").lazy_load()

cmp.setup({
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert({
    ["<C-b>"] = cmp.mapping.scroll_docs(-4),
    ["<C-f>"] = cmp.mapping.scroll_docs(4),
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<C-e>"] = cmp.mapping.abort(),
    ["<CR>"] = cmp.mapping.confirm({ select = true }),
    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { "i", "s" }),
  }),
  sources = cmp.config.sources({
    { name = "nvim_lsp" },
    { name = "luasnip" },
    { name = "buffer" },
    { name = "path" },
  }),
})


-- Configuración específica para Java
-- Configuración específica para Java con JDTLS
local jdtls = require('jdtls')

-- Directorios base
local home = vim.fn.expand("~")
local mason_path = home .. "/.local/share/nvim/mason"
local jdtls_path = mason_path .. "/packages/jdtls"
local launcher_jar = jdtls_path .. "/plugins/org.eclipse.equinox.launcher_1.6.900.v20240613-2009.jar"

-- Seleccionar la configuración correcta dependiendo del sistema operativo
local config_path = jdtls_path .. "/config_"
if vim.fn.has("mac") == 1 then
    config_path = config_path .. "mac"
elseif vim.fn.has("unix") == 1 then
    config_path = config_path .. "linux"
else
    config_path = config_path .. "win"
end

-- Validar la existencia de los archivos necesarios
local function file_exists(path)
  local f = io.open(path, "r")
  if f then f:close() return true else return false end
end

if not file_exists(launcher_jar) then
  vim.notify("JDTLS launcher jar not found at: " .. launcher_jar, vim.log.levels.ERROR)
  return
end

if not file_exists(config_path) then
  vim.notify("JDTLS configuration not found at: " .. config_path, vim.log.levels.ERROR)
  return
end


-- Configuración de JDTLS
local jdtls_config = {
  cmd = {
      'java',
      '-Declipse.application=org.eclipse.jdt.ls.core.id1',
      '-Dosgi.bundles.defaultStartLevel=4',
      '-Declipse.product=org.eclipse.jdt.ls.core.product',
      '-Dlog.protocol=true',
      '-Dlog.level=ALL',
      '-Xms1g',
      '--add-modules=ALL-SYSTEM',
      '--add-opens', 'java.base/java.util=ALL-UNNAMED',
      '--add-opens', 'java.base/java.lang=ALL-UNNAMED',
      '-jar', launcher_jar,
      '-configuration', config_path,
      '-data', home .. '/.cache/jdtls-workspace/' .. vim.fn.getcwd():gsub("/", "-")
  },
  root_dir = require('jdtls.setup').find_root({'.git', 'mvnw', 'gradlew', 'pom.xml'}),
  settings = {
      java = {
          configuration = {
              runtimes = {
                  {
                      name = "JavaSE-21",
                      path = home .. "/.sdkman/candidates/java/21.0.5-oracle",
                  }
              },
          },
      },
  },
  init_options = {
      bundles = {}
  },
  capabilities = require('cmp_nvim_lsp').default_capabilities()
}

-- Iniciar JDTLS

-- Keymaps específicos para Java
local function jdtls_keymaps()
  local opts = { noremap=true, silent=true, buffer=vim.api.nvim_get_current_buf() }
  vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
  vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
  vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
  vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
  vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
  vim.keymap.set('n', '<leader>wa', vim.lsp.buf.add_workspace_folder, opts)
  vim.keymap.set('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder, opts)
  vim.keymap.set('n', '<leader>wl', function() print(vim.inspect(vim.lsp.buf.list_workspace_folders())) end, opts)
  vim.keymap.set('n', '<leader>D', vim.lsp.buf.type_definition, opts)
  vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
  vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
  vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
  vim.keymap.set('n', '<leader>f', function() vim.lsp.buf.format { async = true } end, opts)
  
  -- JDTLS specific
  vim.keymap.set('n', '<leader>di', require('jdtls').organize_imports, opts)
  vim.keymap.set('n', '<leader>dt', require('jdtls').test_class, opts)
  vim.keymap.set('n', '<leader>dn', require('jdtls').test_nearest_method, opts)
  vim.keymap.set('n', '<leader>dm', require('jdtls').extract_method, opts)
  vim.keymap.set('n', '<leader>dc', require('jdtls').extract_constant, opts)
  vim.keymap.set('v', '<leader>dm', [[<ESC><CMD>lua require('jdtls').extract_method(true)<CR>]], opts)
end

-- Autocomandos para Java
vim.api.nvim_create_autocmd("FileType", {
  pattern = "java",
  callback = function()
      require('jdtls').start_or_attach(jdtls_config)
      jdtls_keymaps()
  end
})
-- Configuración de null-ls
local null_ls = require("null-ls")
null_ls.setup({
  sources = {
    -- Python
    null_ls.builtins.formatting.black,
    null_ls.builtins.formatting.isort,
    -- TypeScript/JavaScript
    null_ls.builtins.formatting.prettier,
    null_ls.builtins.diagnostics.eslint,
  },
})

-- Configuración de DAP para Python
local dap = require("dap")
local dapui = require("dapui")

dapui.setup()
require("dap-python").setup()

-- Configuración de Treesitter
require("nvim-treesitter.configs").setup({
  ensure_installed = {
    "python",
    "typescript",
    "javascript",
    "tsx",
    "html",
    "css",
    "json",
    "lua",
  },
  highlight = {
    enable = true,
  },
  indent = {
    enable = true,
  },
})

-- Configuración de ts_context_commentstring
require('ts_context_commentstring').setup({})

-- Configuración de Comment.nvim
require('Comment').setup({
  pre_hook = require('ts_context_commentstring').pre_hook,
})

-- Configuración de Telescope
require("telescope").setup({
  defaults = {
    file_ignore_patterns = {
      "node_modules",
      ".git",
      "dist",
      ".next",
      "__pycache__",
      ".pytest_cache",
      "*.pyc",
      "venv",
      ".venv",
    },
  },
})

-- Configuración de 
require("neo-tree").setup({
  filesystem = {
    filtered_items = {
      visible = false,
      hide_dotfiles = false,
      hide_gitignored = true,
      hide_by_pattern = {
        "__pycache__",
        ".pytest_cache",
        "*.pyc",
      },
    },
  },
})

-- Configuración de autopairs
require("nvim-autopairs").setup({})

-- Configuración de Gitsigns
require("gitsigns").setup()

-- Keymaps globales
local opts = { noremap = true, silent = true }
-- Telescope
vim.keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<CR>", opts)
vim.keymap.set("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", opts)
vim.keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<CR>", opts)
-- Neo-tree
vim.keymap.set("n", "<leader>e", "<cmd>Neotree toggle<CR>", opts)
-- Navegación entre ventanas
vim.keymap.set("n", "<leader>h", "<C-w>h", opts)
vim.keymap.set("n", "<leader>l", "<C-w>l", opts)
vim.keymap.set("n", "<leader>k", "<C-w>k", opts)
vim.keymap.set("n", "<leader>j", "<C-w>j", opts)
-- Python específico
vim.keymap.set("n", "<leader>vs", "<cmd>VenvSelect<cr>", opts)
vim.keymap.set("n", "<leader>vc", "<cmd>VenvSelectCached<cr>", opts)
-- Debug
vim.keymap.set("n", "<leader>db", "<cmd>lua require'dap'.toggle_breakpoint()<CR>", opts)
vim.keymap.set("n", "<leader>dc", "<cmd>lua require'dap'.continue()<CR>", opts)
vim.keymap.set("n", "<leader>do", "<cmd>lua require'dap'.step_over()<CR>", opts)
vim.keymap.set("n", "<leader>di", "<cmd>lua require'dap'.step_into()<CR>", opts)

-- Autocomandos
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = { "*.ts", "*.tsx", "*.js", "*.jsx" },
  callback = function()
    vim.lsp.buf.format({ async = false })
  end,
})

-- Configuración específica para archivos Python
vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    vim.opt_local.expandtab = true
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
    vim.opt_local.softtabstop = 4
  end,
})

local config = {
    cmd = {
        "java",
        "-Declipse.application=org.eclipse.jdt.ls.core.id1",
        "-Dosgi.bundles.defaultStartLevel=4",
        "-Declipse.product=org.eclipse.jdt.ls.core.product",
        "-Dlog.protocol=true",
        "-Dlog.level=ALL",
        "-Xmx4g",
        "--add-modules=ALL-SYSTEM",
        "--add-opens", "java.base/java.util=ALL-UNNAMED",
        "--add-opens", "java.base/java.lang=ALL-UNNAMED",
        "-jar", vim.fn.glob(vim.fn.stdpath("data") .. "/mason/packages/jdtls/plugins/org.eclipse.equinox.launcher_*.jar"),
        "-configuration", vim.fn.stdpath("data") .. "/mason/packages/jdtls/config_linux",
        "-data", "/home/oak/workspace"
    },
    root_dir = require("jdtls.setup").find_root({".git", "mvnw", "gradlew"}),
    settings = {
        java = {
            signatureHelp = { enabled = true },
            contentProvider = { preferred = "fernflower" },
            sources = {
                organizeImports = {
                    starThreshold = 9999,
                    staticStarThreshold = 9999,
                }
            },
            configuration = {
                runtimes = {
                    {
                        name = "JavaSE-17",
                        path = "",
                    },
                    {
                        name = "JavaSE-21",
                        path = "/home/oak/.sdkman/candidates/java/21.0.5-oracle",
                    }
                }
            }
        }
    }
}



local config = {
    cmd = {
        "java",
        "-Declipse.application=org.eclipse.jdt.ls.core.id1",
        "-Dosgi.bundles.defaultStartLevel=4",
        "-Declipse.product=org.eclipse.jdt.ls.core.product",
        "-Dlog.protocol=true",
        "-Dlog.level=ALL",
        "-Xmx4g",
        "--add-modules=ALL-SYSTEM",
        "--add-opens", "java.base/java.util=ALL-UNNAMED",
        "--add-opens", "java.base/java.lang=ALL-UNNAMED",
        "-jar", vim.fn.glob(vim.fn.stdpath("data") .. "/mason/packages/jdtls/plugins/org.eclipse.equinox.launcher_*.jar"),
        "-configuration", vim.fn.stdpath("data") .. "/mason/packages/jdtls/config_linux",
        "-data", "/home/oak/workspace"
    },
    root_dir = require("jdtls.setup").find_root({".git", "mvnw", "gradlew"}),
    settings = {
        java = {
            signatureHelp = { enabled = true },
            contentProvider = { preferred = "fernflower" },
            sources = {
                organizeImports = {
                    starThreshold = 9999,
                    staticStarThreshold = 9999,
                }
            },
            configuration = {
                runtimes = {
                    {
                        name = "JavaSE-17",
                        path = "",
                    },
                    {
                        name = "JavaSE-21",
                        path = "/home/oak/.sdkman/candidates/java/21.0.5-oracle",
                    }
                }
            }
        }
    },
    init_options = {
        bundles = {}
    }
}

-- Configuración adicional para evitar errores de inicialización
vim.api.nvim_create_autocmd("FileType", {
    pattern = "java",
    callback = function()
    end,
})


local config = {
    cmd = {
        "java",
        "-Declipse.application=org.eclipse.jdt.ls.core.id1",
        "-Dosgi.bundles.defaultStartLevel=4",
        "-Declipse.product=org.eclipse.jdt.ls.core.product",
        "-Dlog.protocol=true",
        "-Dlog.level=ALL",
        "-Xmx4g",
        "--add-modules=ALL-SYSTEM",
        "--add-opens", "java.base/java.util=ALL-UNNAMED",
        "--add-opens", "java.base/java.lang=ALL-UNNAMED",
        "-jar", vim.fn.glob(vim.fn.stdpath("data") .. "/mason/packages/jdtls/plugins/org.eclipse.equinox.launcher_*.jar"),
        "-configuration", vim.fn.stdpath("data") .. "/mason/packages/jdtls/config_linux",
        "-data", "/home/oak/workspace"
    },
    root_dir = require("jdtls.setup").find_root({".git", "mvnw", "gradlew"}),
    settings = {
        java = {
            signatureHelp = { enabled = true },
            contentProvider = { preferred = "fernflower" },
            sources = {
                organizeImports = {
                    starThreshold = 9999,
                    staticStarThreshold = 9999,
                }
            },
            configuration = {
                runtimes = {
                    {
                        name = "JavaSE-17",
                        path = "",
                    },
                    {
                        name = "JavaSE-21",
                        path = "/home/oak/.sdkman/candidates/java/21.0.5-oracle",
                    }
                }
            }
        }
    },
    init_options = {
        bundles = {}
    }
}

-- Configuración adicional para evitar errores de inicialización
vim.api.nvim_create_autocmd("FileType", {
    pattern = "java",
    callback = function()
    end,
})


local config = {
    cmd = {
        "java",
        "-Declipse.application=org.eclipse.jdt.ls.core.id1",
        "-Dosgi.bundles.defaultStartLevel=4",
        "-Declipse.product=org.eclipse.jdt.ls.core.product",
        "-Dlog.protocol=true",
        "-Dlog.level=ALL",
        "-Xmx4g",
        "--add-modules=ALL-SYSTEM",
        "--add-opens", "java.base/java.util=ALL-UNNAMED",
        "--add-opens", "java.base/java.lang=ALL-UNNAMED",
        "-jar", vim.fn.glob(vim.fn.stdpath("data") .. "/mason/packages/jdtls/plugins/org.eclipse.equinox.launcher_*.jar"),
        "-configuration", vim.fn.stdpath("data") .. "/mason/packages/jdtls/config_linux",
        "-data", vim.fn.stdpath("data") .. "/jdtls_workspace"
    },
    root_dir = jdtls.setup.find_root({".git", "mvnw", "gradlew"}),
    settings = {
        java = {
            signatureHelp = { enabled = true },
            contentProvider = { preferred = "fernflower" },
            configuration = {
                runtimes = {
                    {
                        name = "JavaSE-17",
                        path = "/usr/lib/jvm/default",
                    }
                }
            }
        }
    },
    init_options = {
        bundles = {}
    }
}

vim.api.nvim_create_autocmd("FileType", {
    pattern = "java",
    callback = function()
        if vim.bo.filetype == "java" and vim.fn.bufname() ~= "" then

local jdtls = require("jdtls")
local config = {
    cmd = {
        "java",
        "-Declipse.application=org.eclipse.jdt.ls.core.id1",
        "-Dosgi.bundles.defaultStartLevel=4",
        "-Declipse.product=org.eclipse.jdt.ls.core.product",
        "-Dlog.protocol=true",
        "-Dlog.level=ALL",
        "-Xmx4g",
        "--add-modules=ALL-SYSTEM",
        "--add-opens", "java.base/java.util=ALL-UNNAMED",
        "--add-opens", "java.base/java.lang=ALL-UNNAMED",
        "-jar", vim.fn.glob(vim.fn.stdpath("data") .. "/mason/packages/jdtls/plugins/org.eclipse.equinox.launcher_*.jar"),
        "-configuration", vim.fn.stdpath("data") .. "/mason/packages/jdtls/config_linux",
        "-data", vim.fn.stdpath("data") .. "/jdtls_workspace"
    },
    root_dir = jdtls.setup.find_root({".git", "mvnw", "gradlew"}),
    settings = {
        java = {
            signatureHelp = { enabled = true },
            contentProvider = { preferred = "fernflower" },
            configuration = {
                runtimes = {
                    {
                        name = "JavaSE-17",
                        path = "/usr/lib/jvm/default",
                    }
                }
            }
        }
    },
    init_options = {
        bundles = {}
    }
}

vim.api.nvim_create_autocmd("FileType", {
    pattern = "java",
    callback = function()
        if vim.bo.filetype == "java" and vim.fn.bufname() ~= "" then
            jdtls.start_or_attach(config)
        end
    end,
})
