----------------------------------------------------------------------------------
-- company: 	  rogerson aircraft
-- engineer: 	  gerardo rodriguez
-- module name:  rotator/array_2d
-- project name: fusion
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity array_2d is
	port (
			i_clk             : in  std_logic;
			i_burst_size      : in  integer;
			i_burst_count_max : in  integer;
			i_data            : in  std_logic_vector(63 downto 0);
			o_data            : out std_logic_vector(63 downto 0) := (others => '0');
			i_wr_burst        : in  std_logic;
			i_rd_burst        : in  std_logic;
			o_empty           : out std_logic := '0';
			o_full            : out std_logic := '0';
			i_rst             : in  std_logic;
			o_rst_ack         : out std_logic := '0'
	);
end array_2d;

architecture behavioral of array_2d is

	type   burst_array is array(1 to 4) of std_logic_vector(63 downto 0); -- declare array of four 64-bit vectors (burst width)
	type   burst_2d_array  is array(1 to 16) of burst_array; -- declare array of sixteen, four 64-bit arrays (16 x 16 pixel quad)
	signal iq : burst_2d_array; -- in quad
	signal oq : burst_2d_array; -- out quad
	signal dq : burst_2d_array; -- debug quad

	type   array_ctrl_type is (rst_s, wr_s, rd_s, idle_s);
	signal ctrl                : array_ctrl_type := rst_s; 
	signal a_wr_cnt, a_rd_cnt  : integer         := 1;
	signal b_wr_cnt, b_rd_cnt  : integer         := 1;
	signal my_full_flag, my_empty_flag : std_logic       := '0';
	
	signal r    : std_logic_vector(15 downto 0) := x"001f";
	signal g    : std_logic_vector(15 downto 0) := x"7c00";
	signal b    : std_logic_vector(15 downto 0) := x"03e0";
	signal rgbr : std_logic_vector(63 downto 0);
	
	signal red   : std_logic_vector(63 downto 0) := x"001f001f001f001f";
	signal green : std_logic_vector(63 downto 0) := x"7c007c007c007c00";
	signal blue  : std_logic_vector(63 downto 0) := x"03e003e003e003e0";
	
-- debug
	signal white : std_logic_vector(63 downto 0) := x"ffffffffffffffff";
	signal black : std_logic_vector(63 downto 0) := x"0000000000000000";
	signal white_pix : std_logic_vector(15 downto 0) := x"ffff";
	signal black_pix : std_logic_vector(15 downto 0) := x"0000";
	signal debug_switch : std_logic := '0';
--	signal black_quad : burst_2d_array;
--	signal white_quad : burst_2d_array;


begin
	
	rgbr <= r & g & b & r; -- four pixels
	
-- normal video, no change
--	oq(01)(01) <= iq(01)(01); oq(01)(02) <= iq(01)(02); oq(01)(03) <= iq(01)(03); oq(01)(04) <= iq(01)(04);
--	oq(02)(01) <= iq(02)(01); oq(02)(02) <= iq(02)(02); oq(02)(03) <= iq(02)(03); oq(02)(04) <= iq(02)(04);
--	oq(03)(01) <= iq(03)(01); oq(03)(02) <= iq(03)(02); oq(03)(03) <= iq(03)(03); oq(03)(04) <= iq(03)(04);
--	oq(04)(01) <= iq(04)(01); oq(04)(02) <= iq(04)(02); oq(04)(03) <= iq(04)(03); oq(04)(04) <= iq(04)(04);
--	oq(05)(01) <= iq(05)(01); oq(05)(02) <= iq(05)(02); oq(05)(03) <= iq(05)(03); oq(05)(04) <= iq(05)(04);
--	oq(06)(01) <= iq(06)(01); oq(06)(02) <= iq(06)(02); oq(06)(03) <= iq(06)(03); oq(06)(04) <= iq(06)(04);
--	oq(07)(01) <= iq(07)(01); oq(07)(02) <= iq(07)(02); oq(07)(03) <= iq(07)(03); oq(07)(04) <= iq(07)(04);
--	oq(08)(01) <= iq(08)(01); oq(08)(02) <= iq(08)(02); oq(08)(03) <= iq(08)(03); oq(08)(04) <= iq(08)(04);
--	oq(09)(01) <= iq(09)(01); oq(09)(02) <= iq(09)(02); oq(09)(03) <= iq(09)(03); oq(09)(04) <= iq(09)(04);
--	oq(10)(01) <= iq(10)(01); oq(10)(02) <= iq(10)(02); oq(10)(03) <= iq(10)(03); oq(10)(04) <= iq(10)(04);
--	oq(11)(01) <= iq(11)(01); oq(11)(02) <= iq(11)(02); oq(11)(03) <= iq(11)(03); oq(11)(04) <= iq(11)(04);
--	oq(12)(01) <= iq(12)(01); oq(12)(02) <= iq(12)(02); oq(12)(03) <= iq(12)(03); oq(12)(04) <= iq(12)(04);
--	oq(13)(01) <= iq(13)(01); oq(13)(02) <= iq(13)(02); oq(13)(03) <= iq(13)(03); oq(13)(04) <= iq(13)(04);
--	oq(14)(01) <= iq(14)(01); oq(14)(02) <= iq(14)(02); oq(14)(03) <= iq(14)(03); oq(14)(04) <= iq(14)(04);
--	oq(15)(01) <= iq(15)(01); oq(15)(02) <= iq(15)(02); oq(15)(03) <= iq(15)(03); oq(15)(04) <= iq(15)(04);
--	oq(16)(01) <= iq(16)(01); oq(16)(02) <= iq(16)(02); oq(16)(03) <= iq(16)(03); oq(16)(04) <= iq(16)(04);
	
