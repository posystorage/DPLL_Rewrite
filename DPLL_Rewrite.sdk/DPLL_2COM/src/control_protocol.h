#ifndef CONTROL_PROTOCOL_H
#define CONTROL_PROTOCOL_H

#define CTRL_PROTOCOL_VERSION              3U
#define CTRL_BANK_SIZE                     96U
#define CTRL_PERSIST_BEGIN                 4U
#define CTRL_PERSIST_END                   64U

#define CTRL_MWS_FREQ_MIN_KHZ              23500UL
#define CTRL_MWS_FREQ_MAX_KHZ              6400000UL
#define CTRL_DPLL_OUTPUT_MAX_DHZ            625000000UL
#define CTRL_FAST_INTERVAL_MIN_MS          10U
#define CTRL_FAST_INTERVAL_MAX_MS          34359U

#define CTRL_REG_ID                        0U
#define CTRL_REG_PROTOCOL_VERSION          1U
#define CTRL_REG_REQUEST_SEQ               2U
#define CTRL_REG_CONTROL_FLAGS             3U

#define CTRL_REG_MWS_FREQ_KHZ               4U
#define CTRL_REG_MWS_POWER                  8U
#define CTRL_REG_CENTER_FREQ_DHZ           12U
#define CTRL_REG_OUTPUT_MUL                16U
#define CTRL_REG_OUTPUT_DIV                18U
#define CTRL_REG_KP_TRACK                  20U
#define CTRL_REG_KI_TRACK                  24U
#define CTRL_REG_KF_ACQUIRE                28U
#define CTRL_REG_KF_BLEND                  32U
#define CTRL_REG_POS_LIMIT_HZ              36U
#define CTRL_REG_NEG_LIMIT_HZ              40U
#define CTRL_REG_PHASE_THRESHOLD_CDEG      44U
#define CTRL_REG_DAC_AMPLITUDE_MV          46U
#define CTRL_REG_FREQ_THRESHOLD_HZ         48U
#define CTRL_REG_FAST_INTERVAL_MS          50U

#define CTRL_REG_RESPONSE_SEQ              64U
#define CTRL_REG_DPLL_STATUS               65U
#define CTRL_REG_MWS_STATUS                66U
#define CTRL_REG_LAST_ERROR                67U
#define CTRL_REG_LOOP_STATE                68U
#define CTRL_REG_LOSS_REASON               69U
#define CTRL_REG_BRIDGE_STATUS             70U
#define CTRL_REG_DEBUG_DAC_PRESET           71U
#define CTRL_REG_FREQ_ERROR_HZ             72U
#define CTRL_REG_PHASE_ERROR_CDEG          76U
#define CTRL_REG_OUTPUT_FREQ_HZ            80U
#define CTRL_REG_FAST_METER_HZ             84U
#define CTRL_REG_FAST_METER_SEQ            88U
#define CTRL_REG_ACTIVE_CONFIG_CRC         92U

#define CTRL_FLAG_DPLL_ENABLE              0x01U
#define CTRL_FLAG_MWS_ENABLE               0x02U

#define CTRL_DPLL_STATUS_ENABLED           0x01U
#define CTRL_DPLL_STATUS_LOCKED            0x02U
#define CTRL_DPLL_STATUS_PHASE_OUT         0x04U
#define CTRL_DPLL_STATUS_FREQ_OUT          0x08U
#define CTRL_DPLL_STATUS_POS_RAIL          0x10U
#define CTRL_DPLL_STATUS_NEG_RAIL          0x20U
#define CTRL_DPLL_STATUS_ERROR             0x40U
#define CTRL_DPLL_STATUS_ARM_ONLINE        0x80U

#define CTRL_MWS_STATUS_ENABLED            0x01U
#define CTRL_MWS_STATUS_LOCKED             0x02U

#define CTRL_BRIDGE_STATUS_BUSY            0x01U
#define CTRL_BRIDGE_STATUS_EEPROM_CRC_ERROR 0x02U

#define CTRL_DEBUG_DAC_PRESET_MIN          0U
#define CTRL_DEBUG_DAC_PRESET_MAX          8U
#define CTRL_DEBUG_DAC_PRESET_DEFAULT      1U
#define CTRL_DEBUG_DAC_PRESET_MANUAL       0xFFU

#define CTRL_ERROR_NONE                    0U
#define CTRL_ERROR_PROTOCOL                1U
#define CTRL_ERROR_RANGE                   2U
#define CTRL_ERROR_FPGA_RESET              3U
#define CTRL_ERROR_APPLY                   4U
#define CTRL_ERROR_ABI                     5U

#define CTRL_UART_REQ                      0xB1U
#define CTRL_UART_RESP                     0xB2U
#define CTRL_UART_ETX                      0xB3U
#define CTRL_UART_CMD_READ                 0x01U
#define CTRL_UART_CMD_WRITE                0x02U
#define CTRL_UART_CMD_SAVE                 0x03U
#define CTRL_UART_CMD_PING                 0x04U
#define CTRL_UART_STATUS_OK                0x00U
#define CTRL_UART_STATUS_BAD_FRAME         0x01U
#define CTRL_UART_STATUS_RANGE             0x02U
#define CTRL_UART_STATUS_COMMAND           0x03U

#endif
