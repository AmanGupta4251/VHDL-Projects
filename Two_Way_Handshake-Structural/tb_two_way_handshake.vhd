library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_two_way_handshake is
end tb_two_way_handshake;

architecture behavioral of tb_two_way_handshake is
    signal clk_sender   : STD_LOGIC := '0';
    signal clk_receiver : STD_LOGIC := '0';
    signal reset        : STD_LOGIC := '1';
    signal start        : STD_LOGIC := '0';
    signal data_in      : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal data_out     : STD_LOGIC_VECTOR(7 downto 0);
    signal done         : STD_LOGIC;
    signal busy         : STD_LOGIC;
    signal req          : STD_LOGIC;
    signal ack          : STD_LOGIC;

begin
    clk_sender <= not clk_sender after 5 ns;
    clk_receiver <= not clk_receiver after 7 ns;

    DUT : entity work.two_way_handshake
        port map (
            clk_sender   => clk_sender,
            clk_receiver => clk_receiver,
            reset        => reset,
            start        => start,
            data_in      => data_in,
            data_out     => data_out,
            done         => done,
            busy         => busy,
            req          => req,
            ack          => ack
        );

    stimulus : process
    begin
        reset <= '1';
        wait for 30 ns;

        reset <= '0';
        wait for 20 ns;

        data_in <= x"AA";
        start <= '1';
        wait for 10 ns;
        start <= '0';
        wait for 150 ns;

        data_in <= x"CC";
        start <= '1';
        wait for 10 ns;
        start <= '0';
        wait for 150 ns;

        data_in <= x"F0";
        start <= '1';
        wait for 10 ns;
        start <= '0';
        wait for 200 ns;

        wait;
    end process;

end behavioral;
