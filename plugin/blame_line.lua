-- @file blame_line.lua
-- @author Braxton Salyer <braxtonsalyer@gmail.com>
-- @brief blame_line.nvim is a simple and configurable "git blame" line for Neovim 0.7+
-- @version 0.1
-- @date 2022-06-12
--
-- MIT License
-- @copyright Copyright (c) 2022 Braxton Salyer <braxtonsalyer@gmail.com>
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
-- INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE,
-- AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
-- DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

-- only load the plugin once
if vim.g.loaded_blame_line then
	return
end
vim.g.loaded_blame_line = true

-- we require nvim_create_autocmd (neovim 0.7)
if not vim.api.nvim_create_autocmd then
	vim.notify("[blame-line.nvim] Your nvim does not have the \"nvim_create_autocmd\" function. \
			   Please update to a newer nvim", vim.log.levels.ERROR)
	return
end

vim.api.nvim_create_augroup("blame_line", { clear = true })
vim.api.nvim_create_autocmd(
	{ "BufEnter", "WinClosed" },
	{
		desc = "Update the blame line",
		pattern = { "*" },
		callback = function()
			if vim.bo.buftype ~= "" then
				return
			end
			require("blame_line").__detail.on_buf_enter()
		end,
		group = "blame_line",
	}
)
vim.api.nvim_create_autocmd(
	"BufLeave",
	{
		desc = "Update the blame line",
		pattern = { "*" },
		callback = function()
			require("blame_line").__detail.on_buf_leave()
		end,
		group = "blame_line",
	}
)
vim.api.nvim_create_autocmd(
	{ "BufEnter", "BufWritePost", "CursorMoved" },
	{
		desc = "Update the blame line",
		pattern = { "*" },
		callback = function()
			require("blame_line").__detail.refresh()
		end,
		group = "blame_line",
	}
)

-- if showing in insert mode is disabled, add autocmds to check for insert enter/leave and
-- disable/enable the blame line appropriately
if not require("blame_line").__detail.config.show_in_insert then
	vim.api.nvim_create_autocmd(
		"InsertEnter",
		{
			desc = "Disable blame line in insert mode",
			pattern = { "*" },
			callback = function()
				require("blame_line").__detail.disable_show()
			end,
			group = "blame_line",
		}
	)
	vim.api.nvim_create_autocmd(
		"InsertLeave",
		{
			desc = "Disable blame line in insert mode",
			pattern = { "*" },
			callback = function()
				require("blame_line").__detail.enable_show()
			end,
			group = "blame_line",
		}
	)
end

vim.api.nvim_create_user_command(
	"BlameLineEnable",
	function()
		require("blame_line").enable()
	end,
	{
		desc = [[Enable blame_line.nvim.
				 Enables the blame line for files tracked by git in modes valid for the current configuration
				 (@see `blame_line.config.show_in_insert` and @see `blame_line.config.show_in_visual`).
				 By default the blame line is enabled]]
	}
)

vim.api.nvim_create_user_command(
	"BlameLineDisable",
	function()
		require("blame_line").disable()
	end,
	{
		desc = [[Disables the blame line completely until the user calls
				 `BlameLineEnable` or `lua require("blame_line").enable()`
				 to re-enable the blame line. The blame line is enabled by default.]]
	}
)

vim.api.nvim_create_user_command(
	"BlameLineToggle",
	function()
		local blame_line = require("blame_line")
		if blame_line.__detail.enabled then
			blame_line.disable()
		else
			blame_line.enable()
		end
	end,
	{
		desc = [[Toggles whether the blame line is enabled.
				 Equivalent to calling `BlameLineEnable` if the blame line is disabled
				 or `BlameLineDisable` if it is enabled. The blame line is enabled by default.]]
	}
)

vim.cmd("highlight default link " .. require("blame_line").__detail.config.hl_group .. " Comment")
