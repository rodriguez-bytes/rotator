----------------------------------------------------------------------------------
-- company: 	 Rogerson Aircraft
-- engineer: 	 Gerardo Rodriguez
-- module name:  rotator
-- project name: fusion
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity rotator is
	port (
		i_clk                     : in  std_logic;
		i_mpmc_init_done          : in  std_logic;
		i_mpmc_rdfifo_latency     : in  std_logic_vector(1 downto 0);
		i_mpmc_rdfifo_flush       : out std_logic := '0';
		i_mpmc_rdfifo_empty       : in  std_logic;
		o_mpmc_wrfifo_flush       : out std_logic := '0';
		i_mpmc_wrfifo_almost_full : in  std_logic;
		i_mpmc_wrfifo_empty       : in  std_logic;
		i_mpmc_rdfifo_rdwdaddr    : in  std_logic_vector(3 downto 0);
		o_mpmc_rd_pop             : out std_logic := '0';
		i_mpmc_rd_data            : in  std_logic_vector(63 downto 0);
		o_mpmc_wr_push            : out std_logic := '0';
		o_mpmc_wrfifo_be          : out std_logic_vector(7 downto 0);
		o_mpmc_wr_data            : out std_logic_vector(63 downto 0);
		o_mpmc_rdmodwr            : out std_logic;
		o_mpmc_size               : out std_logic_vector(3 downto 0);
		o_mpmc_rnw                : out std_logic;
		i_mpmc_addr_ack           : in  std_logic;
		o_mpmc_addr_req           : out std_logic := '0';
		o_mpmc_addr               : out std_logic_vector(31 downto 0) := (others => '0')
	);
end rotator;

architecture behavioral of rotator is

	component array_2d
		port (
			i_clk             : in  std_logic;
			i_burst_size      : in  integer;
			i_burst_count_max : in  integer;
			i_data            : in  std_logic_vector(63 downto 0);
			o_data            : out std_logic_vector(63 downto 0);
			i_wr_burst        : in  std_logic;
			i_rd_burst        : in  std_logic;
			o_empty           : out std_logic;
			o_full            : out std_logic;
			i_rst             : in  std_logic;
			o_rst_ack         : out std_logic
		);
	end component array_2d;

	constant c_burst_size : integer := 4;
	constant c_burst_count_max : integer := 16;
	constant c_full_line_width : std_logic_vector(11 downto 0) := x"800";
	constant c_quad_width : std_logic_vector(7 downto 0) := x"20";
	constant c_quad_height : std_logic_vector(15 downto 0) := x"8000";
	
	type t_addr_req is (s_idle_req, s_rd_addr_req, s_wr_addr_req, s_wait_one_cycle);
	signal state_addr_req : t_addr_req := s_idle_req;

	type t_rd_mem is (s_check_mpmc_init_done, s_addr_req, s_addr_ack, s_check_mpmc_rdfifo_empty, s_rd_pop, s_check_rd_burst_count_max, s_idle);
