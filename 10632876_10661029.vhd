
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.ALL;
use IEEE.numeric_std.ALL;

entity project_reti_logiche is
    Port ( i_clk : in STD_LOGIC;
           i_rst : in STD_LOGIC;
           i_start : in STD_LOGIC;
           i_data : in STD_LOGIC_VECTOR (7 downto 0);
           o_address : out STD_LOGIC_VECTOR (15 downto 0);
           o_done : out STD_LOGIC;
           o_en : out STD_LOGIC;
           o_we : out STD_LOGIC;
           o_data : out STD_LOGIC_VECTOR (7 downto 0));
end project_reti_logiche;

architecture fsm of project_reti_logiche is
type state_type is (IDLE, WAIT_DIM, READ_COL, MULT_DIM, FIND_EDGES, COMP_DELTA, COMP_SHIFT, DIFF, COMP_NEW_PIX, STORE, WAIT_OLD_PIX, DONE);

-- registri interni
    signal current_state : state_type; -- stato corrente della FSM
    signal max_pixel_value : std_logic_vector(7 downto 0) := (others => '0'); -- intensità massima pixel
    signal min_pixel_value : std_logic_vector(7 downto 0) := (others => '1'); -- intensità minima pixel
    signal counter : std_logic_vector(14 downto 0) := (others => '0'); -- contatore
    signal n_pixel : std_logic_vector(14 downto 0) := (others => '0'); -- num pixel
    signal n_col : std_logic_vector(7 downto 0) := (others => '0'); -- num colonne
    signal ram_index : std_logic_vector(15 downto 0) := (others => '0'); -- indirizzo del prossimo indirizzo RAM da caricare
    signal delta_value : std_logic_vector(7 downto 0) := (others => '0'); -- max_pixel_value-min_pixel_value+1
    signal shift_level : std_logic_vector (3 downto 0);
    signal difference : std_logic_vector (7 downto 0);   

