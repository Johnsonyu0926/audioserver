-- Filename: ch395q_rtmp.lua
-- 配置CH395Q以实现RTMP通信

local spi = require "spi"
local ch395q = require "ch395q"

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
ch395q.connect_rtmp(rtmp_url)

-- 发送RTMP数据
function send_rtmp_data(data)
    ch395q.send_rtmp(data)
end

-- 接收RTMP数据
function receive_rtmp_data()
    return ch395q.receive_rtmp()
end

-- By GST @2024/10/25