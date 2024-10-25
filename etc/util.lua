-- Filename: util.lua
module(...,package.seeall)

require "lbsLoc"
require "http"
require "pins"
require "nvm"
require "core"

nvm.init("config.lua")

local function logWrite(info)
    log.debug("core日志输出: " .. info)
end

local relay_list = nvm.get('relay_list')

-- 创建flash路径
local mk_result = rtos.make_dir(nvm.get("mkdir"))
if not mk_result then
    nvm.set("flash_path", "")
end

-- 存储空间
local is_tf_card, sd_card_space, flash_space = 0, 0, 0

-- 继电器Gpi
local setGpio24Fnc = pins.setup(pio.P0_24,0)  --24V 
local setGpio25Fnc = pins.setup(pio.P0_25,0)  --5V
local setGpio26Fnc = pins.setup(pio.P0_26,0) --12V

local lng_val, lat_val = 0, 0
local lbs_lng_val, lbs_lat_val = 0, 0

-- 获取地理信息
local function getLocCb(result, lat, lng)
    if result == 0 then
        lbs_lng_val = lng
        lbs_lat_val = lat
    end
end

function getLocation()
    if NETWORKTYPE == 1 then
        lbsLoc.request(getLocCb, nil, 20000)
    end
    if lng_val == 0 and lat_val == 0 then
        lng_val = lbs_lng_val
        lat_val = lbs_lat_val
        local val = {}
        table.insert(val, lng_val)
        table.insert(val, lat_val)
        return val
    end
end

-- 获取adc测量数据和电压值
function getVolt()
    local adc_value, volt_value = adc.read(nvm.get("adc_id"))
    return volt_value
end

-- 获取GPIO状态
local v5, v12, v24 = nvm.get('v5_relay_status'), nvm.get('v12_relay_status'), nvm.get('v24_relay_status')
function getRelay()
    return nvm.get('relay_status')
end

-- 反转
function getSetRelayStatus(status)
    if status == 1 or status == '1' then
        return 0 
    else
        return 1
    end
end

function getRelayStatus(status)
    if status == 0 or status == '0' then
        return 1
    end
    if status == 1 or status == '1' then
        return 0
    end
end

-- gpio口设置
function setGpio(port_list)
    local tag = true
    local result = ""
    if type(port_list) == "table" then
        for key, port_info in pairs(port_list) do
            if port_info["port"] == "30" or port_info["port"] == 30 then
                if port_info["val"] == 0 or port_info["val"] == 1 then
                    v12 = setGpio26Fnc(getRelayStatus(port_info["val"]))
                else
                    result = result .. "12v电平值输入不符合要求; "
                    break
                end
            elseif port_info["port"] == "31" or port_info["port"] == 31 then
                if port_info["val"] == 0 or port_info["val"] == 1 then
                    v24 = setGpio24Fnc(getRelayStatus(port_info["val"]))
                else
                    result = result .. "24v电平值输入不符合要求; "
                    break
                end
            elseif port_info["port"] == "29" or port_info["port"] == 29 then
                if port_info["val"] == 0 or port_info["val"] == 1 then
                    v5 = setGpio25Fnc(getRelayStatus(port_info["val"]))
                else
                    result = result .. "5v电平值输入不符合要求; "
                    break
                end
            else
                result = result .. "不支持的端口" .. port_info["port"] .. ";"
            end
        end
    else
        result = "入參有問題"
    end
    if result ~= "" then
        tag = false
    else
        result = "设置成功"
    end
    return tag, result, v5, v12, v24
end

-- 文件操作
local download_process = false
local function downSndCb(result, prompt, head, body)
    log.info('download result: ', result, prompt)
    if result == true then
        if tonumber(prompt) ~= 200 then
            sys.publish("download_msg", prompt)
        else
            sys.publish("download_msg", result)
        end
    else
        sys.publish("download_msg", prompt)
    end
end

function downloadFile(data)
    local result = "上传成功"
    local upload_path = data['uploadPath']
    local download_url = data["downloadUrl"]
    if upload_path ~= "" then
        if io.exists(upload_path) then
            log.info("file is exisit")
            os.remove(upload_path)
        end
        local download_tag, download_msg = downloadCore(download_url, upload_path)
        log.info("SPI FLASH剩余存储空间: ", mountFlash.getSpiFreeSpace())
        return download_tag, download_msg
    else
        result = "设备存储路径不存在"
        return false, result
    end
