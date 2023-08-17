SET NAMES latin1;
SET FOREIGN_KEY_CHECKS = 0;

BEGIN;
DROP DATABASE IF EXISTS `mySmartHome`;
CREATE DATABASE `mySmartHome`;
COMMIT;

USE `mySmartHome`;

-- dove c'è il commento nn significa che (forse) si puo togliere il NOT NULL

--#region Area Generale


CREATE TABLE `Documento` (
    `Numero` VARCHAR(50) NOT NULL,
    `Tipologia` VARCHAR(15) NOT NULL CHECK (Tipologia IN ("CartaIdentita", "Patente", "Passaporto")),
    `EnteRilascio` VARCHAR(50) NOT NULL,
    `DataScadenza` DATE NOT NULL,

    `CodFiscale` VARCHAR(16) NOT NULL,

    PRIMARY KEY(`Numero`,`Tipologia`), --
    FOREIGN KEY (`CodFiscale`) REFERENCES `Utente`(`CodFiscale`) ON DELETE CASCADE
    
) ENGINE = InnoDB DEFAULT CHARSET = latin1;


CREATE TABLE `Utente` (
    
    `CodFiscale` VARCHAR(16) NOT NULL,
    `Nome` VARCHAR(50) NOT NULL,
    `Cognome` VARCHAR(50) NOT NULL,
    `Telefono` VARCHAR(10) NOT NULL, -- nn
    `DataNascita` DATE NOT NULL,
    
    PRIMARY KEY (`CodFiscale`)
    
)ENGINE = InnoDB DEFAULT CHARSET = latin1;


CREATE TABLE `Account` (
    
    `NomeUtente` VARCHAR(50) NOT NULL,
    `Password` VARCHAR(50) NOT NULL,
    `DataIscrizione` DATE NOT NULL,
    `Risposta` VARCHAR(50) NOT NULL,

    `CodFiscale` VARCHAR(16) NOT NULL,
    `IdDomanda` INT NOT NULL,

    PRIMARY KEY (`NomeUtente`),
    FOREIGN KEY (`CodFiscale`) REFERENCES `Utente`(`CodFiscale`) ON DELETE CASCADE,
    FOREIGN KEY (`IdDomanda`) REFERENCES `DomandaSicurezza`(`IdDomanda`) ON DELETE CASCADE

)ENGINE = InnoDB DEFAULT CHARSET = latin1;


CREATE TABLE `DomandaSicurezza` (

    `IdDomanda` INT AUTO_INCREMENT NOT NULL,
    `Testo` VARCHAR(50) NOT NULL,

    PRIMARY KEY (`IdDomanda`)

)ENGINE = InnoDB DEFAULT CHARSET = latin1;


CREATE TABLE `Stanza` (

    `IdStanza` INT AUTO_INCREMENT NOT NULL,
    `Nome` VARCHAR(30) NOT NULL ,
    `Piano` VARCHAR(30) NOT NULL, -- se metto come tipo TINYINT ? 
    `Lunghezza` FLOAT NOT NULL, -- cosa cambia se metto DOUBLE ?
    `Larghezza` FLOAT NOT NULL, -- DOUBLE ?
    `Altezza` FLOAT NOT NULL, -- DOUBLE ?
    `Dispersione` FLOAT NOT NULL, --  DOUBLE ?
    
    PRIMARY KEY (`IdStanza`)

)ENGINE = InnoDB DEFAULT CHARSET = latin1;


CREATE TABLE `Finestra` (

    `IdFinestra` INT AUTO_INCREMENT NOT NULL,
    `Tipo`  VARCHAR(13) NOT NULL CHECK(Tipo IN ("Finestra", "Portafinestra")),
    `Cardinale` VARCHAR(2) CHECK(Cardinale IN ("N", "NE", "NW", "S", "SE", "SW", "E", "W")), -- nn
    
    `IdStanza` INT NOT NULL,

    PRIMARY KEY (`IdFinestra`),
    FOREIGN KEY (`IdStanza`) REFERENCES `Stanza`(`IdStanza`) ON DELETE CASCADE

)ENGINE = InnoDB DEFAULT CHARSET = latin1;


CREATE TABLE `Porta` (

    `IdPorta` INT AUTO_INCREMENT NOT NULL,
    `Interna` BOOLEAN, -- nn
    
    `IdStanza` INT NOT NULL,

    PRIMARY KEY (`IdPorta`),
    FOREIGN KEY (`IdStanza`) REFERENCES `Stanza`(`IdStanza`) ON DELETE CASCADE

)ENGINE = InnoDB DEFAULT CHARSET = latin1;


