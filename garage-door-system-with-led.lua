LED_PIN = 5
gpio.mode(LED_PIN, gpio.OUTPUT)

function ledAction(action)
  value = true
  tmr.stop(0)
  if (action == 1) then --on
    gpio.write(LED_PIN,0)
  elseif (action == 2) then --blink
    tmr.alarm(0, 125, 1, function ()
      gpio.write(LED_PIN, value and gpio.HIGH or gpio.LOW)
      value = not value
      end)
  else
    gpio.write(LED_PIN,1) --off
  end
end

--[ garage-door
door_state=7  --globals
last_state=7

function doorState(s)
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
  elseif (is_dn) then door_state=1; last_state=1; ledAction(0) --closed,closed
  elseif (is_up) then door_state=4; last_state=4; ledAction(1) --open,open
  elseif (not (is_up or is_dn)) then         --in motion
    ledAction(2)
    if (last_state == 1) then door_state=5      --if was closed, then now opening
    elseif (last_state == 4) then door_state=2  --if was open, then now closing
    end
    -- start motion timer
    tmr.alarm(2,10000,0, function () 
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

gpio.mode(1, gpio.INT, gpio.PULLUP)
gpio.mode(2, gpio.INT, gpio.PULLUP)
gpio.trig(1, "both", sensorChange)
gpio.trig(2, "both", sensorChange)

--bring up system
sensorChange()

p_flag = 0
tmr.alarm(1, 1000, 1, function ()
  if (door_state ~= p_flag) then
    p_flag = door_state
    print(doorState(door_state))
  end
end)