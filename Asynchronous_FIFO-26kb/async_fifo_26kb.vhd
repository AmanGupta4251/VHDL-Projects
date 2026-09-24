library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity async_fifo_26kb is
    generic (
        DATA_WIDTH : positive := 8;
        DEPTH      : positive := 26624
    );
    port (
        wr_clk  : in  std_logic;
        rd_clk  : in  std_logic;
        reset   : in  std_logic;

        wr_en   : in  std_logic;
        wr_data : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        full    : out std_logic;

        rd_en   : in  std_logic;
        rd_data : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        empty   : out std_logic
    );
end entity async_fifo_26kb;

architecture behavioral of async_fifo_26kb is

    constant PTR_WIDTH : integer := 15;

    type memory_type is array (0 to DEPTH - 1)
        of std_logic_vector(DATA_WIDTH - 1 downto 0);

    signal memory : memory_type := (others => (others => '0'));

    signal wr_ptr : unsigned(PTR_WIDTH - 1 downto 0) := (others => '0');
    signal rd_ptr : unsigned(PTR_WIDTH - 1 downto 0) := (others => '0');

    signal wr_ptr_gray : unsigned(PTR_WIDTH - 1 downto 0) := (others => '0');
    signal rd_ptr_gray : unsigned(PTR_WIDTH - 1 downto 0) := (others => '0');

    signal rd_gray_sync1 : unsigned(PTR_WIDTH - 1 downto 0) := (others => '0');
    signal rd_gray_sync2 : unsigned(PTR_WIDTH - 1 downto 0) := (others => '0');

    signal wr_gray_sync1 : unsigned(PTR_WIDTH - 1 downto 0) := (others => '0');
    signal wr_gray_sync2 : unsigned(PTR_WIDTH - 1 downto 0) := (others => '0');

    signal full_i  : std_logic := '0';
    signal empty_i : std_logic := '1';

    signal rd_data_i : std_logic_vector(DATA_WIDTH - 1 downto 0)
        := (others => '0');

    function binary_to_gray(value : unsigned) return unsigned is
    begin
        return value xor shift_right(value, 1);
    end function;

    function gray_to_binary(value : unsigned) return unsigned is
        variable result : unsigned(value'range);
    begin
        result(result'high) := value(value'high);

        for i in result'high - 1 downto result'low loop
            result(i) := result(i + 1) xor value(i);
        end loop;

        return result;
    end function;

    function pointer_to_address(pointer : unsigned) return integer is
        variable address : integer;
    begin
        address := to_integer(pointer);

        if address >= DEPTH then
            address := address - DEPTH;
        end if;

        return address;
    end function;

begin

    full    <= full_i;
    empty   <= empty_i;
    rd_data <= rd_data_i;

    process(wr_clk)
        variable next_wr_ptr : unsigned(PTR_WIDTH - 1 downto 0);
        variable rd_position : unsigned(PTR_WIDTH - 1 downto 0);
        variable used_space  : unsigned(PTR_WIDTH - 1 downto 0);
    begin
        if rising_edge(wr_clk) then

            if reset = '1' then
                wr_ptr      <= (others => '0');
                wr_ptr_gray <= (others => '0');
                full_i      <= '0';

            else
                next_wr_ptr := wr_ptr;

                if wr_en = '1' and full_i = '0' then
                    memory(pointer_to_address(wr_ptr)) <= wr_data;
                    next_wr_ptr := wr_ptr + 1;
                end if;

                wr_ptr      <= next_wr_ptr;
                wr_ptr_gray <= binary_to_gray(next_wr_ptr);

                rd_position := gray_to_binary(rd_gray_sync2);
                used_space  := next_wr_ptr - rd_position;

                if used_space >= to_unsigned(DEPTH, PTR_WIDTH) then
                    full_i <= '1';
                else
                    full_i <= '0';
                end if;
            end if;

        end if;
    end process;

    process(rd_clk)
        variable next_rd_ptr : unsigned(PTR_WIDTH - 1 downto 0);
        variable wr_position : unsigned(PTR_WIDTH - 1 downto 0);
    begin
        if rising_edge(rd_clk) then

            if reset = '1' then
                rd_ptr      <= (others => '0');
                rd_ptr_gray <= (others => '0');
                rd_data_i   <= (others => '0');
                empty_i     <= '1';

            else
                next_rd_ptr := rd_ptr;

                if rd_en = '1' and empty_i = '0' then
                    rd_data_i <= memory(pointer_to_address(rd_ptr));
                    next_rd_ptr := rd_ptr + 1;
                end if;

                rd_ptr      <= next_rd_ptr;
                rd_ptr_gray <= binary_to_gray(next_rd_ptr);

                wr_position := gray_to_binary(wr_gray_sync2);

                if next_rd_ptr = wr_position then
                    empty_i <= '1';
                else
                    empty_i <= '0';
                end if;
            end if;

        end if;
    end process;

    process(wr_clk)
    begin
        if rising_edge(wr_clk) then
            if reset = '1' then
                rd_gray_sync1 <= (others => '0');
                rd_gray_sync2 <= (others => '0');
            else
                rd_gray_sync1 <= rd_ptr_gray;
                rd_gray_sync2 <= rd_gray_sync1;
            end if;
        end if;
    end process;

    process(rd_clk)
    begin
        if rising_edge(rd_clk) then
            if reset = '1' then
                wr_gray_sync1 <= (others => '0');
                wr_gray_sync2 <= (others => '0');
            else
                wr_gray_sync1 <= wr_ptr_gray;
                wr_gray_sync2 <= wr_gray_sync1;
            end if;
        end if;
    end process;

end architecture behavioral;
