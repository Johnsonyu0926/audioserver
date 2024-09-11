#include <stdio.h>
#include <iostream>
#include "doorsbase.h"
#include <sys/ioctl.h>
#include <fcntl.h>
#include <openssl/md5.h>
#include "json.hpp"

#include "clientthread.h"
#include "login.hpp"
#include "network.hpp"
#include "serverset.hpp"
#include "volume.hpp"
#include "getaudiolist.hpp"
#include "unsupport.hpp"

#include "getDeviceBaseInfo.hpp"
#include "reboot.hpp"
#include "updatePwd.hpp"
#include "restore.hpp"
#include "audioStop.hpp"
#include "audioPlay.hpp"
#include "ttsPlay.hpp"
#include "fileUpload.hpp"
#include "ptzOperate.hpp"
#include "directional_sound_column.hpp"
#include "relaySet.hpp"
#include "audio_del.hpp"
#include "micRecord.hpp"
#include "public.hpp"

using namespace asns;

extern DWORD total_kilo;
#define BUF_LEN 2048 // FOR fragment.
using json = nlohmann::json;

int CClientThread::do_req(char *buf, CSocket *pClient) {
    if (strstr(buf, "Login")) {
        LOG(INFO) << "do login business.";
        CLogin login = m_json;
        login.do_req(pClient);
    } else if (strstr(buf, "NetworkSet")) {
        LOG(INFO) << "do network set business.";
        CNetworkSet networkSet = m_json;
        networkSet.do_req(pClient);
    } else if (strstr(buf, "ServerSet")) {
        LOG(INFO) << "do server set business.";
        CServerSet serverSet = m_json;
        serverSet.do_req(pClient);
    } else if (strstr(buf, "VolumeSet")) {
        LOG(INFO) << "do VolumeSet business.";
        CVolumeSet volumeSet = m_json;
        volumeSet.do_req(pClient);
    } else if (strstr(buf, "GetAudioList")) {
        LOG(INFO) << "GetAudioList cmd.";
        CGetAudioList getAudioList = m_json;
        getAudioList.do_req(pClient);
    } else if (strstr(buf, "GetDeviceBaseInfo")) {
        LOG(INFO) << "GetDeviceBaseInfo cmd";
        CGetDeviceBaseInfo deviceBaseInfo = m_json;
        deviceBaseInfo.do_req(pClient);
    } else if (strstr(buf, "AudioPlay")) {
        LOG(INFO) << "AudioPlay cmd";
        CAudioPlay audioPlay = m_json;
        audioPlay.do_req(pClient);
    } else if (strstr(buf, "TtsPlay")) {
        LOG(INFO) << "TtsPlay cmd";
        CTtsPlay ttsPlay = m_json;
        ttsPlay.do_req(pClient);
    } else if (strstr(buf, "FileUpload")) {
        LOG(INFO) << "FileUpload cmd";
        CFileUpload fileUpload = m_json;
        fileUpload.do_req(pClient);
    } else if (strstr(buf, "AudioStop")) {
        LOG(INFO) << "AudioStop cmd";
        CAudioStop audioStop = m_json;
        audioStop.do_req(pClient);
    } else if (strstr(buf, "Reboot")) {
        LOG(INFO) << "Reboot cmd";
        CReboot reboot = m_json;
        reboot.do_req(pClient);
    } else if (strstr(buf, "Restore")) {
        LOG(INFO) << "Restore cmd";
        CRestore restore = m_json;
        restore.do_req(pClient);
    } else if (strstr(buf, "UpdatePwd")) {
        LOG(INFO) << "UpdatePwd cmd";
        CUpdate update = m_json;
        update.do_req(pClient);
    }//{"duration":"5","uploadUrl":"http://192.168.85.1:8091/iot/1v1/api/v1/micRecordUpload","cmd":"MicRecord"}
    else if (strstr(buf, "MicRecord")) {
        LOG(INFO) << "MicRecord cmd";
        CMicRecord res = m_json;
        res.do_req(pClient);
    }
        //{"cmd":"AudioDelete","deleteName":"23.mp3","storageType":1}
    else if (strstr(buf, "AudioDelete")) {
        LOG(INFO) << "AudioDelete command.";
        CDeleteAudio res = m_json;
        res.do_req(pClient);
    } else if (strstr(buf, "PtzOperate")) {
        LOG(INFO) << "PtzOperate command.";
        CPtzOperate res = m_json;
        res.do_req(pClient);
    } else if (strstr(buf, "RelaySet")) {
        LOG(INFO) << "RelaySet command.";
        CRelaySet res = m_json;
        res.do_req(pClient);
    } else {
        LOG(INFO) << "unsupport command:" << buf;
        CUnsupportBusiness business = m_json;
        business.do_req(pClient);
    }
    return 0;
}

