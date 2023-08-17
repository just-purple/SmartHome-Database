-- modifica della dimensione della variabile group_concat_max_len
set session group_concat_max_len = 5000;

use `mySmartHome`;

-- abbiamo scelto di usare gli itemset costituiti da dispositivi

-- La funzione group_concat restituisce una stringa concatenata contenente i valori diversi da NULL assunti da un attributo nei vari record di ogni gruppo
-- la gropu_concat restituisce una stringa concatenata contenente i valori assunti dall'attributo IdDispositivo nei varia record di ogni gruppo e ci viene affiancato il valore 0
select group_concat(concat('`D', IdDispositivo, '`', ' INT default 0')) 
into @lista_dispositivi from Dispositivo;

-- Le tabelle pivot permettono di riarrangiare, riassumere, dare valore e leggibilita ai dati estratti da tabelle complesse
-- creazione tabella transazioni in cui ogni riga è una transazione
-- ed ogni colonna indica se un dispositivo è stato usato o meno
set @pivot_table = concat('CREATE TABLE Transazioni(',
						  ' ID INT AUTO_INCREMENT PRIMARY KEY, ', 
                            @lista_dispositivi, 
						  ' )ENGINE = InnoDB DEFAULT CHARSET = latin1;');


-- timeout (in minuti) dopo di cui termina la precedente transazione e ne inizia un'altra
set @max_timeout = 200;
-- supporto sopra il cui un itemset viene considerato large
set @support_treshold = 2;
-- confidence necessaria perchè una regola sia forte
set @confidence = 0.6;

DROP TABLE IF EXISTS `Transazioni`;
PREPARE myquery FROM @pivot_table;
EXECUTE myquery;


-- stored procedure che riempe le transazioni

DROP PROCEDURE IF EXISTS FillTransazioni;
DELIMITER $$
CREATE PROCEDURE FillTransazioni()
BEGIN

	DECLARE IdDispositivo INT;
	DECLARE InizioInterazione TIMESTAMP;
	DECLARE UltimaInterazione TIMESTAMP;
	DECLARE primoInserimento INT DEFAULT 1;

	-- finito è la variabile gestita dall’handler inizialmente impostata a 0,
	-- che l’handler metterà a 1 quando il cursore finisce di scorrere il result set
	DECLARE finito INT DEFAULT 0;

	DECLARE cursore CURSOR FOR
		-- il result set finisce in memoria puntato da cursore, che punta al primo elemento
		SELECT d.IdDispositivo, i.Inizio
		FROM `Interazione` i 
		INNER JOIN `RegolazioneDispositivo` rd ON i.CodRegolazioneDispositivo = rd.CodRegolazione
		INNER JOIN `Dispositivo` d ON d.IdDispositivo = rd.IdDispositivo
		ORDER BY i.Inizio;

	-- dichiara un handler di tipo continue (il flusso non viene abortito)
	-- e quando si scatena l’evento not found (non si trova un record successivo),
	-- come conseguenza imposta la variabile finito a 1, che prima era a 0
	DECLARE CONTINUE HANDLER
		FOR NOT FOUND SET finito=1;
	
	OPEN cursore;

	scan: LOOP
		FETCH cursore INTO IdDispositivo, InizioInterazione;
		
		-- se l’handler è scattato e finito = 1 (quindi l’ultimo record processato era l’ultimo da scorrere), salta alla riga successiva e poi direttamente alla riga con CLOSE cursore;
		-- se finito è sempre = 0 non si entra nell’if, ma si salta alla riga  IF primoInserimento  
		IF finito = 1 THEN 
			LEAVE scan;
		END IF;

		-- se 
		-- è la prima interazione
		-- è passato il timeout 
		-- allora creo una altra transazione
		IF primoInserimento OR TIMESTAMPDIFF(MINUTE,UltimaInterazione,InizioInterazione) > @max_timeout  THEN
			INSERT INTO `Transazioni` () VALUES();
		END IF;

		-- setto a 1 il dispositivo nella transazione corrente
		SET @sql_text = concat('UPDATE `Transazioni` SET `D', IdDispositivo, '` = 1 WHERE `ID` = ', LAST_INSERT_ID());
		PREPARE stmt FROM @sql_text;

		EXECUTE stmt;

		SET primoInserimento = 0;
		SET UltimaInterazione = InizioInterazione;

	END LOOP scan;
	CLOSE cursore;