CREATE TABLE `Varco` (

    `IdPorta` INT NOT NULL,
    `IdStanza` INT NOT NULL,

    PRIMARY KEY (`IdPorta`,`IdStanza`),
    FOREIGN KEY (`IdPorta`) REFERENCES `Porta`(`IdPorta`) ON DELETE CASCADE,
    FOREIGN KEY (`IdStanza`) REFERENCES `Stanza`(`IdStanza`) ON DELETE CASCADE

)ENGINE = InnoDB DEFAULT CHARSET = latin1;


--#endregion


--#region Area dispositivi


CREATE TABLE `SmartPlug` (

    `Codice` INT AUTO_INCREMENT NOT NULL,
    `Stato` BOOLEAN NOT NULL,
    
    `IdStanza` INT NOT NULL,

    PRIMARY KEY (`Codice`), 
    FOREIGN KEY (`IdStanza`) REFERENCES `Stanza`(`IdStanza`) ON DELETE CASCADE

) ENGINE = InnoDB DEFAULT CHARSET = latin1;


CREATE TABLE `Dispositivo` (
    
    `IdDispositivo` INT AUTO_INCREMENT NOT NULL, 
    `Nome` VARCHAR(50) NOT NULL, -- nn
    `TipoConsumo` VARCHAR(10) NOT NULL CHECK(TipoConsumo IN ("Fisso", "Variabile")), -- nn, se metto `TipoConsumo` ENUM("Fisso", "Variabile") NOT NULL ?
    
    `Codice` INT NOT NULL,

    PRIMARY KEY (`IdDispositivo`), 
    FOREIGN KEY (`Codice`) REFERENCES `SmartPlug`(`Codice`) ON DELETE CASCADE

) ENGINE = InnoDB DEFAULT CHARSET = latin1;


CREATE TABLE `Potenza` (
    
    `IdLivelloPotenza` INT AUTO_INCREMENT NOT NULL, 
    `Descrizione` INT NOT NULL, -- nn, se metto `Descrizione` TINYINT NOT NULL ?
    `ConsumoPerTempo` FLOAT NOT NULL, -- DOUBLE ?
    
    `IdDispositivo` INT NOT NULL,

    PRIMARY KEY (`IdLivelloPotenza`), 
    FOREIGN KEY (`IdDispositivo`) REFERENCES `Dispositivo`(`IdDispositivo`) ON DELETE CASCADE

) ENGINE = InnoDB DEFAULT CHARSET = latin1;


CREATE TABLE `Programma` (
    
    `Codice` INT AUTO_INCREMENT NOT NULL, 
    `Nome` VARCHAR(20) NOT NULL, -- nn
    `DurataMedia` INT NOT NULL,     -- secondi
    `ConsumoMedio` FLOAT NOT NULL, -- o DOUBLE ?
    
    `IdDispositivo` INT NOT NULL,

    PRIMARY KEY (`Codice`), 
    FOREIGN KEY (`IdDispositivo`) REFERENCES `Dispositivo`(`IdDispositivo`) ON DELETE CASCADE

) ENGINE = InnoDB DEFAULT CHARSET = latin1;


CREATE TABLE `RegolazioneDispositivo` (
    
    `CodRegolazione` INT AUTO_INCREMENT NOT NULL, 

    `IdDispositivo` INT NOT NULL,
    `Codice` INT,
    `IdLivelloPotenza` INT,

    PRIMARY KEY (`CodRegolazione`), 
    FOREIGN KEY (`IdDispositivo`) REFERENCES `Dispositivo`(`IdDispositivo`) ON DELETE CASCADE,
    FOREIGN KEY (`Codice`) REFERENCES `Programma`(`Codice`) ON DELETE CASCADE,
    FOREIGN KEY (`IdLivelloPotenza`) REFERENCES `Potenza`(`IdLivelloPotenza`) ON DELETE CASCADE

) ENGINE = InnoDB DEFAULT CHARSET = latin1;


--#endregion 


--#region AreaEnergia


