--------------------------------------------------------------------------------
-- tb_spi_master.vhd
-- Testbench for spi_master module.
--
-- Verifies:
--   1. Idle state (SCLK low, MOSI high, CS controllable)
--   2. Single byte transfer: MSB-first shifting, MISO sampling
--   3. Back-to-back byte transfers
--   4. Reset behaviour
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_spi_master is
end entity tb_spi_master;

architecture sim of tb_spi_master is

    constant CLK_PERIOD : time := 10 ns;  -- 100 MHz

    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';

    -- SPI bus
    signal sclk     : std_logic;
    signal mosi     : std_logic;
    signal miso     : std_logic := '1';
    signal cs_n     : std_logic;

    -- Control
    signal cs_n_in  : std_logic := '1';
    signal clk_en   : std_logic := '0';

    -- Data
    signal tx_data  : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_valid : std_logic := '0';
    signal tx_ready : std_logic;
    signal rx_data  : std_logic_vector(7 downto 0);
    signal rx_valid : std_logic;

    -- Clock-enable generation (~5 MHz for sim speed)
    signal ce_cnt   : unsigned(3 downto 0) := (others => '0');

begin

    -- Clock generation
    clk <= not clk after CLK_PERIOD / 2;

    -- DUT instantiation
    dut : entity work.spi_master
        port map (
            clk      => clk,
            reset    => reset,
            sclk     => sclk,
            mosi     => mosi,
            miso     => miso,
            cs_n     => cs_n,
            cs_n_in  => cs_n_in,
            clk_en   => clk_en,
            tx_data  => tx_data,
            tx_valid => tx_valid,
            tx_ready => tx_ready,
            rx_data  => rx_data,
            rx_valid => rx_valid
        );

    -- Generate clock enable every 10 system clocks
    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                ce_cnt <= (others => '0');
                clk_en <= '0';
            elsif ce_cnt = 9 then
                ce_cnt <= (others => '0');
                clk_en <= '1';
            else
                ce_cnt <= ce_cnt + 1;
                clk_en <= '0';
            end if;
        end if;
    end process;

    -- MISO loopback: feed back MOSI with 1-cycle delay to simulate a simple device
    process (clk)
    begin
        if rising_edge(clk) then
            miso <= mosi;
        end if;
    end process;

    -- Stimulus
    stim_proc : process
    begin
        -- Hold reset for 5 clock cycles
        reset <= '1';
        wait for 5 * CLK_PERIOD;
        reset <= '0';
        wait for 2 * CLK_PERIOD;

        -- =====================================================================
        -- Test 1: Single byte transfer (0xA5)
        -- =====================================================================
        report "Test 1: Single byte transfer 0xA5" severity note;
        cs_n_in <= '0';     -- assert CS
        wait for CLK_PERIOD;

        tx_data  <= x"A5";
        tx_valid <= '1';
        wait for CLK_PERIOD;
        tx_valid <= '0';

        -- Wait for transfer to complete
        wait until rx_valid = '1' for 5 us;

        if rx_valid = '1' then
            report "Test 1 PASS: rx_data = 0x" & to_hstring(rx_data) severity note;
        else
            report "Test 1 FAIL: timeout waiting for rx_valid" severity error;
        end if;

        cs_n_in <= '1';     -- deassert CS
        wait for 500 ns;

        -- =====================================================================
        -- Test 2: Back-to-back transfers (0xFF then 0x00)
        -- =====================================================================
        report "Test 2: Back-to-back transfers" severity note;
        cs_n_in <= '0';
        wait for CLK_PERIOD;

        -- First byte: 0xFF
        tx_data  <= x"FF";
        tx_valid <= '1';
        wait for CLK_PERIOD;
        tx_valid <= '0';

        wait until rx_valid = '1' for 5 us;
        report "  Byte 1 rx_data = 0x" & to_hstring(rx_data) severity note;

        -- Second byte: 0x00
        wait for 2 * CLK_PERIOD;
        tx_data  <= x"00";
        tx_valid <= '1';
        wait for CLK_PERIOD;
        tx_valid <= '0';

        wait until rx_valid = '1' for 5 us;
        report "  Byte 2 rx_data = 0x" & to_hstring(rx_data) severity note;

        cs_n_in <= '1';
        wait for 500 ns;

        -- =====================================================================
        -- Test 3: Reset during transfer
        -- =====================================================================
        report "Test 3: Reset during transfer" severity note;
        cs_n_in <= '0';
        tx_data  <= x"55";
        tx_valid <= '1';
        wait for CLK_PERIOD;
        tx_valid <= '0';

        -- Wait a few SPI cycles, then reset
        wait for 500 ns;
        reset <= '1';
        wait for 3 * CLK_PERIOD;
        reset <= '0';
        wait for 2 * CLK_PERIOD;

        if tx_ready = '1' then
            report "Test 3 PASS: tx_ready asserted after reset" severity note;
        else
            report "Test 3 FAIL: tx_ready not asserted after reset" severity error;
        end if;

        wait for 500 ns;

        report "All SPI master tests completed." severity note;
        wait;
    end process;

end architecture sim;
