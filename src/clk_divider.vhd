--------------------------------------------------------------------------------
-- clk_divider.vhd
-- Clock-enable generator for SPI master
-- Produces a one-cycle-wide enable pulse at the desired SPI bit rate.
--
-- 100 MHz system clock -->  slow_mode (400 kHz) for SD init
--                      -->  fast_mode (25 MHz)  for data transfer
--
-- The enable pulses are used by the SPI master to advance its shift register;
-- the actual SCLK pin is toggled by the SPI master itself.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clk_divider is
    generic (
        SYS_CLK_HZ  : integer := 100_000_000;  -- system clock frequency
        SLOW_CLK_HZ : integer := 400_000;       -- init-phase SPI clock
        FAST_CLK_HZ : integer := 25_000_000     -- data-phase SPI clock
    );
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;              -- active-high synchronous reset
        fast_mode : in  std_logic;              -- '0' = slow, '1' = fast
        clk_en    : out std_logic               -- one-cycle pulse at SPI rate
    );
end entity clk_divider;

architecture rtl of clk_divider is

    -- Divider values (half-period counts because SPI toggles SCLK every half)
    -- We generate a pulse every (SYS / (2 * SPI)) cycles so the SPI master
    -- can toggle SCLK on each pulse, yielding the correct frequency.
    constant SLOW_DIV : integer := (SYS_CLK_HZ / (2 * SLOW_CLK_HZ)) - 1;
    constant FAST_DIV : integer := (SYS_CLK_HZ / (2 * FAST_CLK_HZ)) - 1;

    signal counter  : unsigned(15 downto 0) := (others => '0');
    signal div_val  : unsigned(15 downto 0);

begin

    div_val <= to_unsigned(FAST_DIV, 16) when fast_mode = '1'
               else to_unsigned(SLOW_DIV, 16);

    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                counter <= (others => '0');
                clk_en  <= '0';
            elsif counter >= div_val then
                counter <= (others => '0');
                clk_en  <= '1';
            else
                counter <= counter + 1;
                clk_en  <= '0';
            end if;
        end if;
    end process;

end architecture rtl;
