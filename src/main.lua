-- SECTION 1 -- Redefine Table Functions for Vanilla Lua Support --
getfenv(0).table = {}
table.insert = function(...) -- I have to change it because the normal insert uses rawget and rawset which dont work with userdatas.
	local Arguments = {...}
	local Table = Arguments[1]
	local Value = Arguments[2]
	local Field = Arguments[3]

	if Table and Value then
		if Field then
			Table[Field] = Value
			return Value
		else
			Table[#Table + 1] = Value
			return Value
		end
	else
		return false
	end
end

table.shift = function(Table, StartIter)
	local Temp = {}
	for i,v in pairs(Table) do
		if type(i) == "number" then
			Temp[StartIter] = v
			StartIter = StartIter + 1
        elseif i == nil then
            -- do nothing
        else
			Temp[i] = v
		end
	end

	Table = Temp
	return Temp
end

table.find = function(Table, Value) -- 1: i am using basic lua (not roblox lua), and 2: i think table.find uses rawget
	for i = 1, #Table, 1 do
		local v = Table[i]
		if v == Value then return i end
	end

	return nil
end

table.flip = function(Table)
    local Temp = {}
    for i = #Table, 1, -1 do
        v = Table[i]
        table.insert(Temp, v)
    end

    return Temp
end

table.concat = function(Table, Sep)
	Sep = Sep or " "
	local Concatenated = ""
	for i,v in pairs(Table) do
		Concatenated = Concatenated..Sep..tostring(v)
	end

	return Concatenated:sub(2)
end

-- SECTION 2 -- Define Memory and a Few Functions --
local Memory = {
    LuaTypes = {
        LUA_TNONE = -1,
        LUA_TNIL = 0,
        LUA_TBOOLEAN = 1,
        LUA_TLIGHTUSERDATA = 2,
        LUA_TNUMBER = 3,
        LUA_TSTRING = 4,
        LUA_TTABLE = 5,
        LUA_TFUNCTION = 6,
        LUA_TUSERDATA = 7,
        LUA_TTHREAD = 8
    };

    GlobalNil = {};
    LuaStates = {};
	LuaThreads = {};
    Cache = {};
    Address = 0x0000001;
}

local StackFunctions = {
    push = function(LuaState, Value)
        local Stack = LuaState.Stack
		if #Stack >= 2048 then
			error("stack overflow")
		end

        table.insert(Stack, Value)
        return
    end;
    
    get = function(LuaState, Field)
        local Stack = LuaState.Stack
        local Value;
    
        Field = tonumber(Field)
        if Field < 0 then
            Field = Field + 1
            Value = Stack[#Stack + Field] -- If field is -5 it should return the last 5 values from the stack.
        else
            Value = Stack[Field]
        end
        
        if Value == LuaState.LuaNil then Value = nil elseif Value == nil then error("Stack Index out of range") end
        return Value
    end;
    
    rem = function(LuaState, Field)
        local Stack = LuaState.Stack
        Field = tonumber(Field)
        if Field < 0 then
            Field = Field + 1
            Stack[#Stack + Field] = Memory.GlobalNil
			-- fix rem func
        else
            Stack[Field] = Memory.GlobalNil
        end

		local Temp = {}
		for i = 1, #Stack, 1 do
			if Stack[i] ~= Memory.GlobalNil then
				table.insert(Temp, Stack[i])
			end
		end

		LuaState.Stack = Temp
        return Temp
    end;
}

function gettype(Obj)
    if not Obj then
        return Memory.LuaTypes.LUA_TNONE
    else
        if type(Obj) == 'nil' then
            return Memory.LuaTypes.LUA_TNIL
        elseif type(Obj) == 'boolean' then
            return Memory.LuaTypes.LUA_TBOOLEAN
        elseif type(Obj) == 'number' then
            return Memory.LuaTypes.LUA_TNUMBER
        elseif type(Obj) == 'string' then
            return Memory.LuaTypes.LUA_TSTRING
        elseif type(Obj) == 'table' then
            return Memory.LuaTypes.LUA_TTABLE
        elseif type(Obj) == 'function' then
            return Memory.LuaTypes.LUA_TFUNCTION
        elseif type(Obj) == 'userdata' and not string.match(tostring(Obj), 'vmthread') then
            return Memory.LuaTypes.LUA_TUSERDATA
        elseif type(Obj) == 'thread' or string.match(tostring(Obj), 'vmthread') then
            return Memory.LuaTypes.LUA_TTHREAD
        else
            return Memory.LuaTypes.LUA_TLIGHTUSERDATA
        end
    end
end

function getaddress()
	Memory.Address = Memory.Address + 0x01 - 0x01
	return string.format('0x%07x', Memory.Address)
end

-- SECTION 3 -- Define the Lua API --
local LuaAPI = {}
LuaAPI.luaL_newstate = function()
    local NewState = {
        Stack = {};
        LuaNil = {};
    }
    
    local Proxy = newproxy(true) -- hehe userdata for life
    local StateAddr = tostring(Proxy):sub(11)

    local Meta = getmetatable(Proxy)

    Meta.__index = function(_, Field)
        return NewState[Field]
    end
    
    Meta.__newindex = function(_, Field, Value)
        NewState[Field] = Value
    end
    
    Meta.__tostring = function()
        return "state: "..StateAddr
    end
    
    Meta.__metatable = "This metatable is locked."

    return table.insert(Memory.LuaStates, Proxy)
end;

LuaAPI.luaL_loadstring = function(LuaState, String)
    return loadstring(String)
end;

LuaAPI.lua_newthread = function(LuaState)
    local Thread = newproxy(true)
    local Meta = getmetatable(Thread)
    local TCache = {}
    local TADDR = getaddress()

    Memory.LuaThreads[Thread] = TADDR
    Meta.__index = TCache
    Meta.__tostring = function() return "vmthread: "..TADDR end
    Meta.__len = function() return "vmthread" end
    Meta.__call = function(self, CALL)
        if not TCache[CALL] then
            local _Thread = coroutine.create(CALL)
            TCache[_Thread] = getaddress()
            TCache[CALL] = _Thread

            return _Thread
        else
            return TCache[CALL]
        end
    end

    StackFunctions.push(LuaState, Thread)
    return Thread
end;

LuaAPI.lua_yield = function(LuaState, StackPosition)
    local Thread = StackFunctions.get(LuaState, StackPosition)
    return coroutine.yield(Thread)
end;

LuaAPI.lua_type = function(LuaState, StackPosition)
    if not StackPosition then
        local Item = LuaState
        return gettype(Item)
    else
        local Item = StackFunctions.get(LuaState, StackPosition)
        return gettype(Item)
    end

    return "LUA_TNONE"
end;

LuaAPI.lua_resume = function(LuaState, N_Args)
    N_Args = tonumber(N_Args)

    --warn("Function:", (-N_Args + -1))
    local Func = StackFunctions.get(LuaState, (-N_Args + -1)) -- if N_Args is one we will get neg2 as the function to call.
    local Arguments = {}

    for i = 1, N_Args do
        i = -i

        local Argument = StackFunctions.get(LuaState, i)
        table.insert(Arguments, Argument)
    end
    Arguments = table.flip(Arguments) -- we need to flip it because if we're counting up. We have to count down to sort arguments.

    --[[
        warn("Arguments Test:")
        for i,v in pairs(Arguments) do
            warn(i,v)
        end
    ]]
    local ReturnParams;
    ReturnParams = {coroutine.resume(Func(unpack(Arguments)))}

    if ReturnParams then
        for i,v in pairs(ReturnParams) do  
            StackFunctions.push(LuaState, v)
        end
    end

    return ReturnParams
end;

LuaAPI.lua_close = function(LuaState)
    Memory.LuaStates[LuaState] = nil -- goodbye
    return
end;

LuaAPI.lua_pushstring = function(LuaState, String)
    assert((type(String) == "string"), "Argument type \""..type(String).."\" is incompatible with parameter of type string")
    StackFunctions.push(LuaState, String)
    return
end;

LuaAPI.lua_pushnumber = function(LuaState, Num)
    assert((type(Num) == "number"), "Argument type \""..type(Num).."\" is incompatible with parameter of type number")
    StackFunctions.push(LuaState, tonumber(Num))
    return
end;

LuaAPI.lua_pushnil = function(LuaState)
    StackFunctions.push(LuaState, LuaState.LuaNil)
    return
end;

LuaAPI.lua_pushboolean = function(LuaState, Bool)
    assert((type(Bool) == "boolean"), "Argument type \""..type(Bool).."\" is incompatible with parameter of type boolean")
    StackFunctions.push(LuaState, Bool)
    return
end;

LuaAPI.lua_printstack = function(LuaState)
    local Stack = LuaState.Stack
    local Iteration = 0
    local Value = nil

    repeat
        Iteration = Iteration + 1
        if Iteration ~= 1 then print((Iteration - 1), Value) end
        Value = Stack[Iteration]
    until Value == nil
    return
end;

LuaAPI.lua_emptystack = function(LuaState)
    local Stack = LuaState.Stack
    local Iteration = 0
    local Value = nil

    repeat
        Iteration = Iteration + 1
        Value = Stack[Iteration]
        if Value then
            Stack[Iteration] = nil
        end
    until Value == nil
    return
end;

LuaAPI.lua_clearstack = LuaAPI.lua_emptystack;

LuaAPI.lua_getfield = function(LuaState, StackPosition, Field)
    --warn(LuaState, StackPosition, Field)
    local Value = StackFunctions.get(LuaState, StackPosition)

    StackFunctions.push(LuaState, Value[Field])
    return Value[Field]
end;

LuaAPI.lua_setfield = function(LuaState, StackPosition, Field)
    local Table = StackFunctions.get(LuaState, StackPosition) -- i.e: Character
    local Value = StackFunctions.get(LuaState, -1) -- Last value is always the value.

    Table[Field] = Value
    LuaAPI.lua_pop(LuaState, -1)
    return true
end;

LuaAPI.lua_getglobal = function(LuaState, Global) -- Update 1: Global caching added.
    local LuaNil = LuaState.LuaNil
    local Global = Memory.Cache[Global] or getfenv(0)[Global]
    if Global == nil then
        Global = LuaNil
    elseif not Memory.Cache[Global] then
        Memory.Cache[Global] = true
    end

    StackFunctions.push(LuaState, Global)
    return Global
end;

LuaAPI.lua_setglobal = function(LuaState, Global, Value)
    Memory.Cache[Global] = Value
    return Value
end;

LuaAPI.lua_checkstack = function(LuaState)
    return (LuaState.Stack >= 2048)
end;

LuaAPI.lua_pushvalue = function(LuaState, StackPosition) -- ok it should be stackindex but do i care?
    local Value = StackFunctions.get(LuaState, StackPosition)
    StackFunctions.push(LuaState, Value)

    return Value
end;

LuaAPI.lua_pushclosure = function(LuaState, Func)
    assert((type(Func) == "function"), "Argument type \""..type(Func).."\" is incompatible with parameter of type funtion")
    StackFunctions.push(LuaState, Func)
end;

LuaAPI.lua_call = function(LuaState, N_Args, N_Results)
    N_Args = tonumber(N_Args)
    N_Results = tonumber(N_Results)

    --warn("Function:", (-N_Args + -1))
    local Func = StackFunctions.get(LuaState, (-N_Args + -1)) -- if N_Args is one we will get neg2 as the function to call.
    local Arguments = {}

    for i = 1, N_Args do
        i = -i

        local Argument = StackFunctions.get(LuaState, i)
        table.insert(Arguments, Argument)
    end
    Arguments = table.flip(Arguments) -- we need to flip it because if we're counting up. We have to count down to sort arguments.

    --[[
        warn("Arguments Test:")
        for i,v in pairs(Arguments) do
            warn(i,v)
        end
    ]]
    local ReturnParams;
    ReturnParams = {Func(unpack(Arguments))}

    if ReturnParams then
        for i,v in pairs(ReturnParams) do
            if i > N_Results then break end
            StackFunctions.push(LuaState, v)
        end
    end

    return ReturnParams
end;

LuaAPI.lua_pcall = function(LuaState, N_Args, N_Results, ErrFunc)
    N_Args = tonumber(N_Args)
    N_Results = tonumber(N_Results)
    ErrFunc = tonumber(ErrFunc)

    if ErrFunc ~= 0 then
        ErrFunc = StackFunctions.get(LuaState, ErrFunc)
    else
        ErrFunc = function(_, Err) error(Err) end
    end

    local _, Err = pcall(function() LuaAPI.lua_call(LuaState, N_Args, N_Results) end)
    if Err then
        ErrFunc(_, Err)
    end
end;

LuaAPI.lua_settop = function(LuaState, Top) -- Update 3: Fixed settop
    local Stack = LuaState.Stack
    Top = Top + 1
    Stack[Top] = nil
    for i = #Stack, Top, -1 do
        Stack[i] = nil
    end

    return
end;

LuaAPI.lua_gettop = function(LuaState)
    local Stack = LuaState.Stack
    return(#Stack)
end;

LuaAPI.lua_pop = function(LuaState, StackPosition)
    local Stack = LuaState.Stack
    StackFunctions.rem(LuaState, StackPosition)

    return
end;

LuaAPI.lua_next = function(LuaState, TableStackPos)
    local Stack = LuaState.Stack
    local Table = StackFunctions.get(LuaState, TableStackPos)
    local TableNxtVal = Table[1]
    Table[1] = nil
    Table = table.shift(Table, 1)
    
    table.insert(Stack, Table, TableStackPos)
    table.insert(Stack, TableNxtVal)
    return
end;

LuaAPI.lua_insert = function(LuaState, StackPosition)
    local Stack = LuaState.Stack
    local Temp = {}
    local InsertPos = 0

    StackPosition = tonumber(StackPosition)
    for i,v in pairs(Stack) do
        if i == StackPosition then
            InsertPos = i
            table.insert(Temp, newproxy()) -- just a userdata placeholder
        end
        
        table.insert(Temp, v)
    end

    --print(Stack[#Stack])
    table.insert(Temp, (Stack[#Stack]), InsertPos)
    LuaState.Stack = Temp
    LuaAPI.lua_pop(LuaState, (#Stack + 1)) -- pop the value out because it's been "moved".
    return
end;

LuaAPI.lua_createtable = function(LuaState, ArrayAllocation, _) -- Update 2: Table allocation added.
    local Table = {}
    local Allocators = {}

    if not ArrayAllocation then ArrayAllocation = 0 end
    if not _ then _ = 0 end

    for i = 1, ArrayAllocation do
        local Allocator = newproxy(true)
        local Meta = getmetatable(Allocator)
        Meta.__tostring = function()
            return "nil"
        end

        table.insert(Allocators, Allocator)
        table.insert(Table, Allocator)
    end

    StackFunctions.push(LuaState, Table)
    return
end;
LuaAPI.lua_newtable = function(LuaState) lua_createtable(LuaState, 0, 0) return end;

LuaAPI.lua_settable = function(LuaState, StackPosition)
    local Table = StackFunctions.get(LuaState, StackPosition)
    local Value = StackFunctions.get(LuaState, -1)

    table.insert(Table, Value)
    LuaAPI.lua_pop(LuaState, -1)
    return
end;

LuaAPI.lua_newuserdata = function(LuaState)
    StackFunctions.push(LuaState, newproxy(true))
    return
end;

LuaAPI.lua_getmetatable = function(LuaState, StackPosition)
    local Obj = StackFunctions.get(LuaState, StackPosition)
    Obj = getmetatable(Obj)

    if Obj then
        StackFunctions.push(LuaState, Obj)
        return
    else
        return 0
    end
end;

LuaAPI.lua_setmetatable = function(LuaState, StackPosition)
    StackFunctions.push(setmetatable(StackFunctions.get(LuaState, -1), StackFunctions.get(LuaState, StackPosition)))
    LuaAPI.lua_pop(LuaState, -1)
    return
end;

LuaAPI.lua_toboolean = function(LuaState, StackPosition) return(StackFunctions.get(LuaState, StackPosition) and 1 or 0) end;
LuaAPI.lua_tointeger = function(LuaState, StackPosition) return(tonumber(StackFunctions.get(LuaState, StackPosition))) end;
LuaAPI.lua_tostring = function(LuaState, StackPosition) return(tostring(StackFunctions.get(LuaState, StackPosition))) end;
LuaAPI.lua_tonumber = function(LuaState, StackPosition) return(tonumber(StackFunctions.get(LuaState, StackPosition))) end;
LuaAPI.lua_touserdata = function(LuaState, StackPosition) return(tostring(StackFunctions.get(LuaState, StackPosition)):sub(11)) end;

return LuaAPI
-- <eof>
