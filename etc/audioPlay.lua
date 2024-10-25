-- Filename: audioPlay.lua
--- 模块功能：音频播放处理
-- @author Mikasa
-- @module mqtt.core
-- @release 2021.11.24
module(..., package.seeall)

require "util"
require "config"
require "sys"
require "nvm"
require "ril"
nvm.init("config.lua")

require "audio"

audio.setChannel(1)

local play_process = false
local play_status = nil
local rtmp_status = false

local times_tag = false -- 次数播放标记
local duration_tag = false  -- 时长播放标记
local playInfo = {}

local volume = nvm.get('volume') -- 默认播放的音量为初始化获取的

local audio_level = nvm.get('audio_level')

local function playAudioCb(r) --播音回调
    play_process = false
    log.info("play end: ", r)
    sys.publish("play_end", r) -- r=0，表示播放成功结束
end

local function rtmpMsg(msg)
    log.info("audio.MSG_AUDIO", json.decode(msg))
    --[[
        result_code：
            0  ==  播放成功
            1  ==  播放失败
            2  ==  停止成功
            3  ==  停止失败
            4  ==  接收超时
            5  ==  连接失败
    ]]
    --sys.publish("RTMP_PLAY_OVER")
    if msg.result == true then
        local tag = true
        local result = 'success'
        if msg.result_code == 0 then
            rtmp_status = true
            result = '播放成功'
        elseif msg.result_code == 1 then
            tag = false
            result = '播放失败'
        elseif msg.result_code == 2 then
            rtmp_status = false
            result = '停止成功'
        elseif msg.result_code == 3 then
            tag = false
            result = '停止失败'
        elseif msg.result_code == 4 then
            tag = false
            result = '接收超时'
        elseif msg.result_code == 5 then
            tag = false
            result = '连接失败'
        else
            tag = false
            result = '未知处理结果'
        end

        sys.publish("RTMP_AUDIO_RST", tag, result)
    else
        sys.publish("RTMP_AUDIO_RST", 2, '未知错误')
    end
end

rtos.on(rtos.MSG_RTMP, rtmpMsg)

