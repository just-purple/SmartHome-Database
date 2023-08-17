-- I database attivi sono dotatati di una parte reattiva, che permette loro di reagire in risposta ai cambiamenti (cioè cause scatenanti: istruzioni DML o istanti temporali),
-- mediante comportamenti specifici (particolari operazioni sui dati).
   -- Trigger
-- È un insieme di istruzioni eseguite al verificarsi di una causa scatenante (inserimento, aggiornamento, cancellazione).
-- La causa è un comando DML.
-- Un trigger è capace di gestire vincoli, detti vincoli di integrità generici (o business rule) e scattano prima che venga effettuata una modifica ad una tabella;
-- oppure è usato per aggiornare ridondanze presenti nel database, quando l’utente aggiorna il database, la modifica è propagata alle ridondanze coinvolte mediante un trigger.




-- Trigger che evita l'inserimento di un nuovo utente ultilizzando un NomeUtente di account già esistente
DELIMITER $$
DROP TRIGGER IF EXISTS inserimento_utente $$
CREATE TRIGGER inserimento_utente
BEFORE INSERT ON Account FOR EACH ROW

BEGIN

-- finito è la variabile gestita dall’handler inizialmente impostata a 0,
-- che l’handler metterà a 1 quando il cursore finisce di scorrere il result set
DECLARE finito INTEGER DEFAULT 0;
DECLARE nomeutente VARCHAR(50) DEFAULT '';

DECLARE cursore CURSOR FOR
	-- il result set finisce in memoria puntato da cursore, che punta al primo elemento
	SELECT A.NomeUtente
    FROM Account A ;

-- dichiara un handler di tipo continue (il flusso non viene abortito)
-- e quando si scatena l’evento not found (non si trova un record successivo),
-- come conseguenza imposta la variabile finito a 1, che prima era a 0
DECLARE CONTINUE HANDLER
	FOR NOT FOUND SET finito=1;

-- controllo che il nuovo nomeutente da inserire non sia gia presente nel campo NomeUtente della tabella Account

OPEN cursore;

scan: 	LOOP
			FETCH cursore INTO nomeutente;

			-- se l’handler è scattato e finito = 1 (quindi l’ultimo record processato era l’ultimo da scorrere), salta alla riga successiva e poi direttamente alla riga con CLOSE cursore;
			-- se finito è sempre = 0 non si entra nell’if  LEAVE scan;
			IF finito=1 THEN
				LEAVE scan;
				
			ELSEIF (nomeutente=NEW.NomeUtente) THEN
				SIGNAL SQLSTATE '45000'
				SET MESSAGE_TEXT='Nome utente non valido';
			
			END IF;
    
		END LOOP scan;
CLOSE cursore;

END $$


-------------------------------------------------------------------------------------------------------------------------------------------


-- Funzione per il calcolo della ridondanza Quantità di EnergiaProdotta dai pannelli 
DROP FUNCTION IF EXISTS energia_prodotta $$ 
CREATE FUNCTION energia_prodotta (_pannello INTEGER)
RETURNS DOUBLE DETERMINISTIC
BEGIN
	DECLARE quantita_ FLOAT DEFAULT 0;
	-- in quantita memorizzo la superficie del pannello
	SET quantita_ = (	SELECT P.Superficie
						FROM Pannello P
						WHERE P.IdPannello=_pannello );
	RETURN quantita_;
END $$


-- Trigger per l’inserimento della ridondanza Quantità nella tabella EnergiaProdotta dai pannelli, dopo averla precedentemente calcolata con la funzione
DROP TRIGGER IF EXISTS InserimentoQEnergia$$ 
CREATE TRIGGER InserimentoQEnergia
AFTER INSERT ON EnergiaProdotta FOR EACH ROW 
BEGIN

    -- aggiorno la tabella EnergiaProdotta con la quantita di energia, moltiplicando la superifie dei pannelli per il rispettivo irraggiamento
	UPDATE EnergiaProdotta
	SET Quantita = ((energia_prodotta(1))+(energia_prodotta(2))+(energia_prodotta(3))) * NEW.Irraggiamento
    WHERE IdEnergia = NEW.IdEnergia; 
    
END$$

-- Event che ogni giorno ad ogni ora registra la quantita di energia prodotta
DROP EVENT IF EXISTS ProduzioneEnergia $$ 
CREATE EVENT ProduzioneEnergia
ON SCHEDULE EVERY 1 HOUR
STARTS '2022-03-29 00:00:00'
DO 
    UPDATE EnergiaProdotta
	SET Quantita = ((energia_prodotta(1))+(energia_prodotta(2))+(energia_prodotta(3))) * Irraggiamento $$  


-------------------------------------------------------------------------------------------------------------------------------------------


