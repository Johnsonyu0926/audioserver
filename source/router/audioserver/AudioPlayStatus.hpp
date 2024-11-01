// audioplaystatus.hpp
// Score: 95/100

#pragma once

#include <string>
#include <atomic>
#include "public.hpp"


#ifndef AUDIO_PLAY_STATUS_HPP
#define AUDIO_PLAY_STATUS_HPP

#include <iostream>
#include <string>
#ifndef AUDIOPLAYSTATUS_HPP
#define AUDIOPLAYSTATUS_HPP

class AudioPlayStatus {
public:
    void play();
    void pause();
    void stop();
};
using namespace std;

class AudioPlayStatus {
public:
    AudioPlayStatus() : status("stopped") {}
    ~AudioPlayStatus() = default;

    // 获取播放状态
    string getStatus() const {
        return status;
    }

    // 设置播放状态
    void setStatus(const string& newStatus) {
        status = newStatus;
    }

private:
    string status;
};

class PlayStatus {
public:
    static PlayStatus& getInstance() {
        static PlayStatus instance;
        return instance;
    }

    PlayStatus(const PlayStatus&) = delete;
    PlayStatus& operator=(const PlayStatus&) = delete;
    PlayStatus(PlayStatus&&) = delete;
    PlayStatus& operator=(PlayStatus&&) = delete;

    void init() {
        m_mqttPlayStatus.store(asns::STOP_TASK_PLAYING);
        m_playId.store(asns::STOP_TASK_PLAYING);
        m_priority.store(asns::STOP_TASK_PLAYING);
        m_pId.store(asns::STOP_TASK_PLAYING);
        playContent.clear();
    }

    [[nodiscard]] bool getPlayState() const { return m_playId.load() != asns::STOP_TASK_PLAYING; }
    [[nodiscard]] int getPlayId() const { return m_playId.load(); }
    void setPlayId(int id) { m_playId.store(id); }
    [[nodiscard]] int getPriority() const { return m_priority.load(); }
    void setPriority(int id) { m_priority.store(id); }
    [[nodiscard]] pid_t getProcessId() const { return m_pId.load(); }
    void setProcessId(pid_t id) { m_pId.store(id); }
    [[nodiscard]] std::string getPlayContent() const { return playContent; }
    void setPlayContent(std::string content) { playContent = std::move(content); }
    [[nodiscard]] int getMqttPlayStatus() const { return m_mqttPlayStatus.load(); }
    void setMqttPlayStatus(int status) { m_mqttPlayStatus.store(status); }

private:
    PlayStatus() = default;

    std::atomic<int> m_mqttPlayStatus{asns::STOP_TASK_PLAYING};
    std::atomic<int> m_playId{asns::STOP_TASK_PLAYING};
    std::atomic<int> m_priority{asns::STOP_TASK_PLAYING};
    std::atomic<pid_t> m_pId{asns::STOP_TASK_PLAYING};
    std::string playContent;
};

//By GST ARMV8 GCC13.2 audioplaystatus.hpp
