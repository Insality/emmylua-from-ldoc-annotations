--- Prepare parsed dump file for annotations module

local utils = require("./src/utils")

---@class prepared_structure
---@field modules table<string, prepared_module_structure>
---@field aliases table<string, string>
---@field parents table<string, string>

---@class prepared_module_structure
---@field functions prepared_function_structure[]
---@field fields prepared_field_info[]

---@class prepared_function_structure
---@field name string
---@field summary string
---@field desc string
---@field args prepared_field_info[]
---@field return_value prepared_field_info[]
---@field is_protected boolean

---@class prepared_field_info
---@field name string
---@field type string
---@field desc string
---@field default string

local M = {}


local function get_module_name(function_name, base_module)
	local names = utils.split(function_name, ".")
	if #names > 1 then
		names[#names] = nil
		return table.concat(names, ".")
	else
		return base_module
	end
end


local function get_function_name(function_name)
	local names = utils.split(function_name, ".")
	if #names > 1 then
		return names[#names]
	else
		return function_name
	end
end


---@param prepared_data prepared_structure
---@param module_name string
local function check_module(prepared_data, module_name)
	if not prepared_data.modules[module_name] then
		prepared_data.modules[module_name] = {
			functions = {},
			fields = {}
		}
	end
end


local function link_module_upside(prepared_data, module_name)
	local upper_module = get_module_name(module_name, module_name)
	if upper_module ~= module_name then
		check_module(prepared_data, upper_module)
		link_module_upside(prepared_data, upper_module)

		local field_name = get_function_name(module_name)

		local is_exist = false
		for i = 1, #prepared_data.modules[upper_module].fields do
			if prepared_data.modules[upper_module].fields[i].name == field_name then
				is_exist = true
			end
		end

		if not is_exist then
			---@type prepared_field_info
			local field_info = {}
			field_info.name = field_name
			field_info.type = module_name
			field_info.desc = "Submodule"
			table.insert(prepared_data.modules[upper_module].fields, field_info)
		end
	end
end


---@param args ldoc_args_structure[]
---@return prepared_field_info[]
local function parse_args(args)
	---@type prepared_field_info[]
	local parsed = {}

	for i = 1, #args do
		---@type prepared_field_info
		local info = {}
		info.name = args[i][1]
		info.type = args[i][2]
		info.desc = utils.replace_new_line(utils.trim(args[i][3]))
		info.default = args[i][4]
		table.insert(parsed, info)
	end

	return parsed
end

---@param args ldoc_return_structure[]
---@return prepared_field_info[]
local function parse_return_values(return_values)
	---@type prepared_field_info[]
	local parsed = {}

	for i = 1, #return_values do
		---@type prepared_field_info
		local info = {}
		info.type = return_values[i][1]
		info.desc = utils.replace_new_line(utils.trim(return_values[i][2]))
		table.insert(parsed, info)
	end

	return parsed
end


---@param prepared prepared_structure
local function make_table_module(prepared, module_name, values)
	check_module(prepared, module_name)
	local fields = prepared.modules[module_name].fields
	for k, v in pairs(values) do
		---@type prepared_field_info
		local field = {}
		field.name = k
		field.type = v.type
		field.desc = v.desc
		field.default = v.default
		table.insert(fields, field)
	end
end


---@param parsed_data table<string, ldoc_structure>
---@return prepared_structure
function M.prepare(parsed_data)
	---@type prepared_structure
	local prepared = {
		modules = {},
		aliases = {},
		parents = {}
	}

	for class_name, data in pairs(parsed_data) do
		prepared.aliases[data.name] = data.alias or data.name
		prepared.aliases[data.name .. "[]"] = (data.alias or data.name) .. "[]"
		prepared.parents[class_name] = data.parent

		for _, function_data in pairs(data.functions) do
			---@type prepared_function_structure
			local function_info = {}

			local module_name = get_module_name(function_data.name, class_name)
			local function_name = get_function_name(function_data.name)
			check_module(prepared, module_name)
			link_module_upside(prepared, module_name)

			function_info.name = function_name
			function_info.summary = utils.trim(utils.replace_new_line(function_data.summary))
			function_info.desc = utils.trim(utils.replace_new_line(function_data.desc))
			function_info.args = parse_args(function_data.args)
			function_info.return_value = parse_return_values(function_data.return_values)
			function_info.is_protected = string.find(function_info.summary, "(protected)")

			table.insert(prepared.modules[module_name].functions, function_info)
		end

		for _, field_data in pairs(data.fields) do
			---@type prepared_field_info
			local field_info = {}

			-- Make table type
			if field_data.values then
				local alias_name = prepared.aliases[class_name] or class_name
				local module_name = alias_name .. "." .. field_data.name
				field_info.name = field_data.name
				field_info.desc = field_data.desc
				field_info.type = module_name

				make_table_module(prepared, module_name, field_data.values)
				table.insert(prepared.modules[class_name].fields, field_info)
			else
				field_info.name = field_data.name
				field_info.desc = field_data.desc
				field_info.type = field_data.type

				check_module(prepared, class_name)
				table.insert(prepared.modules[class_name].fields, field_info)
			end
		end
	end

	for _, data in pairs(prepared.modules) do
		table.sort(data.fields, function(a, b)
			return a.name < b.name
		end)
		table.sort(data.functions, function(a, b)
			return a.name < b.name
		end)
	end

	return prepared
end


return M
