-- Filename: mqttInMsg.lua
--- 模块功能：MQTT客户端数据接收处理
-- @author openLuat
-- @module mqtt.mqttInMsg
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.28

module(..., package.seeall)

require "misc"
require "config"
require "nvm"
require "sys"
require "core"
require "util"

nvm.init("config.lua")

local interval_time = nvm.get('interval_time')
local msgQueue = {}
local mqtt_conent_status = false

local hb_count = 1

local subscribe_topic, publish_topic = util.getTopic()

function proc(mqttClient)
    local result, data
    mqtt_conent_status = true
    while true do
        log.info("进入客户端接收数据处理模块")
        result, data = mqttClient:receive(10000, "APP_SOCKET_SEND_DATA")
        log.info("mqttClient接收到的消息结果: " .. tostring(result) .. " " .. tostring(data))
        if result == true then
            log.info("收到了服务器下发的消息: " .. data.payload or "nil")
            local rst = data.payload
            local tjsondata, r, errinfo = json.decode(rst)
            if r == true and type(tjsondata) == "table" then
                rstTable = core.instructHandler(tjsondata)
                log.info("业务功能处理结果回调: " .. json.encode(rstTable))
                if mqttClient:publish(publish_topic, json.encode(rstTable), 2) == true then
                    log.info("业务功能处理结果发送成功")
                else
                    log.info("业务功能处理结果发送失败")
                end
            else
                local rstTable = {}
                rstTable['resultId'] = 10
                rstTable['result'] = "入参格式不正确"
                log.info("服务器下发消息处理失败: ", json.encode(rstTable))
                if mqttClient:publish(publish_topic, json.encode(rstTable), 2) == true then
                    log.info("处理失败消息发送成功")
                else
                    log.info("处理失败消息发送失败")
                end
            end
        else
            break
        end
    end
    return result or data == "timeout" or data == "APP_SOCKET_SEND_DATA"
end

function helloTask(mqttClient)
    if #msgQueue > 0 then
        log.info('心跳消息发送模块执行方法: ', #msgQueue)
        local outMsg = table.remove(msgQueue, 1)
        log.info('发送消息列表: ', #msgQueue)
        log.info("开始发送心跳信息: " .. outMsg)
        local result = mqttClient:publish(publish_topic, outMsg, 2)
        log.info('心跳发送结果: ', result)
        if result then
            coroutine.resume(socketsoftdog, "feed")
        end
        sys.publish("APP_SOCKET_SEND_DATA")
        msgQueue = {}
        return result
    end
    return true
end

if NETMODE == 1 or NETWORKTYPE == 1 then
    sys.taskInit(function()
        local retryNum = 1
        while true do
            if mqtt_conent_status == false then
                sys.wait(1000)
                retryNum = retryNum + 1
            else
                log.info("心跳消息发送模块TASK")
                helloTime = 1
                local helloInfo = json.encode(core.getHelloInfo())
                table.insert(msgQueue, helloInfo)
                sys.wait(interval_time * 1000)
            end
        end
    end)

    socketsoftdog = sys.taskInit(function()
        while true do
            if sys.wait(600000) == nil then
                local download_tag = nvm.get('download_tag')
                if download_tag ~= true then
                    log.info("网络业务逻辑看门狗重启")
                    sys.restart("网络业务逻辑看门狗重启")
                else
                    log.info("当前下载中，网络狗不进行重启")
                end
            end
        end
    end)
end
-- By GST @2024/10/25