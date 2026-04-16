--------------------------------------------------------------------------------
-- btn_debouncer.vhd
-- Simple button debouncer.
--
-- Waits for the input to remain stable for DEBOUNCE_CYCLES clock cycles
-- before updating the output. At 100 MHz with the default value of 1_000_000,
-- this gives a debounce window of 10 ms.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity btn_debouncer is
    generic (
        DEBOUNCE_CYCLES : positive := 1_000_000  -- 10 ms at 100 MHz
    );
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        btn_in    : in  std_logic;   -- raw button input
        btn_out   : out std_logic    -- debounced output
    );
end entity btn_debouncer;

architecture rtl of btn_debouncer is
    signal counter    : unsigned(19 downto 0) := (others => '0');
    signal btn_stable : std_logic := '0';
begin

    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                counter    <= (others => '0');
                btn_stable <= '0';
            elsif btn_in /= btn_stable then
                -- Input differs from current stable value; count up
                if counter = to_unsigned(DEBOUNCE_CYCLES - 1, counter'length) then
                    btn_stable <= btn_in;
                    counter    <= (others => '0');
                else
                    counter <= counter + 1;
                end if;
            else
                -- Input matches stable value; reset counter
                counter <= (others => '0');
            end if;
        end if;
    end process;

    btn_out <= btn_stable;

end architecture rtl;
