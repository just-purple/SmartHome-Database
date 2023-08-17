#[]INSERIMENTO DI UN NUOVO UTENTE

drop procedure if exists NuovoUtente; 
delimiter $$
create procedure NuovoUtente    (
                                    in CodFiscale varchar(16), --
                                    in Nome varchar(50), --
                                    in Cognome varchar(50), --
                                    in DataNascita date, --
                                    in Telefono varchar(10), --

                                    in Tipologia varchar(15), 
                                    in Numero varchar(50), -- 
                                    in DataScadenza date, 
                                    in EnteRilascio varchar(50),

                                    in NomeUtente varchar(50), 
                                    in Password varchar(50),
                                    in Risposta varchar(50)
                                    -- in DataIscrizione date,

                                    -- in IdDomanda int,
                                    -- in Testo varchar(50)
							    )
begin 
    
    if datediff(current_date, DataScadenza) < 0 && (length(Password) > 8 && length(NomeUtente) > 3) then 
		begin 
			insert into Utente values (CodFiscale, Nome, Cognome, DataNascita, Telefono);
            insert into Documento values (Tipologia, Numero, DataScadenza, EnteRilascio); 
            insert into Account values (NomeUtente, Password, Risposta, current_date);
        end ; 
	else
    
    -- formula generica per settare un messaggio di errore da restituire
    signal sqlstate '45000'
    set message_text='Errore, dati non corretti. Inserire un documento non scaduto, una password lunga almeno 9 caratteri e un nome utente lungo almeno 4 caratteri';
	end if;

end $$
delimiter ; 
#------------------------------------------------------------------------------------------------------------

#[]INSERIMENTO DI UN NUOVO CONTRATTO DI GESTIONE DELLA ENERGIA
drop procedure if exists NuovoContratto; 
delimiter $$
create procedure NuovoContratto (
                                    -- in IdFascia INT,
                                    in Nome VARCHAR(30), 
                                    in Inizio TIME , 
                                    in Fine TIME, 
                                    in PrezzoRin FLOAT, 
                                    in CostoNonRin FLOAT,
                                    in SceltaUtilizzo VARCHAR(30)
                                )
begin

if (length(Nome) > 0) && (PrezzoRin > 0 && CostoNonRin > 0) then 
		begin 
			insert into FasciaOraria values (default, Nome, Inizio, Fine, PrezzoRin, CostoNonRin, SceltaUtilizzo);
        end ; 
	else 
    signal sqlstate '45000'
    set message_text='Errore, dati non corretti. Inserire un nome di almeno 1 carattere e prezzo e costo maggiori di zero';
	end if;

end $$
delimiter ; 

#------------------------------------------------------------------------------------------------------------


#[] -- ENERGIA CONSUMATA DA UN DISPOSITIVO IN UN GIORNO
drop procedure if exists energia_dispositivo;
delimiter $$
create procedure energia_dispositivo(in _dispositivo int, in to_check date, out energia double)
begin
        declare Consumo double default 0;
            
        set energia = 0;

	set consumo = ( 
                    select sum(I.EnergiaConsumata)
					from Interazione I, RegolazioneDispositivo RD, Dispositivo D
					where D.IdDispositivo = _dispositivo and _dispositivo = RD.IdDispositivo and I.CodRegolazioneDispositivo = RD.CodRegolazione
                        and ( DAY(I.Inizio) between DAY(to_check) and DAY(to_check) ) and (I.EnergiaConsumata is not null)
                       
                  ); 
	
    set energia = ifnull(EnergiaConsumata,0);
    
end $$
delimiter ;


#[6] -- ENERGIA CONSUMATA DA UN DISPOSITIVO IN UN GIORNO, ULTIMA VERSIONE MODIFICATA
drop procedure if exists energia_dispositivo;
delimiter $$
create procedure energia_dispositivo(in _dispositivo int, in to_check date, out energia float)
begin
        

	set energia= ( 
                    select sum(I.EnergiaConsumata)
					from Interazione I  INNER JOIN RegolazioneDispositivo RD ON I.CodRegolazioneDispositivo=RD.CodRegolazione
							INNER JOIN  Dispositivo D ON RD.IdDispositivo=D.IdDispositivo
					where D.IdDispositivo = _dispositivo
                        and DAY(I.Inizio)=DAY(to_check) AND DAY(I.Fine)=DAY(to_check) and (I.EnergiaConsumata is not null)
                       
                  ); 
	

end $$
delimiter ;
-- CALL energia_dispositivo(1,'2022-03-29',@variabile);
-- SELECT @variabile;

-- energia autoprodotta o richiesta dalla rete in un giorno

