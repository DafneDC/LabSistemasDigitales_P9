library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
 
entity LCD is
    port (        
        clk : in  std_logic;
        reset : in std_logic;     
        data: inout std_logic_vector(7 downto 0);  
        RS,RW,E: out std_logic
    );
end LCD;
 
architecture Behavioral of LCD is

--Estados de la maquina de estados.

  type estados_t is (RST,ST0,ST1,FSET,EMSET,DO,CLD,RETH,SDDRAMA,WRITE1,WRITE2,
                     WRITE3,WRITE4,SDDRAMA2,WRITE15,WRITE16,
                     WRITE17,WRITE18,WRITE19);
  
  --Señales 
  signal state, Next_state : estados_t; 
  signal CONT1: std_logic_vector(23 downto 0) := X"000000"; --contador de 0 a 16777216 = 0.33 segundos
  signal CONT2: std_logic_vector(4 downto 0) := "00000"; --contador de 0 a 32, = 0.64 us
  signal reinicio: std_logic :='0';
  signal ready: std_logic := '0';
  --signal data1: std_logic_vector(7 downto 0):="00000000";
  --signal RS1,RW1,E1: std_logic := '0';
  --signal BF: std_logic;

--Letras ASCII
   constant D_S: std_logic_vector(7 downto 0):= x"44";   
   constant A_S: std_logic_vector(7 downto 0):= x"41";   
   constant F_S: std_logic_vector(7 downto 0):= x"46";   
   constant L_S: std_logic_vector(7 downto 0):= x"4C";   
   constant E_S: std_logic_vector(7 downto 0):= x"45";  
   constant X_S: std_logic_vector(7 downto 0):= x"58";   
   
   --CONSTANTES DE TIEMPO 
   constant T1: STD_LOGIC_VECTOR(23 DOWNTO 0) := x"000fff"; --espera de 81.9 us
   
  begin
  
  --CONTADOR DE RETARDOS CONT1 --
  process(clk,reset)
  begin
        if reset='1' then   CONT1 <= (others => '0');
        elsif clk'event and clk='1' then CONT1 <= CONT1 + 1;
        end if;
  end process;

--Contador para Secuencias CONT2--
    process(clk,ready)
    begin
        if clk='1' and clk'event then
            if ready='1' then CONT2 <= CONT2 + 1;
            else CONT2 <= "00000";
            end if;
        end if;
   end process;
   
--Actualizacion de estados
    process (clk,Next_state) 
    begin
    if clk='1' and clk'event then state<=Next_state;
    end if;
  end process;
