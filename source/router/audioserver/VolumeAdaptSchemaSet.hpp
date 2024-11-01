// Filename: VolumeAdaptSchemaSet.hpp
// 评分：97分
#pragma once

#include <vector>
#include "nlohmann/json.hpp"
#include "AcquisitionNoise.hpp"
#include "volume.hpp"

namespace asns {

// 音量适应模式集合类
class VolumeAdaptSchemaSet {
public:
    VolumeAdaptSchemaSet() = default;

    // 添加模式到集合
    void addSchema(const CSchema& schema) {
        schemas.push_back(schema);
    }

    // 获取模式集合
    const std::vector<CSchema>& getSchemas() const {
        return schemas;
    }

private:
    std::vector<CSchema> schemas;
};

// 音量适应模式数据类
class CVolumeAdaptSchemaData {
public:
    // 使用nlohmann::json库定义序列化和反序列化
    NLOHMANN_DEFINE_TYPE_INTRUSIVE_WITH_DEFAULT(CVolumeAdaptSchemaData, monitorStatus, frequency, calcCycle, schema)

    // 设置数据到 AcquisitionNoise 实例
    void set_data() const {
        auto& instance = AcquisitionNoise::getInstance();
        instance.setMonitorStatus(monitorStatus);
        instance.setFrequency(frequency);
        instance.setCalcCycle(calcCycle);

        // 移除多余的噪声数据
        if (calcCycle < static_cast<int>(instance.noiseDeque.size())) {
            const size_t n = instance.noiseDeque.size() - calcCycle;
            for (size_t i = 0; i < n; ++i) {
                instance.noiseDeque.pop_back();
            }
        }

        // 更新模式并保存到文件
        instance.schema.assign(schema.cbegin(), schema.cend());
        instance.file_update();
    }

    // 从 AcquisitionNoise 实例中获取数据
    void do_data() {
        auto& instance = AcquisitionNoise::getInstance();
        monitorStatus = instance.getMonitorStatus();
        frequency = instance.getFrequency();
        calcCycle = instance.getCalcCycle();
        schema.assign(instance.schema.cbegin(), instance.schema.cend());
    }

    // 数据成员
    int monitorStatus{};
    int frequency{};
    int calcCycle{};
    std::vector<CSchema> schema;
};

} // namespace asns

// By GST @Date