begin
    global : process(i_clk, i_rst, i_start)
    begin
        if (i_rst = '1') then
            current_state <= IDLE;
        elsif (rising_edge(i_clk)) then
            case current_state is
                when IDLE =>   
                    --inizializzazione registri
                    o_data <= "00000000";
                    max_pixel_value <= "00000000";
                    min_pixel_value <= "11111111";
                    n_pixel <= "000000000000000";
                    ram_index <= "0000000000000000";
                    o_address <= "0000000000000000";
                    counter <= "000000000000000";
                    delta_value <= "00000000";
                    o_done <= '0';
		                             
                    current_state <= IDLE;                  
                    if (i_start = '1') then
                        current_state <= WAIT_DIM;
                    end if;
                    
                when WAIT_DIM => 
                    --viene precaricato l'indirizzo RAM che contiene il numero di righe               
                    ram_index <= ram_index + "0000000000000001";
                    o_address <= ram_index + "0000000000000001";                  
                    current_state <= READ_COL;
                   
                when READ_COL =>
                    --lettura del numero di colonne
                    n_col<= (i_data);                   
                    if (i_data=0) then
                        o_done <= '1'; 
                        current_state <= DONE;          
                     else current_state <= MULT_DIM;
                     end if; 
                    
                when MULT_DIM =>
                    --lettura del numero di righe e calcolo del numero totale di pixel
                    if (n_col>0) then
                        n_pixel <= n_pixel+i_data;
                        n_col <= n_col-'1';
                        if (n_col="00000001")then
                            ram_index <= ram_index + "0000000000000001";
                            o_address <= ram_index + "0000000000000001";
                        end if;
                        current_state <= MULT_DIM;
                    else
                        if( i_data=0) then
                            o_done <= '1'; 
                            current_state <= DONE; 
                        else
                            ram_index <= ram_index + "0000000000000001";
                            o_address <= ram_index + "0000000000000001";
                            --preaggiornamento counter
                            counter <= counter + "000000000000001";
                            current_state <= FIND_EDGES;                              
                        end if;
                    end if;
                    
                when FIND_EDGES =>                
                    if (i_data > max_pixel_value) then
                        max_pixel_value <= i_data;
                    end if; 
                    if (i_data < min_pixel_value) then
                        min_pixel_value <= i_data;
                    end if;
                    --se tutti i pixel sono stati analizzati
                    if (counter = n_pixel) then
                        --viene precaricato di nuovo il primo pixel dell'immagine
                        ram_index <= "0000000000000010";
                        o_address <= "0000000000000010";
                        current_state <= COMP_DELTA;
                    else                       
                        ram_index <= ram_index + "0000000000000001";
                        o_address <= ram_index + "0000000000000001"; 
                        --aggiornamento counter
                        counter <= counter + "000000000000001";
                        current_state <= FIND_EDGES;             
                    end if;
                
                when COMP_DELTA =>
                    delta_value <= max_pixel_value - min_pixel_value+'1';
                    --viene reinizializzato counter
                    counter <= "000000000000000";
                    current_state <= COMP_SHIFT;
                  
                when COMP_SHIFT =>                      
                    --shift_level <= (8 - FLOOR(LOG2(delta_value+1)));
                    if (delta_value(7) = '1') then shift_level <= ("0001");
                    elsif (delta_value(6) = '1') then shift_level <= ("0010");
                    elsif (delta_value(5) = '1') then shift_level <= ("0011");
                    elsif (delta_value(4) = '1') then shift_level <= ("0100");
                    elsif (delta_value(3) = '1') then shift_level <= ("0101");
                    elsif (delta_value(2) = '1') then shift_level <= ("0110");
                    elsif (delta_value(1) = '1') then shift_level <= ("0111");
                    elsif (delta_value(0) = '1') then shift_level <= ("1000");
                    else shift_level <= ("0000");
                    end if;
                    current_state <= DIFF;

                    
                when DIFF =>
                    difference <= i_data - min_pixel_value;
                    current_state <= COMP_NEW_PIX;
                                                          
                when COMP_NEW_PIX =>                
                    counter <= counter + "000000000000001";        
                    if(counter + "000000000000001"<n_pixel)then
                        ram_index <= ram_index + "0000000000000001";    --ram index parte da 00010 in questo stato
                    end if;
                    --a seconda dello shift level, viene caricato il bus dati in uscita con il nuovo valore del pixel
                    case shift_level is 
                        when "0000" => o_data <= i_data;
                        when "0001" =>  if((difference)<="01111111")
                                    then o_data <= difference(6 downto 0) & "0";
                                    else o_data<= ("11111111");
                                    end if;
                        when "0010" =>  if((difference)<="00111111")
                                    then o_data <= difference(5 downto 0) & "00";
                                    else o_data<= ("11111111");
                                    end if;
                        when "0011" =>  if((difference)<="00011111")
                                    then o_data <= difference(4 downto 0) & "000";
                                    else o_data<= ("11111111");
                                    end if;
                        when "0100" =>  if((difference)<="00001111")
                                    then o_data <= difference(3 downto 0) & "0000";
                                    else o_data<= ("11111111");
                                    end if;
                        when "0101" =>  if((difference)<="00000111")
                                    then o_data <= difference(2 downto 0) & "00000";
                                    else o_data<= ("11111111");
                                    end if;
                        when "0110" =>  if((difference)<="00000011")
                                    then o_data <= difference(1 downto 0) & "000000";
                                    else o_data<= ("11111111");
                                    end if;
                        when "0111" =>  if((difference)<="00000001")
                                    then o_data <= difference(0) & "0000000";
                                    else o_data<= ("11111111");
                                    end if;
                        when others =>  o_data <=("00000000");               
                        end case;                  
                    --viene precaricato l'indirizzo RAM dove bisogna caricare il nuovo pixel                    
                    o_address<= ram_index + n_pixel;
                    current_state <= STORE ;
                    
                when STORE =>
                    --viene memorizzato il nuovo pixel, o_we deve essere '1' in STORE
                    --nel frattempo, o_address viene caricato con l'indirizzo del prossimo pixel
                    if(counter<n_pixel) then 
                            o_address <= ram_index;
                            current_state <= WAIT_OLD_PIX;                
                    else 
                            o_done <= '1';
                            current_state <= DONE;
                    end if;
                       
                when WAIT_OLD_PIX =>
                    --attesa di un clock per evitare errori dovuti da ritardi
                    current_state <= DIFF;
	
      when DONE =>
                    current_state <= DONE;

                    if (i_start = '0') then
                         o_done <= '0';
                        current_state <= IDLE;
                    end if;
      when others =>
                    current_state <= IDLE;
            end case;
         end if;
    end process;
    
    -- gestione di o_we, o_en segnali che dipendono solo dallo stato corrente della FSM
    with current_state select
        o_we <= '1' when STORE,
                '0' when others;
                
    with current_state select
        o_en <= '0' when IDLE | DONE,
                '1' when others;
end fsm;