-- rotate cw
	oq(01)(1) <= iq(13)(1)(15 downto 00) & iq(14)(1)(15 downto 00) & iq(15)(1)(15 downto 00) & iq(16)(1)(15 downto 00);
	oq(01)(2) <= iq(09)(1)(15 downto 00) & iq(10)(1)(15 downto 00) & iq(11)(1)(15 downto 00) & iq(12)(1)(15 downto 00);
	oq(01)(3) <= iq(05)(1)(15 downto 00) & iq(06)(1)(15 downto 00) & iq(07)(1)(15 downto 00) & iq(08)(1)(15 downto 00);
	oq(01)(4) <= iq(01)(1)(15 downto 00) & iq(02)(1)(15 downto 00) & iq(03)(1)(15 downto 00) & iq(04)(1)(15 downto 00);
	oq(02)(1) <= iq(13)(1)(31 downto 16) & iq(14)(1)(31 downto 16) & iq(15)(1)(31 downto 16) & iq(16)(1)(31 downto 16);
	oq(02)(2) <= iq(09)(1)(31 downto 16) & iq(10)(1)(31 downto 16) & iq(11)(1)(31 downto 16) & iq(12)(1)(31 downto 16);
	oq(02)(3) <= iq(05)(1)(31 downto 16) & iq(06)(1)(31 downto 16) & iq(07)(1)(31 downto 16) & iq(08)(1)(31 downto 16);
	oq(02)(4) <= iq(01)(1)(31 downto 16) & iq(02)(1)(31 downto 16) & iq(03)(1)(31 downto 16) & iq(04)(1)(31 downto 16);
	oq(03)(1) <= iq(13)(1)(47 downto 32) & iq(14)(1)(47 downto 32) & iq(15)(1)(47 downto 32) & iq(16)(1)(47 downto 32);
	oq(03)(2) <= iq(09)(1)(47 downto 32) & iq(10)(1)(47 downto 32) & iq(11)(1)(47 downto 32) & iq(12)(1)(47 downto 32);
	oq(03)(3) <= iq(05)(1)(47 downto 32) & iq(06)(1)(47 downto 32) & iq(07)(1)(47 downto 32) & iq(08)(1)(47 downto 32);
	oq(03)(4) <= iq(01)(1)(47 downto 32) & iq(02)(1)(47 downto 32) & iq(03)(1)(47 downto 32) & iq(04)(1)(47 downto 32);
	oq(04)(1) <= iq(13)(1)(63 downto 48) & iq(14)(1)(63 downto 48) & iq(15)(1)(63 downto 48) & iq(16)(1)(63 downto 48);
	oq(04)(2) <= iq(09)(1)(63 downto 48) & iq(10)(1)(63 downto 48) & iq(11)(1)(63 downto 48) & iq(12)(1)(63 downto 48);
	oq(04)(3) <= iq(05)(1)(63 downto 48) & iq(06)(1)(63 downto 48) & iq(07)(1)(63 downto 48) & iq(08)(1)(63 downto 48);
	oq(04)(4) <= iq(01)(1)(63 downto 48) & iq(02)(1)(63 downto 48) & iq(03)(1)(63 downto 48) & iq(04)(1)(63 downto 48);
	oq(05)(1) <= iq(13)(2)(15 downto 00) & iq(14)(2)(15 downto 00) & iq(15)(2)(15 downto 00) & iq(16)(2)(15 downto 00);
	oq(05)(2) <= iq(09)(2)(15 downto 00) & iq(10)(2)(15 downto 00) & iq(11)(2)(15 downto 00) & iq(12)(2)(15 downto 00);
	oq(05)(3) <= iq(05)(2)(15 downto 00) & iq(06)(2)(15 downto 00) & iq(07)(2)(15 downto 00) & iq(08)(2)(15 downto 00);
	oq(05)(4) <= iq(01)(2)(15 downto 00) & iq(02)(2)(15 downto 00) & iq(03)(2)(15 downto 00) & iq(04)(2)(15 downto 00);
	oq(06)(1) <= iq(13)(2)(31 downto 16) & iq(14)(2)(31 downto 16) & iq(15)(2)(31 downto 16) & iq(16)(2)(31 downto 16);
	oq(06)(2) <= iq(09)(2)(31 downto 16) & iq(10)(2)(31 downto 16) & iq(11)(2)(31 downto 16) & iq(12)(2)(31 downto 16);
	oq(06)(3) <= iq(05)(2)(31 downto 16) & iq(06)(2)(31 downto 16) & iq(07)(2)(31 downto 16) & iq(08)(2)(31 downto 16);
	oq(06)(4) <= iq(01)(2)(31 downto 16) & iq(02)(2)(31 downto 16) & iq(03)(2)(31 downto 16) & iq(04)(2)(31 downto 16);
	oq(07)(1) <= iq(13)(2)(47 downto 32) & iq(14)(2)(47 downto 32) & iq(15)(2)(47 downto 32) & iq(16)(2)(47 downto 32);
	oq(07)(2) <= iq(09)(2)(47 downto 32) & iq(10)(2)(47 downto 32) & iq(11)(2)(47 downto 32) & iq(12)(2)(47 downto 32);
	oq(07)(3) <= iq(05)(2)(47 downto 32) & iq(06)(2)(47 downto 32) & iq(07)(2)(47 downto 32) & iq(08)(2)(47 downto 32);
	oq(07)(4) <= iq(01)(2)(47 downto 32) & iq(02)(2)(47 downto 32) & iq(03)(2)(47 downto 32) & iq(04)(2)(47 downto 32);
	oq(08)(1) <= iq(13)(2)(63 downto 48) & iq(14)(2)(63 downto 48) & iq(15)(2)(63 downto 48) & iq(16)(2)(63 downto 48);
	oq(08)(2) <= iq(09)(2)(63 downto 48) & iq(10)(2)(63 downto 48) & iq(11)(2)(63 downto 48) & iq(12)(2)(63 downto 48);
	oq(08)(3) <= iq(05)(2)(63 downto 48) & iq(06)(2)(63 downto 48) & iq(07)(2)(63 downto 48) & iq(08)(2)(63 downto 48);
	oq(08)(4) <= iq(01)(2)(63 downto 48) & iq(02)(2)(63 downto 48) & iq(03)(2)(63 downto 48) & iq(04)(2)(63 downto 48);
	oq(09)(1) <= iq(13)(3)(15 downto 00) & iq(14)(3)(15 downto 00) & iq(15)(3)(15 downto 00) & iq(16)(3)(15 downto 00);
	oq(09)(2) <= iq(09)(3)(15 downto 00) & iq(10)(3)(15 downto 00) & iq(11)(3)(15 downto 00) & iq(12)(3)(15 downto 00);
	oq(09)(3) <= iq(05)(3)(15 downto 00) & iq(06)(3)(15 downto 00) & iq(07)(3)(15 downto 00) & iq(08)(3)(15 downto 00);
	oq(09)(4) <= iq(01)(3)(15 downto 00) & iq(02)(3)(15 downto 00) & iq(03)(3)(15 downto 00) & iq(04)(3)(15 downto 00);
	oq(10)(1) <= iq(13)(3)(31 downto 16) & iq(14)(3)(31 downto 16) & iq(15)(3)(31 downto 16) & iq(16)(3)(31 downto 16);
	oq(10)(2) <= iq(09)(3)(31 downto 16) & iq(10)(3)(31 downto 16) & iq(11)(3)(31 downto 16) & iq(12)(3)(31 downto 16);
	oq(10)(3) <= iq(05)(3)(31 downto 16) & iq(06)(3)(31 downto 16) & iq(07)(3)(31 downto 16) & iq(08)(3)(31 downto 16);
	oq(10)(4) <= iq(01)(3)(31 downto 16) & iq(02)(3)(31 downto 16) & iq(03)(3)(31 downto 16) & iq(04)(3)(31 downto 16);
	oq(11)(1) <= iq(13)(3)(47 downto 32) & iq(14)(3)(47 downto 32) & iq(15)(3)(47 downto 32) & iq(16)(3)(47 downto 32);
	oq(11)(2) <= iq(09)(3)(47 downto 32) & iq(10)(3)(47 downto 32) & iq(11)(3)(47 downto 32) & iq(12)(3)(47 downto 32);
	oq(11)(3) <= iq(05)(3)(47 downto 32) & iq(06)(3)(47 downto 32) & iq(07)(3)(47 downto 32) & iq(08)(3)(47 downto 32);
	oq(11)(4) <= iq(01)(3)(47 downto 32) & iq(02)(3)(47 downto 32) & iq(03)(3)(47 downto 32) & iq(04)(3)(47 downto 32);
	oq(12)(1) <= iq(13)(3)(63 downto 48) & iq(14)(3)(63 downto 48) & iq(15)(3)(63 downto 48) & iq(16)(3)(63 downto 48);
	oq(12)(2) <= iq(09)(3)(63 downto 48) & iq(10)(3)(63 downto 48) & iq(11)(3)(63 downto 48) & iq(12)(3)(63 downto 48);
	oq(12)(3) <= iq(05)(3)(63 downto 48) & iq(06)(3)(63 downto 48) & iq(07)(3)(63 downto 48) & iq(08)(3)(63 downto 48);
	oq(12)(4) <= iq(01)(3)(63 downto 48) & iq(02)(3)(63 downto 48) & iq(03)(3)(63 downto 48) & iq(04)(3)(63 downto 48);
	oq(13)(1) <= iq(13)(4)(15 downto 00) & iq(14)(4)(15 downto 00) & iq(15)(4)(15 downto 00) & iq(16)(4)(15 downto 00);
	oq(13)(2) <= iq(09)(4)(15 downto 00) & iq(10)(4)(15 downto 00) & iq(11)(4)(15 downto 00) & iq(12)(4)(15 downto 00);
	oq(13)(3) <= iq(05)(4)(15 downto 00) & iq(06)(4)(15 downto 00) & iq(07)(4)(15 downto 00) & iq(08)(4)(15 downto 00);
	oq(13)(4) <= iq(01)(4)(15 downto 00) & iq(02)(4)(15 downto 00) & iq(03)(4)(15 downto 00) & iq(04)(4)(15 downto 00);
	oq(14)(1) <= iq(13)(4)(31 downto 16) & iq(14)(4)(31 downto 16) & iq(15)(4)(31 downto 16) & iq(16)(4)(31 downto 16);
	oq(14)(2) <= iq(09)(4)(31 downto 16) & iq(10)(4)(31 downto 16) & iq(11)(4)(31 downto 16) & iq(12)(4)(31 downto 16);
	oq(14)(3) <= iq(05)(4)(31 downto 16) & iq(06)(4)(31 downto 16) & iq(07)(4)(31 downto 16) & iq(08)(4)(31 downto 16);
	oq(14)(4) <= iq(01)(4)(31 downto 16) & iq(02)(4)(31 downto 16) & iq(03)(4)(31 downto 16) & iq(04)(4)(31 downto 16);
	oq(15)(1) <= iq(13)(4)(47 downto 32) & iq(14)(4)(47 downto 32) & iq(15)(4)(47 downto 32) & iq(16)(4)(47 downto 32);
	oq(15)(2) <= iq(09)(4)(47 downto 32) & iq(10)(4)(47 downto 32) & iq(11)(4)(47 downto 32) & iq(12)(4)(47 downto 32);
	oq(15)(3) <= iq(05)(4)(47 downto 32) & iq(06)(4)(47 downto 32) & iq(07)(4)(47 downto 32) & iq(08)(4)(47 downto 32);
	oq(15)(4) <= iq(01)(4)(47 downto 32) & iq(02)(4)(47 downto 32) & iq(03)(4)(47 downto 32) & iq(04)(4)(47 downto 32);
	oq(16)(1) <= iq(13)(4)(63 downto 48) & iq(14)(4)(63 downto 48) & iq(15)(4)(63 downto 48) & iq(16)(4)(63 downto 48);
	oq(16)(2) <= iq(09)(4)(63 downto 48) & iq(10)(4)(63 downto 48) & iq(11)(4)(63 downto 48) & iq(12)(4)(63 downto 48);
	oq(16)(3) <= iq(05)(4)(63 downto 48) & iq(06)(4)(63 downto 48) & iq(07)(4)(63 downto 48) & iq(08)(4)(63 downto 48);
	oq(16)(4) <= iq(01)(4)(63 downto 48) & iq(02)(4)(63 downto 48) & iq(03)(4)(63 downto 48) & iq(04)(4)(63 downto 48);

