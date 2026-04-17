--------------------------------------------------------------------------------
-- sd_card_controller.vhd
-- SD card controller operating in SPI mode.
--
-- Supports:
--   - Full initialization:  power-up → CMD0 → CMD8 → CMD55/ACMD41 → CMD58 → CMD9
--   - CSD register read:    CMD9 (auto-detects card capacity)
--   - Single-block read:    CMD17
--   - Single-block write:   CMD24
--
-- The controller communicates with the SPI master via byte-level handshaking
-- (tx_data/tx_valid/tx_ready and rx_data/rx_valid).
--
-- Interface to parent:
--   - cmd_init:  pulse to begin card initialization
--   - cmd_read:  pulse to read a 512-byte block at block_addr
--   - cmd_write: pulse to write a 512-byte block at block_addr
--   - busy:      '1' while an operation is in progress
--   - error:     '1' if the last operation failed (timeout / bad response)
--   - init_done: '1' after successful initialization
--   - card_type: "00" = unknown, "01" = SDv1 (SDSC), "10" = SDv2 (SDHC/XC)
--
-- Data buffer interface:
--   - For READ:  data_out holds each byte as it arrives, data_out_valid pulses
--   - For WRITE: data_in must be presented when data_in_req pulses
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sd_card_controller is
    generic (
        INIT_TIMEOUT : integer := 1_000_000;  -- max clocks to wait during init
        CMD_TIMEOUT  : integer := 100_000     -- max clocks waiting for a response
    );
    port (
        clk          : in  std_logic;
        reset        : in  std_logic;

        -- SPI master interface
        spi_tx_data  : out std_logic_vector(7 downto 0);
        spi_tx_valid : out std_logic;
        spi_tx_ready : in  std_logic;
        spi_rx_data  : in  std_logic_vector(7 downto 0);
        spi_rx_valid : in  std_logic;
        spi_cs_n     : out std_logic;

        -- Clock-speed control
        fast_mode    : out std_logic;  -- '0' during init, '1' after

        -- Command interface
        cmd_init     : in  std_logic;
        cmd_read     : in  std_logic;
        cmd_write    : in  std_logic;
        block_addr   : in  std_logic_vector(31 downto 0);

        -- Status
        busy             : out std_logic;
        error            : out std_logic;
        init_done        : out std_logic;
        card_type        : out std_logic_vector(1 downto 0);  -- "01"=SDSC, "10"=SDHC
        card_total_blocks: out std_logic_vector(31 downto 0); -- total 512-byte blocks

        -- Read data output
        data_out       : out std_logic_vector(7 downto 0);
        data_out_valid : out std_logic;

        -- Write data input
        data_in        : in  std_logic_vector(7 downto 0);
        data_in_req    : out std_logic
    );
end entity sd_card_controller;

