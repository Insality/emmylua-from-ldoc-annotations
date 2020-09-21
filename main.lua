
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



local function parse_module(parsed_data, module_data)
	local class = {}
	class.name = module_data.mod_name
	class.submodules = {}
	class.functions = {}

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

				fun_args_string = fun_args_string .. param_name
				if i ~= #v.params then
					fun_args_string = fun_args_string .. ", "
				end

				table.insert(args, { param_name, param_type, param_desc })
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
		else
			-- print("OTHER TYPE")
		end
	end

	if not parsed_data[class.name] then
		parsed_data[class.name] = class
	end

	return parsed_data
end


local function make_annotations(data)
	local result = ""

	for class_name, class_data in pairs(data) do
		result = result .. "---@class " .. class_name .. "\n"
		result = result .. "local " .. class_name .. " = {}\n"

		for submodule, _ in pairs(class_data.submodules) do
			result = result .. class_name .. "." .. submodule .. " = {}\n"
		end
		result = result .. "\n"

		for i = 1, #class_data.functions do
			local function_data = class_data.functions[i]

			local formatted_desc = split(function_data.desc, "\n")
			for j = 1, #formatted_desc do
				result = result .. "---" .. trim(formatted_desc[j]) .. "\n"
			end

			for _, arg in ipairs(function_data.args) do
				result = result .. "---@param " .. arg[1] .. " " .. arg[2] .. " " .. arg[3] .. "\n"
			end
			for _, ret in ipairs(function_data.return_values) do
				result = result .. "---@return " .. ret[1] .. " " .. ret[2] .. "\n"
			end
			result = result .. "function " .. function_data.name .. "(" .. function_data.args_string .. ") end\n\n"
		end
	end

	return result
end


local function main()
	local filedata = assert(loadfile(arg[1]))()
	local parsed_data = {}
	for _, ldoc_module in pairs(filedata) do
		parse_module(parsed_data, ldoc_module)
	end
	local annotations = make_annotations(parsed_data)
	print(annotations)
end


main()
