# 🌟 Clarity V2 - L'Assistant Discord Ultime

<div align="center">

![Version](https://img.shields.io/badge/version-2.0.0-blue.svg?style=for-the-badge)
![License](https://img.shields.io/badge/license-MIT-green.svg?style=for-the-badge)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey.svg?style=for-the-badge)
![Tech](https://img.shields.io/badge/built%20with-Bun%20%26%20TypeScript-informational.svg?style=for-the-badge)

**Une infrastructure de bot Discord robuste, modulaire et intelligente, déployée en un clin d'œil grâce à InitBot.**

 • [Support](https://discord.gg/clarity-studio) 

</div>

---

## 📖 Introduction

**Clarity V2** représente l'état de l'art des bots Discord. Conçu pour la performance et l'évolutivité, il intègre des fonctionnalités avancées d'intelligence artificielle, de modération proactive et de divertissement.

Ce projet se distingue par son système de déploiement unique, **InitBot**, un orchestrateur intelligent qui automatise l'intégralité du cycle de vie de l'application : de l'installation des dépendances système à la configuration de la persistance des données, en passant par la gestion des processus via PM2.

Que vous soyez un développeur cherchant une base solide ou un administrateur de communauté, Clarity V2 est conçu pour vous.

---

## 📑 Table des Matières

- [🌟 Clarity V2 - L'Assistant Discord Ultime](#-clarity-v2---lassistant-discord-ultime)
  - [📖 Introduction](#-introduction)
  - [📑 Table des Matières](#-table-des-matières)
  - [✨ Fonctionnalités Principales](#-fonctionnalités-principales)
  - [🔧 Prérequis Techniques](#-prérequis-techniques)
  - [🚀 Installation Automatisée (InitBot)](#-installation-automatisée-initbot)
    - [Le Script InitBot](#le-script-initbot)
    - [Procédure d'Installation](#procédure-dinstallation)
  - [⚙️ Configuration & Persistance](#️-configuration--persistance)
    - [Variables d'Environnement](#variables-denvironnement)
    - [Stockage Centralisé](#stockage-centralisé)
  - [📂 Structure du Projet](#-structure-du-projet)
  - [💻 Exemples d'Utilisation](#-exemples-dutilisation)
  - [🧪 Tests et Vérifications](#-tests-et-vérifications)
  - [🤝 Contribution](#-contribution)
  - [📄 Licence](#-licence)

---

## ✨ Fonctionnalités Principales

### 🤖 Cœur du Bot (Clarity V2)
- **Intelligence Artificielle** : Chatbot contextuel (LLM local/distant) et génération d'images.
- **Système Familial** : Arbres généalogiques interactifs, mariages, adoptions.
- **Modération Avancée** : Anti-raid, sanctions graduelles, logs complets.
- **Musique Haute Fidélité** : Support multi-plateformes (Spotify, Deezer, SoundCloud) via Lavalink.
- **Économie & Niveaux** : Système complet de progression et de commerce.

### 🛠️ Système de Déploiement (InitBot)
- **Installation Universelle** : Compatible Linux, macOS et Windows (via Git Bash/WSL).
- **Gestion des Dépendances** : Installation automatique de Bun, PM2, et des outils de build (make, gcc).
- **Persistance des Données** : Sauvegarde automatique des configurations (tokens, préférences) dans un espace centralisé (`~/.clarity-v2-data`).
- **Migration Intelligente** : Détection et transfert automatique des anciennes données locales.
- **Intégrité des Données** : Vérification automatique et auto-réparation des fichiers de configuration corrompus.

---

## 🔧 Prérequis Techniques

Avant de lancer l'installation, assurez-vous de disposer des éléments suivants :

| Composant | Version Requise | Description |
|-----------|----------------|-------------|
| **OS** | Linux, macOS, Windows | Tout système Unix-like ou WSL sur Windows. |
| **Git** | Dernière version | Pour cloner le dépôt et gérer les versions. |
| **Curl** | Dernière version | Pour télécharger les binaires d'installation (Bun). |
| **Accès Internet** | Haut débit | Nécessaire pour télécharger les dépendances et modèles IA. |

> **Note** : Le script `initBot.sh` se chargera d'installer **Bun**, **PM2** et les compilateurs nécessaires si ils sont absents.

---

## 🚀 Installation Automatisée (InitBot)

Nous avons simplifié le processus d'installation à l'extrême grâce à notre script `initBot.sh`.

### Le Script InitBot

`initBot.sh` est bien plus qu'un script d'installation. C'est un gestionnaire de configuration persistant qui :
1. Détecte votre environnement (OS, Shell).
2. Installe les outils manquants.
3. Clone ou met à jour le dépôt Clarity V2.
4. Configure les accès (Token GitHub, Token Discord).
5. Lance l'application via un gestionnaire de processus (PM2).

### Procédure d'Installation

1. **Téléchargez le script** (ou clonez ce dépôt) :
   ```bash
   git clone https://github.com/mrtsubasa/clarity-init-bot.git
   cd Clarity-V2
   ```

2. **Rendez le script exécutable** :
   ```bash
   chmod +x initBot.sh
   ```

3. **Lancez l'initialisation** :
   ```bash
   ./initBot.sh
   ```

4. **Laissez-vous guider** :
   Le script est interactif. Il vous demandera les informations nécessaires uniquement si elles ne sont pas déjà sauvegardées dans le système de persistance.

---

## ⚙️ Configuration & Persistance

### Variables d'Environnement

Le projet utilise un fichier `.env` standard. `initBot.sh` peut le générer pour vous. Voici les variables clés :

```env
# Authentification
DISCORD_TOKEN=votre_token_discord
OWNER_ID=votre_id_discord

# Base de Données
DATABASE_URL="postgresql://user:password@localhost:5432/clarity"

# IA & APIs
OPENAI_API_KEY=sk-...
GEMINI_API_KEY=...
```

### Stockage Centralisé

Pour garantir que vous ne perdez jamais vos configurations (même en supprimant le dossier du projet), InitBot utilise un dossier centralisé :

- **Emplacement** : `~/.clarity-v2-data/` (dans votre dossier utilisateur)
- **Fichiers** :
  - `persistence.json` : Stocke les tokens et préférences avec timestamps.
  - `git_token/` : Conteneur sécurisé pour le token GitHub.

> **Sécurité** : Les permissions de ce dossier sont verrouillées pour n'être accessibles que par votre utilisateur.

---

## 📂 Structure du Projet

Voici un aperçu de l'architecture de Clarity V2 :

```
Clarity-V2/
├── .github/              # Workflows CI/CD
├── Docs/                 # Documentation technique détaillée
├── Src/
│   ├── Client/           # Point d'entrée du Bot (Sharding)
│   ├── Commands/         # Gestionnaires de commandes (Prefix & Slash)
│   │   ├── Fun/          # Commandes de divertissement
│   │   ├── Mod/          # Commandes de modération
│   │   └── ...
│   ├── Components/       # Composants réutilisables & Logique métier
│   ├── Events/           # Gestionnaires d'événements Discord
│   ├── Utils/            # Fonctions utilitaires
│   └── ...
├── initBot.sh            # Script d'initialisation et de gestion (InitBot)
├── package.json          # Définition des dépendances
├── tsconfig.json         # Configuration TypeScript
└── ...
```

---

## 💻 Exemples d'Utilisation

### Lancer le bot manuellement
Si vous n'utilisez pas PM2 via le script :
```bash
bun start
```

### Créer une nouvelle commande
Ajoutez un fichier dans `Src/Commands/PrefixCommands/General/ping.ts` :

```typescript
import { PrefixCommand } from "../../../Interfaces/Command";

export const command: PrefixCommand = {
    name: "ping",
    description: "Renvoie la latence du bot",
    aliases: ["p"],
    run: async (client, message, args) => {
        await message.reply(`Pong! 🏓 Latence: ${client.ws.ping}ms`);
    }
};
```

### Vérifier les logs PM2
```bash
pm2 logs clarity-v2
```

---

## 🧪 Tests et Vérifications

Pour s'assurer que votre installation est robuste :

1. **Vérification de l'intégrité des données** :
   Le script `initBot.sh` lance automatiquement `verify_integrity` à chaque démarrage pour scanner `persistence.json`.

2. **Tests Unitaires** (à venir) :
   ```bash
   bun test
   ```

3. **Vérification des Permissions** :
   Le script tente d'écrire un fichier témoin dans le dossier de stockage centralisé pour confirmer les droits d'accès en écriture/lecture.

---

## 🤝 Contribution

Les contributions sont les bienvenues ! Pour participer :

1. Forkez le projet.
2. Créez une branche pour votre fonctionnalité (`git checkout -b feature/AmazingFeature`).
3. Committez vos changements (`git commit -m 'Add some AmazingFeature'`).
4. Pushez vers la branche (`git push origin feature/AmazingFeature`).
5. Ouvrez une Pull Request.

Veuillez respecter les conventions de codage (ESLint/Prettier) définies dans le projet.

---

## 📄 Licence

Ce projet est sous licence **MIT** - voir le fichier [LICENSE](LICENSE) pour plus de détails.

---

<div align="center">
  <sub>Développé avec ❤️ par l'équipe Clarity</sub>
</div>
