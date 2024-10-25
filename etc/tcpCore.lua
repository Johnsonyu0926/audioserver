-- Filename: tcpCore.lua
module(..., package.seeall)

local function upgradeCb(r, msg)
    log.info('升级完成回调: ', r, msg)
    sys.publish('upgrade_cb', r)
end

-- 为TCP模式时，数据传入：
function coreRun(data)
    local dataObj = json.decode(data)
    local result = {
        resultId = 3,
        msg = '未处理'
    }
    local cmd = dataObj['cmd']
    local return_tag = true

    if cmd == nil or cmd == '' then
        result.resultId = 3
        result.msg = "操作指令不能为空"
    else
        result['cmd'] = cmd
        if cmd == 'Login' then
            local pwd = dataObj['password']
            local user_name = dataObj['userName']
            if user_name ~= nvm.get("tcp_user") then
                result.resultId = 2
                result.msg = "用户名不正确"
            elseif pwd ~= nvm.get('tcp_password') then
                result.resultId = 2
                result.msg = "登录密码不正确"
            else
                result.resultId = 1
                result.msg = "登录成功"
                local status, deviceInfo = pcall(getDeviceInfo)
                if status then
                    result['data'] = deviceInfo
                else
                    result.msg = result.msg .. ", 获取设备信息失败"
                end
            end
        elseif cmd == 'AudioPlay' then    
            local validateResult = validatePlayParams(dataObj)
            if validateResult ~= true then
                return validateResult
            end
            local play_data = {
                playType = 1,
                timeType = getTimeType(dataObj['playType']),
                fileName = dataObj['audioName'],
                playDuration = dataObj['duration'],
                playCount = dataObj['duration'],
            }
            local tag, msg2 = audioPlay.playCore(play_data)
            result.resultId = tag and 1 or 2
            result.msg = msg2
        elseif cmd == 'TtsPlay' then   
            local validateResult = validatePlayParams(dataObj)
            if validateResult ~= true then
                return validateResult
            end
            local tts_content = '[v10]' .. string.fromHex(dataObj['content'])
            local voice_type = dataObj['voiceType']
            if voice_type == 1 then -- 男声 [m52] [53]
                tts_content = '[m52]' .. tts_content
            end
            local play_data = {
                playType = 2,
                timeType = getTimeType(dataObj['playType']),
                content = tts_content,
                playDuration = dataObj['duration'],
                playCount = dataObj['duration'],
            }
            local speed = dataObj['speed']
            audio.setTTSSpeed(speed and tonumber(speed) or 50)
            local tag, msg2 = audioPlay.playCore(play_data)
            result.resultId = tag and 1 or 2
            result.msg = msg2
        elseif cmd == 'GetDeviceBaseInfo' then
            local status, deviceInfo = pcall(getDeviceInfo)
            if status then
                result.resultId = 1
                result.msg = '查询成功'
                result['data'] = deviceInfo
            else
                result.resultId = 2
                result.msg = "查询失败: " .. deviceInfo
            end
        elseif cmd == 'GetAudioList' then
            local tag, status, list = pcall(util.recurDir, util.getStoragePath())
            if tag then
                result.resultId = status and 1 or 2
                result.msg = status and "查询成功" or "查询失败: " .. list
                result['data'] = list
            else
                result.resultId = 2
                result.msg = "查询失败: " .. status
            end
        elseif cmd == 'FileUpload' then
            local status, msg2 = util.fileUploadHandler(dataObj)
            result.resultId = status and 1 or 2
            result.msg = msg2
        elseif cmd == "RecordPlay" then
            local play_data = {
                playType = 3,
                downloadUrl = dataObj['recordUrl'],
                timeType = getTimeType(dataObj['playType']),
                playDuration = dataObj['duration'],
                playCount = dataObj['duration'],
            }
            local status, msg2 = audioPlay.recordPlay(play_data)
            result.resultId = status and 1 or 2
            result.msg = msg2
        elseif cmd == 'BatchFileUpload' then
            local fileSize = dataObj['fileSize']
            if fileSize then
                local validate_tag, validate_result = pcall(util.validateUploadFileSize, fileSize)
                log.info("校验失败: ", validate_tag, validate_result)
                if validate_tag then
                    if validate_result then
                        local downloadList = dataObj['uploadList']
                        if #downloadList == 0 then
                            result.resultId = 2
                            result.msg = "上传列表为空，请检查是否存入文件"
                        else
                            local uploadFailList = {}
                            for _, value in pairs(downloadList) do
                                local file_name = value['fileName']
                                local download_url = value["downloadUrl"]
                                log.info("fileName: ", file_name)
                                log.info("url: ", download_url)
                                if file_name and download_url then
                                    local upload_path = tcpRunCore.getFilePath(file_name)
                                    if upload_path then
                                        value['uploadPath'] = upload_path
                                        local tag, downloadResult = util.downloadFile(value)
                                        if not tag then
                                            table.insert(uploadFailList, file_name .. downloadResult)
                                        end
                                    end
                                end
                            end
                            if #uploadFailList ~= 0 then
                                result.resultId = 2
                                result.msg = "文件上传失败"
                                result['data'] = uploadFailList
                            else
                                result.resultId = 1
                                result.msg = "批量上传成功"
                            end
                        end
                    else
                        result.resultId = 2
                        result.msg = "设备剩余空间不够，请先删除再上传"
                    end
                else
                    result.resultId = 2
                    result.msg = "文件大小校验失败"
                end
            else
                result.resultId = 2
                result.msg = "缺少上传文件大小"
            end
        elseif cmd == 'AudioStop' then   
            audioPlay.stopAudio()
            result.resultId = 1
            result.msg = "停止播放成功"   
        elseif cmd == 'VolumeSet' then
            local volumeValue = tonumber(dataObj['volume'])
            dataObj['muteType'] = 'unmute'
            if volumeValue and volumeValue >= 0 and volumeValue <= 7 then
                local set_tag, set_msg = pcall(rs485.volumeSet, volumeValue, dataObj['muteType'])              
                if set_tag then
                    nvm.set("volume", volumeValue)
                    result.resultId = 1
                    result.msg = "音量设置成功"
                else
                    result.resultId = 2
                    result.msg = "音量设置失败: " .. set_msg
                end
            else
                result.resultId = 2
                result.msg = "音量值不符合要求"
            end
        elseif cmd == 'RelaySet' then
            local relay_mode = dataObj['model']
            local relay_status = dataObj['status']
            local status, tag = pcall(function()
                nvm.set("relay_mode", relay_mode)
                nvm.set("relay_status", relay_status)
                util.updateRelayStatus(0, relay_mode, relay_status)
            end)
            if status then
                result.resultId = 1
                result.msg = "闪灯配置成功"
            else
                result.resultId = 2
                result.msg = "闪灯配置失败: " .. tag 
            end
        elseif cmd == 'UpdatePwd' then
            local oldPwd = dataObj['oldPassword']
            local newPwd = dataObj['password']
            if oldPwd ~= nvm.get("tcp_password") then
                result.resultId = 2
                result.msg = "登录密码不正确，无法修改"
            elseif not newPwd or #newPwd < 8 then
                result.resultId = 2
                result.msg = "新密码位数不符合要求"
            else
                nvm.set('tcp_password', newPwd)
                result.resultId = 1
                result.msg = "密码重置成功"
            end
        elseif cmd == 'NetworkSet' then
            local ipAddress = dataObj['ipAddress']
            local netmask = dataObj['netMask']
            local gateway = dataObj['gateway']
            if ipAddress then nvm.set("ip_address", ipAddress) end
            if netmask then nvm.set("netmask", netmask) end
            if gateway then nvm.set("gateway", gateway) end
            local serverAddr = dataObj['serverAddress']
            if serverAddr then nvm.set("server_address", serverAddr) end
            local port = dataObj['port']
            if port then nvm.set("port", port) end
            local username = dataObj['userName']
            if username then nvm.set('user_name', username) end
            local password = dataObj['password']
            if password then nvm.set('password', password) end
            local mode = dataObj['netMode']
            local nowMode = nvm.get("net_mode")
            if mode and mode ~= nowMode then
                if mode == 1 or mode == 2 then
                    nvm.set('net_mode', mode)
                    msg = mode == 1 and "网络模式转换为客户端模式，正在重启" or "网络模式转换为服务端模式，正在重启"
                else
                    msg = "网络设置成功"
                end
            else
                msg = "网络设置成功"
            end
            result.resultId = 1
            local status, deviceInfo = pcall(getDeviceInfo)
            if status then
                result['data'] = deviceInfo
            end
            core.reboot()
        elseif cmd == 'Reboot' then
            core.reboot()
            result.resultId = 1
            result.msg = "下发重启指令成功, 设备正在重启"
        elseif cmd == 'Upgrade' then
            local url = dataObj['upgradeUrl']
            if not url then
                result.resultId = 2
                result.msg = "升级文件为空，升级失败"
            else
                update.request(upgradeCb, url)
                local r, d = sys.waitUntil("upgrade_cb", 30000)
                print("upgrade: ", r, d)
                if r then
                    result.resultId = d and 1 or 2
                    result.msg = d and "升级成功,进行重启" or "升级失败: " .. d
                    if d then core.reboot() end
                else
                    result.resultId = 2
                    result.msg = "升级失败: " .. d
                end
            end
        elseif cmd == 'Restore' then
            nvm.restore()
            local status, deviceInfo = pcall(util.getDeviceInfo)
            if status then
                result['data'] = deviceInfo
            end
            core.reboot()
            result.resultId = 1
            result.msg = "恢复出厂设置成功，设备正在重启，请等待重启完成后再进行连接操作"
        elseif cmd == 'MicRecord' then
            if play then
                result.resultId = 2
                result.msg = "当前正在播放中，不能采集录音"
            else
                local duration = tonumber(dataObj['duration']) or 5
                local httpUrl = dataObj['uploadUrl']
                if not httpUrl then
                    result.resultId = 2
                    result.msg = "录音上传地址不能为空"
                elseif duration > 60 then
                    result.resultId = 2
                    result.msg = '录音采集时长不能超过60秒'
                else
                    local record_status = util.recordAndUpload(httpUrl, duration)
                    log.info("reocrd返回: ", record_status, record_result)
                    result.resultId = record_status and 1 or 2
                    result.msg = record_status and "录音采集成功" or "录音采集失败"
                end
            end
        elseif cmd == "PtzOperate" then
            local ptzCmd = dataObj['operateCmd']
            pcall(rs485.ptzOperateRun, ptzCmd)
            return_tag = false
        elseif cmd == "AudioDelete" then
            local audio_name = dataObj['deleteName']
            if not audio_name then
                result.resultId = 2
                result.msg = '缺少存储位置或者要删除的文件名'
            else
                local status, set_tag, set_result = pcall(util.deleteFileCore, audio_name)
                result.resultId = status and (set_tag and 1 or 2) or 2
                result.msg = status and set_result or '删除失败'
            end
        elseif cmd == 'IoSignalSet' then
            local audio_name = dataObj['audioName']
            if audio_name then
                local file_path = util.getFilePath(audio_name)
                if io.exists(file_path) then
                    local io_play_info = { ioPlayFileName = file_path }
                    local monitor_status = dataObj['monitorStatus']
                    if not monitor_status then
                        result.resultId = 2
                        result.msg = '使能开关不能为空'
                    else
                        local gather_time = dataObj['gatherTime']
                        if gather_time and gather_time < 200 then
                            result.resultId = 2
                            result.msg = '信号采集时间不能小于200毫秒'
                        elseif monitor_status == 1 or monitor_status == 0 then
                            if gather_time then nvm.set('io_signal_time', gather_time) end
                            nvm.set('io_play_info', io_play_info)
                            nvm.set('monitor_status', monitor_status)
                            util.openSignalEnable()
                            if dataObj['stopMode'] then nvm.set('stop_mode', dataObj['stopMode']) end
                            if not util.validateSuportVersion(nvm.get('iot_version_io')) then
                                nvm.set('iot_version', 'COMMON_IOSIGNAL')
                                core.reboot()
                                result.resultId = 1
                                result.msg = '配置成功，设备重启'
                            else
                                pcall(ioTriagger.updateIoSet)
                                result.resultId = 1
                                result.msg = '配置成功'
                            end
                        else
                            result.resultId = 2
                            result.msg = '不支持的使能开关状态'
                        end
                    end
                else
                    result.resultId = 2
                    result.msg = '音频文件不存在，请先上传'
                end
            else
                result.resultId = 2
                result.msg = '音频文件名不能为空'
            end
        elseif cmd == 'GetIoSignalConfig' then
            result.resultId = 1
            result.msg = "获取成功"
            local io_play_info = nvm.get('io_play_info')
            local data = {}
            if io_play_info then
                data = {
                    monitorStatus = nvm.get('monitor_status'),
                    audioName = io_play_info['ioPlayFileName'],
                    stopMode = nvm.get('stop_mode'),
                    gatherTime = nvm.get('io_signal_time')
                }
            end
            result['data'] = data
        else
            result.resultId = 9
            result.msg = '不支持的操作'
        end
    end
    if return_tag then
        return json.encode(result)
    end
