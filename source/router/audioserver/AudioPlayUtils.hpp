#pragma once

#include "AcquisitionNoise.hpp"
#include "AudioPlayStatus.hpp"
#include "utils.h"

class AudioPlayUtil {
public:
    static std::string ttsCmd(const std::string &txt, const int speed = 50, const int gender = 0) {
        std::string cmd = "tts.sh \"" + txt + "\" " + std::to_string(speed);
        switch (gender) {
            case 0:
                cmd += " xiaoyan";
                break;
            case 1:
                cmd += " xiaofeng";
                break;
            default:
                break;
        }
        return cmd;
    }

    static void tts_loop_play(const std::string &txt, const bool async = false, const int speed = 50, const int gender = 0) {
        std::string cmd = ttsCmd(txt, speed, gender);
        LOG(INFO) << "tts_loop_play cmd :" << cmd;
        if (async) {
            CUtils::async_wait(1, 0, 0, [=] {
                PlayStatus::getInstance().setPlayId(asns::TTS_TASK_PLAYING);
                PlayStatus::getInstance().setPlayConten(txt);
                while (PlayStatus::getInstance().getPlayId() == asns::TTS_TASK_PLAYING) {
                    if (!CUtils::get_process_status("ffplay") &&
                        PlayStatus::getInstance().getPlayId() == asns::TTS_TASK_PLAYING) {
                        CUtils::cmd_system(cmd);
                    } else if (PlayStatus::getInstance().getPlayId() != asns::TTS_TASK_PLAYING) {
                        break;
                    }
                    usleep(1000 * 100);
                }
            });
        } else {
            PlayStatus::getInstance().setPlayId(asns::TTS_TASK_PLAYING);
            PlayStatus::getInstance().setPlayConten(txt);
            while (PlayStatus::getInstance().getPlayId() == asns::TTS_TASK_PLAYING) {
                if (!CUtils::get_process_status("ffplay") &&
                    PlayStatus::getInstance().getPlayId() == asns::TTS_TASK_PLAYING) {
                    CUtils::cmd_system(cmd);
                } else if (PlayStatus::getInstance().getPlayId() != asns::TTS_TASK_PLAYING) {
                    break;
                }
                usleep(1000 * 100);
            }
        }
    }

    static void tts_num_play(const int num, const std::string &txt, const bool async = false, const int speed = 50,
                             const int gender = 0) {
        std::string cmd = ttsCmd(txt, speed, gender);
        LOG(INFO) << "tts_num_play cmd :" << cmd;
        if (async) {
            CUtils::async_wait(1, 0, 0, [=] {
                PlayStatus::getInstance().setPlayId(asns::TTS_TASK_PLAYING);
                PlayStatus::getInstance().setPlayConten(txt);
                for (int i = 0; i < num; ++i) {
                    while (CUtils::get_process_status("ffplay")) {
                        usleep(1000 * 100);
                    }
                    if (PlayStatus::getInstance().getPlayId() != asns::TTS_TASK_PLAYING) {
                        break;
                    }
                    CUtils::cmd_system(cmd);
                    if (PlayStatus::getInstance().getPlayId() != asns::TTS_TASK_PLAYING) {
                        break;
                    }
                }
                PlayStatus::getInstance().init();
            });
        } else {
            PlayStatus::getInstance().setPlayId(asns::TTS_TASK_PLAYING);
            PlayStatus::getInstance().setPlayConten(txt);
            for (int i = 0; i < num; ++i) {
                while (CUtils::get_process_status("ffplay")) {
                    usleep(1000 * 100);
                }
                if (PlayStatus::getInstance().getPlayId() != asns::TTS_TASK_PLAYING) {
                    break;
                }
                CUtils::cmd_system(cmd);
                if (PlayStatus::getInstance().getPlayId() != asns::TTS_TASK_PLAYING) {
                    break;
                }
            }
            PlayStatus::getInstance().init();
        }
    }

