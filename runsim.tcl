open_project D:/amd/traffic_light_zynq7020/project/traffic_light/traffic_light.xpr
set_property top tb_top_traffic [get_filesets sim_1]
launch_simulation
run 200us
quit
