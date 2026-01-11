<?php
/**
 * Plugin Name: PdG App API (PublishPress-safe + Categories)
 * Description: API per app mobile: login + accesso ai soli post leggibili secondo PublishPress Permissions (permessi su post/categorie). Endpoint categorie "navigabile". Hardening endpoint sensibili.
 * Version: 3.4
 * Author: Portobello di Gallura
 */

if (!defined('ABSPATH')) exit;

// API key: definibile in wp-config.php per evitare di hardcodarla nel plugin.
if (!defined('PDG_APP_API_KEY')) {
    define('PDG_APP_API_KEY', 'CHANGE_ME_IN_WP_CONFIG');
}

define('PDG_APP_TOKEN_META', 'pdg_app_token_hash');
define('PDG_APP_TOKEN_EXP_META', 'pdg_app_token_expiry');
define('PDG_APP_AUTH_FAIL_TRANSIENT_PREFIX', 'pdg_app_auth_fail_');

// Quanti post per categoria "campionare" per capire se l'utente può leggere qualcosa in quella categoria
if (!defined('PDG_APP_CATEGORY_SAMPLE_POSTS')) {
    define('PDG_APP_CATEGORY_SAMPLE_POSTS', 8);
}

// Quante categorie max per risposta (evita payload enormi)
if (!defined('PDG_APP_MAX_CATEGORIES')) {
    define('PDG_APP_MAX_CATEGORIES', 300);
}

// DEBUG: Abilita logging per debug permessi (impostare su false in produzione)
if (!defined('PDG_APP_DEBUG_PERMISSIONS')) {
    define('PDG_APP_DEBUG_PERMISSIONS', false);
}

/* ---------------------------
 * Helpers: API key + token
 * --------------------------- */

function pdg_app_verify_api_key(WP_REST_Request $request) {
    // Header primario (usato dall'app)
    $api_key = (string) $request->get_header('x-pdg-api-key');
    // Fallback: alcuni proxy/CDN riscrivono gli header custom
    if (!$api_key) {
        $api_key = (string) $request->get_header('x_pdg_api_key');
    }
    if (!$api_key) {
        return new WP_Error('rest_forbidden', 'Missing API key', ['status' => 403]);
    }
    if (!hash_equals(PDG_APP_API_KEY, $api_key)) {
        return new WP_Error('rest_forbidden', 'Invalid API key', ['status' => 403]);
    }
    return true;
}

function pdg_app_get_raw_authorization_header(WP_REST_Request $request): string {
    // 1) Via WP_REST_Request (quando disponibile)
    $auth = (string) $request->get_header('authorization');
    if ($auth) return $auth;

    // 2) Via $_SERVER (molti hosting usano questa forma)
    $server_candidates = [
        'HTTP_AUTHORIZATION',
        'REDIRECT_HTTP_AUTHORIZATION',
    ];
    foreach ($server_candidates as $k) {
        if (!empty($_SERVER[$k])) {
            return (string) $_SERVER[$k];
        }
    }

    // 3) Via getallheaders()/apache_request_headers (fallback)
    $headers = [];
    if (function_exists('getallheaders')) {
        $headers = getallheaders();
    } elseif (function_exists('apache_request_headers')) {
        $headers = apache_request_headers();
    }

    if (is_array($headers)) {
        foreach ($headers as $k => $v) {
            if (strcasecmp((string)$k, 'Authorization') === 0) {
                return (string) $v;
            }
        }
    }

    return '';
}

function pdg_app_get_bearer_token(WP_REST_Request $request): string {
    // Primary: Authorization: Bearer <token>
    $auth = pdg_app_get_raw_authorization_header($request);
    if ($auth && stripos($auth, 'Bearer ') === 0) {
        return trim(substr($auth, 7));
    }

    // Fallback: header custom (non viene filtrato da molti hosting)
    $token = (string) $request->get_header('x-pdg-token');
    if ($token) return trim($token);

    // Fallback: query param (ultima spiaggia)
    $token = (string) ($request->get_param('token') ?: '');
    if ($token) return trim($token);

    return '';
}

/**
 * Ritorna WP_User oppure WP_Error
 */