--maquina de estados
  process(CONT1,CONT2,state,clk,reset)
  begin
    
    if reset = '1' THEN Next_State <= RST;
    elsif clk='0' and clk'event then
    
    case State is
        when RST => -- Estado de reset
               if CONT1=X"000000"then --0s
                   RS<='0';
                   RW<='0';
                   E<='0';
                   DATA<=X"00";
                   Next_State<=ST0;
               else
                   Next_State<=ST0;
               end if;
     
        when ST0 => --Primer estado de espera por 25ms(20ms=0F4240=1000000)(15ms=0B71B0=750000)
               if CONT1=X"1312D0" then -- 1,250,000=25ms
                    READY<='1';
                    DATA<=X"38"; -- FUNCTION SET 8BITS, 2 LINE, 5X7
                    Next_State<=ST0;
               elsif CONT2>"00001" and CONT2<"01110" then--rango de 12*20ns=240ns
                    E<='1';
               elsif CONT2="1111" then
                    READY<='0';
                    E<='0';
                    Next_State<=ST1;
               else
                    Next_State<=ST0;
               end if;
               reinicio<= CONT2(0)and CONT2(1) and CONT2(2)and CONT2(3); -- CONT1 = 0
               
        when ST1 => --Segundo estado de espera por 100us (5000=x35E8)
               if CONT1=X"0035E8" then -- 13800 = 276us
                   READY<='1';
                   DATA<=X"38"; -- FUNCTION SET
                   Next_State<=ST1;
               elsif CONT2>"00001" and CONT2<"01110" then --rango de 12*20ns=240ns
                   E<='1';
               elsif CONT2="1111" then
                   READY<='0';
                   E<='0';
                   Next_State<=FSET;
               else
                   Next_State<=ST1;
               end if;
               reinicio <= CONT2(0)and CONT2(1)and CONT2(2)and CONT2(3); -- CONT1 = 0 
                 
        when FSET => --FUNCTION SET 0x38 (8bits, 2 lineas, 5x7dots)
               if CONT1=X"0007D0" then --espera por 40us
                   READY<='1';
                   DATA<=X"38"; --001DL-N-F-XX
                   Next_State<=FSET;
               elsif CONT2>"00001" and CONT2<"01110" then--rango de 12*20ns=240ns
                    E<='1';
               elsif CONT2="1111" then
                   READY<='0';
                   E<='0';
                   Next_State<=EMSET;
               else
                   Next_State<=FSET;
               end if;
               reinicio<= CONT2(0)and CONT2(1)and CONT2(2)and CONT2(3); -- CONT1 = 0   
               
        when EMSET => --ENTRY MODE SET 0x06 (1 right-moving cursor and address increment)
               if CONT1=X"0007D0" then --estado de espera por 40us
                   READY<='1';
                   DATA<=X"06"; --000001-I/D-SH
                   Next_State<=EMSET;
               elsif CONT2>"00001" and CONT2<"01110" then--rango de 12*20ns=240ns
                    E<='1';
               elsif CONT2="1111" then
                   READY<='0';
                   E<='0';
                   Next_State<=DO;
               else
                    Next_State<=EMSET;
               end if;
               reinicio<= CONT2(0)and CONT2(1)and CONT2(2)and CONT2(3); -- CONT1 = 0
               
        when DO => --DISPLAY ON/OFF 0x0C (DISPLAY-CURSOR-BLINKING on-off)
               if CONT1=X"0007D0" then -- estado de espera por 40us
                   READY<='1';
                   DATA<=X"0C"; --00001-D-C-B,display on, cursor on
                   Next_State<=DO;
               elsif CONT2>"00001" and CONT2<"01110" then--rango de 12*20ns=240ns
                   E<='1';
               elsif CONT2="1111" then
                   READY<='0';
                   E<='0';
                   Next_State<=CLD;
               else
                   Next_State<=DO;
               end if;
               reinicio<= CONT2(0)and CONT2(1)and CONT2(2)and CONT2(3); -- CONT1 = 0
                  
        when CLD => --CLEAR DISPLAY 0x01
               if CONT1=X"0007D0" then-- estado de espera por 40us
               
               READY<='1';
               DATA<=X"01"; --00000001
               Next_State<=CLD;
               
               elsif CONT2>"00001" and CONT2<"01110" then
               
               E<='1';
               elsif CONT2="1111" then
               READY<='0';
               E<='0';
               Next_State<=RETH;
               
               else
               
               Next_State<=CLD;
               
               end if;
               reinicio<= CONT2(0)and CONT2(1)and CONT2(2)and CONT2(3); -- CONT1 = 0
               
        when RETH => --RETURN CURSOR HOME
               if CONT1=X"0007D0" then -- estado de espera por 40us
               
               READY<='1';
               DATA<=X"02"; --0000001X
               Next_State<=RETH;
               
               elsif CONT2>"00001" and CONT2<"01110" then--rango de 12*20ns=240ns
               
               E<='1';
               elsif CONT2="1111" then
               READY<='0';
               E<='0';
               Next_State<=SDDRAMA;
               
               else
               
               Next_State<=RETH;
               
               end if;
               reinicio<= CONT2(0)and CONT2(1)and CONT2(2)and CONT2(3); -- CONT1 = 0
               
               ------ ------
        when SDDRAMA => --SET DD RAM ADDRESS posición del display del renglón 1 columna 4
               if CONT1=X"014050" then -- estado de espera por 1.64ms
               
               READY<='1';
               DATA<=X"80"; --1-AC6-AC0, 80(R=1,C=1) 84(R=1,C=5)
               Next_State<=SDDRAMA;
               
               elsif CONT2>"00001" and CONT2<"01110" then--rango de 12*20ns=240ns
               
               E<='1';
               elsif CONT2="1111" then
               READY<='0';
               E<='0';
               Next_State<=WRITE1;
               
               else
               
               Next_State<=SDDRAMA;
               
               end if;
               reinicio<= CONT2(0)and CONT2(1)and CONT2(2)and CONT2(3); -- CONT1 = 0
        ---------------------------------------------------------------------------------------
               --DATOS--DATOS--DATOS--DATOS--DATOS--DATOS--DATOS--DATOS--DATOS--DATOS--DATOS--
               ---------------------------------------------------------------------------------------
        when WRITE1 => --Write Data in DD RAM (S 53)
               if CONT1=T1 then -- estado de espera por 0.335s X"FFFFFF"=750,000
               READY<='1';
               RS<='1';
               DATA<=D_S; --DATA<=x"53";
               Next_State<=WRITE1;
               elsif CONT2>"00001" and CONT2<"01110" then--rango de 12*20ns=240ns
               E<='1';
               elsif CONT2="1111" then
               READY<='0';
               E<='0';
               Next_State<=WRITE2;
               else
               Next_State<=WRITE1;
               end if;
               
               reinicio<= CONT2(0)and CONT2(1)and CONT2(2)and CONT2(3); -- CONT1 = 0
              
        when WRITE2 => --Write Data in DD RAM (i 69, í A1)
               if CONT1=T1 then -- estado de espera por 0.335s X"FFFFFF"=750,000
               READY<='1';
               RS<='1';
               DATA<=A_S; --DATA<=x"69";
               Next_State<=WRITE2;
               elsif CONT2>"00001" and CONT2<"01110" then--rango de 12*20ns=240ns
               E<='1';
               elsif CONT2="1111" then
               READY<='0';
               E<='0';
               Next_State<=WRITE3;
               else
               Next_State<=WRITE2;
               end if;
               
               REINICIO<= CONT2(0)and CONT2(1)and CONT2(2)and CONT2(3); -- CONT1 = 0
        when WRITE3 => --Write Data in DD RAM (m 6D)
               if CONT1=T1 then -- estado de espera por 0.335s X"FFFFFF"=750,000
               READY<='1';
               RS<='1';
               DATA<=F_S; --DATA<=x"6D";
               Next_State<=WRITE3;
               elsif CONT2>"00001" and CONT2<"01110" then--rango de 12*20ns=240ns
               E<='1';
               elsif CONT2="1111" then
               READY<='0';
               E<='0';
               Next_State<=SDDRAMA2;
               else
               Next_State<=WRITE3;
               end if;
               
               REINICIO<= CONT2(0)and CONT2(1)and CONT2(2)and CONT2(3); -- CONT1 = 0
        when SDDRAMA2 => --SET DD RAM ADDRESS posición del display renglón 2 columna 1
               if CONT1=X"014050" then -- estado de espera por 1.64ms
               READY<='1';
               RS<='0';
               DATA<=X"C0"; --1-AC6 - AC0, C0(R=2,C=1)
               Next_State<=SDDRAMA2;
               elsif CONT2>"00001" and CONT2<"01110" then--rango de 12*20ns=240ns
               E<='1';
               elsif CONT2="1111" then
               READY<='0';
               E<='0';
               Next_State<=WRITE15; --para brincar al segundo renglón
               else
               Next_State<=SDDRAMA2;
               end if;
               
               REINICIO<= CONT2(0)and CONT2(1)and CONT2(2)and CONT2(3); -- CONT1 = 0
               ------ ------
        when WRITE15 => --Write Data in DD RAM (corchetA [ 5B)
               if CONT1=T1 then -- estado de espera por 0.335s X"FFFFFF"=750,000
                    READY<='1';
                    RS<='1';
                    DATA<=A_S; --DATA<=X"5B";
                    Next_State<=WRITE15;
               elsif CONT2>"00001" and CONT2<"01110" then--rango de 12*20ns=240ns
                    E<='1';
               elsif CONT2="1111" then
                    READY<='0';
                    E<='0';
                    Next_State<=WRITE16;
               else
                    Next_State<=WRITE15;
               end if;
               
               REINICIO<= CONT2(0)and CONT2(1)and CONT2(2)and CONT2(3); -- CONT1 = 0
        when WRITE16 => --Write Data in DD RAM (S 53)
               if CONT1=T1 then -- estado de espera por 0.335s X"FFFFFF"=750,000
                    READY<='1';
                    RS<='1';
                    DATA<=L_S; --DATA<=X"53";
                    Next_State<=WRITE16;
               elsif CONT2>"00001" and CONT2<"01110" then--rango de 12*20ns=240ns
                    E<='1';
               elsif CONT2="1111" then
                    READY<='0';
                    E<='0';
                    Next_State<=WRITE17;
               else
                    Next_State<=WRITE16;
               end if;
               
               REINICIO<= CONT2(0)and CONT2(1)and CONT2(2)and CONT2(3); -- CONT1 = 0
        when WRITE17 => --Write Data in DD RAM (W 57)
               if CONT1=T1 then -- estado de espera por 0.335s X"FFFFFF"=750,000
                    READY<='1';
                    RS<='1';
                    DATA<=E_S; --DATA<=X"57";
                    Next_State<=WRITE17;
               elsif CONT2>"00001" and CONT2<"01110" then--rango de 12*20ns=240ns
                    E<='1';
               elsif CONT2="1111" then
                    READY<='0';
                    E<='0';
                    Next_State<=WRITE18;
               else
               Next_State<=WRITE17;
               end if;
               
               REINICIO<= CONT2(0)and CONT2(1)and CONT2(2)and CONT2(3); -- CONT1 = 0
        when WRITE18 => --Write Data in DD RAM (7 37)
               if CONT1=T1 then -- estado de espera por 0.335s X"FFFFFF"=750,000
                    READY<='1';
                    RS<='1';
                    DATA<=X_S; --DATA<=X"37";
                    Next_State<=WRITE18;
               elsif CONT2>"00001" and CONT2<"01110" then--rango de 12*20ns=240ns
                    E<='1';
               elsif CONT2="1111" then
                    READY<='0';
                    E<='0';
                    Next_State<=WRITE19;
               else
                    Next_State<=WRITE18;
               end if;
               
               REINICIO<= CONT2(0)and CONT2(1)and CONT2(2)and CONT2(3); -- CONT1 = 0
        when WRITE19 =>
            Next_State<=WRITE19;
        when others => 
            E <= '1';
            state <= state;
        end case;
        
        end if;
end process; --FIN DEL PROCESO DE LA MÁQUINA DE ESTADOS
         
end Behavioral;