-- Trigger per il calcolo e l’inserimento del campo EnergiaConsumata nella tabella Interazione. per questo caso ci sono anche le funzioni
DROP TRIGGER IF EXISTS ConsumoEnergia$$
CREATE TRIGGER ConsumoEnergia 
AFTER INSERT  ON Interazione FOR EACH ROW
BEGIN

	DECLARE dispositivo INTEGER DEFAULT 0;
    DECLARE luce INTEGER DEFAULT 0;
    DECLARE clima INTEGER DEFAULT 0;
    DECLARE consumo FLOAT DEFAULT 0;
    
    SET dispositivo = (	SELECT RD.IdDispositivo
						FROM RegolazioneDispositivo RD
						WHERE RD.CodRegolazione=NEW.CodRegolazioneDispositivo );
     
    SET luce = (	SELECT RI.IdLuce
					FROM RegolazioneIlluminazione RI
					WHERE RI.CodIlluminazione=NEW.CodRegolazioneIlluminazione );
			
	SET clima = (	SELECT RC.Clima
					FROM RegolazioneClima RC
					WHERE RC.CodClima=NEW.CodRegolazioneClima );
                        
	IF(NEW.Fine IS NOT NULL) THEN
		IF(NEW.CodRegolazioneDispositivo IS NOT NULL) THEN
			SET consumo=calcolo_consumo_dispositivi(dispositivo,NEW.Inizio,NEW.Fine);
            
            UPDATE Interazione 
            SET EnergiaConsumata=consumo
            WHERE IdInterazione=NEW.IdInterazione AND CodRegolazioneDispositivo=NEW.CodRegolazioneDispositivo;
                
		ELSEIF (NEW.CodRegolazioneIlluminazione IS NOT NULL) THEN
			SET consumo=consumo_luce(luce,NEW.Inizio,NEW.Fine);
            
            UPDATE Interazione 
            SET EnergiaConsumata=consumo
            WHERE IdInterazione=NEW.IdInterazione AND CodRegolazioneIlluminazione=NEW.CodRegolazioneIlluminazione;
                
		ELSEIF(NEW.CodRegolazioneClima IS NOT NULL) THEN
			SET consumo=consumo_clima(clima,NEW.Inizio,NEW.Fine);
            
            UPDATE Interazione 
            SET EnergiaConsumata=consumo
            WHERE IdInterazione=NEW.IdInterazione AND CodregolazioneClima=NEW.CodRegolazioneClima;
		END IF;
	END IF;
			
END $$


-------------------------------------------------------------------------------------------------------------------------------------------


-- Trigger che effettua l’inserimento di una nuova notifica se ho energia necessaria
DROP TRIGGER IF EXISTS nuova_notifica$$
CREATE TRIGGER nuova_notifica
AFTER INSERT ON EnergiaProdotta FOR EACH ROW
BEGIN

	DECLARE finito INTEGER DEFAULT 0;
	DECLARE consumoD INTEGER DEFAULT 0; -- consumo di un dispositivo
	DECLARE codiceD INTEGER DEFAULT 0; -- codice di un dispositivo programmabile
	DECLARE risposta BOOLEAN DEFAULT 1;

	DECLARE cursore2 CURSOR FOR 
		SELECT ((P.ConsumoMedio*P.DurataMedia)/3600) AS cons,P.Codice
		FROM Programma P ;
	
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET finito=1;
	OPEN cursore2;

	scan:LOOP

	FETCH cursore2 INTO consumoD, codiceD;
	IF (finito=1) THEN
		LEAVE scan;
	END IF;
	-- controlla che il consumo di un determinato programma sia uguale alla nuova quantita inserita, nel caso aggiorna la nuova quantita di energia
	IF ((consumoD=NEW.Quantita)AND(risposta=1)) THEN
		INSERT INTO Notifica(Invio,Risposta,Codice,NomeUtente)
		VALUES(CURRENT_TIMESTAMP,risposta,codiceD,'CateBelli');
		
		UPDATE EnergiaProdotta
		SET Quantita=NEW.Quantita-consumoD
		WHERE TIMESTAMP = CURRENT_TIMESTAMP;
	END IF;

	END LOOP scan;

	CLOSE cursore2;

END$$


-------------------------------------------------------------------------------------------------------------------------------------------


-- Trigger che aggiunge una nuova interazione derivante dalla risposta positiva ad una notifica
DROP TRIGGER IF EXISTS interazione_notifica$$  
CREATE TRIGGER interazione_notifica 
AFTER INSERT ON Notifica FOR EACH ROW
BEGIN
	
    DECLARE codiceR INTEGER DEFAULT 0;
    DECLARE durata INTEGER DEFAULT 0;
    
    SET durata=(SELECT P.DurataMedia/3600
				FROM Programma P
                WHERE P.Codice=NEW.Codice);
    
    SET codiceR = (	SELECT R.CodiceRegolazione
					FROM RegolazioneDispositivo R
                    WHERE R.Codice IS NOT NULL  AND  R.Codice=NEW.Codice);
	IF (NEW.Risposta=1) THEN
    
    	-- faccio una chiamata alla procedura InserimentoInterazione fornendo i dati in input
		CALL InserimentoInterazione (CURRENT_TIMESTAMP,(CURRENT_TIMESTAMP+INTERVAL durata HOUR),0, NEW.NomeUtente,codiceR);
	END IF;

END$$