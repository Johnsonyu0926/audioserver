-- Filename: mountFlash.lua
module(..., package.seeall)

require "pmd"
require "nvm"
require "config"

nvm.init("config.lua")

-- 需要挂载文件的路径
local USER_DIR_PATH = nvm.get("user_dir_path")
local spiMountStatus = 0

-- 挂载文件 需要挂载的路径, 挂载 flash 的大小 
-- eg:挂载 8M mountF(path, 8)
function mountF(path, n)
    local size = n * 1024 * 1024
    local clock = 60000000

    local format_tag = nvm.get('flash_format_tag')
    if format_tag == true then
        log.info("初始化格式化SPI FLASH")
        io.format(io.EXTERN_PINLCD, path, size, 0, clock)
        nvm.set('flash_format_tag', false)
    end

    log.info("开始挂载")
    local result = io.mount(io.EXTERN_PINLCD, path, size, 0, clock)
    if result == 1 then 
        log.info("mount", "success")
        return true
    else
        log.info("mount fail", "format")
        result = io.format(io.EXTERN_PINLCD, path, size, 0, clock)
        log.info("format result", result)
        result = io.mount(io.EXTERN_PINLCD, path, size, 0, clock)
        if result == 1 then
            log.info("mount", "success")
            return true
        else
            log.info("mount", "fail")
            return false 
        end
    end
end

function getSpiMountStatus()
    return spiMountStatus
end

function getSpiFreeSpace()
    local freeSpace = rtos.get_fs_free_size(3, 0, USER_DIR_PATH)
    return freeSpace
end

sys.taskInit(function()
    log.info("开始挂载spi flash")
    sys.wait(3000)
    if not mountF(USER_DIR_PATH, 16) then
        log.error("mount", "false")
        spiMountStatus = 2
        return
    else
        spiMountStatus = 1
    end
end)
-- By GST @2024/10/25