end

function downloadCore(download_url, upload_path)
    local result = nil
    local tag = false
    log.info('开始下载:', NETWORKTYPE, download_url, upload_path)
    if NETWORKTYPE == 1 then
        http.request("GET", download_url, nil, nil, nil, 10000, downSndCb, upload_path, {rcvBufferSize=100*1024})
    else
        http.request("GET", download_url, nil, nil, nil, 10000, downSndCb, upload_path)
    end
    local r, d = sys.waitUntil("download_msg", 120000)
    download_process = false
    log.info("download over: ", r, d)
    tag = r
    if r == true and d == true then
        result = "上传成功"
    else
        tag = false
        result = d
        log.info('下载回调：', d)
    end
    return tag, result
end

function deleteFileCore(file_name)
    if file_name == nil or file_name == "" then
        return false, "请求入参中文件名为空"
    end
    local file_path = getFilePath(file_name)
    log.info('删除文件路径: ', file_path)
    if io.exists(file_path) then
        os.remove(file_path)
    end
    return true, "删除成功"
end

function syncFileCore(data)
    local tag, result = true, "同步成功"
    local syncList = data['fileList']
    local callbackFileList = {}
    if syncList ~= nil and type(syncList) == "table" then
        for key, file_info in pairs(syncList) do
            local file_name = file_info['name']
            local file_record_id = file_info['id']
            log.info('handle: ', file_name, file_record_id)
            if file_record_id == nil or file_name == nil or file_name == "" then
                return false, "有文件缺少同步必要信息, 同步失败"
            end
            local file_path = getFilePath(file_name)
            if file_path == nil or file_path == "" then
                return false, "获取文件路径失败，同步失败"
            end
            if io.exists(file_path) then
                callbackFileList[tostring(file_record_id)] = true
            else
                callbackFileList[tostring(file_record_id)] = false
            end
            log.info('table: ', json.encode(callbackFileList))
        end
        return true, "同步成功", callbackFileList
    else
        return false, "同步的文件列表格式不正确，同步失败"
    end
end

function getFilePath(file_name)
    is_tf_card = mountFlash.getSpiMountStatus()
    local flash_path = nvm.get("flash_path")
    local sd_card_path = nvm.get("sd_card_path")
    local file_path = sd_card_path .. file_name
    if string.find(file_name, sd_card_path) then
        return file_name
    end
    return file_path
end

local function split(str, reps)
    local resultStrList = {}
    string.gsub(str, '[^'..reps..']+', function (w)
        table.insert(resultStrList, w)
    end)
    return resultStrList
end

