#pragma once

#include "json.hpp"
#include "AcquisitionNoise.hpp"

namespace asns {
    class CVolumeAdaptSchemaData {
    public:
        NLOHMANN_DEFINE_TYPE_INTRUSIVE_WITH_DEFAULT(CVolumeAdaptSchemaData, monitorStatus, frequency, calcCycle,
                                                    schema)

        void set_data() const {
            AcquisitionNoise::getInstance().setMonitorStatus(monitorStatus);
            AcquisitionNoise::getInstance().setFrequency(frequency);
            AcquisitionNoise::getInstance().setCalcCycle(calcCycle);
			if (calcCycle < static_cast<int>(AcquisitionNoise::getInstance().noiseDeque.size())) {
			    const size_t n = AcquisitionNoise::getInstance().noiseDeque.size() - calcCycle;
			    for(size_t i = 0; i < n; ++i) {
			        AcquisitionNoise::getInstance().noiseDeque.pop_back();
			    }
			}
            AcquisitionNoise::getInstance().schema.assign(schema.cbegin(), schema.cend());
            AcquisitionNoise::getInstance().file_update();
        }

        void do_data() {
            monitorStatus = AcquisitionNoise::getInstance().getMonitorStatus();
            frequency = AcquisitionNoise::getInstance().getFrequency();
            calcCycle = AcquisitionNoise::getInstance().getCalcCycle();
            schema.assign(AcquisitionNoise::getInstance().schema.cbegin(),
                          AcquisitionNoise::getInstance().schema.cend());
        }

    public:
        int monitorStatus{};
        int frequency{};
        int calcCycle{};
        std::vector<CSchema> schema;
    };
}