---- 播放主程序 ---------------------------------------------------------------------------------------
--[[
tjsondata = {
    playType = 1, -- 播放类型：1-文件播放；2-语音合成；3-录音文件播放
    timeType = 1, -- 时长类型：0-时长播放，1-次数播放,2-循环播放
    downloadUrl = '', -- 文件下载路径，如果有的话，且设备没有该文件，则下载
    fileName = ''， -- 播放的音频文件名
    content = '', -- 语音合成播放内容
    playDuration = 1, -- 时长播放，则为播放时长
    playCount= 1， -- 次数播放，则为播放次数
}
]]
function playCore(tjsondata)  
    log.info("进入play core: ", json.encode(tjsondata))
    local tmp_time_type, tmp_play_type, tmp_content, tmp_duration, tmp_audio_level,tmp_play_status = nil, nil, nil, nil,nil,nil
    local validate_tag = util.validateGoToPlay(tjsondata)
    if validate_tag == false then
        return false, "高优先级播放任务进行中"
    end
    play_status = nvm.get("play_status")
    if tjsondata ~= nil then
        tmp_play_type = tjsondata['playType']
        tmp_time_type = tjsondata['timeType']
        if tjsondata["playType"] == 1 or tjsondata['playType'] == 3 then  -- 文件播放
            local upload_path = tjsondata['uploadPath']
            if upload_path == nil or upload_path == "" then
                local file_name = tjsondata["fileName"]
                if file_name == nil or file_name == "" then
                    return false, "请求缺少播放的文件名"
                end
                upload_path = util.getFilePath(file_name)
            end
            local isChangeFileType = tjsondata['changeFileType']
            if isChangeFileType == 1 or isChangeFileType == "1" then
                if tjsondata['downloadUrl'] ~= nil and  tjsondata['downloadUrl'] ~= "" then
                    os.remove(upload_path)
                end
            end
            if io.exists(upload_path) then
                tjsondata["uploadPath"] = upload_path
            else
                if tjsondata['downloadUrl'] == nil or  tjsondata['downloadUrl'] == "" then
                    return false, "文件不存在"
                end
                tjsondata["uploadPath"] = upload_path
                nvm.set('download_tag', true)
                tag, result = util.downloadFile(tjsondata)
                nvm.set('download_tag', false)
                log.info("download result: ",tag, result)
                if tag == true and result == "上传成功" then
                    if io.exists(upload_path) ~= true then
                        return false, "重新下载后文件仍不存在"
                    end
                else
                    return false, "文件不存在，临时下载失败"
                end
            end
            tmp_content = upload_path
        elseif tjsondata['playType'] == 2 then
            if tjsondata['content'] == nil or tjsondata['content'] == "" then
                return false, "文字播报内容为空"
            end
            tmp_content = tjsondata['content']
        else
            return false, "不支持的播放类型"
        end
        local time_type = tjsondata['timeType']
        if time_type == 0 then -- 时长播放
            local play_duration = tjsondata['playDuration']
            if play_duration == nil or tonumber(play_duration) <= 0 then
                return false, "时长播放时，播放时长不能为空"
            end
            tmp_duration = play_duration
        elseif time_type == 1 then
            local play_count = tjsondata['playCount']
            if play_count == nil or tonumber(play_count) <= 0 then
                return false, "次数播放时，播放次数不能为空"
            end
            tmp_duration = play_count
        elseif time_type == 2 then
        else
            return false, "不支持的播放类型"
        end
        tmp_audio_level = tjsondata['priority']
        tmp_play_status = tjsondata['playStatus']
        if tjsondata['timeType'] == 1 then -- 次数播放
            if tjsondata['playCount'] == nil then
                return false, "请求缺少播放次数"
            end
            local isStop = util.validateAudioLevel(tmp_audio_level)
            log.info("次数播放是否停止现有播放: ", isStop)
            if isStop == true then
                conflictStopAudio()
            end
            playInfo = {
                timeType = tmp_time_type,
                playType = tmp_play_type,
                duration = tmp_duration,
                content = tmp_content,
                audioLevel = tmp_audio_level,
                playStatus = tmp_play_status
            }
            times_tag = true
        elseif tjsondata["timeType"] == 0 then -- 时长播放
            if tjsondata['playDuration'] == nil then
                return false, "请求缺少播放时长"
            end
            local isStop = util.validateAudioLevel(tmp_audio_level)
            log.info("时长播放是否停止现有播放: ", isStop)
            if isStop == true then
                conflictStopAudio()
            end
            playInfo = {
                timeType = tmp_time_type,
                playType = tmp_play_type,
                duration = tmp_duration,
                content = tmp_content,
                audioLevel = tmp_audio_level,
                playStatus = tmp_play_status
            }
            duration_tag = true
        elseif tjsondata['timeType'] == 2 then -- 循环播放
            playInfo = {
                playType = tjsondata['playType'],
                content = tmp_content,
                audioLevel = tmp_audio_level,
                playStatus = tmp_play_status
            }
            return repeatPlay(playInfo)
        else
            return false, "不支持的时长类型"
        end
        local s,t,r = pcall(rs485.volumeAdaptation)
        log.info('音量自适应处理: ', s,t, r)
        util.updatePlayStatus(playInfo)
        util.updateRelayWithPlay(1)
        return true, "播放成功"
    else
        return false, "播放信息为空"
    end
end

---- 录音喊话 ---------------------------------------------------------------------------------------
--[[
    data = {
        downloadUrl = '', -- 文件下载路径
    }
]]

    function recordPlay(data)
    local tag, result = true, ""
    local download_url = data['downloadUrl']
    if download_url == nil or download_url == "" then
        return false, "录音播放请求参数缺少录音文件下载路径"
    end
    log.info("新文件下载地址：", download_url)
    local last_download_url = nvm.get('last_download_url')
    log.info("上一个文件下载地址：", last_download_url)
    local formatt = util.getFileFormmat(download_url)
    local file_name = "call." .. formatt
    local upload_path = util.getFilePath(file_name)
    data["uploadPath"] = upload_path
    if download_url ~= last_download_url then
        nvm.set('download_tag', true)
        tag, result = util.downloadFile(data)
        nvm.set('download_tag', false)
    else
        if not io.exists(upload_path) then
            nvm.set('download_tag', true)
            tag, result = util.downloadFile(data)
            nvm.set('download_tag', false)
        end
    end
    -- 下载失败
    if not tag then
        return false, "录音下载失败: " .. result
    else -- 下载成功，开始播放
        nvm.set("last_download_url", download_url)
        data['fileName'] = file_name
        return playCore(data)
    end