function pdg_app_get_user_from_token(WP_REST_Request $request) {
    $token = pdg_app_get_bearer_token($request);
    if (!$token) {
        return new WP_Error('rest_forbidden', 'Missing token', ['status' => 401]);
    }

    $now = time();
    $token_hash = hash('sha256', $token);

    $q = new WP_User_Query([
        'meta_query' => [
            [
                'key'     => PDG_APP_TOKEN_EXP_META,
                'value'   => $now,
                'compare' => '>=',
                'type'    => 'NUMERIC',
            ],
        ],
        'fields' => ['ID'],
        'number' => 1000,
    ]);

    foreach ($q->get_results() as $u) {
        $stored_hash = (string) get_user_meta($u->ID, PDG_APP_TOKEN_META, true);
        $exp         = (int) get_user_meta($u->ID, PDG_APP_TOKEN_EXP_META, true);

        if ($exp >= $now && $stored_hash && hash_equals($stored_hash, $token_hash)) {
            return get_user_by('id', $u->ID);
        }
    }

    return new WP_Error('rest_forbidden', 'Invalid or expired token', ['status' => 401]);
}

/**
 * Imposta user corrente: fondamentale per PublishPress Permissions.
 * 
 * IMPORTANTE: PublishPress Permissions usa filtri su WP_Query e current_user_can().
 * Dobbiamo assicurarci che:
 * 1. L'utente sia impostato correttamente con wp_set_current_user()
 * 2. Il global $current_user sia aggiornato
 * 3. I filtri di PublishPress siano re-inizializzati per il nuovo utente
 */
function pdg_app_set_current_user(int $user_id): void {
    if ($user_id <= 0) {
        return;
    }
    
    // Imposta l'utente corrente
    wp_set_current_user($user_id);
    
    // Forza refresh del global $current_user
    global $current_user;
    $current_user = wp_get_current_user();
    
    // Forza re-inizializzazione di PublishPress Permissions se presente
    // PressPermit (PublishPress Permissions) usa un singleton che potrebbe
    // aver già cachato i permessi per l'utente anonimo/precedente
    if (defined('PRESSPERMIT_VERSION') || defined('PP_VERSION') || defined('PPC_VERSION')) {
        // Prova a resettare il cache dei permessi di PublishPress
        if (function_exists('presspermit')) {
            $pp = presspermit();
            if ($pp && method_exists($pp, 'reinitUser')) {
                $pp->reinitUser($user_id);
            } elseif ($pp && isset($pp->user_permissions) && is_object($pp->user_permissions)) {
                // Forza ricaricamento dei permessi utente
                unset($pp->user_permissions);
            }
        }
        
        // Alternativa: trigger azione che PublishPress ascolta
        do_action('set_current_user');
        
        // Pulisce eventuali cache di capabilities
        wp_cache_delete($user_id, 'user_meta');
        
        if (PDG_APP_DEBUG_PERMISSIONS) {
            error_log("[PDG-APP] PublishPress Permissions detected, user $user_id set");
        }
    }
    
    if (PDG_APP_DEBUG_PERMISSIONS) {
        $user = wp_get_current_user();
        $roles = implode(',', $user->roles ?: []);
        error_log("[PDG-APP] Current user set: ID=$user_id, login={$user->user_login}, roles=[$roles]");
    }
}

function pdg_app_require_auth(WP_REST_Request $request) {
    $k = pdg_app_verify_api_key($request);
    if (is_wp_error($k)) return $k;

    $u = pdg_app_get_user_from_token($request);
    if (is_wp_error($u)) return $u;

    $request->set_param('_pdg_user_id', $u->ID);
    pdg_app_set_current_user((int)$u->ID);

    return true;
}

function pdg_app_current_user_id(WP_REST_Request $request): int {
    return (int) $request->get_param('_pdg_user_id');
}

/**
 * Check permessi lettura singolo post:
 * PublishPress Permissions influenza `read_post` tramite filtri su user_has_cap.
 * 
 * NOTA: PublishPress Permissions può usare diversi metodi:
 * 1. Filtro su 'user_has_cap' per current_user_can()
 * 2. Filtro su 'posts_where' / 'posts_join' per WP_Query
 * 3. Permessi per categoria/termine
 * 
 * Questa funzione controlla TUTTI i metodi possibili.
 */