END $$
DELIMITER ;

CALL FillTransazioni();

-- creazione della tabella con gli itemset
-- ogni itemset può contenere n dispositivi
-- ogni riga è un dispositivo

DROP TABLE IF EXISTS `ItemsSets`;
CREATE TABLE `ItemsSets`(
	ID INT AUTO_INCREMENT PRIMARY KEY,
	IdItemset INT,
	IdDispositivo INT,
    SupportCount INT
)ENGINE = InnoDB DEFAULT CHARSET = latin1;

-- stored procedure che viene chiamata alla prima iterazione per pienare la tabella itemset

DROP PROCEDURE IF EXISTS CreateItems;
DELIMITER $$
CREATE PROCEDURE CreateItems()
BEGIN
	
	DECLARE finito INT DEFAULT 0;
	DECLARE IdDispositivo INT;

    DECLARE currentItemsetId INT DEFAULT 1;

	DECLARE cursore CURSOR FOR
		SELECT d.IdDispositivo
		FROM `Dispositivo` d;
	
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET finito = 1;
	
	OPEN cursore;
	
	scan: LOOP

		FETCH cursore INTO IdDispositivo;

		IF finito = 1 THEN LEAVE scan; END IF;
		
		-- conto il numero di volete che un dispositivo viene utilizzato
		SET @columnDispositivo = CONCAT('D', IdDispositivo);

        SET @stmt = CONCAT(
            'SET @count = (SELECT COUNT(*) FROM `Transazioni` WHERE ',
            @columnDispositivo,
            '= 1);'
        );

        PREPARE query FROM @stmt;
        EXECUTE query;

		-- se l'itemset non supera il minimo support non viene inserito nei large itemset
		IF @count < @support_treshold THEN
			ITERATE scan;
        END IF;

		-- mi ricavo l'itemset corrente
        SET currentItemsetId = (SELECT MAX(IdItemset) FROM `ItemsSets`) + 1;

        IF currentItemsetId IS NULL THEN
            SET currentItemsetId = 1;
        END IF;

		-- inserisco il dispositivo nell'itemset corrente
		INSERT INTO `ItemsSets` (ID, IdItemset, IdDispositivo, SupportCount) VALUES( DEFAULT, currentItemsetId, IdDispositivo, @count);

	END LOOP scan;
	CLOSE cursore;
END $$
DELIMITER ;



DROP PROCEDURE IF EXISTS UpdateItems;
DELIMITER $$
CREATE PROCEDURE UpdateItems(k INT)
BEGIN
	
	DECLARE IdDispositivo1 INT;
    DECLARE IdDispositivo2 INT;
    DECLARE currentItemsetId INT DEFAULT 1;

	DECLARE finito INT DEFAULT 0;

	-- eseguo il cross join tra i dispositivi nella tabella itemset
	DECLARE cursore CURSOR FOR
		SELECT d.IdDispositivo, f.IdDispositivo 
		FROM `ItemsSets` d, `ItemsSets` f
        WHERE d.IdDispositivo <> f.IdDispositivo;
	
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET finito = 1;
	
	OPEN cursore;
	
	scan: LOOP

		FETCH cursore INTO IdDispositivo1, IdDispositivo2;

		IF finito = 1 THEN LEAVE scan; END IF;
		
		-- conto il numero di volete che i due dispositivi sono apparsi insieme
		SET @columnDispositivo1 = CONCAT('D', IdDispositivo1);
		SET @columnDispositivo2 = CONCAT('D', IdDispositivo2);

        SET @stmt = CONCAT(
            'SET @count = (SELECT COUNT(*) FROM `Transazioni` WHERE ',
            @columnDispositivo1,
            ' = 1 AND ',
            @columnDispositivo2,
            ' = 1);'
        );

        PREPARE query FROM @stmt;
        EXECUTE query;

		-- se non supera il minimo support non viene inserito
		IF @count < @support_treshold THEN
			ITERATE scan;
        END IF;
        
		-- mi ricavo l'itemset corrente
        SET currentItemsetId = (SELECT MAX(IdItemset) FROM `ItemsSets`) + 1;

        IF currentItemsetId IS NULL THEN
            SET currentItemsetId = 1;
        END IF;

		-- inserisco i dispositivi nell'itemset corrente
		INSERT INTO `ItemsSets` (ID, IdItemset, IdDispositivo, SupportCount) VALUES( DEFAULT, currentItemsetId, IdDispositivo1, @count);
		INSERT INTO `ItemsSets` (ID, IdItemset, IdDispositivo, SupportCount) VALUES( DEFAULT, currentItemsetId, IdDispositivo2, @count);
		

	END LOOP scan;
	CLOSE cursore;
