library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tanh_approx is
generic(
    datawidth  : integer := 28
);
port(
    clk     : in  std_logic;
    rst_n     : in  std_logic;


    data_in    : in signed(datawidth-1 downto 0); --Q1.10.18 (27 downto 0)17:0 fraction, 27:18 integer
    tanh_out   : out signed(15 downto 0)
);
end entity;

architecture rtl of tanh_approx is
	signal tanh_val : signed(15 downto 0);
-- Tanh LUT Type (Quantized representation mapping input values to an 16-bit signed fractional output)
    type tanh_lut_t is array (0 to 15) of signed(15 downto 0);
    -- Approximate mapping example for positive magnitudes (Symmetric curve handling done in process)
    constant TANH_LUT : tanh_lut_t := (
			 0  =>  x"0000", -- 0.00
             1  =>  x"1F59", -- 0.25
             2  =>  x"3B26", -- 0.50
             3  =>  x"514C", -- 0.75
             4  =>  x"617B", -- 1.00
             5  =>  x"6C94", -- 1.25
             6  =>  x"73DB", -- 1.50
             7  =>  x"787F", -- 1.75
             8  =>  x"7B65", -- 2.00
             9  =>  x"7D2F", -- 2.25
             10 =>  x"7E49", -- 2.50
             11 =>  x"7EF6", -- 2.75
             12 =>  x"7F5E", -- 3.00
             13 =>  x"7F9F", -- 3.25
             14 =>  x"7FC5", -- 3.50
             15 =>  x"7FDC" -- 3.75
    );
begin

 tanh_proc: process(data_in)
    variable z_integer : signed(9 downto 0);
    variable lut_index : integer range 0 to 15;
begin
    -- Extract the whole integer portion (bits 27 down to 18)
    z_integer := data_in(datawidth-1 downto 18);
    
    -- Extract the 4 highest fractional bits right after the binary point (bits 19 down to 16)
    -- taking the absolute value handles symmetric negative curves seamlessly
    lut_index := to_integer(unsigned(abs(data_in(19 downto 16))));

    -- Threshold check based on real-world saturation value of 4.0
    if z_integer >= 4 then
        -- Positive Saturation: Force to +1.0 in Q1.15 format
        tanh_out <= x"7fff";
        
    elsif z_integer <= -4 then
        -- Negative Saturation: Force to -1.0 in Q1.15 format
        tanh_out <= x"ffff";
        
    else
        -- Symmetric lookup for values between -4.0 and 4.0
        if data_in < 0 then
            tanh_out <= (-TANH_LUT(lut_index));
        else
            tanh_out <= (TANH_LUT(lut_index));
        end if;
    end if;
end process;
 
        
	
end rtl;