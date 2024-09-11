#pragma once

#include "public.hpp"
#include "add_column_custom_audio_file.hpp"
#include "utils.h"
#include "Rs485.hpp"

#include <fstream>

class CSThread;

class CSocket;


class TcpTransferThread : public CSThread {
public:
    virtual BOOL InitInstance() {
        CSocket socket;
        if (!socket.Create(TCP)) {
            return SendFast(asns::OPERATION_FAIL_ERROR, pClient);
        }
        int opt = 1;
        setsockopt(socket.m_hSocket, SOL_SOCKET, SO_REUSEADDR, (const char *) &opt, sizeof(opt));
        for (int i = m_nPort; i < asns::ENDPORT; ++i) {
            if (socket.Bind(i)) {
                m_nPort = i;
                if (std::stoi(m_vecStr[3]) != asns::RECORDEND) {
                    std::string res = "01 E1 " + m_vecStr[5] + " " + std::to_string(m_nPort);
                    if(pClient == nullptr){
                        Rs485::_uart_work(res.c_str(),res.length());
                    }else{
                        pClient->Send(res.c_str(), res.length());
                    }
                } else {
                    CUtils utils;
                    int file_size = utils.get_file_size(asns::RECORD_PATH);
                    std::string res = "01 E1 " + m_vecStr[4] + " " + std::to_string(file_size) + " " + std::to_string(m_nPort);
                    if(pClient == nullptr){
                        Rs485::_uart_work(res.c_str(),res.length());
                    }else{
                        pClient->Send(res.c_str(), res.length());
                    }
                }
                break;
            } else if (i == asns::ENDPORT) {
                LOG(INFO) << "fatal , bind error!";
                return SendFast(asns::OPERATION_FAIL_ERROR, pClient);
            }
        }
        socket.Listen();
        fd_set rset;
        FD_ZERO(&rset);
        FD_SET(socket.m_hSocket, &rset);
        struct timeval timeout;
        timeout.tv_sec = 30;
        timeout.tv_usec = 0;
        int n = select(socket.m_hSocket + 1, &rset, NULL, NULL, &timeout);
        if (n < 0) {
            LOG(INFO) << "fatal , select error!";
            return SendFast(asns::OPERATION_FAIL_ERROR, pClient);
        } else if (n == 0) {
            LOG(INFO) << "timeout!";
            return SendFast(asns::TCP_TIMEOUT, pClient);
        } else if (n > 0) {
            LOG(INFO) << "server select n = " << n;
        }
        CSocket *pTcp = new CSocket;
        socket.Accept(pTcp);
        LOG(INFO) << "Got the no." << " connection :" << pTcp->GetRemoteIp() << ":" << ntohs(pTcp->GetPeerPort());
        do_req(pTcp);
        socket.Close();
        delete pTcp;
        return 1;
    }

    virtual BOOL ExitInstance() {
        LOG(INFO) << "exit tcp transfer thread.";
        return TRUE;
    }

    void SetPort(int nPort) { m_nPort = nPort; }

    void SetClient(CSocket *pClient) { this->pClient = pClient; }

    void SetVecStr(const std::vector<std::string> &vecStr) { m_vecStr = vecStr; }

private:
    int do_req(CSocket *pTcp) {
        int condition = std::stoi(m_vecStr[3]);
        switch (condition) {
            case asns::RECORDEND:
                Record(pTcp);
                break;
            case asns::AUDIOFILEUPLOAD:
                FileUpload(pTcp);
                break;
            case asns::REMOTEFILEUPGRADE:
                FileUpgrade(pTcp);
                break;
            default:
                SendFast(asns::NONSUPPORT_ERROR, pClient);
                break;
        }
        return 1;
    }

    int Record(CSocket *pTcp) {
        CUtils utils;
        int file_size = utils.get_file_size(asns::RECORD_PATH);
        LOG(INFO) << "record file size:" << file_size;
        char buf[asns::BUFSIZE] = {0};
        std::fstream fs(asns::RECORD_PATH, std::fstream::in | std::fstream::binary);
        while (!fs.eof()) {
            fs.read(buf, sizeof(buf));
            LOG(INFO) << fs.gcount() << " ";
            if (fs.gcount() <= 0) {
                LOG(INFO) << "read count < 0";
                break;
            }
            pTcp->Send(buf, fs.gcount());
            file_size -= fs.gcount();
            if (file_size <= 0) {
                LOG(INFO) << "file size < 0";
                break;
            }
        }
        fs.close();
        LOG(INFO) << "Send ok";
        system("rm /tmp/record.mp3");
        return SendTrue(pClient);
    }

