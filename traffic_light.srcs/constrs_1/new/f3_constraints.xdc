# ============================================================
# 约束文件: 米联客 MLK-F3-CZ02-7020 交通灯实验
# 依据: MLK_F3_CZ02开发板硬件使用手册 + MLK_F3_230217 原理图
#       (P13_LED&KEY, P15_PLCLK_100M)
# 注意: 本板无数码管; PL 时钟为 100MHz; LED 低电平点亮
# ============================================================

# ---------- 1. PL 时钟 100MHz (BANK35, 固定3.3V) ----------
set_property -dict {PACKAGE_PIN H16 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 10.000 -name pl_clk [get_ports clk]

# ---------- 2. 按键 (BANK34, VCC_ADJ1 默认3.3V, 按下为低) ----------
# KEY4 = R19 (B34_L0)  行人过街请求
set_property -dict {PACKAGE_PIN R19 IOSTANDARD LVCMOS33} [get_ports key_ped]
# KEY5 = T19 (B34_L25) 设置键: 短按切换配置目标, 长按每次+1秒
set_property -dict {PACKAGE_PIN T19 IOSTANDARD LVCMOS33} [get_ports key_set]

# ---------- 3. LED (BANK35, 低电平点亮) ----------
# led[0] = LED1 H15  红灯
set_property -dict {PACKAGE_PIN H15 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
# led[1] = LED2 G15  黄灯
set_property -dict {PACKAGE_PIN G15 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
# led[2] = LED3 K16  绿灯
set_property -dict {PACKAGE_PIN K16 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
# led[3] = LED4 J16  倒计时二进制 bit0 (LSB)
set_property -dict {PACKAGE_PIN J16 IOSTANDARD LVCMOS33} [get_ports {led[3]}]
# led[4] = LED6 J15  倒计时二进制 bit1
set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports {led[4]}]
# led[5] = LED7 G14  倒计时二进制 bit2
set_property -dict {PACKAGE_PIN G14 IOSTANDARD LVCMOS33} [get_ports {led[5]}]
# led[6] = LED8 K14  倒计时二进制 bit3 (MSB)
set_property -dict {PACKAGE_PIN K14 IOSTANDARD LVCMOS33} [get_ports {led[6]}]

# ---------- 4. BIT 文件压缩 ----------
set_property BITSTREAM.GENERAL.COMPRESS true [current_design]
