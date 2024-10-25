--mqttc.lua
module(...,package.seeall)

require "mqtt"
local mqtt_host = '47.102.100.4'
local mqtt_port = 1883
local mqtt_ssl = false
local client_id = '123'
local username = 'mHecD4m5'
local password = 'c81919e7d3abf31f1e4f56b7575670a067565eae'
local mqtt_autoreconn = true
local mqttClient = nil

-- 处理收到服务器下发数据
sys.subscribe('mqtt_recv', function ()
    sys.taskInit(function ()
        local result, payload = sys.waitUntil("mqtt_recv")
        log.info("mqtt收到消息", payload)
        local data = json.decode(payload)
    end)
end)

-- 处理mqtt连接断开
sys.subscribe('mqtt_disconnect', function ()
    sys.taskInit(function ()
        local result, mqtt_client = sys.waitUntil("mqtt_disconnect")
        if result then
            log.info("mqtt链接断开")
            if not mqtt_autoreconn then
                mqtt_client:connect()
            end
        end
    end)
end)

-- 连接mqtt
connect = function ()
    log.info('开始连接网络')
    local result = sys.waitUntil("IP_READY", 30000)
    if not result then
        log.info("网络连接失败")
        return
    end
    log.info('网络连接成功，开始执行mqtt连接')
    mqttClient = mqtt.create(nil, mqtt_host, mqtt_port, mqtt_ssl)
    mqttClient:auth(client_id, username, password)
    mqttClient:keepalive(30)
    mqttClient:autoreconn(mqtt_autoreconn, 3000)

    mqttClient:on(function(mqtt_client, event, data, payload)
        log.info("mqtt", "event", event, mqtt_client, data, payload)
        if event == "conack" then
            log.info("连接成功，订阅相关主题")
            mqttClient:subscribe("testtopic/x", 0)
        elseif event == "recv" then
            log.info("接收到数据: "..payload)
            sys.publish("mqtt_recv", payload)
        elseif event == "sent" then
            log.info("发送完成，pkgid: "..data)
        elseif event == "disconnect" then
            log.info("服务器断开连接,网络问题或服务器踢了客户端")
            sys.publish('mqtt_disconnect', mqtt_client)
        end
    end)

    mqttClient:connect()
    sys.wait(1000)
    local error = mqttClient:ready()
    if not error then
        log.info("mqtt 连接失败")
    else
        log.info("mqtt 连接成功")
    end
    sys.waitUntil("mqtt_conack")
    while true do
        local ret, topic, data, qos = sys.waitUntil("mqtt_pub", 30000)
        if ret then
            mqttClient:publish(topic, data, qos)
        end
    end
    mqttClient:close()
    mqttClient = nil
end

-- 上报设备信息
local reportDeviceInfo = function ()
    local topic = '/sys/a1mcPUDcUmt/'..mobile.imei()..'/thing/event/property/post'
    local deviceInfo = {
        id = '123456',
        params = {
            mobile_rsrp = mobile.rsrp()
        },
        version = '1.0',
        method = 'thing.event.property.post'
    }
    if mqttClient ~= nil then
        local ready = mqttClient.ready()
        if ready then
            mqttClient:publish(topic, json.encode(deviceInfo), 0)
        end
    end
end

return {
    connect = connect,
    reportDeviceInfo = reportDeviceInfo
}
-- By GST @2024/10/25