END $$
DELIMITER ;



DROP PROCEDURE IF EXISTS FillItems;
DELIMITER $$
CREATE PROCEDURE FillItems(k INT)
BEGIN
	
	-- se è la prima itezione chiamo la stored procedure che crea la tabella itemsset
	IF k <= 2 THEN
		CALL CreateItems();
	-- altrimenti la aggiorno
    ELSEIF k = 3 THEN
        CALL UpdateItems(k);
	END IF;

END $$
DELIMITER ;


-- Adesso ricavo le regole attraverso la formula  conf(X => Y)
DROP TABLE IF EXISTS `Regole`;
CREATE TABLE `Regole`(
	ID INT AUTO_INCREMENT PRIMARY KEY,
    IdAntecedente INT,
    IdConseguente INT
);

DROP PROCEDURE IF EXISTS CreateRules;
DELIMITER $$
CREATE PROCEDURE CreateRules()
BEGIN

    DECLARE finito INT DEFAULT 0;
    DECLARE IdDispositivo1 INT DEFAULT 0;
    DECLARE IdDispositivo2 INT DEFAULT 0;
    DECLARE ItemsetSupport INT DEFAULT 0;

	-- negli itemssets cerco quelli con più di un dispositivo
	DECLARE cursore CURSOR FOR
        SELECT j.IdDispositivo, j.SupportCount
        FROM `itemssets` j
        WHERE j.IdItemset IN (
            SELECT i.IdItemset
            FROM `itemssets` i
            GROUP BY i.IdItemset
            HAVING COUNT(*) >= 2
        );
	
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET finito = 1;
	
	OPEN cursore;
	
	scan: LOOP

		-- mi ricavo gli ID e il support dell'itemset
		FETCH cursore INTO IdDispositivo1, ItemsetSupport;
		FETCH cursore INTO IdDispositivo2, ItemsetSupport;

		IF finito = 1 THEN LEAVE scan; END IF;
    
		-- mi ricavo il support del primo dispositivo
        SET @IdDispositivo1Support = (SELECT i.SupportCount FROM `ItemsSets` i WHERE i.IdDispositivo = IdDispositivo1 LIMIT 1);
		-- mi ricavo il support del secondo dispositivo
		SET @IdDispositivo2Support = (SELECT i.SupportCount FROM `ItemsSets` i WHERE i.IdDispositivo = IdDispositivo2 LIMIT 1);
	
		-- seguendo la regola calcolo X U Y / X e controllo se supera la confidence
		-- se si la inserisco tra le regole forti
        IF ItemsetSupport / @IdDispositivo1Support > @confidence THEN
            INSERT INTO `Regole` (ID, IdAntecedente, IdConseguente) VALUES (DEFAULT, IdDispositivo1, IdDispositivo2);
        END IF;

		-- seguendo la regola calcolo X U Y / Y e controllo se supera la confidence prestabilita
		-- se si la inserisco tra le regole forti
        IF ItemsetSupport / @IdDispositivo2Support > @confidence THEN
            INSERT INTO `Regole` (ID, IdAntecedente, IdConseguente) VALUES (DEFAULT, IdDispositivo2, IdDispositivo1);
        END IF;
        
    END LOOP scan;
	CLOSE cursore;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS Apriori;
DELIMITER $$
CREATE PROCEDURE Apriori()
BEGIN

	DECLARE k INT DEFAULT 2;
    DECLARE tot INT;
	SET tot = (select count(*) from Dispositivo);
	
	-- eseguo il loop di apriori tot volte
	apriori: loop
		
		IF k > tot THEN LEAVE apriori; END IF;	

		-- riempio la gli itemset k-esimi
		CALL FillItems(k);

		SET k = k + 1;
	END LOOP apriori; 

	-- alla fine cerco le regole forti
    CALL CreateRules();


END $$
DELIMITER ;

call Apriori();


SELECT * FROM `Transazioni`;
SELECT * FROM `ItemsSets`;
SELECT * FROM `Regole`;

