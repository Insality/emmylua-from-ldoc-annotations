local M = {}


function M.split(inputstr, sep)
	sep = sep or "%s"
	local t = {}
	local i = 1
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		t[i] = str
		i = i + 1
	end
	return t
end


function M.trim(s)
  -- from PiL2 20.4
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end


function M.replace_new_line(s)
	local new_string = ""
	local splitted = M.split(s, "\n")
	for i = 1, #splitted do
		new_string = new_string .. " " .. splitted[i]
	end
	return new_string
end


return M
