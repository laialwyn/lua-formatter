-- file: lua_formatter.lua
-- description: beautiful your lua file
-- author: alwyn lai
-- date: 2013/4/19

-- formatter
Formatter = {}
-- config
Formatter.config = {
	["semicolon"] = true, -- line end with ';'?
	["output"] = "output", -- output reslut to this folder
}
-- block
Formatter.block = {}
-- retain string 
Formatter.retain = {}
-- pattern mode
Formatter.pattern = {
	-- function
	["function"] = "%s+function%s*[%w_:]*%b()%s+",
	["end"] = "%s+end[%s+%;]", -- bad idea to and ';' after end
	-- control block
	["if..then"] = "%s+if%s+.-%s+then%s+",
	["elseif..then"] = "%s+elseif%s+.-%s+then%s+",
	["for..do"] = "%s+for%s+.-%s+do%s+",
	["for..in..do"] = "%s+for%s+.-%s+in.-%s+do%s+",
	["while..do"] = "%s+while%s+.-%s+do%s+",
	["else"] = "%s+else%s+",
	-- comment	
	["line_comment"] = "%-%-",
	["multi_comment"] = "#mutili%-comment%d+",
	-- misc	
	["break"] = "%s+break[%s+%;]",
}
---------- file process start ----------
-- open file
function Formatter:open()
	self.file = io.open(self.file_name, "r")
	assert(self.file, "open file fail!")
end
-- close file
function Formatter:close()
	if self.file then
		self.file:close()
	end
end
-- read line from file
function Formatter:read()
	if self.file then
		return self.file:read()
	end
end
-- read all lines from file
function Formatter:lines()
	if self.file then
		return self.file:lines()
	end
end
-- read all content from file
function Formatter:read_all()
	if self.file then
		return self.file:read("*a")
	end
end
-- write line into file
function Formatter:write(line)
	if self.file then
		return self.file:write(line)
	end
end
---------- file process end ----------
---------- process start ----------
-- trim string  
function Formatter:trim(text) 
	return (string.gsub(text,"^%s*(.-)%s*$", "%1"))
end
-- insert n c before string
function Formatter:insert_tab(text, n, c)
	if n < 1 then
		return text
	end
	local _c = c or '\t'
	local rt = ""
	for i=1,n do
		rt = rt .. _c
	end
	return rt .. text
