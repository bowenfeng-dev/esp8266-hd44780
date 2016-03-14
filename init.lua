local EN = 1
local RS = 2
--local RW = 3
local D4 = 4
local D5 = 5
local D6 = 6
local D7 = 7
local BL = 10

local bor, band, bnot = bit.bor, bit.band, bit.bnot

local function pulse_enable(self)
  gpio.write(self.pin_e, gpio.HIGH)
  tmr.delay(1)
  gpio.write(self.pin_e, gpio.LOW)
end

local function send_n_bits(self, bits)
end

local function write4bits(self, bits, char_mode)
  gpio.write(self.pin_rs, char_mode and gpio.HIGH or gpio.LOW)

  for n = 1, 2 do
    for i, pin in ipairs(self.pin_db) do
      local j = (2-n)*4 + (i-1)
      local val = (bit.isset(bits, j))
      gpio.write(pin, val and gpio.HIGH or gpio.LOW)
    end
    self:pulse_enable()
  end
end

local function home(self)
  write4bits(self, 0x02)
end    

local function clear(self)
  write4bits(self, 0x01)
end

local function message(self, text)
  tmptext = text:gsub("\n", string.char(0xC0))
  for i = 1, #tmptext do
    local c = tmptext:byte(i)
    write4bits(self, c, (c ~= 0xC0))
  end
end

function init(pin_rs, pin_e, pin_db)
  local self = {
    pin_rs = pin_rs,
    pin_e = pin_e,
    pin_db = pin_db
  }
  
  gpio.mode(self.pin_rs, gpio.OUTPUT)
  gpio.mode(self.pin_e, gpio.OUTPUT)
  for _, pin in ipairs(self.pin_db) do
    gpio.mode(pin, gpio.OUTPUT)
  end

  --self.home = home
  self.clear = clear
  self.message = message
  self.write4bits = write4bits
  self.pulse_enable = pulse_enable

  self:write4bits(0x33) -- initialization
  self:write4bits(0x32) -- initialization
  self:write4bits(0x28) -- 2 line 5x7 matrix
  self:write4bits(0x0C) -- turn cursor off 0x0E to enable cursor
  self:write4bits(0x06) -- shift cursor right

  --self:clear()

  return self
end


function update()
  http.get('http://192.168.1.192:5000/api/v1/weather',
    nil,
    function(code, data)
      if (code < 0) then
        m:message("HTTP request failed")
      else
        print(data)
        m:clear()
        m:message(data)
      end
    end)
end



SECOND = 1000
MINUTE = 60 * SECOND
PANIC_SAFTY_INTERVAL = 2 * SECOND

INIT_TIMER = 0
SPLASH_DELAY = 1
UPDATE_TIMER = 2

function main()
  print("--main")
  
  m = init(RS, EN, {D4, D5, D6, D7})
  clear(m)
  m:message("Love Bunny ~\nWeather Station")

  tmr.alarm(SPLASH_DELAY, 4 * SECOND, tmr.ALARM_SINGLE,
      function()
        update()
        gpio.mode(BL, gpio.OUTPUT)
        gpio.write(BL, gpio.HIGH)
        tmr.alarm(UPDATE_TIMER, 5 * MINUTE, tmr.ALARM_AUTO, update)
      end)
end

tmr.alarm(INIT_TIMER, PANIC_SAFTY_INTERVAL, tmr.ALARM_SINGLE, main)

