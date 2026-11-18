# Détection de fraude bancaire et analyse du risque

Ce projet est né d’une question simple : à partir des données d’un portefeuille de transactions bancaires, est-il possible d’identifier les transactions les plus susceptibles d’être frauduleuses, sans pénaliser inutilement les clients légitimes ?

Pour y répondre, j’ai analysé 100 000 transactions à l’aide de SQL, exploré les facteurs associés à la fraude, construit un score de risque interprétable, puis validé une règle de triage sur un échantillon indépendant.

## Le problème que j’ai voulu résoudre

La fraude ne se résume pas à trouver des transactions « suspectes ». Le véritable enjeu est de trouver un équilibre entre deux risques opposés :

- Laisser passer une fraude, ce qui génère une perte financière.
- Alerter ou bloquer une transaction légitime, ce qui crée de la friction pour le client et un coût opérationnel.

Avec seulement 2,055 % de fraudes dans le dataset, la difficulté était donc réelle : la grande majorité des transactions sont légitimes. Une règle trop large générerait beaucoup de fausses alertes, tandis qu’une règle trop restrictive laisserait passer l’essentiel des fraudes.

Mon objectif n’était donc pas de prédire la fraude avec un modèle complexe dès le départ, mais de comprendre d’abord quels signaux pouvaient réellement aider à prioriser les contrôles.

## Les données

Le dataset contient 100 000 transactions et 43 variables. Il inclut des informations sur la transaction, le marchand, le client, le moyen de paiement, la géographie et le comportement récent du client.

La variable cible est `is_fraud` :

- `0` : transaction légitime
- `1` : transaction frauduleuse

Le dataset est fortement déséquilibré :

| Type de transaction | Nombre | Part |
|---|---:|---:|
| Légitime | 97 945 | 97,945 % |
| Frauduleuse | 2 055 | 2,055 % |

Les transactions frauduleuses ont également un montant moyen plus élevé : 169,93 contre 125,97 pour les transactions légitimes. Ce premier constat m’a poussé à explorer plus finement la relation entre le montant et le risque.

## Ma démarche

J’ai commencé par des analyses simples : taux de fraude global, montant moyen, catégories de marchands et tranches de montant.

Puis j’ai progressivement croisé les variables entre elles. L’idée était de ne pas regarder chaque signal isolément, mais de comprendre comment ils se combinent.

Par exemple, une transaction internationale n’a pas le même niveau de risque selon qu’elle est réalisée en ligne, dans un magasin physique, sur un distributeur ou depuis une application mobile. De même, un pays à risque ne signifie pas automatiquement une fraude : il faut aussi regarder le montant, la fréquence des transactions et le comportement habituel du client.

Cette approche m’a permis de construire progressivement une logique de score, plutôt que de poser une règle arbitraire dès le départ.

## Ce que j’ai découvert

### Les transactions internationales sont un signal fort

Les transactions internationales représentent 55,5 % du volume, mais 92,4 % des fraudes.

Leur taux de fraude atteint 3,420 %, contre 0,353 % pour les transactions nationales. Une transaction internationale a donc environ 9,7 fois plus de chances d’être frauduleuse.

C’est l’un des signaux les plus discriminants du dataset.

### Les pays à risque amplifient fortement le risque

Les transactions vers un pays à risque ne représentent que 4,9 % du volume, mais 26,5 % des fraudes.

Leur taux de fraude atteint 11,050 %, contre 1,588 % pour les autres pays. Le risque est donc environ 7 fois plus élevé.

### Le canal Online concentre une grande partie du risque

Le canal Online regroupe 45,5 % des transactions, mais 70,4 % des fraudes.

Son taux de fraude est de 3,178 %, contre 0,802 % pour les transactions en magasin. Cela s’explique en partie par le fait que les paiements en ligne sont davantage associés aux transactions internationales et aux fraudes de type Card-Not-Present.

### La vélocité est un signal important

Lorsqu’un client effectue 3 transactions ou plus en une heure, le taux de fraude passe à 5,001 %.

Ce segment ne représente que 9 % du volume, mais 24,4 % des fraudes. La rafale de transactions est donc un signal beaucoup plus fort que le simple nombre de transactions sur 24 heures.

### Le montant anormal compte, mais seulement au-delà d’un seuil

Tant que le montant reste inférieur à 5 fois la moyenne habituelle du client, le taux de fraude reste relativement stable.

En revanche, au-delà de 5 fois la moyenne, le taux passe à 3,863 %. Le signal devient donc net seulement lorsque le montant est réellement inhabituel.

## Construction du score

Après avoir exploré les données, j’ai construit un score simple et interprétable à partir des signaux les plus robustes :

- Pays à risque
- Transaction internationale
- Canal Online
- Rafale de transactions sur une heure
- Montant anormalement élevé

Le score est calculé ainsi :

```sql
(high_risk_country::INTEGER * 3)
+ (CASE WHEN transactions_last_1h::INTEGER >= 3 THEN 2 ELSE 0 END)
+ (CASE WHEN amount_vs_avg_ratio::NUMERIC >= 5 THEN 1 ELSE 0 END)
+ (CASE WHEN international_transaction::INTEGER = 1 THEN 2 ELSE 0 END)
+ (CASE WHEN transaction_channel = 'Online' THEN 2 ELSE 0 END)
```

