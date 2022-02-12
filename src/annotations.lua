-- Generate final emmylua nnotations output

local utils = require("./src/utils")

local M = {}

---@param data prepared_structure
function M.generate(data)
	local result = "-- luacheck: ignore\n\n"

	local keys = {}
	for key in pairs(data.modules) do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return (data.aliases[a] or a) < (data.aliases[b] or b)
	end)

	for i = 1, #keys do
		local module_alias = data.aliases[keys[i]] or keys[i]
		local module_name = keys[i]
		local class_structure = data.modules[module_name]
		local class_string = "\n---@class " .. module_alias
		--- Class title
		if data.parents[module_name] then
			local parent = data.parents[module_name]
			local parent_name = data.aliases[parent] or parent
			class_string = class_string .. " : " .. parent_name
		end
		result = result .. class_string .. "\n"

		--- Class fields
		for j = 1, #class_structure.fields do
			local field = class_structure.fields[j]
			local field_string = string.format("---@field %s %s %s", field.name, field.type, field.desc or "")
			result = result .. utils.trim(field_string) .. "\n"
		end

		--- Add local module variable
		local underscored = table.concat(utils.split(module_alias, "."), "__")
		result = result .. "local " .. underscored .. " = {}\n"

		--- Class functions
		for _, function_info in pairs(class_structure.functions) do
			result = result .. "\n"
			local function_args = ""
			if function_info.desc then
				result = result .. "--- " .. function_info.desc .. "\n"
			end
			for j = 1, #function_info.args do
				local arg = function_info.args[j]
				local arg_type = data.aliases[arg.type] or arg.type
				function_args = function_args .. arg.name

				if j < #function_info.args then
					function_args = function_args  .. ", "
				end

				local param_string = string.format("---@param %s %s %s", arg.name, arg_type, utils.trim(arg.desc))
				result = result .. utils.trim(param_string) .. "\n"
			end

			for j = 1, #function_info.return_value do
				local arg = function_info.return_value[j]
				local arg_type = data.aliases[arg.type] or arg.type

				local return_string = string.format("---@return %s %s", arg_type, utils.trim(arg.desc))
				result = result .. utils.trim(return_string) .. "\n"
			end

			local function_name = underscored .. "." .. function_info.name
			local function_string = string.format("function %s(%s) end", function_name, function_args)
			result = result .. function_string .. "\n"
		end

		result = result .. "\n"
	end

	return result
end


return M