int CClientThread::do_verify(char *buf) {
    try {
        m_json = json::parse(buf, nullptr, false);
    }
    catch (...) {
        LOG(INFO) << "error parse:" << buf;
        return 0;
    }
    LOG(INFO) << "json is parse ok:" << m_json.dump();
    return 1;
}

int CClientThread::do_str_req(CSocket *pClient) {
    CBusiness bus;
    int opcode = std::stoi(m_str[3]);
    LOG(INFO) << "opcode: " << opcode;
    switch (opcode) {
        case TCPNETWORKSET:
            LOG(INFO) << "TCPNetworkSet";
            bus.TCPNetworkSet(m_str, pClient);
            break;
        case UPDATEPWD:
            LOG(INFO) << "UpdatePwd";
            bus.UpdatePwd(m_str, pClient);
            break;
        case NETWORKSET:
            LOG(INFO) << "NetworkSet";
            bus.NetworkSet(m_str, pClient);
            break;
        case LOGIN:
            LOG(INFO) << "LOGIN";
            bus.Login(m_str, pClient);
            break;
        case SETDEVICEADDRRESS:
            LOG(INFO) << "设置设备地址";
            break;
        case AUDIOPLAY:
            LOG(INFO) << "AudioPlay";
            bus.AudioPlay(m_str, pClient);
            break;
        case AUDIOSTOP:
            LOG(INFO) << "AudioStop";
            bus.AudioStop(pClient);
            break;
        case VOLUMSET:
            LOG(INFO) << "VolumeSet";
            bus.VolumeSet(m_str, pClient);
            break;
        case REBOOT:
            LOG(INFO) << "Reboot";
            bus.Reboot(pClient);
            break;
        case GETDEVICESTATUS:
            LOG(INFO) << "GetDeviceStatus";
            bus.GetDeviceStatus(pClient);
            break;
        case TTSPLAY:
            LOG(INFO) << "TtsPlay";
            bus.TtsPlay(m_str, pClient);
            break;
        case LIGHTSWITCH:
            LOG(INFO) << "闪灯开关";
            break;
        case FILEUPLOAD:
            LOG(INFO) << "fileUpload";
            bus.FileUpload(m_str, pClient);
            break;
        case RESTORE:
            LOG(INFO) << "Restore";
            bus.Restore(pClient);
            break;
        case AUDIONUMORTPLAY:
            LOG(INFO) << "AudioNumberOrTimePlay";
            bus.AudioNumberOrTimePlay(m_str, pClient);
            break;
        case TTSNUMORTPLAY:
            LOG(INFO) << "Tts Number or Time Play";
            bus.TtsNumTimePlay(m_str, pClient);
            break;
        case GETDEVICEBASEINFO:
            LOG(INFO) << "GetDeviceBaseInfo";
            bus.GetDeviceBaseInfo(pClient);
            break;
        case RECORD:
            LOG(INFO) << "Record";
            bus.Record(m_str, pClient);
            break;
        case REMOTEUPGRADE:
            LOG(INFO) << "远程升级";
            break;
        case GETAUDIOLIST:
            LOG(INFO) << "GetAudioList";
            bus.GetAudioList(m_str, pClient);
            break;
        case LIGHTCONFIG:
            LOG(INFO) << "FlashConfig";
            bus.FlashConfig(m_str, pClient);
            break;
        case RECORDBEGIN:
            LOG(INFO) << "RecordBegin";
            bus.RecordBegin(m_str, pClient);
            break;
        case RECORDEND:
            LOG(INFO) << "RecordEnd";
            bus.RecordEnd(m_str, pClient);
            break;
        case AUDIOFILEUPLOAD:
            LOG(INFO) << "AudioFileUpload";
            bus.AudioFileUpload(m_str, pClient);
            LOG(INFO) << "do_str_req end ...";
            break;
        case REMOTEFILEUPGRADE:
            LOG(INFO) << "RemoteFileUpgrade";
            bus.RemoteFileUpgrade(m_str, pClient);
            break;
        case DSPMANAGE:
            LOG(INFO) << "DSP Management";
            bus.DspManagement(m_str, pClient);
            break;
        default:
            LOG(INFO) << "switch F4";
            bus.SendFast(asns::NONSUPPORT_ERROR, pClient);
            break;
    }
    return 1;
}