CREATE TABLE `Interazione`(

    `IdInterazione` INT AUTO_INCREMENT NOT NULL,
    `Inizio` TIMESTAMP NOT NULL, -- per mettere un campo con data e ora dell'inizio dell'interazione va bene questo ? lo stesso per fine
    `Fine` TIMESTAMP NOT NULL,  -- nn
    `ComandoVocale` BOOLEAN NOT NULL DEFAULT FALSE, -- nn
    `EnergiaConsumata` FLOAT CHECK(EnergiaConsumata>=0), -- nn

    `IdFascia` INT,
    `NomeUtente` VARCHAR(50) NOT NULL,
    `IdSchedule` INT, 

    `CodRegolazioneDispositivo` INT,
    `CodRegolazioneClima` INT,
    `CodRegolazioneIlluminazione` INT, 

    PRIMARY KEY (`IdInterazione`), 
    FOREIGN KEY (`IdFascia`) REFERENCES `FasciaOraria`(`IdFascia`) ON DELETE CASCADE,
    FOREIGN KEY (`NomeUtente`) REFERENCES `Accout`(`NomeUtente`) ON DELETE CASCADE,
    FOREIGN KEY (`IdSchedule`) REFERENCES `Schedule`(`IdSchedule`) ON DELETE CASCADE,
    FOREIGN KEY (`CodRegolazioneDispositivo`) REFERENCES `RegolazioneDispositivo`(`CodRegolazione`) ON DELETE CASCADE,
    FOREIGN KEY (`CodRegolazioneClima`) REFERENCES `RegolazioneClima`(`CodClima`) ON DELETE CASCADE,
    FOREIGN KEY (`CodRegolazioneIlluminazione`) REFERENCES `RegolazioneIlluminazione`(`CodIlluminazione`) ON DELETE CASCADE

)ENGINE = InnoDB DEFAULT CHARSET = latin1;


CREATE TABLE `FasciaOraria`(

    `IdFascia` INT AUTO_INCREMENT NOT NULL,
    `Nome` VARCHAR(30) NOT NULL, -- ad esempio F1, F2, ...
    `Inizio` TIME NOT NULL, 
    `Fine` TIME NOT NULL, 
    `PrezzoRin` FLOAT NOT NULL CHECK(PrezzoRin>0), -- nn
    `CostoNonRin` FLOAT NOT NULL CHECK(CostoNonRin>0), -- nn
    `SceltaUtilizzo` VARCHAR(50) NOT NULL CHECK(`SceltaUtilizzo` IN ("UtilizzareEnergiaAutoprodotta", "ReimmettereNellaRete")), -- per una determinata fascia oraria l'utente sceglie se preferire che l'eventuale energia autoprodotta venga utilizzata per il fabbisogno, oppure che venga reimmessa nella rete

    PRIMARY KEY (`IdFascia`) 

)ENGINE = InnoDB DEFAULT CHARSET = latin1;


CREATE TABLE `EnergiaProdotta`(
    
    `IdEnergia` INT AUTO_INCREMENT NOT NULL, 
    `Timestamp` DATETIME NOT NULL, -- oppure TIMESTAMP ?
    `Irraggiamento` FLOAT NOT NULL CHECK(Irraggiamento>=0), 
    `Quantita` FLOAT NOT NULL CHECK(Quantita>=0), -- DOUBLE , dato calcolato con EnergiaProdotta.Irraggiamento e Pannello.Superfice
    
    `IdPannello` INT NOT NULL,
    `IdFascia` INT NOT NULL,

    PRIMARY KEY (`IdEnergia`),
    FOREIGN KEY (`IdPannello`) REFERENCES `Pannello`(`IdPannello`) ON DELETE CASCADE,
    FOREIGN KEY (`IdFascia`) REFERENCES `FasciaOraria`(`IdFascia`) ON DELETE CASCADE

)ENGINE = InnoDB DEFAULT CHARSET = latin1;


CREATE TABLE `Pannello` (

    `IdPannello` INT AUTO_INCREMENT NOT NULL, 
    `Superficie` FLOAT NOT NULL CHECK(Superficie>0),  -- m^2, DOUBLE ?

    PRIMARY KEY (`IdPannello`)

)ENGINE = InnoDB DEFAULT CHARSET = latin1;


CREATE TABLE `Notifica` (

    `IdNotifica` INT AUTO_INCREMENT NOT NULL,
    `Invio` TIMESTAMP NOT NULL,
    `Risposta` BOOLEAN NOT NULL DEFAULT FALSE, 

    `Codice` INT NOT NULL, 
    `NomeUtente` VARCHAR(50) NOT NULL,

    PRIMARY KEY (`IdNotifica`),
    FOREIGN KEY (`Codice`) REFERENCES `Programma`(`Codice`) ON DELETE CASCADE,
    FOREIGN KEY (`NomeUtente`) REFERENCES `Accout`(`NomeUtente`) ON DELETE CASCADE

)ENGINE = InnoDB DEFAULT CHARSET = latin1;


