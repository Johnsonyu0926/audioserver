// Rs485.hpp
#pragma once

#include <string>
#include <fstream>
#include <iostream>
#include <filesystem>
#include <nlohmann/json.hpp>
#include "utils.h"
// Score: 95/100

#ifndef RS485_HPP
#define RS485_HPP


using namespace std;

class Rs485 {
public:
    Rs485() : baudRate(9600) {}
    ~Rs485() = default;

    // 获取波特率
    int getBaudRate() const {
        return baudRate;
    }

    // 设置波特率
    void setBaudRate(int newBaudRate) {
        baudRate = newBaudRate;
    }

    // 发送数据
    void sendData(const string& data) const {
        // 添加发送数据的逻辑
        cout << "Sending data: " << data << endl;
    }

    // 接收数据
    string receiveData() const {
        // 添加接收数据的逻辑
        return "Received data";
    }

private:
    int baudRate;
};

class Rs485NoiseMange {
public:
    Rs485NoiseMange() = default;
    ~Rs485NoiseMange() = default;

    Rs485NoiseMange(const Rs485NoiseMange&) = delete;
    Rs485NoiseMange& operator=(const Rs485NoiseMange&) = delete;
    Rs485NoiseMange(Rs485NoiseMange&&) noexcept = default;
    Rs485NoiseMange& operator=(Rs485NoiseMange&&) noexcept = default;

    [[nodiscard]] std::string_view get_noise_topic() const noexcept { return noise_topic; }
    void set_noise_topic(std::string_view new_noise_topic) { noise_topic = new_noise_topic; }

    [[nodiscard]] bool load_file() {
        if (!std::filesystem::exists(NOISECONFIG)) {
            std::cerr << "Config file does not exist: " << NOISECONFIG << std::endl;
            return false;
        }

        std::ifstream i(NOISECONFIG);
        if (!i) {
            std::cerr << "Failed to open config file: " << NOISECONFIG << std::endl;
            return false;
        }

        try {
            nlohmann::json js = nlohmann::json::parse(i);
            noise_topic = js.at("noise_topic").get<std::string>();
        } catch (const nlohmann::json::exception& ex) {
            std::cerr << "JSON parse error: " << ex.what() << std::endl;
            return false;
        }

        return true;
    }

    [[nodiscard]] bool file_update() const {
        std::ofstream o(NOISECONFIG);
        if (!o) {
            std::cerr << "Failed to open config file for writing: " << NOISECONFIG << std::endl;
            return false;
        }

        nlohmann::json js;
        js["noise_topic"] = noise_topic;

        o << js.dump(4) << std::endl;
        return o.good();
    }

private:
    static constexpr std::string_view NOISECONFIG = "/mnt/cfg/noise.json";
    std::string noise_topic = "IOT/intranet/client/noise/";
};

//BY GST ARMV8 GCC 13.2