    static void tts_time_play(const int time, const std::string &txt, const bool async = false, const int speed = 50,
                              const int gender = 0) {
        std::string cmd = ttsCmd(txt, speed, gender);
        LOG(INFO) << "tts_time_play cmd :" << cmd;
        CUtils::async_wait(1, time, 0, [&] {
            CUtils::cmd_system("killall -9 ffplay");
            PlayStatus::getInstance().init();
        });
        if (async) {
            CUtils::async_wait(1, 0, 0, [=] {
                PlayStatus::getInstance().setPlayId(asns::TTS_TASK_PLAYING);
                PlayStatus::getInstance().setPlayConten(txt);
                while (PlayStatus::getInstance().getPlayId() == asns::TTS_TASK_PLAYING) {
                    if (!CUtils::get_process_status("ffplay") &&
                        PlayStatus::getInstance().getPlayId() == asns::TTS_TASK_PLAYING) {
                        CUtils::cmd_system(cmd);
                    } else if (PlayStatus::getInstance().getPlayId() != asns::TTS_TASK_PLAYING) {
                        break;
                    }
                    usleep(1000 * 100);
                }
            });
        } else {
            PlayStatus::getInstance().setPlayId(asns::TTS_TASK_PLAYING);
            PlayStatus::getInstance().setPlayConten(txt);
            while (PlayStatus::getInstance().getPlayId() == asns::TTS_TASK_PLAYING) {
                if (!CUtils::get_process_status("ffplay") &&
                    PlayStatus::getInstance().getPlayId() == asns::TTS_TASK_PLAYING) {
                    CUtils::cmd_system(cmd);
                } else if (PlayStatus::getInstance().getPlayId() != asns::TTS_TASK_PLAYING) {
                    break;
                }
                usleep(1000 * 100);
            }
        }
    }

    static void ffplay_audio_num_play(const int num, const std::string &path, const bool async = false) {
        const std::string cmd = "ffplay -autoexit -nodisp " + path;
        LOG(INFO) << "ffplay_audio_num_play cmd :" << cmd;
        if (async) {
            CUtils::async_wait(1, 0, 0, [=] {
                PlayStatus::getInstance().setPlayId(asns::AUDIO_TASK_PLAYING);
                PlayStatus::getInstance().setPlayConten(path.substr(path.find_last_of('/') + 1));
                for (int i = 0; i < num; ++i) {
                    while (CUtils::get_process_status("ffplay")) {
                        usleep(1000 * 100);
                    }
                    if (PlayStatus::getInstance().getPlayId() != asns::AUDIO_TASK_PLAYING) {
                        break;
                    }
                    CUtils::cmd_system(cmd);
                    if (PlayStatus::getInstance().getPlayId() != asns::AUDIO_TASK_PLAYING) {
                        break;
                    }
                }
                PlayStatus::getInstance().init();
            });
        } else {
            PlayStatus::getInstance().setPlayId(asns::AUDIO_TASK_PLAYING);
            PlayStatus::getInstance().setPlayConten(path.substr(path.find_last_of('/') + 1));
            for (int i = 0; i < num; ++i) {
                while (CUtils::get_process_status("ffplay")) {
                    usleep(1000 * 100);
                }
                if (PlayStatus::getInstance().getPlayId() != asns::AUDIO_TASK_PLAYING) {
                    break;
                }
                CUtils::cmd_system(cmd);
                if (PlayStatus::getInstance().getPlayId() != asns::AUDIO_TASK_PLAYING) {
                    break;
                }
            }
            PlayStatus::getInstance().init();
        }
    }
	
