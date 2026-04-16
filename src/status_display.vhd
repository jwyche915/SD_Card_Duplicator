--------------------------------------------------------------------------------
-- status_display.vhd
-- Maps duplicator FSM state and progress to the Nexys Video's 8 LEDs.
--
-- LED mapping:
--   LED[0]   : Heartbeat (blinks when system is running)
--   LED[1]   : Source card initialized
--   LED[2]   : Destination card initialized
--   LED[3]   : Copying in progress (blinks during copy)
--   LED[7:4] : Progress bar (4-bit, lights up proportionally to completion)
--
-- Error indication: All LEDs flash rapidly on error.
-- Done indication:  All LEDs solid on.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity status_display is
    generic (
        SYS_CLK_HZ : integer := 100_000_000
    );
    port (
        clk           : in  std_logic;
        reset         : in  std_logic;

        -- Duplicator status
        fsm_idle      : in  std_logic;
        fsm_copying   : in  std_logic;
        fsm_done      : in  std_logic;
        fsm_error     : in  std_logic;
        src_init_done : in  std_logic;
        dst_init_done : in  std_logic;
        current_block : in  std_logic_vector(31 downto 0);
        total_blocks  : in  std_logic_vector(31 downto 0);

        -- LED output
        led           : out std_logic_vector(7 downto 0)
    );
end entity status_display;

architecture rtl of status_display is

    -- ~1 Hz heartbeat and ~4 Hz error flash
    constant HEARTBEAT_DIV : integer := SYS_CLK_HZ / 2;
    constant ERROR_DIV     : integer := SYS_CLK_HZ / 8;

    signal hb_counter  : unsigned(26 downto 0) := (others => '0');
    signal heartbeat   : std_logic := '0';

    signal err_counter : unsigned(24 downto 0) := (others => '0');
    signal err_flash   : std_logic := '0';

    -- Progress calculation (4-bit bar)
    signal progress_bar : std_logic_vector(3 downto 0) := (others => '0');

begin

    -- Heartbeat generator (~1 Hz toggle)
    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                hb_counter <= (others => '0');
                heartbeat  <= '0';
            elsif hb_counter >= to_unsigned(HEARTBEAT_DIV, 27) then
                hb_counter <= (others => '0');
                heartbeat  <= not heartbeat;
            else
                hb_counter <= hb_counter + 1;
            end if;
        end if;
    end process;

    -- Error flash generator (~4 Hz toggle)
    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                err_counter <= (others => '0');
                err_flash   <= '0';
            elsif err_counter >= to_unsigned(ERROR_DIV, 25) then
                err_counter <= (others => '0');
                err_flash   <= not err_flash;
            else
                err_counter <= err_counter + 1;
            end if;
        end if;
    end process;

    -- Progress bar: map current_block / total_blocks to 4-bit thermometer
    process (clk)
        variable ratio : unsigned(3 downto 0);
        variable cur   : unsigned(31 downto 0);
        variable tot   : unsigned(31 downto 0);
    begin
        if rising_edge(clk) then
            cur := unsigned(current_block);
            tot := unsigned(total_blocks);

            if tot = 0 then
                progress_bar <= "0000";
            else
                -- Simple approximation: shift both down so ratio fits
                -- progress = (current * 16) / total, capped at 15
                -- Use upper bits to avoid overflow
                ratio := cur(31 downto 28);  -- rough approximation
                if cur >= tot then
                    progress_bar <= "1111";
                elsif cur >= tot(31 downto 0) - shift_right(tot, 4) then
                    progress_bar <= "1111";
                elsif cur >= shift_right(tot, 1) + shift_right(tot, 2) then
                    progress_bar <= "0111";
                elsif cur >= shift_right(tot, 1) then
                    progress_bar <= "0011";
                elsif cur >= shift_right(tot, 2) then
                    progress_bar <= "0001";
                else
                    progress_bar <= "0000";
                end if;
            end if;
        end if;
    end process;

    -- LED output multiplexer
    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                led <= (others => '0');
            elsif fsm_error = '1' then
                -- All LEDs flash on error
                led <= (others => err_flash);
            elsif fsm_done = '1' then
                -- All LEDs solid on when done
                led <= (others => '1');
            else
                led(0) <= heartbeat;
                led(1) <= src_init_done;
                led(2) <= dst_init_done;
                led(3) <= fsm_copying and heartbeat;  -- blink during copy
                led(7 downto 4) <= progress_bar;
            end if;
        end if;
    end process;

end architecture rtl;
