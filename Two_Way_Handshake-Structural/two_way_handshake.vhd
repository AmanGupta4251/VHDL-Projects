library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity dff is
    port (
        clk : in  STD_LOGIC;
        rst : in  STD_LOGIC;
        d   : in  STD_LOGIC;
        q   : out STD_LOGIC
    );
end dff;

architecture rtl of dff is
begin
    process(clk, rst)
    begin
        if rst = '1' then
            q <= '0';
        elsif rising_edge(clk) then
            q <= d;
        end if;
    end process;
end rtl;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity sender is
    port (
        clk      : in  STD_LOGIC;
        rst      : in  STD_LOGIC;
        start    : in  STD_LOGIC;
        data_in  : in  STD_LOGIC_VECTOR(7 downto 0);
        ack_sync : in  STD_LOGIC;
        data_reg : out STD_LOGIC_VECTOR(7 downto 0);
        req      : out STD_LOGIC;
        busy     : out STD_LOGIC
    );
end sender;

architecture rtl of sender is
    type state_type is (IDLE, WAIT_ACK);
    signal state   : state_type;
    signal req_reg : STD_LOGIC;
begin

    req <= req_reg;

    process(clk, rst)
    begin
        if rst = '1' then
            state    <= IDLE;
            req_reg  <= '0';
            busy     <= '0';
            data_reg <= (others => '0');
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    busy <= '0';

                    if start = '1' then
                        data_reg <= data_in;
                        req_reg  <= not req_reg;
                        busy     <= '1';
                        state    <= WAIT_ACK;
                    end if;

                when WAIT_ACK =>
                    busy <= '1';

                    if ack_sync = req_reg then
                        busy  <= '0';
                        state <= IDLE;
                    end if;
            end case;
        end if;
    end process;

end rtl;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity receiver is
    port (
        clk      : in  STD_LOGIC;
        rst      : in  STD_LOGIC;
        req_sync : in  STD_LOGIC;
        data_in  : in  STD_LOGIC_VECTOR(7 downto 0);
        data_out : out STD_LOGIC_VECTOR(7 downto 0);
        ack      : out STD_LOGIC;
        done     : out STD_LOGIC
    );
end receiver;

architecture rtl of receiver is
    signal ack_reg : STD_LOGIC;
begin

    ack <= ack_reg;

    process(clk, rst)
    begin
        if rst = '1' then
            ack_reg  <= '0';
            done     <= '0';
            data_out <= (others => '0');
        elsif rising_edge(clk) then
            done <= '0';

            if req_sync /= ack_reg then
                data_out <= data_in;
                ack_reg  <= req_sync;
                done     <= '1';
            end if;
        end if;
    end process;

end rtl;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity synchronizer is
    port (
        clk  : in  STD_LOGIC;
        rst  : in  STD_LOGIC;
        din  : in  STD_LOGIC;
        dout : out STD_LOGIC
    );
end synchronizer;

architecture structural of synchronizer is
    signal q1 : STD_LOGIC;
begin

    FF1 : entity work.dff
        port map (
            clk => clk,
            rst => rst,
            d   => din,
            q   => q1
        );

    FF2 : entity work.dff
        port map (
            clk => clk,
            rst => rst,
            d   => q1,
            q   => dout
        );

end structural;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity two_way_handshake is
    port (
        clk_sender   : in  STD_LOGIC;
        clk_receiver : in  STD_LOGIC;
        reset        : in  STD_LOGIC;
        start        : in  STD_LOGIC;
        data_in      : in  STD_LOGIC_VECTOR(7 downto 0);
        data_out     : out STD_LOGIC_VECTOR(7 downto 0);
        done         : out STD_LOGIC;
        busy         : out STD_LOGIC;
        req          : out STD_LOGIC;
        ack          : out STD_LOGIC
    );
end two_way_handshake;

architecture structural of two_way_handshake is
    signal req_internal : STD_LOGIC;
    signal ack_internal : STD_LOGIC;
    signal req_sync     : STD_LOGIC;
    signal ack_sync     : STD_LOGIC;
    signal data_sender  : STD_LOGIC_VECTOR(7 downto 0);
begin

    SENDER_INST : entity work.sender
        port map (
            clk      => clk_sender,
            rst      => reset,
            start    => start,
            data_in  => data_in,
            ack_sync => ack_sync,
            data_reg => data_sender,
            req      => req_internal,
            busy     => busy
        );

    REQ_SYNC_INST : entity work.synchronizer
        port map (
            clk  => clk_receiver,
            rst  => reset,
            din  => req_internal,
            dout => req_sync
        );

    RECEIVER_INST : entity work.receiver
        port map (
            clk      => clk_receiver,
            rst      => reset,
            req_sync => req_sync,
            data_in  => data_sender,
            data_out => data_out,
            ack      => ack_internal,
            done     => done
        );

    ACK_SYNC_INST : entity work.synchronizer
        port map (
            clk  => clk_sender,
            rst  => reset,
            din  => ack_internal,
            dout => ack_sync
        );

    req <= req_internal;
    ack <= ack_internal;

end structural;
