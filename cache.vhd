--
-- Entity: cache
-- Architecture: structural
-- Description: 1 cache block consisting of a valid bit, 2-bit index, and 4 data bytes (32 bits)
-- Author: Lance Boac and Emily Bearden
-- Created On: 10/23/2025
--

library IEEE;
use IEEE.std_logic_1164.all;

entity cache is
  port (
    writeData  : in  std_logic_vector(31 downto 0);  -- 4 bytes = 32 bits
    chipEnable : in  std_logic;
    rw         : in  std_logic;                      -- '1' = READ, '0' = WRITE
    indexBits  : in  std_logic_vector(1 downto 0);   -- 2-bit index
    validBit   : inout std_logic;                    -- cache valid bit
    readData   : out std_logic_vector(31 downto 0)
  );
end cache;

architecture structural of cache is

  -- Reuse cacheCell for every bit
  component cacheCell
    port (
      writeData  : in  std_logic;
      chipEnable : in  std_logic;
      rw         : in  std_logic;
      readData   : out std_logic
    );
  end component;

  -- Internal signals for each data bit
  signal dataOut : std_logic_vector(31 downto 0);

begin

  -- Generate the 32 cacheCell instances for 4 bytes (8 bits each)
  genBytes : for i in 0 to 31 generate
    dataBit : cacheCell
      port map (
        writeData  => writeData(i),
        chipEnable => chipEnable,
        rw         => rw,
        readData   => dataOut(i)
      );
  end generate;

  -- Output data
  readData <= dataOut;

end structural;