--	type t_rd_mem is (s_check_mpmc_init_done, s_addr_req, s_check_mpmc_rdfifo_empty, s_rd_pop, s_check_rd_burst_count_max, s_idle);
	signal state_rd_mem : t_rd_mem := s_check_mpmc_init_done;
	signal my_rd_addr_req, my_rd_addr_ack : std_logic := '0';
	signal rd_burst_count, rd_pop_count : integer := 0;
	signal rd_mem_done, rd_quad_done, rd_quad_done_ack : boolean := false;
	
	type t_addr_gen is (s_rst, s_gen);
	signal state_addr_gen : t_addr_gen := s_rst;
	signal burst_count : integer := 1;
	signal rd_addr : std_logic_vector(31 downto 0) := (others => '0');
	signal rd_addr_base : std_logic_vector(7 downto 0) := x"92";
	signal rd_x, rd_y : std_logic_vector(23 downto 0) := (others => '0');
	signal rd_y_offset : std_logic_vector(23 downto 0) := (others => '0');
	signal rd_quad_row_end : boolean := false;
	signal rd_frame_end : boolean := false;
	signal wr_addr : std_logic_vector(31 downto 0) := (others => '0');
	signal wr_addr_base : std_logic_vector(7 downto 0) := x"93"; 
	signal wr_x, wr_y : std_logic_vector(23 downto 0) := (others => '0');
	signal y_offset : std_logic_vector(23 downto 0) := (others => '0');
	signal wr_y_offset : std_logic_vector(23 downto 0) := (others => '0');

	type t_wr_mem is (s_check_mpmc_init_done, s_idle, s_wait_one_cycle, s_prep, s_wr_push, s_addr_ack, s_check_wrfifo_empty, s_check_wr_burst_count_max);
	signal state_wr_mem : t_wr_mem := s_check_mpmc_init_done;
	signal my_wr_addr_req, my_wr_addr_ack                          : std_logic                     := '0';
	signal wr_push_count                        : integer                       := 1;
	signal wr_burst_count                       : integer                       := 0;
	signal wr_mem_done, wr_quad_done, wr_quad_done_ack : boolean                       := false;

	-- note:
	-- for 16-bit color =>  |15|14|13|12|11|10|09|08|07|06|04|03|02|01|00| 
	----------------------  |--|gr|gr|gr|gr|--|bl|bl|bl|bl|--|rd|rd|rd|rd| 
	
	signal red   : std_logic_vector(15 downto 0) := x"001f";
	signal green : std_logic_vector(15 downto 0) := x"7c00";
	signal blue  : std_logic_vector(15 downto 0) := x"03e0";
	signal rgbr  : std_logic_vector(63 downto 0);
	
	signal pix_array_wr, pix_array_rd, pix_array_empty, pix_array_full, pix_array_rst, pix_array_rst_ack : std_logic := '0';
	signal rd_rst, wr_rst : std_logic := '0';
	
-- This signal was needed only for testbenches so that it can be enabled at the same time "o_mpmc_addr_req" is enabled but raised for a few more clock cycles.
-- Otherwise, I could not tell when "o_mpmc_addr_req" was asserted -- it does not show up on the testbench since it is deasserted in the same clock cycle.
-- Technically, it can be taken out when not evaluating with a testbench.
	signal my_addr_req_hold : std_logic := '0';
	
begin

	rgbr <= red & green & blue & red; -- four pixels, one burst length

	process_addr_req : process (i_clk, my_rd_addr_req, my_wr_addr_req, i_mpmc_addr_ack)
	begin
		if rising_edge (i_clk) then
			case state_addr_req is
				
				when s_idle_req =>
					my_addr_req_hold <= '0';
					o_mpmc_addr_req  <= '0';
					my_rd_addr_ack   <= '0';
					my_wr_addr_ack   <= '0';
					if my_wr_addr_req = '1' then
						state_addr_req <= s_wr_addr_req;
					elsif my_rd_addr_req = '1' then
						state_addr_req <= s_rd_addr_req;
					end if;
					
				when s_rd_addr_req =>
					o_mpmc_addr_req  <= '1';
					my_addr_req_hold <= '1';
					o_mpmc_addr      <= rd_addr;
					o_mpmc_rnw       <= '1';
					o_mpmc_size      <= x"2";
					o_mpmc_rdmodwr   <= '0';
					if i_mpmc_addr_ack = '1' then
						o_mpmc_addr_req <= '0';
						my_rd_addr_ack  <= '1';
						state_addr_req  <= s_wait_one_cycle;
					end if;
						
				when s_wr_addr_req =>
					o_mpmc_addr_req  <= '1';
					my_addr_req_hold <= '1';
					o_mpmc_addr      <= wr_addr;
					o_mpmc_rnw       <= '0';
					o_mpmc_size      <= x"2";
					o_mpmc_rdmodwr   <= '0';
					if i_mpmc_addr_ack = '1' then
						o_mpmc_addr_req <= '0';
						my_wr_addr_ack  <= '1';
						state_addr_req  <= s_wait_one_cycle;
					end if;
			
			-- needed to wait one more cycle for the "my_xx_addr_ack" signals to be read from the processes listening to them
				when s_wait_one_cycle =>
					state_addr_req <= s_idle_req;
					
				when others =>
					state_addr_req <= s_idle_req;
					
			end case state_addr_req;
		end if;
	end process process_addr_req;

	process_rd_mem : process (i_clk, i_mpmc_init_done, my_rd_addr_ack, i_mpmc_rdfifo_empty, rd_pop_count, rd_burst_count, rd_quad_done_ack, wr_quad_done)
	begin
		if rising_edge (i_clk) then
			case state_rd_mem is
				
				when s_check_mpmc_init_done =>
					if i_mpmc_init_done = '1' then
						state_rd_mem <= s_addr_req;
					else 
						state_rd_mem <= s_check_mpmc_init_done;
					end if;
			
				when s_addr_req =>
					my_rd_addr_req <= '1';
					state_rd_mem   <= s_addr_ack;

				when s_addr_ack => 
			--	when s_addr_req => 
				--	my_rd_addr_req   <= '1';
					wr_quad_done_ack <= false;
					if my_rd_addr_ack = '1' then	
						my_rd_addr_req <= '0';
						state_rd_mem   <= s_check_mpmc_rdfifo_empty;
					else 
						my_rd_addr_req <= '1';
						state_rd_mem   <= s_addr_ack;
					--	state_rd_mem   <= s_addr_req;
					end if;
				
				when s_check_mpmc_rdfifo_empty =>
					if i_mpmc_rdfifo_empty = '0' then
						o_mpmc_rd_pop  <= '1';
						rd_burst_count <= rd_burst_count + 1; 
						state_rd_mem   <= s_rd_pop;
					else 
						o_mpmc_rd_pop  <= '0';
						rd_burst_count <= rd_burst_count; 
						state_rd_mem   <= s_check_mpmc_rdfifo_empty;
					end if;
				
