library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- this module is developed by use of AI (google gemini)
entity axi_reg is
    generic (
        C_S_AXI_DATA_WIDTH : integer := 128;
        C_S_AXI_ADDR_WIDTH : integer := 9 -- Allows up to 512 bytes of address space
    );
    port (
        -- AXI Global Clock and Reset
        S_AXI_ACLK    : in  std_logic;
        S_AXI_ARESETN : in  std_logic;
        
        -- AXI Write Address Channel
        S_AXI_AWADDR  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_AWVALID : in  std_logic;
        S_AXI_AWREADY : out std_logic;
        
        -- AXI Write Data Channel
        S_AXI_WDATA   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_WSTRB   : in  std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
        S_AXI_WVALID  : in  std_logic;
        S_AXI_WREADY  : out std_logic;
        
        -- AXI Write Response Channel
        S_AXI_BRESP   : out std_logic_vector(1 downto 0);
        S_AXI_BVALID  : out std_logic;
        S_AXI_BREADY  : in  std_logic;
		
		 -- AXI Read Address & Data
        S_AXI_ARADDR    : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_ARVALID   : in  std_logic;
        S_AXI_ARREADY   : out std_logic;
        S_AXI_RDATA     : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_RRESP     : out std_logic_vector(1 downto 0);
        S_AXI_RVALID    : out std_logic;
        S_AXI_RREADY    : in  std_logic;
        --
		a_readback		: in signed(15 downto 0);
        -- Configuration and control
        config_b_out  : out std_logic_vector(7 downto 0);
        ctrl_start    : out std_logic;
        ctrl_clear    : out std_logic;
        matrix_dim_n  : out std_logic_vector(11 downto 0);
        status_busy   : in  std_logic;
        status_done   : in  std_logic;
        debug_accum_s : in  signed(19 downto 0);
			
		-- Current updated row lines for Matrix W
        row_data_valid  : out std_logic;
        row_data    	: out std_logic_vector(127 downto 0)
    );
end entity axi_reg;

architecture rtl of axi_reg is

    -- Internal AXI Handshaking Signals
    signal axi_awready : std_logic := '0';
    signal axi_wready  : std_logic := '0';
    signal axi_bvalid  : std_logic := '0';
    
    -- Internal Configuration Registers
    signal reg_coeff_b  : std_logic_vector(7 downto 0) := (others => '0');
    signal reg_ctrl     : std_logic_vector(31 downto 0) := (others => '0');
    
    -- 128-bit temporary assembly buffer for receiving 32-bit AXI words
    signal row_assemble : std_logic_vector(127 downto 0) := (others => '0');
	
	signal we_matrix_row : std_logic_vector(15 downto 0);
	
	signal axi_arready : std_logic;
	signal axi_rvalid  : std_logic;
	signal axi_rdata   : std_logic_vector(C_S_AXI_DATA_WIDTH downto 0);
	signal constant_zero   : std_logic_vector(95 downto 0):= (others => '0');

begin

    -- Tie off AXI write response to OKAY (00)
    S_AXI_BRESP  <= "00";
    
    -- Assign Ready Signals to Output Ports
    S_AXI_AWREADY <= axi_awready;
    S_AXI_WREADY  <= axi_wready;
    S_AXI_BVALID  <= axi_bvalid;
	
	-- Assign internal signals to output ports
    S_AXI_ARREADY <= axi_arready;
    S_AXI_RVALID  <= axi_rvalid;
    S_AXI_RDATA   <= axi_rdata;
    S_AXI_RRESP   <= "00"; -- Always return 'OKAY' response
    
    -- Drive parallel lines outward
    config_b_out <= reg_coeff_b;
    ctrl_start   <= reg_ctrl(0);
    ctrl_clear   <= reg_ctrl(1);

    -- 1. AXI Write Handshaking Protocol Control
    process(S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_awready <= '0';
                axi_wready  <= '0';
                axi_bvalid  <= '0';
            else
                -- Manage Address Ready
               axi_awready <= '1';
                axi_wready <= '1';
                

                -- Manage Write Response Valid
                if (axi_awready = '1' and S_AXI_AWVALID = '1' and axi_wready = '1' and S_AXI_WVALID = '1') then
                    axi_bvalid <= '1';
                elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then
                    axi_bvalid <= '0';
                end if;
            end if;
        end if;
    end process;

    --  Memory-Mapped Register 
    process(S_AXI_ACLK)
        variable loc_addr : integer;
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                reg_coeff_b   <= (others => '0');
                reg_ctrl      <= (others => '0');
                we_matrix_row <= (others => '0');
                row_data    <= (others => '0');
            else
                -- Default strobe line suppression
                we_matrix_row <= (others => '0');
                row_data_valid			<= '0'	;
                -- Execute register write when handshakes align
                if (axi_awready = '1' and S_AXI_AWVALID = '1' and axi_wready = '1' and S_AXI_WVALID = '1') then
                    -- Drop the lower 2 bits because AXI-Lite addresses are byte-aligned (multiples of 4)
                    loc_addr := to_integer(unsigned(S_AXI_AWADDR(C_S_AXI_ADDR_WIDTH-1 downto 4)));
                    
                    case loc_addr is
                        when 0 => -- Register 0 (Address 0x00): Config Block
                            reg_coeff_b <= S_AXI_WDATA(7 downto 0);   -- Lower byte holds B
                            reg_ctrl    <= S_AXI_WDATA(63 downto 32); -- Middle word holds control
                            
                        when 2 to 17 => -- Registers 2 to 17 (Addresses 0x20 to 0x110)
                            -- Write the full 128-bit block into the selected W matrix row at once
                            we_matrix_row(loc_addr - 2) <= '1';
                            row_data                  <= S_AXI_WDATA;
							row_data_valid			<= '1'	;
                            
                        when others =>
                            null;
                    end case;
                end if;
            end if;
        end if;
    end process;
------------------------------------------READ channel------------------------------------------------	
----- read channel handshaking
	read_handshake_proc : process(S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_arready <= '0';
                axi_rvalid  <= '0';
            else
                axi_arready <= '1';
                if (axi_arready = '1' and S_AXI_ARVALID = '1' and axi_rvalid = '0') then
                    axi_rvalid <= '1';
                elsif (axi_rvalid = '1' and S_AXI_RREADY = '1') then
                    axi_rvalid <= '0'; -- Master read the data, drop valid
                end if;
            end if;
        end if;
    end process;
	
	-- Process: Multiplex internal signals onto the Read Data Bus
    reg_readback_proc : process(S_AXI_ACLK)
        variable addr_idx : integer;
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_rdata <= (others => '0');
            -- Capture data when the master initiates a valid read address cycle
            elsif (S_AXI_ARVALID = '1') then
                
                -- Convert the upper address bits to an integer index
                -- (Assuming standard byte address sizing, trimming the lower 2 bits for 32-bit alignment)
                addr_idx := to_integer(unsigned(S_AXI_ARADDR(C_S_AXI_ADDR_WIDTH-1 downto 4)));
                
                case addr_idx is
                    
                    when 18 => -- address space of a=tanh(z)
						axi_rdata <= constant_zero&x"00" & std_logic_vector(a_readback);
                    when others =>
                        axi_rdata <= (others => '0');
                end case;
            end if;
        end if;
    end process;

end architecture rtl;