-- ccw
--	oq(01)(1) <= iq(04)(1)(15 downto 00) & iq(03)(1)(15 downto 00) & iq(02)(1)(15 downto 00) & iq(01)(1)(15 downto 00);
--	oq(01)(2) <= iq(08)(1)(15 downto 00) & iq(07)(1)(15 downto 00) & iq(06)(1)(15 downto 00) & iq(05)(1)(15 downto 00);
--	oq(01)(3) <= iq(12)(1)(15 downto 00) & iq(11)(1)(15 downto 00) & iq(10)(1)(15 downto 00) & iq(09)(1)(15 downto 00);
--	oq(01)(4) <= iq(16)(1)(15 downto 00) & iq(15)(1)(15 downto 00) & iq(14)(1)(15 downto 00) & iq(13)(1)(15 downto 00);
--	oq(02)(1) <= iq(04)(1)(31 downto 16) & iq(03)(1)(31 downto 16) & iq(02)(1)(31 downto 16) & iq(01)(1)(31 downto 16);
--	oq(02)(2) <= iq(08)(1)(31 downto 16) & iq(07)(1)(31 downto 16) & iq(06)(1)(31 downto 16) & iq(05)(1)(31 downto 16);
--	oq(02)(3) <= iq(12)(1)(31 downto 16) & iq(11)(1)(31 downto 16) & iq(10)(1)(31 downto 16) & iq(09)(1)(31 downto 16);
--	oq(02)(4) <= iq(16)(1)(31 downto 16) & iq(15)(1)(31 downto 16) & iq(14)(1)(31 downto 16) & iq(13)(1)(31 downto 16);
--	oq(03)(1) <= iq(04)(1)(47 downto 32) & iq(03)(1)(47 downto 32) & iq(02)(1)(47 downto 32) & iq(01)(1)(47 downto 32);
--	oq(03)(2) <= iq(08)(1)(47 downto 32) & iq(07)(1)(47 downto 32) & iq(06)(1)(47 downto 32) & iq(05)(1)(47 downto 32);
--	oq(03)(3) <= iq(12)(1)(47 downto 32) & iq(11)(1)(47 downto 32) & iq(10)(1)(47 downto 32) & iq(09)(1)(47 downto 32);
--	oq(03)(4) <= iq(16)(1)(47 downto 32) & iq(15)(1)(47 downto 32) & iq(14)(1)(47 downto 32) & iq(13)(1)(47 downto 32);
--	oq(04)(1) <= iq(04)(1)(63 downto 48) & iq(03)(1)(63 downto 48) & iq(02)(1)(63 downto 48) & iq(01)(1)(63 downto 48);
--	oq(04)(2) <= iq(08)(1)(63 downto 48) & iq(07)(1)(63 downto 48) & iq(06)(1)(63 downto 48) & iq(05)(1)(63 downto 48);
--	oq(04)(3) <= iq(12)(1)(63 downto 48) & iq(11)(1)(63 downto 48) & iq(10)(1)(63 downto 48) & iq(09)(1)(63 downto 48);
--	oq(04)(4) <= iq(16)(1)(63 downto 48) & iq(15)(1)(63 downto 48) & iq(14)(1)(63 downto 48) & iq(13)(1)(63 downto 48);
--	oq(05)(1) <= iq(04)(2)(15 downto 00) & iq(03)(2)(15 downto 00) & iq(02)(2)(15 downto 00) & iq(01)(2)(15 downto 00);
--	oq(05)(2) <= iq(08)(2)(15 downto 00) & iq(07)(2)(15 downto 00) & iq(06)(2)(15 downto 00) & iq(05)(2)(15 downto 00);
--	oq(05)(3) <= iq(12)(2)(15 downto 00) & iq(11)(2)(15 downto 00) & iq(10)(2)(15 downto 00) & iq(09)(2)(15 downto 00);
--	oq(05)(4) <= iq(16)(2)(15 downto 00) & iq(15)(2)(15 downto 00) & iq(14)(2)(15 downto 00) & iq(13)(2)(15 downto 00);
--	oq(06)(1) <= iq(04)(2)(31 downto 16) & iq(03)(2)(31 downto 16) & iq(02)(2)(31 downto 16) & iq(01)(2)(31 downto 16);
--	oq(06)(2) <= iq(08)(2)(31 downto 16) & iq(07)(2)(31 downto 16) & iq(06)(2)(31 downto 16) & iq(05)(2)(31 downto 16);
--	oq(06)(3) <= iq(12)(2)(31 downto 16) & iq(11)(2)(31 downto 16) & iq(10)(2)(31 downto 16) & iq(09)(2)(31 downto 16);
--	oq(06)(4) <= iq(16)(2)(31 downto 16) & iq(15)(2)(31 downto 16) & iq(14)(2)(31 downto 16) & iq(13)(2)(31 downto 16);
--	oq(07)(1) <= iq(04)(2)(47 downto 32) & iq(03)(2)(47 downto 32) & iq(02)(2)(47 downto 32) & iq(01)(2)(47 downto 32);
--	oq(07)(2) <= iq(08)(2)(47 downto 32) & iq(07)(2)(47 downto 32) & iq(06)(2)(47 downto 32) & iq(05)(2)(47 downto 32);
--	oq(07)(3) <= iq(12)(2)(47 downto 32) & iq(11)(2)(47 downto 32) & iq(10)(2)(47 downto 32) & iq(09)(2)(47 downto 32);
--	oq(07)(4) <= iq(16)(2)(47 downto 32) & iq(15)(2)(47 downto 32) & iq(14)(2)(47 downto 32) & iq(13)(2)(47 downto 32);
--	oq(08)(1) <= iq(04)(2)(63 downto 48) & iq(03)(2)(63 downto 48) & iq(02)(2)(63 downto 48) & iq(01)(2)(63 downto 48);
--	oq(08)(2) <= iq(08)(2)(63 downto 48) & iq(07)(2)(63 downto 48) & iq(06)(2)(63 downto 48) & iq(05)(2)(63 downto 48);
--	oq(08)(3) <= iq(12)(2)(63 downto 48) & iq(11)(2)(63 downto 48) & iq(10)(2)(63 downto 48) & iq(09)(2)(63 downto 48);
--	oq(08)(4) <= iq(16)(2)(63 downto 48) & iq(15)(2)(63 downto 48) & iq(14)(2)(63 downto 48) & iq(13)(2)(63 downto 48);
--	oq(09)(1) <= iq(04)(3)(15 downto 00) & iq(03)(3)(15 downto 00) & iq(02)(3)(15 downto 00) & iq(01)(3)(15 downto 00);
--	oq(09)(2) <= iq(08)(3)(15 downto 00) & iq(07)(3)(15 downto 00) & iq(06)(3)(15 downto 00) & iq(05)(3)(15 downto 00);
--	oq(09)(3) <= iq(12)(3)(15 downto 00) & iq(11)(3)(15 downto 00) & iq(10)(3)(15 downto 00) & iq(09)(3)(15 downto 00);
--	oq(09)(4) <= iq(16)(3)(15 downto 00) & iq(15)(3)(15 downto 00) & iq(14)(3)(15 downto 00) & iq(13)(3)(15 downto 00);
--	oq(10)(1) <= iq(04)(3)(31 downto 16) & iq(03)(3)(31 downto 16) & iq(02)(3)(31 downto 16) & iq(01)(3)(31 downto 16);
--	oq(10)(2) <= iq(08)(3)(31 downto 16) & iq(07)(3)(31 downto 16) & iq(06)(3)(31 downto 16) & iq(05)(3)(31 downto 16);
--	oq(10)(3) <= iq(12)(3)(31 downto 16) & iq(11)(3)(31 downto 16) & iq(10)(3)(31 downto 16) & iq(09)(3)(31 downto 16);
--	oq(10)(4) <= iq(16)(3)(31 downto 16) & iq(15)(3)(31 downto 16) & iq(14)(3)(31 downto 16) & iq(13)(3)(31 downto 16);
--	oq(11)(1) <= iq(04)(3)(47 downto 32) & iq(03)(3)(47 downto 32) & iq(02)(3)(47 downto 32) & iq(01)(3)(47 downto 32);
--	oq(11)(2) <= iq(08)(3)(47 downto 32) & iq(07)(3)(47 downto 32) & iq(06)(3)(47 downto 32) & iq(05)(3)(47 downto 32);
--	oq(11)(3) <= iq(12)(3)(47 downto 32) & iq(11)(3)(47 downto 32) & iq(10)(3)(47 downto 32) & iq(09)(3)(47 downto 32);
--	oq(11)(4) <= iq(16)(3)(47 downto 32) & iq(15)(3)(47 downto 32) & iq(14)(3)(47 downto 32) & iq(13)(3)(47 downto 32);
--	oq(12)(1) <= iq(04)(3)(63 downto 48) & iq(03)(3)(63 downto 48) & iq(02)(3)(63 downto 48) & iq(01)(3)(63 downto 48);
--	oq(12)(2) <= iq(08)(3)(63 downto 48) & iq(07)(3)(63 downto 48) & iq(06)(3)(63 downto 48) & iq(05)(3)(63 downto 48);
--	oq(12)(3) <= iq(12)(3)(63 downto 48) & iq(11)(3)(63 downto 48) & iq(10)(3)(63 downto 48) & iq(09)(3)(63 downto 48);
--	oq(12)(4) <= iq(16)(3)(63 downto 48) & iq(15)(3)(63 downto 48) & iq(14)(3)(63 downto 48) & iq(13)(3)(63 downto 48);
--	oq(13)(1) <= iq(04)(4)(15 downto 00) & iq(03)(4)(15 downto 00) & iq(02)(4)(15 downto 00) & iq(01)(4)(15 downto 00);
--	oq(13)(2) <= iq(08)(4)(15 downto 00) & iq(07)(4)(15 downto 00) & iq(06)(4)(15 downto 00) & iq(05)(4)(15 downto 00);
--	oq(13)(3) <= iq(12)(4)(15 downto 00) & iq(11)(4)(15 downto 00) & iq(10)(4)(15 downto 00) & iq(09)(4)(15 downto 00);
--	oq(13)(4) <= iq(16)(4)(15 downto 00) & iq(15)(4)(15 downto 00) & iq(14)(4)(15 downto 00) & iq(13)(4)(15 downto 00);
--	oq(14)(1) <= iq(04)(4)(31 downto 16) & iq(03)(4)(31 downto 16) & iq(02)(4)(31 downto 16) & iq(01)(4)(31 downto 16);
--	oq(14)(2) <= iq(08)(4)(31 downto 16) & iq(07)(4)(31 downto 16) & iq(06)(4)(31 downto 16) & iq(05)(4)(31 downto 16);
--	oq(14)(3) <= iq(12)(4)(31 downto 16) & iq(11)(4)(31 downto 16) & iq(10)(4)(31 downto 16) & iq(09)(4)(31 downto 16);
--	oq(14)(4) <= iq(16)(4)(31 downto 16) & iq(15)(4)(31 downto 16) & iq(14)(4)(31 downto 16) & iq(13)(4)(31 downto 16);
--	oq(15)(1) <= iq(04)(4)(47 downto 32) & iq(03)(4)(47 downto 32) & iq(02)(4)(47 downto 32) & iq(01)(4)(47 downto 32);
--	oq(15)(2) <= iq(08)(4)(47 downto 32) & iq(07)(4)(47 downto 32) & iq(06)(4)(47 downto 32) & iq(05)(4)(47 downto 32);
--	oq(15)(3) <= iq(12)(4)(47 downto 32) & iq(11)(4)(47 downto 32) & iq(10)(4)(47 downto 32) & iq(09)(4)(47 downto 32);
--	oq(15)(4) <= iq(16)(4)(47 downto 32) & iq(15)(4)(47 downto 32) & iq(14)(4)(47 downto 32) & iq(13)(4)(47 downto 32);
--	oq(16)(1) <= iq(04)(4)(63 downto 48) & iq(03)(4)(63 downto 48) & iq(02)(4)(63 downto 48) & iq(01)(4)(63 downto 48);
--	oq(16)(2) <= iq(08)(4)(63 downto 48) & iq(07)(4)(63 downto 48) & iq(06)(4)(63 downto 48) & iq(05)(4)(63 downto 48);
--	oq(16)(3) <= iq(12)(4)(63 downto 48) & iq(11)(4)(63 downto 48) & iq(10)(4)(63 downto 48) & iq(09)(4)(63 downto 48);
--	oq(16)(4) <= iq(16)(4)(63 downto 48) & iq(15)(4)(63 downto 48) & iq(14)(4)(63 downto 48) & iq(13)(4)(63 downto 48);

