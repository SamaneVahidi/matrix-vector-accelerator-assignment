library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.my_types_pkg.all;

entity tb_matrix_vector_core is
end entity tb_matrix_vector_core;

architecture sim of tb_matrix_vector_core is

    -- Constant Parameters Matching Your 128-bit Architecture
    constant CLK_PERIOD         : time := 10 ns;
    constant C_S_AXI_DATA_WIDTH : integer := 128;
    constant C_S_AXI_ADDR_WIDTH : integer := 10;--address space of 1024 bytes

    -- Component Signals
    signal clk           : std_logic := '0';
    signal rst_n         : std_logic := '0';
    
    -- AXI Write Address Channel
    signal s_axi_awaddr  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0) := (others => '0');
    signal s_axi_awvalid : std_logic := '0';
    signal s_axi_awready : std_logic;
    
    -- AXI Write Data Channel
    signal s_axi_wdata   : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0) := (others => '0');
    signal s_axi_wstrb   : std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0) := (others => '0');
    signal s_axi_wvalid  : std_logic := '0';
    signal s_axi_wready  : std_logic;
	
    
    -- AXI Write Response Channel
    signal s_axi_bresp   : std_logic_vector(1 downto 0);
    signal s_axi_bvalid  : std_logic;
    signal s_axi_bready  : std_logic := '0';
    -- AXI Read Channel
    signal s_axi_araddr  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0) := (others => '0');
    signal s_axi_arvalid : std_logic := '0';
    signal s_axi_arready : std_logic;
    signal s_axi_rdata   : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal s_axi_rresp   : std_logic_vector(1 downto 0);
    signal s_axi_rvalid  : std_logic;
    signal s_axi_rready  : std_logic := '1';

   

    -- Custom Procedure to handle a 128-bit AXI Write Transaction
    procedure axi_write_128(
        constant addr : in  integer;
        constant data : in  std_logic_vector(127 downto 0);
        signal clk_s  : in  std_logic;
        signal awaddr : out std_logic_vector;
        signal awval  : out std_logic;
        signal awrdy  : in  std_logic;
        signal wdata  : out std_logic_vector(127 downto 0);
        signal wval   : out std_logic;
        signal wrdy   : in  std_logic;
        signal bready : out std_logic;
        signal bvalid : in  std_logic
    ) is
    begin
        wait until rising_edge(clk_s);
        awaddr <= std_logic_vector(to_unsigned(addr, awaddr'length));
        wdata  <= data;
        awval  <= '1';
        wval   <= '1';
        bready <= '1';

     
        loop
            wait until rising_edge(clk_s);
            if awrdy = '1' then awval <= '0'; end if;
            if wrdy = '1'  then wval  <= '0'; end if;
            if bvalid = '1' then exit; end if;
        end loop;
        
        bready <= '0';
        wait for 40 ns;
    end procedure;
--
type Matrix_array2 is array (0 to 15, 0 to 15) of std_logic_vector(7 downto 0);

constant W : Matrix_array2 := (
    (x"80", x"81", x"82", x"83", x"84", x"85", x"86", x"87", x"88", x"89", x"8A", x"8B", x"8C", x"8D", x"8E", x"8F"),
    (x"90", x"91", x"92", x"93", x"94", x"95", x"96", x"97", x"98", x"99", x"9A", x"9B", x"9C", x"9D", x"9E", x"9F"),
    (x"A0", x"A1", x"A2", x"A3", x"A4", x"A5", x"A6", x"A7", x"A8", x"A9", x"AA", x"AB", x"AC", x"AD", x"AE", x"AF"),
    (x"B0", x"B1", x"B2", x"B3", x"B4", x"B5", x"B6", x"B7", x"B8", x"B9", x"BA", x"BB", x"BC", x"BD", x"BE", x"BF"),
    (x"C0", x"C1", x"C2", x"C3", x"C4", x"C5", x"C6", x"C7", x"C8", x"C9", x"CA", x"CB", x"CC", x"CD", x"CE", x"CF"),
    (x"D0", x"D1", x"D2", x"D3", x"D4", x"D5", x"D6", x"D7", x"D8", x"D9", x"DA", x"DB", x"DC", x"DD", x"DE", x"DF"),
    (x"E0", x"E1", x"E2", x"E3", x"E4", x"E5", x"E6", x"E7", x"E8", x"E9", x"EA", x"EB", x"EC", x"ED", x"EE", x"EF"),
    (x"F0", x"F1", x"F2", x"F3", x"F4", x"F5", x"F6", x"F7", x"F8", x"F9", x"FA", x"FB", x"FC", x"FD", x"FE", x"FF"),
    (x"00", x"01", x"02", x"03", x"04", x"05", x"06", x"07", x"08", x"09", x"0A", x"0B", x"0C", x"0D", x"0E", x"0F"),
    (x"10", x"11", x"12", x"13", x"14", x"15", x"16", x"17", x"18", x"19", x"1A", x"1B", x"1C", x"1D", x"1E", x"1F"),
    (x"20", x"21", x"22", x"23", x"24", x"25", x"26", x"27", x"28", x"29", x"2A", x"2B", x"2C", x"2D", x"2E", x"2F"),
    (x"30", x"31", x"32", x"33", x"34", x"35", x"36", x"37", x"38", x"39", x"3A", x"3B", x"3C", x"3D", x"3E", x"3F"),
    (x"40", x"41", x"42", x"43", x"44", x"45", x"46", x"47", x"48", x"49", x"4A", x"4B", x"4C", x"4D", x"4E", x"4F"),
    (x"50", x"51", x"52", x"53", x"54", x"55", x"56", x"57", x"58", x"59", x"5A", x"5B", x"5C", x"5D", x"5E", x"5F"),
    (x"60", x"61", x"62", x"63", x"64", x"65", x"66", x"67", x"68", x"69", x"6A", x"6B", x"6C", x"6D", x"6E", x"6F"),
    (x"70", x"71", x"72", x"73", x"74", x"75", x"76", x"77", x"78", x"79", x"7A", x"7B", x"7C", x"7D", x"7E", x"7F")
);


	
begin

    -- Clock = 100 MHz
    clk <= not clk after CLK_PERIOD / 2;

    -- Instantiate UUT
    uut: entity work.matrix_vector_core
        generic map (
            C_S_AXI_DATA_WIDTH => C_S_AXI_DATA_WIDTH,
            C_S_AXI_ADDR_WIDTH => C_S_AXI_ADDR_WIDTH
        )
        port map (
            clk           => clk,
            rst_n         => rst_n,
            s_axi_awaddr  => s_axi_awaddr,
            s_axi_awvalid => s_axi_awvalid,
            s_axi_awready => s_axi_awready,
            s_axi_wdata   => s_axi_wdata,
            s_axi_wstrb   => s_axi_wstrb,
            s_axi_wvalid  => s_axi_wvalid,
            s_axi_wready  => s_axi_wready,
            s_axi_bresp   => s_axi_bresp,
            s_axi_bvalid  => s_axi_bvalid,
            s_axi_bready  => s_axi_bready,
            s_axi_araddr  => s_axi_araddr,
            s_axi_arvalid => s_axi_arvalid,
            s_axi_arready => s_axi_arready,
            s_axi_rdata   => s_axi_rdata,
            s_axi_rresp   => s_axi_rresp,
            s_axi_rvalid  => s_axi_rvalid,
            s_axi_rready  => s_axi_rready
        );

    -- Main Simulation Vector Generation Sequence
    stim_proc: process
        variable temp_row : std_logic_vector(127 downto 0);
    begin
        -- 1. System Reset Initialization
        rst_n <= '0';
        wait for 40 ns;
        rst_n <= '1';
        wait for 20 ns;

        -- 2. Write Config Register (Address x"00) to pass Coefficient B
        temp_row := (others => '0');
        temp_row(7 downto 0) := x"40"; 
        report "Configuring Coefficient B...";
        axi_write_128(0, temp_row, clk, s_axi_awaddr, s_axi_awvalid, s_axi_awready, 
                      s_axi_wdata, s_axi_wvalid, s_axi_wready, s_axi_bready, s_axi_bvalid);

        -- 3. Assert the Start Strobe via the Control Register (Address x"00", Bit 32)
        temp_row := (others => '0');
        temp_row(7 downto 0)  := x"40"; -- Keep B intact
        temp_row(32)          := '1';   -- Set Start Bit high
        
        report "Pulsing Start Bit...";
        axi_write_128(0, temp_row, clk, s_axi_awaddr, s_axi_awvalid, s_axi_awready, 
                      s_axi_wdata, s_axi_wvalid, s_axi_wready, s_axi_bready, s_axi_bvalid);

        -- Clear the start bit immediately after execution to make it a clean pulse
        temp_row(32)          := '0';
        axi_write_128(0, temp_row, clk, s_axi_awaddr, s_axi_awvalid, s_axi_awready, 
                      s_axi_wdata, s_axi_wvalid, s_axi_wready, s_axi_bready, s_axi_bvalid);
					  
		 wait for 20 ns;
        -- 4. We write 16 distinct rows sequentially into addresses x"20 through x"110
        report "Starting AXI Configuration: Loading 16 Matrix Rows...";
        for row in 0 to 15 loop
            -- Create a test pattern for each row (e.g., replicate the row index across all 16 bytes)
            for col_idx in 0 to 15 loop
                -- Slices data bits: Col 0 goes to bits 7:0, Col 1 goes to bits 15:8, etc.
                temp_row((col_idx * 8) + 7 downto (col_idx * 8)) := W(row, col_idx);
            end loop;
            
            -- Memory mapped address calculation: Base x"20" + (Row Index * 16 bytes)
            axi_write_128(32 + (row * 16), temp_row, clk, s_axi_awaddr, s_axi_awvalid, s_axi_awready, 
                          s_axi_wdata, s_axi_wvalid, s_axi_wready, s_axi_bready, s_axi_bvalid);
        end loop;
        report "Weight Matrix W loading complete.";
		-- 5. Monitor and Await Computation Completion
        
        wait for 500 ns; 

        report "Simulation Complete. Check wave traces for verification.";
        wait;
    end process;

end architecture sim;