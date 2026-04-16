--------------------------------------------------------------------------------
-- sd_card_duplicator_top.vhd
-- Top-level entity for the SD Card Duplicator on Digilent Nexys Video.
--
-- Source SD:  Onboard microSD slot (directly wired to FPGA)
-- Dest SD:   External VKLSVAN module on PMOD JA
-- Interface: SPI mode for both cards
--
-- User controls:
--   CPU_RESET (active-low) = system reset
--   BTNC      = start duplication
--   SW[15:0]  = total blocks to copy (x1024, so SW=1 → 1024 blocks = 512KB)
--   LED[7:0]  = status display
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sd_card_duplicator_top is
    port (
        -- System
        clk_100mhz   : in  std_logic;   -- 100 MHz system clock
        reset_n       : in  std_logic;   -- CPU_RESET pushbutton (active-low)

        -- User controls
        btn_start     : in  std_logic;   -- BTNC: start copy
        sw            : in  std_logic_vector(15 downto 0);  -- bloc   k count selector

        -- Source SD card (onboard microSD slot, directly wired)
        src_sd_sclk   : out std_logic;
        src_sd_mosi   : out std_logic;   -- mapped to sd_cmd
        src_sd_miso   : in  std_logic;   -- mapped to sd_dat[0]
        src_sd_cs_n   : out std_logic;   -- mapped to sd_dat[3]

        -- Destination SD card (PMOD JA)
        dst_sd_cs_n   : out std_logic;   -- JA pin 1 (AB22)
        dst_sd_mosi   : out std_logic;   -- JA pin 2 (AB21)
        dst_sd_miso   : in  std_logic;   -- JA pin 3 (AB20)
        dst_sd_sclk   : out std_logic;   -- JA pin 4 (AB18)

        -- LEDs
        led           : out std_logic_vector(7 downto 0)
    );
end entity sd_card_duplicator_top;

architecture structural of sd_card_duplicator_top is

    -- Active-high reset
    signal reset : std_logic;

    -- Start button debounce + edge detection
    signal btn_start_db : std_logic := '0';
    signal btn_start_d  : std_logic := '0';
    signal btn_start_re : std_logic := '0';

    -- Clock enables
    signal src_clk_en : std_logic;
    signal dst_clk_en : std_logic;

    -- Fast-mode selection from each SD controller
    signal src_fast_mode : std_logic;
    signal dst_fast_mode : std_logic;

    -- Source SPI master <-> SD controller
    signal src_spi_tx_data   : std_logic_vector(7 downto 0);
    signal src_spi_tx_valid  : std_logic;
    signal src_spi_tx_ready  : std_logic;
    signal src_spi_rx_data   : std_logic_vector(7 downto 0);
    signal src_spi_rx_valid  : std_logic;
    signal src_spi_cs_n_int  : std_logic;

    -- Destination SPI master <-> SD controller
    signal dst_spi_tx_data   : std_logic_vector(7 downto 0);
    signal dst_spi_tx_valid  : std_logic;
    signal dst_spi_tx_ready  : std_logic;
    signal dst_spi_rx_data   : std_logic_vector(7 downto 0);
    signal dst_spi_rx_valid  : std_logic;
    signal dst_spi_cs_n_int  : std_logic;

    -- Source SD controller signals
    signal src_cmd_init   : std_logic;
    signal src_cmd_read   : std_logic;
    signal src_block_addr : std_logic_vector(31 downto 0);
    signal src_busy       : std_logic;
    signal src_error      : std_logic;
    signal src_init_done  : std_logic;
    signal src_card_type  : std_logic_vector(1 downto 0);
    signal src_data_out   : std_logic_vector(7 downto 0);
    signal src_data_out_v : std_logic;

    -- Destination SD controller signals
    signal dst_cmd_init   : std_logic;
    signal dst_cmd_write  : std_logic;
    signal dst_block_addr : std_logic_vector(31 downto 0);
    signal dst_busy       : std_logic;
    signal dst_error      : std_logic;
    signal dst_init_done  : std_logic;
    signal dst_card_type  : std_logic_vector(1 downto 0);
    signal dst_data_in    : std_logic_vector(7 downto 0);
    signal dst_data_in_req: std_logic;

    -- Duplicator FSM signals
    signal total_blocks   : std_logic_vector(31 downto 0);
    signal current_block  : std_logic_vector(31 downto 0);
    signal fsm_idle       : std_logic;
    signal fsm_copying    : std_logic;
    signal fsm_done       : std_logic;
    signal fsm_error      : std_logic;