-- vertical 180
--	oq(16)(04) <= iq(01)(01)(15 downto 00) & iq(01)(01)(31 downto 16) & iq(01)(01)(47 downto 32) & iq(01)(01)(63 downto 48); 
--	oq(16)(03) <= iq(01)(02)(15 downto 00) & iq(01)(02)(31 downto 16) & iq(01)(02)(47 downto 32) & iq(01)(02)(63 downto 48); 
--	oq(16)(02) <= iq(01)(03)(15 downto 00) & iq(01)(03)(31 downto 16) & iq(01)(03)(47 downto 32) & iq(01)(03)(63 downto 48); 
--	oq(16)(01) <= iq(01)(04)(15 downto 00) & iq(01)(04)(31 downto 16) & iq(01)(04)(47 downto 32) & iq(01)(04)(63 downto 48); 
--	oq(15)(04) <= iq(02)(01)(15 downto 00) & iq(02)(01)(31 downto 16) & iq(02)(01)(47 downto 32) & iq(02)(01)(63 downto 48); 
--	oq(15)(03) <= iq(02)(02)(15 downto 00) & iq(02)(02)(31 downto 16) & iq(02)(02)(47 downto 32) & iq(02)(02)(63 downto 48); 
--	oq(15)(02) <= iq(02)(03)(15 downto 00) & iq(02)(03)(31 downto 16) & iq(02)(03)(47 downto 32) & iq(02)(03)(63 downto 48); 
--	oq(15)(01) <= iq(02)(04)(15 downto 00) & iq(02)(04)(31 downto 16) & iq(02)(04)(47 downto 32) & iq(02)(04)(63 downto 48); 
--	oq(14)(04) <= iq(03)(01)(15 downto 00) & iq(03)(01)(31 downto 16) & iq(03)(01)(47 downto 32) & iq(03)(01)(63 downto 48); 
--	oq(14)(03) <= iq(03)(02)(15 downto 00) & iq(03)(02)(31 downto 16) & iq(03)(02)(47 downto 32) & iq(03)(02)(63 downto 48); 
--	oq(14)(02) <= iq(03)(03)(15 downto 00) & iq(03)(03)(31 downto 16) & iq(03)(03)(47 downto 32) & iq(03)(03)(63 downto 48); 
--	oq(14)(01) <= iq(03)(04)(15 downto 00) & iq(03)(04)(31 downto 16) & iq(03)(04)(47 downto 32) & iq(03)(04)(63 downto 48); 
--	oq(13)(04) <= iq(04)(01)(15 downto 00) & iq(04)(01)(31 downto 16) & iq(04)(01)(47 downto 32) & iq(04)(01)(63 downto 48); 
--	oq(13)(03) <= iq(04)(02)(15 downto 00) & iq(04)(02)(31 downto 16) & iq(04)(02)(47 downto 32) & iq(04)(02)(63 downto 48); 
--	oq(13)(02) <= iq(04)(03)(15 downto 00) & iq(04)(03)(31 downto 16) & iq(04)(03)(47 downto 32) & iq(04)(03)(63 downto 48); 
--	oq(13)(01) <= iq(04)(04)(15 downto 00) & iq(04)(04)(31 downto 16) & iq(04)(04)(47 downto 32) & iq(04)(04)(63 downto 48); 
--	oq(12)(04) <= iq(05)(01)(15 downto 00) & iq(05)(01)(31 downto 16) & iq(05)(01)(47 downto 32) & iq(05)(01)(63 downto 48); 
--	oq(12)(03) <= iq(05)(02)(15 downto 00) & iq(05)(02)(31 downto 16) & iq(05)(02)(47 downto 32) & iq(05)(02)(63 downto 48); 
--	oq(12)(02) <= iq(05)(03)(15 downto 00) & iq(05)(03)(31 downto 16) & iq(05)(03)(47 downto 32) & iq(05)(03)(63 downto 48); 
--	oq(12)(01) <= iq(05)(04)(15 downto 00) & iq(05)(04)(31 downto 16) & iq(05)(04)(47 downto 32) & iq(05)(04)(63 downto 48); 
--	oq(11)(04) <= iq(06)(01)(15 downto 00) & iq(06)(01)(31 downto 16) & iq(06)(01)(47 downto 32) & iq(06)(01)(63 downto 48); 
--	oq(11)(03) <= iq(06)(02)(15 downto 00) & iq(06)(02)(31 downto 16) & iq(06)(02)(47 downto 32) & iq(06)(02)(63 downto 48); 
--	oq(11)(02) <= iq(06)(03)(15 downto 00) & iq(06)(03)(31 downto 16) & iq(06)(03)(47 downto 32) & iq(06)(03)(63 downto 48); 
--	oq(11)(01) <= iq(06)(04)(15 downto 00) & iq(06)(04)(31 downto 16) & iq(06)(04)(47 downto 32) & iq(06)(04)(63 downto 48); 
--	oq(10)(04) <= iq(07)(01)(15 downto 00) & iq(07)(01)(31 downto 16) & iq(07)(01)(47 downto 32) & iq(07)(01)(63 downto 48); 
--	oq(10)(03) <= iq(07)(02)(15 downto 00) & iq(07)(02)(31 downto 16) & iq(07)(02)(47 downto 32) & iq(07)(02)(63 downto 48); 
--	oq(10)(02) <= iq(07)(03)(15 downto 00) & iq(07)(03)(31 downto 16) & iq(07)(03)(47 downto 32) & iq(07)(03)(63 downto 48); 
--	oq(10)(01) <= iq(07)(04)(15 downto 00) & iq(07)(04)(31 downto 16) & iq(07)(04)(47 downto 32) & iq(07)(04)(63 downto 48); 
--	oq(09)(04) <= iq(08)(01)(15 downto 00) & iq(08)(01)(31 downto 16) & iq(08)(01)(47 downto 32) & iq(08)(01)(63 downto 48); 
--	oq(09)(03) <= iq(08)(02)(15 downto 00) & iq(08)(02)(31 downto 16) & iq(08)(02)(47 downto 32) & iq(08)(02)(63 downto 48); 
--	oq(09)(02) <= iq(08)(03)(15 downto 00) & iq(08)(03)(31 downto 16) & iq(08)(03)(47 downto 32) & iq(08)(03)(63 downto 48); 
--	oq(09)(01) <= iq(08)(04)(15 downto 00) & iq(08)(04)(31 downto 16) & iq(08)(04)(47 downto 32) & iq(08)(04)(63 downto 48); 
--	oq(08)(04) <= iq(09)(01)(15 downto 00) & iq(09)(01)(31 downto 16) & iq(09)(01)(47 downto 32) & iq(09)(01)(63 downto 48); 
--	oq(08)(03) <= iq(09)(02)(15 downto 00) & iq(09)(02)(31 downto 16) & iq(09)(02)(47 downto 32) & iq(09)(02)(63 downto 48); 
--	oq(08)(02) <= iq(09)(03)(15 downto 00) & iq(09)(03)(31 downto 16) & iq(09)(03)(47 downto 32) & iq(09)(03)(63 downto 48); 
--	oq(08)(01) <= iq(09)(04)(15 downto 00) & iq(09)(04)(31 downto 16) & iq(09)(04)(47 downto 32) & iq(09)(04)(63 downto 48); 
--	oq(07)(04) <= iq(10)(01)(15 downto 00) & iq(10)(01)(31 downto 16) & iq(10)(01)(47 downto 32) & iq(10)(01)(63 downto 48); 
--	oq(07)(03) <= iq(10)(02)(15 downto 00) & iq(10)(02)(31 downto 16) & iq(10)(02)(47 downto 32) & iq(10)(02)(63 downto 48); 
--	oq(07)(02) <= iq(10)(03)(15 downto 00) & iq(10)(03)(31 downto 16) & iq(10)(03)(47 downto 32) & iq(10)(03)(63 downto 48); 
--	oq(07)(01) <= iq(10)(04)(15 downto 00) & iq(10)(04)(31 downto 16) & iq(10)(04)(47 downto 32) & iq(10)(04)(63 downto 48); 
--	oq(06)(04) <= iq(11)(01)(15 downto 00) & iq(11)(01)(31 downto 16) & iq(11)(01)(47 downto 32) & iq(11)(01)(63 downto 48); 
--	oq(06)(03) <= iq(11)(02)(15 downto 00) & iq(11)(02)(31 downto 16) & iq(11)(02)(47 downto 32) & iq(11)(02)(63 downto 48); 
--	oq(06)(02) <= iq(11)(03)(15 downto 00) & iq(11)(03)(31 downto 16) & iq(11)(03)(47 downto 32) & iq(11)(03)(63 downto 48); 
--	oq(06)(01) <= iq(11)(04)(15 downto 00) & iq(11)(04)(31 downto 16) & iq(11)(04)(47 downto 32) & iq(11)(04)(63 downto 48); 
--	oq(05)(04) <= iq(12)(01)(15 downto 00) & iq(12)(01)(31 downto 16) & iq(12)(01)(47 downto 32) & iq(12)(01)(63 downto 48); 
--	oq(05)(03) <= iq(12)(02)(15 downto 00) & iq(12)(02)(31 downto 16) & iq(12)(02)(47 downto 32) & iq(12)(02)(63 downto 48); 
--	oq(05)(02) <= iq(12)(03)(15 downto 00) & iq(12)(03)(31 downto 16) & iq(12)(03)(47 downto 32) & iq(12)(03)(63 downto 48); 
--	oq(05)(01) <= iq(12)(04)(15 downto 00) & iq(12)(04)(31 downto 16) & iq(12)(04)(47 downto 32) & iq(12)(04)(63 downto 48); 
--	oq(04)(04) <= iq(13)(01)(15 downto 00) & iq(13)(01)(31 downto 16) & iq(13)(01)(47 downto 32) & iq(13)(01)(63 downto 48); 
--	oq(04)(03) <= iq(13)(02)(15 downto 00) & iq(13)(02)(31 downto 16) & iq(13)(02)(47 downto 32) & iq(13)(02)(63 downto 48); 
--	oq(04)(02) <= iq(13)(03)(15 downto 00) & iq(13)(03)(31 downto 16) & iq(13)(03)(47 downto 32) & iq(13)(03)(63 downto 48); 
--	oq(04)(01) <= iq(13)(04)(15 downto 00) & iq(13)(04)(31 downto 16) & iq(13)(04)(47 downto 32) & iq(13)(04)(63 downto 48); 
--	oq(03)(04) <= iq(14)(01)(15 downto 00) & iq(14)(01)(31 downto 16) & iq(14)(01)(47 downto 32) & iq(14)(01)(63 downto 48); 
--	oq(03)(03) <= iq(14)(02)(15 downto 00) & iq(14)(02)(31 downto 16) & iq(14)(02)(47 downto 32) & iq(14)(02)(63 downto 48); 
--	oq(03)(02) <= iq(14)(03)(15 downto 00) & iq(14)(03)(31 downto 16) & iq(14)(03)(47 downto 32) & iq(14)(03)(63 downto 48); 
--	oq(03)(01) <= iq(14)(04)(15 downto 00) & iq(14)(04)(31 downto 16) & iq(14)(04)(47 downto 32) & iq(14)(04)(63 downto 48); 
--	oq(02)(04) <= iq(15)(01)(15 downto 00) & iq(15)(01)(31 downto 16) & iq(15)(01)(47 downto 32) & iq(15)(01)(63 downto 48); 
--	oq(02)(03) <= iq(15)(02)(15 downto 00) & iq(15)(02)(31 downto 16) & iq(15)(02)(47 downto 32) & iq(15)(02)(63 downto 48); 
--	oq(02)(02) <= iq(15)(03)(15 downto 00) & iq(15)(03)(31 downto 16) & iq(15)(03)(47 downto 32) & iq(15)(03)(63 downto 48); 
--	oq(02)(01) <= iq(15)(04)(15 downto 00) & iq(15)(04)(31 downto 16) & iq(15)(04)(47 downto 32) & iq(15)(04)(63 downto 48); 
--	oq(01)(04) <= iq(16)(01)(15 downto 00) & iq(16)(01)(31 downto 16) & iq(16)(01)(47 downto 32) & iq(16)(01)(63 downto 48); 
--	oq(01)(03) <= iq(16)(02)(15 downto 00) & iq(16)(02)(31 downto 16) & iq(16)(02)(47 downto 32) & iq(16)(02)(63 downto 48); 
--	oq(01)(02) <= iq(16)(03)(15 downto 00) & iq(16)(03)(31 downto 16) & iq(16)(03)(47 downto 32) & iq(16)(03)(63 downto 48); 
--	oq(01)(01) <= iq(16)(04)(15 downto 00) & iq(16)(04)(31 downto 16) & iq(16)(04)(47 downto 32) & iq(16)(04)(63 downto 48); 

