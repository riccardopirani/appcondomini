# 🔍 Debug - Plugin PdG App API Non Funziona

## Problema Identificato
Il plugin API è installato e autentica correttamente gli utenti, **ma non ritorna nessun post**.

✅ Login funziona  
❌ Fetch posts ritorna `[]` (array vuoto)

## Causa Probabile
L'utente PdGadmin **non ha i permessi di lettura** sui post pubblicati.

Il plugin filtra i post usando:
```php
if (pdg_app_user_can_read_post($user_id, (int)$p->ID)) {
    // mostra il post
}
```

Se l'utente non ha i permessi, nessun post viene ritornato.

## Soluzione Rapida - Verifica Permessi

### Opzione 1: Via WordPress Admin Dashboard
1. Accedi a WordPress Admin: `https://www.portobellodigallura.it/wp-admin`
2. Vai a **Utenti** → Seleziona **PdGadmin**
3. Scorri fino a **PublishPress Permissions** (se installato)
4. Assicurati che l'utente abbia permessi di **lettura** su tutte le categorie/post

### Opzione 2: Test da Linea di Comando
SSH sul server e esegui:

```bash
cd /var/www/wordpress

# Test 1: Verifica che il plugin sia attivo
wp plugin list | grep pdg-app

# Test 2: Verifica i post pubblici
wp post list --post_type=post --status=publish,private

# Test 3: Verifica i permessi dell'utente PdGadmin
wp user get pdgadmin --field=ID  # nota l'ID (es: 2)

# Test 4: Verifica se l'utente può leggere un post specifico
wp eval 'wp_set_current_user(2); var_dump(current_user_can("read_post", 1));'
# Dovrebbe ritornare: bool(true) oppure bool(false)
```

## Soluzione Permanente

### Aggiungi un Endpoint di Debug al Plugin

Modifica `/wp-content/plugins/pdg-app-api.php` e aggiungi questo endpoint **prima di `?>` finale**:

```php
// ENDPOINT DEBUG (RIMUOVERE IN PRODUZIONE)
add_action('rest_api_init', function () {
    register_rest_route('pdg-app/v1', '/debug', [
        'methods'  => 'GET',
        'callback' => 'pdg_app_debug_endpoint',
        'permission_callback' => '__return_true', // Pubblico per debug
    ]);
});

function pdg_app_debug_endpoint(WP_REST_Request $request) {
    // Prendi il token dalla richiesta
    $user = pdg_app_get_user_from_token($request);
    
    if (is_wp_error($user)) {
        return [
            'status' => 'error',
            'message' => $user->get_error_message(),
            'code' => $user->get_error_code(),
        ];
    }
    
    pdg_app_set_current_user($user->ID);
    
    // Leggi qualche post
    $posts = get_posts([
        'post_type' => 'post',
        'post_status' => ['publish', 'private'],
        'posts_per_page' => 5,
    ]);
    
    $readable = [];
    foreach ($posts as $p) {
        $can_read = pdg_app_user_can_read_post($user->ID, $p->ID);
        $readable[] = [
            'post_id' => $p->ID,
            'title' => $p->post_title,
            'user_can_read' => $can_read,
            'capabilities' => [
                'read_post' => current_user_can('read_post', $p->ID),
                'edit_posts' => current_user_can('edit_posts'),
                'publish_posts' => current_user_can('publish_posts'),
            ],
        ];
    }
    
    return [
        'status' => 'ok',
        'user' => [
            'id' => $user->ID,
            'login' => $user->user_login,
            'display_name' => $user->display_name,
        ],
        'total_posts' => count($posts),
        'readable_posts' => $readable,
    ];
}
?>
```

### Test dell'Endpoint di Debug

```bash
curl -X GET 'https://www.portobellodigallura.it/wp-json/pdg-app/v1/debug' \
  -H "x-pdg-api-key: Tz7Wq8GlWVlVhZg3sGQgRrSn7lOc8AHe" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

La risposta ti dirà:
- Se il token è valido
- Quanti post totali ci sono
- Quanti post l'utente può leggere
- I permessi specifici dell'utente

## Azioni da Intraprendere

1. **Verifica permessi** - Accedi a WordPress e controlla i permessi di PdGadmin
2. **Se il plugin non è attivo** - Attivalo da Admin → Plugin
3. **Se non ci sono post** - Crea almeno un post test published
4. **Se i permessi sono errati** - Configura PublishPress per dare accesso a PdGadmin

## Rimozione Debug
Una volta risolto, **rimuovi l'endpoint di debug** dal plugin per motivi di sicurezza.

---

**Prossimo step**: Fammi sapere il risultato del test e possiamo procedere!