-- have to look at testbench for how to replace ">=" to "="
				when s_rd_pop =>
					rd_pop_count <= rd_pop_count + 1;
					pix_array_wr <= '1';
					if rd_pop_count >= 1 then
						pix_array_wr <= '0';
							if rd_pop_count >= 3 then
								pix_array_wr <= '0';
								o_mpmc_rd_pop <= '0';
								if rd_pop_count >= 4 then     
									rd_mem_done <= true;
									rd_pop_count <= 0;
									state_rd_mem <= s_check_rd_burst_count_max;
								end if;
							end if;
					end if;
				
				when s_check_rd_burst_count_max =>
					rd_mem_done <= false;
					if rd_burst_count = c_burst_count_max then 
						rd_quad_done   <= true;
						rd_burst_count <= 0;
						state_rd_mem   <= s_idle;
					else 
						rd_quad_done   <= false;
						rd_burst_count <= rd_burst_count;
						my_rd_addr_req <= '1';
						state_rd_mem   <= s_addr_ack;
					--	state_rd_mem   <= s_addr_req;
					end if;
				
				when s_idle =>
					if rd_quad_done_ack = true then
						rd_quad_done <= false;
					end if;
					if wr_quad_done = true then
						wr_quad_done_ack <= true;
						my_rd_addr_req   <= '1';
						state_rd_mem     <= s_addr_ack;
					--	state_rd_mem     <= s_addr_req;
					else
						wr_quad_done_ack <= false;
						my_rd_addr_req   <= '0';
						state_rd_mem     <= s_idle;
					end if;
				
				when others =>
					state_rd_mem <= s_check_mpmc_init_done;
				
			end case state_rd_mem;
		end if;
	end process process_rd_mem;

	rd_addr <= rd_addr_base & (rd_y + rd_x + rd_y_offset); 
--	wr_addr <= wr_addr_base & (wr_y + wr_x + wr_y_offset); -- no rotation
	wr_addr <= wr_addr_base & (wr_y - wr_x - x"260");         -- cw