J’ai d’abord testé une première version du score, puis je me suis rendu compte que certaines pondérations ne reflétaient pas correctement le risque réel. En particulier, le poids accordé au pays à risque était trop élevé par rapport à la rafale de transactions et au canal Online.

J’ai donc ajusté les pondérations afin que les segments les plus dangereux obtiennent réellement les scores les plus élevés.

## Résultats du score

| Groupe de risque | Transactions | Fraudes | Taux de fraude | Part des fraudes |
|---|---:|---:|---:|---:|
| 0–2 | 63 786 | 333 | 0,522 % | 16,204 % |
| 3–4 | 27 013 | 799 | 2,958 % | 38,881 % |
| 5–6 | 6 472 | 492 | 7,602 % | 23,942 % |
| 7+ | 2 729 | 431 | 15,793 % | 20,973 % |

Le score sépare clairement les populations :

- Le groupe 0–2 concentre 63,8 % des transactions, mais seulement 16,2 % des fraudes.
- Le groupe 7+ ne représente que 2,7 % des transactions, mais capte 21 % des fraudes.
- Le taux de fraude passe de 0,522 % à 15,793 % entre le groupe le plus sûr et le groupe le plus risqué.

## Règle opérationnelle

Plutôt que de bloquer automatiquement les transactions à risque, j’ai proposé une approche progressive.

| Score | Action recommandée | Transactions | Fraudes | Taux de fraude |
|---|---|---:|---:|---:|
| 0–3 | Parcours standard | 67 621 | 392 | 0,580 % |
| 4 | Contrôle léger | 23 178 | 740 | 3,193 % |
| 5–6 | Authentification renforcée | 6 472 | 492 | 7,602 % |
| 7–10 | Revue manuelle | 2 729 | 431 | 15,793 % |

Cette logique permet de concentrer les efforts sur les transactions réellement à risque, sans créer une friction excessive pour les clients légitimes.

## Validation sur un échantillon test

Construire un score et l’évaluer sur les mêmes données ne suffit pas. J’ai donc créé un échantillon test de 20 % des transactions, puis j’ai évalué la règle uniquement sur cet échantillon.

La règle retenue est simple :

```sql
Alerte si score_risque >= 5
```

### Matrice de confusion

| Décision | Fraude réelle = 1 | Fraude réelle = 0 | Total |
|---|---:|---:|---:|
| Alerte | 182 | 1 593 | 1 775 |
| Pas d’alerte | 217 | 17 853 | 18 070 |

### Performance

| Indicateur | Résultat |
|---|---:|
| Précision | 10,254 % |
| Rappel | 45,614 % |
| Taux de faux positifs | 8,193 % |
| Exactitude | 90,897 % |

La règle capte 45,6 % des fraudes en alertant seulement 8,9 % des transactions. Parmi les transactions alertées, 10,3 % sont réellement frauduleuses.

Ce résultat est cohérent avec ce que l’on observe sur l’ensemble des données, ce qui renforce la robustesse du score.

## Ce que ce projet m’a appris

Ce projet m’a appris que l’analyse de données ne se résume pas à produire des graphiques ou des taux. La vraie valeur vient de la capacité à transformer une question business en une décision concrète.

J’ai appris à distinguer plusieurs choses qui peuvent sembler similaires, mais qui ne le sont pas :

- Un taux de fraude élevé ne signifie pas nécessairement un grand nombre de fraudes.
- Un grand nombre de fraudes ne signifie pas nécessairement un segment prioritaire.
- Un score élevé ne garantit pas un meilleur ciblage si les pondérations ne reflètent pas la réalité du risque.
- Une règle utile doit tenir compte à la fois des fraudes détectées et des faux positifs générés.

J’ai aussi compris l’importance de valider un score sur des données non utilisées pour sa construction. Sans cette étape, il est facile de se tromper sur la performance réelle d’une règle.

## Limites

Cette analyse reste descriptive. Elle met en évidence des associations entre certaines variables et la fraude, mais elle ne démontre pas de relation de cause à effet.

Le dataset est également déséquilibré : les fraudes ne représentent que 2,055 % des transactions. Cela rend l’interprétation plus difficile et impose de regarder attentivement la précision, le rappel et les faux positifs.

Certaines variables sont redondantes, notamment `used_chip`, `card_present` et `distance_from_home_km`. Elles apportent peu d’information supplémentaire une fois le canal ou l’internationalité pris en compte.

Enfin, `fraud_type` et `fraud_amount_lost` ne doivent pas être utilisées comme variables prédictives. Elles ne sont disponibles qu’après identification de la fraude et introduiraient donc une fuite de données.

## Ce que je ferais ensuite

La suite naturelle serait de transformer cette analyse en un projet Python reproductible.

L’objectif ne serait pas de remplacer le score par un modèle complexe, mais de vérifier si un modèle statistique peut améliorer le compromis entre détection des fraudes et faux positifs.

Je commencerais par une régression logistique, afin de garder un modèle interprétable, puis je comparerais les résultats avec un modèle de gradient boosting. L’évaluation se ferait sur un jeu de test distinct, avec une attention particulière portée à la précision, au rappel, à la matrice de confusion et à la courbe précision-rappel.

## Outils utilisés

- PostgreSQL
- pgAdmin 4
- SQL
- Analyse exploratoire de données
- Construction de score de risque
- Validation sur échantillon test
