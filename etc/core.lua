-- Filename: core.lua
if cmd == 'ptzOperate' then
    local ptzCmd = data['operateCmd']
    if not ptzCmd or ptzCmd == '' then
        tag = false
        resultTable['result'] = "云台操作指令为空"
    else
        local status, set_status, result = pcall(rs485.ptzOperateRun, ptzCmd)
        if status then
            tag = set_status
            resultTable['result'] = result
        else
            tag = status
            resultTable['result'] = "处理错误: " .. set_status
        end
    end
elseif cmd == 'rebootTaskSet' then
    local reboot_task = data['rebootTask']
    if not reboot_task or #reboot_task == 0 then
        tag = false
        resultTable['result'] = '任务列表不能为空'
    else
        nvm.set('reboot_task', reboot_task)
        tag = true
        resultTable['result'] = '任务配置成功'
        dataInit.updateRebootTask(reboot_task)
    end
elseif cmd == 'getRebootTask' then
    tag = true
    resultTable['result'] = '获取成功'
    resultTable['data'] = { rebootTask = nvm.get('reboot_task') }
else
    resultTable["result"] = "不支持的操作"
end

resultTable['resultId'] = tag and 1 or 2
return resultTable
end

--- 获取开机信息
function getStartInfo()
    log.info('开机获取IOTVERSION配置: ', nvm.get('iot_version'), nvm.get('baud'))

    local resultTable = {
        cmd = "start",
        imei = misc.getImei(),
        iotVersion = IOTVERSION,
        project = PRODUCT_KEY,
        iccId = sim.getIccid(),
        version = VERSION,
        volume = nvm.get("volume"),
        baud = nvm.get("baud"),
        flashSpace = util.getStorageInfo(),
        storageType = storage_type,
        sdcardSpace = sdcard_space,
        hardwareModelId = 3,
        volt = util.getVolt(),
        rebootReason = nvm.get("reboot_reason"),
        relayList = util.getRelayListStr(),
        infoBoardInfo = nvm.get('info_board_info')
    }

    nvm.set("reboot_reason", 0)

    if NETWORKTYPE == 1 then
        local location = util.getLocation()
        log.info('location: ', location)
        resultTable['lng'] = location and location[1] or -1
        resultTable['lat'] = location and location[2] or -1
    else
        resultTable['ipAddress'] = nvm.get('ip_address')
    end

    return resultTable
end

--- 获取心跳信息
function getHelloInfo()
    local resultTable = {
        imei = misc.getImei(),
        cmd = 'hello',
        volume = nvm.get("volume"),
        playStatus = nvm.get("play_status"),
        volt = util.getVolt(),
        storageType = storage_type,
        sdcardSpace = sdcard_space,
        flashSpace = flash_space,
        infoBoardInfo = nvm.get('info_board_info'),
        relayList = util.getRelayListStr(),
        intervalTime = nvm.get('interval_time'),
        decibel = rs485.getDecibel()
    }

    log.info('playStatus: ', resultTable['playStatus'])

    if NETWORKTYPE == 1 then
        resultTable['rssi'] = net.getRssi()
    else
        resultTable['ipAddress'] = nvm.get('ip_address')
    end

    if resultTable['playStatus'] and resultTable['playStatus'] ~= 0 then
        resultTable['playInfo'] = { content = nvm.get('play_content') }
    end

    if util.validateSuportVersion(nvm.get('iot_version_ax')) then
        local red_audio = nvm.get('red_audio')
        local green_audio = nvm.get('green_audio')
        local green_blink_audio = nvm.get('green_blink_audio')
        if red_audio or green_audio or green_blink_audio then
            resultTable['axSignalConfig'] = {
                signalEnable = nvm.get('signal_enable'),
                monitorStatus = nvm.get('monitor_status'),
                redAudioName = red_audio,
                greenAudioName = green_audio,
                greenBlinkAudioName = green_blink_audio
            }
        end
    end

    if util.validateSuportVersion(nvm.get('iot_version_hk')) then
        local hk_config = nvm.get('hx_light_config')
        log.info("hk_config:", hk_config)
        if hk_config then
            resultTable['hkSignalConfig'] = {
                signalEnable = nvm.get('signal_enable'),
                monitorStatus = nvm.get('monitor_status'),
                configList = hk_config
            }
        end
    end

    if util.validateSuportVersion(nvm.get('iot_version_io')) then
        local io_config = nvm.get('io_play_file_name')
        log.info("io_config:", io_config)
        if io_config then
            resultTable['ioSignalConfig'] = {
                signalEnable = nvm.get('signal_enable'),
                monitorStatus = nvm.get('monitor_status'),
                ioPlayFileName = io_config
            }
        end
    end

    return resultTable
end

function reboot()
    rebootStatus = true
end

sys.taskInit(function ()
    sys.timerLoopStart(function()
        if rebootStatus then
            logWrite("软件正常重启")
            sys.restart("软件正常重启")
        end
    end, 5000)
end)
-- By GST @2024/10/25