--	wr_addr <= wr_addr_base & (wr_x + wr_y);                  -- ccw
--	wr_addr <= wr_addr_base & (wr_x + wr_y - y_offset);       -- vertical 180

	process_addr_gen : process (i_clk, rd_mem_done, rd_y, rd_x, rd_y_offset, wr_mem_done, burst_count, wr_x, wr_y_offset)
	begin
		if rising_edge (i_clk) then
			case state_addr_gen is
			
				when s_rst =>
					rd_frame_end         <= false;
					rd_x              <= (others => '0');
					rd_y              <= (others => '0');
					rd_y_offset      <= (others => '0');
					burst_count         <= 1;
					state_addr_gen <= s_gen;
				-- no rotation
--					wr_x              <= (others => '0');
--					wr_y              <= (others => '0');
--					wr_y_offset    <= (others => '0');
				-- cw
					wr_x              <= x"000020"; 
					wr_y              <= x"000800"; 
				-- ccw
--					wr_x              <= x"000000";
--					wr_y              <= x"178000";			
				-- vertical 180
--					wr_x              <= x"0007c0";
--					wr_y              <= x"178000"; 
--					y_offset          <= x"000000";
				
				when s_gen =>
					
					
					if rd_mem_done = true then
						rd_y      <= rd_y + x"800";
						burst_count <= burst_count + 1;
						if burst_count = 16 then
							rd_x      <= rd_x + x"20"; 
							burst_count <= 1;
							rd_y      <= (others => '0');
							if rd_x = x"5e0" then
								rd_quad_row_end <= true;
								rd_x         <= (others => '0');
								rd_y_offset <= rd_y_offset + x"8000"; 
								if rd_y_offset = x"f0000" then 
									rd_frame_end <= true;
								--	state_addr_gen <= s_rst; -- uncomment for correct code
								else state_addr_gen <= s_gen;
								end if;
							else state_addr_gen <= s_gen;
							end if;
						else state_addr_gen <= s_gen;
						end if;
					else state_addr_gen <= s_gen;
					end if;
					
					if wr_mem_done = true then
					-- no rotatation
--						wr_y      <= wr_y + x"800"; 
--						burst_count <= burst_count + 1;
--						if burst_count = 16 then -- 
--							burst_count <= 1; 
--							wr_x      <= wr_x + x"20"; 
--							wr_y      <= (others => '0');
--							if rd_quad_row_end = true then 
--								rd_quad_row_end <= false;
--								wr_x           <= (others => '0');
--								wr_y_offset <= wr_y_offset + x"8000"; 
--								if rd_frame_end = true then 
--									state_addr_gen <= s_rst;
--								else state_addr_gen <= s_gen;
--								end if;
--							else state_addr_gen <= s_gen;
--							end if;
--						else state_addr_gen <= s_gen;
--						end if;

					-- cw
						wr_y      <= wr_y + x"800";
						burst_count <= burst_count + 1;
						if burst_count = 16 then
							burst_count <= 1;
							if rd_quad_row_end = true then
								rd_quad_row_end <= false;
								if rd_frame_end = true then
									state_addr_gen <= s_rst;
								else 
									wr_x <= wr_x + x"20";
									wr_y <= x"000800";
								end if;
							end if;
						end if;

					-- ccw
--						wr_y      <= wr_y - x"800";
--						burst_count <= burst_count + 1;
--						if burst_count = 16 then
--							burst_count <= 1;
--							if rd_quad_row_end = true then
--								rd_quad_row_end <= false;
--								if rd_frame_end = true then
--									state_addr_gen <= s_rst;
--								else 
--									wr_y             <= x"00178000";
--									wr_x             <= wr_x + x"20";
--								end if;
--							end if;
--						end if;

					-- vertical 180