--	alternated between black and white quads
--	debug_switch is changed at the end of the quad read
--	debug_switch_process : process(debug_switch)
--	begin
--		case debug_switch is
--			when '0' =>
--				dq(01)(01) <= black; dq(01)(02) <= black; dq(01)(03) <= black; dq(01)(04) <= black;
--				dq(02)(01) <= black; dq(02)(02) <= black; dq(02)(03) <= black; dq(02)(04) <= black;
--				dq(03)(01) <= black; dq(03)(02) <= black; dq(03)(03) <= black; dq(03)(04) <= black;
--				dq(04)(01) <= black; dq(04)(02) <= black; dq(04)(03) <= black; dq(04)(04) <= black;
--				dq(05)(01) <= black; dq(05)(02) <= black; dq(05)(03) <= black; dq(05)(04) <= black;
--				dq(06)(01) <= black; dq(06)(02) <= black; dq(06)(03) <= black; dq(06)(04) <= black;
--				dq(07)(01) <= black; dq(07)(02) <= black; dq(07)(03) <= black; dq(07)(04) <= black;
--				dq(08)(01) <= black; dq(08)(02) <= black; dq(08)(03) <= black; dq(08)(04) <= black;
--				dq(09)(01) <= black; dq(09)(02) <= black; dq(09)(03) <= black; dq(09)(04) <= black;
--				dq(10)(01) <= black; dq(10)(02) <= black; dq(10)(03) <= black; dq(10)(04) <= black;
--				dq(11)(01) <= black; dq(11)(02) <= black; dq(11)(03) <= black; dq(11)(04) <= black;
--				dq(12)(01) <= black; dq(12)(02) <= black; dq(12)(03) <= black; dq(12)(04) <= black;
--				dq(13)(01) <= black; dq(13)(02) <= black; dq(13)(03) <= black; dq(13)(04) <= black;
--				dq(14)(01) <= black; dq(14)(02) <= black; dq(14)(03) <= black; dq(14)(04) <= black;
--				dq(15)(01) <= black; dq(15)(02) <= black; dq(15)(03) <= black; dq(15)(04) <= black;
--				dq(16)(01) <= black; dq(16)(02) <= black; dq(16)(03) <= black; dq(16)(04) <= black;
--			when '1' => 
--				dq(01)(01) <= white; dq(01)(02) <= white; dq(01)(03) <= white; dq(01)(04) <= white;
--				dq(02)(01) <= white; dq(02)(02) <= white; dq(02)(03) <= white; dq(02)(04) <= white;
--				dq(03)(01) <= white; dq(03)(02) <= white; dq(03)(03) <= white; dq(03)(04) <= white;
--				dq(04)(01) <= white; dq(04)(02) <= white; dq(04)(03) <= white; dq(04)(04) <= white;
--				dq(05)(01) <= white; dq(05)(02) <= white; dq(05)(03) <= white; dq(05)(04) <= white;
--				dq(06)(01) <= white; dq(06)(02) <= white; dq(06)(03) <= white; dq(06)(04) <= white;
--				dq(07)(01) <= white; dq(07)(02) <= white; dq(07)(03) <= white; dq(07)(04) <= white;
--				dq(08)(01) <= white; dq(08)(02) <= white; dq(08)(03) <= white; dq(08)(04) <= white;
--				dq(09)(01) <= white; dq(09)(02) <= white; dq(09)(03) <= white; dq(09)(04) <= white;
--				dq(10)(01) <= white; dq(10)(02) <= white; dq(10)(03) <= white; dq(10)(04) <= white;
--				dq(11)(01) <= white; dq(11)(02) <= white; dq(11)(03) <= white; dq(11)(04) <= white;
--				dq(12)(01) <= white; dq(12)(02) <= white; dq(12)(03) <= white; dq(12)(04) <= white;
--				dq(13)(01) <= white; dq(13)(02) <= white; dq(13)(03) <= white; dq(13)(04) <= white;
--				dq(14)(01) <= white; dq(14)(02) <= white; dq(14)(03) <= white; dq(14)(04) <= white;
--				dq(15)(01) <= white; dq(15)(02) <= white; dq(15)(03) <= white; dq(15)(04) <= white;
--				dq(16)(01) <= white; dq(16)(02) <= white; dq(16)(03) <= white; dq(16)(04) <= white;
--			when others =>
--				dq(01)(01) <= red; dq(01)(02) <= green; dq(01)(03) <= blue; dq(01)(04) <= red;
--				dq(02)(01) <= red; dq(02)(02) <= green; dq(02)(03) <= blue; dq(02)(04) <= red;
--				dq(03)(01) <= red; dq(03)(02) <= green; dq(03)(03) <= blue; dq(03)(04) <= red;
--				dq(04)(01) <= red; dq(04)(02) <= green; dq(04)(03) <= blue; dq(04)(04) <= red;
--				dq(05)(01) <= red; dq(05)(02) <= green; dq(05)(03) <= blue; dq(05)(04) <= red;
--				dq(06)(01) <= red; dq(06)(02) <= green; dq(06)(03) <= blue; dq(06)(04) <= red;
--				dq(07)(01) <= red; dq(07)(02) <= green; dq(07)(03) <= blue; dq(07)(04) <= red;
--				dq(08)(01) <= red; dq(08)(02) <= green; dq(08)(03) <= blue; dq(08)(04) <= red;
--				dq(09)(01) <= red; dq(09)(02) <= green; dq(09)(03) <= blue; dq(09)(04) <= red;
--				dq(10)(01) <= red; dq(10)(02) <= green; dq(10)(03) <= blue; dq(10)(04) <= red;
--				dq(11)(01) <= red; dq(11)(02) <= green; dq(11)(03) <= blue; dq(11)(04) <= red;
--				dq(12)(01) <= red; dq(12)(02) <= green; dq(12)(03) <= blue; dq(12)(04) <= red;
--				dq(13)(01) <= red; dq(13)(02) <= green; dq(13)(03) <= blue; dq(13)(04) <= red;
--				dq(14)(01) <= red; dq(14)(02) <= green; dq(14)(03) <= blue; dq(14)(04) <= red;
--				dq(15)(01) <= red; dq(15)(02) <= green; dq(15)(03) <= blue; dq(15)(04) <= red;
--				dq(16)(01) <= red; dq(16)(02) <= green; dq(16)(03) <= blue; dq(16)(04) <= red;
--		end case debug_switch;
--	end process debug_switch_process;


	ctrl_process : process (i_clk, i_wr_burst, i_rd_burst, a_wr_cnt, b_wr_cnt, a_rd_cnt, b_rd_cnt, i_rst, my_full_flag, my_empty_flag) -- keep this updated!
	begin
		if rising_edge (i_clk) then
		
			case ctrl is 
			
				when rst_s =>
					a_wr_cnt <= 1;
					b_wr_cnt <= 1;
					a_rd_cnt <= 1;
					b_rd_cnt <= 1;
					o_rst_ack  <= '0';
					if i_wr_burst = '1' then
						o_empty     <= '0';
						my_empty_flag <= '0';
						ctrl      <= wr_s; 
					elsif i_rd_burst = '1' then
						o_full     <= '0';
						my_full_flag <= '0';
						ctrl     <= rd_s;
					else
						ctrl <= rst_s;
					end if;
				
				when wr_s =>
					iq(a_wr_cnt)(b_wr_cnt) <= i_data;
					b_wr_cnt                     <= b_wr_cnt + 1;
					if a_wr_cnt = i_burst_count_max then 
						o_full     <= '1'; 
						my_full_flag <= '1';
					end if;
					if b_wr_cnt = i_burst_size then
						a_wr_cnt <= a_wr_cnt + 1;
						b_wr_cnt <= 1;
						if my_full_flag = '1' then
							ctrl <= rst_s;
						else
							ctrl <= idle_s;
						end if;
					end if;
			
				when rd_s => 
				--	o_data <= dq(a_rd_cnt)(b_rd_cnt); -- debug
				--	o_data <= iq(a_rd_cnt)(b_rd_cnt); -- non-rotated video out
					o_data <= oq(a_rd_cnt)(b_rd_cnt); -- rotated video out
				--	o_data <= rgbr;                   -- just red-green-blue-red pixels
					b_rd_cnt <= b_rd_cnt + 1;
					if a_rd_cnt = i_burst_count_max then 
						o_empty     <= '1';
						my_empty_flag <= '1';
					end if;
					if b_rd_cnt = i_burst_size then
						a_rd_cnt <= a_rd_cnt + 1;
						b_rd_cnt <= 1;
						if my_empty_flag = '1' then
							ctrl <= rst_s;
							debug_switch <= not debug_switch;
						else
							ctrl <= idle_s;
						end if;
					end if;
				
				when idle_s =>
					if i_wr_burst = '1' then
						ctrl <= wr_s;
					elsif i_rd_burst = '1' then
						ctrl <= rd_s;
					elsif i_rst = '1' then
						o_rst_ack <= '1';
						ctrl    <= rst_s;
					end if;
				
				when others =>
					o_data <= rgbr;
				
			end case ctrl;
				
		end if;
	end process ctrl_process;

end behavioral;