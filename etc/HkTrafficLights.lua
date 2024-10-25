-- HkTrafficLights.lua
module(..., package.seeall)

require "nvm"
require "util"
require "audioPlay"

nvm.init("config.lua")

local traffic_play_status = nvm.get('traffic_play_status')
local play_status = 0
local traffic_priority = nvm.get('traffic_priority')
local play_screen_num = nil

local function playAudioCb(r)
    play_status = 0
    sys.publish('play_audio_result', r)
end

local function getCmdList(data)
    local dataList = {}
    for i = 0, #data - 2, 2 do
        local tmp = string.sub(data, i + 1, i + 2)
        table.insert(dataList, tmp)
    end
    return dataList
end

local function getHxTrafficConfig()
    local config = nvm.get('hx_light_config')
    if config == nil or config == '' then
        return false, '无配置'
    end
    return true, config
end

function matchPolicy()
    local r, config = getHxTrafficConfig()
    if r ~= true then
        log.error("解析配置失败: ", config)
        return
    end
    if type(config) ~= 'table' then
        log.error("获取的配置格式不正确")
        return
    end
    for key, value in ipairs(config) do
        log.info('config: ', key, value)
        log.info('status: ', value['monitorStatus'])
        log.info('screenNum: ', value['screenNum'])
        log.info('redcCount ', value['redCountdown'])
        log.info('redAudioName ', value['redAudioName'])
    end
end

function handlerCore(data)
    local signalEnable = nvm.get('signal_enable')
    if signalEnable ~= 1 then
        log.info('总开关未打开')
        if play_status == traffic_play_status then
            log.info('监测到当前开关已关闭，停止播放')
            audioPlay.stopAudio()
            play_status = 0
            nvm.set('play_screen_num', nil)
        end
        return
    end
    local r, config = getHxTrafficConfig()
    if r ~= true then
        log.error("解析配置失败: ", config)
        return
    end
    if type(config) ~= 'table' then
        log.error("获取的配置格式不正确")
        return
    end
    local statusTag = false
    local play_screen_num = nvm.get('play_screen_num')
    for key, value in ipairs(config) do
        log.info('config size: ', #config)
        local screen_num = value['screenNum']
        local red_countdown = value['redCountdown']
        local red_audio = value['redAudioName']
        local monitorStatus = value['monitorStatus']
        log.info('当前配置: ', key, monitorStatus, screen_num, red_countdown, red_audio, play_screen_num)
        if play_screen_num == nil or play_screen_num == screen_num then
            if monitorStatus == 1 then
                statusTag = true
                local dataList = getCmdList(data)
                if dataList[4] == '0B' or dataList[4] == '0F' then
                    log.info("目前是红灯状态: ", dataList[4])
                end
                if dataList[1] == "55" and dataList[2] == "AA" then
                    local screenNumTmp = tonumber(dataList[3])
                    log.info('screenNum: ', screenNumTmp, screen_num)
                    if screen_num <= screenNumTmp then
                        local zoneData = dataList[2 + screen_num * 2]
                        local duration = dataList[3 + screen_num * 2]
                        local binData = util.hex2bin(zoneData, 8)
                        local screenAddr = string.sub(binData, 1, 5)
                        local blinkStatus = string.sub(binData, 6, 6)
                        local color = string.sub(binData, 7, 8)
                        local decDuration = tonumber(duration, 16)
                        log.info('zone, duration, bindata, screeaddr, blinkstatus, color, decduratin: ', zoneData, duration, binData, screenAddr, blinkStatus, color, decDuration)
                        play_status = nvm.get('play_status')
                        if color == "11" then
                            if decDuration ~= 0 then
                                local red_audio_path = util.getFilePath(red_audio)
                                if io.exists(red_audio_path) and red_countdown ~= nil then
                                    if red_countdown >= decDuration then
                                        if play_status == 0 then
                                            audio.play(7, "FILE", red_audio_path, 7, nil, true)
                                            play_status = traffic_play_status
                                            play_screen_num = screen_num
                                            nvm.set('play_screen_num', screen_num)
                                            nvm.set('play_status', play_status)
                                            nvm.set("play_content", red_audio_path)
                                            nvm.set('audio_level', traffic_priority)
                                        else
                                            if util.validateAudioLevel(traffic_priority) then
                                                audioPlay.conflictStopAudio()
                                                audio.play(7, "FILE", red_audio_path, 7, nil, true)
                                                play_status = traffic_play_status
                                                play_screen_num = screen_num
                                                nvm.set('play_screen_num', screen_num)
                                                nvm.set('play_status', play_status)
                                                nvm.set("play_content", red_audio_path)
                                                nvm.set('audio_level', traffic_priority)
                                            end
                                        end
                                    else
                                        log.error('未进入倒计时: ', red_countdown, decDuration)
                                    end
                                else
                                    log.error(red_audio .. '文件不存在')
                                end
                            else
                                log.error('倒计时校验失败，倒计时计算为： ', decDuration)
                            end
                        else
                            if play_status == traffic_play_status then
                                log.info('配置失效，停止播放')
                                audioPlay.stopAudio()
                                play_status = 0
                                nvm.set('play_screen_num', nil)
                            end
                        end
                    end
                end
            end
        end
    end
    if statusTag == false then
        if play_status == traffic_play_status then
            log.info('当前无配置，停止播放')
            audioPlay.stopAudio()
            play_status = 0
            nvm.set('play_screen_num', nil)
        end
    end
end
-- By GST @2024/10/25