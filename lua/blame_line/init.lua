-- @file init.lua
-- @author Braxton Salyer <braxtonsalyer@gmail.com>
-- @brief Entry point to blame_line.nvim plugin
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

-- the blame_line module
local blame_line = {}
-- our implementation details
blame_line.__detail = {}
blame_line.__detail.config = require("blame_line.config")
-- pull in type_check so we can ensure function parameters are the correct types
local type_check = require("blame_line.type_check")

-- Configures blame_line.nvim with the settings in the given `config` table
--
-- @param config: table - The table containing the configuration for the blame line.
-- Possible entries:
--
-- - show_in_visual: boolean - Whether the blame_line should be shown in visual modes.
-- Default `true`
-- - show_in_insert: boolean - Whether the blame_line should be shown in insert modes.
-- Default `true`
-- - prefix: string - String specifying the prefix, if any, that should be shown at the
-- beginning of the blame line. Default `" "`
-- - template: string - String specifying the the blame line format.
-- Can be any combination of the following specifiers, along with any additional text.
-- Excludes the prefix.
--     - `"<author>"` - the author of the change.
--     - `"<author-mail>"` - the email of the author.
--     - `"<author-time>"` - the time the author made the change.
--     - `"<committer>"` - the person who committed the change to the repository.
--     - `"<committer-mail>"` - the email of the committer.
--     - `"<committer-time>"` - the time the change was committed to the repository.
--     - `"<summary>"` - the commit summary/message.
--     - `"<commit-short>"` - short portion of the commit hash.
--     - `"<commit-long>"` - the full commit hash.
-- Default `"<author> • <author-time> • <summary>"`
-- - date: table - The date format settings, for `"<author-time>"` and `"<committer-time>"`
--     - relative: boolean - whether the date should be relative instead of precise
--     (I.E. "3 days ago" instead of "09-06-2022". Default `true`
--     - format: string - any `strftime` compatible format string. Default `"%d-%m-%y"`
-- - hl_group: string - The name for the highlight group associated with the blame line.
-- Default `"BlameLineNvim"`
-- - delay: number - the delay in milliseconds before the blame line should be updated.
-- Default `0`
--
-- @usage
--     require("blame_line").setup {
--         show_in_visual = true,
--         show_in_insert = true,
--         prefix = " ",
--         template = "<author> • <author-time> • <summary>",
--         date = {
--             relative = true,
--             format = "%d-%m-%y",
--         },
--         hl_group = "BlameLineNvim",
--         delay = 0,
--     }
-- @function blame_line.setup(config)
blame_line.setup = function(config)
	if config ~= nil then
		if config.show_in_visual ~= nil then
			blame_line.__detail.config.set_show_in_visual(config.show_in_visual)
		end
		if config.show_in_insert ~= nil then
			blame_line.__detail.config.set_show_in_insert(config.show_in_insert)
		end
		if config.prefix ~= nil then
			blame_line.__detail.config.set_prefix(config.prefix)
		end
		if config.template ~= nil then
			blame_line.__detail.config.set_template(config.template)
		end
		if config.date ~= nil then
			blame_line.__detail.config.set_date(config.date)
		end
		if config.hl_group ~= nil then
			blame_line.__detail.config.set_hl_group(config.hl_group)
		end
		if config.delay ~= nil then
			blame_line.__detail.config.set_delay(config.delay)
		end
	end
end

blame_line.__detail.enabled = true
-- the buffer might not be enabled even if we are (eg, if not in a git repo)
blame_line.__detail.buffer_enabled = false
-- showing not be enabled even if we are (eg, if not in a git repo)
blame_line.__detail.show_enabled = false
-- git user name of the current user, used to check and replace w/ "You" if committer/author matches
blame_line.__detail.user_name = ""
-- git user email of the current user, used to check and replace w/ "You" if committer/author email matches
blame_line.__detail.user_email = ""

if vim.api.nvim_create_namespace then
	blame_line.__detail.namespace = vim.api.nvim_create_namespace("blame_line")
else
	vim.notify("[blame_line.nvim] your nvim doesn't support `nvim_create_namespace`,\
		  	   please update to a newer nvim", vim.log.levels.ERROR)
end

-- Checks if we're running on windows
-- @return boolean
-- @function blame_line.__detail.os_is_windows()
blame_line.__detail.os_is_windows = function()
	return vim.loop.os_uname().sysname == "Windows"
end

-- Converts a commit time to a string representing a time relative to the current time
-- (e.g. convert 163587981 to "3 days ago")
--
-- @param commit_time: number - The commit timestamp
-- @return string
-- @function blame_line.__detail.get_relative_time(commit_time)
blame_line.__detail.get_relative_time = function(commit_time)
	type_check.check(commit_time, "number", "commit_time", "blame_line", "get_relative_time")
	local current_time = vim.fn.localtime()
	local elapsed = current_time - commit_time

	local seconds_in_minute = 60
	local seconds_in_hour = 3600
	local seconds_in_day = 86400
	local seconds_in_month = 2592000
	local seconds_in_year = 31104000

	if elapsed == 0 then
		return "now"
	end

	local function to_plural(word, number)
		if number > 1 then
			return word .. "s"
		end

		return word
	end

	local function to_relative_string(time, divisor, time_word)
		local as_number = vim.fn.float2nr(vim.fn.round(time / divisor))
		return vim.fn.string(as_number) .. to_plural(" " .. time_word, as_number) .. " ago"
	end

	if elapsed < seconds_in_minute then
		return to_relative_string(elapsed, 1, "second")
	elseif elapsed < seconds_in_hour then
		return to_relative_string(elapsed, seconds_in_minute, "minute")
	elseif elapsed < seconds_in_day then
		return to_relative_string(elapsed, seconds_in_hour, "hour")
	elseif elapsed < seconds_in_month then
		return to_relative_string(elapsed, seconds_in_day, "day")
	elseif elapsed < seconds_in_year then
		return to_relative_string(elapsed, seconds_in_month, "month")
	else
		return to_relative_string(elapsed, seconds_in_year, "year")
	end
end

-- Returns the range of lines the cursor is on or has selected (if in a visual mode)
--
-- @return number[] - The range of lines the cursor is on or has selected
-- @function blame_line.__detail.get_selected_or_hovered_lines()
blame_line.__detail.get_selected_or_hovered_lines = function()
	local cursor_line_number = vim.fn.line(".")

	return cursor_line_number
end

-- Converts the given table of `commit_data` to the blame line string
--
-- @param commit_data: table - The table of commit data, with keys as message template strings and
-- values as the associated string. e.g. `commit_data["author"] == "braxtons12"`
-- @return string - The blame line string
-- @function blame_line.__detail.convert_commit_data_to_string(commit_data)
blame_line.__detail.convert_commit_data_to_string = function(commit_data)
	local message = blame_line.__detail.config.prefix
	if commit_data ~= nil then
        local previous = nil
		for index = 1, #blame_line.__detail.config.template do
			local field = blame_line.__detail.config.template[index]
            if field.is_template then
                message = message .. commit_data[field.string]
            else
                -- skip punctuation (if any) after a template field that was empty
                local num_to_skip = 0
                if string.sub(field.string, 1, 1) == "," then
                    num_to_skip = num_to_skip + 1
                end
                if string.sub(field.string, 2, 2) == " " then
                    num_to_skip = num_to_skip + 1
                end

                if previous ~= nil
                   and num_to_skip ~= 0
                   and commit_data[previous.string] == "" then
                        message = message
                                  .. string.sub(field.string,
                                                num_to_skip + 1,
                                                string.len(field.string))
                else
                    message = message .. field.string
                end
            end
            previous = field
		end
	end

	return message
end

-- Splits a string on the given seperator pattern  and returns the resulting substrings as an
-- array of substrings as if returned by `string.gmatch(_string, "([^" .. separator .. "]+)")`
--
-- @param _string: string - the string to split
-- @param separator: string - The separator to split the string on
-- @return string[] - The substrings comprising the split string
-- @function blame_line.__detail.split_string(_string, separator)
blame_line.__detail.split_string = function(_string, separator)
	type_check.check(_string, "string", "string", "blame_line", "split_string")
	type_check.check(separator, "string", "separator", "blame_line", "split_string")

	separator = separator or "%s"
	local _table = {}
	for str in string.gmatch(_string, "([^" .. separator .. "]+)") do
		table.insert(_table, str)
	end

	return _table
end

-- Splits a commit data line returned from git blame into template/key, value pairs
-- (e.g. "author", "braxtons12")
--
-- @param str: string - the string to split
-- @param separator: string - The separator to split the string on. Probably should always be `" "`
-- @return string, string - The key, value pair of substrings comprising the original string
-- @function blame_line.__detail.split_commit_line(str, separator)
blame_line.__detail.split_commit_line = function(str, separator)
	type_check.check(str, "string", "string", "blame_line", "split_commit_line")
	type_check.check(separator, "string", "separator", "blame_line", "split_commit_line")

	local start, _end = string.find(str, separator)
	if start then
		return string.sub(str, 0, start - 1), string.sub(str, _end + 1, string.len(str))
	end

	return str, ""
end

-- Parses an author or committer line (line 2 or 6, 1-indexed) returned from git blame and returns
-- the corresponding key,value pair
--
-- @param line: string - the line to parse
-- @return string, string - The key, value pair for the line
-- @function blame_line.__detail.parse_commit_committer_or_author_line(line)
blame_line.__detail.parse_commit_committer_or_author_line = function(line)
	type_check.check(line, "string", "line", "blame_line", "parse_commit_committer_or_author_line")
	local property, value = blame_line.__detail.split_commit_line(line, " ")

	value = vim.fn.escape(value, "&")
	value = vim.fn.escape(value, "~")

	local contains_user_name, _ = string.find(value, blame_line.__detail.user_name)
	local not_committed_yet, _ = string.find(value, "Not Committed Yet")
	if contains_user_name or not_committed_yet then
		value = "You"
	end

	return property, value
end

-- Parses an author or committer email line (line 3 or 7, 1-indexed) returned from git blame and
-- returns the corresponding key,value pair
--
-- @param line: string - the line to parse
-- @return string, string - The key, value pair for the line
-- @function blame_line.__detail.parse_commit_committer_or_author_email_line(line)
blame_line.__detail.parse_commit_committer_or_author_email_line = function(line)
	type_check.check(line, "string", "line", "blame_line", "parse_commit_committer_or_author_email_line")
	local property, value = blame_line.__detail.split_commit_line(line, " ")

	value = vim.fn.escape(value, "&")
	value = vim.fn.escape(value, "~")

	local contains_user_email, _ = string.find(value, blame_line.__detail.user_name)
	local not_committed_yet, _ = string.find(value, "not%.committed%.yet")
	if contains_user_email or not_committed_yet then
		value = "You"
	end

	return property, value
end

-- Parses the commit summary line (line 10, 1-indexed) returned from git blame and
-- returns the corresponding key,value pair
--
-- @param line: string - the line to parse
-- @return string, string - The key, value pair for the line
-- @function blame_line.__detail.parse_commit_summary_line(line)
blame_line.__detail.parse_commit_summary_line = function(line)
	type_check.check(line, "string", "line", "blame_line", "parse_commit_summary_line")
	local property, value = blame_line.__detail.split_commit_line(line, " ")

	value = vim.fn.escape(value, "&")
	value = vim.fn.escape(value, "~")

	return property, value
end

-- Parses an author or committer timestamp line (line 4 or 8, 1-indexed) returned from git blame and
-- returns the corresponding key,value pair
--
-- @param line: string - the line to parse
-- @return string, string - The key, value pair for the line
-- @function blame_line.__detail.parse_commit_time_line(line)
blame_line.__detail.parse_commit_time_line = function(line)
	type_check.check(line, "string", "line", "blame_line", "parse_commit_time_line")
	local property, value = blame_line.__detail.split_commit_line(line, " ")
	local contains_time, _ = string.find(property, "time")
	if contains_time then
		if blame_line.__detail.config.date.relative then
			value = blame_line.__detail.get_relative_time(tonumber(value))
		else
			value = vim.fn.strftime(blame_line.__detail.config.date.format, tonumber(value))
		end
	end

	value = vim.fn.escape(value, "&")
	value = vim.fn.escape(value, "~")

	return property, value
end

-- Replaces the platform-specific path separators, if any, in the given `path` with POSIX compliant
-- separators (e.g. replaces any/all "\\" with "/")
--
-- @param path: string - the path to POSIX-ize
-- @return string - the corrected path
-- @function blame_line.__detail.substitute_path_separator(path)
blame_line.__detail.substitute_path_separator = function(path)
	type_check.check(path, "string", "path", "blame_line", "substitute_path_separator")
	if blame_line.__detail.os_is_windows() then
		return string.gsub(path, "\\", "/")
	end

	return path
end

-- Retrieves the git blame/commit data for the given sequence of lines in `file`, returned as an
-- array of tables
--
-- @param file: string - the file path of the file to pass to git blame
-- @param line_number: number - the start line to get blame data for
-- @param line_count: number - the number of lines to get blame data for
-- @return table[] - the commit data, in the format;
--     {
--         [1] = {
--             ["author"] = "braxtons12",
--             ["author-mail"] = "<braxtonsalyer@gmail.com>",
--             ["author-time"] = "16293480",
--             ["committer"] = "braxtons12",
--             ["committer-mail"] = "<braxtonsalyer@gmail.com>",
--             ["committer-time"] = "16293480",
--             ["commit-short"] = "1bc4adf",
--             ["commit-long"] = "1bc4adf...fda", -- 40 chars
--             ["summary"] = "Added documentation"
--         }
--         .
--         .
--         .
--         [line_count] = {
--             ["author"] = "braxtons12",
--             ["author-mail"] = "<braxtonsalyer@gmail.com>",
--             ["author-time"] = "16293480",
--             ["committer"] = "braxtons12",
--             ["committer-mail"] = "<braxtonsalyer@gmail.com>",
--             ["committer-time"] = "16293480",
--             ["commit-short"] = "1bc4adf",
--             ["commit-long"] = "1bc4adf...fda", -- 40 chars
--             ["summary"] = "Added documentation"
--         }
--     }
-- @function blame_line.__detail.get_commit_data(file, line_number, line_count)
blame_line.__detail.get_commit_data = function(file, line_number)
	type_check.check(file, "string", "file", "blame_line", "get_commit_data")
	type_check.check(line_number, "number", "line_number", "blame_line", "get_commit_data")

	local dir_path = vim.fn.shellescape(blame_line.__detail.substitute_path_separator(vim.fn.expand("%:h", nil, nil)))
	local file_path_escaped = vim.fn.shellescape(file)
	local command = "git -C " .. dir_path .. " --no-pager blame --line-porcelain -L "
		.. line_number .. " -- " .. file_path_escaped
	local result = vim.fn.system(command)
	local lines = blame_line.__detail.split_string(result, "\n")

	local hash = vim.fn.matchstr(lines[1], "\\c[0-9a-f]\\{40}")
	local hash_empty = vim.fn.empty(hash) == 1
	local was_fatal, _ = string.find(lines[1], "fatal")
	local not_git, _ = string.find(lines[1], "not a git repository")

	if hash_empty then
		if was_fatal and not_git then
			blame_line.__detail.enabled = false
			vim.notify("[blame_line.nvim] not a git repository, blame_line disabled",
				vim.log.levels.ERROR)
			return nil
		end
		return nil
	end

	-- git blame output lines are in the order:
	-- 1  commit (hash)
	-- 2  author
	-- 3  author-mail
	-- 4  author-time
	-- 5  author-tz
	-- 6  comitter
	-- 7  comitter-mail
	-- 8  comitter-time
	-- 9  comitter-tz
	-- 10 summary
	-- 11 previous
	-- 12 filename
	-- 13 the line
	local commit_data = {
	    ["commit-short"] = "",
	    ["commit-long"] = "",
	    ["author"] = "",
	    ["author-mail"] = "",
	    ["author-time"] = "",
	    ["committer"] = "",
	    ["committer-mail"] = "",
	    ["committer-time"] = "",
	    ["summary"] = "",
	}

	for index = 1, 10 do
		local line_is_hash = index == 1 and not hash_empty
                             and not select(1, string.find(lines[2], "Not Committed Yet"))

		if line_is_hash then
                commit_data["commit-short"] = string.sub(hash, 1, 7)
                commit_data["commit-long"] = hash
		elseif index ~= 1 then
            if index ~= 10 then
                if index == 2 or index == 6 then -- author or committer
                    local property, value =
                    blame_line.__detail.parse_commit_committer_or_author_line(lines[index])
                    commit_data[property] = value
                elseif index == 3 or index == 7 then -- author-mail or committer-mail
                    local property, value =
                    blame_line.__detail.parse_commit_committer_or_author_email_line(lines[index])
                    commit_data[property] = value
                elseif index == 4 or index == 8 then -- author-time or committer-time
                    local property, value =
                    blame_line.__detail.parse_commit_time_line(lines[index])
                    commit_data[property] = value
                end
            else
                local not_committed_yet, _ = string.find(lines[2], "Not Committed Yet")
                if not_committed_yet then
                    commit_data["summary"] = "Not Committed Yet"
                else
                    local property, value =
                    blame_line.__detail.parse_commit_summary_line(lines[index])
                    commit_data[property] = value
                end
            end
		end
	end
	return commit_data
end

-- Displays the git blame info for the given line as virtual text
--
-- @param buffer_num: number - The buffer to display the git blame line in
-- @param line_num: number - The line to display the git blame line at
-- @param message: string - The git blame line text to display
-- @function blame_line.__detail.set_virtual_text(buffer_num, line_num, message)
blame_line.__detail.set_virtual_text = function(buffer_num, line_num, message)
	type_check.check(buffer_num, "number", "buffer_num", "blame_line", "set_virtual_text")
	type_check.check(line_num, "number", "line_num", "blame_line", "set_virtual_text")
	type_check.check(message, "string", "message", "blame_line", "set_virtual_text")

	local line_index = line_num - 1
    blame_line.__detail.hide()
	vim.api.nvim_buf_set_extmark(
		buffer_num,
		blame_line.__detail.namespace,
		line_index,
		0,
		{
			hl_mode = "combine",
			virt_text = { { message, blame_line.__detail.config.hl_group } }
		}
	)
end

-- Retrieves the git blame info for the lines currently associated with the cursor
-- in the current buffer, then displays the blame line.
--
-- If the blame_line is not enabled, the buffer is a special type, or visual mode is active and
-- `config.show_in_visual` is false, this will do nothing.
--
-- @function blame_line.__detail.show()
blame_line.__detail.show = function()

	local function process_blame_line()
        blame_line.__detail.hide()

		if not blame_line.__detail.enabled
           or not blame_line.__detail.show_enabled
           or vim.bo.buftype ~= "" then
			return
		end

	    local mode = vim.api.nvim_get_mode().mode
        local is_in_visual_mode = mode == "v"
                                  or mode == "V"
                                  or mode == vim.api.nvim_replace_termcodes("<C-v>", true, true, true)
        local is_in_insert_mode = mode == "i" or select(1, string.find(mode, "i"))

		if (is_in_visual_mode and not blame_line.__detail.config.show_in_visual)
            or (is_in_insert_mode and not blame_line.__detail.config.show_in_insert) then
			return
		end

		local file_path = blame_line.__detail.substitute_path_separator(vim.fn.expand("%:p", nil, nil))

		if string.len(file_path) == 0 then
			return
		end

		local line_number = blame_line.__detail.get_selected_or_hovered_lines()
		local commit_data = blame_line.__detail.get_commit_data(file_path, line_number)
		if commit_data == nil then
			return
		end

		local buffer_num = vim.fn.bufnr("")
		blame_line.__detail.set_virtual_text(
			buffer_num,
			line_number,
			blame_line.__detail.convert_commit_data_to_string(commit_data)
		)
	end

	if blame_line.__detail.config.delay > 0 then
		vim.defer_fn(process_blame_line, blame_line.__detail.config.delay)
	else
		process_blame_line()
	end
end

-- Hides the git blame line without disabling it
--
-- @function blame_line.__detail.hide()
blame_line.__detail.hide = function()
	vim.api.nvim_buf_clear_namespace(vim.fn.bufnr(), blame_line.__detail.namespace, 0, -1)
end

-- Updates the cached git user information (user.name, user.email), so we can correctly replace the
-- users username and email with "You" if they made the change
--
-- @function blame_line.__detail.update_git_user_config()
blame_line.__detail.update_git_user_config = function()
	local dir_path = vim.fn.shellescape(
		blame_line.__detail.substitute_path_separator(
			vim.fn.expand("%:h", nil, nil)
		)
	)

	local function get_first_substring(str, separator)
		local start, _ = string.find(str, separator)
		if start then
			return string.sub(str, 0, start - 1)
		else
			return str
		end
	end

	blame_line.__detail.user_name = get_first_substring(vim.fn.system("git -C " .. dir_path .. " config --get user.name"), "\n")
	blame_line.__detail.user_email = get_first_substring(vim.fn.system("git -C " .. dir_path .. " config --get user.email"), "\n")
end

-- Returns whether the file associated with the current buffer is tracked by git
--
-- @return boolean
-- @function blame_line.__detail.is_buffer_git_tracked()
blame_line.__detail.is_buffer_git_tracked = function()
	local file_path = vim.fn.shellescape(
		blame_line.__detail.substitute_path_separator(
			vim.fn.expand("%:p", nil, nil)
		)
	)
	if string.len(file_path) == 0 then
		return false
	end

	local dir_path = vim.fn.shellescape(
		blame_line.__detail.substitute_path_separator(
			vim.fn.expand("%:h", nil, nil)
		)
	)
	local git_check = vim.fn.system("git -C " .. dir_path .. " ls-files --error-unmatch " .. file_path)
	local was_fatal, _ = string.find(git_check, "fatal")
	if was_fatal then
		return false
	end

	return true
end

-- Enables showing the blame line, refreshes it, and displays it
-- Called when `config.show_in_insert` is false and an `InsertLeave` event occurs
-- (so we show the blame line in normal mode, but not insert mode)
--
-- @function blame_line.__detail.enable_show()
blame_line.__detail.enable_show = function()
	if not blame_line.__detail.enabled
		or not blame_line.__detail.buffer_enabled
		or blame_line.__detail.show_enabled then
		return
	end

	blame_line.__detail.show_enabled = true
	blame_line.__detail.show()
end

-- Disables showing the blame line and hides it
-- Called when `config.show_in_insert` is false and an `InsertEnter` event occurs
-- (so we show the blame line in normal mode, but not insert mode)
--
-- @function blame_line.__detail.disable_show()
blame_line.__detail.disable_show = function()
	if not blame_line.__detail.enabled
		or not blame_line.__detail.buffer_enabled
		or not blame_line.__detail.show_enabled then
		return
	end

	blame_line.__detail.show_enabled = false
	blame_line.__detail.hide()
end

-- Checks whether the file associated with the just-entered buffer is tracked by git,
-- and if it is updates the cached git user data and enables showing the blame line
--
-- @function blame_line.__detail.on_buf_enter()
blame_line.__detail.on_buf_enter = function()
	if not blame_line.__detail.enabled then
		return
	end

	if blame_line.__detail.is_buffer_git_tracked() then
		blame_line.__detail.buffer_enabled = true
		blame_line.__detail.update_git_user_config()
		blame_line.__detail.enable_show()
	else
		blame_line.__detail.buffer_enabled = false
	end
end

-- Disables showing the blame line when exiting a buffer
--
-- @function blame_line.__detail.on_buf_leave()
blame_line.__detail.on_buf_leave = function()
	if not blame_line.__detail.enabled then
		return
	end

	blame_line.__detail.disable_show()
end

-- If enabled, updates the blame line and displays
--
-- @function blame_line.__detail.refresh()
blame_line.__detail.refresh = function()
	if not blame_line.__detail.enabled
		or not blame_line.__detail.buffer_enabled
		or not blame_line.__detail.show_enabled then
		return
	end

	blame_line.__detail.show()
end

-- Enables the blame line.
-- Enables the blame line for files tracked by git in modes valid for the current configuration
-- (@see `blame_line.config.show_in_insert` and @see `blame_line.config.show_in_visual`).
-- By default the blame line is enabled
--
-- @function blame_line.__detail.enable()
blame_line.enable = function()
	blame_line.__detail.enabled = true
	blame_line.__detail.buffer_enabled = blame_line.__detail.is_buffer_git_tracked()

	blame_line.__detail.refresh()
end

-- Disables the blame line completely until the user calls `blame_line.enable()` to re-enable the
-- blame line. The blame line is enabled by default.
--
-- @function blame_line.__detail.disable()
blame_line.disable = function()
    blame_line.__detail.hide()
	blame_line.__detail.enabled = false
end

return blame_line
