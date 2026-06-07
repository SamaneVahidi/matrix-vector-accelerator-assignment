library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.my_types_pkg.all;

entity matrix_vector_core is
generic(
	N          			:   integer := 16;
    acc_width_growth  	:	integer := 4;
    acc_width  		  	:	integer := 16;
    datawidth  		  	:	integer := 8;
	C_S_AXI_DATA_WIDTH 	: 	integer := 128;
    C_S_AXI_ADDR_WIDTH 	: 	integer := 9
);
port(
    clk     : in  std_logic;
    rst_n     : in  std_logic;
	---------------------------
	--AI generated port map--
    -- Write Address Channel 
    s_axi_awaddr    : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    s_axi_awvalid   : in  std_logic;
    s_axi_awready   : out std_logic;
	-- Write data Channel 
    s_axi_wdata     : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    s_axi_wstrb     : in  std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
    s_axi_wvalid    : in  std_logic;
    s_axi_wready    : out std_logic;
	-- Write Response Channel 
    s_axi_bresp     : out std_logic_vector(1 downto 0);
    s_axi_bvalid    : out std_logic;
    s_axi_bready    : in  std_logic;
	-- read Address Channel 
    s_axi_araddr    : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    s_axi_arvalid   : in  std_logic;
    s_axi_arready   : out std_logic;
	-- read data Channel 
    s_axi_rdata     : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    s_axi_rresp     : out std_logic_vector(1 downto 0);
    s_axi_rvalid    : out std_logic;
    s_axi_rready    : in  std_logic 
    
    
    

);
end entity;

architecture rtl of matrix_vector_core is
-- Inter-unit Control/Status Wires
signal start        : std_logic;
signal clr_all      : std_logic;
signal B 		    : std_logic_vector(7 downto 0);
signal loc_matrix_n : std_logic_vector(7 downto 0);

signal loc_busy     : std_logic;
signal loc_debug_s  : std_logic_vector(19 downto 0);
signal row_valid    : std_logic;-- row tracker counter
signal row_count    : integer := 0;-- row tracker counter
signal busy 		: std_logic := '0';
signal done 		: std_logic := '0';
signal core_done    : std_logic;
signal row_index 	: integer := 0;
signal scalar_acc 	: signed(acc_width+acc_width_growth-1 downto 0) := (others=> '0');

signal clr     		: std_logic := '0';
signal en      		: std_logic := '0';
signal w       		: row_array  := (others => (others => '0'));

signal y_readback       : signed(acc_width-1 downto 0) ;
signal j_complete       : std_logic ;
signal calc_done        : std_logic ;

signal Z		   		:  signed(acc_width+acc_width_growth+8-1 downto 0);	
signal tanh_out  		:  signed(15 downto 0);
--configurations
signal matrix_dim_n		:  std_logic_vector(11 downto 0) := x"100";

-- data Channel
signal s_axis_tdata		: std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
signal s_axis_tvalid	: std_logic;
	
-- X vector
signal x : x_reg_array  := (
0 => x"80", -- -128
1 => x"90", -- -112
2 => x"A0", -- -96
3 => x"B0", -- -80
4 => x"C0", -- -64
5 => x"D0", -- -48
6 => x"E0", -- -32
7 => x"F0", -- -16
8 => x"00", -- 0
9 => x"10", -- 16
10 => x"20", -- 32
11 => x"30", -- 48
12 => x"40", -- 64
13 => x"50", -- 80
14 => x"60", -- 96
15 => x"70" -- 112
);

--- Control FSM Status
signal current_state : state_t := IDLE;
signal next_state    : state_t;


 
begin 

--N <= to_integer(unsigned(matrix_dim_n));

-- Unpack the 128-bit AXI-Stream data into arrays of 8-bit signed
unpack_gen: for i in 0 to 15 generate
	w(i) 	<= signed(s_axis_tdata((i*datawidth) + datawidth - 1 downto i*datawidth));
end generate unpack_gen;

row_valid	<=	s_axis_tvalid;


--	Control flow
state_reg_proc: process(clk)
begin
    if rising_edge(clk) then
        if rst_n = '0' then
            current_state <= IDLE;
        elsif clr_all = '1' then
            current_state <= IDLE;
        else
            current_state <= next_state;
        end if;
    end if;
end process;