begin

    reset <= not reset_n;

    -- ==========================================================================
    -- Button debouncer (~10 ms stabilisation window)
    -- ==========================================================================
    start_debounce : entity work.btn_debouncer
        generic map (
            DEBOUNCE_CYCLES => 1_000_000  -- 10 ms at 100 MHz
        )
        port map (
            clk     => clk_100mhz,
            reset   => reset,
            btn_in  => btn_start,
            btn_out => btn_start_db
        );

    -- ==========================================================================
    -- Button edge detector (rising edge of debounced btn_start)
    -- ==========================================================================
    process (clk_100mhz)
    begin
        if rising_edge(clk_100mhz) then
            btn_start_d  <= btn_start_db;
            btn_start_re <= btn_start_db and not btn_start_d;
        end if;
    end process;

    -- Total blocks to copy: switches * 1024  (shift left 10)
    total_blocks <= std_logic_vector(
        resize(unsigned(sw) & "0000000000", 32)
    );

    -- ==========================================================================
    -- Source card: Clock divider
    -- ==========================================================================
    src_clk_div : entity work.clk_divider
        port map (
            clk       => clk_100mhz,
            reset     => reset,
            fast_mode => src_fast_mode,
            clk_en    => src_clk_en
        );

    -- ==========================================================================
    -- Source card: SPI master
    -- ==========================================================================
    src_spi : entity work.spi_master
        port map (
            clk      => clk_100mhz,
            reset    => reset,
            sclk     => src_sd_sclk,
            mosi     => src_sd_mosi,
            miso     => src_sd_miso,
            cs_n     => src_sd_cs_n,
            cs_n_in  => src_spi_cs_n_int,
            clk_en   => src_clk_en,
            tx_data  => src_spi_tx_data,
            tx_valid => src_spi_tx_valid,
            tx_ready => src_spi_tx_ready,
            rx_data  => src_spi_rx_data,
            rx_valid => src_spi_rx_valid
        );

    -- ==========================================================================
    -- Source card: SD controller
    -- ==========================================================================
    src_sd_ctrl : entity work.sd_card_controller
        port map (
            clk          => clk_100mhz,
            reset        => reset,
            spi_tx_data  => src_spi_tx_data,
            spi_tx_valid => src_spi_tx_valid,
            spi_tx_ready => src_spi_tx_ready,
            spi_rx_data  => src_spi_rx_data,
            spi_rx_valid => src_spi_rx_valid,
            spi_cs_n     => src_spi_cs_n_int,
            fast_mode    => src_fast_mode,
            cmd_init     => src_cmd_init,
            cmd_read     => src_cmd_read,
            cmd_write    => '0',
            block_addr   => src_block_addr,
            busy         => src_busy,
            error        => src_error,
            init_done    => src_init_done,
            card_type    => src_card_type,
            data_out     => src_data_out,
            data_out_valid => src_data_out_v,
            data_in      => (others => '0'),
            data_in_req  => open
        );

    -- ==========================================================================
    -- Destination card: Clock divider
    -- ==========================================================================
    dst_clk_div : entity work.clk_divider
        port map (
            clk       => clk_100mhz,
            reset     => reset,
            fast_mode => dst_fast_mode,
            clk_en    => dst_clk_en
        );

    -- ==========================================================================
    -- Destination card: SPI master
    -- ==========================================================================
    dst_spi : entity work.spi_master
        port map (
            clk      => clk_100mhz,
            reset    => reset,
            sclk     => dst_sd_sclk,
            mosi     => dst_sd_mosi,
            miso     => dst_sd_miso,
            cs_n     => dst_sd_cs_n,
            cs_n_in  => dst_spi_cs_n_int,
            clk_en   => dst_clk_en,
            tx_data  => dst_spi_tx_data,
            tx_valid => dst_spi_tx_valid,
            tx_ready => dst_spi_tx_ready,
            rx_data  => dst_spi_rx_data,
            rx_valid => dst_spi_rx_valid
        );

    -- ==========================================================================
    -- Destination card: SD controller
    -- ==========================================================================
    dst_sd_ctrl : entity work.sd_card_controller
        port map (
            clk          => clk_100mhz,
            reset        => reset,
            spi_tx_data  => dst_spi_tx_data,
            spi_tx_valid => dst_spi_tx_valid,
            spi_tx_ready => dst_spi_tx_ready,
            spi_rx_data  => dst_spi_rx_data,
            spi_rx_valid => dst_spi_rx_valid,
            spi_cs_n     => dst_spi_cs_n_int,
            fast_mode    => dst_fast_mode,
            cmd_init     => dst_cmd_init,
            cmd_read     => '0',
            cmd_write    => dst_cmd_write,
            block_addr   => dst_block_addr,
            busy         => dst_busy,
            error        => dst_error,
            init_done    => dst_init_done,
            card_type    => dst_card_type,
            data_out     => open,
            data_out_valid => open,
            data_in      => dst_data_in,
            data_in_req  => dst_data_in_req
        );

    -- ==========================================================================
    -- Duplicator FSM
    -- ==========================================================================
    dup_fsm : entity work.duplicator_fsm
        port map (
            clk           => clk_100mhz,
            reset         => reset,
            start         => btn_start_re,
            total_blocks  => total_blocks,
            current_block => current_block,
            fsm_idle      => fsm_idle,
            fsm_copying   => fsm_copying,
            fsm_done      => fsm_done,
            fsm_error     => fsm_error,
            src_cmd_init  => src_cmd_init,
            src_cmd_read  => src_cmd_read,
            src_block_addr=> src_block_addr,
            src_busy      => src_busy,
            src_error     => src_error,
            src_init_done => src_init_done,
            src_data_out  => src_data_out,
            src_data_out_v=> src_data_out_v,
            dst_cmd_init  => dst_cmd_init,
            dst_cmd_write => dst_cmd_write,
            dst_block_addr=> dst_block_addr,
            dst_busy      => dst_busy,
            dst_error     => dst_error,
            dst_init_done => dst_init_done,
            dst_data_in   => dst_data_in,
            dst_data_in_req => dst_data_in_req
        );

    -- ==========================================================================
    -- Status display (LEDs)
    -- ==========================================================================
    status : entity work.status_display
        port map (
            clk           => clk_100mhz,
            reset         => reset,
            fsm_idle      => fsm_idle,
            fsm_copying   => fsm_copying,
            fsm_done      => fsm_done,
            fsm_error     => fsm_error,
            src_init_done => src_init_done,
            dst_init_done => dst_init_done,
            current_block => current_block,
            total_blocks  => total_blocks,
            led           => led
        );

end architecture structural;
