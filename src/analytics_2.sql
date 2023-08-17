use `mySmartHome`;

-- abbiamo deciso di trovare qual è la fascia oraria in cui c'è più energia disponibile
-- in modo da suggerire in che momento accendere i propri dispositivi in modo da salvaguardare l'ambiente



-- ricavo l'energia disponibile per ogni fascia oraria dalla differenza fra energia prodotta e energia consumata, calcolate sotto
SELECT (P.Energiaprodotta - U.EnergiaConsumata) as EnergiaDisponibile, P.Nome as FasciaOraria

FROM (  -- calcolo di tutta la quantita di energia prodotta dai pannelli per ogni fascia oraria
        SELECT SUM(e.Quantita) as Energiaprodotta, f.IdFascia as IdFascia, f.Nome as Nome
        FROM energiaprodotta e
        INNER JOIN fasciaoraria f ON f.IdFascia = e.IdFascia
        GROUP BY f.IdFascia
     ) as P
INNER JOIN (    -- calcolo dell'energia consumata dalle interazioni per ogni fascia oraria
                SELECT SUM(i.EnergiaConsumata) as EnergiaConsumata, f.IdFascia as IdFascia
                FROM interazione i
                INNER JOIN fasciaoraria f ON f.IdFascia = i.IdFascia 
                GROUP BY f.IdFascia
           ) as U
-- la congiunzione fra le due tabelle è sulla stessa fascia oraria
ON P.IdFascia = U.IdFascia

-- ordino in modo decrescente (descending) la tabella relativa all'energia disponibile per ogni fascia oraria
ORDER BY EnergiaDisponibile DESC;