-- 2. Combinatorial Next-State Logic Process
next_state_logic_proc: process(current_state, start, core_done)
begin
    -- Default assignment to prevent latches
    next_state <= current_state;
    
    case current_state is
        when IDLE =>
            if start = '1' then
                next_state <= STARTED;
            end if;
            
        when STARTED =>
            if core_done = '1' then
                next_state <= IS_DONE;
            end if;
            
        when IS_DONE =>
            -- Automatically go back to IDLE or wait for start to drop
            next_state <= IDLE;
            
        when others =>
            next_state <= IDLE;
    end case;
end process;

process(clk)
begin 
	if rising_edge(clk) then
       if row_valid = '1' then
			en	<= '1'	;
		else
			en  <= '0'	;
		end if;
		
		core_done	<=	done; -- Propagate done because of tanh 1 clk delay
	end if;	
end process;

-- Accumulate row results into scalar s
    accum_proc: process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
				scalar_acc <= (others=> '0');
				row_count  <= 0;
				calc_done  <= '0';
				busy 	   <= '0';
				done 	   <= '0';
            else
				if j_complete = '1' and row_count < N then
					scalar_acc <= scalar_acc + y_readback;--Q1.10.10.
					busy 	   <= '1';
					-- Increment row tracker
                    row_count <= row_count + 1;
					if row_count = N-1 then
						calc_done <= '1';
						busy 	  <= '0';
					end if;
					
				end if;
				-- Scale by coefficient B
				if calc_done = '1' then
                    Z <= scalar_acc * signed(B);--20-bit signed * 8-bit signed => 28-bit signed, Q1.11.17
                end if;
                done <= calc_done; -- Propagate done
				
            end if;
        end if;
    end process;

-- =========================================================================
-- AXI  Block
-- =========================================================================
    inst_axi_reg : entity work.axi_reg
        generic map (
            C_S_AXI_DATA_WIDTH => C_S_AXI_DATA_WIDTH,
            C_S_AXI_ADDR_WIDTH => C_S_AXI_ADDR_WIDTH
        )
        port map (
            S_AXI_ACLK      => clk,
            S_AXI_ARESETN   => rst_n,
            S_AXI_AWADDR    => s_axi_awaddr,
            S_AXI_AWVALID   => s_axi_awvalid,
            S_AXI_AWREADY   => s_axi_awready,
            S_AXI_WDATA     => s_axi_wdata,
			S_AXI_WSTRB		=> s_axi_wstrb,	
            S_AXI_WVALID    => s_axi_wvalid,
            S_AXI_WREADY    => s_axi_wready,
            S_AXI_BRESP     => s_axi_bresp,
            S_AXI_BVALID    => s_axi_bvalid,
            S_AXI_BREADY    => s_axi_bready,
            S_AXI_ARADDR    => s_axi_araddr,
            S_AXI_ARVALID   => s_axi_arvalid,
            S_AXI_ARREADY   => s_axi_arready,
            S_AXI_RDATA     => s_axi_rdata,
            S_AXI_RRESP     => s_axi_rresp,
            S_AXI_RVALID    => s_axi_rvalid,
            S_AXI_RREADY    => s_axi_rready,
            
            -- Inter-unit reading  signals
			a_readback		=> tanh_out,
            -- Inter-unit wiring signals
            ctrl_start      => start,
            ctrl_clear      => clr_all,
            config_b_out    => B,
            matrix_dim_n    => matrix_dim_n,
            status_busy     => busy,
            status_done     => done,
            debug_accum_s   => scalar_acc,
			
			-- data ports (128 bits data width)
			row_data        => s_axis_tdata ,
			row_data_valid  => s_axis_tvalid
        );


-- =========================================================================
-- mac_engine.vhd
-- =========================================================================
inst_mac_engine : entity work.mac_engine
generic map (
    N         		 => 16 ,
    acc_width_growth => 4,
    acc_width  		 => 16,
    datawidth 		 => 8
)
port map (
    clk        => clk,
    rst_n        => rst_n,

    clr        => clr_all,
    en         => en,

    w          => w,
    x          => x,
    y_readback => y_readback,--Q1.0.14.
    j_complete => j_complete
);
-- =========================================================================
-- tanh_approx.vhd
-- =========================================================================
inst_tanh_approx : entity work.tanh_approx
generic map (
    datawidth => 28 --acc_width+acc_width_growth+8
)
port map (
    clk        => clk,

    rst_n        => rst_n,

    data_in    => Z,	
    tanh_out   => tanh_out
);
end rtl;