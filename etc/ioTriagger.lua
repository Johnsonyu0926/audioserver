-- ioTriagger.lua
module(..., package.seeall)
require "pins"
require "nvm"
require "config"
require "audio"
require "util"
nvm.init("config.lua")

local ioPlayStatus = false
local io_play_process = false
local io_signal_time = nvm.get('io_signal_time')
local playFile = nvm.get('io_play_file_name')
local stop_tag = false
local io_audio_level = nvm.get('io_priority')
local io_play_status = nvm.get('io_play_status')
local playInfo = {}
local monitor_status = nvm.get('monitor_status')
local signalEnable = nvm.get('signal_enable')

local getGpio27Fnc = pins.setup(pio.P0_27)
local getGpio28Fnc = pins.setup(pio.P0_28)
local getGpio5Fnc = pins.setup(pio.P0_05)
local getGpio17Fnc = pins.setup(pio.P0_17)

local ioPlayInfo = nvm.get('io_play_info')

function updateIoSet()
    requestUrl = nvm.get('io_request_url')
    interval_time = nvm.get('io_interval_time')
    ioPlayInfo = nvm.get('io_play_info')
    io_signal_time = nvm.get('io_signal_time')
    monitor_status = nvm.get('monitor_status')
    signalEnable = nvm.get('signal_enable')
end

function stopIoPlay(id)
    log.info('停止IO播放, id=', id)
    if id ~= nil and id == 2 then
        sys.wait(3000)
    end
    stop_tag = false
    io_play_process = false
end

local function judgePlay()
    local H1, H2 = getGpio17Fnc(), getGpio5Fnc()
    local L1, L2 = getGpio27Fnc(), getGpio28Fnc()
    log.info('H1, H2, L1, L2:', H1, H2, L1, L2)
    return L1 == 0 or L2 == 0 or H1 == 0 or H2 == 0
end

function operateInfboard(typeId)
    if ioPlayInfo == nil then
        return
    end
    local data = {}
    if typeId == 1 then
        if ioPlayInfo['infoboard'] == nil or ioPlayInfo['infoboard']['start']['command'] == nil or ioPlayInfo['infoboard']['start']['command'] == '' then
            return
        else
            data = {
                ledCommand = ioPlayInfo['infoboard']['start']['command'],
                operateType = ioPlayInfo['infoboard']['start']['operateType']
            }
            if ioPlayInfo['infoboard']['start']['operateType'] == 1 then
                data['showContent'] = ioPlayInfo['infoboard']['start']['content']
            end
        end
    else
        if ioPlayInfo['infoboard'] == nil or ioPlayInfo['infoboard']['stop']['command'] == nil or ioPlayInfo['infoboard']['stop']['command'] == '' then
            return
        else
            data = {
                ledCommand = ioPlayInfo['infoboard']['stop']['command'],
                operateType = ioPlayInfo['infoboard']['stop']['operateType']
            }
            if ioPlayInfo['infoboard']['stop']['operateType'] == 1 then
                data['showContent'] = ioPlayInfo['infoboard']['stop']['content']
            end
        end
    end
    log.info('LED data: ', json.encode(data))
    rs485.ledRun(data)
end

function operateRelay(typeId)
    if ioPlayInfo['relayEnable'] == nil or ioPlayInfo['relayEnable'] ~= 1 then
        return
    end
    util.updateRelayStatus(4, 1, typeId)
    util.updateRelayListByIO(typeId)
end

function ioPLayCore(data)
    log.info('infoBoard get: ', json.encode(ioPlayInfo))
    local tag, rsg = audioPlay.playCore(data)
    operateInfboard(1)
    operateRelay(1)
    if tag then
        io_play_process = true
        stop_tag = true
    end
end

function ioStopCore()
    if io_play_process == true and stop_tag == true then
        log.info('监测停止信号，停止播放')
        local stopMode = nvm.get('stop_mode')
        log.info('iostopMode: ', stopMode)
        if stopMode == 1 then
            audioPlay.stopAudio()
        else
            local data = audioPlay.getPlayInfo()
            log.info('当前播放内容: ', json.encode(data))
            data['end_time'] = 1
            audioPlay.changePlayInfo(data)
        end
        io_play_process = false
        stop_tag = false
        operateRelay(0)
        operateInfboard(0)
    end
end

function validateParams()
    return ioPlayInfo == nil or 
    ((ioPlayInfo['ioPlayFileName'] == nil or ioPlayInfo['ioPlayFileName'] == '') 
    and (ioPlayInfo['infoboardInfo'] == nil or ioPlayInfo['start'] == nil or ioPlayInfo['start'] == '' or ioPlayInfo['start']['command'] == nil or ioPlayInfo['start']['command'] == '' 
    or ioPlayInfo['stop'] == nil or ioPlayInfo['stop'] == '' or ioPlayInfo['stop']['command'] == nil or ioPlayInfo['stop']['command'] == nil) 
    and (ioPlayInfo['relayEnable'] == nil or ioPlayInfo['relayEnable'] == false))
end

local modelType = nvm.get('io_model_type')
if modelType == 1 then
    sys.taskInit(function()
        sys.timerLoopStart(function()
            log.info('monitor status: ', monitor_status, signalEnable)
            if monitor_status == 1 and signalEnable == 1 then
                if validateParams() then
                    log.info('IO参数校验不通过')
                    return
                end
                if judgePlay() == true then
                    if io_play_process == false then
                        local data = {
                            priority = nvm.get('io_priority'),
                            playStatus = nvm.get('io_play_status'),
                            fileName = ioPlayInfo['ioPlayFileName'],
                            playType = 1,
                            playDuration = 14400,
                            timeType = 0
                        }
                        if data['playStatus'] == 0 then
                            ioPLayCore(data)
                        else
                            if util.validateGoToPlay(data) == true then
                                ioPLayCore(data)
                            end
                        end
                    else
                        log.info("IO播放中，不重复播放")
                    end
                else
                    ioStopCore()
                end
            else
                if io_play_process == true then
                    ioStopCore()
                end
            end
        end, io_signal_time)
    end)
end

local requestUrl = nvm.get('io_request_url')
local interval_time = nvm.get('io_interval_time')
local is_report = false
local count = 0
if modelType == 2 or modelType == '2' then
    sys.taskInit(function()
        while not socket.isReady() do
            sys.wait(5000)
        end
        while true do
            local signal_enable = nvm.get('signal_enable')
            local monitor_status = nvm.get('monitor_status')
            log.info('monitor status: ', monitor_status, signal_enable, is_report)
            if monitor_status == 1 and signal_enable == 1 then
                if judgePlay() == true then
                    if is_report == false then
                        is_report = true
                        if util.postRequest(requestUrl) then
                            count = 0
                        else
                            is_report = false
                        end
                    end
                end
            end
            sys.wait(1000)
            if is_report == true then
                count = count + 1
                log.info('计算是否需要上报: ', count, interval_time)
                if count > interval_time then
                    is_report = false
                    count = 0
                end
            end
        end
    end)
end
-- By GST @2024/10/25