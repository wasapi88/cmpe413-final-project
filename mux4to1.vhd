--
-- Entity: mux4to1
-- Architecture: structural
-- Author: Lance Boac and Emily Bearden
-- Date: 2025-11-03
--

library IEEE;
use IEEE.std_logic_1164.all;

entity mux4to1 is
  port (
    a, b, c, d : in  std_logic;
    sel        : in  std_logic_vector(1 downto 0);
    y          : out std_logic
  );
end entity;

architecture structural of mux4to1 is

  component and2
    port (input1, input2 : in std_logic; output : out std_logic);
  end component;

  component inverter
    port (input : in std_logic; output : out std_logic);
  end component;

  component or2
    port (input1, input2 : in std_logic; output : out std_logic);
  end component;

  -- Internal signals
  signal nsel0, nsel1 : std_logic;
  signal s00, s01, s10, s11 : std_logic;
  signal and_a, and_b, and_c, and_d : std_logic;
  signal or_ab, or_cd : std_logic;

begin

  -- Invert select lines
  u_inv0 : inverter port map(input => sel(0), output => nsel0);
  u_inv1 : inverter port map(input => sel(1), output => nsel1);

  -- Decode select terms
  and_s00 : and2 port map(input1 => nsel1, input2 => nsel0, output => s00);  -- 00
  and_s01 : and2 port map(input1 => nsel1, input2 => sel(0),  output => s01); -- 01
  and_s10 : and2 port map(input1 => sel(1),  input2 => nsel0, output => s10); -- 10
  and_s11 : and2 port map(input1 => sel(1),  input2 => sel(0),  output => s11); -- 11

  -- AND each input with its decoded select
  u_and_a : and2 port map(input1 => a, input2 => s00, output => and_a);
  u_and_b : and2 port map(input1 => b, input2 => s01, output => and_b);
  u_and_c : and2 port map(input1 => c, input2 => s10, output => and_c);
  u_and_d : and2 port map(input1 => d, input2 => s11, output => and_d);

  -- Combine results with ORs
  u_or1 : or2 port map(input1 => and_a, input2 => and_b, output => or_ab);
  u_or2 : or2 port map(input1 => and_c, input2 => and_d, output => or_cd);
  u_or3 : or2 port map(input1 => or_ab, input2 => or_cd, output => y);

end structural;
