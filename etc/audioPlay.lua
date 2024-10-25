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
                    return false, "请求缺少播放的文件
                                   if file_name == nil or file_name == "" then
                    return false, "请求缺少播放的文件名"
                end
                tmp_content = util.getFilePath(file_name)
            else
                tmp_content = upload_path
            end
        elseif tjsondata["playType"] == 2 then  -- 语音合成
            tmp_content = tjsondata["content"]
        end
        tmp_duration = tjsondata["playDuration"]
        tmp_audio_level = tjsondata["audioLevel"]
        tmp_play_status = tjsondata["playStatus"]
    end
    if tmp_play_type == 1 or tmp_play_type == 3 then
        if io.exists(tmp_content) then
            if tmp_time_type == 0 then  -- 时长播放
                duration_tag = true
                audio.play(7, "FILE", tmp_content, tmp_duration, playAudioCb)
            elseif tmp_time_type == 1 then  -- 次数播放
                times_tag = true
                audio.play(7, "FILE", tmp_content, tmp_duration, playAudioCb)
            elseif tmp_time_type == 2 then  -- 循环播放
                audio.play(7, "FILE", tmp_content, 0, playAudioCb)
            end
        else
            return false, "文件不存在"
        end
    elseif tmp_play_type == 2 then
        if tmp_content ~= nil and tmp_content ~= "" then
            audio.play(7, "TTS", tmp_content, tmp_duration, playAudioCb)
        else
            return false, "语音合成内容为空"
        end
    end
    play_process = true
    play_status = tmp_play_status
    nvm.set("play_status", play_status)
    nvm.set("audio_level", tmp_audio_level)
    return true, "播放成功"
end

function stopAudio()
    if play_process then
        audio.stop()
        play_process = false
        play_status = 0
        nvm.set("play_status", play_status)
        nvm.set("audio_level", 9999)
    end
end

function conflictStopAudio()
    if play_process then
        audio.stop()
        play_process = false
        play_status = 0
        nvm.set("play_status", play_status)
        nvm.set("audio_level", 9999)
    end
end

function getPlayStatus()
    return play_process
end

function getPlayInfo()
    return playInfo
end

function setVolume(vol)
    volume = vol
    audio.setVolume(vol)
    nvm.set('volume', vol)
end

function getVolume()
    return volume
end

-- By GST @2024/10/25
