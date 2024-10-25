-- Filename: datainit.lua
--- 模块功能：开机数据初始化
-- @author Mikasa
-- @module mqtt.core
-- @release 2023.12.29
module(..., package.seeall)

require "nvm"
require "pins"
require "config"
require "sys"
require "util"

nvm.init("config.lua")

local setGpio24Fnc = pins.setup(pio.P0_24, 0)  -- 24V 
local setGpio25Fnc = pins.setup(pio.P0_25, 0)  -- 5V
local setGpio26Fnc = pins.setup(pio.P0_26, 0)  -- 12V

function initData()
    log.info("数据初始化模块获取网络模式: ", NETMODE, NETWORKTYPE)
    if NETMODE == 1 or NETWORKTYPE == 1 then -- mqtt
        log.info('数据初始化模块(MQTT)')
        local relay_list = nvm.get('relay_list') or {
            { id = 1, relayMode = 1, relayStatus = 0 },
            { id = 2, relayMode = 1, relayStatus = 0 },
            { id = 3, relayMode = 1, relayStatus = 0 }
        }
        nvm.set('relay_list', relay_list)
        for _, val in ipairs(relay_list) do
            local status = val['val'] or val['relayStatus']
            local relay_mode = val['relayMode'] or 1
            util.updateRelayStatus(val['id'], relay_mode, status)
        end
        util.updateRelayList(relay_list)
    else
        log.info('数据初始化模块TCP')
        local relay_mode = nvm.get('relay_mode')
        local relay_status = nvm.get('relay_status')
        util.updateRelayStatus(0, relay_mode, relay_status)
    end
end

local reboot_task = nvm.get('reboot_task')

function updateRebootTask(task)
    reboot_task = task
end

sys.taskInit(function()
    sys.wait(30000)
    if NETMODE == 1 or NETWORKTYPE == 1 then
        sys.timerLoopStart(function()
            local t = os.date("*t", os.time())
            log.info("printTime", string.format("%04d-%02d-%02d %02d:%02d:%02d", t.year, t.month, t.day, t.hour, t.min, t.sec))
            log.info('reboot task: ', json.encode(reboot_task))
            local currentTime = string.format("%02d:%02d", t.hour, t.min)
            for _, val in ipairs(reboot_task) do
                log.info('对比时间：', val, currentTime)
                if val == currentTime then
                    log.info('开始重启')
                    sys.restart("定时重启")
                    break
                end
            end
        end, 60000)
    end
end)

-- By GST @2024/10/25