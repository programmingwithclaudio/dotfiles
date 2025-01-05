-- ~/.config/nvim/init.lua
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
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
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

-- Plugins
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
        },
    },
    
    -- Temas y UI
    {
        "morhetz/gruvbox",
        config = function()
            vim.cmd("colorscheme gruvbox")
        end
    },
    
    -- Utilidades
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    {
        "nvim-telescope/telescope.nvim",
        branch = "0.1.x",
        dependencies = {"nvim-lua/plenary.nvim"}
    },
})

-- Configuración de LSP
require("mason").setup()
require("mason-lspconfig").setup({
    ensure_installed = {
        "jdtls",
        "lua_ls",
    },
})

-- Configuración de completion
local cmp = require('cmp')
local luasnip = require('luasnip')

cmp.setup({
    snippet = {
        expand = function(args)
            luasnip.lsp_expand(args.body)
        end,
    },
    mapping = cmp.mapping.preset.insert({
        ['<C-b>'] = cmp.mapping.scroll_docs(-4),
        ['<C-f>'] = cmp.mapping.scroll_docs(4),
        ['<C-Space>'] = cmp.mapping.complete(),
        ['<C-e>'] = cmp.mapping.abort(),
        ['<CR>'] = cmp.mapping.confirm({ select = true }),
    }),
    sources = cmp.config.sources({
        { name = 'nvim_lsp' },
        { name = 'luasnip' },
        { name = 'buffer' },
        { name = 'path' },
    }),
})

-- Configuración específica para Java
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
        '-jar', vim.fn.expand('~/.local/share/nvim/mason/packages/jdtls/plugins/org.eclipse.equinox.launcher.jar'),
        '-configuration', vim.fn.expand('~/.local/share/nvim/mason/packages/jdtls/config_linux'),
        '-data', vim.fn.expand('~/.cache/jdtls-workspace') .. vim.fn.getcwd():gsub("/", "-")
    },
    
    root_dir = require('jdtls.setup').find_root({'.git', 'mvnw', 'gradlew'}),
    
    settings = {
        java = {
            configuration = {
                runtimes = {
                    {
                        name = "JavaSE-17",
                        path = vim.fn.expand("~/.sdkman/candidates/java/17.0.12-oracle"),
                    },
                    {
                        name = "JavaSE-21",
                        path = vim.fn.expand("~/.sdkman/candidates/java/21.0.5-oracle"),
                    },
                },
            },
            eclipse = {
                downloadSources = true,
            },
            maven = {
                downloadSources = true,
            },
            implementationsCodeLens = {
                enabled = true,
            },
            referencesCodeLens = {
                enabled = true,
            },
            references = {
                includeDecompiledSources = true,
            },
            format = {
                enabled = true,
                settings = {
                    url = vim.fn.stdpath("config") .. "/language-servers/java-format.xml",
                },
            },
        },
        signatureHelp = { enabled = true },
        completion = {
            favoriteStaticMembers = {
                "org.junit.Assert.*",
                "org.junit.Assume.*",
                "org.junit.jupiter.api.Assertions.*",
                "org.junit.jupiter.api.Assumptions.*",
                "org.junit.jupiter.api.DynamicContainer.*",
                "org.junit.jupiter.api.DynamicTest.*",
            },
        },
        contentProvider = { preferred = 'fernflower' },
        extendedClientCapabilities = require('jdtls').extendedClientCapabilities,
        sources = {
            organizeImports = {
                starThreshold = 9999,
                staticStarThreshold = 9999,
            },
        },
        codeGeneration = {
            toString = {
                template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}",
            },
            useBlocks = true,
        },
    },
    
    flags = {
        allow_incremental_sync = true,
    },
    
    capabilities = require('cmp_nvim_lsp').default_capabilities(),
}

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
    vim.keymap.set('n', '<leader>di', jdtls.organize_imports, opts)
    vim.keymap.set('n', '<leader>dt', jdtls.test_class, opts)
    vim.keymap.set('n', '<leader>dn', jdtls.test_nearest_method, opts)
    vim.keymap.set('n', '<leader>dm', jdtls.extract_method, opts)
    vim.keymap.set('n', '<leader>dc', jdtls.extract_constant, opts)
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