#define DONE 0
#define UNCOMPLETE -1
#define LEN_ERR -2
#define CODE_ERR -3
int CClientThread::do_str_verify(char *buf, CSocket *pClient) {
    CBusiness bus;
    CUtils utils;
    m_str = utils.string_split(buf);
    if (m_str[0].compare("AA") != 0 || m_str[m_str.size() - 1].compare("EF") != 0) {
        bus.SendFast(asns::BEGIN_END_CODE_ERROR, pClient);
        return UNCOMPLETE;
    } else if (std::stoi(m_str[1]) != static_cast<int>(m_str.size() - 3)) {
        bus.SendFast(asns::LENGTH_ERROR, pClient);
        return LEN_ERR;
    } else if (m_str[m_str.size() - 2].compare("BB") != 0) {
        bus.SendFast(asns::CHECK_CODE_ERROR, pClient);
        return CODE_ERR;
    }
    return DONE;
}

BOOL CClientThread::InitInstance() {
    //m_login_status = 0;

    fd_set rset;
    int n;
    char buf[8192] = {0};
    char *p = buf;
    int offset = 0;
    while (1) {
        LOG(INFO) << "audioserver begin ...";
        FD_ZERO(&rset);
        FD_SET(m_pClient->m_hSocket, &rset);

        n = select(m_pClient->m_hSocket + 1, &rset, NULL, NULL, NULL);
        if (n > 0) {
            int n1 = m_pClient->Recv(p, sizeof(buf) - 1 - offset);
            if (n1 == 0) {
                LOG(INFO) << "recv finish!";
                m_pClient->Close();
                return 0;
            } else if (n1 < 0) {
                LOG(INFO) << "recv failed.";
                m_pClient->Close();
                return 0;
            } else {
                LOG(INFO) << "read buf:" << buf;
                if (strstr(buf, "AA") && strstr(buf, "EF")) {
                    int ret = do_str_verify(buf, m_pClient); 
					switch(ret) {
						case DONE:
								p = buf;
								offset = 0;
								do_str_req(m_pClient);
								LOG(INFO) << "InitInstance do_str_req end";
								memset(buf, 0, sizeof(buf));
							break;
						case UNCOMPLETE:
							offset += n1;
							p += offset;
							break;
						default:
							//error. ignore.
							offset = 0;
							memset(buf, 0, sizeof(buf));
							LOG(INFO) << "Ignore this message, ret = "<<ret;
							break;
					}
                } else {
                    if (do_verify(buf)) {
                        p = buf;
                        offset = 0;
                        do_req(buf, m_pClient);
                        memset(buf, 0, sizeof(buf));
                    } else {
                        offset += n1;
                        p += offset;
                    }
                }
            }
        } else {
            if (n == 0) {
            }

            if (n < 0) {
                LOG(WARNING) << "select < 0";
                return 0;
            }
        }
    }
    return TRUE;
}

BOOL CClientThread::Check(const unsigned char *szBuf) {
    unsigned char szHash[16];
    MD5(szBuf, 1008, szHash);
    if (memcmp(szHash, &(szBuf[1008]), 16) == 0)
        return TRUE;

    return FALSE;
}

BOOL CClientThread::ExitInstance() {
    if (m_pClient) {
        delete m_pClient;
        m_pClient = NULL;
    }
    return TRUE;
}

BOOL CClientThread::Gen(BYTE *szBuf) {
    static unsigned long long key;
    for (int i = 0; i < 1008; i += 8) {
        key = key * (unsigned long long) (3141592621) + (unsigned long long) (663896637);
        memcpy(&(szBuf[i]), &key, 8);
    }
    MD5((const BYTE *) szBuf, 1008, &(szBuf[1008]));
    return TRUE;
}
