-- Filename: restoreSetting.lua
module(..., package.seeall)
require "config"
require "nvm"

nvm.init("config.lua")

local tKeypad = {
    ["50"] = "1"
}

local pressTag = false

local function keyLongPressTimerCb(keyName)
    log.info("keypadCB : ", keyName, pressTag)
    if keyName == "1" and pressTag == true then
        nvm.restore()
        sys.restart("keypad reboot")
    end
end

local function keyMsg(msg)
    local keyName = tKeypad[msg.key_matrix_row .. msg.key_matrix_col]
    log.info("keyMsg", msg.key_matrix_row, msg.key_matrix_col, msg.pressed, keyName)
    if msg.pressed then
        pressTag = true
        sys.timerStart(keyLongPressTimerCb, 5000, keyName)
    else
        pressTag = false
    end
end

rtos.on(rtos.MSG_KEYPAD, keyMsg)
rtos.init_module(rtos.MOD_KEYPAD, 0, 0x20, 0x0F)
-- By GST @2024/10/25