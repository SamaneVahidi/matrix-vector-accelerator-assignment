library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.my_types_pkg.all;

entity mac_engine is
generic(
    N          :integer := 16;
    acc_width_growth  :integer := 4;--ceil(log2(N))
    acc_width  : integer := 16;
    datawidth  : integer := 8
);
port(
    clk     : in  std_logic;
    rst_n     : in  std_logic;

    clr     : in  std_logic;
    en      : in  std_logic;

    w       : in  row_array;
    x       : in  x_reg_array;

    y_readback  : out signed(acc_width-1 downto 0);
    j_complete  : out std_logic
);
end entity;

architecture rtl of mac_engine is

type T_N_Datawidth    is array (0 to N-1) of signed((datawidth*2)-1 downto 0);

signal row_acc      : signed((datawidth*2)+acc_width_growth-1 downto 0); 
signal product      : T_N_Datawidth;
signal row_acc_done : std_logic := '0';

 
begin

process(clk)
begin
    if rising_edge(clk) then
        if rst_n='0' then
            row_acc  <= (others=>'0');
        elsif clr='1' then
            row_acc  <= (others=>'0');
        elsif en='1' then
			--Q1.4.14
            row_acc <= resize(product(0), row_acc'length)  + resize(product(1), row_acc'length) +
					   resize(product(2), row_acc'length)  + resize(product(3), row_acc'length) +
					   resize(product(4), row_acc'length)  + resize(product(5), row_acc'length) +
					   resize(product(6), row_acc'length)  + resize(product(7), row_acc'length) +
					   resize(product(8), row_acc'length)  + resize(product(9), row_acc'length) +
					   resize(product(10), row_acc'length) + resize(product(11), row_acc'length) +
					   resize(product(12), row_acc'length) + resize(product(13), row_acc'length) +
					   resize(product(14), row_acc'length) + resize(product(15), row_acc'length);
        end if;
    end if;
end process;

process(clk)
begin
    if rising_edge(clk) then
	--propagation valid
        row_acc_done  <= en;
    end if;
end process;

multiply_gen: for i in 0 to N-1 generate
    product(i) <= w(i) * x(i);--Q1.0.14.
end generate multiply_gen;
------------outputs-----------
-- ŷᵢ = saturate(yᵢ), 16-bit signed numbers are between 2^16-1(32767) and -2^16(-32768),...--Q1.6.10
y_readback  <= to_signed(32767, acc_width)  when (row_acc > 32767)  else
			   to_signed(-32768, acc_width) when (row_acc < -32768) else row_acc((datawidth*2)+acc_width_growth-1 downto 4);

j_complete  <= row_acc_done;


end rtl; 