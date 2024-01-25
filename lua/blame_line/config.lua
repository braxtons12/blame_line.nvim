-- @file config.lua
-- @author Braxton Salyer <braxtonsalyer@gmail.com>
-- @brief Configuration of blame_line.nvim
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

-- the config module
local config = {}
-- import type_check so we can ensure our parameters are the correct types
local type_check = require("blame_line.type_check")

--  Whether the blame line should be shown when in visual mode.
--  Can be `true` or `false`. Default `true`
config.show_in_visual = true
--  Whether the blame line should be shown when in insert mode.
--  Cane be `true` or `false`. Default `true`
config.show_in_insert = true
-- The prefix to prepend to the blame line.
-- Any string. Default `" "`
config.prefix = " "
-- The template for the blame line message.
-- Any string containing `<author>`, `<author-mail>`, `<author-time>`, `<committer>`,
-- `<committer-mail>`, `<committer-time>`, `<summary>`, `<commit-short>`, and/or `<commit-long>`
-- Default `"<author> • <author-time> • <summary>"`
config.template = {
	[1] = {
		is_template = true,
		string = "author",
	},
	[2] = {
		is_template = false,
		string = " • ",
	},
	[3] = {
		is_template = true,
		string = "author-time",
	},
	[4] = {
		is_template = false,
		string = " • ",
	},
	[5] = {
		is_template = true,
		string = "summary",
	},
}
-- The date configuration for the blame line date formatting.
-- Default `{ relative = true, format = "%d-%m-%y"}`
config.date = {
	-- Whether the date should be relative instead of fixed.
	-- I.E. "3 days ago" instead of "08-06-2022"
	relative = true,
	-- The format of the date if `relative == false`.
	-- Any format string compatible w/ `strftime`
	-- Default "%d-%m-%y"
	format = "%d-%m-%y",
}
-- The highlight group to use for the blame line.
-- Default "BlameLineNvim"
config.hl_group = "BlameLineNvim"

-- The delay before the blame_line should be shown/updated
-- Default 0
config.delay = 0

-- Sets whether the blame line should be shown in visual mode.
-- @param show - Whether to show the blame line in visual mode. `true` or `false`
config.set_show_in_visual = function(show)
	if show ~= nil then
		type_check.check(show, "boolean", "show_in_visual", "config", "setup")
		config.show_in_visual = show
	end
end

-- Sets whether the blame line should be shown in insert mode.
-- @param show - Whether to show the blame line in insert mode. `true` or `false`
config.set_show_in_insert = function(show)
	if show ~= nil then
		type_check.check(show, "boolean", "show_in_insert", "config", "setup")
		config.show_in_insert = show
	end
end

-- Sets the prefix string for the blame line.
-- @param show - The prefix string of the blame line. Any string
config.set_prefix = function(prefix)
	if prefix ~= nil then
		type_check.check(prefix, "string", "prefix", "config", "setup")
		config.prefix = prefix
	end
end

-- Sets the template string for the blame line.
-- @param template - The template string of the blame line. Any string containing `<author>`,
-- `<author-mail>`, `<author-time>`, `<committer>`, `<committer-mail>`, `<committer-time>`,
-- `<summary>`, `<commit-short>`, and/or `<commit-long>`
config.set_template = function(template)
	if template ~= nil then
		type_check.check(template, "string", "template", "config", "setup")
		local stop = false
		local start = 0
		local _end = 1
		config.template = {}
		while not stop do
			local old_end = _end
			start, _end = string.find(template, "<.->", old_end)
			if start then
				if start > old_end then
					table.insert(config.template, {
						is_template = false,
						string = string.sub(template, old_end + 1, start - 1)
					})
				end
				table.insert(config.template, {
						is_template = true,
						string = string.sub(template, start + 1, _end - 1),
					})
			else
				table.insert(config.template, {
					is_template = false,
					string = string.sub(template, old_end + 1, string.len(template))
				})

				stop = true
			end
		end
	end
end

config.set_date = function(date)
	if date ~= nil then
		local relative = date.relative == nil and config.date.relative or date.relative
		local format = date.format or config.date.format
		type_check.check(relative, "boolean", "date.relative", "config", "setup")
		type_check.check(format, "string", "date.format", "config", "setup")

		config.date.relative = relative
		config.date.format = format
	end
end

config.set_hl_group = function(hl_group)
	if hl_group ~= nil then
		type_check.check(hl_group, "string", "hl_group", "config", "setup")
		config.hl_group = hl_group
	end
end

config.set_delay = function(delay)
	if delay ~= nil then
		type_check.check(delay, "number", "delay", "config", "setup")
		config.delay = delay
	end
end

return config
