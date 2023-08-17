-- In SQL è possibile utilizzare un approccio procedurale, piuttosto che dichiarativo, e le stesse operazioni possono essere implementate con entrambi gli approcci.
-- Le stored procedure sono procedure dichiarativo-procedurali memorizzate nel DBMS (dichiarativo: invocate tramite chiamata).
-- Lo scopo principale è il miglioramento delle prestazioni.
-- Sono compilate e inserite in una cache, se un’applicazione usa più volte una stored procedure, MySQL utilizza la versione nella cache.

-- Con accesso mediante stored procedure, gli utenti che non hanno accesso diretto al DBMS visualizzano solo l’interfaccia esposta, composta da chiamate che sono autorizzati ad effettuare.
-- Dati mascherati e codice mascherato (sicurezza e protezione da attacchi).
   -- Prestazioni
-- Mediante le stored procedure, le applicazioni inviano solo una chiamata, non il codice della query.
-- In questo modo il carico è spostato sul server DBMS.
-- Il traffico sulla rete è drasticamente ridotto, e l’utente non deve scrivere codice SQL complesso.
   -- Sicurezza
-- Le applicazioni possono essere autorizzate a eseguire stored procedure, ma avere accesso vietato alle tabelle.
-- Il codice può essere mascherato e i dati “grezzi” non sono visibili, le restrizioni sono impostate con opportuni grant.
   -- Riuso del codice
-- Una stored procedure è come un servizio che gli utenti delle applicazioni che usano il database possono utilizzare senza scrivere codice.
-- Gli utenti devono avere i permessi per invocare le procedure.
   -- Svantaggi
-- Carico delle CPU sul server, uso di memoria sul server, debug difficoltoso, non sono banali da scrivere.



-- Inserimento di una nuova interazione con id autoincrement in cui va specificato l'inizio e la fine della fascia in base al fatto che:
-- -il dispositivo sia ad accensione programmata
-- -si debba inserire un accensione sul momento
-- -debba essere inserito lo spegnimento di un dispositivo
-- la procedura deve popolare la tabella interazione con:
-- -il consumo energetico nella fasccia oraria della durata stabilita
-- -il nome utente dell'utente che sta realizzando l'interazione
-- -


-- Il DBMS quando trova il ; compila ed esegue. Siccome una procedure può avere più statment al suo interno, tutti terminati da ; ma il compilatore non deve compilare ogni volta che trova un ; .
-- DELIMITER $$ comunica al compilatore che da qui in poi finché non trova il simbolo $$ non deve compilare, è un cambio di fine delimitatore.
DELIMITER $$

-- Prima di creare una procedura cancella la procedura InserimentoInterazione, se esiste.
DROP PROCEDURE IF EXISTS InserimentoInterazione ;

-- Eseguire questo codice ( dal CREATE PROCEDURE al DELIMITER; ) effettua la compilazione e lo stoccaggio nel DBMS.

