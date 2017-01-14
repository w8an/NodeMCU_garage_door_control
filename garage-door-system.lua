--[[ garage door control system
     written by Steven R. Stuart
     $Id: garage-door-system.lua,v 1.1 2016-10-16 21:51:49 strast Exp $

 door states
 1 closed
 2 closing
 3 closing-stopped
 4 open
 5 opening
 6 opening-stopped
 7 error

 
 
  ]]

btn = 5                      --gpio port connected to door open/close relay
gpio.mode(btn, gpio.OUTPUT)

door_state=7  --known door position
last_state=7  --used during door open timer

function doorState(s)  -- returns text of door state
  local ds = {"closed","closing","cl-stop","open","opening","op-stop","error"}  
  return ds[s] or "unk"
end

function getSensors()
    is_up = not(gpio.read(1)==1) 
    is_dn = not(gpio.read(2)==1)
end

function sensorChange()
  last_state=door_state
  tmr.alarm(1,1000,0, function () --debounce
    getSensors()                  --refresh sensor states
    setDoorState()                --determine door position
  end)
end

function setDoorState()
  if (is_dn and is_up) then door_state=7  --error
  elseif (is_dn) then door_state=1; last_state=1 --it's closed
  elseif (is_up) then door_state=4; last_state=4 --it's open
  elseif (not (is_up or is_dn)) then         --in motion
    if (last_state == 1) then door_state=5      --was closed, now opening
    elseif (last_state == 4) then door_state=2  --was open, now closing
    end
    -- start motion timer
    tmr.alarm(2,10000,0, function () -- 10 secs
      getSensors()
      if (is_dn and is_up) then door_state=7  --error
      else
        if(door_state==2) then door_state=3     --closing stopped
        elseif(door_state==5) then door_state=6 --opening stopped
        end
      end
    end) --tmr
  end
end

function pressBtn(n)
  gpio.write(btn, gpio.LOW)
  tmr.alarm(1,n,0,function() gpio.write(btn, gpio.HIGH) end)
end

srv=net.createServer(net.TCP)
srv:listen(80,function(conn)
  conn:on("receive", function(client,request)
    if request:sub(1,6) == "telnet" then
      -- console session
      node.output(function(s)
        if client ~= nil then client:send(s) end
      end,0)
      conn:on("receive",function(client,request)
        if request:byte(1) == 4 then client:close() -- ctrl-d to exit
        else node.input(request) end
      end)
      conn:on("disconnection",function(client)
        node.output(nil)
      end)
      print("NodeMCU "..doorState(door_state))
      node.input("\r\n")
      return
    end
    local buf = ""
    local _, _, method, path, vars = string.find(request, "([A-Z]+) (.+)?(.+) HTTP")
    if(method == nil)then
      _, _, method, path = string.find(request, "([A-Z]+) (.+) HTTP")
    end
    local _GET = {}
    if (vars ~= nil)then
      for k, v in string.gmatch(vars, "(%w+)=(%w+)&*") do
        _GET[k] = v
      end
    end
    buf = buf.."<h1>NodeMCU</h1>"..doorState(door_state)
    buf = buf.."<p>OUT5 <a href=\"?pin=A\"><button>press</button></a></p>"
    buf = buf.."<input type='button' value='Refresh' onClick='history.go(0)'>"
--    local _on,_off = "",""
    if(_GET.pin == "A")then pressBtn(250)
    end
    client:send(buf)
    client:close()
    collectgarbage()
  end)
end)

gpio.mode(1, gpio.INT, gpio.PULLUP)
gpio.mode(2, gpio.INT, gpio.PULLUP)
gpio.trig(1, "both", sensorChange)
gpio.trig(2, "both", sensorChange)

p_flag = 0
tmr.alarm(0, 1000, 1, function ()
  if (door_state ~= p_flag) then
    p_flag = door_state
    print(doorState(door_state))
  end
end)
