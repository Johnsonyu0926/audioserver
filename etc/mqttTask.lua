-- Filename: mqttTask.lua
--- 模块功能：MQTT客户端处理框架
-- @author openLuat
-- @module mqtt.mqttTask
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.28

module(..., package.seeall)

require "mqtt"
require "update"
require "core"
require "mqttInMsg"
require "tcpCore"
require "nvm"
require "sys"

nvm.init("config.lua")

local ready = false
local user_name = nvm.get('user_name')
local port = nvm.get('port')
local password = nvm.get('password')
local server_address = nvm.get('server_address')
local netMode = nvm.get('net_mode')
local retry_connect_network_count = 0

nvm.set('play_status', 0)
nvm.set('download_tag', false)

local hb_count = 1

function isReady()
    return ready
end

local function initNetwork()
    if port == nil then
        if nvm.get('mqtt_env') == 'prod' then
            if NETWORKTYPE == 1 then
                port = 51883
            else
                port = 18832
                user_name = 'intranet'
                password = 'gst@2024_123!'
                nvm.set('user_name', user_name)
                nvm.set('password', password)
            end
        else
            port = 1883
            user_name = 'intranet'
            password = 'Aa123456'
        end
        nvm.set('port', port)
    end
end

sys.taskInit(function()
    sys.wait(3000)
    log.info('进入网络模块: ', NETWORKTYPE)
    initNetwork()
    local reason = rtos.poweron_reason()
    log.info("开机原因: ", reason)
    if NETWORKTYPE == 2 then
        if netMode == 1 then
            local mqttDate = {
                mode = 1,
                intPin = pio.P0_22,
                rstPin = pio.P0_23,
                localAddr = nvm.get('ip_address'),
                localSubnetMas = nvm.get('netmask'),
                localGateway = nvm.get('gateway'),
                powerFunc = function(state) end,
                spi = {spi.SPI_1, 0, 0, 8, 800000}
            }
            while not link.openNetwork(link.CH395, mqttDate) do
                log.info("网络开启失败")
                retry_connect_network_count = retry_connect_network_count + 1
                log.info("网络开启失败，重试: ", retry_connect_network_count)
                if retry_connect_network_count > 10 then
                    sys.restart('网络连接超时，设备重启')
                end
            end
        else
            mqtt_connect = false
            local tcpData = {
                mode = 2,
                clientNum = 4,
                intPin = pio.P0_22,
                rstPin = pio.P0_23,
                localPort = nvm.get('tcp_port'),
                localAddr = nvm.get('ip_address'),
                localSubnetMas = nvm.get('netmask'),
                localGateway = nvm.get('gateway'),
                powerFunc = function(state)
                    if state then
                        local setGpioFnc_Tx = pins.setup(pio.P0_7, 0)
                        pmd.ldoset(15, pmd.LDO_VMMC)
                    else
                        pmd.ldoset(0, pmd.LDO_VMMC)
                        local setGpioFnc_Tx = pins.setup(pio.P0_7, 1)
                    end
                end,
                spi = {spi.SPI_1, 0, 0, 8, 3000000}
            }
            while true do
                log.info('TCP服务端网络开启')
                while not link.openNetwork(link.CH395, tcpData) do
                    retry_connect_network_count = retry_connect_network_count + 1
                    log.info("网络开启失败，重试: ", retry_connect_network_count)
                    if retry_connect_network_count > 10 then
                        sys.restart('网络连接超时，设备重启')
                    end
                end
                log.info("网络参数 ", link.getIp())
                while not socket.isReady() do
                    sys.wait(1000)
                    log.info("socket连接失败")
                end
                local socketServer = socket.tcp(nil, nil, {type = "TCPSERVER"})
                while socketServer:serverSelect() do end
                socketServer:close()
                serverOn = {}
                log.info("会走出来吗")
            end
        end
    else
        netMode = 1
        nvm.set('net_mode', netMode)
    end

    retry_connect_network_count = 0
    if netMode == 1 or NETWORKTYPE == 1 then
        log.info("当前设备imei: ", misc.getImei())
        local retryConnectCnt = 0
        while true do
            log.info("开始准备网络环境，重试次数: ", retryConnectCnt)
            while not socket.isReady() do
                log.error("mqttTask: network connect error!")
                retryConnectCnt = 0
                local tag, d = sys.waitUntil("IP_READY_IND", 30000)
                log.info('IP_READY_IND: ', tag, d)
            end
            if socket.isReady() then
                local subscribe_topic, publish_topic = util.getTopic()
                log.info("mqttTask: network connect success! begin to connect mqtt server!")
                log.info("mqttTask: userName : " .. user_name .. "; password: " .. password .. "; mqttServerAddress: " .. server_address .. "; port: " .. port)
                local mqttClient = mqtt.client(misc.getImei(), nil, user_name, password)
                local connectStatus = mqttClient:connect(server_address, port)
                log.info('MQTT连接结果: ', connectStatus)
                if connectStatus == true then
                    ready = true
                    log.info("订阅的主题: " .. subscribe_topic)
                    log.info("发布的主题: " .. publish_topic)
                    if mqttClient:subscribe(subscribe_topic, 2) == true then
                        log.info("mqttTask: 消息订阅成功")
                        dataInit.initData()
                        sys.wait(5000)
                        log.info("进入mqtt客户端数据处理主模块, 发布主题： " .. publish_topic)
                        local startInfo = json.encode(core.getStartInfo())
                        log.info("开始发送开机信息： " .. startInfo)
                        if mqttClient:publish(publish_topic, startInfo, 2) == true then
                            log.info("开机信息发送成功")
                        end
                        while true do
                            if not mqttInMsg.helloTask(mqttClient) then
                                log.error("mqttTask.mqttInMsgResult task error")
                                break
                            end
                            local mqttInMsgResult = mqttInMsg.proc(mqttClient)
                            log.info("mqttTask.mqttInMsg.proc.result: ", mqttInMsgResult)
                            if not mqttInMsgResult then
                                log.error("mqttTask.mqttInMsg.proc error: ", mqttInMsgResult)
                                break
                            end
                        end
                    else
                        retryConnectCnt = retryConnectCnt + 1
                        log.info("MQTT连接重试次数计算： ", retryConnectCnt)
                    end
                    log.info("MQTT连接重试次数: " .. retryConnectCnt)
                    log.info("开始断开mqtt连接")
                    mqttClient:disconnect()
                    log.info("mqtt连接断开成功")
                    if retryConnectCnt >= 5 then
                        link.shut()
                        retryConnectCnt = 0
                    end
                    if retryConnectCnt >= 20 then
                        sys.restart('网络重试超出次数重启设备')
                    end
                    sys.wait(5000)
                else
                    log.info("进入飞行模式")
                    net.switchFly(true)
                    sys.wait(20000)
                    net.switchFly(false)
                    log.info("退出飞行模式")
                end
            end
        end
    end
end)