-- Una stored procedure MySQL accetta parametri di tipo ingresso, uscita e ingresso-uscita, che permettono di comunicare col chiamante.
-- Ingresso IN: un parametro in ingresso può essere letto (equivalente al passaggio per valore), ma non modificato. I parametri sono in ingresso per default (se non specificato diversamente).
-- Uscita OUT: un parametro di uscita può essere modificato per assumere il valore del risultato della stored procedure.
   -- Nella chiamata si possono usare variabili user-defined (quelle che iniziano con ‘@‘. Sono inizializzate dall’utente senza necessità di dichiarazione, e il loro ciclo di vita equivale alla durata delle connection a MySQL server (ogni connection ha le proprie variabili) è sempre scalare, non può contenere un result set.

CREATE PROCEDURE InserimentoInterazione(IN inizio TIMESTAMP, IN fine2 TIMESTAMP, IN ComandoVocale BOOLEAN, IN nomeUtente VARCHAR (50), IN codiceRegolazione INTEGER)
BEGIN

	-- Le variabili locali sono usate all’interno di una stored procedure, per memorizzare informazioni intermedie di ausilio.
    -- Devono essere dichiarate tutte insieme all’inizio del body.
	DECLARE consumoD FLOAT DEFAULT 0;
	DECLARE durata INTEGER DEFAULT 0 ;
    DECLARE fine TIMESTAMP DEFAULT '0000-00-00 00:00:00';
    DECLARE fascia0 INTEGER DEFAULT 0;
    DECLARE tipo BOOLEAN DEFAULT 0;
    
    -- avvio istantaneo dispositivo con programma, i programmi hanno Codice tra 0 e 49
	IF(codiceRegolazione<50) THEN
			
            IF  (  (SELECT Codice
					FROM RegolazioneDispositivo
					WHERE CodRegolazione=codiceRegolazione
				   ) IS NULL
				) THEN
				SET consumoD = (SELECT ConsumoPerTempo
								FROM Potenza
								WHERE IdLivelloPotenza =   (SELECT IdLivelloPotenza
														  	FROM RegolazioneDispositivo
															WHERE CodRegolazione=codiceRegolazione)
							   ) * ( (TIMESTAMPDIFF(SECOND,inizio,fine2)) / 3600 );
				SET tipo=1;
			ELSE 
				SET tipo=0;
				SET durata =   (SELECT DurataMedia 
								FROM Programma
								WHERE Codice = (SELECT Codice
												FROM RegolazioneDispositivo
												WHERE CodRegolazione=codiceRegolazione)
							   ) / 3600; -- trasformo la durata in ore per sapere i kw/h consumati
							
				SET fine = inizio + INTERVAL durata HOUR; /*TIMESTAMPADD(SECOND, inizio,durata);*/
			
				SET consumoD = calcolo_consumo_dispositivi((SELECT IdDispositivo 
															FROM RegolazioneDispositivo
															WHERE CodRegolazione=codiceRegolazione)
														   ,inizio,fine);
			END IF;

			

			SET fascia0 = (SELECT F.IdFascia
						   FROM FasciaOraria F
						   WHERE (HOUR(inizio)>=HOUR(F.Inizio)) AND ( HOUR(IF(tipo=1,fine2,fine)) <= HOUR(F.Fine) ));

			IF (codiceRegolazione IN (SELECT CodRegolazione
									  FROM RegolazioneDispositivo)
			   ) THEN
			   INSERT INTO Interazione(Inizio,Fine,ComandoVocale,EnergiaConsumata,IdFascia,NomeUtente,CodRegolazioneDispositivo)
			   VALUES (CURRENT_TIME, IF(tipo=1,fine2,fine),ComandoVocale,consumoD,fascia0,nomeUtente,codiceRegolazione);
			END IF;



	-- caso dei dispositivi di illuminazione
	ELSEIF (codiceRegolazione>=100) THEN
     	SET consumoD = consumo_luce((SELECT RI.IdLuce
									 FROM RegolazioneIlluminazione RI
                                     WHERE RI.CodIlluminazione=codiceRegolazione)
									,inizio,fine2);
		SET fascia0 = (SELECT F.IdFascia
					   FROM FasciaOraria F
					   WHERE (HOUR(inizio)>=HOUR(F.Inizio)) AND ( HOUR(fine2) <= HOUR(F.Fine) ) );

		INSERT INTO Interazione(Inizio,Fine,ComandoVocale,EnergiaConsumata,IdFascia,NomeUtente,CodRegolazioneIlluminazione)
		VALUES (CURRENT_TIME,fine2,ComandoVocale,consumoD,fascia0,nomeUtente,codiceRegolazione);
	


	-- caso dei condizionatori
	ELSEIF (codiceRegolazione>=50 AND codiceRegolazione<100) THEN
			SET consumoD=consumo_clima((SELECT RC.IdCondizionatore
										FROM RegolazioneClima RC
										WHERE RC.CodClima=codiceRegolazione)
									   ,inizio,fine2);
			SET fascia0 = ( SELECT F.IdFascia
							FROM FasciaOraria F
							WHERE (HOUR(inizio)>=HOUR(F.Inizio)) AND (HOUR(fine2)<=HOUR(F.Fine)));
           
			INSERT INTO Interazione(Inizio,Fine,ComandoVocale,EnergiaConsumata,IdFascia,NomeUtente,CodRegolazioneClima)
			VALUES (CURRENT_TIME,fine2,ComandoVocale,consumoD,fascia0,nomeUtente,codiceRegolazione);
END IF;


    END $$
    
    -- Una volta finita la scrittura del multi-statement bisogna comunicare al compilatore di reimpostare il delimitatore di fine statement con ;
    DELIMITER ;
    
-- La chiamata esegue la stored procedure e ottiene il risultato restituito dall’esecuzione del body.
-- call InserimentoInterazione();
    
    


-- mancano considerazioni sullo shedule