#pragma once

#include "json.hpp"
#include "utils.h"
#include "add_custom_audio_file.hpp"

namespace asns {
    class CFileUploadResult {
    public:
        NLOHMANN_DEFINE_TYPE_INTRUSIVE(CFileUploadResult, cmd, resultId, msg)

        void do_success() {
            cmd = "FileUpload";
            resultId = 1;
            msg = "file upload success";
        }

        void do_fail(const std::string& str) {
            cmd = "FileUpload";
            resultId = 2;
            msg = str;
        }

    private:
        std::string cmd;
        int resultId;
        std::string msg;
    };

    class CFileUpload {
    public:
        NLOHMANN_DEFINE_TYPE_INTRUSIVE(CFileUpload, downloadUrl, fileName)

        int do_req(CSocket *pClient) {
            std::transform(fileName.begin(), fileName.end(), fileName.begin(), ::tolower);
            CFileUploadResult fileUploadResult;
            CUtils utils;
            if(utils.get_available_Disk("/mnt") < asns::DISK_SIZE){
                fileUploadResult.do_fail("Lack of space");
                json js = fileUploadResult;
                std::string str = js.dump();
                LOG(INFO) << "return json: " << str;
                return pClient->Send(str.c_str(), str.length());
            }
            CAudioCfgBusiness cfg;
            std::string res = utils.get_upload_result(downloadUrl.c_str(), cfg.getAudioFilePath().c_str(),
                                                      fileName.c_str());
            if (res.compare("success") != 0) {
                fileUploadResult.do_fail(res);
            } else {
                CAddCustomAudioFileData node;
                node.filePath = downloadUrl;
                node.customAudioName = fileName;
                CAddCustomAudioFileBusiness business;
                utils.bit_rate_32_to_48(cfg.getAudioFilePath() + fileName);
                if (!business.exist(fileName)) {
                    business.business.push_back(node);
                    business.saveToJson();
                    fileUploadResult.do_success();
                } else {
                    fileUploadResult.do_success();
                }
            }
            json js = fileUploadResult;
            std::string str = js.dump();
            LOG(INFO) << "return json: " << str;
            return pClient->Send(str.c_str(), str.length());
        }

    private:
        std::string cmd;
        std::string downloadUrl;
        std::string fileName;
    };
}