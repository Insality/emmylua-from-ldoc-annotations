--- Parse the ldoc dump file ($1 script argument)
--- and generate the emmylua annotations output to stout
---
--- author: Maxim Tuprikov, Insality <insality@gmail.com
--- license: MIT
--- date: 10.2020

local parser = require("./src/parser")
local prepare = require("./src/prepare")
local annotations = require("./src/annotations")

local function main()
	local filedata = assert(loadfile(arg[1]))()
	local parsed_data = parser.parse_file(filedata)
	local prepared_data = prepare.prepare(parsed_data) -- Transform ldoc parsed data to our structure
	local annotations_string = annotations.generate(prepared_data) -- Output our structure to string
	print(annotations_string)
end

main()
