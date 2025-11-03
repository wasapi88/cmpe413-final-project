
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity cache_fsm is
  port (
    clk, reset       : in  std_logic;
    start            : in  std_logic;
    rd_wr            : in  std_logic; -- '1'=read, '0'=write
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
end entity;

architecture structural of cache_fsm is
  
  -- Components
  
  component dff
    port ( d, clk : in std_logic; q, qbar : out std_logic );
  end component;

  component inverter
    port ( input : in std_logic; output : out std_logic );
  end component;

  component and2
    port ( input1, input2 : in std_logic; output : out std_logic );
  end component;

  
  -- State storage (one-hot)
  
  signal S_IDLE_Q, S_LATCH_Q, S_CHECK_Q                : std_logic := '0';
  signal S_READ_HIT_Q, S_WRITE_SEQ_Q, S_WRITE_DONE_Q   : std_logic := '0';
  signal S_RMISS_REQ_Q, S_RMISS_WAIT_Q                 : std_logic := '0';
  signal S_RMISS_FILL_Q, S_RRESPOND_Q                  : std_logic := '0';

  signal S_IDLE_D, S_LATCH_D, S_CHECK_D                : std_logic;
  signal S_READ_HIT_D, S_WRITE_SEQ_D, S_WRITE_DONE_D   : std_logic;
  signal S_RMISS_REQ_D, S_RMISS_WAIT_D                 : std_logic;
  signal S_RMISS_FILL_D, S_RRESPOND_D                  : std_logic;

  
  -- Counters
  
  signal OC0_Q, OC1_Q : std_logic := '0';
  signal OC0_D, OC1_D : std_logic;
  signal OC_EN, OC_CLR : std_logic;

  signal C0_Q, C1_Q, C2_Q, C3_Q, C4_Q : std_logic := '0';
  signal C0_D, C1_D, C2_D, C3_D, C4_D : std_logic;
  signal C_EN, C_CLR : std_logic;
  signal K0, K1, K2, K3, K4 : std_logic;

  
  -- Misc
  
  signal nRESET, nTAG_HIT, nRD_WR : std_logic;
  signal ANY_BUSY_Q : std_logic;
  signal BYTE0_STB, BYTE1_STB, BYTE2_STB, BYTE3_STB : std_logic;
begin
  
  -- Inverters
  
  U_INV_RST  : inverter port map(input => reset,   output => nRESET);
  U_INV_RDWR : inverter port map(input => rd_wr,   output => nRD_WR);
  U_INV_THIT : inverter port map(input => tag_hit, output => nTAG_HIT);

  
  -- Busy aggregate
  
  ANY_BUSY_Q <= S_LATCH_Q or S_CHECK_Q or S_READ_HIT_Q or
                S_WRITE_SEQ_Q or S_WRITE_DONE_Q or
                S_RMISS_REQ_Q or S_RMISS_WAIT_Q or
                S_RMISS_FILL_Q or S_RRESPOND_Q;

  
  -- === Operation Counter (2-bit) ===
  
  OC_EN  <= S_READ_HIT_Q or S_WRITE_SEQ_Q;
  OC_CLR <= (not OC_EN) or reset;

  OC0_D <= '0' when OC_CLR='1'
           else (not OC0_Q) when OC_EN='1'
           else OC0_Q;

  OC1_D <= '0' when OC_CLR='1'
           else (OC1_Q xor OC0_Q) when OC_EN='1'
           else OC1_Q;

  U_OC0 : dff port map(d => OC0_D, clk => clk, q => OC0_Q, qbar => open);
  U_OC1 : dff port map(d => OC1_D, clk => clk, q => OC1_Q, qbar => open);

  
  -- === Miss Counter (5-bit) ===
  
  C_EN  <= (S_RMISS_WAIT_Q or S_RMISS_FILL_Q) and (not reset);
  C_CLR <= (S_RMISS_REQ_Q or reset);

  K0 <= C_EN;
  K1 <= C0_Q and K0;
  K2 <= C1_Q and K1;
  K3 <= C2_Q and K2;
  K4 <= C3_Q and K3;

  C0_D <= '0' when C_CLR='1' else (C0_Q xor K0) when C_EN='1' else C0_Q;
  C1_D <= '0' when C_CLR='1' else (C1_Q xor K1) when C_EN='1' else C1_Q;
  C2_D <= '0' when C_CLR='1' else (C2_Q xor K2) when C_EN='1' else C2_Q;
  C3_D <= '0' when C_CLR='1' else (C3_Q xor K3) when C_EN='1' else C3_Q;
  C4_D <= '0' when C_CLR='1' else (C4_Q xor K4) when C_EN='1' else C4_Q;

  U_C0 : dff port map(d => C0_D, clk => clk, q => C0_Q, qbar => open);
  U_C1 : dff port map(d => C1_D, clk => clk, q => C1_Q, qbar => open);
  U_C2 : dff port map(d => C2_D, clk => clk, q => C2_Q, qbar => open);
  U_C3 : dff port map(d => C3_D, clk => clk, q => C3_Q, qbar => open);
  U_C4 : dff port map(d => C4_D, clk => clk, q => C4_Q, qbar => open);

  
  -- === Byte-strobes for READ MISS (8,10,12,14) ===
  
  BYTE0_STB <= '1' when (S_RMISS_WAIT_Q='1' and C4_Q='0' and C3_Q='1' and C2_Q='0' and C1_Q='0' and C0_Q='0') else '0';
  BYTE1_STB <= '1' when (S_RMISS_FILL_Q='1' and C4_Q='0' and C3_Q='1' and C2_Q='0' and C1_Q='1' and C0_Q='0') else '0';
  BYTE2_STB <= '1' when (S_RMISS_FILL_Q='1' and C4_Q='0' and C3_Q='1' and C2_Q='1' and C1_Q='0' and C0_Q='0') else '0';
  BYTE3_STB <= '1' when (S_RMISS_FILL_Q='1' and C4_Q='0' and C3_Q='1' and C2_Q='1' and C1_Q='1' and C0_Q='0') else '0';

  
  -- === State Next-Logic ===
  
  S_IDLE_D <= '1' when reset='1'
              else '1' when (S_WRITE_DONE_Q='1' or S_RRESPOND_Q='1')
              else '1' when (S_IDLE_Q='1' and start='0' and ANY_BUSY_Q='0')
              else '0';


  S_LATCH_D <= '1' when (S_IDLE_Q='1' and start='1' and reset='0') else '0';
  S_CHECK_D <= '1' when (S_LATCH_Q='1') else '0';

  -- Read-hit (2 cycles)
  S_READ_HIT_D <= '1' when (S_CHECK_Q='1' and rd_wr='1' and tag_hit='1')
                  else '1' when (S_READ_HIT_Q='1' and not (OC1_Q='0' and OC0_Q='1'))
                  else '0';

  -- Write sequence (3 cycles)
  S_WRITE_SEQ_D <= '1' when (S_CHECK_Q='1' and rd_wr='0')
                   else '1' when (S_WRITE_SEQ_Q='1' and not (OC1_Q='1' and OC0_Q='0'))
                   else '0';

  -- Write done (1 cycle after seq)
  S_WRITE_DONE_D <= '1' when (S_WRITE_SEQ_Q='1' and (OC1_Q='1' and OC0_Q='0')) else '0';

  -- Read-miss sequence
  S_RMISS_REQ_D  <= '1' when (S_CHECK_Q='1' and rd_wr='1' and tag_hit='0') else '0';
  S_RMISS_WAIT_D <= '1' when (S_RMISS_REQ_Q='1')
                    else '1' when (S_RMISS_WAIT_Q='1' and BYTE0_STB='0')
                    else '0';
  S_RMISS_FILL_D <= '1' when (S_RMISS_WAIT_Q='1' and BYTE0_STB='1')
                    else '1' when (S_RMISS_FILL_Q='1' and BYTE3_STB='0')
                    else '0';
  S_RRESPOND_D   <= '1' when (S_RMISS_FILL_Q='1' and BYTE3_STB='1') else '0';

  
  -- === Flip-Flops ===
  
  U_S_IDLE       : dff port map(d => S_IDLE_D,       clk => clk, q => S_IDLE_Q,       qbar => open);
  U_S_LATCH      : dff port map(d => S_LATCH_D,      clk => clk, q => S_LATCH_Q,      qbar => open);
  U_S_CHECK      : dff port map(d => S_CHECK_D,      clk => clk, q => S_CHECK_Q,      qbar => open);
  U_S_RHIT       : dff port map(d => S_READ_HIT_D,   clk => clk, q => S_READ_HIT_Q,   qbar => open);
  U_S_WSEQ       : dff port map(d => S_WRITE_SEQ_D,  clk => clk, q => S_WRITE_SEQ_Q,  qbar => open);
  U_S_WDONE      : dff port map(d => S_WRITE_DONE_D, clk => clk, q => S_WRITE_DONE_Q, qbar => open);
  U_S_RMREQ      : dff port map(d => S_RMISS_REQ_D,  clk => clk, q => S_RMISS_REQ_Q,  qbar => open);
  U_S_RMWAIT     : dff port map(d => S_RMISS_WAIT_D, clk => clk, q => S_RMISS_WAIT_Q, qbar => open);
  U_S_RMFILL     : dff port map(d => S_RMISS_FILL_D, clk => clk, q => S_RMISS_FILL_Q, qbar => open);
  U_S_RRESP      : dff port map(d => S_RRESPOND_D,   clk => clk, q => S_RRESPOND_Q,   qbar => open);

  
  -- === Outputs ===
  
  busy <= '1' when (S_LATCH_Q='1' or S_CHECK_Q='1' or S_READ_HIT_Q='1' or
                    S_WRITE_SEQ_Q='1' or S_WRITE_DONE_Q='1' or
                    S_RMISS_REQ_Q='1' or S_RMISS_WAIT_Q='1' or
                    S_RMISS_FILL_Q='1' or S_RRESPOND_Q='1')
          else '0';


  out_en <= '1' when (S_READ_HIT_Q='1' and OC1_Q='0' and OC0_Q='1')
             else '1' when (S_RRESPOND_Q='1')
             else '0';

  cache_we <= '1' when (S_WRITE_SEQ_Q='1' or S_RMISS_FILL_Q='1') else '0';

  cache_sel <= "00" when (S_RMISS_FILL_Q='1' and BYTE0_STB='1') else
               "01" when (S_RMISS_FILL_Q='1' and BYTE1_STB='1') else
               "10" when (S_RMISS_FILL_Q='1' and BYTE2_STB='1') else
               "11" when (S_RMISS_FILL_Q='1' and BYTE3_STB='1') else
               "00";

  set_valid  <= '1' when (S_RMISS_FILL_Q='1' and BYTE0_STB='1') else '0';
  update_tag <= '1' when (S_RMISS_FILL_Q='1' and BYTE0_STB='1') else '0';

  mem_enable <= '1' when (S_RMISS_REQ_Q='1')
                else '1' when (S_WRITE_DONE_Q='1' and nTAG_HIT='1')
                else '0';

  mem_byte_strobe <= (BYTE3_STB & BYTE2_STB & BYTE1_STB & BYTE0_STB);

  
  -- === Debug Bus ===
  
  state_debug <= ( S_RRESPOND_Q & S_RMISS_FILL_Q & S_RMISS_WAIT_Q & S_RMISS_REQ_Q &
                   S_WRITE_DONE_Q & S_WRITE_SEQ_Q & S_READ_HIT_Q & S_CHECK_Q &
                   S_LATCH_Q & S_IDLE_Q );
end architecture;
