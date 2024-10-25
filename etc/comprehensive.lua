-- Filename: comprehensive.lua
-- 综合解决方案

local wdt = require "wdt"
local sys = require "sys"
local net = require "net"

-- 初始化硬件看门狗，设置超时时间为10秒
wdt.init(10)

-- 启动硬件看门狗
function start_hardware_watchdog()
    sys.timerLoopStart(function()
        wdt.feed()
    end, 5000) -- 每5秒喂狗一次
end

start_hardware_watchdog()

-- 启动软件看门狗
function start_software_watchdog()
    sys.timerLoopStart(function()
        local connected = net.isReady()
        if not connected then
            log.info("网络连接断开，触发硬件看门狗重启...")
            wdt.feed() -- 触发硬件看门狗重启
        end
    end, 10000) -- 每10秒检查一次网络连接状态
end

start_software_watchdog()

-- 启动内部定时器
function start_internal_timer()
    sys.timerLoopStart(function()
        -- 定时器任务
        log.info("内部定时器任务执行")
    end, 5000) -- 每5秒执行一次
end

-- 优化定时器优先级
sys.taskInit(function()
    while true do
        start_internal_timer()
        sys.wait(10000) -- 每10秒重启一次定时器，避免优先级问题
    end
end)

-- By GST @2024/10/25