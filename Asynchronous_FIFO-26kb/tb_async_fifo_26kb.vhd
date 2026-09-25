library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_async_fifo_26kb is
end entity tb_async_fifo_26kb;

architecture behavioral of tb_async_fifo_26kb is

    constant DATA_WIDTH : integer := 8;
    constant DEPTH      : integer := 26624;

    signal wr_clk : std_logic := '0';
    signal rd_clk : std_logic := '0';

    signal reset : std_logic := '1';

    signal wr_en   : std_logic := '0';
    signal wr_data : std_logic_vector(DATA_WIDTH - 1 downto 0)
        := (others => '0');
    signal full : std_logic;

    signal rd_en   : std_logic := '0';
    signal rd_data : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal empty : std_logic;

begin

    dut : entity work.async_fifo_26kb
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            DEPTH      => DEPTH
        )
        port map (
            wr_clk  => wr_clk,
            rd_clk  => rd_clk,
            reset   => reset,
            wr_en   => wr_en,
            wr_data => wr_data,
            full    => full,
            rd_en   => rd_en,
            rd_data => rd_data,
            empty   => empty
        );

    write_clock : process
    begin
        loop
            wr_clk <= '0';
            wait for 5 ns;

            wr_clk <= '1';
            wait for 5 ns;
        end loop;
    end process write_clock;

    read_clock : process
    begin
        loop
            rd_clk <= '0';
            wait for 7.5 ns;

            rd_clk <= '1';
            wait for 7.5 ns;
        end loop;
    end process read_clock;

    stimulus : process
    begin

        reset <= '1';
        wr_en <= '0';
        rd_en <= '0';

        wait for 50 ns;

        reset <= '0';

        -- First write sequence
        wait until rising_edge(wr_clk);
        wr_en   <= '1';
        wr_data <= x"11";

        wait until rising_edge(wr_clk);
        wr_data <= x"22";

        wait until rising_edge(wr_clk);
        wr_data <= x"33";

        wait until rising_edge(wr_clk);
        wr_data <= x"44";

        wait until rising_edge(wr_clk);
        wr_en <= '0';

        -- Allow the write pointer to reach the read clock domain.
        wait for 100 ns;

        -- First read sequence
        rd_en <= '1';

        wait until rising_edge(rd_clk);
        wait for 1 ns;

        assert rd_data = x"11"
            report "ERROR: Expected 11"
            severity error;

        wait until rising_edge(rd_clk);
        wait for 1 ns;

        assert rd_data = x"22"
            report "ERROR: Expected 22"
            severity error;

        wait until rising_edge(rd_clk);
        wait for 1 ns;

        assert rd_data = x"33"
            report "ERROR: Expected 33"
            severity error;

        wait until rising_edge(rd_clk);
        wait for 1 ns;

        assert rd_data = x"44"
            report "ERROR: Expected 44"
            severity error;

        rd_en <= '0';

        -- Allow the empty indication to propagate back.
        wait for 100 ns;

        assert empty = '1'
            report "ERROR: FIFO should be EMPTY"
            severity error;

        -- Second write sequence
        wait until rising_edge(wr_clk);
        wr_en   <= '1';
        wr_data <= x"A5";

        wait until rising_edge(wr_clk);
        wr_data <= x"5A";

        wait until rising_edge(wr_clk);
        wr_en <= '0';

        -- Allow the write pointer to reach the read clock domain.
        wait for 100 ns;

        -- Second read sequence
        rd_en <= '1';

        wait until rising_edge(rd_clk);
        wait for 1 ns;

        assert rd_data = x"A5"
            report "ERROR: Expected A5"
            severity error;

        wait until rising_edge(rd_clk);
        wait for 1 ns;

        assert rd_data = x"5A"
            report "ERROR: Expected 5A"
            severity error;

        rd_en <= '0';

        wait for 50 ns;

        report "26 KB asynchronous FIFO simulation completed successfully."
            severity note;

        stop;

        wait;
    end process stimulus;

end architecture behavioral;
