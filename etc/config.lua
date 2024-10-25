-- Filename: config.lua
module(..., package.seeall)

volume = 4
playFileName = "0.mp3"
device_type = 0
adc_id = 2
play_status = 0 -- 播放状态0:未播放；1：音频播放；2：文字播报；3：录音喊话；4：定时任务播放；5：IO触发播放；6：AiBox出发播放；7：主从播放
play_content = '' -- 当前播放内容
sd_card_path = '/user_dir/' -- sd卡存储根目录
mkdir = '/flash'
flash_path = '/flash/' -- flash存储根目录
last_download_url = "" -- 录音喊话最后的下载地址

info_board_info = nil -- 存储显示内容和开关屏状态{"content"： "", "screenStatus": 3}

mqtt_env = 'prod'

net_mode = 2 -- 2：服务端模式（tcp）1：客户端模式（mqtt）

port = nil
user_name = "TaDiao"
password = "kN8!VY5X.WtaE8"
server_address = "iot.giantsound.cn"

-- 4G测试环境：test；本地环境:local；线上环境：prod
subscribe_topic = "TaDiao/server/request/prod/%s"
publish_topic = "TaDiao/device/report/prod/%s"

-- 测试环境：test；本地环境:local；线上环境：prod
test_publish_topic = "IOT/intranet/server/report/%s/%s"
test_subscribe_topic = "IOT/intranet/client/request/%s/%s"

-- LAN 相关信息
ip_address = "192.168.3.100"
gateway = "192.168.3.1"
netmask = "255.255.255.0"
tcp_port = 34508
tcp_user="admin"
tcp_password="Aa123456"

-- 网口
iot_publish_topic = "IOT/intranet/server/report/prod/%s"
iot_subscribe_topic = "IOT/intranet/client/request/prod/%s"

relay_mode = 1 -- 闪灯控制模式：1-手动控制暗灭；2-随播放状态暗灭
relay_status = 0 -- 打开关闭状态：0-关闭；1-打开
relay_list = nil -- mqtt分端口继电器状态

reboot_reason = 0 -- 0： 表示非监测重启；1：远程重启；2-网络重启；3:超时收到mqtt消息重启;4:网络狗重启

flash_format_tag = true

-- io_play_info结构体
io_play_info = nil

stop_mode = 2
io_model_type = 1
user_dir_path = '/user_dir'
io_request_url = ''
io_interval_time = 60
io_signal_time = 1000 -- IO信号采集间隔时间，单位毫秒

audio_level = 9999

io_priority = 4 -- IO触发播放优先级
io_play_status = 5 --IO触发播放playStatus值

slave_priority = 4
slave_play_status = 7 --从设备播放playStatus值

traffic_priority = 4
traffic_play_status = 8

download_tag = false
interval_time = 60 -- 心跳间隔，秒

monitor_status = 0 -- 配置的开关
signal_enable = -1 -- 信号机使能开关-全局控制

rs485_recevier_data = ''

-- 测试版本机制
start_date = ''
expire_period = 30
is_expire = true

-- 澳星信号机配置
green_audio = ""
red_audio = ""
green_blink_audio = ""

-- 海康信号机配置
hx_light_config = ''

-- 功能配置标记
iot_version = 'COMMON'
baud = 9600

-- 音量自适应配置
volume_adaptation_status = 0
volume_adaptation_schema = nil

-- iotversion版本枚举
iot_version_common = 'COMMON'
iot_version_ax = 'AXSIGNAL'
iot_version_hk = 'HKSIGNAL'
iot_version_io = 'IOSIGNAL'
iot_version_volumeAda = 'VOLUMEADAPT'

reboot_task = {}
-- By GST @2024/10/25