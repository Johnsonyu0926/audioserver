-- Filename: ch395q_rtmp.lua
-- 配置CH395Q以实现RTMP通信

local spi = require "spi"
local ch395q = require "ch395q"
require "watchdog"

-- 初始化SPI接口
spi.setup(1, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW, 8, 20 * 1000 * 1000)

-- 初始化CH395Q
ch395q.init(1, 0)

-- 配置网络参数
local ip = "192.168.1.100"
local netmask = "255.255.255.0"
local gateway = "192.168.1.1"
local dns = "8.8.8.8"
local server_ip = "192.168.1.200"

ch395q.set_ip(ip, netmask, gateway, dns)

-- 连接RTMP服务器
local rtmp_url = "rtmp://" .. server_ip .. "/live/stream"

-- 判断网络状态并选择RTMP传输路径
function connect_rtmp()
    local network_status = ch395q.get_network_status()
    if network_status == "LAN" then
        -- 优先使用LAN网络传输RTMP数据
        ch395q.connect_rtmp(rtmp_url)
    elseif network_status == "4G" then
        -- 如果LAN不可用，则使用4G网络传输RTMP数据
        ch395q.connect_rtmp(rtmp_url)
    else
        -- 如果都不可用，尝试使用4G网络传输RTMP数据
        ch395q.connect_rtmp(rtmp_url)
    end
end

-- 发送RTMP数据
function send_rtmp_data(data)
    ch395q.send_rtmp(data)
end

-- 接收RTMP数据
function receive_rtmp_data()
    return ch395q.receive_rtmp()
end

watchdog.init(60000) -- 初始化看门狗，超时时间为60秒

sys.taskInit(function()
    sys.timerLoopStart(function()
        watchdog.feed() -- 喂狗
    end, 60000)

    sys.timerLoopStart(function()
        local network_status = ch395q.get_network_status()
        if network_status == "disconnected" then
            ch395q.reconnect()
        end
    end, 60000)

    sys.timerLoopStart(function()
        local cpu_usage = sys.get_cpu_usage()
        local memory_usage = sys.get_memory_usage()
        local storage_usage = sys.get_storage_usage()
    end, 60000)

    -- 初始化时连接RTMP服务器
    connect_rtmp()
end)

-- By GST @2024/10/25