function pdg_app_user_can_read_post(int $user_id, int $post_id): bool {
    if ($user_id <= 0 || $post_id <= 0) return false;

    pdg_app_set_current_user($user_id);
    
    $post = get_post($post_id);
    if (!$post instanceof WP_Post) {
        return false;
    }

    // Metodo 1: Standard WordPress capability check
    // PublishPress Permissions filtra questo tramite 'user_has_cap'
    $can_read = current_user_can('read_post', $post_id);
    
    // Metodo 2: Controlla anche 'read' generico per post privati
    if (!$can_read && $post->post_status === 'private') {
        $can_read = current_user_can('read_private_posts');
    }
    
    // Metodo 3: Se PublishPress Permissions è attivo, usa le sue API dirette
    if (!$can_read && function_exists('presspermit')) {
        $pp = presspermit();
        if ($pp && method_exists($pp, 'userCan')) {
            $can_read = $pp->userCan('read', $post_id, 'post');
        }
    }
    
    // Metodo 4: Controlla se l'utente ha accesso alla categoria del post
    // (PublishPress Permissions può limitare per categoria)
    if (!$can_read) {
        $can_read = pdg_app_user_can_read_post_by_terms($user_id, $post);
    }
    
    if (PDG_APP_DEBUG_PERMISSIONS) {
        $result = $can_read ? 'YES' : 'NO';
        error_log("[PDG-APP] User $user_id can read post $post_id ({$post->post_status}): $result");
    }
    
    return $can_read;
}

/**
 * Controlla se l'utente può leggere il post basandosi sui termini/categorie.
 * Utile quando PublishPress Permissions limita per categoria.
 */
function pdg_app_user_can_read_post_by_terms(int $user_id, WP_Post $post): bool {
    // Se esiste la funzione di PublishPress per check categorie, usala
    if (function_exists('pp_get_terms_exceptions')) {
        // Prova approccio PP diretto
        return false; // Lascia che gli altri metodi decidano
    }
    
    // Fallback: controlla se l'utente può leggere almeno una categoria del post
    $categories = wp_get_post_categories($post->ID, ['fields' => 'ids']);
    if (empty($categories)) {
        return false;
    }
    
    // Se l'utente può leggere il post di tipo generico E ha accesso
    // Questo è un controllo aggiuntivo che può essere customizzato
    return false; // Di default, non concediamo accesso extra qui
}

/* ---------------------------
 * REST endpoints
 * --------------------------- */

add_action('rest_api_init', function () {

    register_rest_route('pdg-app/v1', '/auth', [
        'methods'  => 'POST',
        'callback' => 'pdg_app_authenticate_user',
        'permission_callback' => 'pdg_app_verify_api_key',
        'args' => [
            'username' => ['required' => true, 'type' => 'string'],
            'password' => ['required' => true, 'type' => 'string'],
        ],
    ]);

    register_rest_route('pdg-app/v1', '/posts', [
        'methods'  => 'GET',
        'callback' => 'pdg_app_get_readable_posts',
        'permission_callback' => 'pdg_app_require_auth',
    ]);

    register_rest_route('pdg-app/v1', '/posts/(?P<id>\d+)', [
        'methods'  => 'GET',
        'callback' => 'pdg_app_get_readable_single_post',
        'permission_callback' => 'pdg_app_require_auth',
    ]);

    // ✅ Categorie "navigabili": include solo categorie dove l'utente può leggere almeno 1 post
    register_rest_route('pdg-app/v1', '/categories', [
        'methods'  => 'GET',
        'callback' => 'pdg_app_get_navigable_categories',
        'permission_callback' => 'pdg_app_require_auth',
    ]);
    
    // 🔍 Debug endpoint per verificare permessi utente
    register_rest_route('pdg-app/v1', '/debug/permissions', [
        'methods'  => 'GET',
        'callback' => 'pdg_app_debug_permissions',
        'permission_callback' => 'pdg_app_require_auth',
    ]);
});

/* ---------------------------
 * Auth + rate limit
 * --------------------------- */

