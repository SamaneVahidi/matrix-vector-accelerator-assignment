library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
---- AI-generated base module; customized for target architecture.
entity pl_memory_gateway is
    generic (
        AXI_DATA_WIDTH : integer := 128; -- one row of W matrix(16 * 8 bits)
        AXI_ADDR_WIDTH : integer := 9    -- Allows up to 512 bytes of address space(256 bytes W matrix, B coefficient, control signals and...)
    );
    port (
        -- Global Clock and Reset
        S_AXI_ACLK     : in  std_logic;
        S_AXI_ARESETN  : in  std_logic;
        
        -- Write Address Channel (Full AXI4 subset for single transfers)
        S_AXI_AWADDR   : in  std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_AWVALID  : in  std_logic;
        S_AXI_AWREADY  : out std_logic;
        
        -- Write Data Channel
        S_AXI_WDATA    : in  std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
        S_AXI_WSTRB    : in  std_logic_vector((AXI_DATA_WIDTH/8)-1 downto 0);
        S_AXI_WVALID   : in  std_logic;
        S_AXI_WREADY   : out std_logic;
        
        -- Write Response Channel
        S_AXI_BRESP    : out std_logic_vector(1 downto 0);
        S_AXI_BVALID   : out std_logic;
        S_AXI_BREADY   : in  std_logic;
        
        -- Export Interfaces to Accelerator Core
        config_b_out   : out std_logic_vector(7 downto 0);
        ctrl_start     : out std_logic;
        ctrl_clear     : out std_logic;
        
        -- Matrix W Parallel Routing
        we_matrix_row  : out std_logic_vector(15 downto 0);
        w_row_data     : out std_logic_vector(127 downto 0)
    );
end entity pl_memory_gateway;

architecture rtl of pl_memory_gateway is

    signal axi_awready : std_logic := '0';
    signal axi_wready  : std_logic := '0';
    signal axi_bvalid  : std_logic := '0';
    
    signal reg_coeff_b  : std_logic_vector(7 downto 0) := (others => '0');
    signal reg_ctrl     : std_logic_vector(31 downto 0) := (others => '0');

begin

    S_AXI_BRESP   <= "00"; -- OKAY response
    S_AXI_AWREADY <= axi_awready;
    S_AXI_WREADY  <= axi_wready;
    S_AXI_BVALID  <= axi_bvalid;
    
    config_b_out <= reg_coeff_b;
    ctrl_start   <= reg_ctrl(0);
    ctrl_clear   <= reg_ctrl(1);

    -- AXI4 Handshaking Process
    process(S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_awready <= '0';
                axi_wready  <= '0';
                axi_bvalid  <= '0';
            else
                axi_awready <= '1';
                axi_wready  <= '1';

                if (axi_awready = '1' and S_AXI_AWVALID = '1' and axi_wready = '1' and S_AXI_WVALID = '1') then
                    axi_bvalid <= '1';
                elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then
                    axi_bvalid <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Memory Map Register Decoding Logic
    process(S_AXI_ACLK)
        variable loc_addr : integer;
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                reg_coeff_b   <= (others => '0');
                reg_ctrl      <= (others => '0');
                we_matrix_row <= (others => '0');
                w_row_data    <= (others => '0');
            else
                we_matrix_row <= (others => '0');
                
                if (axi_awready = '1' and S_AXI_AWVALID = '1' and axi_wready = '1' and S_AXI_WVALID = '1') then
                    -- Because data width is 128 bits (16 bytes), we drop the lower 4 address bits
                    -- (bits 3 downto 0) to get the clean register index step.
                    loc_addr := to_integer(unsigned(S_AXI_AWADDR(AXI_ADDR_WIDTH-1 downto 4)));
                    
                    case loc_addr is
                        when 0 => -- Register 0 (Address 0x00): Config Block
                            reg_coeff_b <= S_AXI_WDATA(7 downto 0);   -- Lower byte holds B
                            reg_ctrl    <= S_AXI_WDATA(63 downto 32); -- Middle word holds control
                            
                        when 2 to 17 => -- Registers 2 to 17 (Addresses 0x20 to 0x110)
                            -- Write the full 128-bit block into the selected W matrix row at once
                            we_matrix_row(loc_addr - 2) <= '1';
                            w_row_data                  <= S_AXI_WDATA;
                            
                        when others =>
                            null;
                    end case;
                end if;
            end if;
        end if;
    end process;

end architecture rtl;