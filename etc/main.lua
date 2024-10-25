### 文件名：main.lua
#### 原始代码
-- main.lua
-- 必须在这个位置定义PROJECT和VERSION变量
-- PROJECT：ascii string类型，可以随便定义，只要不使用,就行
-- VERSION：ascii string类型，如果使用Luat物联云平台固件升级的功能，必须按照"X.X.X"定义，X表示1位数字；否则可随便定义
PROJECT = "GS_COMMON"
VERSION = "3.1.0"
PRODUCT_KEY = "0Tr1N2kbP5sKUDglAIOUxHdwp4VkLusssscz"

-- 加载日志功能模块，并且设置日志输出等级
require "log"
LOG_LEVEL = log.LOGLEVEL_INFO

require "sys"
require "net"

-- 关闭RNDIS网卡功能
ril.request("AT+RNDISCALL=0,1")

require "misc"
require "config"
require "nvm"
require "update"
require "util"

nvm.init('config.lua')

IOTVERSION = nvm.get('iot_version')
NETMODE = nvm.get('net_mode') -- 2：服务端模式（tcp）1：客户端模式（mqtt）
NETWORKTYPE = 1 -- 0：表示初始状态，1：表示4G；2：表示LAN; 用这个参数来控制

pcall(function()
    if sys.SCRIPT_LIB_VER == '2.4.4' then
        NETWORKTYPE = 1
        NETMODE = 1
        net.startQueryAll(8 * 1000, 600 * 1000)
        update.request()
        log.info('NETWORKTYPE VERSION:', NETWORKTYPE)
    else
        NETWORKTYPE = 2
        log.info('NETWORKTYPE VERSION2:', NETWORKTYPE)
    end

    if NETWORKTYPE == 2 then
        require "socketCh395"
    end

    if util.validateSuportVersion(nvm.get('iot_version_io')) then
        log.info('加载IO信号机模块')
        require "ioTriagger"
    end
    if util.validateSuportVersion(nvm.get('iot_version_ax')) then
        log.info('加载通用信号机模块')
        require "AxTrafficLights"
    end
    if util.validateSuportVersion(nvm.get('iot_version_hk')) then
        log.info('加载海康信号机模块')
        require "HkTrafficLights"
    end
    if util.validateSuportVersion(nvm.get('iot_version_volumeAda')) then
        log.info('加载噪声检测模块')
        sys.taskInit(rs485.initDecibel)
    end
end)

require "rs485"
require "mountFlash"
require "mqttTask"
require "restoreSetting"
require "dataInit"

sys.init(0, 0)
sys.run()
-- By GST @2024/10/25

#### 替换后的代码
-- main.lua
-- 必须在这个位置定义PROJECT和VERSION变量
-- PROJECT：ascii string类型，可以随便定义，只要不使用,就行
-- VERSION：ascii string类型，如果使用Luat物联云平台固件升级的功能，必须按照"X.X.X"定义，X表示1位数字；否则可随便定义
PROJECT = "GS_COMMON"
VERSION = "3.1.0"
PRODUCT_KEY = "0Tr1N2kbP5sKUDglAIOUxHdwp4VkLusssscz"

require "sys"
require "net"
require "watchdog"

-- 关闭RNDIS网卡功能
ril.request("AT+RNDISCALL=0,1")

require "misc"
require "config"
require "nvm"
require "update"
require "util"

nvm.init('config.lua')

IOTVERSION = nvm.get('iot_version')
NETMODE = nvm.get('net_mode') -- 2：服务端模式（tcp）1：客户端模式（mqtt）
NETWORKTYPE = 1 -- 0：表示初始状态，1：表示4G；2：表示LAN; 用这个参数来控制

pcall(function()
    if sys.SCRIPT_LIB_VER == '2.4.4' then
        NETWORKTYPE = 1
        NETMODE = 1
        net.startQueryAll(8 * 1000, 600 * 1000)
        update.request()
    else
        NETWORKTYPE = 2
    end

    if NETWORKTYPE == 2 then
        require "socketCh395"
    end

    if util.validateSuportVersion(nvm.get('iot_version_io')) then
        require "ioTriagger"
    end
    if util.validateSuportVersion(nvm.get('iot_version_ax')) then
        require "AxTrafficLights"
    end
    if util.validateSuportVersion(nvm.get('iot_version_hk')) then
        require "HkTrafficLights"
    end
    if util.validateSuportVersion(nvm.get('iot_version_volumeAda')) then
        sys.taskInit(rs485.initDecibel)
    end
end)

require "rs485"
require "mountFlash"
require "mqttTask"
require "restoreSetting"
require "dataInit"

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
end)

sys.init(0, 0)
sys.run()
-- By GST @2024/10/25