--					--	wr_y             <= wr_y - x"800";
--						wr_y             <= wr_y + x"800";
--						burst_count        <= burst_count + 1;
--						if burst_count = 16 then
--							burst_count <= 1;
--							wr_x      <= wr_x - x"20";
--						--	wr_y      <= x"00178000";
--							wr_y      <= wr_y - x"7800";
--							if rd_quad_row_end = true then
--						--	if wr_x = x"00000000" then
--								rd_quad_row_end     <= false;
--								wr_x             <= x"000007c0";
--								y_offset         <= y_offset + x"8000"; 
--								if rd_frame_end = true then 
--							--	if y_offset >= x"e8800" then 
--									state_addr_gen <= s_rst;
--								else state_addr_gen <= s_gen;
--								end if;
--							else state_addr_gen <= s_gen;
--							end if;
--						end if;

					end if;
				
				when others =>
					state_addr_gen <= s_rst;
				
			end case state_addr_gen;
		end if;
	end process process_addr_gen;

	o_mpmc_wrfifo_be <= "11111111";
	process_wr_mem : process (i_clk, i_mpmc_init_done, i_mpmc_wrfifo_empty, wr_push_count, my_wr_addr_ack, wr_quad_done, wr_quad_done_ack, rd_quad_done)
	begin
		if rising_edge (i_clk) then
			case state_wr_mem is
			
				when s_check_mpmc_init_done =>
					if i_mpmc_init_done = '1' then
						state_wr_mem <= s_idle;
					else 
						state_wr_mem <= s_check_mpmc_init_done;
					end if;
			
				when s_idle	=>
					if wr_quad_done_ack = true then
						wr_quad_done <= false;
					end if;
					if rd_quad_done = true then
						rd_quad_done_ack <= true;
						pix_array_rd     <= '1';
						state_wr_mem     <= s_wait_one_cycle;
					else 
						rd_quad_done_ack <= false;
						pix_array_rd     <= '0';
						state_wr_mem     <= s_idle;
					end if;
				
				when s_wait_one_cycle => 
					rd_quad_done_ack <= false;
					pix_array_rd     <= '0'; -- edit 1, added
					state_wr_mem     <= s_prep;

				when s_prep =>
					wr_burst_count <= wr_burst_count + 1;
					o_mpmc_wr_push <= '1';
					state_wr_mem   <= s_wr_push; 
				
-- could probably merge "s_wr_push" and "s_addr_ack"
-- "s_addr_ack" is still looking at "my_wr_addr_ack", even though "my_wr_addr_req" was asserted and deasserted a couple clock cycles ago
				when s_wr_push =>
				--	pix_array_rd <= '0'; -- edit 1, removed
					wr_push_count <= wr_push_count + 1;	
					if wr_push_count >= 1 then 
						my_wr_addr_req <= '1'; -- asserted
						if wr_push_count >= 2 then
							my_wr_addr_req <= '0'; -- deasserted
							if wr_push_count >= 4 then 
								wr_push_count <= 1;	
								o_mpmc_wr_push <= '0';
								state_wr_mem <=  s_addr_ack;
							else 
								state_wr_mem <= s_wr_push;
							end if;
						end if;
					end if; 
				when s_addr_ack =>
					if my_wr_addr_ack = '1' then -- still checking
						my_wr_addr_req <= '0';
						state_wr_mem <= s_check_wrfifo_empty;
						wr_mem_done      <= true;
					end if;

				when s_check_wrfifo_empty =>
					wr_mem_done <= false;
					if i_mpmc_wrfifo_empty = '1' then 
						state_wr_mem <= s_check_wr_burst_count_max;
					else 
						state_wr_mem <= s_check_wrfifo_empty;
					end if;
				 
				when s_check_wr_burst_count_max =>
					if wr_burst_count = c_burst_count_max then 
						wr_quad_done <= true;
						wr_burst_count <= 0;
						state_wr_mem <= s_idle;
					else  
						wr_quad_done <= false;
						wr_burst_count <= wr_burst_count;
						pix_array_rd <= '1';
						state_wr_mem <= s_wait_one_cycle;
					end if;
				
				when others =>
					state_wr_mem <= s_check_mpmc_init_done; 
					
			end case;
		end if; 
	end process process_wr_mem;

	pix_array : array_2d
		port map (
			i_clk             => i_clk,        
			i_burst_size      => c_burst_size,
			i_burst_count_max => c_burst_count_max,
			i_data            => i_mpmc_rd_data,
			o_data            => o_mpmc_wr_data,
			i_wr_burst        => pix_array_wr,        
			i_rd_burst        => pix_array_rd,        
			o_empty           => pix_array_empty,     
			o_full            => pix_array_full,      
			i_rst             => pix_array_rst,       
			o_rst_ack         => pix_array_rst_ack
		);  

end behavioral;