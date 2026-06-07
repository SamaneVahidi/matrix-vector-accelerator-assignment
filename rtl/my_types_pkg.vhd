library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package my_types_pkg is
	
    type row_array    		is array (0 to 15) of signed(7 downto 0);
    type Matrix_array    	is array (0 to 15) of row_array;
	type y_array      		is array (0 to 15) of signed(7 downto 0);
	type x_reg_array  		is array (0 to 15) of signed(7 downto 0);
	type state_t 			is (IDLE, STARTED, IS_DONE);

    

end package my_types_pkg;

