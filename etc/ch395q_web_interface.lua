-- Filename: ch395q_web_interface.lua
-- 配置CH395Q以实现网页管理界面

local ch395q = require "ch395q"

-- 初始化CH395Q
ch395q.init(1, 0)

-- 配置网络参数
local ip = "192.168.1.100"
local netmask = "255.255.255.0"
local gateway = "192.168.1.1"
local dns = "8.8.8.8"

ch395q.set_ip(ip, netmask, gateway, dns)

-- 启动HTTPS服务器
ch395q.start_https_server(443)

-- 处理HTTPS请求
function handle_https_request(request)
    local response = ""

    if request.path == "/network" then
        response = [[
            <html>
            <body>
                <h1>Network Configuration</h1>
                <form action="/network" method="post">
                    IP: <input type="text" name="ip" value="]] .. ip .. [[" /><br />
                    Netmask: <input type="text" name="netmask" value="]] .. netmask .. [[" /><br />
                    Gateway: <input type="text" name="gateway" value="]] .. gateway .. [[" /><br />
                    DNS: <input type="text" name="dns" value="]] .. dns .. [[" /><br />
                    <input type="submit" value="Save" />
                </form>
            </body>
            </html>
        ]]
    elseif request.method == "POST" and request.path == "/network" then
        ip = request.body.ip
        netmask = request.body.netmask
        gateway = request.body.gateway
        dns = request.body.dns
        ch395q.set_ip(ip, netmask, gateway, dns)
        response = "Network configuration updated"
    elseif request.path == "/audio" then
        response = [[
            <html>
            <body>
                <h1>Audio Management</h1>
                <form action="/audio" method="post">
                    Volume: <input type="range" name="volume" min="0" max="100" value="50" /><br />
                    <input type="submit" value="Set Volume" />
                </form>
            </body>
            </html>
        ]]
    elseif request.method == "POST" and request.path == "/audio" then
        local volume = request.body.volume
        -- 设置音量
        ch395q.set_volume(volume)
        response = "Volume set to " .. volume
    end

    return response
end

ch395q.on_https_request(handle_https_request)

-- By GST @2024/10/25