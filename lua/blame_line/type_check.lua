-- @file type_check.lua
-- @author Braxton Salyer <braxtonsalyer@gmail.com>
-- @brief Runtime type checking for blame_line.nvim
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

-- The type_checking module
local type_check = {}
-- Checks `param` to ensure it matches the given `type_string`
--
-- @param param - The parameter to check the type of
-- @param type_string - The type string identifying the required type
-- @param param_name - The pretty-printed name of param, to give context to the assertion message
-- @param function_name - The pretty-printed name of param, to give context to the assertion message
-- @param function_name - The pretty-printed name of param, to give context to the assertion message
--
-- @usage
-- function my_function(must_be_string)
--     type_check.check(must_be_string, "string", "must_be_string"
-- end
-- @function type_check.check
type_check.check = function(param, type_string, param_name, module_name, function_name)
	assert(type(type_string) == "string",
		"[blame_line.nvim] invalid type for argument `type_string` given to internal \
		   function `check_type`")
	assert(type(param_name) == "string",
		"[blame_line.nvim] invalid type for argument `param_name` given to internal \
		   function `check_type`")
	local had_function = true
	local had_module = true
	local module_string = "."
	if not function_name then
		had_function = false
		module_string = ""
		function_name = ""
	end
	if not module_name then
		had_module = false
		module_string = ""
		module_name = ""
	end

	if not had_function and not had_module then
		assert(type(param) == type_string,
			"[blame_line.nvim] invalid type given for parameter " .. param_name)
	else
		assert(type(param) == type_string,
			"[blame_line.nvim] invalid type given for parameter " .. param_name ..
			" in " .. module_name .. module_string .. function_name)
	end
end

return type_check