--#endregion


--#region Area comfort 


CREATE TABLE `RegistroTemperatura` (
    
    `IdRegistroTemperatura` INT AUTO_INCREMENT NOT NULL,
    `Timestamp` DATETIME NOT NULL, -- 
    `TemperaturaOut` FLOAT NOT NULL, -- 
    `TemperaturaIn` FLOAT NOT NULL, -- 
    `Efficienza` FLOAT CHECK(Efficienza>=0), -- nn perche questo campo va calcolato con una formula

    `IdStanza` INT NOT NULL,

    PRIMARY KEY (`IdRegistroTemperatura`), 
    FOREIGN KEY (`IdStanza`) REFERENCES `Stanza`(`IdStanza`) ON DELETE CASCADE

) ENGINE = InnoDB DEFAULT CHARSET = latin1;


CREATE TABLE `Condizionatore` (
    
    `IdCondizionatore` INT AUTO_INCREMENT NOT NULL,
    `Nome` VARCHAR(50), -- nn

    `IdStanza` INT NOT NULL,

    PRIMARY KEY (`IdCondizionatore`), 
    FOREIGN KEY (`IdStanza`) REFERENCES `Stanza`(`IdStanza`) ON DELETE CASCADE

) ENGINE = InnoDB DEFAULT CHARSET = latin1;


CREATE TABLE `Luce` (
    `IdLuce` INT AUTO_INCREMENT NOT NULL,
    `Nome` VARCHAR(50) NOT NULL, -- nn

    `IdStanza` INT NOT NULL,

    PRIMARY KEY (`IdLuce`), 
    FOREIGN KEY (`IdStanza`) REFERENCES `Stanza`(`IdStanza`) ON DELETE CASCADE
    
) ENGINE = InnoDB DEFAULT CHARSET = latin1;


CREATE TABLE `RegolazioneClima` (

    `CodClima` INT AUTO_INCREMENT NOT NULL, 
    `Temperatura` FLOAT NOT NULL CHECK (Temperatura BETWEEN 10 AND 30), -- DOUBLE ?
    `Umidita` FLOAT NOT NULL CHECK (Umidita BETWEEN 30 AND 70), -- DOUBLE ?
    `Predefinita` BOOLEAN NOT NULL DEFAULT FALSE,
    `Consumo` FLOAT NOT NULL, -- DOUBLE ?

    `IdCondizionatore` INT NOT NULL,

    PRIMARY KEY (`CodClima`), 
    FOREIGN KEY (`IdCondizionatore`) REFERENCES `Condizionatore`(`IdCondizionatore`)  ON DELETE CASCADE
    
) ENGINE = InnoDB DEFAULT CHARSET = latin1;


CREATE TABLE `RegolazioneIlluminazione` (

    `CodIlluminazione` INT AUTO_INCREMENT NOT NULL, 
    `Intensita` FLOAT NOT NULL, 
    `TemperaturaColore` FLOAT NOT NULL, -- misurata in Kelvin
    `Predefinita` BOOLEAN NOT NULL DEFAULT FALSE,
    `Consumo` FLOAT NOT NULL, -- DOUBLE ?

    `IdLuce` INT NOT NULL,

    PRIMARY KEY (`CodIlluminazione`), 
    FOREIGN KEY (`IdLuce`) REFERENCES `Luce`(`IdLuce`) ON DELETE CASCADE

) ENGINE = InnoDB DEFAULT CHARSET = latin1;


CREATE TABLE `Schedule` (
    `IdSchedule` INT AUTO_INCREMENT NOT NULL,
    `Durata` INT NOT NULL CHECK (Durata BETWEEN 1 AND 24), -- in ore 
    `PeriodoRipetizione` INT, -- in ore, nn perchè campo opzionale
    
    `CodClima` INT NOT NULL, 

    PRIMARY KEY (`IdSchedule`), 
    FOREIGN KEY (`CodClima`) REFERENCES `RegolazioneClima`(`CodClima`) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = latin1;


--#endregion 


SET FOREIGN_KEY_CHECKS = 1;
