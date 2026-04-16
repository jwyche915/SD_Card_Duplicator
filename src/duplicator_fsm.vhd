--------------------------------------------------------------------------------
-- duplicator_fsm.vhd
-- High-level state machine for SD-to-SD card duplication.
--
-- Flow:
--   IDLE → INIT_SRC → INIT_DST → READ_BLOCK → WRITE_BLOCK → NEXT_BLOCK
--        → (loop until all blocks copied) → DONE
--
-- A 512-byte block RAM buffer is used to hold one block at a time.
-- The block count to copy is configurable via the total_blocks input.
-- Progress is reported via current_block output.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity duplicator_fsm is
    port (
        clk           : in  std_logic;
        reset         : in  std_logic;

        -- User controls
        start         : in  std_logic;              -- pulse to begin duplication
        total_blocks  : in  std_logic_vector(31 downto 0);  -- blocks to copy

        -- Status
        current_block : out std_logic_vector(31 downto 0);
        fsm_idle      : out std_logic;
        fsm_copying   : out std_logic;
        fsm_done      : out std_logic;
        fsm_error     : out std_logic;

        -- Source SD card controller interface
        src_cmd_init   : out std_logic;
        src_cmd_read   : out std_logic;
        src_block_addr : out std_logic_vector(31 downto 0);
        src_busy       : in  std_logic;
        src_error      : in  std_logic;
        src_init_done  : in  std_logic;
        src_data_out   : in  std_logic_vector(7 downto 0);
        src_data_out_v : in  std_logic;

        -- Destination SD card controller interface
        dst_cmd_init   : out std_logic;
        dst_cmd_write  : out std_logic;
        dst_block_addr : out std_logic_vector(31 downto 0);
        dst_busy       : in  std_logic;
        dst_error      : in  std_logic;
        dst_init_done  : in  std_logic;
        dst_data_in    : out std_logic_vector(7 downto 0);
        dst_data_in_req: in  std_logic
    );
end entity duplicator_fsm;

architecture rtl of duplicator_fsm is

    type state_t is (
        ST_IDLE,
        ST_INIT_SRC,
        ST_WAIT_INIT_SRC,
        ST_INIT_DST,
        ST_WAIT_INIT_DST,
        ST_READ_BLOCK,
        ST_WAIT_READ,
        ST_WRITE_BLOCK,
        ST_WAIT_WRITE,
        ST_NEXT_BLOCK,
        ST_DONE,
        ST_ERROR
    );

    signal state : state_t := ST_IDLE;

    -- Block address counter
    signal block_cnt  : unsigned(31 downto 0) := (others => '0');
    signal total_blks : unsigned(31 downto 0) := (others => '0');

    -- 512-byte block buffer (dual-port inferred RAM)
    type ram_t is array (0 to 511) of std_logic_vector(7 downto 0);
    signal buf_ram : ram_t := (others => (others => '0'));

    -- Buffer write pointer (during read from source)
    signal wr_ptr : unsigned(8 downto 0) := (others => '0');
    -- Buffer read pointer (during write to destination)
    signal rd_ptr : unsigned(8 downto 0) := (others => '0');

begin

    current_block <= std_logic_vector(block_cnt);

    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state        <= ST_IDLE;
                block_cnt    <= (others => '0');
                total_blks   <= (others => '0');
                wr_ptr       <= (others => '0');
                rd_ptr       <= (others => '0');
                src_cmd_init <= '0';
                src_cmd_read <= '0';
                dst_cmd_init <= '0';
                dst_cmd_write<= '0';
                fsm_idle     <= '1';
                fsm_copying  <= '0';
                fsm_done     <= '0';
                fsm_error    <= '0';
            else
                -- Default de-assertions
                src_cmd_init  <= '0';
                src_cmd_read  <= '0';
                dst_cmd_init  <= '0';
                dst_cmd_write <= '0';

                case state is

                -- =============================================================
                when ST_IDLE =>
                    fsm_idle    <= '1';
                    fsm_copying <= '0';
                    fsm_done    <= '0';
                    fsm_error   <= '0';

                    if start = '1' then
                        total_blks <= unsigned(total_blocks);
                        block_cnt  <= (others => '0');
                        fsm_idle   <= '0';
                        state      <= ST_INIT_SRC;
                    end if;

                -- =============================================================
                -- Initialize source card
                -- =============================================================
                when ST_INIT_SRC =>
                    src_cmd_init <= '1';
                    state        <= ST_WAIT_INIT_SRC;

                when ST_WAIT_INIT_SRC =>
                    if src_error = '1' then
                        state <= ST_ERROR;
                    elsif src_init_done = '1' then
                        state <= ST_INIT_DST;
                    end if;
                    -- else keep waiting

                -- =============================================================
                -- Initialize destination card
                -- =============================================================
                when ST_INIT_DST =>
                    dst_cmd_init <= '1';
                    state        <= ST_WAIT_INIT_DST;

                when ST_WAIT_INIT_DST =>
                    if dst_error = '1' then
                        state <= ST_ERROR;
                    elsif dst_init_done = '1' then
                        state <= ST_READ_BLOCK;
                    end if;

                -- =============================================================
                -- Read one 512-byte block from source
                -- =============================================================
                when ST_READ_BLOCK =>
                    fsm_copying    <= '1';
                    src_block_addr <= std_logic_vector(block_cnt);
                    src_cmd_read   <= '1';
                    wr_ptr         <= (others => '0');
                    state          <= ST_WAIT_READ;

                when ST_WAIT_READ =>
                    -- Capture data bytes as they arrive from the source controller
                    if src_data_out_v = '1' then
                        buf_ram(to_integer(wr_ptr)) <= src_data_out;
                        wr_ptr <= wr_ptr + 1;
                    end if;

                    if src_error = '1' then
                        state <= ST_ERROR;
                    elsif src_busy = '0' and wr_ptr >= 512 then
                        -- Read complete
                        state <= ST_WRITE_BLOCK;
                    end if;

                -- =============================================================
                -- Write the buffered block to destination
                -- =============================================================
                when ST_WRITE_BLOCK =>
                    dst_block_addr <= std_logic_vector(block_cnt);
                    dst_cmd_write  <= '1';
                    rd_ptr         <= (others => '0');
                    state          <= ST_WAIT_WRITE;

                when ST_WAIT_WRITE =>
                    -- Supply data bytes when the destination controller requests them
                    if dst_data_in_req = '1' then
                        dst_data_in <= buf_ram(to_integer(rd_ptr));
                        rd_ptr      <= rd_ptr + 1;
                    end if;

                    if dst_error = '1' then
                        state <= ST_ERROR;
                    elsif dst_busy = '0' and rd_ptr >= 512 then
                        state <= ST_NEXT_BLOCK;
                    end if;

                -- =============================================================
                -- Advance to next block or finish
                -- =============================================================
                when ST_NEXT_BLOCK =>
                    block_cnt <= block_cnt + 1;
                    if (block_cnt + 1) >= total_blks then
                        state <= ST_DONE;
                    else
                        state <= ST_READ_BLOCK;
                    end if;

                -- =============================================================
                when ST_DONE =>
                    fsm_copying <= '0';
                    fsm_done    <= '1';
                    -- Stay here until reset or new start

                    if start = '1' then
                        state <= ST_IDLE;
                    end if;

                -- =============================================================
                when ST_ERROR =>
                    fsm_copying <= '0';
                    fsm_error   <= '1';

                    if start = '1' then
                        state <= ST_IDLE;
                    end if;

                when others =>
                    state <= ST_IDLE;

                end case;
            end if;
        end if;
    end process;

end architecture rtl;