function pdg_app_authenticate_user(WP_REST_Request $request) {
    $username = (string) $request->get_param('username');
    $password = (string) $request->get_param('password');

    $ip  = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
    $key = PDG_APP_AUTH_FAIL_TRANSIENT_PREFIX . md5($ip);

    $fails = (int) get_transient($key);
    if ($fails >= 10) {
        return new WP_Error('rate_limited', 'Too many attempts. Try again later.', ['status' => 429]);
    }

    $user = wp_authenticate($username, $password);
    if (is_wp_error($user)) {
        set_transient($key, $fails + 1, 15 * MINUTE_IN_SECONDS);
        return new WP_Error('invalid_credentials', 'Invalid credentials', ['status' => 401]);
    }

    delete_transient($key);

    $token = bin2hex(random_bytes(32)); // 64 chars
    $hash  = hash('sha256', $token);
    $exp   = time() + (30 * DAY_IN_SECONDS);

    update_user_meta($user->ID, PDG_APP_TOKEN_META, $hash);
    update_user_meta($user->ID, PDG_APP_TOKEN_EXP_META, $exp);

    return rest_ensure_response([
        'success' => true,
        'user' => [
            'id'           => $user->ID,
            'username'     => $user->user_login,
            'display_name' => $user->display_name,
        ],
        'token'  => $token,
        'expiry' => $exp,
    ]);
}

/* ---------------------------
 * Posts (PublishPress filtered)
 * --------------------------- */

function pdg_app_get_readable_posts(WP_REST_Request $request) {
    $user_id = pdg_app_current_user_id($request);
    
    // CRITICO: Imposta l'utente PRIMA di qualsiasi query
    // Questo permette a PublishPress Permissions di applicare i filtri
    pdg_app_set_current_user($user_id);

    // 🔥 Supporto per caricare TUTTI i post: per_page=-1 o all=1
    $load_all = (int) ($request->get_param('all') ?: 0) === 1;
    
    $per_page = (int) ($request->get_param('per_page') ?: 20);
    if ($per_page === -1) {
        $load_all = true;
    }
    if (!$load_all) {
        if ($per_page < 1) $per_page = 20;
        if ($per_page > 100) $per_page = 100; // Aumentato limite max per pagina
    }

    $page = (int) ($request->get_param('page') ?: 1);
    if ($page < 1) $page = 1;

    $allowed_orderby = ['date', 'modified', 'title'];
    $orderby = (string) ($request->get_param('orderby') ?: 'date');
    if (!in_array($orderby, $allowed_orderby, true)) $orderby = 'date';

    $order = strtoupper((string) ($request->get_param('order') ?: 'DESC'));
    if (!in_array($order, ['ASC', 'DESC'], true)) $order = 'DESC';

    $cat = (int) ($request->get_param('category') ?: 0);

    // IMPORTANTE: suppress_filters = false permette a PublishPress Permissions
    // di applicare i suoi filtri (posts_where, posts_join, etc.)
    $args = [
        'post_type'        => 'post',
        'post_status'      => ['publish', 'private'],
        'posts_per_page'   => $load_all ? -1 : ($per_page * 6),  // -1 = tutti, altrimenti oversampling
        'orderby'          => $orderby,
        'order'            => $order,
        'no_found_rows'    => $load_all, // Ottimizzazione se carichiamo tutto
        'suppress_filters' => false, // CRITICO: permette filtri di PublishPress
        'ignore_sticky_posts' => true,
    ];
    
    // Paginazione solo se non carichiamo tutto
    if (!$load_all) {
        $args['paged'] = $page;
    }

    if ($cat > 0) {
        $args['cat'] = $cat;
    }
    
    if (PDG_APP_DEBUG_PERMISSIONS) {
        $user = wp_get_current_user();
        $roles = implode(',', $user->roles ?: []);
        error_log("[PDG-APP] Querying posts for user $user_id (roles: $roles), category: $cat, load_all: " . ($load_all ? 'YES' : 'NO'));
    }

    $query = new WP_Query($args);
    
    if (PDG_APP_DEBUG_PERMISSIONS) {
        error_log("[PDG-APP] Query returned " . count($query->posts ?: []) . " posts before permission check");
    }

    $posts = [];
    $checked = 0;
    $denied = 0;

    foreach (($query->posts ?: []) as $p) {
        // Se non carichiamo tutto, rispetta il limite per_page
        if (!$load_all && count($posts) >= $per_page) break;

        // Normalizza WP_Post o ID
        $post_obj = null;
        $post_id  = 0;

        if (is_object($p) && isset($p->ID)) {
            $post_obj = $p;
            $post_id  = (int) $p->ID;
        } else {
            $post_id  = (int) $p;
            $post_obj = get_post($post_id);
        }

        if (!$post_obj instanceof WP_Post) continue;
        if ($post_obj->post_type !== 'post') continue;
        if (!in_array($post_obj->post_status, ['publish', 'private'], true)) continue;

        $checked++;
        
        if (pdg_app_user_can_read_post($user_id, $post_id)) {
            $formatted = pdg_app_format_post($post_obj);
            if (!empty($formatted)) {
                $posts[] = $formatted;
            }
        } else {
            $denied++;
        }
    }
    
    if (PDG_APP_DEBUG_PERMISSIONS) {
        error_log("[PDG-APP] Permission check: checked=$checked, allowed=" . count($posts) . ", denied=$denied");
    }

    return rest_ensure_response([
        'posts'        => $posts,
        'current_page' => $load_all ? 1 : $page,
        'total_posts'  => count($posts),
        'total_checked' => $checked,
        'total_denied' => $denied,
        'load_all'     => $load_all,
        'note'         => $load_all ? 'All readable posts loaded' : 'Filtered by PublishPress Permissions',
    ]);
}