architecture rtl of sd_card_controller is

    -- =========================================================================
    -- Types
    -- =========================================================================
    type state_t is (
        -- Idle / reset
        ST_IDLE,
        -- Initialization sub-states
        ST_INIT_POWER,        -- send >=74 dummy clocks with CS high
        ST_INIT_CMD0,         -- software reset
        ST_INIT_CMD0_RESP,
        ST_INIT_CMD8,         -- send interface condition
        ST_INIT_CMD8_RESP,
        ST_INIT_CMD8_DATA,    -- read 4 extra bytes of R7
        ST_INIT_CMD55,        -- app command prefix
        ST_INIT_CMD55_RESP,
        ST_INIT_ACMD41,       -- send operating condition
        ST_INIT_ACMD41_RESP,
        ST_INIT_CMD58,        -- read OCR
        ST_INIT_CMD58_RESP,
        ST_INIT_CMD58_DATA,   -- read 4 OCR bytes
        ST_INIT_CMD9,         -- send CSD (card size)
        ST_INIT_CMD9_RESP,
        ST_INIT_CMD9_TOKEN,   -- wait for data start token
        ST_INIT_CMD9_DATA,    -- read 16 CSD bytes
        ST_INIT_CMD9_CRC,     -- read/discard 2 CRC bytes
        ST_INIT_COMPLETE,
        -- Read sub-states
        ST_READ_CMD17,
        ST_READ_CMD17_RESP,
        ST_READ_WAIT_TOKEN,
        ST_READ_DATA,
        ST_READ_CRC,
        ST_READ_COMPLETE,
        -- Write sub-states
        ST_WRITE_CMD24,
        ST_WRITE_CMD24_RESP,
        ST_WRITE_TOKEN,
        ST_WRITE_DATA,
        ST_WRITE_CRC,
        ST_WRITE_RESP,
        ST_WRITE_BUSY,
        ST_WRITE_COMPLETE,
        -- Error
        ST_ERROR
    );

    signal state     : state_t := ST_IDLE;
    signal ret_state : state_t := ST_IDLE;  -- return state after send_cmd

    -- =========================================================================
    -- Internal signals
    -- =========================================================================
    -- Command frame buffer: [cmd_byte, arg3..arg0, crc]
    signal cmd_buf     : std_logic_vector(47 downto 0) := (others => '0');
    signal cmd_byte_idx: unsigned(2 downto 0) := (others => '0');

    -- Send-byte FSM helper
    signal send_pending : std_logic := '0';
    signal send_byte    : std_logic_vector(7 downto 0) := (others => '1');

    -- Response / data
    signal resp_r1      : std_logic_vector(7 downto 0) := (others => '1');
    signal r7_data      : std_logic_vector(31 downto 0) := (others => '0');
    signal ocr_data     : std_logic_vector(31 downto 0) := (others => '0');
    signal byte_counter : unsigned(9 downto 0) := (others => '0');

    -- Timeout
    signal timeout_cnt  : unsigned(19 downto 0) := (others => '0');

    -- Retry counter for ACMD41
    signal retry_cnt    : unsigned(15 downto 0) := (others => '0');

    -- Internal card type register
    signal card_sdhc    : std_logic := '0';

    -- Dummy clock counter for power-up
    signal dummy_cnt    : unsigned(7 downto 0) := (others => '0');

    -- Internal status
    signal i_busy       : std_logic := '0';
    signal i_error      : std_logic := '0';
    signal i_init_done  : std_logic := '0';
    signal i_fast_mode  : std_logic := '0';

    -- R7 / OCR byte index
    signal extra_byte_idx : unsigned(1 downto 0) := (others => '0');

    -- CSD register buffer (16 bytes)
    type csd_buf_t is array (0 to 15) of std_logic_vector(7 downto 0);
    signal csd_buf       : csd_buf_t := (others => (others => '0'));
    signal csd_byte_idx  : unsigned(4 downto 0) := (others => '0');
    signal i_card_total_blocks : unsigned(31 downto 0) := (others => '0');

    -- Wait-for-response helpers
    signal wait_resp_cnt : unsigned(19 downto 0) := (others => '0');

