-- =====================================================
-- Banking Fraud Detection & Risk Analytics
-- Analyse SQL des transactions bancaires
-- =====================================================

-- 1. Volume global et montant moyen

SELECT
  is_fraud,
  COUNT(*) AS transactions,
  ROUND(AVG(transaction_amount::NUMERIC), 2) AS montant_moyen
FROM transactions
GROUP BY is_fraud;


-- 2. Taux de fraude par catégorie de marchand

SELECT
  merchant_category AS categorie_marchand,
  COUNT(*) AS transactions,
  SUM(is_fraud::INTEGER) AS fraudes,
  ROUND(
    100.0 * SUM(is_fraud::INTEGER) / COUNT(*),
    3
  ) AS taux_fraude_pct
FROM transactions
GROUP BY merchant_category
ORDER BY taux_fraude_pct DESC;


-- 3. Taux de fraude par tranche de montant

SELECT
  CASE
    WHEN transaction_amount::NUMERIC < 50 THEN '0-49'
    WHEN transaction_amount::NUMERIC < 100 THEN '50-99'
    WHEN transaction_amount::NUMERIC < 250 THEN '100-249'
    WHEN transaction_amount::NUMERIC < 500 THEN '250-499'
    ELSE '500+'
  END AS tranche_montant,
  COUNT(*) AS transactions,
  SUM(is_fraud::INTEGER) AS fraudes,
  ROUND(
    100.0 * SUM(is_fraud::INTEGER) / COUNT(*),
    3
  ) AS taux_fraude_pct
FROM transactions
GROUP BY tranche_montant
ORDER BY tranche_montant;


-- 4. Taux de fraude par heure

SELECT
  transaction_hour::INTEGER AS heure,
  COUNT(*) AS transactions,
  SUM(is_fraud::INTEGER) AS fraudes,
  ROUND(
    100.0 * SUM(is_fraud::INTEGER) / COUNT(*),
    3
  ) AS taux_fraude_pct
FROM transactions
GROUP BY transaction_hour::INTEGER
ORDER BY heure;


-- 5. Taux de fraude par canal

SELECT
  transaction_channel AS canal,
  COUNT(*) AS transactions,
  SUM(is_fraud::INTEGER) AS fraudes,
  ROUND(
    100.0 * SUM(is_fraud::INTEGER) / COUNT(*),
    3
  ) AS taux_fraude_pct
FROM transactions
GROUP BY transaction_channel
ORDER BY taux_fraude_pct DESC;


-- 6. Croisement canal et plage horaire

SELECT
  transaction_channel AS canal,
  CASE
    WHEN transaction_hour::INTEGER BETWEEN 0 AND 5 THEN '00-05'
    WHEN transaction_hour::INTEGER BETWEEN 6 AND 11 THEN '06-11'
    WHEN transaction_hour::INTEGER BETWEEN 12 AND 17 THEN '12-17'
    ELSE '18-23'
  END AS plage_horaire,
  COUNT(*) AS transactions,
  SUM(is_fraud::INTEGER) AS fraudes,
  ROUND(
    100.0 * SUM(is_fraud::INTEGER) / COUNT(*),
    3
  ) AS taux_fraude_pct
FROM transactions
GROUP BY
  transaction_channel,
  CASE
    WHEN transaction_hour::INTEGER BETWEEN 0 AND 5 THEN '00-05'
    WHEN transaction_hour::INTEGER BETWEEN 6 AND 11 THEN '06-11'
    WHEN transaction_hour::INTEGER BETWEEN 12 AND 17 THEN '12-17'
    ELSE '18-23'
  END
ORDER BY canal, plage_horaire;


-- 7. Taux de fraude selon l’internationalité

SELECT
  international_transaction AS international,
  COUNT(*) AS transactions,
  SUM(is_fraud::INTEGER) AS fraudes,
  ROUND(
    100.0 * SUM(is_fraud::INTEGER) / COUNT(*),
    3
  ) AS taux_fraude_pct
FROM transactions
GROUP BY international_transaction
ORDER BY taux_fraude_pct DESC;


-- 8. Taux de fraude selon le pays à risque

SELECT
  high_risk_country AS pays_a_risque,
  COUNT(*) AS transactions,
  SUM(is_fraud::INTEGER) AS fraudes,
  ROUND(
    100.0 * SUM(is_fraud::INTEGER) / COUNT(*),
    3
  ) AS taux_fraude_pct
FROM transactions
GROUP BY high_risk_country
ORDER BY taux_fraude_pct DESC;


-- 9. Croisement canal, internationalité et pays à risque

SELECT
  transaction_channel AS canal,
  international_transaction AS international,
  high_risk_country AS pays_a_risque,
  COUNT(*) AS transactions,
  SUM(is_fraud::INTEGER) AS fraudes,
  ROUND(
    100.0 * SUM(is_fraud::INTEGER) / COUNT(*),
    3
  ) AS taux_fraude_pct
FROM transactions
GROUP BY
  transaction_channel,
  international_transaction,
  high_risk_country
ORDER BY taux_fraude_pct DESC;