function pdg_app_get_readable_single_post(WP_REST_Request $request) {
    $user_id = pdg_app_current_user_id($request);
    pdg_app_set_current_user($user_id);

    $post_id = (int) $request->get_param('id');
    $post = get_post($post_id);

    if (!$post || !$post instanceof WP_Post || $post->post_type !== 'post') {
        return new WP_Error('post_not_found', 'Post not found', ['status' => 404]);
    }

    if (!in_array($post->post_status, ['publish', 'private'], true)) {
        return new WP_Error('rest_forbidden', 'Forbidden', ['status' => 403]);
    }

    if (!pdg_app_user_can_read_post($user_id, $post_id)) {
        return new WP_Error('rest_forbidden', 'Forbidden', ['status' => 403]);
    }

    return rest_ensure_response(pdg_app_format_post($post));
}

/* ---------------------------
 * Categories "navigabili"
 * --------------------------- */

function pdg_app_get_navigable_categories(WP_REST_Request $request) {
    $user_id = pdg_app_current_user_id($request);
    pdg_app_set_current_user($user_id);

    $cats = get_categories([
        'taxonomy'   => 'category',
        'hide_empty' => false,     // vogliamo anche categorie vuote (ma poi filtriamo per leggibilità)
        'number'     => PDG_APP_MAX_CATEGORIES,
        'orderby'    => 'name',
        'order'      => 'ASC',
    ]);

    $out = [];

    foreach (($cats ?: []) as $cat) {
        $cat_id = (int) $cat->term_id;
        if ($cat_id <= 0) continue;

        // Se la categoria ha zero post, NON possiamo dedurre permesso "reale".
        // Per sicurezza: la includiamo SOLO se l'app chiede esplicitamente include_empty=1 E l'utente può almeno leggere qualcosa nel sito.
        // (Default: la nascondiamo per non leakare struttura.)
        if ((int)$cat->count === 0) {
            $include_empty = (int) ($request->get_param('include_empty') ?: 0);
            if ($include_empty !== 1) {
                continue;
            }
            // include_empty=1: includiamo ma marcando readable=false (l'app può mostrarla "grigia")
            $out[] = [
                'id'     => $cat_id,
                'name'   => (string) $cat->name,
                'slug'   => (string) $cat->slug,
                'parent' => (int) $cat->parent,
                'readable' => false,
            ];
            continue;
        }

        // Campioniamo alcuni post della categoria e vediamo se ALMENO UNO è leggibile
        $sample = new WP_Query([
            'post_type'        => 'post',
            'post_status'      => ['publish', 'private'],
            'posts_per_page'   => PDG_APP_CATEGORY_SAMPLE_POSTS,
            'fields'           => 'ids',
            'no_found_rows'    => true,
            'cat'              => $cat_id,
            'suppress_filters' => false, // Permetti filtri PublishPress
            'ignore_sticky_posts' => true,
        ]);

        $readable = false;
        foreach (($sample->posts ?: []) as $pid) {
            $pid = (int)$pid;
            if ($pid > 0 && pdg_app_user_can_read_post($user_id, $pid)) {
                $readable = true;
                break;
            }
        }

        if ($readable) {
            $out[] = [
                'id'     => $cat_id,
                'name'   => (string) $cat->name,
                'slug'   => (string) $cat->slug,
                'parent' => (int) $cat->parent,
                'readable' => true,
            ];
        }
    }

    return rest_ensure_response($out);
}