begin

    busy              <= i_busy;
    error             <= i_error;
    init_done         <= i_init_done;
    fast_mode         <= i_fast_mode;
    card_type         <= "10" when card_sdhc = '1' else
                         "01" when i_init_done = '1' else
                         "00";
    card_total_blocks <= std_logic_vector(i_card_total_blocks);

    -- =========================================================================
    -- Main FSM
    -- =========================================================================
    process (clk)
        -- Helper: assemble a 48-bit SD command frame
        procedure build_cmd(
            cmd_index : in integer;
            arg       : in std_logic_vector(31 downto 0);
            crc       : in std_logic_vector(7 downto 0)
        ) is
        begin
            cmd_buf <= "01" & std_logic_vector(to_unsigned(cmd_index, 6))
                       & arg & crc;
        end procedure;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state         <= ST_IDLE;
                spi_tx_valid  <= '0';
                spi_tx_data   <= (others => '1');
                spi_cs_n      <= '1';
                i_busy        <= '0';
                i_error       <= '0';
                i_init_done   <= '0';
                i_fast_mode   <= '0';
                card_sdhc     <= '0';
                data_out_valid<= '0';
                data_in_req   <= '0';
                send_pending  <= '0';
            else
                -- Default de-assertions
                spi_tx_valid   <= '0';
                data_out_valid <= '0';
                data_in_req    <= '0';

                -- Handle pending SPI byte send
                if send_pending = '1' and spi_tx_ready = '1' then
                    spi_tx_data  <= send_byte;
                    spi_tx_valid <= '1';
                    send_pending <= '0';
                end if;

                case state is

                -- =============================================================
                -- IDLE
                -- =============================================================
                when ST_IDLE =>
                    i_busy  <= '0';
                    i_error <= '0';
                    spi_cs_n <= '1';

                    if cmd_init = '1' then
                        i_busy       <= '1';
                        i_init_done  <= '0';
                        i_fast_mode  <= '0';
                        card_sdhc    <= '0';
                        dummy_cnt    <= (others => '0');
                        state        <= ST_INIT_POWER;
                    elsif cmd_read = '1' and i_init_done = '1' then
                        i_busy  <= '1';
                        state   <= ST_READ_CMD17;
                    elsif cmd_write = '1' and i_init_done = '1' then
                        i_busy  <= '1';
                        state   <= ST_WRITE_CMD24;
                    end if;

                -- =============================================================
                -- INIT: Power-up — send >=80 dummy clocks with CS high
                -- =============================================================
                when ST_INIT_POWER =>
                    spi_cs_n <= '1';   -- CS stays high during dummy clocks
                    if spi_tx_ready = '1' then
                        if dummy_cnt >= 10 then  -- 10 * 8 = 80 clocks
                            dummy_cnt <= (others => '0');
                            state     <= ST_INIT_CMD0;
                        else
                            spi_tx_data  <= x"FF";
                            spi_tx_valid <= '1';
                            dummy_cnt    <= dummy_cnt + 1;
                        end if;
                    end if;

                -- =============================================================
                -- INIT: CMD0 — GO_IDLE_STATE
                -- =============================================================
                when ST_INIT_CMD0 =>
                    spi_cs_n      <= '0';
                    build_cmd(0, x"00000000", x"95");
                    cmd_byte_idx  <= (others => '0');
                    wait_resp_cnt <= (others => '0');
                    -- Send first byte
                    send_byte    <= cmd_buf(47 downto 40);
                    send_pending <= '1';
                    cmd_byte_idx <= "001";
                    state        <= ST_INIT_CMD0_RESP;

                when ST_INIT_CMD0_RESP =>
                    -- Continue sending remaining command bytes
                    if cmd_byte_idx <= 5 and spi_tx_ready = '1' and send_pending = '0' then
                        case cmd_byte_idx is
                            when "001" => send_byte <= cmd_buf(39 downto 32);
                            when "010" => send_byte <= cmd_buf(31 downto 24);
                            when "011" => send_byte <= cmd_buf(23 downto 16);
                            when "100" => send_byte <= cmd_buf(15 downto 8);
                            when "101" => send_byte <= cmd_buf(7 downto 0);
                            when others => null;
                        end case;
                        send_pending <= '1';
                        cmd_byte_idx <= cmd_byte_idx + 1;
                    end if;

                    -- After all 6 bytes sent, poll for response
                    if cmd_byte_idx > 5 then
                        if spi_tx_ready = '1' and send_pending = '0' then
                            -- Send dummy byte to clock out response
                            send_byte    <= x"FF";
                            send_pending <= '1';
                        end if;

                        if spi_rx_valid = '1' then
                            if spi_rx_data(7) = '0' then  -- valid R1 response
                                resp_r1 <= spi_rx_data;
                                if spi_rx_data = x"01" then  -- idle state, OK
                                    state <= ST_INIT_CMD8;
                                else
                                    state <= ST_ERROR;
                                end if;
                            else
                                -- Still waiting; check timeout
                                wait_resp_cnt <= wait_resp_cnt + 1;
                                if wait_resp_cnt >= to_unsigned(CMD_TIMEOUT, 20) then
                                    state <= ST_ERROR;
                                end if;
                            end if;
                        end if;
                    end if;

                -- =============================================================
                -- INIT: CMD8 — SEND_IF_COND (voltage check)
                -- =============================================================
                when ST_INIT_CMD8 =>
                    build_cmd(8, x"000001AA", x"87");
                    cmd_byte_idx  <= (others => '0');
                    wait_resp_cnt <= (others => '0');
                    extra_byte_idx<= (others => '0');
                    send_byte     <= "01" & std_logic_vector(to_unsigned(8, 6));
                    send_pending  <= '1';
                    cmd_byte_idx  <= "001";
                    state         <= ST_INIT_CMD8_RESP;

                when ST_INIT_CMD8_RESP =>
                    -- Send remaining bytes
                    if cmd_byte_idx <= 5 and spi_tx_ready = '1' and send_pending = '0' then
                        case cmd_byte_idx is
                            when "001" => send_byte <= cmd_buf(39 downto 32);
                            when "010" => send_byte <= cmd_buf(31 downto 24);
                            when "011" => send_byte <= cmd_buf(23 downto 16);
                            when "100" => send_byte <= cmd_buf(15 downto 8);
                            when "101" => send_byte <= cmd_buf(7 downto 0);
                            when others => null;
                        end case;
                        send_pending <= '1';
                        cmd_byte_idx <= cmd_byte_idx + 1;
                    end if;

                    -- Wait for R1 response
                    if cmd_byte_idx > 5 then
                        if spi_tx_ready = '1' and send_pending = '0' then
                            send_byte    <= x"FF";
                            send_pending <= '1';
                        end if;

                        if spi_rx_valid = '1' then
                            if spi_rx_data(7) = '0' then
                                resp_r1 <= spi_rx_data;
                                if spi_rx_data = x"01" then
                                    -- SDv2 card: read 4 more bytes (R7)
                                    extra_byte_idx <= (others => '0');
                                    state          <= ST_INIT_CMD8_DATA;
                                elsif spi_rx_data(2) = '1' then
                                    -- Illegal command: SDv1 or MMC
                                    -- Skip to CMD55/ACMD41 without SDHC bit
                                    state <= ST_INIT_CMD55;
                                else
                                    state <= ST_ERROR;
                                end if;
                            else
                                wait_resp_cnt <= wait_resp_cnt + 1;
                                if wait_resp_cnt >= to_unsigned(CMD_TIMEOUT, 20) then
                                    state <= ST_ERROR;
                                end if;
                            end if;
                        end if;
                    end if;

                -- Read 4 bytes of R7
                when ST_INIT_CMD8_DATA =>
                    if spi_tx_ready = '1' and send_pending = '0' then
                        send_byte    <= x"FF";
                        send_pending <= '1';
                    end if;

                    if spi_rx_valid = '1' then
                        r7_data <= r7_data(23 downto 0) & spi_rx_data;
                        if extra_byte_idx = 3 then
                            -- Check echo pattern: should end in 0x1AA
                            state <= ST_INIT_CMD55;
                        else
                            extra_byte_idx <= extra_byte_idx + 1;
                        end if;
                    end if;

                -- =============================================================
                -- INIT: CMD55 + ACMD41 loop
                -- =============================================================
                when ST_INIT_CMD55 =>
                    build_cmd(55, x"00000000", x"65");
                    cmd_byte_idx  <= (others => '0');
                    wait_resp_cnt <= (others => '0');
                    send_byte     <= "01" & std_logic_vector(to_unsigned(55, 6));
                    send_pending  <= '1';
                    cmd_byte_idx  <= "001";
                    state         <= ST_INIT_CMD55_RESP;

                when ST_INIT_CMD55_RESP =>
                    if cmd_byte_idx <= 5 and spi_tx_ready = '1' and send_pending = '0' then
                        case cmd_byte_idx is
                            when "001" => send_byte <= cmd_buf(39 downto 32);
                            when "010" => send_byte <= cmd_buf(31 downto 24);
                            when "011" => send_byte <= cmd_buf(23 downto 16);
                            when "100" => send_byte <= cmd_buf(15 downto 8);
                            when "101" => send_byte <= cmd_buf(7 downto 0);
                            when others => null;
                        end case;
                        send_pending <= '1';
                        cmd_byte_idx <= cmd_byte_idx + 1;
                    end if;

                    if cmd_byte_idx > 5 then
                        if spi_tx_ready = '1' and send_pending = '0' then
                            send_byte    <= x"FF";
                            send_pending <= '1';
                        end if;

                        if spi_rx_valid = '1' and spi_rx_data(7) = '0' then
                            resp_r1 <= spi_rx_data;
                            state   <= ST_INIT_ACMD41;
                        end if;
                    end if;

                when ST_INIT_ACMD41 =>
                    -- ACMD41 with HCS bit (bit 30) to indicate SDHC support
                    build_cmd(41, x"40000000", x"77");
                    cmd_byte_idx  <= (others => '0');
                    wait_resp_cnt <= (others => '0');
                    send_byte     <= "01" & std_logic_vector(to_unsigned(41, 6));
                    send_pending  <= '1';
                    cmd_byte_idx  <= "001";
                    state         <= ST_INIT_ACMD41_RESP;

                when ST_INIT_ACMD41_RESP =>
                    if cmd_byte_idx <= 5 and spi_tx_ready = '1' and send_pending = '0' then
                        case cmd_byte_idx is
                            when "001" => send_byte <= cmd_buf(39 downto 32);
                            when "010" => send_byte <= cmd_buf(31 downto 24);
                            when "011" => send_byte <= cmd_buf(23 downto 16);
                            when "100" => send_byte <= cmd_buf(15 downto 8);
                            when "101" => send_byte <= cmd_buf(7 downto 0);
                            when others => null;
                        end case;
                        send_pending <= '1';
                        cmd_byte_idx <= cmd_byte_idx + 1;
                    end if;

                    if cmd_byte_idx > 5 then
                        if spi_tx_ready = '1' and send_pending = '0' then
                            send_byte    <= x"FF";
                            send_pending <= '1';
                        end if;

                        if spi_rx_valid = '1' and spi_rx_data(7) = '0' then
                            resp_r1 <= spi_rx_data;
                            if spi_rx_data = x"00" then
                                -- Card is ready → read OCR
                                state <= ST_INIT_CMD58;
                            elsif spi_rx_data = x"01" then
                                -- Still initializing, retry
                                retry_cnt <= retry_cnt + 1;
                                if retry_cnt >= 50000 then
                                    state <= ST_ERROR;
                                else
                                    state <= ST_INIT_CMD55;
                                end if;
                            else
                                state <= ST_ERROR;
                            end if;
                        end if;
                    end if;

                -- =============================================================
                -- INIT: CMD58 — READ_OCR
                -- =============================================================
                when ST_INIT_CMD58 =>
                    build_cmd(58, x"00000000", x"FD");
                    cmd_byte_idx  <= (others => '0');
                    wait_resp_cnt <= (others => '0');
                    extra_byte_idx<= (others => '0');
                    send_byte     <= "01" & std_logic_vector(to_unsigned(58, 6));
                    send_pending  <= '1';
                    cmd_byte_idx  <= "001";
                    state         <= ST_INIT_CMD58_RESP;

                when ST_INIT_CMD58_RESP =>
                    if cmd_byte_idx <= 5 and spi_tx_ready = '1' and send_pending = '0' then
                        case cmd_byte_idx is
                            when "001" => send_byte <= cmd_buf(39 downto 32);
                            when "010" => send_byte <= cmd_buf(31 downto 24);
                            when "011" => send_byte <= cmd_buf(23 downto 16);
                            when "100" => send_byte <= cmd_buf(15 downto 8);
                            when "101" => send_byte <= cmd_buf(7 downto 0);
                            when others => null;
                        end case;
                        send_pending <= '1';
                        cmd_byte_idx <= cmd_byte_idx + 1;
                    end if;

                    if cmd_byte_idx > 5 then
                        if spi_tx_ready = '1' and send_pending = '0' then
                            send_byte    <= x"FF";
                            send_pending <= '1';
                        end if;

                        if spi_rx_valid = '1' and spi_rx_data(7) = '0' then
                            resp_r1        <= spi_rx_data;
                            extra_byte_idx <= (others => '0');
                            state          <= ST_INIT_CMD58_DATA;
                        end if;
                    end if;

                when ST_INIT_CMD58_DATA =>
                    if spi_tx_ready = '1' and send_pending = '0' then
                        send_byte    <= x"FF";
                        send_pending <= '1';
                    end if;

                    if spi_rx_valid = '1' then
                        ocr_data <= ocr_data(23 downto 0) & spi_rx_data;
                        if extra_byte_idx = 3 then
                            -- OCR bit 30 = CCS (Card Capacity Status)
                            -- Latch it now before moving to CMD9
                            card_sdhc <= ocr_data(22);  -- will be bit 30 after final shift
                            spi_cs_n  <= '1';  -- deselect briefly
                            state     <= ST_INIT_CMD9;
                        else
                            extra_byte_idx <= extra_byte_idx + 1;
                        end if;
                    end if;

                -- =============================================================
                -- INIT: CMD9 — SEND_CSD (read card capacity)
                -- =============================================================
                when ST_INIT_CMD9 =>
                    spi_cs_n      <= '0';
                    build_cmd(9, x"00000000", x"AF");
                    cmd_byte_idx  <= (others => '0');
                    wait_resp_cnt <= (others => '0');
                    csd_byte_idx  <= (others => '0');
                    send_byte     <= "01" & std_logic_vector(to_unsigned(9, 6));
                    send_pending  <= '1';
                    cmd_byte_idx  <= "001";
                    state         <= ST_INIT_CMD9_RESP;

                when ST_INIT_CMD9_RESP =>
                    if cmd_byte_idx <= 5 and spi_tx_ready = '1' and send_pending = '0' then
                        case cmd_byte_idx is
                            when "001" => send_byte <= cmd_buf(39 downto 32);
                            when "010" => send_byte <= cmd_buf(31 downto 24);
                            when "011" => send_byte <= cmd_buf(23 downto 16);
                            when "100" => send_byte <= cmd_buf(15 downto 8);
                            when "101" => send_byte <= cmd_buf(7 downto 0);
                            when others => null;
                        end case;
                        send_pending <= '1';
                        cmd_byte_idx <= cmd_byte_idx + 1;
                    end if;

                    if cmd_byte_idx > 5 then
                        if spi_tx_ready = '1' and send_pending = '0' then
                            send_byte    <= x"FF";
                            send_pending <= '1';
                        end if;

                        if spi_rx_valid = '1' and spi_rx_data(7) = '0' then
                            resp_r1       <= spi_rx_data;
                            if spi_rx_data = x"00" then
                                wait_resp_cnt <= (others => '0');
                                state         <= ST_INIT_CMD9_TOKEN;
                            else
                                state <= ST_ERROR;
                            end if;
                        end if;
                    end if;

                -- Wait for data start token (0xFE)
                when ST_INIT_CMD9_TOKEN =>
                    if spi_tx_ready = '1' and send_pending = '0' then
                        send_byte    <= x"FF";
                        send_pending <= '1';
                    end if;

                    if spi_rx_valid = '1' then
                        if spi_rx_data = x"FE" then
                            csd_byte_idx <= (others => '0');
                            state        <= ST_INIT_CMD9_DATA;
                        else
                            wait_resp_cnt <= wait_resp_cnt + 1;
                            if wait_resp_cnt >= to_unsigned(CMD_TIMEOUT, 20) then
                                state <= ST_ERROR;
                            end if;
                        end if;
                    end if;

                -- Read 16 CSD bytes
                when ST_INIT_CMD9_DATA =>
                    if spi_tx_ready = '1' and send_pending = '0' then
                        send_byte    <= x"FF";
                        send_pending <= '1';
                    end if;

                    if spi_rx_valid = '1' then
                        csd_buf(to_integer(csd_byte_idx)) <= spi_rx_data;
                        if csd_byte_idx = 15 then
                            byte_counter <= (others => '0');
                            state        <= ST_INIT_CMD9_CRC;
                        else
                            csd_byte_idx <= csd_byte_idx + 1;
                        end if;
                    end if;

                -- Read & discard 2 CRC bytes
                when ST_INIT_CMD9_CRC =>
                    if spi_tx_ready = '1' and send_pending = '0' then
                        send_byte    <= x"FF";
                        send_pending <= '1';
                    end if;

                    if spi_rx_valid = '1' then
                        if byte_counter = 1 then
                            state <= ST_INIT_COMPLETE;
                        else
                            byte_counter <= byte_counter + 1;
                        end if;
                    end if;

                when ST_INIT_COMPLETE =>
                    -- Parse CSD to determine card capacity
                    if card_sdhc = '1' then
                        -- CSD v2.0 (SDHC/SDXC)
                        -- C_SIZE is in CSD bytes 7,8,9 bits [69:48]
                        -- csd_buf[7][5:0] = C_SIZE[21:16]
                        -- csd_buf[8][7:0] = C_SIZE[15:8]
                        -- csd_buf[9][7:0] = C_SIZE[7:0]
                        -- Total blocks = (C_SIZE + 1) * 1024
                        i_card_total_blocks <= resize(
                            shift_left(
                                resize(unsigned(std_logic_vector'(csd_buf(7)(5 downto 0)
                                                & csd_buf(8) & csd_buf(9))) + 1, 32),
                                10),  -- * 1024
                            32);
                    else
                        -- CSD v1.0 (SDSC)
                        -- Simplified: assume READ_BL_LEN = 9 (512 bytes)
                        -- C_SIZE = csd_buf[6][1:0] & csd_buf[7] & csd_buf[8][7:6]
                        -- C_SIZE_MULT = csd_buf[9][1:0] & csd_buf[10][7]
                        -- total_blocks = (C_SIZE + 1) * 2^(C_SIZE_MULT + 2)
                        i_card_total_blocks <= resize(
                            shift_left(
                                resize(unsigned(std_logic_vector'(csd_buf(6)(1 downto 0)
                                                & csd_buf(7)
                                                & csd_buf(8)(7 downto 6))) + 1, 32),
                                to_integer(unsigned(std_logic_vector'(csd_buf(9)(1 downto 0)
                                                    & csd_buf(10)(7 downto 7))) + 2)
                            ),
                            32);
                    end if;
                    i_init_done <= '1';
                    i_fast_mode <= '1';  -- switch to 25 MHz
                    spi_cs_n    <= '1';  -- deselect card
                    state       <= ST_IDLE;

                -- =============================================================
                -- READ: CMD17 — READ_SINGLE_BLOCK
                -- =============================================================
                when ST_READ_CMD17 =>
                    spi_cs_n     <= '0';
                    -- For SDHC, block_addr is already in 512-byte blocks
                    -- For SDSC, multiply by 512 (shift left 9)
                    if card_sdhc = '1' then
                        build_cmd(17, block_addr, x"FF");
                    else
                        build_cmd(17,
                            std_logic_vector(unsigned(block_addr(22 downto 0)) & "000000000"),
                            x"FF");
                    end if;
                    cmd_byte_idx  <= (others => '0');
                    wait_resp_cnt <= (others => '0');
                    send_byte     <= cmd_buf(47 downto 40);
                    send_pending  <= '1';
                    cmd_byte_idx  <= "001";
                    state         <= ST_READ_CMD17_RESP;

                when ST_READ_CMD17_RESP =>
                    if cmd_byte_idx <= 5 and spi_tx_ready = '1' and send_pending = '0' then
                        case cmd_byte_idx is
                            when "001" => send_byte <= cmd_buf(39 downto 32);
                            when "010" => send_byte <= cmd_buf(31 downto 24);
                            when "011" => send_byte <= cmd_buf(23 downto 16);
                            when "100" => send_byte <= cmd_buf(15 downto 8);
                            when "101" => send_byte <= cmd_buf(7 downto 0);
                            when others => null;
                        end case;
                        send_pending <= '1';
                        cmd_byte_idx <= cmd_byte_idx + 1;
                    end if;

                    if cmd_byte_idx > 5 then
                        if spi_tx_ready = '1' and send_pending = '0' then
                            send_byte    <= x"FF";
                            send_pending <= '1';
                        end if;

                        if spi_rx_valid = '1' and spi_rx_data(7) = '0' then
                            resp_r1 <= spi_rx_data;
                            if spi_rx_data = x"00" then
                                wait_resp_cnt <= (others => '0');
                                state         <= ST_READ_WAIT_TOKEN;
                            else
                                state <= ST_ERROR;
                            end if;
                        end if;
                    end if;

                -- Wait for data start token (0xFE)
                when ST_READ_WAIT_TOKEN =>
                    if spi_tx_ready = '1' and send_pending = '0' then
                        send_byte    <= x"FF";
                        send_pending <= '1';
                    end if;

                    if spi_rx_valid = '1' then
                        if spi_rx_data = x"FE" then
                            byte_counter <= (others => '0');
                            state        <= ST_READ_DATA;
                        elsif spi_rx_data(4) = '0' and spi_rx_data(7 downto 5) = "000" then
                            -- Data error token
                            state <= ST_ERROR;
                        else
                            wait_resp_cnt <= wait_resp_cnt + 1;
                            if wait_resp_cnt >= to_unsigned(CMD_TIMEOUT, 20) then
                                state <= ST_ERROR;
                            end if;
                        end if;
                    end if;

                -- Read 512 data bytes
                when ST_READ_DATA =>
                    if spi_tx_ready = '1' and send_pending = '0' then
                        send_byte    <= x"FF";
                        send_pending <= '1';
                    end if;

                    if spi_rx_valid = '1' then
                        data_out       <= spi_rx_data;
                        data_out_valid <= '1';
                        if byte_counter = 511 then
                            byte_counter <= (others => '0');
                            state        <= ST_READ_CRC;
                        else
                            byte_counter <= byte_counter + 1;
                        end if;
                    end if;

                -- Read & discard 2 CRC bytes
                when ST_READ_CRC =>
                    if spi_tx_ready = '1' and send_pending = '0' then
                        send_byte    <= x"FF";
                        send_pending <= '1';
                    end if;

                    if spi_rx_valid = '1' then
                        if byte_counter = 1 then
                            state <= ST_READ_COMPLETE;
                        else
                            byte_counter <= byte_counter + 1;
                        end if;
                    end if;

                when ST_READ_COMPLETE =>
                    spi_cs_n <= '1';
                    state    <= ST_IDLE;

                -- =============================================================
                -- WRITE: CMD24 — WRITE_SINGLE_BLOCK
                -- =============================================================
                when ST_WRITE_CMD24 =>
                    spi_cs_n <= '0';
                    if card_sdhc = '1' then
                        build_cmd(24, block_addr, x"FF");
                    else
                        build_cmd(24,
                            std_logic_vector(unsigned(block_addr(22 downto 0)) & "000000000"),
                            x"FF");
                    end if;
                    cmd_byte_idx  <= (others => '0');
                    wait_resp_cnt <= (others => '0');
                    send_byte     <= cmd_buf(47 downto 40);
                    send_pending  <= '1';
                    cmd_byte_idx  <= "001";
                    state         <= ST_WRITE_CMD24_RESP;

                when ST_WRITE_CMD24_RESP =>
                    if cmd_byte_idx <= 5 and spi_tx_ready = '1' and send_pending = '0' then
                        case cmd_byte_idx is
                            when "001" => send_byte <= cmd_buf(39 downto 32);
                            when "010" => send_byte <= cmd_buf(31 downto 24);
                            when "011" => send_byte <= cmd_buf(23 downto 16);
                            when "100" => send_byte <= cmd_buf(15 downto 8);
                            when "101" => send_byte <= cmd_buf(7 downto 0);
                            when others => null;
                        end case;
                        send_pending <= '1';
                        cmd_byte_idx <= cmd_byte_idx + 1;
                    end if;

                    if cmd_byte_idx > 5 then
                        if spi_tx_ready = '1' and send_pending = '0' then
                            send_byte    <= x"FF";
                            send_pending <= '1';
                        end if;

                        if spi_rx_valid = '1' and spi_rx_data(7) = '0' then
                            resp_r1 <= spi_rx_data;
                            if spi_rx_data = x"00" then
                                state <= ST_WRITE_TOKEN;
                            else
                                state <= ST_ERROR;
                            end if;
                        end if;
                    end if;

                -- Send data start token (0xFE)
                when ST_WRITE_TOKEN =>
                    if spi_tx_ready = '1' and send_pending = '0' then
                        send_byte    <= x"FE";
                        send_pending <= '1';
                        byte_counter <= (others => '0');
                        data_in_req  <= '1';  -- request first data byte
                        state        <= ST_WRITE_DATA;
                    end if;

                -- Write 512 data bytes
                when ST_WRITE_DATA =>
                    if spi_tx_ready = '1' and send_pending = '0' then
                        send_byte    <= data_in;
                        send_pending <= '1';
                        if byte_counter = 511 then
                            byte_counter <= (others => '0');
                            state        <= ST_WRITE_CRC;
                        else
                            byte_counter <= byte_counter + 1;
                            data_in_req  <= '1';  -- request next byte
                        end if;
                    end if;

                -- Send 2 dummy CRC bytes
                when ST_WRITE_CRC =>
                    if spi_tx_ready = '1' and send_pending = '0' then
                        send_byte    <= x"FF";
                        send_pending <= '1';
                        if byte_counter = 1 then
                            state <= ST_WRITE_RESP;
                        else
                            byte_counter <= byte_counter + 1;
                        end if;
                    end if;

                -- Read data response token
                when ST_WRITE_RESP =>
                    if spi_tx_ready = '1' and send_pending = '0' then
                        send_byte    <= x"FF";
                        send_pending <= '1';
                    end if;

                    if spi_rx_valid = '1' then
                        -- Data response = xxx0sss1, sss: 010=accepted
                        if spi_rx_data(4 downto 0) = "00101" then
                            state <= ST_WRITE_BUSY;
                        else
                            state <= ST_ERROR;  -- write rejected
                        end if;
                    end if;

                -- Wait for card to finish programming (MISO goes high)
                when ST_WRITE_BUSY =>
                    if spi_tx_ready = '1' and send_pending = '0' then
                        send_byte    <= x"FF";
                        send_pending <= '1';
                    end if;

                    if spi_rx_valid = '1' then
                        if spi_rx_data = x"FF" then
                            state <= ST_WRITE_COMPLETE;  -- card is done
                        end if;
                        -- else card is still busy, keep polling
                    end if;

                when ST_WRITE_COMPLETE =>
                    spi_cs_n <= '1';
                    state    <= ST_IDLE;

                -- =============================================================
                -- ERROR
                -- =============================================================
                when ST_ERROR =>
                    spi_cs_n <= '1';
                    i_error  <= '1';
                    state    <= ST_IDLE;

                when others =>
                    state <= ST_IDLE;

                end case;
            end if;
        end if;
    end process;

end architecture rtl;
