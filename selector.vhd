--
-- Entity: selector
-- Architecture: structural
-- Author: Lance Boac
-- Created On: 10/21/2025
--

library STD;
library IEEE;
use IEEE.std_logic_1164.all;

entity selector is
  port (
    ce          : in  std_logic; -- Chip Enable
    rw          : in  std_logic; -- RD/WR' 
    readEnable  : out std_logic;
    writeEnable : out std_logic
  );
end selector;

architecture structural of selector is

  component and2
    port (
      input1 : in  std_logic;
      input2 : in  std_logic;
      output : out std_logic
    );
  end component;

  component inverter
    port (
      input  : in  std_logic;
      output : out std_logic
    );
  end component;

  signal rw_inv : std_logic;

begin

  -- Invert RW to generate write-enable control
  U1 : inverter port map (
    input  => rw,
    output => rw_inv
  );

  -- Generate read enable (CE AND RW)
  U2 : and2 port map (
    input1 => ce,
    input2 => rw,
    output => readEnable
  );

  -- Generate write enable (CE AND NOT RW)
  U3 : and2 port map (
    input1 => ce,
    input2 => rw_inv,
    output => writeEnable
  );

end structural;
