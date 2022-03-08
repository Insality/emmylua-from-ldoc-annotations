--- Parse ldoc dump file for inner structure
--- Get dump file via `ldoc . --filter pl.pretty.dump`

local utils = require("./src/utils")

---@class ldoc_structure
---@field functions ldoc_function_structure[]
---@field name string
---@field alias string
---@field parent string
---@field submodules table<name, boolean>
---@field fields table

---@class ldoc_function_structure
---@field args ldoc_args_structure[]
---@field args_string string
---@field desc string
---@field name string
---@field return_values ldoc_return_structure[]

---@class ldoc_args_structure [1] - name, [2] - type, [3] - desc

---@class ldoc_return_structure [1] - type, [2] - desc

local M = {}


local function split_tag_string(tag_string)
	local splitted = utils.split(tag_string, " ")

	if #splitted > 1 then
		local name = splitted[1]
		table.remove(splitted, 1)
		return name, table.concat(splitted, " ")
	end

	return tag_string, ""
end


local function parse(parsed_data, module_data)
	local class = {}
	class.name = module_data.mod_name
	class.alias  = module_data.tags and module_data.tags.alias or class.name
	class.parent = module_data.tags and module_data.tags.within or nil
	class.submodules = {}
	class.functions = {}
	class.fields = {}

	for _, v in pairs(module_data.items) do
		if v.type == "function" then
			local fun_name = v.name

			local paths = utils.split(fun_name, ".")
			if #paths > 2 and paths[1] == class.name then
				class.submodules[paths[2]] = true
			end

			local fun_summary = v.summary
			local fun_desc = v.description
			local fun_args_string = ""
			local args = {}
			local return_values = {}

			for i = 1, #v.params do
				local param_name = v.params[i]
				local param_type = v.modifiers.param[i] and v.modifiers.param[i].type or "unknown"
				local param_desc = utils.trim(utils.replace_new_line(v.params.map[param_name]))
				local default_value = v.modifiers.param[i] and v.modifiers.param[i].opt or nil


				fun_args_string = fun_args_string .. param_name
				if i ~= #v.params then
					fun_args_string = fun_args_string .. ", "
				end

				table.insert(args, { param_name, param_type, param_desc, default_value })
			end
			if v.ret then
				for i = 1, #v.ret do
					local ret_type = v.modifiers["return"][i].type or ""
					local ret_desc = utils.trim(utils.replace_new_line(v.ret[i] or ""))
					table.insert(return_values, { ret_type, ret_desc })
				end
			end
			table.insert(class.functions, {
				name = fun_name,
				summary = fun_summary,
				desc = fun_desc,
				args = args,
				args_string = fun_args_string,
				return_values = return_values
			})
		end

		if v.type == "field" then
			local field_type = v.type
			if v.modifiers and v.modifiers.field[v.name] then
				field_type = v.modifiers.field[v.name].type
			end
			table.insert(class.fields, {
				name = v.name,
				desc = v.summary,
				type = field_type
			})
		end

		if v.type == "table" then
			local values = {}
			local map_params = {}
			for key, value in pairs(v.params.map) do
				values[key] = value
				table.insert(map_params, value)
			end
			if #map_params == #v.params then
				--- Assume it's map
				table.insert(class.fields, {
					name = v.name,
					desc = v.summary,
					type = "table",
					values = values
				})
			else
				--- Assume it's simple array
				table.insert(class.fields, {
					name = v.name,
					desc = v.summary,
					type = "field[]"
				})
			end
		end
	end

	-- Tags is details that cannot be derived from the source code automatically.
	if module_data.tags and module_data.tags.field then
		for i = 1, #module_data.tags.field do
			local tag_string = module_data.tags.field[i]
			local tag_name, tag_desc = split_tag_string(tag_string)
			local tag_type = module_data.modifiers.field[i].type or ""
			table.insert(class.fields, {
				name = tag_name,
				desc = tag_desc,
				type = tag_type
			})
		end
	end

	if not parsed_data[class.name] then
		parsed_data[class.name] = class
	end

	return parsed_data
end


function M.parse_file(filedata)
    local parsed_data = {}
    for _, ldoc_module in pairs(filedata) do
        parse(parsed_data, ldoc_module)
    end

    return parsed_data
end


return M
