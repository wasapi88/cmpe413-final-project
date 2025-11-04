exec xvhdl and2.vhd inverter.vhd selector.vhd dff.vhd Dlatch.vhd tx.vhd mux4to1.vhd cacheCell.vhd cache.vhd cache_array.vhd tag_valid.vhd cache_fsm.vhd cache_top.vhd cache_top_test.vhd
exec xelab cache_top_test -debug typical -s sim_out
exec xsim sim_out -gui