end

function getDeviceInfo()
    return {
        address = nvm.get("uart_address"),
        imei = misc.getImei(),
        codeVersion = VERSION,
        coreVersion = misc.getVersion(),
        functionVersion = FUNCTIONVERSION,
        ip = nvm.get("ip_address"),
        port = nvm.get("tcp_port"),
        gateway = nvm.get("gateway"),
        userName = nvm.get("tcp_user"),
        password = nvm.get("tcp_password"),
        netmask = nvm.get("netmask"),
        temperature = nil,
        storageType = mountFlash.getSpiMountStatus(),
        volume = nvm.get("volume"),
        relayMode = nvm.get("relay_mode"),
        playStatus = nvm.get("play_status"),
        relayStatus = nvm.get('relay_status'),
        spiFreeSpace = mountFlash.getSpiFreeSpace(),
        flashFreeSpace = rtos.get_fs_free_size(),
        hardwareReleaseTime = HARDRELASETIME,
        hardwareVersion = HARDVERSION
    }
end

-- 播放参数校验
function validatePlayParams(data)
    local result = {}
    if data['cmd'] == 'AudioPlay' then
        local audioName = data['audioName']
        local playType = data['playType']
        local playDuration = data['duration']
        if not audioName then
            result['resultId'] = 4
            result['msg'] = "请求缺少播放的音频文件"
            return json.encode(result)
        end
        if not playType then
            result['resultId'] = 4
            result['msg'] = "请求缺少播放的模式"
            return json.encode(result)
        elseif playType ~= 1 and playType ~= 2 and playType ~= 0 then
            result['resultId'] = 4
            result['msg'] = "不支持的操作模式"
            return json.encode(result)
        end
        if (playType == 2 or playType == 1) and (not playDuration or playDuration <= 0) then
            result['resultId'] = 4
            result['msg'] = "缺少播放时长"
            return json.encode(result)
        end
        return true
    else
        result['resultId'] = 4
        result['msg'] = "不支持的指令"
        return json.encode(result)
    end
end

function getTimeType(playType)
    if playType == 0 then
        return 2
    elseif playType == 1 then
        return 1
    elseif playType == 2 then
        return 0
    end
end

-- By GST @2024/10/25