end

---- 任务播放 ---------------------------------------------------------------------------------------
function planPlayCore(data)
    return playCore(data)
end

---- 循环播放 ---------------------------------------------------------------------------------------
function repeatPlay(data)
    if data['playType'] == 1 or data['playType'] == 3 then
        local file_name = data['content']
        if file_name == nil or file_name == '' then
            return false, "入参缺少播放文件名"
        end
        local file_path = util.getFilePath(file_name)
        if not io.exists(file_path) then
            return false, "文件不存在"
        end
        util.updatePlayStatus(data)
        audio.play(7, "FILE", file_path, 7, playAudioCb, true, 1000)
    else
        util.updatePlayStatus(data)
        audio.play(7, "TTS", data['content'], 7, playAudioCb, true, 1000)
    end
    util.updateRelayWithPlay(1)
    return true, "播放成功"
end

function getPlayInfo()
    return playInfo
end
function changePlayInfo(data)
    playInfo = data
end

function beginPlayTask(data)
    if playInfo['timeType'] == 0 then
        duration_tag = true
        playInfo = data
    elseif playInfo['timeType'] == 1 then
        times_tag = true
        playInfo = data
    end
end

sys.taskInit(function()
    sys.timerLoopStart(function() 
        if times_tag == true and next(playInfo) ~= nil then
            log.info("次数播放参数: ", times_tag, json.encode(playInfo))
            local init_count = playInfo['initCount']
            local play_type = playInfo["playType"]
            if init_count == nil then
                init_count = 0
            end
            if play_type == 1 or play_type == 3 then -- 文件播放(音频文件、录音文件)
                if init_count < playInfo["duration"] then
                    if not play_process and times_tag == true then
                        play_process = true
                        -- util.updatePlayStatus(playInfo)
                        audio.play(7, "FILE", playInfo['content'], 7, playAudioCb)
                        -- local r,d = sys.waitUntil("play_end")
                        init_count = init_count + 1
                        playInfo['initCount'] = init_count
                    else
                        log.info("process")
                    end
                else
                    if play_process == false then
                        times_tag = false
                        playInfo = {}
                        play_process = false
                        nvm.set("play_status", 0)
                        nvm.set("audio_level", 9999)
                        util.updateRelayWithPlay(0)
                    end
                end
            elseif play_type == 2 then -- tts播放
                if init_count < playInfo["duration"] then
                    if not play_process and times_tag == true then
                        play_process = true
                        -- util.updatePlayStatus(playInfo)
                        audio.play(7, "TTS", playInfo["content"], 7, playAudioCb)
                        init_count = init_count + 1
                        playInfo['initCount'] = init_count
                    end
                else
                    if play_process == false then
                        times_tag = false
                        log.info('次数播放停止播放')
                        playInfo = {}
                        nvm.set("play_status", 0)
                        nvm.set("audio_level", 9999)
                        log.info('times_tag: ', times_tag)
                        util.updateRelayWithPlay(0)
                    end
                end
            else
                log.info('不支持的播放类型, playType: ', play_type)
                times_tag = false
                playInfo = {}
                play_process = false
                nvm.set("play_status", 0)
                util.updateRelayWithPlay(0)
            end
        end
    end, 1000)
end)