end
-- split string with pattern
function Formatter:split(text, pattern)
	local rt= {}
	string.gsub(text, '[^'..pattern..']+', function(w) rt[#rt+1]= self:trim(w) end )
	return rt
end
-- match string
function Formatter:match(text, pattern)
    return string.match(text, self.pattern[pattern])
end
-- line comment search
function Formatter:line(line)
	return self:match(line, "line_comment")
end
-- function start search
function Formatter:find_function_start(line)
	local tmp = string.match(line, "function%s*[%w_:]*%b()")
	if tmp and tmp:len()==line:len() then
		return true
	end
	return false	
end
-- function end search
function Formatter:find_end(line)
	local tmp = string.match(line, "end")
	if tmp and tmp:len()==line:len() then
		return true
	end
	return false
end
-- function local search
function Formatter:find_local(line)
	local tmp = string.match(line, "local%;*")
	if tmp and tmp:len()==line:len() then
		return true
	end
	return false
end
-- control block search
function Formatter:find_control(line)
	-- elseif..then else is special
	local pt = {"if%s+.+%s+then", "for%s+.+%s+do", "for%s+.+%s+in%s+.+%s+do", "while%s+.+%s+do"}
	for _, pattern in pairs(pt) do
		local tmp = string.match(line, pattern)
		if tmp and tmp:len()==line:len() then
			return true
		end
	end
	return false
end
function Formatter:find_else(line)
	-- elseif or else
	local pt = {"else", "elseif%s+.+%s+then",}
	for _, pattern in pairs(pt) do
		local tmp = string.match(line, pattern)
		if tmp and tmp:len()==line:len() then
			return true
		end
	end
	return false
end
function Formatter:find_comment(line)
	-- line_comment mutili_comment
	local pt = {"#line_comment%d+", "#mutili_comment%d+",}
	for _, pattern in pairs(pt) do
		local tmp = string.match(line, pattern)
		if tmp and tmp:len()==line:len() then
			return true
		end
	end
end
---------- process end  ----------

-- insert line to block[index] ----------
function Formatter:insert(index, line, deep, kind)
	self.block[index] = self.block[index] or {}
	local len = #self.block[index]
	if kind and kind == "function" then
		-- if preline end with = or local, then concat them 
		if self.block[index][len] and (string.find(self.block[index][len], "[%w_%s]+=%;*$") or self:find_local(self:trim(self.block[index][len]))) then
			line = self:trim(line)
			self.block[index][len] = string.gsub(self.block[index][len], "%;$", "")
			self.block[index][len] = self.block[index][len] .. " " ..self:format_line(line)
			return
		end
	end
	line = self:insert_tab(self:trim(line),deep)
	self.block[index][len+1] = self:format_line(line, false, kind, deep)
end
-- restore retain
function Formatter:restore()
	--table square_bracket  brackets line_comment mutili_comment double_quote single_quote
	local key_table = {[1] = "#table", [2] = "#square_bracket", [3] = "#brackets", [4] = "#single_quote", [5] = "#double_quote", [6] = "#line_comment", [7] = "#mutili_comment",}
	for k = 1, #key_table do
		if Formatter.retain[key_table[k]] then
			for key,value in pairs(Formatter.retain[key_table[k]]) do
				for i=1, #Formatter.block do
					for j =1, #Formatter.block[i] do
						Formatter.block[i][j] = string.gsub(Formatter.block[i][j], "%#[%w_]+", function(s) if s == key_table[k] ..key then  return value else return s end end)						
					end
				end
			end
		end
	end	
end
-- format line
function Formatter:format_line(line, flag, kind, deep)
	if line == "\n" then
		return line
	end
	local deep = deep or select(2,string.gsub(line, "^\t",""))
	symbol_table = {"%+","%-","%*","%/","%%","<", ">", ">=", "<=", "==", "~=", "=", "%.%."}
	for _,symbol in pairs(symbol_table) do
		line = string.gsub(line, "[%w_%)%s%]%{]+" ..symbol.."[%w_%(%[%}%s]+" , function(s) return string.gsub(s, symbol, " " .. symbol .. " ") end)
	end
	-- add " " atfer ,
	line = string.gsub(line, ",", ", ")
	-- deal " " first we just need 1 
	line = string.gsub(line, "%s+", " ")
	-- add "\n" brefor local and return break
	if not flag then
		line = string.gsub(line, "[^%w_]local%s+", "\nlocal ")
		line = string.gsub(line, "[^%w_]return[^%w_]", "\nreturn ")
		line = string.gsub(line, "[^%w_]break[^%w_]", "\nbreak\n")
	else 
		-- brackets  remove " " from ( )
		line = string.gsub(line, "%(%s*", "(")
		line = string.gsub(line, "%s*%)", ")")
	end
	-- ok ,last step 
	local lines_table = self:split(line,"\n")
	local rt = ""
	for i = 1, #lines_table do
		local tmp = self:trim(lines_table[i])
		tmp = self:insert_tab(tmp,deep)
		if kind and kind == "normal" and self.config.semicolon then			
			rt = rt ..tmp..";\n"
		else
			rt = rt ..tmp.."\n"
		end
	end
	-- remove last \n
	rt = string.gsub(rt, "%s+$", "")
	return rt
end

-- format brackets, yeah..it is a big deal..
function Formatter:format_brackets()
	local tbl = {}
	for k,v in pairs(self.retain["#brackets"]) do
		-- remove'(' ')'
		local line = string.sub(v,2, -2)
		line = self:format_line(line, true)
		table.insert(tbl,k,line)
	end	
	self.retain["#brackets"] = tbl
end
function Formatter:format_mutiline_comment()
	local tbl = {}
	for k,v in pairs(self.retain["#mutili_comment"]) do		
		local line = ""
		local deep = select(2,string.gsub(v, "\t",""))
		local lines_table = self:split(v,"\n")
		for i = 1, #lines_table do
			local tmp = self:trim(lines_table[i])
			tmp = self:insert_tab(tmp,deep)
			line = line ..tmp.."\n"
		end
		-- remove last \n
		line = string.gsub(line, "%s+$", "")
		table.insert(tbl,k,line)
	end	
	self.retain["#mutili_comment"] = tbl
end
-- separate line
function Formatter:separate_line(line)
	local pt = {"function", "end", "if..then", "elseif..then", "for..do", "for..in..do", "while..do", "break","else"}
	-- add " " at begin and end ... some time we need it
	line = " " .. line .. " "	
	local make_func = function (kind)
						func = function(s)
								local kind_tbl = self.retain["#" ..kind] 
								kind_tbl = kind_tbl or {}
								kind_tbl[#kind_tbl+1] = self:trim(s)
								--print("#" .. kind ..#kind_tbl .. ":" ..kind_tbl[#kind_tbl])
								self.retain["#" ..kind] = kind_tbl
								--self.retain[k] = s
								if kind == "brackets" then
									return "(#" .. kind ..#kind_tbl.. ")"
								elseif kind == "line_comment" then
									return "#" .. kind ..#kind_tbl .. "\n"
								elseif kind == "mutili_comment" then 
									return "\n#" .. kind ..#kind_tbl .. "\n"
								else
									return "#" .. kind ..#kind_tbl
								end
							end
							return func
						end
	-- string between "" or '' [[]] (-- \n) [] () {} we should keep them self at last  we will restore them back
	-- the order is very important
	-- mutiline comment
	line = string.gsub(line, "[^%-]%-%-%[%[.-%]%]", make_func("mutili_comment"))
	-- line comment
	line = string.gsub(line, "%-%-.-\n", make_func("line_comment"))	
	-- "" 
	line = string.gsub(line, "%b\"\"", make_func("double_quote"))
	-- ''
	line = string.gsub(line, "%b''", make_func("single_quote"))
	-- ()
	line = string.gsub(line, "%b()", make_func("brackets"))
	-- []
	line = string.gsub(line, "%b[]", make_func("square_bracket"))
	-- {}
	line = string.gsub(line, "%b{}", make_func("table"))	
	
	-- i hate ';' 
	line = string.gsub(line, ";", "\n")
	
	for _, pattern in pairs(pt) do
		line = string.gsub(line, self.pattern[pattern], function(s) return "\n"..s.."\n" end)
	end
	local rt = self:split(line,"\n")
	return rt
end
-- process 
function Formatter:process()
	local block_index, function_deep = 1, 0
	local function process_line(line)
		if line:len() < 1 then
			return
		end
		if self:find_function_start(line) or self:find_control(line) then				
			-- closure or control block
			self:insert(block_index, line, function_deep, "function")
			function_deep = function_deep + 1			
		elseif self:find_else(line) then
			-- else or elseif
			self:insert(block_index, line, function_deep - 1)
		elseif self:find_end(line) then
			-- end
			function_deep = function_deep - 1			
			self:insert(block_index, line, function_deep)
			if function_deep == 0 then
				self:insert(block_index, "\n", function_deep)
			elseif function_deep < 0 then
				function_deep = 0
			end
		elseif self:find_comment(line) then
			-- yeah it is a normal line  let it go
			self:insert(block_index, line, function_deep, "comment")
		else			
			-- yeah it is a normal line  let it go
			self:insert(block_index, line, function_deep, "normal")
		end	
	end
	-- let''s do it....
	-- read all file
	local text = self:read_all()
	if text:len() < 1 then
		print("empty file!")
		return
	end
	-- second separate content to serval lines then process every line 
	local lines_table = self:separate_line(text)
	for i = 1, #lines_table do
		process_line(lines_table[i])
	end
	
	-- restore them back!
	self:format_brackets()
	self:restore()
end
-- dump all block
function Formatter:save()
	--os.execute ("mkdir "..self.config.output);
	local dir = self.config.output
	local name = self:split(self.file_name,"/")
	local filename = name[#name]
	os.execute ("if not exist "..dir.." mkdir "..dir)
	local new_file  = io.open(self.config.output .."/"..filename, "w")
	if new_file then
		for i=1, #Formatter.block do
			for j =1, #Formatter.block[i] do
				--print(Formatter.block[i][j])
				new_file:write(Formatter.block[i][j].."\n")
			end
		end
		new_file:close()
	end
	print("yeah.. job is done! new file is: " .. filename)
end 
-- dump all block
function Formatter:dump()	
	--print("------------------")
	for i=1, #Formatter.block do
		for j =1, #Formatter.block[i] do
			print(Formatter.block[i][j])
		end
	end
end
-- reset
function Formatter:clean()
	-- name
	Formatter.file_name = nil
	-- block
	Formatter.block = {}
	-- retain string 
	Formatter.retain = {}
end
--[[
	main--
--]]
local function main(filename)
	if filename == "lua_formatter.lua" then
		return
	end
	filename = string.gsub(filename, "\\", "/")
	Formatter.file_name = filename
	Formatter:open(filename)
	Formatter:process()	
	Formatter:save()
	Formatter:close()
	Formatter:clean()
	--Formatter:dump()
end

--main(arg[1])
for i = 1, #arg do
	print("formatting file: " ..arg[i])
	main(arg[i])
end
--main("daily_tasks_dialog.lua")