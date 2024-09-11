#pragma once
#include "directional_sound_column.hpp"

class RSBusinessManage {
public:
    int do_str_req() {
        asns::CBusiness bus;
        int opcode = std::stoi(m_str[3]);
        cout << "opcode: " << opcode << endl;
        switch (opcode) {
            case asns::TCPNETWORKSET:
                LOG(INFO) << "TCPNetworkSet";
                bus.TCPNetworkSet(m_str);
                break;
            case asns::UPDATEPWD:
                LOG(INFO) << "UpdatePwd";
                bus.UpdatePwd(m_str);
                break;
            case asns::NETWORKSET:
                LOG(INFO) << "NetworkSet";
                bus.NetworkSet(m_str);
                break;
            case asns::LOGIN:
                LOG(INFO) << "LOGIN";
                bus.Login(m_str);
                break;
            case asns::SETDEVICEADDRRESS:
                LOG(INFO) << "设置设备地址";
                break;
            case asns::AUDIOPLAY:
                LOG(INFO) << "AudioPlay";
                bus.AudioPlay(m_str);
                break;
            case asns::AUDIOSTOP:
                LOG(INFO) << "AudioStop";
                bus.AudioStop();
                break;
            case asns::VOLUMSET:
                LOG(INFO) << "VolumeSet";
                bus.VolumeSet(m_str);
                break;
            case asns::REBOOT:
                LOG(INFO) << "Reboot";
                bus.Reboot();
                break;
            case asns::GETDEVICESTATUS:
                LOG(INFO) << "GetDeviceStatus";
                bus.GetDeviceStatus();
                break;
            case asns::TTSPLAY:
                LOG(INFO) << "TtsPlay";
                bus.TtsPlay(m_str);
                break;
            case asns::LIGHTSWITCH:
                LOG(INFO) << "闪灯开关";
                break;
            case asns::FILEUPLOAD:
                LOG(INFO) << "fileUpload";
                bus.FileUpload(m_str);
                break;
            case asns::RESTORE:
                LOG(INFO) << "Restore";
                bus.Restore();
                break;
            case asns::AUDIONUMORTPLAY:
                LOG(INFO) << "AudioNumberOrTimePlay";
                bus.AudioNumberOrTimePlay(m_str);
                break;
            case asns::TTSNUMORTPLAY:
                LOG(INFO) << "Tts Number or Time Play";
                bus.TtsNumTimePlay(m_str);
                break;
            case asns::GETDEVICEBASEINFO:
                LOG(INFO) << "GetDeviceBaseInfo";
                bus.GetDeviceBaseInfo();
                break;
            case asns::RECORD:
                LOG(INFO) << "Record";
                bus.Record(m_str);
                break;
            case asns::REMOTEUPGRADE:
                LOG(INFO) << "远程升级";
                break;
            case asns::GETAUDIOLIST:
                LOG(INFO) << "GetAudioList";
                bus.GetAudioList(m_str);
                break;
            case asns::LIGHTCONFIG:
                LOG(INFO) << "FlashConfig";
                bus.FlashConfig(m_str);
                break;
            case asns::RECORDBEGIN:
                LOG(INFO) << "RecordBegin";
                bus.RecordBegin(m_str);
                break;
            case asns::RECORDEND:
                LOG(INFO) << "RecordEnd";
                bus.RecordEnd(m_str);
                break;
            case asns::AUDIOFILEUPLOAD:
                LOG(INFO) << "AudioFileUpload";
                bus.AudioFileUpload(m_str);
                break;
            case asns::REMOTEFILEUPGRADE:
                LOG(INFO) << "RemoteFileUpgrade";
                bus.RemoteFileUpgrade(m_str);
                break;
            case asns::DSPMANAGE:
                LOG(INFO) << "DSP Management";
                bus.DspManagement(m_str);
                break;
            default:
                LOG(INFO) << "switch F4";
                asns::CBusiness::SendFast(asns::NONSUPPORT_ERROR);
                break;
        }
        return 1;
    }

    int handle_receive(const char *buf) {
        CUtils utils;
        m_str = utils.string_split(buf);
        if (m_str[0].compare("AA") != 0 || m_str[m_str.size() - 1].compare("EF") != 0) {
            asns::CBusiness::SendFast(asns::BEGIN_END_CODE_ERROR);
            return 0;
        } else if (std::stoi(m_str[1]) != static_cast<int>(m_str.size() - 3)) {
            asns::CBusiness::SendFast(asns::LENGTH_ERROR);
            return 0;
        } else if (m_str[m_str.size() - 2].compare("BB") != 0) {
            asns::CBusiness::SendFast(asns::CHECK_CODE_ERROR);
            return 0;
        }
        return do_str_req();
    }

    int worker() {
        int fd = Rs485::_uart_open();
        if (fd < 0) {
            return -1;
        }

        int read_count = 0;
        char buf[1024] = {0};
        while (!AcquisitionNoise::getInstance().getMonitorStatus()) {
            memset(buf, 0, sizeof(buf));
            read_count = Rs485::_uart_read(buf, sizeof(buf));

            if (read_count < 0) {
                LOG(INFO) << "failed to read ! errno ="<< errno << " strerror=" << strerror(errno);
                return 0;
            }
            LOG(INFO) <<"recv request:"<< buf << "len: "<< read_count << ", handle it...";
            handle_receive(buf);
        }
        return 1;
    }

private:
    std::vector<std::string> m_str;
};
