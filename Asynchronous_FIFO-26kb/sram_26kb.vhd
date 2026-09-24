library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sram_26kb is
    generic (
        DATA_WIDTH : positive := 8;
        DEPTH      : positive := 26624
    );
    port (
        clk        : in  std_logic;
        write_en   : in  std_logic;
        write_addr : in  integer range 0 to DEPTH - 1;
        write_data : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        read_addr  : in  integer range 0 to DEPTH - 1;
        read_data  : out std_logic_vector(DATA_WIDTH - 1 downto 0)
    );
end entity sram_26kb;

architecture behavioral of sram_26kb is

    type memory_type is array (0 to DEPTH - 1)
        of std_logic_vector(DATA_WIDTH - 1 downto 0);

    signal memory : memory_type := (others => (others => '0'));

begin

    process(clk)
    begin
        if rising_edge(clk) then

            if write_en = '1' then
                memory(write_addr) <= write_data;
            end if;

            read_data <= memory(read_addr);
        end if;
    end process;

end architecture behavioral;