drop procedure if exists energia_consumata;
delimiter $$
create procedure energia_consumata(in to_check date, out energia double)
begin
    SET energia =   (
                    SELECT (SUM(E.Quantita) - SUM(I.EnergiaConsumata)) AS energia_prodotta_o_richiesta
                    FROM EnergiaProdotta E
                        INNER JOIN FasciaOraria F ON E.IdFascia =  F.IdFascia
                        INNER JOIN Interazione I ON I.IdFascia = F.IdFascia
                    WHERE DAY(E.Timestamp) = DAY(to_check) AND DAY(I.Inizio)=DAY(to_check)
                    ) ;

end $$

DROP EVENT IF EXISTS consumi_giorno$$
CREATE EVENT consumi_giorno
ON SCHEDULE EVERY 1 DAY
STARTS '2022-03-29 00:00:00'
DO
	CALL energia_consumata(@consumigg)$$
    
SELECT @consumigg;

-- delimiter ;


# -- RIASSUNTO ENERGIA CONSUMATA GIORNALMENTE DAGLI ELEMENTI DI CONDIZIONAMENTO IN BASE ALL'ENERGIA PRODOTTA QUEL GIORNO
DELIMITER $$
DROP PROCEDURE IF EXISTS consumo_giornaliero_cond $$
CREATE PROCEDURE consumo_giornaliero_cond( OUT consumo_giornaliero_ FLOAT)
BEGIN


SET consumo_giornaliero_=(SELECT SUM( I.EnergiaConsumata) 
						FROM Interazione I
						WHERE I.CodRegolazioneClima IS NOT NULL
							AND DAY(I.Inizio)=DAY(CURRENT_DATE)
							AND DAY(I.Fine)=DAY(CURRENT_DATE));


END$$


DROP EVENT IF EXISTS consumo_per_giorno$$
CREATE EVENT consumo_per_giorno
ON SCHEDULE EVERY 1 DAY
STARTS '2022-03-29 22:40:00'
DO
	CALL consumo_giornaliero_cond(@consumo)$$
    
SELECT @consumo;

#-------------------------------------------------------------------------------------------------------------------------------
# ---- Account che ha consumato maggiormente energia nell'ultimo mese---------------------------------------------------------------------------------------------------------------------------------------


DROP PROCEDURE IF EXISTS consumo_account_mese;
DELIMITER $$
CREATE PROCEDURE consumo_account_mese(OUT account_ VARCHAR(50))
BEGIN
 
 WITH consumo_energia AS(
	SELECT I1.NomeUtente, SUM(I1.EnergiaConsumata) AS consumo
	FROM Interazione I1
	WHERE 
		MONTH(I1.Inizio)=MONTH(CURRENT_DATE)
		AND MONTH (I1.Fine)=MONTH(CURRENT_DATE)
	 GROUP BY I1.NomeUtente,I1.EnergiaConsumata 
  )
  SELECT I2.NomeUtente INTO account_
  FROM Interazione I2
  WHERE MONTH(I2.Inizio)=MONTH(CURRENT_DATE)
		AND MONTH (I2.Fine)=MONTH(CURRENT_DATE)

  GROUP BY I2.NomeUtente,I2.EnergiaConsumata
  HAVING SUM(I2.EnergiaConsumata)>ALL(SELECT CE.consumo
									FROM consumo_energia CE
									WHERE CE.NomeUtente<>I2.NomeUtente);
 END $$
 
DELIMITER ;

#---- 

-- verificare le smart plug inattive

drop procedure if exists sp_inattive;
delimiter $$
create procedure sp_inattive()
begin
	select Codice
	from SmartPlug
	where Stato='0';
end $$
delimiter ;

-- call sp_inattive();


#---- Regolazione Più frequente di una luce---------------------------------------------------------------------------------------------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS regolazione_frequente;
DELIMITER $$
CREATE PROCEDURE regolazione_frequente(OUT luce_ INTEGER)
BEGIN
	 WITH regolazione AS(
	SELECT I.CodRegolazioneIlluminazione, Count(*) As TotRegolazioni
	FROM Interazione I
    WHERE I.CodRegolazioneIlluminazione IS NOT NULL   
	GROUP BY I.CodRegolazioneIlluminazione 
  )
  SELECT I2.CodRegolazioneIlluminazione INTO luce_
  FROM Interazione I2
  WHERE I2.CodRegolazioneIlluminazione IS NOT NULL
  GROUP BY I2.CodRegolazioneIlluminazione
  HAVING COUNT(*)>ALL(SELECT R.TotRegolazioni
						FROM regolazione R
                        WHERE R.CodRegolazioneIlluminazione<>I2.CodRegolazioneIlluminazione);
                        
END $$
DELIMITER ;

