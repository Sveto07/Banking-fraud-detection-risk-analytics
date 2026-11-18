# Données

Ce projet utilise un dataset de transactions bancaires afin d’analyser les facteurs associés à la fraude.

## Source des données

Le dataset est un dataset public de transactions bancaires, téléchargé depuis Kaggle.

Le fichier CSV n’est pas inclus dans ce dépôt afin d’éviter le stockage de données volumineuses ou potentiellement sensibles.

## Comment obtenir les données

1. Créer un compte sur Kaggle.
2. Télécharger le dataset utilisé pour ce projet.
3. Placer le fichier CSV dans un dossier local, par exemple :

```text
data/transactions.csv
```

4. Importer le fichier dans PostgreSQL afin de reproduire l’analyse.

## Structure attendue

Le fichier CSV doit contenir au minimum les colonnes suivantes :

- transaction_id
- customer_id
- card_id
- merchant_id
- transaction_datetime
- transaction_amount
- merchant_category
- merchant_country
- transaction_hour
- international_transaction
- high_risk_country
- transactions_last_1h
- amount_vs_avg_ratio
- transaction_channel
- is_fraud

## Remarque

Les colonnes fraud_type et fraud_amount_lost ne doivent pas être utilisées comme variables prédictives, car elles ne sont disponibles qu’après identification de la fraude.
