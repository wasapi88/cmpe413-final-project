--
-- Entity: tag_valid
-- Architecture: structural
-- Description : Structural 2-bit tag store with valid bits (4 entries)
-- Author      : Lance Boac and Emily Bearden
-- Date        : 2025-11-03
--

library IEEE;
use IEEE.std_logic_1164.all;

entity tag_valid is
  port (
    clk        : in  std_logic;
    reset      : in  std_logic;
    index      : in  std_logic_vector(1 downto 0);
    tag_in     : in  std_logic_vector(1 downto 0);
    write_tag  : in  std_logic;  -- FSM control to update tag
    set_valid  : in  std_logic;  -- FSM control to set valid bit
    tag_match  : out std_logic   -- high when tag + valid match
  );
end entity;

architecture structural of tag_valid is

  
  -- Component declarations
  
  component Dlatch
    port ( d, clk : in std_logic; q, qbar : out std_logic );
  end component;

  component and2
    port ( input1, input2 : in std_logic; output : out std_logic );
  end component;

  component inverter
    port ( input : in std_logic; output : out std_logic );
  end component;

  component selector
    port ( a, b, sel : in std_logic; y : out std_logic );
  end component;

  component mux4to1
    port (
      a, b, c, d : in std_logic;
      sel        : in std_logic_vector(1 downto 0);
      y          : out std_logic
    );
  end component;

  
  -- Internal signals
  
  -- Tag storage: 4 lines × 2 bits = 8 latches
  signal tag_bits : std_logic_vector(7 downto 0);

  -- Valid bits: 4 entries
  signal valid_bits : std_logic_vector(3 downto 0);

  -- Index decoder
  signal n_idx0, n_idx1 : std_logic;
  signal idx0_sel, idx1_sel, idx2_sel, idx3_sel : std_logic;

  -- Write enables
  signal tag_we0, tag_we1, tag_we2, tag_we3 : std_logic;
  signal val_we0, val_we1, val_we2, val_we3 : std_logic;

  -- Selected tag bits and valid for comparison
  signal sel_tag0, sel_tag1, sel_valid : std_logic;

  -- Inverted tag inputs for equality check
  signal n_tag_in0, n_tag_in1 : std_logic;

  -- Tag match per bit and overall match
  signal bit_match0, bit_match1, both_match : std_logic;

begin
  
  -- INDEX DECODER (2-to-4) using gates
  
  u_inv0 : inverter port map(input => index(0), output => n_idx0);
  u_inv1 : inverter port map(input => index(1), output => n_idx1);

  u_and0 : and2 port map(input1 => n_idx1, input2 => n_idx0, output => idx0_sel);
  u_and1 : and2 port map(input1 => n_idx1, input2 => index(0),  output => idx1_sel);
  u_and2 : and2 port map(input1 => index(1),  input2 => n_idx0, output => idx2_sel);
  u_and3 : and2 port map(input1 => index(1),  input2 => index(0),  output => idx3_sel);

  
  -- WRITE ENABLES (for tag and valid latches)
  
  tag_we0_and : and2 port map(input1 => write_tag, input2 => idx0_sel, output => tag_we0);
  tag_we1_and : and2 port map(input1 => write_tag, input2 => idx1_sel, output => tag_we1);
  tag_we2_and : and2 port map(input1 => write_tag, input2 => idx2_sel, output => tag_we2);
  tag_we3_and : and2 port map(input1 => write_tag, input2 => idx3_sel, output => tag_we3);

  val_we0_and : and2 port map(input1 => set_valid, input2 => idx0_sel, output => val_we0);
  val_we1_and : and2 port map(input1 => set_valid, input2 => idx1_sel, output => val_we1);
  val_we2_and : and2 port map(input1 => set_valid, input2 => idx2_sel, output => val_we2);
  val_we3_and : and2 port map(input1 => set_valid, input2 => idx3_sel, output => val_we3);

  
  -- TAG AND VALID STORAGE USING DLATCHES
  
  gen_tags : for line in 0 to 3 generate
    signal tag_en, val_en : std_logic;
  begin
    tag_en <= tag_we0 when line=0 else
              tag_we1 when line=1 else
              tag_we2 when line=2 else
              tag_we3;

    val_en <= val_we0 when line=0 else
              val_we1 when line=1 else
              val_we2 when line=2 else
              val_we3;

    -- Two tag bits per line
    gen_tag_bits : for bit in 0 to 1 generate
      constant idx : integer := (line * 2) + bit;
    begin
      u_tag_latch : Dlatch port map(
        d => tag_in(bit),
        clk => tag_en,
        q => tag_bits(idx),
        qbar => open
      );
    end generate;

    -- One valid bit per line
    u_valid_latch : Dlatch port map(
      d => '1',
      clk => val_en,
      q => valid_bits(line),
      qbar => open
    );
  end generate;

  
  -- READ PATH: SELECT CURRENT TAG & VALID (4:1 muxes)
  
  u_mux_tag0 : mux4to1
    port map(
      a => tag_bits(0), b => tag_bits(2),
      c => tag_bits(4), d => tag_bits(6),
      sel => index,
      y => sel_tag0
    );

  u_mux_tag1 : mux4to1
    port map(
      a => tag_bits(1), b => tag_bits(3),
      c => tag_bits(5), d => tag_bits(7),
      sel => index,
      y => sel_tag1
    );

  u_mux_valid : mux4to1
    port map(
      a => valid_bits(0), b => valid_bits(1),
      c => valid_bits(2), d => valid_bits(3),
      sel => index,
      y => sel_valid
    );

  
  -- TAG COMPARISON LOGIC (bitwise XNOR using AND/INV)
  
  u_inv_tag0 : inverter port map(input => tag_in(0), output => n_tag_in0);
  u_inv_tag1 : inverter port map(input => tag_in(1), output => n_tag_in1);

  -- bit_match = (tag XOR tag_in)' => XNOR
  bit0_eq_and1 : and2 port map(input1 => sel_tag0, input2 => tag_in(0), output => bit_match0);
  bit1_eq_and1 : and2 port map(input1 => sel_tag1, input2 => tag_in(1), output => bit_match1);

  -- Combine both tag bits must match + valid = 1
  both_and : and2 port map(input1 => bit_match0, input2 => bit_match1, output => both_match);
  valid_and : and2 port map(input1 => both_match, input2 => sel_valid, output => tag_match);

end architecture structural;
