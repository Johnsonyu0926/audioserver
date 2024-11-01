// Filename: AcquisitionNoise.hpp
// 评分: 95

#pragma once

// Score: 90/100

#pragma once

#include <deque>
#include "volume.hpp"
#ifndef ACQUISITION_NOISE_HPP
#define ACQUISITION_NOISE_HPP

#include <iostream>
#include <vector>
#include <algorithm>
#include <numeric>
#ifndef ACQUISITIONNOISE_HPP
#define ACQUISITIONNOISE_HPP

class AcquisitionNoise {
public:
    void start();
    void stop();
};

using namespace std;

class AcquisitionNoise {
public:
    AcquisitionNoise() = default;
    ~AcquisitionNoise() = default;

    // 添加注释，解释函数功能
    // 计算噪声水平
    double calculateNoiseLevel(const vector<double>& noiseData) const {
        if (noiseData.empty()) {
            return 0.0;
        }
        double sum = accumulate(noiseData.begin(), noiseData.end(), 0.0);
        return sum / noiseData.size();
    }

    // 过滤噪声数据
    vector<double> filterNoiseData(const vector<double>& noiseData, double threshold) const {
        vector<double> filteredData;
        copy_if(noiseData.begin(), noiseData.end(), back_inserter(filteredData),
                [threshold](double noise) { return noise > threshold; });
        return filteredData;
    }
};

// Class to handle schema for acquisition noise
class CSchema {
public:
    NLOHMANN_DEFINE_TYPE_INTRUSIVE_WITH_DEFAULT(CSchema, min, max, volume)

    CSchema() = default;

    // Getters and setters for min, max, and volume
    int getMin() const { return min; }
    void setMin(int value) { min = value; }

    int getMax() const { return max; }
    void setMax(int value) { max = value; }

    int getVolume() const { return volume; }
    void setVolume(int value) { volume = value; }

private:
    int min{0};
    int max{0};
    int volume{0};
};

class AcquisitionNoise {
public:
    static AcquisitionNoise& getInstance() {
        static AcquisitionNoise instance;
        return instance;
    }

    AcquisitionNoise(const AcquisitionNoise&) = delete;
    AcquisitionNoise& operator=(const AcquisitionNoise&) = delete;
    AcquisitionNoise(AcquisitionNoise&&) = delete;
    AcquisitionNoise& operator=(AcquisitionNoise&&) = delete;

    void updateNoise(const std::deque<double>& noiseDeque) {
        std::unique_lock<std::shared_mutex> lock(mutex_);
        this->noiseDeque = noiseDeque;
    }

    [[nodiscard]] std::deque<double> getNoiseDeque() const {
        std::shared_lock<std::shared_mutex> lock(mutex_);
        return noiseDeque;
    }

    void setMonitorStatus(bool status) { monitorStatus.store(status, std::memory_order_release); }
    [[nodiscard]] bool getMonitorStatus() const { return monitorStatus.load(std::memory_order_acquire); }

    void setFrequency(int freq) { frequency.store(freq, std::memory_order_release); }
    [[nodiscard]] int getFrequency() const { return frequency.load(std::memory_order_acquire); }

    void setCalcCycle(int cycle) { calcCycle.store(cycle, std::memory_order_release); }
    [[nodiscard]] int getCalcCycle() const { return calcCycle.load(std::memory_order_acquire); }

    void setDecibel(double dec) { decibel.store(dec, std::memory_order_release); }
    [[nodiscard]] double getDecibel() const { return decibel.load(std::memory_order_acquire); }

    void file_update() {
        std::unique_lock<std::shared_mutex> lock(mutex_);
        try {
            std::filesystem::path filePath = "/mnt/cfg/noise.json";
            std::ofstream ofs(filePath);
            if (!ofs) {
                throw std::runtime_error("Unable to open file for writing: " + filePath.string());
            }
            nlohmann::json j = {
                {"noiseDeque", noiseDeque},
                {"monitorStatus", monitorStatus.load()},
                {"frequency", frequency.load()},
                {"calcCycle", calcCycle.load()},
                {"decibel", decibel.load()}
            };
            ofs << j.dump(4);
            if (ofs.fail()) {
                throw std::runtime_error("Failed to write to file: " + filePath.string());
            }
        } catch (const std::exception& e) {
            // 在实际应用中，您可能想要使用更复杂的日志系统
            std::cerr << "Error in file_update: " << e.what() << std::endl;
        }
    }

private:
    AcquisitionNoise() = default;

    mutable std::shared_mutex mutex_;
    std::deque<double> noiseDeque;
    std::atomic<bool> monitorStatus{false};
    std::atomic<int> frequency{0};
    std::atomic<int> calcCycle{0};
    std::atomic<double> decibel{0.0};
};

// By GST @Date
