--------------------------------------------------------------------------------
-- spi_master.vhd
-- Generic SPI master with active-low chip select.
--
-- Operation:
--   1. Load tx_data, assert tx_valid for one cycle.
--   2. Module drives CS_N low, shifts 8 bits out on MOSI (MSB first),
--      simultaneously sampling MISO into rx_data.
--   3. tx_ready goes low while a transfer is in progress.
--   4. When the byte is complete, rx_valid pulses high for one cycle and
--      tx_ready returns high.
--
--   CS_N is directly controlled by the parent module via cs_n_in so that
--   multi-byte SD card commands can keep CS asserted across bytes.
--
-- Clocking:
--   All logic runs on the system clock. Bit timing is governed by the
--   external clk_en input (one-cycle pulse at the desired SPI half-period).
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_master is
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;

        -- SPI bus
        sclk     : out std_logic;
        mosi     : out std_logic;
        miso     : in  std_logic;
        cs_n     : out std_logic;

        -- Control from parent
        cs_n_in  : in  std_logic;  -- directly drives the CS_N pin
        clk_en   : in  std_logic;  -- half-period tick from clk_divider

        -- Data interface
        tx_data  : in  std_logic_vector(7 downto 0);
        tx_valid : in  std_logic;  -- pulse to start a byte transfer
        tx_ready : out std_logic;  -- '1' when idle, ready for new byte
        rx_data  : out std_logic_vector(7 downto 0);
        rx_valid : out std_logic   -- pulses '1' when rx_data is valid
    );
end entity spi_master;

architecture rtl of spi_master is

    type state_t is (S_IDLE, S_TRANSFER, S_DONE);
    signal state      : state_t := S_IDLE;

    signal shift_out  : std_logic_vector(7 downto 0) := (others => '1');
    signal shift_in   : std_logic_vector(7 downto 0) := (others => '0');
    signal bit_cnt    : unsigned(3 downto 0)          := (others => '0');
    signal sclk_int   : std_logic := '0';
    signal phase      : std_logic := '0';  -- 0 = leading edge, 1 = trailing edge

begin

    cs_n <= cs_n_in;

    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state     <= S_IDLE;
                shift_out <= (others => '1');
                shift_in  <= (others => '0');
                bit_cnt   <= (others => '0');
                sclk_int  <= '0';
                phase     <= '0';
                tx_ready  <= '1';
                rx_valid  <= '0';
                mosi      <= '1';
                sclk      <= '0';
            else
                rx_valid <= '0';  -- default: de-assert

                case state is
                    --------------------------------------------------------
                    when S_IDLE =>
                        sclk_int <= '0';
                        sclk     <= '0';
                        phase    <= '0';
                        tx_ready <= '1';
                        mosi     <= '1';

                        if tx_valid = '1' then
                            shift_out <= tx_data;
                            bit_cnt   <= (others => '0');
                            tx_ready  <= '0';
                            state     <= S_TRANSFER;
                            mosi      <= tx_data(7);  -- drive MSB immediately
                        end if;

                    --------------------------------------------------------
                    when S_TRANSFER =>
                        if clk_en = '1' then
                            if phase = '0' then
                                -- Leading edge: drive SCLK high, sample MISO
                                sclk_int <= '1';
                                sclk     <= '1';
                                shift_in <= shift_in(6 downto 0) & miso;
                                phase    <= '1';
                            else
                                -- Trailing edge: drive SCLK low, shift next bit
                                sclk_int <= '0';
                                sclk     <= '0';
                                phase    <= '0';

                                if bit_cnt = 7 then
                                    state <= S_DONE;
                                else
                                    bit_cnt   <= bit_cnt + 1;
                                    shift_out <= shift_out(6 downto 0) & '1';
                                    mosi      <= shift_out(6);  -- next MSB
                                end if;
                            end if;
                        end if;

                    --------------------------------------------------------
                    when S_DONE =>
                        rx_data  <= shift_in;
                        rx_valid <= '1';
                        tx_ready <= '1';
                        mosi     <= '1';
                        state    <= S_IDLE;

                end case;
            end if;
        end if;
    end process;

end architecture rtl;
