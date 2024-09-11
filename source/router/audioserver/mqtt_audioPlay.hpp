#pragma once

#include "json.hpp"
#include "audiocfg.hpp"
#include "add_mqtt_custom_audio_file.hpp"
#include "utils.h"
#include "volume.hpp"

using json = nlohmann::json;

/*
 *  // mqtt发送体（即详细的功能参数，详细参数已JSON格式体展现）
            {
                "fileName":"65.mp3", // 播放音频文件�?
                "audioUploadRecordId":389, // 播放音频文件上传id
                "playCount":1, // 播放次数，单位次；当timeType为次数播放时生效
                "playDuration":60, // 播放时长，单位秒，当timeType为时长播放时生效
                "playStatus":1, // 播放状态，�?代表音频播放，详细参�?播放状态枚�?
                "playType":1, // 播放模式�?-音频文件�?-文字播报�?-录音文件播放
                "storageType":1, // 存储位置�?-内置Flash�?-外置存储, 可不�?
                "timeType":0 // 0-时长播放�?-次数播放
            }


        {
            "result":"播放成功", // 处理结果
            "resultId":1, // 处理结果标记�?-表示未处理；1-表示处理成功�?-表示处理失败�?
            "imei":"869298057401606", // 设备唯一序列�?
            "topic":"TaDiao/device/report/test/869298057401606", // topic
            "cmd":"audioPlay", // 当次处理的功能标�?
            "publishId":172684, // 平台下发的本次请求id
            "data": "" // 处理完成上传数据，如果有则需要上传，详情参照详细功能通信指令，已JSON格式体展�?
        }
 */



namespace asns {
    template<typename Quest, typename Result>
    class CReQuest;

    template<typename T>
    class CResult;

    class CAudioPlayResultData {
    public:
        NLOHMANN_DEFINE_TYPE_INTRUSIVE_WITH_DEFAULT(CAudioPlayResultData, null)

        template<typename Quest, typename Result, typename T>
        int do_success(const CReQuest<Quest, Result> &c, CResult<T> &r) {
            CUtils utils;
            if (CUtils::get_process_status("madplay") || CUtils::get_process_status("ffplay")) {
                r.resultId = 2;
                r.result = "Already played";
                return 2;
            }
            CAudioCfgBusiness cfg;
            cfg.load();

            CAddMqttCustomAudioFileBusiness business;
            if (business.exist(c.data.fileName) &&
                utils.find_dir_file_exists(cfg.getAudioFilePath(), c.data.fileName) == false) {
                business.deleteData(c.data.fileName);
                r.resultId = 2;
                r.result = "audio file does not exist";
                return 2;
            } else if (business.exist(c.data.fileName) &&
                       utils.find_dir_file_exists(cfg.getAudioFilePath(), c.data.fileName)) {
                switch (c.data.timeType) {
                    case 0: {
                        if (c.data.playDuration < 1) {
                            r.resultId = 2;
                            r.result = "play time error";
                            return 2;
                        }
                        AcquisitionNoise::getInstance().noise_auto_set_volume();
						AcquisitionNoise::getInstance().noiseDeque.clear();
                        PlayStatus::getInstance().setMqttPlayStatus(c.data.playStatus);
                        AudioPlayUtil::audio_time_play(c.data.playDuration, cfg.getAudioFilePath() + c.data.fileName,
                                              ASYNC_START);
                        break;
                    }
                    case 1: {
                        if (c.data.playCount < 1) {
                            r.resultId = 2;
                            r.result = "play count error";
                            return 2;
                        }
                        AcquisitionNoise::getInstance().noise_auto_set_volume();
						AcquisitionNoise::getInstance().noiseDeque.clear();
                        PlayStatus::getInstance().setMqttPlayStatus(c.data.playStatus);
                        AudioPlayUtil::audio_num_play(c.data.playCount, cfg.getAudioFilePath() + c.data.fileName, ASYNC_START);
                        break;
                    }
                }
            } else {
                r.resultId = 2;
                r.result = "audio file does not exist";
                return 2;
            }
            r.resultId = 1;
            r.result = "success";
            return 1;
        }

    public:
        std::nullptr_t null;
    };


    class CAudioPlayData {
    public:
        NLOHMANN_DEFINE_TYPE_INTRUSIVE_WITH_DEFAULT(CAudioPlayData, fileName, audioUploadRecordId, playCount,
                                                    playDuration,
                                                    playStatus, playType, storageType, timeType)

    public:
        std::string fileName;
        int audioUploadRecordId;
        int playCount;
        int playDuration;
        int playStatus;
        int playType;
        int storageType;
        int timeType;
    };
}