-- 时长播放任务
sys.taskInit(function()
    sys.timerLoopStart(function() 
        if duration_tag == true and next(playInfo) ~= nil then
            log.info('时长播放参数: ', duration_tag, json.encode(playInfo))
            local play_type = playInfo["playType"]
            local end_time = playInfo['end_time']
            if end_time == nil or end_time == 0 then
                end_time = playInfo["duration"] + os.time()
                playInfo['end_time'] = end_time
            end
            if play_type == 1 or play_type == 3 then -- 文件播放/录音播放
                log.info("end time > os time")
                if end_time > os.time() then
                    if not play_process and duration_tag == true then
                        play_process = true
                        -- util.updatePlayStatus(playInfo)
                        audio.play(7, "FILE", playInfo['content'], 7, playAudioCb)
                    end
                else
                    if play_process == false then
                        duration_tag = false
                        log.info('stop play')
                        playInfo = {}
                        nvm.set("play_status", 0)
                        nvm.set("audio_level", 9999)
                        util.updateRelayWithPlay(0)
                    end
                end
            elseif play_type == 2 then -- tts播放
                if end_time > os.time() then
                    log.info("end time > os time")
                    if not play_process and duration_tag == true then
                        play_process = true
                        -- util.updatePlayStatus(playInfo)
                        audio.play(7, "TTS", playInfo["content"], 7, playAudioCb)
                    end
                else
                    if play_process == false then
                        duration_tag = false
                        log.info('时长播放停止播放')
                        playInfo = {}
                        nvm.set("play_status", 0)
                        nvm.set("audio_level", 9999)
                        util.updateRelayWithPlay(0)
                    end
                end
            else
                duration_tag = false
                log.info('不支持的操作')
                playInfo = {}
                play_process = false
                nvm.set("play_status", 0)
                util.updateRelayWithPlay(0)
            end
        end
    end, 1000)
end)

-- 停止播放  ------------------------------------------------------------------------------------------------
function stopAudio()
    log.info("手动停止播放")
    play = false
    if rtmp_status == true then
        log.info('rtmp stop')
        audiocore.rtmpclose()
    else
        log.info('audio stop')
        audio.stop()
    end
    rtmp_status = false
    play_status = 0
    nvm.set("play_status", 0)
    nvm.set("play_content", '')
    times_tag = false
    duration_tag = false
    play_process =false
    playInfo = {}
    audio_level = 9999
    nvm.set('audio_level', audio_level)
    util.updateRelayWithPlay(0)
    return true, "停止播放成功"
end

-- 冲突停止播放 -------------------------------1: 表示普通播放；2-表示rtmp；
function conflictStopAudio(type)
    log.info("冲突停止播放")
    local play_status = nvm.get('play_status')
    stopAudio()
    if play_status ~= 0 then
        if util.validateSuportVersion(nvm.get('iot_version_io')) == true then
            ioTriagger.stopIoPlay(type)
        end
        if util.validateSuportVersion(nvm.get('iot_version_ax')) == true then
            AxTrafficLights.stopPlay()
        end
    end
end

-- 流媒体播放 ------
function rtmpPlay(data)
    log.info('流媒体播放体: ', json.encode(data))
    local validate_tag = util.validateGoToPlay(data)
    log.info("流媒体播放优先级比较结果: ", validate_tag)
    if validate_tag == false then
        return false, "当前有播放进行中, 不能重复播放"
    end
    local isStop = util.validateAudioLevel(data['priority'])
    log.info("流媒体播放判断当前是否有播放需要停止: ", isStop)
    if isStop == true then
        conflictStopAudio(2)
    end
    local rtmp_url = data['streamPath']
    if data['roomId'] ~= nil and data['roomId'] ~= '' then
        rtmp_url = rtmp_url + data['roomId']
    end
    local retryCount = 0
    while retryCount < 3 do
        log.info('rtmpUrl: ', rtmp_url)
        local resultId = audiocore.rtmpopen(rtmp_url, 3)
        log.info("rtmp拉流结果: ", resultId)
        if resultId == true or resultId == 1 then
            local tag,code, result = sys.waitUntil('RTMP_AUDIO_RST', 10000)
            log.info('RTMP AUDIO RST: ', tag, code, result)
            if tag == false then
                retryCount = retryCount + 1
            else
                if code == true then
                    play_status = data['playStatus'] ~= nil and data['playStatus'] or 1
                    local playInfo = {
                        playType = 4,
                        content = rtmp_url,
                        audioLevel = data['priority'] ~= nil and data['priority'] or 3,
                        playStatus = play_status
                    }
                    util.updatePlayStatus(playInfo)
                    util.updateRelayWithPlay(1)
                    return code, result
                else
                    retryCount = retryCount + 1
                end
            end
        else
            log.info("rtmp拉流重试")
            retryCount = retryCount + 1
        end
    end
    return false, '播放失败'
end
-- By GST @2024/10/25