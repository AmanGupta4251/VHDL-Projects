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

    --------------------------------------------------------------------
    -- 26 KB = 26,624 bytes
    --
    -- DATA_WIDTH = 8 bits
    -- DEPTH      = 26,624 locations
    --
    -- A 15-bit pointer gives us a circular pointer range of:
    --
    -- 0 to 32767
    --
    -- This pointer space is intentionally larger than the memory.
    -- The memory address is generated separately by taking the pointer
    -- modulo DEPTH.
    --------------------------------------------------------------------

    constant PTR_WIDTH : integer := 15;

    --------------------------------------------------------------------
    -- Memory
    --------------------------------------------------------------------

    type memory_type is array (
        0 to DEPTH - 1
    ) of std_logic_vector(DATA_WIDTH - 1 downto 0);

    signal memory : memory_type :=
        (others => (others => '0'));

    --------------------------------------------------------------------
    -- Binary pointers
    --------------------------------------------------------------------

    signal wr_ptr : unsigned(PTR_WIDTH - 1 downto 0)
        := (others => '0');

    signal rd_ptr : unsigned(PTR_WIDTH - 1 downto 0)
        := (others => '0');

    --------------------------------------------------------------------
    -- Gray-coded pointers
    --
    -- These are used for safe clock-domain crossing.
    --------------------------------------------------------------------

    signal wr_ptr_gray : unsigned(PTR_WIDTH - 1 downto 0)
        := (others => '0');

    signal rd_ptr_gray : unsigned(PTR_WIDTH - 1 downto 0)
        := (others => '0');

    --------------------------------------------------------------------
    -- Read pointer synchronized into WRITE clock domain
    --------------------------------------------------------------------

    signal rd_gray_sync1 : unsigned(PTR_WIDTH - 1 downto 0)
        := (others => '0');

    signal rd_gray_sync2 : unsigned(PTR_WIDTH - 1 downto 0)
        := (others => '0');

    --------------------------------------------------------------------
    -- Write pointer synchronized into READ clock domain
    --------------------------------------------------------------------

    signal wr_gray_sync1 : unsigned(PTR_WIDTH - 1 downto 0)
        := (others => '0');

    signal wr_gray_sync2 : unsigned(PTR_WIDTH - 1 downto 0)
        := (others => '0');

    --------------------------------------------------------------------
    -- FIFO status
    --------------------------------------------------------------------

    signal full_i : std_logic := '0';

    signal empty_i : std_logic := '1';

    --------------------------------------------------------------------
    -- Read data register
    --------------------------------------------------------------------

    signal rd_data_i : std_logic_vector(DATA_WIDTH - 1 downto 0)
        := (others => '0');


    --------------------------------------------------------------------
    -- Binary to Gray conversion
    --------------------------------------------------------------------

    function binary_to_gray(
        binary_value : unsigned
    ) return unsigned is
    begin
        return binary_value xor
               shift_right(binary_value, 1);
    end function;


    --------------------------------------------------------------------
    -- Gray to Binary conversion
    --------------------------------------------------------------------

    function gray_to_binary(
        gray_value : unsigned
    ) return unsigned is

        variable binary_value :
            unsigned(gray_value'range);

    begin

        binary_value(binary_value'high) :=
            gray_value(gray_value'high);

        for i in binary_value'high - 1 downto binary_value'low loop

            binary_value(i) :=
                binary_value(i + 1) xor gray_value(i);

        end loop;

        return binary_value;

    end function;


    --------------------------------------------------------------------
    -- Convert FIFO pointer to actual SRAM address.
    --
    -- The pointer has a range of 0 to 32767.
    -- The memory has a range of 0 to 26623.
    --
    -- Therefore:
    --
    -- pointer 0      -> address 0
    -- pointer 1      -> address 1
    -- ...
    -- pointer 26623  -> address 26623
    -- pointer 26624  -> address 0
    --
    --------------------------------------------------------------------

    function pointer_to_address(
        pointer : unsigned
    ) return integer is

        variable pointer_value : integer;

    begin

        pointer_value := to_integer(pointer);

        if pointer_value >= DEPTH then
            pointer_value := pointer_value - DEPTH;
        end if;

        return pointer_value;

    end function;


begin

    --------------------------------------------------------------------
    -- Output assignments
    --------------------------------------------------------------------

    full    <= full_i;
    empty   <= empty_i;
    rd_data <= rd_data_i;


    --------------------------------------------------------------------
    -- WRITE CLOCK DOMAIN
    --
    -- This process:
    --
    -- 1. Checks wr_en
    -- 2. Checks full
    -- 3. Writes data into memory
    -- 4. Advances write pointer
    -- 5. Generates Gray-coded write pointer
    -- 6. Updates full flag
    --------------------------------------------------------------------

    write_process : process(wr_clk)

        variable next_wr_ptr :
            unsigned(PTR_WIDTH - 1 downto 0);

        variable synchronized_rd_ptr :
            unsigned(PTR_WIDTH - 1 downto 0);

        variable fifo_count :
            unsigned(PTR_WIDTH - 1 downto 0);

    begin

        if rising_edge(wr_clk) then

            if reset = '1' then

                wr_ptr  <= (others => '0');
                wr_ptr_gray <= (others => '0');

                full_i <= '0';

            else

                ----------------------------------------------------------------
                -- Start with the current write pointer.
                ----------------------------------------------------------------

                next_wr_ptr := wr_ptr;

                ----------------------------------------------------------------
                -- Perform write only when:
                --
                -- wr_en = 1
                -- full  = 0
                ----------------------------------------------------------------

                if wr_en = '1' and full_i = '0' then

                    memory(pointer_to_address(wr_ptr))
                        <= wr_data;

                    next_wr_ptr :=
                        wr_ptr + 1;

                end if;


                ----------------------------------------------------------------
                -- Update write pointer.
                ----------------------------------------------------------------

                wr_ptr <= next_wr_ptr;

                wr_ptr_gray <=
                    binary_to_gray(next_wr_ptr);


                ----------------------------------------------------------------
                -- Convert synchronized read pointer back to binary.
                ----------------------------------------------------------------

                synchronized_rd_ptr :=
                    gray_to_binary(rd_gray_sync2);


                ----------------------------------------------------------------
                -- Calculate current FIFO occupancy.
                --
                -- Because the pointer is unsigned and 15 bits wide,
                -- subtraction naturally works around the 32768-pointer
                -- circular boundary.
                ----------------------------------------------------------------

                fifo_count :=
                    next_wr_ptr - synchronized_rd_ptr;


                ----------------------------------------------------------------
                -- Full condition.
                --
                -- FIFO contains 26,624 bytes.
                ----------------------------------------------------------------

                if fifo_count >=
                    to_unsigned(DEPTH, PTR_WIDTH) then

                    full_i <= '1';

                else

                    full_i <= '0';

                end if;

            end if;

        end if;

    end process write_process;


    --------------------------------------------------------------------
    -- READ CLOCK DOMAIN
    --
    -- This process:
    --
    -- 1. Checks rd_en
    -- 2. Checks empty
    -- 3. Reads memory
    -- 4. Advances read pointer
    -- 5. Generates Gray-coded read pointer
    -- 6. Updates empty flag
    --------------------------------------------------------------------

    read_process : process(rd_clk)

        variable next_rd_ptr :
            unsigned(PTR_WIDTH - 1 downto 0);

        variable synchronized_wr_ptr :
            unsigned(PTR_WIDTH - 1 downto 0);

    begin

        if rising_edge(rd_clk) then

            if reset = '1' then

                rd_ptr  <= (others => '0');
                rd_ptr_gray <= (others => '0');

                rd_data_i <=
                    (others => '0');

                empty_i <= '1';

            else

                ----------------------------------------------------------------
                -- Start with the current read pointer.
                ----------------------------------------------------------------

                next_rd_ptr := rd_ptr;


                ----------------------------------------------------------------
                -- Perform read only when:
                --
                -- rd_en = 1
                -- empty = 0
                ----------------------------------------------------------------

                if rd_en = '1' and empty_i = '0' then

                    rd_data_i <=
                        memory(pointer_to_address(rd_ptr));

                    next_rd_ptr :=
                        rd_ptr + 1;

                end if;


                ----------------------------------------------------------------
                -- Update read pointer.
                ----------------------------------------------------------------

                rd_ptr <= next_rd_ptr;

                rd_ptr_gray <=
                    binary_to_gray(next_rd_ptr);


                ----------------------------------------------------------------
                -- Convert synchronized write pointer to binary.
                ----------------------------------------------------------------

                synchronized_wr_ptr :=
                    gray_to_binary(wr_gray_sync2);


                ----------------------------------------------------------------
                -- Empty condition.
                ----------------------------------------------------------------

                if next_rd_ptr =
                    synchronized_wr_ptr then

                    empty_i <= '1';

                else

                    empty_i <= '0';

                end if;

            end if;

        end if;

    end process read_process;


    --------------------------------------------------------------------
    -- READ POINTER SYNCHRONIZER
    --
    -- Transfers the read pointer from rd_clk domain to wr_clk domain.
    --------------------------------------------------------------------

    read_pointer_synchronizer : process(wr_clk)

    begin

        if rising_edge(wr_clk) then

            if reset = '1' then

                rd_gray_sync1 <=
                    (others => '0');

                rd_gray_sync2 <=
                    (others => '0');

            else

                rd_gray_sync1 <=
                    rd_ptr_gray;

                rd_gray_sync2 <=
                    rd_gray_sync1;

            end if;

        end if;

    end process read_pointer_synchronizer;


    --------------------------------------------------------------------
    -- WRITE POINTER SYNCHRONIZER
    --
    -- Transfers the write pointer from wr_clk domain to rd_clk domain.
    --------------------------------------------------------------------

    write_pointer_synchronizer : process(rd_clk)

    begin

        if rising_edge(rd_clk) then

            if reset = '1' then

                wr_gray_sync1 <=
                    (others => '0');

                wr_gray_sync2 <=
                    (others => '0');

            else

                wr_gray_sync1 <=
                    wr_ptr_gray;

                wr_gray_sync2 <=
                    wr_gray_sync1;

            end if;

        end if;

    end process write_pointer_synchronizer;


end architecture behavioral;