/* ---------------------------
 * Output post (minimo e robusto)
 * --------------------------- */

function pdg_app_format_post($post): array {
    if (is_numeric($post)) {
        $post = get_post((int)$post);
    }
    if (!$post instanceof WP_Post) {
        return [];
    }

    $featured_image = '';
    if (has_post_thumbnail($post->ID)) {
        $featured_image = (string) get_the_post_thumbnail_url($post->ID, 'full');
    }

    // 🔥 Estrai categorie dal post
    $categories = [];
    $post_categories = get_the_category($post->ID);
    if (!empty($post_categories) && !is_wp_error($post_categories)) {
        foreach ($post_categories as $cat) {
            $categories[] = (int) $cat->term_id;
        }
    }

    return [
        'id'       => (int) $post->ID,
        'date'     => (string) $post->post_date,
        'modified' => (string) $post->post_modified,
        'slug'     => (string) $post->post_name,
        'status'   => (string) $post->post_status,
        'link'     => (string) get_permalink($post->ID),
        'title'    => ['rendered' => (string) $post->post_title],
        'content'  => ['rendered' => apply_filters('the_content', $post->post_content)],
        'excerpt'  => ['rendered' => (string) ($post->post_excerpt ?: wp_strip_all_tags(wp_trim_words($post->post_content, 55)))],
        'featured_image_url' => $featured_image,
        'categories' => $categories, // 🔥 NUOVO: ID delle categorie
    ];
}

/* ---------------------------
 * Hardening REST: blocca endpoint sensibili
 * --------------------------- */

add_filter('rest_authentication_errors', function ($result) {
    if (!empty($result)) return $result;

    $uri = $_SERVER['REQUEST_URI'] ?? '';

    $blocked_for_non_admin = [
        '#/wp-json/wp/v2/users#',
        '#/wp-json/wp/v2/settings#',
        '#/wp-json/wp/v2/plugins#',
        '#/wp-json/wp/v2/themes#',
    ];

    foreach ($blocked_for_non_admin as $pattern) {
        if (preg_match($pattern, $uri)) {
            if (!current_user_can('manage_options')) {
                return new WP_Error('rest_forbidden', 'Forbidden', ['status' => 403]);
            }
        }
    }

    return $result;
}, 20);

/* ---------------------------
 * Debug Permissions Endpoint
 * --------------------------- */