    int FileUpload(CSocket *pTcp) {
        std::string prefix = m_vecStr[6].substr(0, m_vecStr[6].find_first_of('.'));
        std::string suffix = m_vecStr[6].substr(m_vecStr[6].find_first_of('.') + 1);
        std::transform(suffix.begin(), suffix.end(), suffix.begin(), ::tolower);
        std::string name = prefix + "." + suffix;
        asns::CAudioCfgBusiness cfg;
        std::string path = cfg.getAudioFilePath() + name;
        std::fstream fs(path, std::fstream::out | std::fstream::binary | std::fstream::trunc);

        int file_size = std::atoi(m_vecStr[4].c_str());
        char buf[asns::BUFSIZE] = {0};

        while (true) {
            int len = pTcp->Recv(buf, sizeof(buf));
            LOG(INFO) << "recv len :" << len;
            if (len > 0) {
                fs.write(buf, len);
                file_size -= len;
                if (file_size <= 0) {
                    LOG(INFO) << "read end";
                    break;
                }
            } else if (len == 0) {
                LOG(INFO) << "read end";
                break;
            } else if (len < 0) {
                fs.close();
                std::string cmd = "rm " + path;
                system(cmd.c_str());
                return SendFast(asns::RECORD_SIZE_ERROR, pClient);
            }
        }
        fs.close();
        LOG(INFO) << "begin json";
        CUtils utils;
        utils.bit_rate_32_to_48(path);
        asns::CAddColumnCustomAudioFileBusiness business;
        if (!business.exist(name)) {
            asns::CAddColumnCustomAudioFileData node;
            node.type = asns::AUDIO_FILE_TYPE;
            node.setName(name);
            node.size = utils.get_file_size(path);
            business.business.push_back(node);
            business.saveJson();
        } else {
            business.updateSize(name, std::atoi(m_vecStr[4].c_str()));
        }
        return SendTrue(pClient);
    }

    int FileUpgrade(CSocket *pTcp) {
        CUtils utils;
        std::fstream fs(asns::FIRMWARE_PATH, std::fstream::out | std::fstream::binary);
        int file_size = std::atoi(m_vecStr[4].c_str());
        char buf[asns::BUFSIZE] = {0};
        while (true) {
            int len = pTcp->Recv(buf, sizeof(buf));
            if (len > 0) {
                fs.write(buf, len);
                LOG(INFO) << len << " ";
                file_size -= len;
                if (file_size <= 0)break;
            } else if (len <= 0) {
                fs.close();
                return SendFast(asns::TCP_TRANSFER_ERROR, pClient);
            }
        }
        fs.close();
        SendTrue(pClient);
        LOG(INFO) << "begin up read size:" << utils.get_file_size(asns::FIRMWARE_PATH);
        std::string cmdRes = utils.get_by_cmd_res("webs -U /var/run/SONICCOREV100R001.bin");
        LOG(INFO) << "cmd res:" << cmdRes;
        if (cmdRes.find("OK") != std::string::npos) {
            utils.reboot();
        } else {
            system("rm /var/run/SONICCOREV100R001.bin");
        }
        return 1;
    }

    int SendTrue(CSocket *pClient) {
        std::string res = "01 E1";
        LOG(INFO) << "return: " << res;
        if(pClient == nullptr){
            return Rs485::_uart_work(res.c_str(),res.length());
        }
        return pClient->Send(res.c_str(), res.length());
    }

    int SendFast(const std::string &err_code, CSocket *pClient) {
        std::string buf = "01 " + err_code;
        LOG(INFO) << "return: " << buf;
        if(pClient == nullptr){
            return Rs485::_uart_work(buf.c_str(),buf.length());
        }
        return pClient->Send(buf.c_str(), buf.length());
    }

private:
    CSocket *pClient;
    int m_nPort;
    std::vector<std::string> m_vecStr;
};