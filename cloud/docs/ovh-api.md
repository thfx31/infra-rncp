# API OVH — DNS challenge cert-manager

Les credentials OVH sont nécessaires uniquement pour cert-manager : il crée des
enregistrements DNS temporaires sur `yplank.fr` (géré chez OVH) pour prouver la
propriété du domaine auprès de Let's Encrypt.

## 1. Créer l'application OVH

1. Aller sur https://www.ovh.com/auth/api/createApp
2. Se connecter avec le compte OVH qui gère `yplank.fr`
3. Remplir :
   - **Application name** : ex. `infra-rncp-certmanager`
   - **Application description** : ex. `cert-manager DNS challenge k8s.yplank.fr`
4. Récupérer : `Application Key` et `Application Secret`

## 2. Créer le Consumer Key

```bash
curl -XPOST -H "X-Ovh-Application: <APPLICATION_KEY>" \
  -H "Content-type: application/json" \
  -d '{"accessRules":[{"method":"GET","path":"/*"},{"method":"POST","path":"/*"},{"method":"PUT","path":"/*"},{"method":"DELETE","path":"/*"}]}' \
  https://eu.api.ovh.com/1.0/auth/credential
```

La commande retourne un JSON avec une `validationUrl` et un `consumerKey` :

```json
{
  "validationUrl": "https://www.ovh.com/auth/?credentialToken=xxx",
  "consumerKey": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "state": "pendingValidation"
}
```

Ouvrir la `validationUrl` dans un navigateur et valider. Le `consumerKey` est alors actif.

## 3. GitHub Secrets à configurer

| Secret | Valeur |
|--------|--------|
| `OVH_APPLICATION_KEY` | `Application Key` (étape 1) |
| `OVH_APPLICATION_SECRET` | `Application Secret` (étape 1) |
| `OVH_CONSUMER_KEY` | `consumerKey` (étape 2) |

> Si ces secrets sont déjà configurés dans le dépôt pour `cloud/`, ils s'appliquent
> automatiquement à `cloud/` aussi — rien à refaire.
