-- Le stored function sono funzioni stoccate nel dbms, che restituiscono un solo valore
-- e sono richiamabili anche da statement sql (sia all’interno delle procedure sia all’interno di una semplice query sql).
-- Ad esempio lo sono il COUNT, AVG, MAX, MIN, CONCAT.
-- Sono utili per incapsulare formule o aggregazioni personalizzate.


 -- funzione che calcola il consumo dei dispositivi
 
 DELIMITER $$
  -- la drop è una istruzione sql (il contrario della create), che esegue perche termina con il "punto e virgola" e sopra c'è "$$"
  DROP FUNCTION IF EXISTS calcolo_consumo_dispositivi ; --$$
  CREATE FUNCTION calcolo_consumo_dispositivi (dispositivo INT, inizio TIMESTAMP, fine TIMESTAMP)
  
  -- Risultato della funzione deterministico, perchè restituisce un risultato invariante (sempre lo stesso risultato di uscita),
  -- a fronte delle chiamate (esecuzioni) effettuate con gli stessi valori per i parametri in ingresso.
  -- Se la eseguo più volte con gli stessi parametri in ingresso da gli stessi risultati.
  -- Se una funzione è non deterministica a fronte degli stessi ingressi due esecuzioni diverse possono restituire un risultato di uscita diverso.
  RETURNS FLOAT DETERMINISTIC 
  BEGIN 
        DECLARE consumo DOUBLE DEFAULT 0; -- variabile risultato
        DECLARE variabile_provvisoria INTEGER DEFAULT 0; -- conterra 0 se si tratta di dispositivi regolati da programmi, altrimenti da dispositivi regolati con potenze
        DECLARE durata DOUBLE DEFAULT 0;
        
		-- assegnamento della durata tramite questo calcolo
        SET durata = TIMESTAMPDIFF(SECOND,inizio,fine)/3600; -- durata in secondi di un' interazione portata a ore

		-- se RegolazioneDispositivo ha il campo Codice NULL allora si tratta di un dispositivo con potenza
		SELECT SUM(IF(RD.Codice IS NULL,1,0)) INTO variabile_provvisoria
		FROM RegolazioneDispositivo RD
		WHERE RD.IdDispositivo=dispositivo;
        
        IF (variabile_provvisoria>0) THEN

		-- assegnamento del consumo nel caso di dispositivi con livelli di potenza. Calcolo della media di tutti i campi ConsumoPerTempo relativi al dispositivo fornito in input
			SET consumo=(SELECT AVG(P.ConsumoPerTempo)
						 FROM Potenza P
                         WHERE P.IdDispositivo=dispositivo
						) * durata;
                            
        -- assegnamento del consumo nel caso di dispositivi con programmi. Media del consumo relativi al dispositivo fornito in input.
		ELSEIF (variabile_provvisoria=0) THEN
			SET consumo=(SELECT AVG(P.ConsumoMedio/P.DurataMedia)
						FROM Programma P
                        WHERE P.IdDispositivo=dispositivo)*durata;
		END IF;
        
		-- restituzione del risultato
        RETURN consumo ;
    END $$
    DELIMITER ;


    
    -- funzione per calcolo del consumo di un dispositivo di illuminazione
	DELIMITER $$
	DROP FUNCTION IF EXISTS consumo_luce ; --$$
    CREATE FUNCTION consumo_luce (luce INT, inizio TIMESTAMP, fine TIMESTAMP)
    RETURNS DOUBLE DETERMINISTIC
    BEGIN
    
		DECLARE durata DOUBLE DEFAULT 0;
        DECLARE consumo DOUBLE DEFAULT 0; -- variabile risultato
        
        -- assegno alla durata la differenza fra il timestamp inizio e fine forniti in input,
        -- e porto la durata in ore poichè conosco i kw/h dei consumi
        SET durata = TIMESTAMPDIFF(SECOND, inizio, fine)/3600;
        
        -- assegono a consumo il consumo[kw/h] per la durata[h], della luce fornita in input
        SET consumo = (	SELECT RI.Consumo
						FROM RegolazioneIlluminazione RI
						WHERE RI.IdLuce=luce
					  ) * durata;
                    
        -- restituzione del risultato            
		RETURN consumo ;
	END $$
    
    DELIMITER ;
    
    
-- funzione per il calcolo del consumo di un dispositivo di climatizzazione
DELIMITER $$
DROP FUNCTION IF EXISTS consumo_clima ; --$$
CREATE FUNCTION consumo_clima (clima INT, inizio TIMESTAMP, fine TIMESTAMP)
RETURNS DOUBLE DETERMINISTIC
BEGIN
	 
     DECLARE durata DOUBLE DEFAULT 0;
     DECLARE consumo DOUBLE DEFAULT 0; -- variabile risultato
	
     -- assegno alla durata la differenza fra il timestamp inizio e fine forniti in input,
	 -- e porto la durata in ore poichè conosco i kw/h dei consumi
     SET durata= TIMESTAMPDIFF(SECOND, inizio, fine)/3600;
     
     -- assegno alla variabile consumo il consumo[kw/h] per la durata[h], del climatizzatore fornito in input
     SET consumo=(SELECT RC.Consumo
				  FROM RegolazioneClima RC
				  WHERE RC.IdCondizionatore=clima
				 ) * durata;
                 
    -- restituzione del risultato             
	RETURN consumo ;
END $$

DELIMITER ;



    
    