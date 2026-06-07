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

    
end architecture rtl;
