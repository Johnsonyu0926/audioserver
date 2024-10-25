-- Filename: rs485.lua
module(..., package.seeall)

require "utils"
require "pm"
require "config"
require "nvm"
require "pmd"
require "audio"
require "common"
require "core"
require "util"

nvm.init("config.lua")

local baud = nvm.get('baud') or 57600
local UART_ID = 3
local last_decibel = 0
local retry_get_decibel = 0

local function taskRead()
    local cacheData = ""
    while true do
        local s = uart.read(UART_ID, "*l")
        if s == "" then
            if not sys.waitUntil("UART_RECEIVE", 100) and cacheData:len() > 0 then
                log.info("<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<: ", cacheData)
                if cacheData == "FFF" then
                    write("connect ok")
                end
                local dataHex = string.toHex(cacheData)
                log.info("received data:: ", dataHex)
                if string.sub(dataHex, 1, 8) == '55AA0000' then
                    nvm.set('rs485_recevier_data', dataHex)
                elseif string.sub(dataHex, 1, 4) == '55AA' and util.validateSuportVersion(nvm.get('iot_version_hk')) then
                    pcall(HkTrafficLights.handlerCore, dataHex)
                elseif string.sub(dataHex, 1, 4) == '0103' then
                    local value = tonumber(string.sub(dataHex, 7, 10), 16) / 10
                    log.info('当前噪声值: ', value)
                    last_decibel = value
                    retry_get_decibel = 0
                elseif string.sub(cacheData, 1, 4) == 'AABB' then
                    util.RS485ServiceSet(cacheData)
                else
                    local dataObj = json.decode(cacheData)
                    if type(dataObj) == 'table' and dataObj['cmd'] then
                        log.info('处理JSON协议')
                        local tag, result = tcpCore.coreRun(cacheData)
                        log.info("RS485协议处理结果: ", tag, result)
                    end
                end
                cacheData = ""
            end
        else
            cacheData = cacheData .. s
        end
    end
end

function write(text)
    log.info("testUart.write", text)
    uart.write(UART_ID, text .. "\r\n")
end

function noiseWrite(text)
    log.info("testUart.write", text)
    uart.write(UART_ID, text)
end

local function writeOk()
    log.info("testUart.writeOk")
end

pmd.ldoset(15, pmd.LDO_VLCD)
pm.wake("testUart")
uart.on(UART_ID, "receive", function() sys.publish("UART_RECEIVE") end)
uart.on(UART_ID, "sent", writeOk)
uart.setup(UART_ID, baud, 8, uart.PAR_NONE, uart.STOP_1, nil, 1)
uart.set_rs485_oe(UART_ID, pio.P0_19)
sys.taskInit(taskRead)

function ledRun(data)
    local commandList = data['ledCommand']
    local led_show_content = data['showContent']
    local operateType = data['operateType']
    if not commandList or #commandList == 0 then
        return false, "缺少指令"
    else
        local info = ""
        for _, value in pairs(commandList) do
            info = info .. string.char(value)
        end
        write(info)
        local infoBoardInfo = nvm.get('info_board_info') or {}
        if led_show_content and operateType == 1 then
            infoBoardInfo['content'] = led_show_content
        end
        if operateType == 2 or operateType == 3 then
            infoBoardInfo['operateType'] = operateType
        end
        log.info('infoboard: ', json.encode(infoBoardInfo))
        nvm.set('info_board_info', infoBoardInfo)
        return true, "设置成功"
    end
end

local ttl_uart_id = 1
uart.on(ttl_uart_id, "receive", function() sys.publish("TTL_RECEIVE") end)
uart.on(ttl_uart_id, "sent", ttlWriteOk)
uart.setup(ttl_uart_id, 115200, 8, uart.PAR_NONE, uart.STOP_1)

local function ttlRead()
    local cacheData = ""
    while true do
        local s = uart.read(ttl_uart_id, "*l")
        if s == "" then
            if not sys.waitUntil("TTL_RECEIVE", 1000) and cacheData:len() > 0 then
                log.info("<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<")
                log.info("ttl received data:: ", cacheData)
                log.info("ttl received data toHex:: ", string.toHex(cacheData))
                cacheData = ""
            end
        else
            cacheData = cacheData .. s
        end  
    end
end

sys.taskInit(ttlRead)

function ttlWrite(s)
    log.info("ttl testUart.write", s)
    uart.write(ttl_uart_id, s .. "\r\n")
