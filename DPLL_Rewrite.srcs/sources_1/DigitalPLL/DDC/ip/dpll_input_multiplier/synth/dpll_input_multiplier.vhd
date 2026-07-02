library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dpll_input_multiplier is
  port (
    CLK : in  std_logic;
    A   : in  std_logic_vector(15 downto 0);
    B   : in  std_logic_vector(15 downto 0);
    P   : out std_logic_vector(31 downto 0)
  );
end dpll_input_multiplier;

architecture rtl of dpll_input_multiplier is
  signal p_r : signed(31 downto 0) := (others => '0');
begin
  process (CLK)
  begin
    if rising_edge(CLK) then
      p_r <= signed(A) * signed(B);
    end if;
  end process;

  P <= std_logic_vector(p_r);
end rtl;
