library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity cache_top is
  port (
    clk, reset  : in  std_logic;
    start       : in  std_logic;
    rd_wr       : in  std_logic;
    CA          : in  std_logic_vector(5 downto 0);
    CD_in       : in  std_logic_vector(7 downto 0);
    CD_out      : out std_logic_vector(7 downto 0);
    busy        : out std_logic;
    MA          : out std_logic_vector(5 downto 0);
    MD          : in  std_logic_vector(7 downto 0);
    mem_enable  : out std_logic;
    state_debug : out std_logic_vector(9 downto 0)  -- Added for waveform visibility
  );
end entity;

architecture structural of cache_top is

  -- Components

  component cache_fsm is
    port (
      clk, reset       : in  std_logic;
      start            : in  std_logic;
      rd_wr            : in  std_logic;
      tag_hit          : in  std_logic;
      busy             : out std_logic;
      out_en           : out std_logic;
      cache_we         : out std_logic;
      cache_sel        : out std_logic_vector(1 downto 0);
      set_valid        : out std_logic;
      update_tag       : out std_logic;
      mem_enable       : out std_logic;
      mem_byte_strobe  : out std_logic_vector(3 downto 0);
      state_debug      : out std_logic_vector(9 downto 0)
    );
  end component;

  component cache_array is
    port (
      clk, we        : in  std_logic;
      index, byte_sel: in  std_logic_vector(1 downto 0);
      data_in        : in  std_logic_vector(7 downto 0);
      data_out       : out std_logic_vector(7 downto 0)
    );
  end component;

  component tag_valid is
    port (
      clk, reset     : in  std_logic;
      index, tag_in  : in  std_logic_vector(1 downto 0);
      write_tag      : in  std_logic;
      set_valid      : in  std_logic;
      tag_match      : out std_logic
    );
  end component;


  -- Internal wiring

  signal tag_hit        : std_logic;
  signal out_en         : std_logic;
  signal cache_we       : std_logic;
  signal cache_sel      : std_logic_vector(1 downto 0);
  signal set_valid_s    : std_logic;
  signal update_tag_s   : std_logic;
  signal md_stb         : std_logic_vector(3 downto 0);
  signal cache_data_out : std_logic_vector(7 downto 0);

  alias tag_bits   : std_logic_vector(1 downto 0) is CA(5 downto 4);
  alias index_bits : std_logic_vector(1 downto 0) is CA(3 downto 2);
  alias byte_bits  : std_logic_vector(1 downto 0) is CA(1 downto 0);

begin

  u_fsm : cache_fsm
    port map (
      clk             => clk,
      reset           => reset,
      start           => start,
      rd_wr           => rd_wr,
      tag_hit         => tag_hit,
      busy            => busy,
      out_en          => out_en,
      cache_we        => cache_we,
      cache_sel       => cache_sel,
      set_valid       => set_valid_s,
      update_tag      => update_tag_s,
      mem_enable      => mem_enable,
      mem_byte_strobe => md_stb,
      state_debug     => state_debug
    );


  u_tag : tag_valid
    port map (
      clk       => clk,
      reset     => reset,
      index     => index_bits,
      tag_in    => tag_bits,
      write_tag => update_tag_s,
      set_valid => set_valid_s,
      tag_match => tag_hit
    );


  -- Cache Array

  u_cache : cache_array
    port map (
      clk       => clk,
      we        => cache_we,
      index     => index_bits,
      byte_sel  => cache_sel,
      data_in   => MD,       -- from memory during fill
      data_out  => cache_data_out
    );


  -- External buses

  CD_out <= cache_data_out when out_en = '1' else (others => 'Z');
  MA     <= tag_bits & index_bits & "00";  -- points to block base per spec
end architecture;
