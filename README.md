# Lwrap
<img src="https://github.com/OpenGamerTips/Lwrap/raw/master/icon.png" alt="Lwrap Icon"></img><br>
Lwrap is a Lua API Wrapper written in vanilla Lua 5.1.5.<br>
Lua C executors parse the text in a script and use the API to do what has been parsed. Because the script is being parsed we can parse in the same way to execute Lua C scripts.
[Click here to view my Lua C VM source](https://raw.githubusercontent.com/OpenGamerTips/Lwrap/master/src/lua_c_vm.lua).<br><br>Here's a demo of the Lua C VM:<br>[![Run on Repl.it](https://repl.it/badge/github/OpenGamerTips/luacvm)](https://luacvm-4.nicholash777.repl.run)

# Usage
You can use this for practicing Lua C, or if you just want to add this to your exploit i'm totally fine with that. This could be extremely useful for old scripts that were written when only Lua C executors existed.

# How to Use
**NOTE: LWRAP OVERWRITES TABLE FUNCTIONS**<br>
If you require *module.lua*, it will return the Lua API in a table as seen below:
<br><img src="https://h3x0r.has-no-bra.in/j9IaVR.png" alt="eof_module.lua"><br><br>
This will show the stack and print out '*Hello, World!*' if your executor supports HttpGet:
```
local LuaAPI = loadstring(game:HttpGet("https://raw.githubusercontent.com/OpenGamerTips/Lwrap/master/src/main.lua"))()
function DoCode()
    local L = luaL_newstate() -- Create a lua state.
    lua_getglobal(L, "print")
    lua_pushstring(L, "Hello, World!")
    lua_printstack(L) -- Show the stack.
    lua_call(L, 1, 0)
    
    return
end
setfenv(DoCode, setmetatable(LuaAPI, {__index = getfenv()}))()
```

The Lua C VM returns quite a bit of arguments but only one is needed.
```
local luaC_execute, luaC_execline, luaL_newstate, lua_close = loadstring(game:HttpGet("https://raw.githubusercontent.com/OpenGamerTips/Lwrap/master/src/lua_c_vm.lua"))()

-- Executes a Lua C script
luaC_execute([[
getglobal print
pushstring Hello, World!
printstack
call 1 0
]])

-- Executes by line
local L = luaL_newstate()
luaC_execline(L, "getglobal print")
luaC_execline(L, "pushstring Hello, World!")
luaC_execline(L, "printstack")
luaC_execline(L, "call 1 0")
lua_close(L)
```

# Supported Versions
Lwrap is supported in Lua 5.1.x without any dependencies as they are written in the vm itself.

# Installation
There is really no installation process. Just copy and paste easy enough.