local function split(inputstr, sep)
	sep = sep or "%s"
	local t = {}
	local i = 1
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		t[i] = str
		i = i + 1
	end
	return t
end


local function trim(s)
  -- from PiL2 20.4
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end


local function replace_new_line(s)
	local new_string = ""
	local splitted = split(s, "\n")
	for i = 1, #splitted do
		new_string = new_string .. " " .. splitted[i]
	end
	return new_string
end


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


local function split_tag_string(tag_string)
	local splitted = split(tag_string, " ")

	if #splitted > 1 then
		local name = splitted[1]
		table.remove(splitted, 1)
		return name, table.concat(splitted, " ")
	end

	return tag_string, ""
end


local function parse_module(parsed_data, module_data)
	local class = {}
	class.name = module_data.name
	class.alias  = module_data.tags and module_data.tags.alias or class.name
	class.parent = module_data.tags and module_data.tags.within or nil
	class.submodules = {}
	class.functions = {}
	class.fields = {}

	for k, v in pairs(module_data.items) do
		if v.type == "function" then
			local fun_name = v.name

			local paths = split(fun_name, ".")
			if #paths > 2 and paths[1] == class.name then
				class.submodules[paths[2]] = true
			end

			local fun_desc = v.summary
			local fun_args_string = ""
			local args = {}
			local return_values = {}

			for i = 1, #v.params do
				local param_name = v.params[i]
				local param_type = v.modifiers.param[i] and v.modifiers.param[i].type or "unknown"
				local param_desc = replace_new_line(v.params.map[param_name])
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
					local ret_desc = replace_new_line(v.ret[i] or "")
					table.insert(return_values, { ret_type, ret_desc })
				end
			end
			table.insert(class.functions, {
				name = fun_name,
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


local function get_module_name(function_name, base_module)
	local names = split(function_name, ".")
	if #names > 1 then
		names[#names] = nil
		return table.concat(names, ".")
	else
		return base_module
	end
end


local function get_function_name(function_name)
	local names = split(function_name, ".")
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
		info.desc = replace_new_line(trim(args[i][3]))
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
		info.desc = replace_new_line(trim(return_values[i][2]))
		table.insert(parsed, info)
	end

	return parsed
end


---@class prepared_structure
---@field modules table<string, prepared_module_structure>
---@field aliases table<string, string>
---@field parents table<string, string>

---@class prepared_module_structure
---@field functions prepared_function_structure[]
---@field fields prepared_field_info[]

---@class prepared_function_structure
---@field name string
---@field desc string
---@field args prepared_field_info[]
---@field return_value prepared_field_info[]

---@class prepared_field_info
---@field name string
---@field type string
---@field desc string
---@field default string


---@param prepared prepared_structure
local function make_table_module(prepared, module_name, values)
	check_module(prepared, module_name)
	local fields = prepared.modules[module_name].fields
	for k, v in pairs(values) do
		---@type prepared_field_info
		local field = {}
		field.name = k
		field.type = "field"
		field.desc = v
		table.insert(fields, field)
	end
end


---@param parsed_data table<string, ldoc_structure>
---@return prepared_structure
local function prepare_data(parsed_data)
	---@type prepared_structure
	local prepared = {
		modules = {},
		aliases = {},
		parents = {}
	}

	for class_name, data in pairs(parsed_data) do
		prepared.aliases[data.name] = data.alias or data.name
		prepared.parents[class_name] = data.parent

		for _, function_data in pairs(data.functions) do
			---@type prepared_function_structure
			local function_info = {}

			local module_name = get_module_name(function_data.name, class_name)
			local function_name = get_function_name(function_data.name)
			check_module(prepared, module_name)
			link_module_upside(prepared, module_name)

			function_info.name = function_name
			function_info.desc = trim(replace_new_line(function_data.desc))
			function_info.args = parse_args(function_data.args)
			function_info.return_value = parse_return_values(function_data.return_values)

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


---@param data prepared_structure
local function make_annotations(data)
	local result = ""

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
		local class_string = "---@class " .. module_alias
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
			result = result .. trim(field_string) .. "\n"
		end

		--- Class functions
		for _, function_info in pairs(class_structure.functions) do
			local args_string = ""
			for j = 1, #function_info.args do
				local arg = function_info.args[j]
				local arg_type = data.aliases[arg.type] or arg.type
				local arg_string = string.format("%s:%s", arg.name, arg_type)
				args_string = args_string .. arg_string

				if j < #function_info.args then
					args_string = args_string .. ", "
				end
			end

			local return_string = #function_info.return_value > 0 and ":" or ""
			for j = 1, #function_info.return_value do
				local arg = function_info.return_value[j]
				local arg_type = data.aliases[arg.type] or arg.type
				return_string = return_string .. arg_type

				if j < #function_info.return_value then
					return_string = return_string .. ", "
				end
			end

			local field_string = string.format("---@field %s fun(%s)%s %s", function_info.name, args_string, return_string, function_info.desc)
			result = result .. field_string .. "\n"
		end

		result = result .. "\n"
	end

	return result
end


local function main()
	local filedata = assert(loadfile(arg[1]))()
	local parsed_data = {}
	for _, ldoc_module in pairs(filedata) do
		parse_module(parsed_data, ldoc_module)
	end

	-- print(inspect(parsed_data))
	local prepared_data = prepare_data(parsed_data) -- Transform ldoc parsed data to our structure
	local annotations = make_annotations(prepared_data) -- Output our structure to string
	print(annotations)
end

main()
