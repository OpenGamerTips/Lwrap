local LuaAPI;
local _, Err = pcall(function()
    LuaAPI = require("main")
end)
if Err then
    LuaAPI = loadstring(game:HttpGet("https://raw.githubusercontent.com/OpenGamerTips/Lwrap/master/src/main.lua"))()
end

function _luaC_execline(L, Line) -- Lua C Parser
	local Ctr = 0
	local Call;
	local Args = {}
	for Instruction in Line:gmatch("[^ ]+") do
		Ctr = Ctr + 1
		if Ctr == 1 then Call = Instruction
		else table.insert(Args, Instruction) end
	end

	Call = string.lower(Call)
	if Call == "getglobal" then
		assert((#Args == 1), "invalid number of arguments")
		lua_getglobal(L, Args[1])
	elseif Call == "setglobal" then
		assert((#Args == 0), "invalid number of arguments")
		lua_setglobal(L, StackFunctions.get(L, -2), StackFunctions.get(L, -1))
		lua_pop(-2)
		lua_pop(-1)
	elseif Call == "getfield" then
		assert((#Args >= 2), "invalid number of arguments")
		local Index = Args[1]
		local Field = ""

		for Iter, Value in pairs(Args) do
			if Iter > 1 then
				Field = Field..Value.." "
			end
		end
		Field = Field:sub(1, #Field - 1)
		lua_getfield(L, Index, Field)
	elseif Call == "setfield" then
		assert((#Args >= 2), "invalid number of arguments")
		local Index = Args[1]
		local Field = ""

		for Iter, Value in pairs(Args) do
			if Iter > 1 then
				Field = Field..Value.." "
			end
		end
		Field = Field:sub(1, #Field - 1)
		lua_setfield(L, Index, Field)
	elseif Call == "pushvalue" then
		assert((#Args == 1), "invalid number of arguments")
		lua_pushvalue(L, Args[1])
	elseif Call == "printstack" then
		assert((#Args == 0), "invalid number of arguments")
		lua_printstack(L)
	elseif Call == "pushstring" then
		assert((#Args >= 1), "invalid number of arguments")
		lua_pushstring(L, table.concat(Args))
	elseif Call == "pushnumber" then
		assert((#Args == 1), "invalid number of arguments")
		lua_pushnumber(L, tonumber(Args[1]))
	elseif Call == "pushboolean" then
		assert((#Args == 1), "invalid number of arguments")
		local Bool = string.upper(Args[1])
		if string.match(Bool:sub(1, 4), "TRUE") then
			lua_pushboolean(L, true)
		elseif string.match(Bool:sub(1, 5), "FALSE") then
			lua_pushboolean(L, false)
		else
			error("invalid boolean", 0)
		end
	elseif Call == "pcall" then
		assert((#Args == 3), "invalid number of arguments")
		local N_Args = Args[1]
		local N_Results = Args[2]
		local ErrFunc = Args[3]

		lua_pcall(L, N_Args, N_Results, ErrFunc)
	elseif Call == "call" then
		assert((#Args == 2), "invalid number of arguments")
		local N_Args = Args[1]
		local N_Results = Args[2]

		lua_call(L, N_Args, N_Results)
	elseif Call == "emptystack" then
		assert((#Args == 0), "invalid number of arguments")
		lua_emptystack(L)
	elseif Call == "clearstack" then
		assert((#Args == 0), "invalid number of arguments")
		lua_clearstack(L)
	elseif Call == "settop" then
		assert((#Args == 1), "invalid number of arguments")
		lua_settop(L, Args[1])
	elseif Call == "gettop" then
		assert((#Args == 0), "invalid number of arguments")
		print(lua_gettop(L))
	elseif Call == "pushnil" then
		assert((#Args == 0), "invalid number of arguments")
		lua_pushnil(L)
	elseif Call == "next" then
		assert((#Args == 1), "invalid number of arguments")
		lua_next(L, Args[1])
	elseif Call == "pop" then
		assert((#Args == 1), "invalid number of arguments")
		lua_pop(L, Args[1])
	elseif Call == "insert" then
		assert((#Args == 1), "invalid number of arguments")
		lua_insert(L, Args[1])
	elseif Call == "createtable" then
		assert((#Args == 2), "invalid number of arguments")
		lua_createtable(L, Args[1], Args[2])
	elseif Call == "newtable" then
		assert((#Args == 0), "invalid number of arguments")
		lua_newtable(L)
	elseif Call == "settable" then
		assert((#Args == 1), "invalid number of arguments")
		lua_settable(L, Args[1])
	elseif Call == "newuserdata" then
		assert((#Args == 0), "invalid number of arguments")
		lua_newuserdata(L)
	elseif Call == "pushuserdata" then
		assert((#Args == 0), "invalid number of arguments")
		lua_newuserdata(L)
	elseif Call == "tonumber" then
		assert((#Args == 1), "invalid number of arguments")
		print(lua_tonumber(L, Args[1]))
	elseif Call == "tostring" then
		assert((#Args == 1), "invalid number of arguments")
		print(lua_tostring(L, Args[1]))
	elseif Call == "touserdata" then
		assert((#Args == 1), "invalid number of arguments")
		print(lua_touserdata(L, Args[1]))
	elseif Call == "toboolean" then
		assert((#Args == 1), "invalid number of arguments")
		print(lua_toboolean(L, Args[1]))
	else
		error("invalid function", 0)
	end
	
	return
end

local luaC_execline = setfenv(_luaC_execline, setmetatable(LuaAPI, {__index = getfenv()}))
function luaC_execute(Code, DontAllowComments)
	local State = LuaAPI.luaL_newstate()
	for Line in string.gmatch(Code, "[^\r\n]+") do
		if Line:sub(1, 2) ~= "--" and DontAllowComments ~= true then -- ignore comments
			luaC_execline(State, Line)
		end
    end
    
	LuaAPI.lua_close(State)
end

--[[
luaC_execute([==[
getglobal print
pushstring Hello, World!
pcall 1 0 0
printstack
]==])
]]

return luaC_execute, luaC_execline, LuaAPI.luaL_newstate, LuaAPI.lua_close
-- <eof>