function pdg_app_debug_permissions(WP_REST_Request $request) {
    $user_id = pdg_app_current_user_id($request);
    pdg_app_set_current_user($user_id);
    
    $user = wp_get_current_user();
    
    // Info utente
    $user_info = [
        'id'           => $user->ID,
        'login'        => $user->user_login,
        'display_name' => $user->display_name,
        'email'        => $user->user_email,
        'roles'        => $user->roles,
        'caps'         => array_keys(array_filter($user->allcaps ?: [])),
    ];
    
    // Info Ultimate Member (se presente)
    $um_info = [];
    if (function_exists('um_user')) {
        um_fetch_user($user_id);
        $um_info = [
            'um_role'     => um_user('role'),
            'um_status'   => um_user('account_status'),
        ];
    }
    
    // Info PublishPress Permissions (se presente)
    $pp_info = [
        'installed' => false,
        'version'   => null,
    ];
    
    if (defined('PRESSPERMIT_VERSION')) {
        $pp_info['installed'] = true;
        $pp_info['version'] = PRESSPERMIT_VERSION;
    } elseif (defined('PP_VERSION')) {
        $pp_info['installed'] = true;
        $pp_info['version'] = PP_VERSION;
    } elseif (defined('PPC_VERSION')) {
        $pp_info['installed'] = true;
        $pp_info['version'] = PPC_VERSION;
    }
    
    // Test lettura post: prendi 5 post random e verifica permessi
    $test_posts = get_posts([
        'post_type'        => 'post',
        'post_status'      => ['publish', 'private'],
        'posts_per_page'   => 10,
        'orderby'          => 'rand',
        'suppress_filters' => true, // Ignora filtri per ottenere TUTTI i post
    ]);
    
    $post_tests = [];
    foreach ($test_posts as $p) {
        $can_standard = current_user_can('read_post', $p->ID);
        $can_pdg = pdg_app_user_can_read_post($user_id, $p->ID);
        
        $cats = wp_get_post_categories($p->ID, ['fields' => 'names']);
        
        $post_tests[] = [
            'id'             => $p->ID,
            'title'          => $p->post_title,
            'status'         => $p->post_status,
            'categories'     => $cats,
            'can_read_wp'    => $can_standard,
            'can_read_pdg'   => $can_pdg,
        ];
    }
    
    // Conta totale post e quanti leggibili
    $total_posts = wp_count_posts('post');
    $published = (int)($total_posts->publish ?? 0);
    $private = (int)($total_posts->private ?? 0);
    
    // Query con filtri PublishPress attivi
    $filtered_query = new WP_Query([
        'post_type'        => 'post',
        'post_status'      => ['publish', 'private'],
        'posts_per_page'   => -1,
        'fields'           => 'ids',
        'suppress_filters' => false,
    ]);
    $filtered_count = count($filtered_query->posts ?: []);
    
    // Query senza filtri (tutti i post)
    $unfiltered_query = new WP_Query([
        'post_type'        => 'post',
        'post_status'      => ['publish', 'private'],
        'posts_per_page'   => -1,
        'fields'           => 'ids',
        'suppress_filters' => true,
    ]);
    $unfiltered_count = count($unfiltered_query->posts ?: []);
    
    return rest_ensure_response([
        'user'          => $user_info,
        'ultimate_member' => $um_info,
        'publishpress_permissions' => $pp_info,
        'post_counts'   => [
            'total_published' => $published,
            'total_private'   => $private,
            'with_filters'    => $filtered_count,
            'without_filters' => $unfiltered_count,
            'difference'      => $unfiltered_count - $filtered_count,
        ],
        'sample_posts'  => $post_tests,
        'diagnosis'     => pdg_app_diagnose_permissions($user_info, $pp_info, $filtered_count, $unfiltered_count),
    ]);
}

/**
 * Diagnosi automatica dei problemi di permessi
 */
function pdg_app_diagnose_permissions(array $user_info, array $pp_info, int $filtered, int $unfiltered): array {
    $issues = [];
    $suggestions = [];
    
    // Check 1: PublishPress installato?
    if (!$pp_info['installed']) {
        $issues[] = 'PublishPress Permissions non rilevato';
        $suggestions[] = 'Verifica che PublishPress Permissions sia installato e attivato';
    }
    
    // Check 2: Ruoli utente
    if (empty($user_info['roles'])) {
        $issues[] = 'Utente senza ruoli assegnati';
        $suggestions[] = 'Assegna un ruolo all\'utente in WordPress o Ultimate Member';
    }
    
    // Check 3: Filtri funzionanti?
    if ($filtered === $unfiltered && $unfiltered > 0) {
        $issues[] = 'I filtri PublishPress non sembrano attivi (stesso numero di post con/senza filtri)';
        $suggestions[] = 'Verifica le impostazioni di PublishPress Permissions per il ruolo ' . implode(',', $user_info['roles']);
    }
    
    // Check 4: Nessun post accessibile
    if ($filtered === 0 && $unfiltered > 0) {
        $issues[] = 'Utente non ha accesso a nessun post';
        $suggestions[] = 'Configura i permessi in PublishPress > Permissions per il ruolo dell\'utente';
        $suggestions[] = 'Verifica che le categorie abbiano permessi di lettura per il ruolo';
    }
    
    // Check 5: Capability read_post
    if (!in_array('read', $user_info['caps']) && !in_array('read_post', $user_info['caps'])) {
        $issues[] = 'Utente non ha capability "read" base';
        $suggestions[] = 'Aggiungi la capability "read" al ruolo in WordPress';
    }
    
    if (empty($issues)) {
        return [
            'status' => 'ok',
            'message' => 'Nessun problema rilevato. I permessi sembrano configurati correttamente.',
        ];
    }
    
    return [
        'status' => 'issues_found',
        'issues' => $issues,
        'suggestions' => $suggestions,
    ];
}
?>
