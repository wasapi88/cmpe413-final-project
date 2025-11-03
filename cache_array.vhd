--
-- Entity: cache_array
-- Architecture: structural
-- Description : Gate-level cache array with 4 lines × 4 bytes/line
-- Author      : Lance
-- Date        : 2025-11-03
--

library IEEE;
use IEEE.std_logic_1164.all;

entity cache_array is
  port (
    clk       : in  std_logic;
    we        : in  std_logic;
    index     : in  std_logic_vector(1 downto 0);  -- selects 1 of 4 cache lines
    byte_sel  : in  std_logic_vector(1 downto 0);  -- selects 1 of 4 bytes
    data_in   : in  std_logic_vector(7 downto 0);
    data_out  : out std_logic_vector(7 downto 0)
  );
end entity;

architecture structural of cache_array is

  
  -- COMPONENT DECLARATIONS
  
  component Dlatch
    port (
      d, clk : in std_logic;
      q, qbar : out std_logic
    );
  end component;

  component and2
    port (
      input1, input2 : in std_logic;
      output : out std_logic
    );
  end component;

  component inverter
    port (
      input : in std_logic;
      output : out std_logic
    );
  end component;

  component selector
    port (
      a, b, sel : in std_logic;
      y : out std_logic
    );
  end component;

  component mux4to1
    port (
      a, b, c, d : in std_logic;
      sel        : in std_logic_vector(1 downto 0);
      y          : out std_logic
    );
  end component;

  
  -- INTERNAL SIGNALS
  
  -- 4 cache lines × 4 bytes × 8 bits = 128 latches
  signal cache_bits : std_logic_vector(127 downto 0);

  -- index decoder
  signal n_idx0, n_idx1 : std_logic;
  signal idx0_sel, idx1_sel, idx2_sel, idx3_sel : std_logic;

  -- write enables per line
  signal we0, we1, we2, we3 : std_logic;

begin
  
  -- INDEX DECODER (2-to-4) USING GATES
  
  u_inv0 : inverter port map(input => index(0), output => n_idx0);
  u_inv1 : inverter port map(input => index(1), output => n_idx1);

  u_and0 : and2 port map(input1 => n_idx1, input2 => n_idx0, output => idx0_sel);
  u_and1 : and2 port map(input1 => n_idx1, input2 => index(0),  output => idx1_sel);
  u_and2 : and2 port map(input1 => index(1),  input2 => n_idx0, output => idx2_sel);
  u_and3 : and2 port map(input1 => index(1),  input2 => index(0),  output => idx3_sel);

  
  -- WRITE ENABLES (gated per cache line)
  
  we_line0 : and2 port map(input1 => we, input2 => idx0_sel, output => we0);
  we_line1 : and2 port map(input1 => we, input2 => idx1_sel, output => we1);
  we_line2 : and2 port map(input1 => we, input2 => idx2_sel, output => we2);
  we_line3 : and2 port map(input1 => we, input2 => idx3_sel, output => we3);

  
  -- CACHE STORAGE (4 lines × 32 bits)
  -- Each line = 4 bytes = 32 D-latches (1 per bit)
  
  gen_lines : for line in 0 to 3 generate
    signal wen : std_logic;
  begin
    wen <= we0 when line=0 else
           we1 when line=1 else
           we2 when line=2 else
           we3;

    gen_bits : for bit in 0 to 7 generate
      gen_bytes : for byte in 0 to 3 generate
        constant idx : integer := (line * 32) + (byte * 8) + bit;
      begin
        u_latch : Dlatch port map(
          d => data_in(bit),
          clk => wen,
          q => cache_bits(idx),
          qbar => open
        );
      end generate;
    end generate;
  end generate;

  
  -- READ PATH (4:1 MUX PER BIT)
  
  gen_read : for bit in 0 to 7 generate
    signal bit0, bit1, bit2, bit3 : std_logic;
    signal base : integer;
  begin
    base := to_integer(unsigned(index)) * 32 + bit;

    bit0 <= cache_bits(base + 0);
    bit1 <= cache_bits(base + 8);
    bit2 <= cache_bits(base + 16);
    bit3 <= cache_bits(base + 24);

    u_mux : mux4to1 port map(
      a   => bit0,
      b   => bit1,
      c   => bit2,
      d   => bit3,
      sel => byte_sel,
      y   => data_out(bit)
    );
  end generate;

end architecture structural;
