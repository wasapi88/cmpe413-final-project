--
-- Entity: mux4to1
-- Architecture: structural
-- Description : 4-to-1 multiplexer built using 2:1 selector gates
-- Author      : Lance
-- Date        : 2025-11-03
--

library IEEE;
use IEEE.std_logic_1164.all;

entity mux4to1 is
  port (
    a, b, c, d : in  std_logic;           -- data inputs
    sel        : in  std_logic_vector(1 downto 0); -- select lines
    y          : out std_logic            -- output
  );
end entity mux4to1;

architecture structural of mux4to1 is

  
  -- Component declarations
  
  component selector
    port (
      a, b, sel : in  std_logic;
      y         : out std_logic
    );
  end component;

  
  -- Internal signals
  
  signal y_low, y_high : std_logic;

begin
  
  -- First stage (two 2:1 muxes)
  
  mux_low  : selector port map(a => a, b => b, sel => sel(0), y => y_low);
  mux_high : selector port map(a => c, b => d, sel => sel(0), y => y_high);

  
  -- Second stage (final 2:1 mux)
  
  mux_final : selector port map(a => y_low, b => y_high, sel => sel(1), y => y);

end architecture structural;