local serverOn = {}
local a = true

sys.subscribe("tcpServer", function(para)
    sys.taskInit(function()
        log.info("当前TCP连接数: ", #serverOn)
        if #serverOn >= 3 then
            sys.restart("TCP超出连接上限, 已重启")
            return
        end
        local socketClient
        while not socketClient do
            socketClient = socket.tcp(nil, nil, para)
        end

        serverOn[socketClient.id] = socketClient
        log.info("TCP连接成功: ", socketClient.id)
        while socketClient:serverSelect() do end
        log.info('TCP连接断开: ', socketClient.id)
        socketClient:close()
        serverOn[socketClient.id] = nil
        log.info("当前剩余TCP连接有: ", serverOn)
    end)
end)

if netMode == 2 then
    sys.taskInit(function()
        local cnt = 0
        while not socket.isReady() do
            sys.wait(2000)
        end
        sys.wait(3000)
        while true do
            for i, v in ipairs(serverOn) do
                if serverOn[i] then
                    local data = serverOn[i]:serverRecv()
                    if data ~= '' then
                        cnt = cnt + #data
                        log.info("客户端" .. serverOn[i].id .. "发来数据:", cnt, data:sub(1, 600))
                        print("type: " .. type(data), string.match(data, "cmd"), string.match(data, "cmd") ~= nil)
                        if string.match(data, "cmd") ~= nil then
                            local handler_result = tcpCore.coreRun(data)
                            log.info("TCP Server处理结果: ", handler_result)
                            sys.publish("send_data", handler_result)
                        else
                            local call_result = {
                                resultId = 2,
                                msg = "不支持的操作"
                            }
                            sys.publish("send_data", json.encode(call_result))
                        end
                    end
                end
                sys.wait(100)
            end
            sys.wait(100)
        end
    end)

    sys.taskInit(function()
        while true do
            local res, data = sys.waitUntil("send_data", 30000)
            log.info("回调数据: ", res, data)
            if res == true and data ~= nil then
                if #serverOn > 0 then
                    for i, v in pairs(serverOn) do
                        if serverOn[i] then
                            local status = serverOn[i]:serverSend(data, 20)
                            log.info('TCP发送结果: ', status)
                            if status then
                                coroutine.resume(socketsoftdog, "feed")
                            end
                        end
                    end
                end
            end
        end
    end)

    sys.taskInit(function()
        while true do
            while not socket.isReady() do
                sys.wait(5000)
            end
            sys.wait(60000)
            log.info('上报心跳')
            sys.publish("send_data", json.encode(tcpCore.getDeviceInfo()))
        end
    end)

    socketsoftdog = sys.taskInit(function()
        while true do
            if sys.wait(600000) == nil then
                if socket.isReady() then
                    sys.restart("网络业务逻辑看门狗重启")
                end
            end
        end
    end)
end

local wdi = pins.setup(pio.P0_7, 1)
sys.taskInit(function()
    wdi(1)
    while true do
        wdi(0)
        sys.wait(2000)
        wdi(1)
        sys.wait(120000)
    end
end)
-- By GST @2024/10/25