-- 10. Ratio montant / moyenne client

SELECT
  CASE
    WHEN amount_vs_avg_ratio::NUMERIC < 1 THEN '< 1'
    WHEN amount_vs_avg_ratio::NUMERIC < 2 THEN '1-2'
    WHEN amount_vs_avg_ratio::NUMERIC < 3 THEN '2-3'
    WHEN amount_vs_avg_ratio::NUMERIC < 5 THEN '3-5'
    ELSE '5+'
  END AS ratio_montant,
  COUNT(*) AS transactions,
  SUM(is_fraud::INTEGER) AS fraudes,
  ROUND(
    100.0 * SUM(is_fraud::INTEGER) / COUNT(*),
    3
  ) AS taux_fraude_pct
FROM transactions
GROUP BY ratio_montant
ORDER BY ratio_montant;


-- 11. Vélocité sur une heure

SELECT
  CASE
    WHEN transactions_last_1h::INTEGER = 0 THEN '0'
    WHEN transactions_last_1h::INTEGER = 1 THEN '1'
    WHEN transactions_last_1h::INTEGER = 2 THEN '2'
    WHEN transactions_last_1h::INTEGER = 3 THEN '3'
    WHEN transactions_last_1h::INTEGER <= 5 THEN '4-5'
    ELSE '6+'
  END AS transactions_1h,
  COUNT(*) AS transactions,
  SUM(is_fraud::INTEGER) AS fraudes,
  ROUND(
    100.0 * SUM(is_fraud::INTEGER) / COUNT(*),
    3
  ) AS taux_fraude_pct
FROM transactions
GROUP BY transactions_1h
ORDER BY transactions_1h;


-- 12. Construction du score de risque

SELECT
  (high_risk_country::INTEGER * 3)
  + (CASE WHEN transactions_last_1h::INTEGER >= 3 THEN 2 ELSE 0 END)
  + (CASE WHEN amount_vs_avg_ratio::NUMERIC >= 5 THEN 1 ELSE 0 END)
  + (CASE WHEN international_transaction::INTEGER = 1 THEN 2 ELSE 0 END)
  + (CASE WHEN transaction_channel = 'Online' THEN 2 ELSE 0 END)
  AS score_risque,
  COUNT(*) AS transactions,
  SUM(is_fraud::INTEGER) AS fraudes,
  ROUND(
    100.0 * SUM(is_fraud::INTEGER) / COUNT(*),
    3
  ) AS taux_fraude_pct,
  ROUND(
    100.0 * SUM(is_fraud::INTEGER) / 2055,
    3
  ) AS part_des_fraudes_pct
FROM transactions
GROUP BY score_risque
ORDER BY score_risque;


-- 13. Règle opérationnelle

SELECT
  CASE
    WHEN score_risque <= 3 THEN 'Parcours standard'
    WHEN score_risque = 4 THEN 'Contrôle léger'
    WHEN score_risque BETWEEN 5 AND 6 THEN 'Authentification renforcée'
    ELSE 'Revue manuelle'
  END AS action_recommandee,
  COUNT(*) AS transactions,
  SUM(is_fraud::INTEGER) AS fraudes,
  ROUND(
    100.0 * SUM(is_fraud::INTEGER) / COUNT(*),
    3
  ) AS taux_fraude_pct,
  ROUND(
    100.0 * SUM(is_fraud::INTEGER) / 2055,
    3
  ) AS part_des_fraudes_pct
FROM (
  SELECT
    *,
    (high_risk_country::INTEGER * 3)
    + (CASE WHEN transactions_last_1h::INTEGER >= 3 THEN 2 ELSE 0 END)
    + (CASE WHEN amount_vs_avg_ratio::NUMERIC >= 5 THEN 1 ELSE 0 END)
    + (CASE WHEN international_transaction::INTEGER = 1 THEN 2 ELSE 0 END)
    + (CASE WHEN transaction_channel = 'Online' THEN 2 ELSE 0 END)
    AS score_risque
  FROM transactions
) t
GROUP BY action_recommandee
ORDER BY taux_fraude_pct DESC;


-- 14. Validation sur échantillon test

SELECT
  CASE
    WHEN score_risque >= 5 THEN 'Alerte'
    ELSE 'Pas d’alerte'
  END AS decision,
  is_fraud::INTEGER AS fraude_reelle,
  COUNT(*) AS transactions
FROM (
  SELECT
    *,
    (high_risk_country::INTEGER * 3)
    + (CASE WHEN transactions_last_1h::INTEGER >= 3 THEN 2 ELSE 0 END)
    + (CASE WHEN amount_vs_avg_ratio::NUMERIC >= 5 THEN 1 ELSE 0 END)
    + (CASE WHEN international_transaction::INTEGER = 1 THEN 2 ELSE 0 END)
    + (CASE WHEN transaction_channel = 'Online' THEN 2 ELSE 0 END)
    AS score_risque
  FROM transactions
  WHERE hashtext(transaction_id) % 5 = 0
) t
GROUP BY decision, fraude_reelle
ORDER BY decision, fraude_reelle;