    static void ffplay_audio_time_play(const int time, const std::string &path, const bool async = false) {
        const std::string cmd = "ffplay -autoexit -nodisp " + path;
        LOG(INFO) << "ffplay_audio_time_play cmd :" << cmd;
        CUtils::async_wait(1, time, 0, [&] {
            CUtils::cmd_system("killall -9 ffplay");
            PlayStatus::getInstance().init();
        });
        if (async) {
            CUtils::async_wait(1, 0, 0, [=] {
                PlayStatus::getInstance().setPlayId(asns::AUDIO_TASK_PLAYING);
                PlayStatus::getInstance().setPlayConten(path.substr(path.find_last_of('/') + 1));
                while (PlayStatus::getInstance().getPlayId() == asns::AUDIO_TASK_PLAYING) {
                    if (!CUtils::get_process_status("ffplay") &&
                        PlayStatus::getInstance().getPlayId() == asns::AUDIO_TASK_PLAYING) {
                        CUtils::cmd_system(cmd);
                    } else if (PlayStatus::getInstance().getPlayId() != asns::AUDIO_TASK_PLAYING) {
                        break;
                    }
                    usleep(1000 * 100);
                }
            });
        } else {
            PlayStatus::getInstance().setPlayId(asns::AUDIO_TASK_PLAYING);
            PlayStatus::getInstance().setPlayConten(path.substr(path.find_last_of('/') + 1));
            while (PlayStatus::getInstance().getPlayId() == asns::AUDIO_TASK_PLAYING) {
                if (!CUtils::get_process_status("ffplay") &&
                    PlayStatus::getInstance().getPlayId() == asns::AUDIO_TASK_PLAYING) {
                    CUtils::cmd_system(cmd);
                    } else if (PlayStatus::getInstance().getPlayId() != asns::AUDIO_TASK_PLAYING) {
                        break;
                    }
                usleep(1000 * 100);
            }
        }
    }
 
    static void audio_loop_play(const std::string &path, const bool async = false) {
        if (async) {
            CUtils::async_wait(1, 0, 0, [=] {
                std::string cmd = "madplay " + path + " -r";
                PlayStatus::getInstance().setPlayId(asns::AUDIO_TASK_PLAYING);
                PlayStatus::getInstance().setPlayConten(path.substr(path.find_last_of('/') + 1));
                CUtils::cmd_system(cmd);
                PlayStatus::getInstance().init();
            });
        } else {
            std::string cmd = "madplay " + path + " -r";
            PlayStatus::getInstance().setPlayId(asns::AUDIO_TASK_PLAYING);
            PlayStatus::getInstance().setPlayConten(path.substr(path.find_last_of('/') + 1));
            CUtils::cmd_system(cmd);
            PlayStatus::getInstance().init();
        }
    }

    static void audio_num_play(const int num, const std::string &path, const bool async = false) {
        if (async) {
            CUtils::async_wait(1, 0, 0, [=] {
                std::string cmd = "madplay ";
                for (int i = 0; i < num; ++i) {
                    cmd += path + ' ';
                }
                PlayStatus::getInstance().setPlayId(asns::AUDIO_TASK_PLAYING);
                PlayStatus::getInstance().setPlayConten(path.substr(path.find_last_of('/') + 1));
                CUtils::cmd_system(cmd);
                PlayStatus::getInstance().init();
            });
        } else {
            std::string cmd = "madplay ";
            for (int i = 0; i < num; ++i) {
                cmd += path + ' ';
            }
            PlayStatus::getInstance().setPlayId(asns::AUDIO_TASK_PLAYING);
            PlayStatus::getInstance().setPlayConten(path.substr(path.find_last_of('/') + 1));
            CUtils::cmd_system(cmd);
            PlayStatus::getInstance().init();
        }

    }

    static void audio_time_play(const int time, const std::string &path, const bool async = false) {
        int d = time / (3600 * 24);
        int t = time % (3600 * 24) / 3600;
        int m = time % (3600 * 24) % 3600 / 60;
        int s = time % (3600 * 24) % 3600 % 60;
        char buf[64] = {0};
        char cmd[128] = {0};
        sprintf(buf, "%d:%d:%d:%d", d, t, m, s);
        sprintf(cmd, "madplay %s -r -t %s", path.c_str(), buf);
        if (async) {
            CUtils::async_wait(1, 0, 0, [=] {
                PlayStatus::getInstance().setPlayId(asns::AUDIO_TASK_PLAYING);
                PlayStatus::getInstance().setPlayConten(path.substr(path.find_last_of('/') + 1));
                CUtils::cmd_system(cmd);
                PlayStatus::getInstance().init();
            });
        } else {
            PlayStatus::getInstance().setPlayId(asns::AUDIO_TASK_PLAYING);
            PlayStatus::getInstance().setPlayConten(path.substr(path.find_last_of('/') + 1));
            CUtils::cmd_system(cmd);
            PlayStatus::getInstance().init();
        }
    }

    static void audio_stop() {
        PlayStatus::getInstance().init();
        CUtils::cmd_system("killall -9 ffplay");
        CUtils::cmd_system("killall -9 madplay");
    }
};