function getFileFormmat(file_name)
    local tab = split(file_name, ".")
    return tab[#tab]
end

function getStorageInfo()
    is_tf_card = mountFlash.getSpiMountStatus()
    if is_tf_card == 1 then
        sd_card_space = mountFlash.getSpiFreeSpace()
    end
    flash_space = mountFlash.getSpiFreeSpace()
    return is_tf_card, sd_card_space, flash_space
end

function volumeSet(data)
    local volume = data["volume"]
    local tag, result = true, "调节音量成功"
    if volume == nil or volume == "" then
        result = "调节音量失败: 请求缺少音量值"
        return tag, result
    end
    local set_tag, set_msg = pcall(rs485.volumeSet, volume, data['muteType'])
    if set_tag == true then
        nvm.set("volume", volume)
        tag = true
        result = "音量设置成功"
    else
        tag = false
        result = "音量设置失败: " .. set_msg
    end
    return tag, result
end

function testMqttServiceConfigSet(data)
    local server_address =  data['serverAddress']
    local port =  data['port']
    local username =  data['username']
    local password =  data['password']
    local sub_topic =  data['subTopic']
    local pub_topic =  data['pubTopic']
    if server_address ~= nil and server_address ~= '' then
        nvm.set('server_address', server_address)
    end
    if port ~= nil then
        nvm.set('port', port)
    end
    if username ~= nil and username ~= '' then
        nvm.set('user_name', username)
    end
    if password ~= nil and password ~= '' then
        nvm.set('password', password)
    end
    if sub_topic ~= nil and sub_topic ~= '' then
        nvm.set('test_subscribe_topic', sub_topic .. '%s/%s')
    end
    if pub_topic ~= nil and pub_topic ~= '' then
        nvm.set('test_publish_topic', pub_topic .. '%s/%s')
    end
end

local function upgradeCb(r, msg)
    log.info('升级完成回调: ', r, msg)
    sys.publish('upgrade_cb', r)
end

-- 噪声返回解析
function noiseCallBackHandler(data)

end

function getTopic()
    local env = nvm.get("mqtt_env")
    local imei = misc.getImei()
    log.info('获取TOPIC, 当前环境: ', env)
    if env == 'prod' then
        local subscribe_topic = nvm.get("subscribe_topic")
        local publish_topic = nvm.get("publish_topic")
        if NETWORKTYPE == 2 then
            subscribe_topic = nvm.get("iot_subscribe_topic")
            publish_topic = nvm.get("iot_publish_topic")
        end
        if string.sub(subscribe_topic, 1, 6) == 'TaDiao' or string.sub(subscribe_topic, 1, 12) == 'IOT/intranet' then
            log.info('topic生成条件: ', imei)
            log.info('topic： ', string.format(subscribe_topic, imei), string.format(publish_topic, imei))
            return string.format(subscribe_topic, imei), string.format(publish_topic, imei)
        else
            return string.format(subscribe_topic, misc.getImei()), string.format(publish_topic, misc.getImei())
        end
    else
        local testsubscribe_topic = nvm.get("test_subscribe_topic")
        local testpublish_topic = nvm.get("test_publish_topic")
        return string.format(testsubscribe_topic, env, imei), string.format(testpublish_topic, env, imei)
    end
end

-- 判断红绿灯播报音频入参以及设置
function trafficConfigSet(data)
    local greenAudioName = data['greenAudioName']
    local redAudioName =  data['redAudioName']
    local greenBlinkAudioName = data['greenBlinkAudioName']
    local sd_card_path = nvm.get("sd_card_path")
    if greenAudioName == nil and redAudioName == nil and green_blink_audio == nil then -- 表示不需要配置文件
        return true, '配置成功'
    end
    local errorMsg = ''
    if greenAudioName ~= nil and greenAudioName ~= '' then
        if io.exists(sd_card_path .. greenAudioName) ~= true then
            errorMsg =  errorMsg .. '绿灯提示音频不存在,'
        end
        nvm.set('green_audio', greenAudioName)
    else
        nvm.set('green_audio', '')
    end
    if redAudioName ~= nil and redAudioName ~= '' then
        if io.exists(sd_card_path .. redAudioName) ~= true then
            errorMsg = errorMsg .. '红灯预警音频不存在,'
        end
        nvm.set('red_audio', redAudioName)
    else
        nvm.set('red_audio', '')
    end
    if greenBlinkAudioName ~= nil and greenBlinkAudioName ~= '' then
        if io.exists(sd_card_path .. greenBlinkAudioName) ~= true then
            errorMsg = errorMsg .. '绿灯闪烁提示音频不存在,'
        end
        nvm.set('green_blink_audio', greenBlinkAudioName)
    else
        nvm.set('green_blink_audio', '')
    end
    if data['playStatus'] ~= nil then
        nvm.set('traffic_play_status', data['playStatus'])
    end
    if data['priority'] ~= nil then
        nvm.set('traffic_priority', data['priority'])
    end
    if errorMsg == '' then
        return true, '配置成功'
    else
        return false, "配置成功, 但是文件校验失败: " .. errorMsg
    end
end

function hxTrafficConfigSet(data)
    nvm.set('hx_light_config', data)
    return true, '配置成功'
end

-- 十进制转换为二进制
-- num：十进制数字，
-- digit：转换后的二进制位数，如果digit小于转换后的位数，则直接返回，否则按照digit补齐
function hex2bin(num, digit)
    local dec = tonumber(num, 16)
    local t = {}
    for i=digit - 1,0,-1 do
        t[#t+1] = math.floor(dec / 2^i)
        dec = dec % 2^i
    end
    return table.concat(t)
end

-- 判断是否包含某版本功能
function validateSuportVersion(iotVersion)
    local versionTab = split(IOTVERSION, "_")
    for _,value in ipairs(versionTab) do
        if value == iotVersion then
            return true
        end
    end
    return false
end

-- 初始化打开信号使能开关
function openSignalEnable()
    local signabeEnable = nvm.get('signal_enable')
    if signabeEnable ~= 0 and  signabeEnable ~= 1 then
        nvm.set('signal_enable', 1)
    end
end

-- 不开放功能，通过485进行mqtt服务配置
function RS485ServiceSet(dataStr)
    local dataList = split(dataStr, " ")
    for key,valu in pairs(dataList) do
        log.info('key: ', key)
        log.info('value: ', dataList[key])
    end
    if #dataList == 8 then
        if dataList[8] ~= 'ZZKK' then
            return false
        end
        local serverInfo = {
            serverAddress = dataList[2],
            port = dataList[3],
            username = dataList[4],
            password = dataList[5],
            subTopic = dataList[6],
            pubTopic = dataList[7]
        }
        if nvm.get('mqtt_env') == 'prod' then
            mqttServiceConfigSet(serverInfo)
        else
            testMqttServiceConfigSet(serverInfo)
        end
    elseif #dataList == 2 then
        nvm.set('mqtt_env', dataList[2])
    else
        return false
    end
    sys.restart("mqtt set and reboot")
end

function getRandomStr(n)
    local t = {
        "0","1","2","3","4","5","6","7","8","9",
        "a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z",
        "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
    }    
    local s = ""
    math.randomseed(os.time())
    for i =1, n do
        s = s .. t[math.random(1, #t)]        
    end;
    return s
end

local function httpCbV2(result, prompt, head, body) --下载回调
    log.info('Http requset result: ', result, prompt, head, body)
    if result == true then
        if  tonumber(prompt) ~= 200 then
            sys.publish("request_msg", prompt)
        else
            sys.publish("request_msg", result)
        end
    else
        sys.publish("request_msg", prompt)
    end
 end    

local randomStr = getRandomStr(10)
local start_count = 1

function postRequest(url)
    if url ~= nil and url ~= '' then
        local data = {
            type = 'IO_1',
            id = randomStr .. start_count,
            device_id = misc.getImei()
        }
        local params = {
            requestData = data
        }
        log.info('data: ', params, json.encode(params))
        local head = {
            ["Content-Type"] = "application/json",
            ["Connection"] = "keep-alive"
        }
        http.request('POST', url, nil, head, json.encode(params), 60000, httpCbV2)
        local r, d = sys.waitUntil("request_msg", 600000)
        log.info("请求完成: ", r, d)
        start_count = start_count + 1
        if start_count > 100000 then
            randomStr = getRandomStr(10)
            start_count = 1
        end
        return r == true and d == true
    end
end

-- 继电器开关
function operateRelay(operate) --入参： 0-断；1-通
    print("当前传入需要设置的继电器状态: ", operate)
    relay_mode = nvm.get("relay_mode")
    local setStatus = util.getRelayStatus(operate) -- 0：通；1-断
    if relay_mode == 2 or relay_mode == "2" then
        if operate == 1 or operate == "1" then -- 当前需要设置为通的状态, 则判断relay_status是否为打开状态，打开状态才去改变，关闭状态则不做操作
            local relay_status = nvm.get("relay_status")
            log.info("获取继电器控制状态： ", relay_status)
            if relay_status == 1 or relay_status == "1" then
                log.info("设置继电器为：", setStatus)
                v5 = setGpio25Fnc(setStatus)
                v12 = setGpio26Fnc(setStatus)
                v24 = setGpio24Fnc(setStatus)
            end
        else
            log.info("设置继电器为: ", setStatus)
            v5 = setGpio25Fnc(setStatus)
            v12 = setGpio26Fnc(setStatus)
            v24 = setGpio24Fnc(setStatus)
        end
    end
end

-- 校验下载文件大小
function validateUploadFileSize(fileSize)
    if fileSize == nil or fileSize == 0 then
        return true
    end
    local mountStatus = mountFlash.getSpiMountStatus()
    local freeSpace = 0
    if mountStatus == 1 then
        freeSpace = mountFlash.getSpiFreeSpace()
    else
        freeSpace = rtos.get_fs_free_size()
    end
    if freeSpace == 0 then
        return false
    else
        log.info("space: ", freeSpace, fileSize)
        if freeSpace < fileSize then
            log.info("剩余空间不足")
            return false
        else
            return true
        end
    end
end

function fileUploadHandler(data)
    local validate_tag, validate_result = pcall(util.validateUploadFileSize, data['fileSize'])
    log.info("校验结果: ", validate_tag, validate_result)
    if validate_tag == true and validate_result == true then
        local file_name = data['fileName']
        local download_url = data["downloadUrl"]
        if file_name == nil or file_name == '' or download_url == nil or download_url == '' then
            return false, "缺少文件名或者路径"
        else
            local upload_path = getFilePath(file_name)
            if upload_path == nil or upload_path == '' then
                return false, "获取存储路径失败"
            else
                data['uploadPath'] = upload_path
                local startTime = os.time()
                nvm.set('download_tag', true)
                tag, result = downloadFile(data)
                log.info("download result: ", tag, result, startTime, os.time())
                nvm.set('download_tag', false)
                if tag ~= true then
                    if io.exists(upload_path) then
                        pcall(deleteFileCore, file_name)
                    end
                end
                return tag, result
            end
        end
    else
        return false, '存储空间不够'
    end
end

function updateRelayStatus(id, relay_mode, statusp)
    local play_status = nvm.get('play_status')
    if relay_mode == 2 or relay_mode == "2" then -- 随播放亮灭
        statusp = play_status == 0 and 0 or 1
        print("播放模式, mode: " .. relay_mode .. ", 设置值status: " .. statusp) -- 0:通，1：断
    elseif relay_mode == 1 or relay_mode == "1" then -- 手动控制
        print("自定义模式, mode: " .. relay_mode .. ", status: " .. statusp)
    end
    local status = getRelayStatus(statusp)
    if id == 1 then
        print("端口1: ", status)
        v5 = setGpio25Fnc(status)
    elseif id == 2 then
        print("端口2: ", status)
        v12 = setGpio26Fnc(status)
    elseif id == 3 then
        print("端口3: ", status)
        v24 = setGpio24Fnc(status)
    else
        print("全端口: ", status)
        v5 = setGpio25Fnc(status)
        v12 = setGpio26Fnc(status)
        v24 = setGpio24Fnc(status)
    end
end

function batchUpdateRelay(port_list)
    log.info('relay_list: ', json.encode(port_list))
    local relay_list = {}
    for key, val in ipairs(port_list) do
        local status = val['val'] == nil and val['relayStatus'] or val['val']
        local relay_mode = val['relayMode'] == nil and 1 or val['relayMode']
        local id = val['id']
        local data = {
            id = id,
            relayMode = relay_mode,
            relayStatus = status
        }
        table.insert(relay_list, data)
        updateRelayStatus(id, relay_mode, status)
        log.info('操作后relayList: ', json.encode(relay_list))
    end
    return relay_list
end

-- 播放模式更新继电器
function updateRelayWithPlay(status)
    if NETMODE == 1 or NETWORKTYPE == 1 then -- mqtt
        local relay_list = nvm.get('relay_list')
        log.info('当前继电器配置: ', json.encode(relay_list))
        local tmpList = {}
        if relay_list == nil or #relay_list == 0 then
            return
        end
        for key, val in ipairs(relay_list) do
            local relay_mode = val['relayMode']
            local id = val['id']
            if relay_mode == 2 or relay_mode == '2' then
                updateRelayStatus(id, relay_mode, status)
            else
                status = val['val'] == nil and val['relayStatus'] or val['val']
                updateRelayStatus(id, relay_mode, status)
            end
            local data = {
                id = id,
                relayMode = relay_mode,
                relayStatus = status
            }
            table.insert(tmpList, data)
        end
        log.info('继电器操作后配置列表： ', json.encode(tmpList))
        nvm.set('relay_list', tmpList)
        relay_list = tmpList
    end
end
-- By GST @2024/10/25