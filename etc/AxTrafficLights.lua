-- Filename: AxTrafficLights.lua
module(..., package.seeall)

require "nvm"
require "audioPlay"

nvm.init("config.lua")
local sd_card_path = nvm.get('sd_card_path')
local gpio4_status, gpio5_status
local green_audio = ""
local red_audio = ""
local greenBlinkAudio = ""
local play_audio = ""
local traffic_play_status = nvm.get('traffic_play_status')
local play_status = 0
local now_light_type = 0 -- 0: 初始状态；1-绿灯；2-红灯；3-绿闪
local greenList = {}
local traffic_priority = nvm.get('traffic_priority')
local stop_tag = false

local function playAudioCb(r) --播音回调
    play_status = 0
    sys.publish('play_audio_result', r)
end

-- 判断是否在绿灯倒计时
local function validateTimeCount()
    for _, value in ipairs(greenList) do
        if value == 1 then
            return true
        end
    end
    return false
end

function sliceTable(tbl, start, stop)
    if not tbl or #tbl == 0 then
        return {}
    end
    local slice = {}
    for i = start, (stop or #tbl) do
        slice[#slice + 1] = tbl[i]
    end
    return slice
end

-- 判断绿灯倒计时状态是否正常
local function validateGreenBlink()
    if #greenList <= 5 then
        return true
    end
    local tag, list = pcall(sliceTable, greenList, #greenList - 5, #greenList)
    log.info('绿灯解析: ', tag, list)
    if tag then
        for _, value in ipairs(list) do
            if value == 0 then
                return true
            end
        end
        return false
    end
    return true
end

local function validateAudioLevel(priority) -- 入参为本次请求的优先级数值
    local audio_level = nvm.get('audio_level') -- 当前正在播放的优先级
    if not priority then -- 如果请求参数优先级为空，则判断为正确，
        return false
    end
    return tonumber(audio_level) >= tonumber(priority)
end

function stopPlay()
    audio.stop()
    play_status = 0
    now_light_type = 0
    play_audio = ''
    nvm.set('play_status', 0)
    nvm.set("play_content", '')
    nvm.set('audio_level', 9999)
end

function getTrafficPlayInfo()
    return {
        lightType = now_light_type,
        playContent = play_audio
    }
end

-- 判断红绿灯模式;如果当前是在播放中，则播放播放的灯色状态（不检测其他灯色信号），检测到停止，则停止；当未播放时，检测信号进行播放判断; 绿灯转绿闪也需要一个周期来判断，先停止，在播放绿闪
sys.taskInit(function() 
    local getGpio5Fnc = pins.setup(pio.P0_05) --H1/H2默认为1，接收到高电平后，状态变为0
    local getGpio4Fnc = pins.setup(pio.P0_17)
    sys.wait(2000)
    log.info('澳星信号灯功能模块已加载')
    sys.timerLoopStart(function()
        local trafficLightsTag = nvm.get("monitor_status")
        local signalEnable = nvm.get('signal_enable')
        log.info('澳星信号灯使能开关/配置开关: ', signalEnable, trafficLightsTag)
        if trafficLightsTag == 1 and signalEnable == 1 then
            traffic_play_status = nvm.get('traffic_play_status')
            traffic_priority = nvm.get('traffic_priority')
            if validateAudioLevel(traffic_priority) then
                gpio4_status = getGpio4Fnc() -- 红灯 
                gpio5_status = getGpio5Fnc() -- 绿灯
                log.info('红灯，绿灯: ', gpio4_status, gpio5_status)
                if gpio4_status == 0 and gpio5_status == 0 then -- 如果红绿灯都为播放信号，则判定为异常状态，不做处理
                    if play_status == traffic_play_status then
                        log.info("红绿灯都为播放信号，且处理红绿灯播放中，停止播放")
                        stop_tag = true
                    end
                else
                    if now_light_type == 0 then --当前初始状态
                        log.info('进入初始状态判断')
                        if gpio5_status == 0 then
                            if validateTimeCount() then 
                                play_audio = nvm.get("green_blink_audio") -- 绿闪
                                now_light_type = 3
                                pcall(rs485.volumeAdaptation)
                            else
                                play_audio = nvm.get("green_audio") -- 绿灯
                                now_light_type = 1
                                pcall(rs485.volumeAdaptation)
                            end
                        elseif gpio4_status == 0 then
                            greenList = {}
                            play_audio = nvm.get("red_audio") -- 红灯
                            now_light_type = 2
                            pcall(rs485.volumeAdaptation)
                        else
                            log.info('不符合的状态，无需处理')
                        end
                    else
                        log.info('当前播放状态：', now_light_type)
                        if now_light_type == 1 then -- 当前播放绿灯
                            table.insert(greenList, gpio5_status) 
                            if play_status == traffic_play_status and gpio5_status == 1 then -- -- 当前绿灯灭或者红灯亮了
                                stop_tag = true
                            end
                        elseif now_light_type == 3 then -- 当前播放绿闪
                            table.insert(greenList, gpio5_status)
                            local isblink = validateGreenBlink()
                            log.info('是否为绿灯闪烁状态: ', isblink)
                            if play_status == traffic_play_status and not isblink then -- -- 当前绿闪灭或者红灯亮了
                                stop_tag = true
                            end
                        elseif now_light_type == 2 then -- 当前播放红灯
                            if play_status == traffic_play_status and gpio4_status == 1 then -- 当前红灯灭或者绿灯亮了
                                stop_tag = true
                            end
                        else
                            stop_tag = true
                        end
                    end
                end
            end
        else
            if play_status == traffic_play_status then
                stop_tag = true
            end
        end
    end, 200)
end)

-- 播放处理
sys.taskInit(function() 
    sys.timerLoopStart(function()
        if play_status == 0 then
            if now_light_type == 1 or now_light_type == 2 or now_light_type == 3 then
                if io.exists(sd_card_path .. play_audio) then
                    play_status = traffic_play_status
                    nvm.set('play_status', play_status)
                    nvm.set("play_content", play_audio)
                    nvm.set('audio_level', traffic_priority)
                    audio.play(7, "FILE", sd_card_path .. play_audio, 7, playAudioCb)
                else
                    now_light_type = 0
                end
            end
        else
            if stop_tag then
                stop_tag = false
                if play_status == traffic_play_status then
                    stopPlay()
                end
            end
        end
    end, 200)
end)

sys.taskInit(function() 
    sys.timerLoopStart(function()
        local storage = collectgarbage("count")
        log.info("已用内存 ", storage, #greenList)
        if #greenList > 5000 then
            greenList = {}
        end
        collectgarbage("collect")
    end, 5000)
end)
-- By GST @2024/10/25