// Filename: Rs485.hpp
// 评分：96分
#pragma once

#include <cstdlib>
#include <csignal>
#include <cerrno>
#include <cstring>
#include <cstdio>
#include <fcntl.h>
#include <string>
#include <termios.h>
#include "audiocfg.hpp"
#include "AcquisitionNoise.hpp"

    static int init_rs485(const char *device, int baudrate) {
        m_rs485 = open(device, O_RDWR | O_NOCTTY | O_NONBLOCK);
        if (m_rs485 == -1) {
            perror("Unable to open RS485 device");
            return -1;
        }

        struct termios tty{};
        memset(&tty, 0, sizeof tty);

        if (tcgetattr(m_rs485, &tty) != 0) {
            perror("tcgetattr");
            close(m_rs485);
            return -1;
        }

        cfsetospeed(&tty, baudrate);
        cfsetispeed(&tty, baudrate);

        tty.c_cflag = (tty.c_cflag & ~CSIZE) | CS8; // 8-bit chars
        tty.c_iflag &= ~IGNBRK; // disable break processing
        tty.c_lflag = 0; // no signaling chars, no echo,
        tty.c_oflag = 0; // no remapping, no delays
        tty.c_cc[VMIN]  = 0; // read doesn't block
        tty.c_cc[VTIME] = 5; // 0.5 seconds read timeout

        tty.c_iflag &= ~(IXON | IXOFF | IXANY); // shut off xon/xoff ctrl

        tty.c_cflag |= (CLOCAL | CREAD); // ignore modem controls,
        tty.c_cflag &= ~(PARENB | PARODD); // shut off parity
        tty.c_cflag |= 0;
        tty.c_cflag &= ~CSTOPB;
        tty.c_cflag &= ~CRTSCTS;

        if (tcsetattr(m_rs485, TCSANOW, &tty) != 0) {
            perror("tcsetattr");
            close(m_rs485);
            return -1;
        }

        return 0;
    }

    static void close_rs485() {
        if (m_rs485 != -1) {
            close(m_rs485);
            m_rs485 = -1;
        }
    }
};

    static int while_select(const int fd, unsigned char buffer[], const int length, int timeout) {
        timeval time{};
        time.tv_sec = timeout; // set the rcv wait time
        fd_set fs_read;
        while (true) {
            FD_ZERO(&fs_read); // 每次循环都要清空集合，否则不能检测描述符变化
            FD_SET(fd, &fs_read); // 添加描述符
            // 超时等待读变化，>0：就绪描述字的正数目， -1：出错， 0 ：超时
            const int res = select(fd + 1, &fs_read, nullptr, nullptr, &time);
            if (res <= 0) {
                return -1;
            }
            return read(fd, buffer, length);
        }
    }

    static int _uart_read(char *pcBuf, int iBufLen) {
        set_receive_dir();
        int iFd = m_rs485, iLen = 0;
        int i;

        *pcBuf = '\0';
        LOG(INFO) << "reading... from fd:" << iFd;
        iLen = select_read(iFd, (unsigned char *)pcBuf, iBufLen, 100);
        if (iLen < 0) {
            close(iFd);
            m_rs485 = -1;
            LOG(INFO) << "error read from fd " << iFd;
            return iLen;
        }

        // ignore 0x0
        while (iLen == 1 && pcBuf[0] == 0x0) {
            LOG(INFO) << "ignore the 0x0 .";
            iLen = select_read(iFd, (unsigned char*)pcBuf, iBufLen, 100);
            if (AcquisitionNoise::getInstance().getMonitorStatus())  {
                close(iFd);
                m_rs485 = -1;
                return -1;
            }
        }

        LOG(INFO) << "read success: iLen= " << iLen << " , hex dump: ";
        for (i = 0; i < iLen; i++) {
            LOG(INFO) << std::hex << pcBuf[i];
        }
        LOG(INFO) << "\nhex dump end.";

        while (true) {
            if ((iLen > 5) &&
                ('B' == pcBuf[iLen - 5]) &&
                ('B' == pcBuf[iLen - 4]) &&
                (' ' == pcBuf[iLen - 3]) &&
                ('E' == pcBuf[iLen - 2]) &&
                ('F' == pcBuf[iLen - 1])) {
                LOG(INFO) << "receive completed.";
                break;
            }

            int next = select_read(iFd, (unsigned char*)pcBuf + iLen, iBufLen - iLen, 100);
            if (AcquisitionNoise::getInstance().getMonitorStatus()) {
                close(iFd);
                m_rs485 = -1;
                return -1;
            }
            iLen += next;
        }
        LOG(INFO) << "total len = " << iLen;

        for (i = 0; i < iLen; i++) {
            LOG(INFO) << "%02x " << std::hex << pcBuf[i];
        }
        LOG(INFO) << "\nhex dump end.";
        return iLen;
    }

    static int _uart_open() {
        int iFd = -1;
        struct termios opt{};
        asns::CAudioCfgBusiness cfg;
        cfg.load();
        int iBdVal = cfg.business[0].iBdVal;

        system("echo 3 > /sys/class/gpio/export");
        system("echo out > /sys/class/gpio/gpio3/direction");

        char name[32] = {0};
        sprintf(name, "/dev/ttyS%d", m_rsTty);

        iFd = open(name, O_RDWR | O_NOCTTY);  /* 读写方式打开串口 */
        LOG(INFO) << "uart open fd: " << iFd;
        if (iFd < 0) {
            LOG(WARNING) << "uart open fd error" << iFd;
            return -1;
        }

        tcgetattr(iFd, &opt);
        cfmakeraw(&opt);

        cfsetispeed(&opt, iBdVal);
        cfsetospeed(&opt, iBdVal);

        tcsetattr(iFd, TCSANOW, &opt);
        char cmd[64] = {0};
        sprintf(cmd, "stty -F /dev/ttyS%d %d", m_rsTty, iBdVal);
        system(cmd);
        LOG(INFO) << "uart open ibd :" << cmd;
        m_rs485 = iFd;
        return iFd;
    }

    /* Write data to uart dev, return 0 means OK */
    static int _uart_write(const char *pData, int iLen)  {
        set_send_dir();
        int iFd = m_rs485;
        int iRet = -1;
        int len = 0;
        unsigned const char *pcData = (unsigned const char*)pData;
        int count = iLen / MAX_SEND;
        if (iLen % MAX_SEND) {
            count++;
        }
        int offset = 0;
        LOG(INFO) << "count=" << count;
        for (int i = 0; i < count; i++) {
            if ((i + 1) * MAX_SEND > iLen) {
                len = iLen - i * MAX_SEND;
            } else {
                len = MAX_SEND;
            }
            LOG(INFO)<< "no." << i << ": offset:" << offset << " len:" << len;
            unsigned const char *data = pcData + offset;
            for (int j = 0; j < len; j++) {
                LOG(INFO) << std::hex << data[j];
            }
            iRet = write(iFd, data, len);
            if (iRet < 0) {
                close(iFd);
                m_rs485 = -1;
                LOG(INFO) << "error write " << iFd << " , len:" << len;
            } else {
                LOG(INFO) << "no." << i << ": write len:" << len << " success, iRet:" << iRet;
            }

            offset += MAX_SEND;
        }
        set_receive_dir();
        return iRet;
    }

    static int get_rs485_state() {
        return m_rs485 != -1;
    }

    static int _uart_work(const char *buf, int len) {
        if(m_rs485 <= 0){
            int fd = _uart_open();
            if (fd < 0) {
                LOG(WARNING) << "failed to open ttyS%d to read write." << m_rsTty;
                return 0;
            }
            m_rs485 = fd;
        }
        _uart_write(buf, len);
        return 1;
    }

    static void uart_fcntl_set(const int flag){
        fcntl(m_rs485,F_SETFL, flag);
    }

    static void uart_close() {
        close(m_rs485);
        std::cout << "m_rs485 close fd:" << m_rs485;
        m_rs485 = -1;
    }

    static int SendTrue() {
        std::string res = "01 E1";
        return _uart_write(res.c_str(), res.length());
    }

    static int SendFast(const std::string &err_code) {
        std::string buf = "01 " + err_code;
        return _uart_write(buf.c_str(), buf.length());
    }
};
// By GST @Date