end

local function ttlWriteOk()
    log.info("ttl testUart.writeOk")
end

function volumeSet(volume, muteType)
    log.info('下发音量值: ', volume)
    local mute_type = nvm.get("mute_type")
    local dac0_1 = nil
    if muteType and mute_type and mute_type ~= muteType then
        if muteType == 'mute' then
            dac0_1 = "A5 5A 09 03 02 00 00 16 A5 5A 0A 03 02 00 00 16 A5 5A FD 00 16"
        elseif muteType == 'unmute' then
            dac0_1 = "A5 5A 09 03 02 03 00 16 A5 5A 0A 03 02 03 00 16 A5 5A FD 00 16"
        end
        ttlWrite(string.fromHex(dac0_1))
    end
    local volumeMap = {
        ["0"] = "A5 5A 09 03 03 01 00 16 A5 5A 09 03 04 01 00 16 A5 5A 0A 03 03 01 00 16 A5 5A FD 00 16",
        ["1"] = "A5 5A 09 03 03 41 00 16 A5 5A 09 03 04 41 00 16 A5 5A 0A 03 03 41 00 16 A5 5A FD 00 16",
        ["2"] = "A5 5A 09 03 03 82 00 16 A5 5A 09 03 04 82 00 16 A5 5A 0A 03 03 82 00 16 A5 5A FD 00 16",
        ["3"] = "A5 5A 09 03 03 02 01 16 A5 5A 09 03 04 02 01 16 A5 5A 0A 03 03 02 01 16 A5 5A FD 00 16",
        ["4"] = "A5 5A 09 03 03 04 02 16 A5 5A 09 03 04 04 02 16 A5 5A 0A 03 03 04 02 16 A5 5A FD 00 16",
        ["5"] = "A5 5A 09 03 03 05 04 16 A5 5A 09 03 04 05 04 16 A5 5A 0A 03 03 05 04 16 A5 5A FD 00 16",
        ["6"] = "A5 5A 09 03 03 05 08 16 A5 5A 09 03 04 05 08 16 A5 5A 0A 03 03 05 08 16 A5 5A FD 00 16",
        ["7"] = "A5 5A 09 03 03 00 10 16 A5 5A 09 03 04 00 10 16 A5 5A 0A 03 03 00 10 16 A5 5A FD 00 16"
    }
    dac0_1 = volumeMap[tostring(volume)]
    if dac0_1 then
        ttlWrite(string.fromHex(dac0_1))
        return true
    else
        log.info("不支持的音量值")
        return false
    end
end

local volume = nvm.get("volume")
volumeSet(volume, nil)

local function exchangeVolume(tmpvolume)
    local volumeMap = { ["1"] = 3, ["2"] = 4, ["3"] = 5, ["4"] = 7 }
    return volumeMap[tostring(tmpvolume)] or tmpvolume
end

function ptzOperateRun(ptzCmd)
    log.info(string.toHex(ptzCmd))
    write(string.fromHex(ptzCmd))
    return true, "操作成功"
end

function volumeAdaptation()
    if util.validateSuportVersion(nvm.get('iot_version_volumeAda')) and nvm.get('volume_adaptation_status') == 1 then
        local nowVol = nvm.get('volume')
        for _, value in ipairs(nvm.get('volume_adaptation_schema')) do
            log.info('音量配置: ', nowVol, last_decibel, value['min'], value['max'], value['volume'])
            if last_decibel and last_decibel >= tonumber(value['min']) and last_decibel < tonumber(value['max']) then
                if tonumber(nowVol) ~= exchangeVolume(tonumber(value['volume'])) then
                    volume = exchangeVolume(value['volume'])
                    volumeSet(volume, nil)
                    nvm.set("volume", volume)
                    return true, '音量调节成功'
                else
                    return false, '音量一致，无需调节'
                end
            end
        end
    else
        return false, '该功能不支持自适应音量'
    end
end

function getDecibel()
    return last_decibel
end

function initDecibel()
    log.info('噪声采集模块加载....')
    while true do
        sys.waitUntil('get_decibel', 5000)
        log.info('采集噪声, 上一次噪声值: ', last_decibel)
        noiseWrite(string.fromHex("010300000001840A"))
        if retry_get_decibel >= 5 then
            last_decibel = 0
        else
            retry_get_decibel = retry_get_decibel + 1
        end
    end
end

-- By GST @2024/10/25